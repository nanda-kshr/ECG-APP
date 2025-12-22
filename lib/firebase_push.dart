// Example: Firebase Cloud Messaging integration (minimal)
// Add to your Flutter app after adding firebase_core & firebase_messaging.

import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;

// Call this early in main()
Future<void> initFirebaseAndRegisterToken(String baseUrl, {String? cookie}) async {
  await Firebase.initializeApp();
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  // Request permissions on iOS
  NotificationSettings settings = await messaging.requestPermission(alert: true, badge: true, sound: true);

  // Foreground message handler
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('Foreground message: ${message.notification?.title} - ${message.notification?.body}');
  });

  // When user taps a notification
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    // Navigate to task screen using message.data['task_id']
    print('Opened app from notification: ${message.data}');
  });

  String? token = await messaging.getToken();
  print('FCM token: $token');
  if (token != null) {
    // Option A: send token to login endpoint along with credentials
    // Option B: send token to register_fcm_token.php using session cookie from login
    final url = Uri.parse('$baseUrl/api/register_fcm_token.php');
    final headers = <String,String>{'Content-Type':'application/json'};
    if (cookie != null) headers['Cookie'] = cookie;

    try {
      final resp = await http.post(url, headers: headers, body: jsonEncode({'fcm_token': token}));
      print('Register token response: ${resp.statusCode} ${resp.body}');
    } catch (e) {
      print('Failed to register token: $e');
    }
  }
}
