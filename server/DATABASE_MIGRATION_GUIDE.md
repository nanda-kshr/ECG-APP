# Database Migration Guide - Task Assignment System

## 🎯 Overview

This guide helps you safely migrate your ECG database to the new task assignment system.

## 📋 Before You Start

### Verify MySQL Command Access

First, find where MySQL is installed and test the command:

**Option 1: Check if mysql is in PATH**
```powershell
mysql --version
```

**Option 2: Find MySQL installation**
```powershell
# Common locations:
Get-ChildItem "C:\Program Files\MySQL" -Recurse -Filter mysql.exe
Get-ChildItem "C:\xampp\mysql" -Recurse -Filter mysql.exe
```

**Option 3: Use full path (replace with your actual path)**
```powershell
& "C:\xampp\mysql\bin\mysql.exe" --version
```

### Set MySQL Path (Recommended)

Once you find MySQL, create an alias for this session:
```powershell
# Example for XAMPP
Set-Alias -Name mysql -Value "C:\xampp\mysql\bin\mysql.exe"

# Example for MySQL Server 8.0
Set-Alias -Name mysql -Value "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe"
```

Or add to PATH permanently:
```powershell
# Add to system PATH (run as Administrator)
[Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\xampp\mysql\bin", "Machine")
```

## 🔍 Step 1: Pre-flight Check

**IMPORTANT**: Run this first to verify your database structure!

```powershell
mysql -u root -p ecg_db < "d:\Machine Learning\ECG - Copy\server\preflight_check.sql"
```

This will show you:
- ✓ Users table structure (must have INT UNSIGNED id)
- ✓ Existing users count by role
- ⚠ If new tables already exist
- ⚠ If old reports table has data

### Interpreting Results

**Check 1: Users Table Structure**
- **GOOD**: `id | int unsigned | NO | PRI | auto_increment`
- **BAD**: `id | varchar(36) | NO | PRI |`

If you see `varchar(36)`, you need to convert it (see Step 2A).

**Check 3: Existing Users**
You should see at least:
- 1 admin
- 1 doctor (for testing duty roster)
- 1 technician (for testing upload)

If missing, create them first.

**Check 4: New Tables Status**
- If tables already exist, you can skip the creation or drop them first
- `DROP TABLE IF EXISTS task_history, tasks, ecg_images, patients, duty_roster;`

## 🔄 Step 2A: Convert Users Table (Only If Needed)

**ONLY run this if** your users.id is `VARCHAR(36)` instead of `INT UNSIGNED`.

⚠️ **WARNING**: This will reassign user IDs! Backup first!

```powershell
# Backup entire database first
mysqldump -u root -p ecg_db > "d:\Machine Learning\ECG - Copy\backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').sql"

# Run conversion
mysql -u root -p ecg_db < "d:\Machine Learning\ECG - Copy\server\convert_users_to_int.sql"
```

After conversion, **save the ID mapping** shown in the output.

## 🚀 Step 2B: Run Migration (Standard Path)

If your users table is already `INT UNSIGNED`, run this:

```powershell
# Navigate to the server directory first
cd "d:\Machine Learning\ECG - Copy\server"

# Run the migration
mysql -u root -p ecg_db < create_tasks_schema.sql
```

This creates:
- ✓ `patients` table
- ✓ `ecg_images` table  
- ✓ `tasks` table
- ✓ `task_history` table
- ✓ `duty_roster` table

## 📁 Step 3: Create Upload Directory

```powershell
# Create directory for ECG images
New-Item -ItemType Directory -Path "d:\Machine Learning\ECG - Copy\server\uploads\ecg_images" -Force

# Verify creation
Test-Path "d:\Machine Learning\ECG - Copy\server\uploads\ecg_images"
```

Make sure your web server (Apache/IIS) has write permissions to this directory.

### Set Permissions (for Apache/XAMPP)

```powershell
# Grant full control (Windows)
icacls "d:\Machine Learning\ECG - Copy\server\uploads\ecg_images" /grant Everyone:F
```

## 👥 Step 4: Add Test Users (If Needed)

If you don't have test users, create them:

```sql
-- Create admin (password: admin123)
INSERT INTO users (email, password, name, role) VALUES 
('admin@test.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Admin User', 'admin');

-- Create doctor (password: doctor123)
INSERT INTO users (email, password, name, role) VALUES 
('doctor@test.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Dr. John Smith', 'doctor');

-- Create technician (password: tech123)
INSERT INTO users (email, password, name, role) VALUES 
('tech@test.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Tech User', 'technician');
```

**Note**: These use bcrypt hash for 'secret'. In production, use proper password hashing.

## 📅 Step 5: Add Duty Roster Entry

Add a doctor to today's duty roster:

```sql
-- Get your doctor's ID first
SELECT id, name FROM users WHERE role='doctor';

-- Add to duty roster (replace doctor_id with actual ID)
INSERT INTO duty_roster (doctor_id, duty_date, shift, created_by) VALUES
(2, CURDATE(), 'full_day', 1);  -- Replace 2 with your doctor's ID, 1 with admin's ID

-- Verify
SELECT dr.*, u.name as doctor_name 
FROM duty_roster dr
JOIN users u ON dr.doctor_id = u.id;
```

