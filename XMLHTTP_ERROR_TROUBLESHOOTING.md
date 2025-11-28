# Duty Doctor XMLHttpRequest Error - Troubleshooting Guide

## Common Causes & Solutions

### 1. CORS (Cross-Origin Resource Sharing) Error ⚠️ MOST COMMON

**Symptoms:**
- Error in browser console: "Access to XMLHttpRequest at '...' from origin '...' has been blocked by CORS policy"
- Network tab shows request status as "(failed)" or "CORS error"

**Solution:**

The PHP files already have CORS headers, but verify they're at the TOP of the file:

```php
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Origin, Content-Type, Authorization, X-Requested-With, Accept');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS, PUT, DELETE');
```

**Quick Fix:** Check if your server is sending these headers:

```powershell
# Test with curl (add -v for verbose)
curl -v "http://172.25.91.15/ecg_new/api/list_doctors.php"
```

Look for these response headers:
```
< Access-Control-Allow-Origin: *
< Access-Control-Allow-Methods: GET, POST, OPTIONS, PUT, DELETE
```

---

### 2. Server Not Running

**Symptoms:**
- Error: "Failed to connect" or "Network error"
- XMLHttpRequest error with no response

**Solution:**

Check if Apache/XAMPP is running:

```powershell
# Check if Apache is listening on port 80
netstat -an | findstr ":80"
```

Should show:
```
TCP    0.0.0.0:80    0.0.0.0:0    LISTENING
```

Start XAMPP if needed:
- Open XAMPP Control Panel
- Click "Start" for Apache module

---

### 3. Wrong API URL

**Symptoms:**
- 404 Not Found error
- "The requested URL was not found on this server"

**Current Configuration:**
- API Base: `http://172.25.91.15/ecg_new/api/`
- Endpoint: `list_doctors.php`
- Full URL: `http://172.25.91.15/ecg_new/api/list_doctors.php`

**Verify:**

```powershell
# Test the exact URL
curl "http://172.25.91.15/ecg_new/api/list_doctors.php"
```

**Expected Response:**
```json
{
  "success": true,
  "doctors": [...],
  "total": 5,
  "count": 5
}
```

**If 404 Error:**
1. Check file exists: `d:\Machine Learning\ECG - 31.10.25\server\api\api\list_doctors.php`
2. Verify XAMPP document root points to your project
3. Check Apache virtual host configuration

---

### 4. PHP Error in Endpoint

**Symptoms:**
- 500 Internal Server Error
- Blank response
- HTML error page instead of JSON

**Debug:**

Enable error display in the PHP file (temporarily):

```php
<?php
// Add at the top of list_doctors.php for debugging
error_reporting(E_ALL);
ini_set('display_errors', 1);
```

Or check Apache error log:
```
C:\xampp\apache\logs\error.log
```

---

### 5. Database Connection Issues

**Symptoms:**
- Error: "DB connection failed"
- Error: "Table 'users' doesn't exist"

**Solution:**

Run the migration script:

```powershell
& "C:\xampp\mysql\bin\mysql.exe" -u root -p ecg_db < "d:\Machine Learning\ECG - 31.10.25\server\alter_schema_for_assignment.sql"
```

Test database connection:

```powershell
& "C:\xampp\mysql\bin\mysql.exe" -u root -p -e "USE ecg_db; SELECT COUNT(*) FROM users WHERE role='doctor';"
```

---

## Step-by-Step Debugging

### Step 1: Test Endpoint Directly

Open browser and navigate to:
```
http://172.25.91.15/ecg_new/api/list_doctors.php
```

**Expected:** JSON response with doctors
**If error:** Note the exact error message

### Step 2: Check Browser Console

1. Open Chrome DevTools (F12)
2. Go to "Console" tab
3. Go to "Network" tab
4. Navigate to Duty Doctors page
5. Look for red errors

**Look for:**
- CORS errors (red text about "blocked by CORS policy")
- 404 errors (wrong URL)
- 500 errors (server/PHP error)
- Network timeout (server not responding)

### Step 3: Check Network Tab

In Chrome DevTools Network tab:
1. Find the `list_doctors.php` request
2. Click on it
3. Check:
   - **Status**: Should be 200
   - **Response**: Should be JSON
   - **Headers**: Should include CORS headers

### Step 4: Test with Flutter Debug Console

The updated code now logs to console. Look for:

```
DoctorService: Fetching from http://172.25.91.15/ecg_new/api/list_doctors.php
DoctorService: Response status 200
DoctorService: Response body: {"success":true,"doctors":[...]...
```

Or error messages:
```
DoctorService: Exception - SocketException: Failed host lookup
DoctorService: Exception - TimeoutException after 10 seconds
```

---

## Quick Fixes

### Fix 1: Force CORS Headers

Add to `.htaccess` in `/ecg_new/api/`:

```apache
Header set Access-Control-Allow-Origin "*"
Header set Access-Control-Allow-Methods "GET, POST, OPTIONS, PUT, DELETE"
Header set Access-Control-Allow-Headers "Origin, Content-Type, Authorization, X-Requested-With, Accept"
```

### Fix 2: Update API URL

If server IP changed, update `lib/config.dart`:

```dart
const String kApiBaseUrl = 'http://YOUR_NEW_IP/ecg_new/api/';
```

Then restart Flutter app:
```powershell
flutter run -d chrome
```

### Fix 3: Bypass CORS (Development Only)

Run Chrome with CORS disabled (ONLY FOR TESTING):

```powershell
# Close all Chrome windows first, then:
"C:\Program Files\Google\Chrome\Application\chrome.exe" --disable-web-security --user-data-dir="C:\temp\chrome_dev"
```

Then run Flutter:
```powershell
flutter run -d chrome
```

---

## Verify Solution

After applying fixes:

1. ✅ Can access `http://172.25.91.15/ecg_new/api/list_doctors.php` in browser
2. ✅ Returns valid JSON (not HTML error page)
3. ✅ Flutter console shows "DoctorService: Response status 200"
4. ✅ Doctor list appears in app with no errors

---

## Still Having Issues?

**Collect this information:**

1. **Browser Console Error** (exact text)
2. **Network Tab Response** (screenshot or copy)
3. **Flutter Console Output** (the debug logs)
4. **Apache Error Log** (last 20 lines)
5. **cURL Test Result**:
   ```powershell
   curl "http://172.25.91.15/ecg_new/api/list_doctors.php"
   ```

Share these for further debugging.

---

## Common Error Messages Decoded

| Error | Meaning | Solution |
|-------|---------|----------|
| "blocked by CORS policy" | Server not sending CORS headers | Check PHP headers |
| "ERR_CONNECTION_REFUSED" | Server not running | Start Apache |
| "ERR_NAME_NOT_RESOLVED" | Wrong IP/hostname | Check config.dart |
| "404 Not Found" | Wrong URL or file missing | Check file path |
| "500 Internal Server Error" | PHP error | Check error logs |
| "TimeoutException" | Server too slow/not responding | Check network |
| "SocketException" | Network/firewall issue | Check firewall |

---

**Last Updated**: November 4, 2025  
**For**: Duty Doctor Management System
