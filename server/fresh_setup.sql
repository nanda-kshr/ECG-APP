-- Fresh setup for ECG Task Assignment System
-- Drops and recreates tables with the required structure

-- Create database if missing
CREATE DATABASE IF NOT EXISTS ecg_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE ecg_db;

-- Disable foreign key checks for drops
SET FOREIGN_KEY_CHECKS = 0;

-- Drop new schema tables if they exist
DROP TABLE IF EXISTS task_history;
DROP TABLE IF EXISTS tasks;
DROP TABLE IF EXISTS ecg_images;
DROP TABLE IF EXISTS patients;
DROP TABLE IF EXISTS duty_roster;

-- Optional: drop legacy reports table
DROP TABLE IF EXISTS reports;

-- Users table (int IDs) with duty flag
DROP TABLE IF EXISTS users;
CREATE TABLE users (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  email VARCHAR(255) NOT NULL UNIQUE,
  username VARCHAR(100) NULL UNIQUE,
  password_hash VARCHAR(255) NULL,
  password VARCHAR(255) NULL,
  name VARCHAR(255) NULL,
  role ENUM('admin','doctor','technician') NOT NULL,
  is_duty TINYINT(1) NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Patients table stores core patient info and assignment summary
CREATE TABLE patients (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  patient_id VARCHAR(32) NOT NULL UNIQUE,
  name VARCHAR(255) NOT NULL,
  age INT NULL,
  gender ENUM('male','female','other') NULL,
  assigned_doctor_id INT UNSIGNED NULL,
  status ENUM('pending','in_progress','completed','cancelled') NOT NULL DEFAULT 'pending',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_patients_assigned_doctor FOREIGN KEY (assigned_doctor_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ECG images uploaded by technician
CREATE TABLE ecg_images (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  patient_id INT UNSIGNED NOT NULL,
  technician_id INT UNSIGNED NULL,
  image_path VARCHAR(1024) NOT NULL,
  image_name VARCHAR(255) NULL,
  file_size BIGINT NULL,
  mime_type VARCHAR(100) NULL,
  uploaded_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_ecg_images_patient FOREIGN KEY (patient_id) REFERENCES patients(id) ON DELETE CASCADE,
  CONSTRAINT fk_ecg_images_technician FOREIGN KEY (technician_id) REFERENCES users(id) ON DELETE SET NULL,
  INDEX idx_ecg_images_patient (patient_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tasks represent workflow over a patient ECG request
CREATE TABLE tasks (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  patient_id INT UNSIGNED NOT NULL,
  technician_id INT UNSIGNED NOT NULL,
  assigned_doctor_id INT UNSIGNED NULL,
  assigned_by INT UNSIGNED NULL,
  status ENUM('pending','assigned','in_progress','completed','cancelled') NOT NULL DEFAULT 'pending',
  priority ENUM('low','normal','high','urgent') NOT NULL DEFAULT 'normal',
  technician_notes TEXT NULL,
  admin_notes TEXT NULL,
  doctor_feedback TEXT NULL,
  assigned_at DATETIME NULL,
  completed_at DATETIME NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_tasks_patient FOREIGN KEY (patient_id) REFERENCES patients(id) ON DELETE CASCADE,
  CONSTRAINT fk_tasks_technician FOREIGN KEY (technician_id) REFERENCES users(id) ON DELETE RESTRICT,
  CONSTRAINT fk_tasks_doctor FOREIGN KEY (assigned_doctor_id) REFERENCES users(id) ON DELETE SET NULL,
  CONSTRAINT fk_tasks_assigned_by FOREIGN KEY (assigned_by) REFERENCES users(id) ON DELETE SET NULL,
  INDEX idx_tasks_doctor (assigned_doctor_id),
  INDEX idx_tasks_technician (technician_id),
  INDEX idx_tasks_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Task history for audit trail
CREATE TABLE task_history (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  task_id INT UNSIGNED NOT NULL,
  changed_by INT UNSIGNED NULL,
  old_status ENUM('pending','assigned','in_progress','completed','cancelled') NULL,
  new_status ENUM('pending','assigned','in_progress','completed','cancelled') NOT NULL,
  comment VARCHAR(500) NULL,
  changed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_task_history_task FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE,
  CONSTRAINT fk_task_history_user FOREIGN KEY (changed_by) REFERENCES users(id) ON DELETE SET NULL,
  INDEX idx_task_history_task (task_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Duty roster (optional scheduling, not used by auto-assign)
CREATE TABLE duty_roster (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  doctor_id INT UNSIGNED NOT NULL,
  duty_date DATE NOT NULL,
  shift ENUM('morning','afternoon','evening','night','full_day') NOT NULL DEFAULT 'full_day',
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_by INT UNSIGNED NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_duty_doctor FOREIGN KEY (doctor_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_duty_created_by FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL,
  UNIQUE KEY uniq_doctor_date (doctor_id, duty_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET FOREIGN_KEY_CHECKS = 1;

-- Seed users (passwords use bcrypt for 'password123': $2y$10$...) -- replace in production
INSERT INTO users (email, username, password_hash, name, role, is_duty) VALUES
('admin@ecg.com', NULL, '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Admin User', 'admin', 0),
('doctor1@ecg.com', NULL, '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Dr. Sarah Johnson', 'doctor', 1),
('doctor2@ecg.com', NULL, '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Dr. Michael Chen', 'doctor', 0),
('tech1@ecg.com', NULL, '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Tech One', 'technician', 0),
('tech2@ecg.com', NULL, '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Tech Two', 'technician', 0);

-- Optional: seed next 7 days duty roster for both doctors
INSERT INTO duty_roster (doctor_id, duty_date, shift, created_by)
SELECT d.id, CURDATE() + INTERVAL seq DAY, 'full_day', 1
FROM (
  SELECT 0 AS seq UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6
) x
CROSS JOIN (SELECT id FROM users WHERE role='doctor' ORDER BY id LIMIT 1) d;
