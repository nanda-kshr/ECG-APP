<?php
// Send CORS headers early so preflight requests don't get blocked
header('Content-Type: application/json; charset=utf-8');
// Allow any origin. If you need credentials, replace '*' with the exact origin and
// add Access-Control-Allow-Credentials: true
header('Access-Control-Allow-Origin: *');
header('Vary: Origin');
// Allow common request headers that clients may send
header('Access-Control-Allow-Headers: Origin, Content-Type, Authorization, X-Requested-With, Accept');
// Allow common HTTP methods
header('Access-Control-Allow-Methods: GET, POST, OPTIONS, PUT, DELETE');
// Cache preflight response for 1 day
header('Access-Control-Max-Age: 86400');

// Reply to preflight requests immediately
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    // No body for OPTIONS
    http_response_code(200);
    exit;
}

$is_debug = (getenv('DEBUG') === '1');

try {
    require_once __DIR__ . '/db.php'; // ensure this file defines $pdo (PDO)

    // --- begin: robust input parsing ---
    $contentType = $_SERVER['CONTENT_TYPE'] ?? $_SERVER['HTTP_CONTENT_TYPE'] ?? '';
    $raw = file_get_contents('php://input');
    if ($raw === false) $raw = '';

    // remove UTF-8 BOM if present
    if (strpos($raw, "\xEF\xBB\xBF") === 0) {
        $raw = substr($raw, 3);
    }

    // Accept JSON if content type contains 'json' (even with charset)
    $isJson = stripos($contentType, 'json') !== false || preg_match('/^\s*[\{\[]/', $raw);

    $data = null;
    if ($isJson) {
        if (trim($raw) !== '') {
            $data = json_decode($raw, true);
            if (json_last_error() !== JSON_ERROR_NONE) {
                error_log("login.php: Invalid JSON. Content-Type: $contentType Raw: " . substr($raw, 0, 200));
                http_response_code(400);
                $resp = [
                    'success' => false,
                    'error' => 'Invalid JSON'
                ];
                if ($is_debug) {
                    $resp['detail'] = json_last_error_msg();
                    $resp['raw'] = $raw;
                    $resp['content_type'] = $contentType;
                }
                echo json_encode($resp);
                exit;
            }
        } else {
            $data = null;
        }
    }

    if (!is_array($data)) {
        $data = $_POST;
    }

    $identifier = trim((string)($data['email'] ?? $data['username'] ?? $data['user'] ?? ''));
    $password = $data['password'] ?? $data['pass'] ?? $data['pwd'] ?? '';
    // Optional role filter: if client provides role, only authenticate users of that role
    $requestedRole = isset($data['role']) ? trim((string)$data['role']) : null;
    // --- end: robust input parsing ---

    if ($identifier === '' || $password === '') {
        http_response_code(400);
        $resp = ['success'=>false,'error'=>'Missing username/email or password'];
        if ($is_debug) {
            $resp['data'] = $data;
            $resp['raw'] = $raw;
        }
        echo json_encode($resp);
        exit;
    }

    // Detect existence of key columns to build a compatible query across schemas
    $hasUsername = false;
    $hasPasswordHash = false;
    $hasPlainPassword = false;

    try {
        $colStmt = $pdo->prepare("SHOW COLUMNS FROM users LIKE 'username'");
        $colStmt->execute();
        $hasUsername = (bool)$colStmt->fetch(PDO::FETCH_ASSOC);
    } catch (Throwable $ignore) {}

    try {
        $colStmt = $pdo->prepare("SHOW COLUMNS FROM users LIKE 'password_hash'");
        $colStmt->execute();
        $hasPasswordHash = (bool)$colStmt->fetch(PDO::FETCH_ASSOC);
    } catch (Throwable $ignore) {}

    try {
        $colStmt = $pdo->prepare("SHOW COLUMNS FROM users LIKE 'password'");
        $colStmt->execute();
        $hasPlainPassword = (bool)$colStmt->fetch(PDO::FETCH_ASSOC);
    } catch (Throwable $ignore) {}

    // Build SELECT list based on existing columns
    $selectCols = ['id', 'email', 'name', 'role'];
    if ($hasUsername) $selectCols[] = 'username';
    if ($hasPasswordHash) $selectCols[] = 'password_hash';
    if ($hasPlainPassword) $selectCols[] = 'password';
    $selectList = implode(', ', $selectCols);

    if ($hasUsername) {
        // Authenticate by email OR username
        $stmt = $pdo->prepare("SELECT $selectList FROM users WHERE email = :id OR username = :id_alt LIMIT 1");
        $stmt->execute(['id' => $identifier, 'id_alt' => $identifier]);
    } else {
        // Authenticate by email only
        $stmt = $pdo->prepare("SELECT $selectList FROM users WHERE email = :id LIMIT 1");
        $stmt->execute(['id' => $identifier]);
    }

    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$user) {
        // Helpful debug: log when no user matched the identifier
        if ($is_debug) {
            error_log("login.php: no user found for identifier: $identifier");
        }
    }

    $authOk = false;
    if ($user) {
        // Prefer secure bcrypt verification if password_hash column exists
        if ($hasPasswordHash && isset($user['password_hash']) && (string)$user['password_hash'] !== '') {
            $authOk = password_verify((string)$password, (string)$user['password_hash']);
        }
        // Fallback: legacy plain text password (development-only schemas)
        if (!$authOk && $hasPlainPassword && isset($user['password'])) {
            $authOk = ((string)$password === (string)$user['password']);
        }
    }

    if ($authOk) {
        if ($requestedRole !== null && strcasecmp($requestedRole, (string)$user['role']) !== 0) {
            http_response_code(401);
            echo json_encode(['success' => false, 'error' => 'Invalid credentials']);
            exit;
        }
        // --- Migration/rehash helpers ---
        // If we authenticated using a legacy plain text password but the schema
        // has a password_hash column, create a bcrypt hash and save it. Also
        // rehash existing hashes when password_needs_rehash indicates so.
        try {
            // Ensure we have the id available
            $userId = $user['id'] ?? null;
            if ($userId) {
                // If the schema has password_hash but the user's column is empty,
                // and we matched via plain text fallback, create the hash now.
                if ($hasPasswordHash && (empty($user['password_hash']) || $user['password_hash'] === null) && $hasPlainPassword && isset($user['password']) ) {
                    // create new hash from provided password
                    $newHash = password_hash((string)$password, PASSWORD_DEFAULT);
                    $upd = $pdo->prepare('UPDATE users SET password_hash = :h WHERE id = :id');
                    $upd->execute(['h' => $newHash, 'id' => $userId]);
                    // update local copy so we don't leak old value below
                    $user['password_hash'] = $newHash;
                }

                // If the user has a password_hash and it needs rehash (algorithm changed), update it
                if ($hasPasswordHash && !empty($user['password_hash']) && password_needs_rehash($user['password_hash'], PASSWORD_DEFAULT)) {
                    $rehash = password_hash((string)$password, PASSWORD_DEFAULT);
                    $upd2 = $pdo->prepare('UPDATE users SET password_hash = :h WHERE id = :id');
                    $upd2->execute(['h' => $rehash, 'id' => $userId]);
                    $user['password_hash'] = $rehash;
                }
            }
        } catch (Throwable $ignore) {
            // Non-fatal: don't prevent login if the DB update fails; log when debugging
            if ($is_debug) error_log('login: rehash/update failed: ' . $ignore->getMessage());
        }
        // Clean sensitive fields
        unset($user['password_hash'], $user['password']);
        if (!isset($user['id']) || $user['id'] === '' || $user['id'] === null) {
            $user['id'] = $user['email'];
        }
        echo json_encode(['success'=>true,'user'=>$user]);
    } else {
        http_response_code(401);
        echo json_encode(['success'=>false,'error'=>'Invalid credentials']);
    }
} catch (Throwable $e) {
    error_log('login error: '.$e->getMessage());
    http_response_code(500);
    $resp = ['success'=>false,'error'=>'Server error'];
    $resp['detail'] = $e->getMessage(); // always include detail for now
    echo json_encode($resp);
}
?>