<?php
// CLI script to migrate legacy plain-text passwords into password_hash column.
// Usage: php migrate_passwords.php [--dry]

if (php_sapi_name() !== 'cli') {
    echo "This script must be run from the command line.\n";
    exit(1);
}

$dry = in_array('--dry', $argv, true);

require_once __DIR__ . '/../api/api/db.php'; // adjusts to repo layout; db.php should set $pdo

try {
    // Ensure password_hash column exists
    $colStmt = $pdo->query("SHOW COLUMNS FROM users LIKE 'password_hash'");
    $hasPasswordHash = (bool)$colStmt->fetch();
    if (!$hasPasswordHash) {
        echo "ERROR: users.password_hash column does not exist. Run the ALTER TABLE first.\n";
        exit(1);
    }

    $countStmt = $pdo->query("SELECT COUNT(*) as c FROM users WHERE password IS NOT NULL AND TRIM(password) <> '' AND (password_hash IS NULL OR password_hash = '')");
    $row = $countStmt->fetch(PDO::FETCH_ASSOC);
    $toMigrate = (int)($row['c'] ?? 0);
    echo "Users to migrate: $toMigrate\n";
    if ($toMigrate === 0) {
        echo "Nothing to do.\n";
        exit(0);
    }

    $select = $pdo->query("SELECT id, password FROM users WHERE password IS NOT NULL AND TRIM(password) <> '' AND (password_hash IS NULL OR password_hash = '')");
    $updated = 0;
    while ($u = $select->fetch(PDO::FETCH_ASSOC)) {
        $id = $u['id'];
        $plain = (string)$u['password'];
        $h = password_hash($plain, PASSWORD_DEFAULT);
        if ($dry) {
            echo "DRY: Would update user $id with hash: $h\n";
            $updated++;
            continue;
        }
        $upd = $pdo->prepare('UPDATE users SET password_hash = :h WHERE id = :id');
        $upd->execute(['h' => $h, 'id' => $id]);
        $updated += $upd->rowCount();
        echo "Updated user $id\n";
    }

    echo "Done. Updated $updated rows.\n";
} catch (Throwable $e) {
    echo "Migration failed: " . $e->getMessage() . "\n";
    exit(1);
}
