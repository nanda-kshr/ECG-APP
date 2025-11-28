<?php
// Run this once to create/update an admin user. Place it in htdocs/ecg_new/ and open it in browser.
// Update credentials below before running.
$email = 'admin@example.com';
$password = 'admin123'; // change immediately after creating
$name = 'Admin User';

// Use the shared PDO connection (db.php) so configuration is consistent
require_once __DIR__ . '/db.php';

$hash = password_hash($password, PASSWORD_DEFAULT);

try {
    // Use INSERT ... ON DUPLICATE KEY UPDATE by email. Assumes email has UNIQUE constraint.
    $ins = $pdo->prepare("INSERT INTO users (name, email, password_hash, role) VALUES (:name, :email, :hash, 'admin')
                          ON DUPLICATE KEY UPDATE name = VALUES(name), password_hash = VALUES(password_hash), role = 'admin'");
    $ins->execute(['name' => $name, 'email' => $email, 'hash' => $hash]);
    echo "Admin user ensured: $email\n";
    echo "Use this email/password to test login (change password after).\n";
} catch (Throwable $e) {
    echo "Error: " . $e->getMessage();
}
?>
