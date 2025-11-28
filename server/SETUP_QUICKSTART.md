# Quick Setup Reference Card

## 🚀 ONE-COMMAND SETUP (Recommended)

```powershell
cd "d:\Machine Learning\ECG - Copy\server"
.\setup.ps1
```

This will:
- ✓ Find MySQL automatically
- ✓ Drop old tables
- ✓ Create fresh tables with correct structure
- ✓ Create test users
- ✓ Create duty roster for next 7 days
- ✓ Create uploads directory

---

## 📋 Manual Setup (Alternative)

### Option 1: Using MySQL Command Line

```powershell
# Navigate to server directory
cd "d:\Machine Learning\ECG - Copy\server"

# Run fresh setup (replace path if MySQL is elsewhere)
& "C:\xampp\mysql\bin\mysql.exe" -u root -p ecg_db < fresh_setup.sql
```

### Option 2: Using MySQL Workbench

1. Open MySQL Workbench
2. Connect to your server
3. File → Open SQL Script → Select `fresh_setup.sql`
4. Execute (lightning bolt icon)

---

## 👥 Test Credentials

After setup, you'll have these test users:

| Role       | Email              | Password    | ID |
|------------|-------------------|-------------|-----|
| Admin      | admin@ecg.com     | password123 | 1   |
| Doctor     | doctor1@ecg.com   | password123 | 2   |
| Doctor     | doctor2@ecg.com   | password123 | 3   |
| Technician | tech1@ecg.com     | password123 | 4   |
| Technician | tech2@ecg.com     | password123 | 5   |

---

## 📊 Database Structure

### Tables Created:
1. **users** - User accounts (INT UNSIGNED id) ✓
2. **patients** - Patient information
3. **ecg_images** - Uploaded ECG image files
4. **tasks** - Task workflow tracking
5. **task_history** - Audit trail
6. **duty_roster** - Doctor scheduling

### OLD Tables Removed:
- ❌ reports (replaced by patients + tasks)
- ❌ old users with VARCHAR(36) (if existed)

---

## 📅 Sample Duty Roster

The setup creates doctor schedules for the next 7 days:

- **Today**: Dr. Sarah Johnson (morning), Dr. Michael Chen (afternoon)
- **Tomorrow**: Dr. Sarah Johnson (full day)
- **Day 3**: Dr. Michael Chen (full day)
- **Etc...**

---

## 🧪 Testing Workflow

### 1. Test Technician Upload
```
Login: tech1@ecg.com / password123
→ Upload New ECG
→ Fill patient info
→ Select images
→ Submit
```

### 2. Test Admin Assignment
```
Login: admin@ecg.com / password123
→ View Pending Tasks
→ Select task
→ Assign to duty doctor
```

### 3. Test Doctor Review
```
Login: doctor1@ecg.com / password123
→ View Assigned Tasks
→ Select task
→ Add feedback
→ Mark complete
```

### 4. Verify Technician Sees Feedback
```
Login: tech1@ecg.com / password123
→ Dashboard
→ See "Feedback Received" count
→ Click task to view feedback
```

---

## 🔧 Troubleshooting

### "MySQL not found"
**Solution**: Edit `setup.ps1` and add your MySQL path:
```powershell
$mysqlPaths = @(
    "YOUR_MYSQL_PATH_HERE\mysql.exe",
    "C:\xampp\mysql\bin\mysql.exe"
)
```

### "Access Denied"
**Solution**: Check MySQL root password is correct

### "Uploads directory permission denied"
**Solution**: Grant permissions:
```powershell
icacls "d:\Machine Learning\ECG - Copy\server\uploads\ecg_images" /grant Everyone:F
```

### "Foreign key constraint fails"
**Solution**: Run `fresh_setup.sql` which drops ALL tables first, ensuring clean slate

---

## 📁 File Reference

| File | Purpose |
|------|---------|
| `fresh_setup.sql` | Complete setup script (recommended) |
| `setup.ps1` | PowerShell automation script |
| `preflight_check.sql` | Check existing database (optional) |
| `create_tasks_schema.sql` | Only creates new tables (no user drop) |
| `DATABASE_MIGRATION_GUIDE.md` | Full documentation |

---

## ✅ Verification Checklist

After running setup:

- [ ] MySQL command completed without errors
- [ ] Uploads directory created: `server/uploads/ecg_images/`
- [ ] Can login to Flutter app with test credentials
- [ ] Technician can access upload screen
- [ ] Admin can see pending tasks (will be empty initially)
- [ ] Doctor can see assigned tasks (will be empty initially)

---

## 🎯 What Changed From Old Schema

### Users Table
- **Before**: `id VARCHAR(36)` (UUID)
- **After**: `id INT UNSIGNED AUTO_INCREMENT` ✓

### Reports Table
- **Before**: Single table with patient_name, result
- **After**: Split into 3 tables:
  - `patients` (patient info)
  - `ecg_images` (file uploads)
  - `tasks` (workflow tracking)

### Workflow
- **Before**: Direct doctor-to-report assignment
- **After**: Technician → Admin → Doctor → Technician (full cycle)

---

## 🔗 API Endpoints Ready

After setup, these APIs are ready to use:

- ✓ `login.php` - User authentication
- ✓ `upload_ecg.php` - Technician uploads
- ✓ `list_tasks.php` - Get tasks (filtered by role)
- ✓ `assign_task.php` - Admin assigns to doctor
- ✓ `update_task.php` - Doctor adds feedback
- ✓ `get_duty_doctors.php` - Get on-duty doctors

---

## 📞 Need Help?

If you encounter issues:

1. Check error messages in MySQL output
2. Verify MySQL credentials
3. Ensure database `ecg_db` exists
4. Check file paths are correct
5. Review `DATABASE_MIGRATION_GUIDE.md` for detailed troubleshooting

---

**Last Updated**: October 17, 2025
**Schema Version**: 2.0 (Task Assignment System)
