# Updated Task Assignment System - Technician-Initiated Workflow

## 🔄 Workflow Overview

**Corrected Flow:**
1. **Technician** uploads ECG images with patient info → creates task (status: pending)
2. **Admin** views pending tasks and assigns to a duty doctor
3. **Doctor** reviews ECG and provides feedback → marks complete
4. **Technician** views feedback on their submissions

## 📊 Database Schema Updates

### New Tables Created

#### 1. **patients** Table
```sql
CREATE TABLE patients (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  patient_id VARCHAR(50) UNIQUE NOT NULL,  -- Auto: PAT20251017001
  name VARCHAR(255) NOT NULL,
  age INT UNSIGNED NULL,
  gender ENUM('male', 'female', 'other') NULL,
  contact VARCHAR(50) NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### 2. **ecg_images** Table
```sql
CREATE TABLE ecg_images (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  patient_id INT UNSIGNED NOT NULL,
  technician_id INT UNSIGNED NOT NULL,
  image_path VARCHAR(500) NOT NULL,
  image_name VARCHAR(255) NOT NULL,
  file_size INT UNSIGNED NULL,
  mime_type VARCHAR(100) NULL,
  uploaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (patient_id) REFERENCES patients(id),
  FOREIGN KEY (technician_id) REFERENCES users(id)
);
```

#### 3. **tasks** Table (Updated)
```sql
CREATE TABLE tasks (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  patient_id INT UNSIGNED NOT NULL,  -- Changed from report_id
  technician_id INT UNSIGNED NOT NULL,
  assigned_doctor_id INT UNSIGNED NULL,
  assigned_by INT UNSIGNED NULL,
  status ENUM('pending', 'assigned', 'in_progress', 'completed', 'cancelled'),
  priority ENUM('low', 'normal', 'high', 'urgent'),
  technician_notes TEXT NULL,  -- Notes from technician
  admin_notes TEXT NULL,       -- Notes from admin when assigning
  doctor_feedback TEXT NULL,
  assigned_at TIMESTAMP NULL,
  completed_at TIMESTAMP NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (patient_id) REFERENCES patients(id),
  FOREIGN KEY (technician_id) REFERENCES users(id),
  FOREIGN KEY (assigned_doctor_id) REFERENCES users(id)
);
```

#### 4. **duty_roster** Table
```sql
CREATE TABLE duty_roster (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  doctor_id INT UNSIGNED NOT NULL,
  duty_date DATE NOT NULL,
  shift ENUM('morning', 'afternoon', 'evening', 'night', 'full_day'),
  is_active BOOLEAN DEFAULT TRUE,
  created_by INT UNSIGNED NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY unique_doctor_date_shift (doctor_id, duty_date, shift),
  FOREIGN KEY (doctor_id) REFERENCES users(id)
);
```

## 🔌 API Endpoints

### New Endpoints

#### 1. `upload_ecg.php` - Technician Upload
**Method:** POST (multipart/form-data)

**Fields:**
- `technician_id`: int
- `patient_name`: string
- `patient_age`: int (optional)
- `patient_gender`: male|female|other
- `notes`: string (optional)
- `priority`: low|normal|high|urgent
- `images[]`: files (multiple)

**Response:**
```json
{
  "success": true,
  "task_id": 123,
  "patient_id": "PAT20251017001",
  "images_uploaded": 3
}
```

**Features:**
- Auto-generates patient ID (format: PAT{YYYYMMDD}{sequential})
- Uploads multiple images to `server/uploads/ecg_images/`
- Creates task with status 'pending'
- Validates technician role

#### 2. `get_duty_doctors.php` - Get Duty Roster
**Method:** GET

**Query Params:**
- `date`: YYYY-MM-DD (default: today)
- `shift`: morning|afternoon|evening|night|full_day (optional)

**Response:**
```json
{
  "success": true,
  "doctors": [
    {
      "id": 2,
      "name": "Dr. Smith",
      "email": "doctor@example.com",
      "shift": "full_day",
      "duty_date": "2025-10-17"
    }
  ],
  "count": 1
}
```

### Updated Endpoints

#### `list_tasks.php` - Updated
- Now joins with `patients` table instead of `reports`
- Returns `patient_name`, `patient_id_str`, `patient_age`
- Returns `technician_notes` and `admin_notes` separately

#### `assign_task.php` - Updated
- Now accepts `task_id` instead of creating new task
- Updates existing pending task to assign doctor
- Validates task is in 'pending' status before assigning

## 📱 Flutter UI Components

### Technician Screens

#### 1. **TechnicianUploadScreen**
**File:** `lib/screens/technician_upload_screen.dart`

**Features:**
- Patient information form (name, age, gender)
- Auto patient ID generation
- Multiple ECG image upload (file picker for web)
- Priority selection
- Technician notes field
- Upload progress indicator

**Key Functions:**
- `_pickImages()`: Opens file picker for multiple images
- `_uploadECG()`: Submits multipart form to server

#### 2. **TechnicianDashboard** (To be updated)
**File:** `lib/screens/technician_dashboard.dart`

**Features Required:**
- "Upload New ECG" button
- Statistics cards:
  - Total Submitted
  - Pending Review
  - Under Review
  - Completed
  - Feedback Received
- List of technician's submissions
- Click to view feedback

### Admin Screens Updates

#### **AssignTaskScreen** (Needs update)
Should be updated to:
1. List pending tasks (not ask for report ID)
2. Fetch duty doctors for today
3. Show patient info for the task
4. Assign to selected duty doctor

## 📋 Setup Instructions

### 1. Drop and Recreate Schema
Since the schema changed significantly:

```powershell
# Backup existing data first!
mysqldump -u root -p ecg_db > backup.sql

