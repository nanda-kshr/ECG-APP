# Task Assignment System - Implementation Guide

## Overview
This system allows admins to assign ECG report review tasks to doctors. Doctors can view their assigned tasks, provide feedback, and mark them as complete. Technicians can see the feedback on their submitted reports.

## Database Setup

### 1. Run the SQL schema
Execute the SQL file to create the required tables:

```powershell
# From PowerShell (adjust path if needed)
mysql -u root -p ecg_db < "d:\Machine Learning\ECG - Copy\server\create_tasks_schema.sql"

# Or using XAMPP's mysql
& 'C:\xampp\mysql\bin\mysql.exe' -u root -p ecg_db < "d:\Machine Learning\ECG - Copy\server\create_tasks_schema.sql"
```

This creates:
- `tasks` table: stores task assignments
- `task_history` table: audit trail for status changes

### 2. Verify tables were created
```sql
USE ecg_db;
SHOW TABLES;
DESCRIBE tasks;
DESCRIBE task_history;
```

## API Endpoints Created

All endpoints are in `server/api/`:

### 1. `assign_task.php`
- **Purpose**: Admin assigns a report to a doctor
- **Method**: POST
- **Body**:
  ```json
  {
    "report_id": "rep-1",
    "doctor_id": 2,
    "assigned_by": 1,
    "notes": "Please review urgently",
    "priority": "high"
  }
  ```
- **Response**:
  ```json
  {
    "success": true,
    "task_id": 123
  }
  ```

### 2. `list_tasks.php`
- **Purpose**: List tasks with filters
- **Method**: GET
- **Query params**:
  - `status`: pending|assigned|in_progress|completed|cancelled
  - `doctor_id`: filter by assigned doctor
  - `technician_id`: filter by technician
  - `limit`: max results (default 50)
  - `offset`: pagination offset
- **Example**: `http://10.151.102.45/ecg_new/list_tasks.php?status=assigned&doctor_id=2`
- **Response**:
  ```json
  {
    "success": true,
    "tasks": [...],
    "count": 10
  }
  ```

### 3. `update_task.php`
- **Purpose**: Doctor updates task status and submits feedback
- **Method**: POST
- **Body**:
  ```json
  {
    "task_id": 123,
    "user_id": 2,
    "status": "completed",
    "feedback": "ECG shows normal sinus rhythm. No abnormalities detected."
  }
  ```
- **Response**:
  ```json
  {
    "success": true,
    "message": "Opinion updated"
  }
  ```

## Flutter UI Screens Created

### Admin Screens

1. **AssignTaskScreen** (`lib/screens/assign_task_screen.dart`)
   - Form to assign a task to a doctor
   - Fields: report ID, doctor selection, priority, notes
   - Accessible from admin dashboard

2. **TaskListScreen** (`lib/screens/task_list_screen.dart`)
   - Lists tasks filtered by status
   - Shows pending, assigned, completed tasks
   - Clickable list items navigate to detail screen

3. **TaskDetailScreen** (`lib/screens/task_detail_screen.dart`)
   - Full task details with all information
   - Shows doctor feedback
   - Admin/doctor can update status

### Admin Dashboard Integration
The admin dashboard now includes:
- "Assign Task" button
- "Pending Tasks" button
- "Assigned Tasks" button
- "Completed Tasks" button
- "All Tasks" button

## Models & Services Created

### Models
- `Task` (`lib/models/task.dart`): represents a task assignment

### Services
- `TaskService` (`lib/services/task_service.dart`): API client for task operations

## Testing the System

### 1. Create test data
First, ensure you have:
- An admin user (id=1)
- A doctor user (id=2)
- A technician user (id=3)
- A report (id='rep-1')

You can use the `server/seed_setup.php` to create these if needed.

### 2. Test API endpoints manually
```powershell
# Test assign task
curl -X POST http://10.151.102.45/ecg_new/assign_task.php `
  -H "Content-Type: application/json" `
  -d '{\"report_id\":\"rep-1\",\"doctor_id\":2,\"assigned_by\":1,\"notes\":\"Test task\",\"priority\":\"normal\"}'

# Test list tasks
curl http://10.151.102.45/ecg_new/list_tasks.php?status=assigned

# Test update task
curl -X POST http://10.151.102.45/ecg_new/update_task.php `
  -H "Content-Type: application/json" `
  -d '{\"task_id\":1,\"user_id\":2,\"status\":\"completed\",\"feedback\":\"Normal ECG\"}'
```

### 3. Test in Flutter app
1. Run the app: `flutter run -d chrome`
2. Login as admin
3. Navigate to admin dashboard
4. Click "Assign Task"
5. Fill form and submit
6. Check "Assigned Tasks" to see the task
7. Click on a task to view details

### 4. Test as doctor
1. Login as doctor
2. The doctor dashboard should show assigned tasks (you'll need to add this screen - see below)
3. Click on a task to view and provide feedback
4. Mark as "In Progress" or "Complete"

## Next Steps / TODO

### For Doctor Dashboard
Create a doctor-specific dashboard similar to admin:

```dart
// lib/screens/doctor_dashboard.dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => TaskListScreen(
      title: 'My Assigned Tasks',
      doctorId: currentUser.id, // pass doctor's ID as filter
    ),
  ),
);
```

### For Technician Dashboard
Show tasks related to technician's reports:

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => TaskListScreen(
      title: 'My Reports - Task Status',
      technicianId: currentUser.id,
    ),
  ),
);
```

### Fetch Doctors List Dynamically
Update `AssignTaskScreen` to fetch doctors from API:

Create `server/api/list_users.php`:
```php
// GET /list_users.php?role=doctor
// Returns list of users filtered by role
```

## Status Flow

```
pending → assigned → in_progress → completed
                  ↓
              cancelled
```

## Security Notes

1. **Authorization**: All APIs verify user roles before allowing actions
2. **Admin only**: Only admins can assign tasks
3. **Doctor/Admin**: Only assigned doctor or admin can update task
4. **Transactions**: Database operations use transactions for consistency
5. **Audit trail**: All status changes logged in `task_history` table

## Troubleshooting

### Foreign key constraint errors
If you get FK errors when creating tasks table:
- Ensure `reports` table exists with `id` column
- Ensure `users` table exists with `id` column
- Match data types exactly (INT UNSIGNED for all FK columns)

### API returns 500
- Check Apache error logs
- Enable debug mode: set `DEBUG=1` environment variable
- Check `server/api/db.php` for DB connection issues

### Tasks not showing in UI
- Check browser console for errors
- Verify API URL in `lib/services/task_service.dart`
- Test API endpoint directly with curl

## File Summary

### New Files Created
- `server/create_tasks_schema.sql` - Database schema
- `server/api/assign_task.php` - Assign task endpoint
- `server/api/list_tasks.php` - List tasks endpoint
- `server/api/update_task.php` - Update task endpoint
- `lib/models/task.dart` - Task model
- `lib/services/task_service.dart` - Task API service
- `lib/screens/assign_task_screen.dart` - Assign task UI
- `lib/screens/task_list_screen.dart` - Task list UI
- `lib/screens/task_detail_screen.dart` - Task detail UI

### Modified Files
- `lib/screens/admin_dashboard.dart` - Added task management buttons

## Support

If you encounter issues:
1. Check that all tables exist and have correct structure
2. Verify API endpoints are accessible
3. Check browser console for client errors
4. Check Apache/PHP error logs for server errors
5. Ensure CORS headers are present in API responses
