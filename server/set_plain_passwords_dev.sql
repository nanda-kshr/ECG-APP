-- DEVELOPMENT ONLY: Set plain text passwords
-- Run this in phpMyAdmin SQL tab

-- First, check your existing users
SELECT id, email, name, role FROM users ORDER BY id;

-- Update ALL existing users to have plain text password: "password123"
UPDATE users SET password = 'password123';

-- Verify the update
SELECT id, email, name, role, password FROM users ORDER BY id;

-- Now you can login with any user email + password: password123
-- Example logins:
-- Any email from your database + password: password123