# Drop old task tables
mysql -u root -p -e "USE ecg_db; DROP TABLE IF EXISTS task_history, tasks;"

# Run new schema
mysql -u root -p ecg_db < "d:\Machine Learning\ECG - Copy\server\create_tasks_schema.sql"
```

### 2. Create Uploads Directory
```powershell
New-Item -ItemType Directory -Path "d:\Machine Learning\ECG - Copy\server\uploads\ecg_images" -Force
```

Make sure Apache/PHP has write permissions to this directory.

### 3. Add Duty Roster Entries (Test Data)
```sql
-- Add a doctor on duty for today
INSERT INTO duty_roster (doctor_id, duty_date, shift, created_by)
VALUES (2, CURDATE(), 'full_day', 1);

-- Add for tomorrow
INSERT INTO duty_roster (doctor_id, duty_date, shift, created_by)
VALUES (2, DATE_ADD(CURDATE(), INTERVAL 1 DAY), 'full_day', 1);
```

### 4. Update pubspec.yaml (if needed)
Add file picker dependency:

```yaml
dependencies:
  file_picker: ^6.1.1
```

Run:
```powershell
flutter pub get
```

## 🧪 Testing the New Workflow

### Test Sequence:

1. **As Technician:**
   ```
   - Login as technician
   - Click "Upload New ECG"
   - Fill patient info: Name, Age, Gender
   - Select multiple ECG images
   - Set priority
   - Add notes
   - Click "Upload & Submit"
   - Note the Task ID and Patient ID returned
   ```

2. **As Admin:**
   ```
   - Login as admin
   - Go to "Pending Tasks"
   - See the task created by technician
   - Click on task
   - Assign to duty doctor (fetched from roster)
   - Add admin notes
   - Submit assignment
   ```

3. **As Doctor:**
   ```
   - Login as doctor
   - View "My Assigned Tasks"
   - Click on task
   - View patient info and ECG images
   - Add feedback/diagnosis
   - Mark as "In Progress" or "Completed"
   ```

4. **As Technician (verify feedback):**
   ```
   - Go back to technician dashboard
   - See updated status
   - Click on completed task
   - View doctor's feedback
   ```

## 🔧 Pending Implementation Tasks

### High Priority:
1. ✅ Database schema created
2. ✅ upload_ecg.php API created
3. ✅ get_duty_doctors.php API created
4. ✅ TechnicianUploadScreen created
5. ⏳ Update TechnicianDashboard (replace old implementation)
6. ⏳ Update AssignTaskScreen to:
   - List pending tasks instead of asking for report ID
   - Fetch and show duty doctors
   - Display patient info
7. ⏳ Update TaskDetailScreen to show ECG images
8. ⏳ Create API to fetch images for a patient

### Medium Priority:
9. Create DutyRosterManagementScreen for admin
10. Create API endpoints for roster management
11. Add image viewer in TaskDetailScreen
12. Add filters/search in technician dashboard

### Low Priority:
13. Add notifications when feedback is received
14. Export/print functionality for reports
15. Statistics/analytics dashboard

## 🐛 Troubleshooting

### Image Upload Fails
- Check `server/uploads/ecg_images/` directory exists
- Check Apache/PHP write permissions
- Check max upload size in `php.ini`:
  ```ini
  upload_max_filesize = 10M
  post_max_size = 10M
  ```

### No Duty Doctors Showing
- Verify duty_roster table has entries
- Check date format is correct (YYYY-MM-DD)
- Verify doctor role is set correctly in users table

### Task Creation Fails
- Check all foreign keys (patient_id, technician_id)
- Verify patients table exists and is accessible
- Check technician_id matches logged-in user

## 📄 File Reference

### Created Files:
- `server/create_tasks_schema.sql` (updated)
- `server/api/upload_ecg.php` (new)
- `server/api/get_duty_doctors.php` (new)
- `lib/screens/technician_upload_screen.dart` (new)

### Modified Files:
- `server/api/list_tasks.php` (updated for new schema)
- `server/api/assign_task.php` (updated workflow)
- `lib/models/task.dart` (updated fields)

### Need to Modify:
- `lib/screens/technician_dashboard.dart` (update implementation)
- `lib/screens/assign_task_screen.dart` (update workflow)
- `lib/screens/task_detail_screen.dart` (add image viewer)

## 🎯 Next Steps

1. **Run the new schema SQL**
2. **Test technician upload** (use curl or Postman first)
3. **Update technician dashboard** to use new task service
4. **Update assign task screen** to fetch pending tasks
5. **Test full workflow** end-to-end

The system is now properly designed for the technician-initiated workflow!
