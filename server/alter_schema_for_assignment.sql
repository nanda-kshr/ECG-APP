-- Alter existing schema to add fields needed for duty doctor + patient assignment workflow
USE ecg_db;

-- USERS: add is_duty flag and department column
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS is_duty TINYINT(1) NOT NULL DEFAULT 0 AFTER role,
  ADD COLUMN IF NOT EXISTS department VARCHAR(100) NULL AFTER name;

-- PATIENTS: add assigned_doctor_id and status
ALTER TABLE patients
  ADD COLUMN IF NOT EXISTS assigned_doctor_id INT UNSIGNED NULL AFTER gender,
  ADD COLUMN IF NOT EXISTS status ENUM('pending','in_progress','completed','cancelled') NOT NULL DEFAULT 'pending' AFTER assigned_doctor_id;

-- Add FK for patients.assigned_doctor_id if not present
SET @fk_exists := (
  SELECT COUNT(*) FROM information_schema.REFERENTIAL_CONSTRAINTS
  WHERE CONSTRAINT_SCHEMA = DATABASE() AND CONSTRAINT_NAME = 'fk_patients_assigned_doctor'
);
SET @sql := IF(@fk_exists = 0,
  'ALTER TABLE patients ADD CONSTRAINT fk_patients_assigned_doctor FOREIGN KEY (assigned_doctor_id) REFERENCES users(id) ON DELETE SET NULL',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- TASKS: ensure columns exist (assigned_by, assigned_at, priority/status defaults)
ALTER TABLE tasks
  MODIFY COLUMN status ENUM('pending','assigned','in_progress','completed','cancelled') NOT NULL DEFAULT 'pending',
  MODIFY COLUMN priority ENUM('low','normal','high','urgent') NOT NULL DEFAULT 'normal',
  ADD COLUMN IF NOT EXISTS assigned_by INT UNSIGNED NULL AFTER assigned_doctor_id,
  ADD COLUMN IF NOT EXISTS assigned_at DATETIME NULL AFTER doctor_feedback,
  ADD CONSTRAINT IF NOT EXISTS fk_tasks_assigned_by FOREIGN KEY (assigned_by) REFERENCES users(id) ON DELETE SET NULL;

-- TASK_HISTORY: allow changed_by to be NULL (system/auto actions)
ALTER TABLE task_history
  MODIFY COLUMN changed_by INT UNSIGNED NULL;
