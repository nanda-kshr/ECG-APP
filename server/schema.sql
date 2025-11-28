CREATE DATABASE IF NOT EXISTS ecg_app CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE ecg_app;

-- users table
CREATE TABLE IF NOT EXISTS users (
  id VARCHAR(36) PRIMARY KEY,
  email VARCHAR(255) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  name VARCHAR(255),
  role ENUM('admin','doctor','technician') NOT NULL DEFAULT 'technician',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- reports table (dummy ECG reports)
CREATE TABLE IF NOT EXISTS reports (
  id VARCHAR(36) PRIMARY KEY,
  patient_name VARCHAR(255) NOT NULL,
  technician_id VARCHAR(36),
  doctor_id VARCHAR(36),
  result VARCHAR(255),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (technician_id) REFERENCES users(id) ON DELETE SET NULL,
  FOREIGN KEY (doctor_id) REFERENCES users(id) ON DELETE SET NULL
);

-- Insert a sample admin (password: admin123) -- replace with secure password in production
INSERT IGNORE INTO users (id, email, password_hash, name, role)
VALUES ('admin-1', 'admin@example.com', '$2y$10$XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX', 'Admin User', 'admin');
-- Note: replace the password_hash with a real bcrypt hash from password_hash('admin123', PASSWORD_DEFAULT)
