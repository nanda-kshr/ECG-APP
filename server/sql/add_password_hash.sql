-- add_password_hash.sql
-- Adds a nullable password_hash column for bcrypt storage.
-- Replace `your_database_name` with your DB name if you run this directly with mysql client.

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS password_hash VARCHAR(255) DEFAULT NULL;

-- OPTIONAL: verify counts after running
SELECT
  (SELECT COUNT(*) FROM users WHERE password_hash IS NOT NULL AND TRIM(password_hash) <> '') AS with_hash,
  (SELECT COUNT(*) FROM users WHERE password IS NOT NULL AND TRIM(password) <> '' AND (password_hash IS NULL OR TRIM(password_hash) = '')) AS legacy_plain;
