<?php
$DB_HOST = getenv('DB_HOST') ?: '127.0.0.1';
$DB_PORT = getenv('DB_PORT') ?: '3306';
$DB_NAME = getenv('DB_NAME') ?: null; // allow null so we can try fallbacks
$DB_USER = getenv('DB_USER') ?: 'root';
$DB_PASS = getenv('DB_PASS') ?: '';

// show detailed errors only in development
$is_debug = true; // force debug output for troubleshooting

// Candidate database names to try (env override first, then common names)
$candidates = [];
if ($DB_NAME) {
    $candidates[] = $DB_NAME;
}
$candidates = array_merge($candidates, [
    // Common database names used across environments. Add any other names you
    // use on your server (e.g., ecg_app_db) so the API can auto-detect them.
        'ecg_app_db']);
$candidates = array_values(array_unique($candidates));

$lastException = null;
$pdo = null;

// First: attempt to connect directly to a candidate DB (fast path)
foreach ($candidates as $candidateDb) {
    $DSN = "mysql:host={$DB_HOST};port={$DB_PORT};dbname={$candidateDb};charset=utf8mb4";
    try {
        $pdo = new PDO($DSN, $DB_USER, $DB_PASS, [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false,
            PDO::ATTR_STRINGIFY_FETCHES => false,
        ]);
        $DB_NAME = $candidateDb;
        break;
    } catch (PDOException $e) {
        $lastException = $e;
    }
}

// If direct connect failed, try connecting to the server without specifying a database
if (!$pdo) {
    try {
        $DSN_SERVER = "mysql:host={$DB_HOST};port={$DB_PORT};charset=utf8mb4";
        $serverPdo = new PDO($DSN_SERVER, $DB_USER, $DB_PASS, [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_NUM,
            PDO::ATTR_EMULATE_PREPARES => false,
        ]);

        $dbs = [];
        $rows = $serverPdo->query("SHOW DATABASES")->fetchAll(PDO::FETCH_COLUMN);
        if ($rows && is_array($rows)) $dbs = $rows;

        // find first candidate that exists on the server
        $found = null;
        foreach ($candidates as $c) {
            if (in_array($c, $dbs, true)) { $found = $c; break; }
        }

        if ($found) {
            // try connecting to the found DB
            $DSN = "mysql:host={$DB_HOST};port={$DB_PORT};dbname={$found};charset=utf8mb4";
            $pdo = new PDO($DSN, $DB_USER, $DB_PASS, [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_EMULATE_PREPARES => false,
                PDO::ATTR_STRINGIFY_FETCHES => false,
            ]);
            $DB_NAME = $found;
        } else {
            // no candidate DBs exist — produce helpful debug output
            http_response_code(500);
            $tried = implode(', ', $candidates);
            $existing = implode(', ', $dbs ?: ['(none)']);
            $errMsg = $lastException ? $lastException->getMessage() : 'Could not connect to MySQL server';
            error_log("DB connection failed (tried: {$tried}). Existing DBs: {$existing}. Server error: {$errMsg}");
            header('Content-Type: application/json; charset=utf-8');
            if ($is_debug) {
                echo json_encode([
                    'success' => false,
                    'error' => "DB connection failed (tried: {$tried}). Existing DBs: {$existing}. Server error: {$errMsg}",
                    'hint' => "Create/import one of the databases listed or set DB_NAME in environment. To import, run: mysql -u root -p < server/schema_ecg_new.sql (or schema.sql for ecg_app)."
                ]);
            } else {
                echo json_encode(['success' => false, 'error' => 'DB connection failed']);
            }
            exit;
        }

    } catch (PDOException $e) {
        http_response_code(500);
        $errMsg = $e->getMessage();
        error_log('DB server connection failed: ' . $errMsg);
        header('Content-Type: application/json; charset=utf-8');
        if ($is_debug) {
            echo json_encode(['success' => false, 'error' => 'DB server connection failed: ' . $errMsg]);
        } else {
            echo json_encode(['success' => false, 'error' => 'DB connection failed']);
        }
        exit;
    }
}