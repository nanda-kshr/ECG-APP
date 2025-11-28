# Duty Doctor Management - Setup Guide

## Overview
Admin can now manage doctors directly from the Flutter app with a dedicated Duty Doctor tab that includes:
- Searchable, paginated list of all doctors
- Current duty status display
- "+" button to add new doctors
- Assign duty doctor functionality

## Backend Setup

### 1. Run Database Migration
Add the required columns to your existing database:

```powershell
# PowerShell (Windows)
& "C:\xampp\mysql\bin\mysql.exe" -u root -p ecg_db < "d:\Machine Learning\ECG - 31.10.25\server\alter_schema_for_assignment.sql"
```

This adds:
- `users.is_duty` (TINYINT) - Flag for current duty doctor
- `users.department` (VARCHAR) - Optional department field
- `patients.assigned_doctor_id` (INT) - Doctor assignment
- `patients.status` (ENUM) - Patient status tracking

### 2. API Endpoints Created

#### List Doctors
- **Endpoint**: `GET /api/list_doctors.php`
- **Parameters**: 
  - `search` (optional) - Search by name or email
  - `limit` (default: 50) - Results per page
  - `offset` (default: 0) - Pagination offset
- **Returns**: List of doctors with duty status

#### Add Doctor
- **Endpoint**: `POST /api/add_doctor.php`
- **Body** (JSON):
  ```json
  {
    "admin_id": 1,
    "name": "Dr. John Doe",
    "email": "john.doe@hospital.com",
    "password": "securePassword123",
    "department": "Cardiology"
  }
  ```
- **Features**:
  - Email validation and duplicate check
  - Secure password hashing (bcrypt)
  - Role automatically set to 'doctor'

#### Set Duty Doctor
- **Endpoint**: `POST /api/set_duty_doctor.php`
- **Body** (JSON):
  ```json
  {
    "admin_id": 1,
    "doctor_id": 2
  }
  ```
- **Behavior**: Clears all doctor duty flags, sets selected doctor as on-duty

## Flutter Implementation

### Files Created/Modified

#### New Files:
1. **lib/models/doctor.dart** - Doctor model with duty status
2. **lib/services/doctor_service.dart** - API service for doctor operations
3. **lib/screens/duty_doctor_tab.dart** - Main doctor list with search
4. **lib/screens/add_doctor_screen.dart** - Add new doctor form

#### Modified Files:
1. **lib/screens/admin_dashboard.dart** - Added Duty Doctor navigation

### Features

#### Duty Doctor Tab
- ✓ Searchable doctor list (by name/email)
- ✓ Real-time duty status display
- ✓ Color-coded badges (Green = On Duty, Grey = Off Duty)
- ✓ Department display (if available)
- ✓ "Set Duty" button for each doctor
- ✓ Floating "+" button to add new doctors

#### Add Doctor Screen
- ✓ Form validation (name, email, password)
- ✓ Email format validation
- ✓ Password strength check (min 6 chars)
- ✓ Optional department field
- ✓ Duplicate email detection
- ✓ Auto-role assignment (doctor)

## Usage Flow

### Admin Workflow

1. **View Doctors**
   - Open Admin Dashboard
   - Tap "Duty Doctors" in bottom navigation
   - View searchable list of all doctors

2. **Add New Doctor**
   - Tap the "+" floating button
   - Fill in doctor details:
     - Name (required)
     - Email (required, must be unique)
     - Password (required, min 6 chars)
     - Department (optional)
   - Submit form
   - Doctor account created immediately

3. **Set Duty Doctor**
   - Find the doctor in the list
   - Tap "Set Duty" button
   - Confirm action
   - Doctor marked as current duty doctor
   - New ECG uploads will auto-assign to this doctor

### Doctor Login
After creation, doctors can:
- Login using email & password (existing login screen)
- Access assigned ECG tasks
- View patient records
- Submit feedback

## Testing

### Test Backend Endpoints

#### List Doctors:
```powershell
curl "http://YOUR_SERVER/ecg_new/api/list_doctors.php?search=john"
```

#### Add Doctor:
```powershell
curl -X POST http://YOUR_SERVER/ecg_new/api/add_doctor.php `
  -H "Content-Type: application/json" `
  -d '{ "admin_id": 1, "name": "Dr. Jane Smith", "email": "jane.smith@hospital.com", "password": "password123", "department": "Emergency" }'
```

#### Set Duty Doctor:
```powershell
curl -X POST http://YOUR_SERVER/ecg_new/api/set_duty_doctor.php `
  -H "Content-Type: application/json" `
  -d '{ "admin_id": 1, "doctor_id": 2 }'
```

### Test Flutter App

1. **Login as Admin**
   - Email: admin@ecg.com
   - Password: password123

2. **Navigate to Duty Doctors**
   - Tap "Duty Doctors" in bottom nav

3. **Add Test Doctor**
   - Tap "+" button
   - Fill: 
     - Name: Dr. Test User
     - Email: test.doctor@hospital.com
     - Password: test123456
     - Department: Test Department
   - Submit

4. **Set Duty**
   - Find newly created doctor
   - Tap "Set Duty"
   - Confirm

5. **Verify Auto-Assignment**
   - Login as technician
   - Upload new ECG
   - Verify it auto-assigns to duty doctor

## Security Notes

- ✅ Passwords hashed using PHP `password_hash()` (bcrypt)
- ✅ Admin-only endpoints (role validation)
- ✅ Email uniqueness enforced
- ✅ Input validation on backend
- ✅ SQL injection protection (prepared statements)

## Future Enhancements

- [ ] Edit doctor details
- [ ] Deactivate/archive doctors
- [ ] Bulk duty roster assignment
- [ ] Shift scheduling (morning/afternoon/night)
- [ ] Doctor activity logs
- [ ] Department-based filtering
- [ ] Doctor availability calendar

## Troubleshooting

### "Email already exists"
- Check if doctor already registered
- Use different email address

### "Only admins can add doctors"
- Verify logged-in user has admin role
- Check `admin_id` parameter

### Duty status not showing
- Run database migration script
- Verify `users.is_duty` column exists
- Check `duty_roster` table created

### New doctor can't login
- Verify doctor added to `users` table
- Check password was set (not NULL)
- Ensure `role = 'doctor'`

## API Documentation Summary

| Endpoint | Method | Auth | Description |
|----------|--------|------|-------------|
| `/api/list_doctors.php` | GET | None | List all doctors with search |
| `/api/add_doctor.php` | POST | Admin | Create new doctor account |
| `/api/set_duty_doctor.php` | POST | Admin | Set current duty doctor |

---

**Last Updated**: November 4, 2025  
**Version**: 1.0  
**Schema Version**: 2.1 (with duty management)
