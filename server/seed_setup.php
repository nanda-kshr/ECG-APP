<?php
// seed_setup.php
// Lightweight script to ensure users + reports tables exist and to seed admin/doctor/technician users.
// Usage: place this file in your server htdocs (same folder as this repo's server/) and open in browser,
// or run via CLI: php seed_setup.php

header('Content-Type: text/plain; charset=utf-8');

try {
    require_once __DIR__ . '/api/db.php'; // this sets up $pdo or exits with JSON error
    if (!isset($pdo) || !($pdo instanceof PDO)) {
        throw new RuntimeException('Database connection ($pdo) not available. Check server/api/db.php');
    }

    echo "Connected to database. Using DB: " . (defined('DB_NAME') ? DB_NAME : (getenv('DB_NAME') ?: '(env not set)')) . "\n";

    // Create users table compatible with the project's expected schema
    $sqlUsers = <<<'SQL'
CREATE TABLE IF NOT EXISTS users (
  id VARCHAR(36) PRIMARY KEY,
  name VARCHAR(255),
  email VARCHAR(255) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  role ENUM('admin','doctor','technician') NOT NULL DEFAULT 'technician',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
SQL;

    $pdo->exec($sqlUsers);
    echo "Ensured table: users\n";

    // Create reports table compatible with admin_dashboard.php
    $sqlReports = <<<'SQL'
CREATE TABLE IF NOT EXISTS reports (
  id VARCHAR(36) PRIMARY KEY,
  patient_name VARCHAR(255) NOT NULL,
  technician_id VARCHAR(36) NULL,
  doctor_id VARCHAR(36) NULL,
  result TEXT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
SQL;

    $pdo->exec($sqlReports);
    echo "Ensured table: reports\n";

    // Helper: upsert a user by email
    $upsert = $pdo->prepare(
        "INSERT INTO users (id, name, email, password_hash, role) VALUES (:id, :name, :email, :hash, :role) " .
        "ON DUPLICATE KEY UPDATE name = VALUES(name), password_hash = VALUES(password_hash), role = VALUES(role)"
    );

    // Seed users
    $users = [
        ['id' => 'admin-1', 'name' => 'Admin User', 'email' => 'admin@example.com', 'password' => 'admin123', 'role' => 'admin'],
        ['id' => 'doctor-1', 'name' => 'Doctor User', 'email' => 'doctor@example.com', 'password' => 'doctor123', 'role' => 'doctor'],
        ['id' => 'tech-1', 'name' => 'Technician User', 'email' => 'tech@example.com', 'password' => 'tech123', 'role' => 'technician'],
    ];

    foreach ($users as $u) {
        $hash = password_hash($u['password'], PASSWORD_DEFAULT);
        $upsert->execute([':id' => $u['id'], ':name' => $u['name'], ':email' => $u['email'], ':hash' => $hash, ':role' => $u['role']]);
        echo "Seeded user: {$u['email']} (role: {$u['role']})\n";
    }

    echo "\nSetup complete. You can login with the seeded accounts (change passwords immediately in production).\n";
    echo "Admin: admin@example.com / admin123\nDoctor: doctor@example.com / doctor123\nTechnician: tech@example.com / tech123\n";

} catch (Throwable $e) {
    http_response_code(500);
    echo "Error during seed: " . $e->getMessage() . "\n";
    // If db.php already emitted JSON and exited, this likely won't run; otherwise show details for debugging
    error_log('seed_setup error: ' . $e->getMessage());
    exit(1);
}

?>