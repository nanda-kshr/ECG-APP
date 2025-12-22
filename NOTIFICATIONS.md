# Push Notifications (FCM) - Duty Doctor Alerts

Goal: When a technician uploads an ECG, the duty doctor receives a push notification via Firebase Cloud Messaging (FCM).

Server-side changes (already implemented):
- Migration added: `api/migrations/001_add_fcm_token_to_users.sql` — adds `fcm_token` column to `users` table.
- `api/firebase.php` — helper to send notifications via legacy FCM HTTP endpoint.
- `api/register_fcm_token.php` — endpoint for authenticated clients to update the user's FCM device token.
- `api/login.php` — updated to accept optional `fcm_token` parameter during login and store it on successful auth.
- `api/upload_ecg.php` — after auto-assigning a duty doctor, fetches duty doctor's `fcm_token` and sends a notification (`title`: "New ECG uploaded").

Environment / configuration (manual steps):
1. Create a Firebase project (https://console.firebase.google.com).
2. In Project settings -> Cloud Messaging, obtain the **Server key** (legacy key) and set it in your server environment as `FIREBASE_SERVER_KEY` (e.g., in MAMP export or Apache env vars). Example for local testing:

   export FIREBASE_SERVER_KEY="AAAA...your_server_key..."

   (Alternatively, set `$_SERVER['FIREBASE_SERVER_KEY']` in your Apache config.)

3. Run the migration SQL against your database:

   mysql -u root -p ecg_app_db < api/migrations/001_add_fcm_token_to_users.sql

Client-side (Flutter) — high level instructions:

1. Add dependencies in `pubspec.yaml`:

   dependencies:
     firebase_core: ^2.10.0
     firebase_messaging: ^14.5.0

2. Follow Firebase setup for Android and iOS:
   - Android: add `google-services.json` to `android/app/`, add `com.google.gms:google-services` plugin in Gradle (see Firebase docs).
   - iOS: add `GoogleService-Info.plist` to Runner, enable push notifications and background modes.

3. Initialize Firebase in your app (usually in `main()`):

   await Firebase.initializeApp();
   FirebaseMessaging messaging = FirebaseMessaging.instance;

   // Request permissions (iOS)
   await messaging.requestPermission();

   // Get the FCM token
   String? token = await messaging.getToken();
   // Send token to server either during login or via `/register_fcm_token.php`
   - `lib/firebase_push.dart` — minimal Flutter example showing initialization, getting token, and registering it on the server.
   - `lib/services/push_service.dart` — service that initializes Firebase, listens for token refresh, and registers the token with the server.
   - `lib/services/auth_service.dart` and `lib/screens/login_screen.dart` — updated to include FCM token in the login request and register token after login; session cookie is captured to allow server-side `register_fcm_token.php` to be used.

4. Example: send token to server after login (pseudo-code):

   final res = await http.post(Uri.parse('$baseUrl/login.php'),
     headers: {'Content-Type': 'application/json'},
     body: jsonEncode({'email': email, 'password': pass, 'fcm_token': token})
   );

   // Or, if token refreshes later, call `/register_fcm_token.php` with session cookie and JSON body {fcm_token: token}

5. Handle foreground messages and taps using `FirebaseMessaging.onMessage` and `FirebaseMessaging.onMessageOpenedApp` to navigate the doctor to the assigned task.
  
App changes I made (what to look for in the running app):

- `lib/services/push_service.dart` — initializes Firebase, obtains token, listens for token refresh and notification events.
- `lib/main.dart` — initializes `PushService` early, and sets up listeners so notification taps navigate to the `TaskDetailScreen`.
- `lib/screens/login_screen.dart` — calls `PushService.ensureRegisteredAfterLogin()` after successful login to ensure the server receives token.
- `lib/screens/doctor_dashboard.dart` — displays a short snippet of the registered token (for QA) and adds a **Send test push** button to trigger `api/test_fcm.php` for convenience.

How to verify in the app:

1. Build and run the app on an Android or iOS device (emulators may have limitations for FCM).
2. Sign in as a doctor (e.g., `sathish@doc.com`). You should see a short token snippet in the Doctor Dashboard near the top.
3. Tap **Send test push** — you should receive a push notification on that same device (or see errors displayed as a SnackBar).
4. To test full flow: set a duty doctor with the token, then upload an ECG (via app or curl). The duty doctor should receive the notification, and tapping it will open the Task detail screen.

  Note: I wired the token flow into the app:
  - Added `firebase_core` and `firebase_messaging` to `pubspec.yaml`
  - Added `lib/services/push_service.dart` which initializes messaging, saves the token locally, listens for token refresh, and attempts to call `register_fcm_token.php` using the session cookie stored at login.
  - Updated `AuthService.login()` to include `fcm_token` in the login request (so server saves token on initial login) and to capture the session cookie so later token refresh registrations can use it.
  - Updated `LoginScreen` to call `PushService.ensureRegisteredAfterLogin()` immediately after a successful sign-in.

Notes & Caveats:
- This implementation uses the legacy FCM server key + endpoint for simplicity. For production or security-conscious deployments, consider moving to the FCM HTTP v1 API with OAuth and a service account.
- If the duty doctor does not have a stored `fcm_token`, no notification will be sent. Ensure doctors' devices register and send tokens.
- The server sends a minimal payload: notification (title/body) + data {task_id, patient_id, type}. The app should handle navigation when tapped.

If you want, I can:
- Add a small Flutter example file that shows how to initialize messaging and register token (I can create a small `lib/firebase_push.dart` example),
- Add automated database migration runner (simple PHP CLI script) to run migrations,
- Convert to FCM HTTP v1 flow (needs service account JSON and more setup).

Tell me which of the above you'd like me to do next (add Flutter example, add migration script, or switch to HTTP v1). If you prefer to do config steps manually, I can provide exact commands and files to add. ✅

Quick manual testing steps
1) Make sure `FIREBASE_SERVER_KEY` is set in your environment (or in Apache/PHP envvars) and the doctor device token is available.

2) Register a token for a doctor (example using login with token):

```bash
curl -X POST -H "Content-Type: application/json" \
   -c cookiejar.txt \
   -d '{"email":"sathish@doc.com","password":"<password>","fcm_token":"<doctor_device_token>"}' \
   "http://localhost/ecg_new/api/login.php"
```

3) Test sending a notification directly using `test_fcm.php`:

```bash
curl -X POST -H "Content-Type: application/json" -d '{"token":"<doctor_device_token>"}' http://localhost/ecg_new/api/test_fcm.php
```

4) Simulate an ECG upload (multipart form) using Postman or curl to `upload_ecg.php` to exercise the real path (this will create a patient, task and, if duty doctor exists and token is set, should send a push notification).

Quick verification: check that the duty doctor has a token saved using:

```bash
curl "http://localhost/ecg_new/api/get_duty_doctors.php"
```

The returned JSON now includes `fcm_token` for each doctor so you can confirm the token was received and stored.

If you'd like, I can craft an exact `curl` multipart example (you can supply a small test image) and optionally run it locally for you if you want me to.