## ✅ Step 6: Verify Migration

Run these checks:

```sql
USE ecg_db;

-- Check all tables exist
SHOW TABLES;

-- Check users
SELECT role, COUNT(*) FROM users GROUP BY role;

-- Check duty roster
SELECT * FROM duty_roster WHERE duty_date >= CURDATE();

-- Verify foreign keys
SELECT 
  TABLE_NAME,
  COLUMN_NAME,
  CONSTRAINT_NAME,
  REFERENCED_TABLE_NAME,
  REFERENCED_COLUMN_NAME
FROM information_schema.KEY_COLUMN_USAGE
WHERE TABLE_SCHEMA = 'ecg_db' 
  AND REFERENCED_TABLE_NAME IS NOT NULL
ORDER BY TABLE_NAME;
```

Expected foreign keys:
- `ecg_images` → `patients.id`, `users.id`
- `tasks` → `patients.id`, `users.id` (3 times: technician, doctor, assigned_by)
- `task_history` → `tasks.id`, `users.id`
- `duty_roster` → `users.id` (2 times: doctor, created_by)

## 🧪 Step 7: Test Upload API

Test the technician upload endpoint:

```powershell
# Create a test image file (or use an existing one)
$testImage = "d:\Machine Learning\ECG - Copy\assets\images\test_ecg.jpg"

# Test using curl (if installed)
curl -X POST http://10.151.102.45/ecg_new/api/upload_ecg.php `
  -F "technician_id=3" `
  -F "patient_name=Test Patient" `
  -F "patient_age=45" `
  -F "patient_gender=male" `
  -F "notes=Test upload" `
  -F "priority=normal" `
  -F "images[]=@$testImage"
```

Expected response:
```json
{
  "success": true,
  "task_id": 1,
  "patient_id": "PAT20251017001",
  "images_uploaded": 1
}
```

## 🔧 Troubleshooting

### MySQL Command Not Found

**Solution 1: Use full path**
```powershell
& "C:\xampp\mysql\bin\mysql.exe" -u root -p ecg_db < create_tasks_schema.sql
```

**Solution 2: Add to PATH for this session**
```powershell
$env:Path += ";C:\xampp\mysql\bin"
mysql --version  # Test
```

### Foreign Key Constraint Errors

**Cause**: Users table has wrong ID type (VARCHAR instead of INT UNSIGNED)

**Solution**: Run `convert_users_to_int.sql` first

### Upload Directory Permission Denied

**Windows + Apache/XAMPP**:
```powershell
icacls "d:\Machine Learning\ECG - Copy\server\uploads\ecg_images" /grant "IUSR:F"
icacls "d:\Machine Learning\ECG - Copy\server\uploads\ecg_images" /grant "IIS_IUSRS:F"
```

**Windows + IIS**:
```powershell
icacls "d:\Machine Learning\ECG - Copy\server\uploads\ecg_images" /grant "IIS_IUSRS:(OI)(CI)F"
```

### Patient ID Generation Fails

Check the SQL function in `upload_ecg.php`:
- Verify date format: `YYYYMMDD`
- Check for existing patient IDs for today

### No Duty Doctors Available

**Problem**: Admin can't assign tasks because no doctors are on duty

**Solution**:
```sql
-- Add doctor to today's roster
INSERT INTO duty_roster (doctor_id, duty_date, shift, created_by)
SELECT id, CURDATE(), 'full_day', 1 
FROM users WHERE role='doctor' LIMIT 1;
```

## 📝 Summary of Changes

### New Tables
1. **patients** - Patient information with auto-generated IDs
2. **ecg_images** - Stores uploaded ECG image file paths
3. **tasks** - Task workflow (pending → assigned → in_progress → completed)
4. **task_history** - Audit trail of status changes
5. **duty_roster** - Doctor scheduling

### Old Tables
- **reports** - No longer used (replaced by patients + tasks)
- **users** - Must have `INT UNSIGNED` id (may need conversion)

### Workflow
1. **Technician** uploads ECG → creates task (pending)
2. **Admin** assigns task to duty doctor
3. **Doctor** reviews and provides feedback
4. **Technician** views feedback

## 🎯 Next Steps After Migration

1. Test technician upload from Flutter app
2. Test admin assignment workflow
3. Test doctor feedback workflow
4. Create duty roster management UI
5. Add more doctors to duty roster

## 📞 Quick Reference

**File Locations:**
- Schema: `server/create_tasks_schema.sql`
- Uploads: `server/uploads/ecg_images/`
- APIs: `server/api/`

**Database:**
- Name: `ecg_db`
- User: `root`
- Tables: users, patients, ecg_images, tasks, task_history, duty_roster

**Test Credentials** (if using defaults):
- Admin: admin@test.com / admin123
- Doctor: doctor@test.com / doctor123
- Technician: tech@test.com / tech123
