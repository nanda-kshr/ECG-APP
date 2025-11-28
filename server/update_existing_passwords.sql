-- This script will update existing user passwords to bcrypt hashes
-- Run this in phpMyAdmin SQL tab

-- First, let's see what users exist
SELECT id, email, name, role, 
       LENGTH(password) as password_length,
       SUBSTRING(password, 1, 10) as password_preview
FROM users 
ORDER BY id;

-- If you see passwords that are NOT bcrypt (bcrypt starts with $2y$ and is 60 characters),
-- you need to update them. 

-- OPTION 1: Update ALL users to have password: "password123" (for testing)
-- Uncomment the lines below to run:

-- UPDATE users SET password = '$2y$10$YixHDl6FmE8FqR5pZKKqBeFqLvX3QgOYqF6qKL2/8wWmXC2eGH6Gm';

-- This bcrypt hash is for "password123"
-- After running this, you can login with any user email + password: password123


-- OPTION 2: If you want to set specific passwords for specific users
-- Uncomment and modify as needed:

-- UPDATE users SET password = '$2y$10$YixHDl6FmE8FqR5pZKKqBeFqLvX3QgOYqF6qKL2/8wWmXC2eGH6Gm' WHERE email = 'admin@ecg.com';
-- UPDATE users SET password = '$2y$10$YixHDl6FmE8FqR5pZKKqBeFqLvX3QgOYqF6qKL2/8wWmXC2eGH6Gm' WHERE email = 'doctor1@ecg.com';
-- UPDATE users SET password = '$2y$10$YixHDl6FmE8FqR5pZKKqBeFqLvX3QgOYqF6qKL2/8wWmXC2eGH6Gm' WHERE email = 'tech1@ecg.com';

-- The hash above is for "password123"
