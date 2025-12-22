import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import '../config.dart';

class PushService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static String? _token;
  static bool _initialized = false;
  static final StreamController<RemoteMessage> _onMessageController = StreamController<RemoteMessage>.broadcast();
  static final StreamController<RemoteMessage> _onMessageOpenedController = StreamController<RemoteMessage>.broadcast();

  static String? get token => _token;

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      await Firebase.initializeApp();
    } catch (e) {
      // Already initialized or platform not configured; just continue
    }

    // Request permission where needed (iOS)
    try {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);
    } catch (e) {}

    _token = await _messaging.getToken();
    if (_token != null) {
      await _saveTokenLocally(_token!);
    }

    // Listen for token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      _token = newToken;
      await _saveTokenLocally(newToken);
      final res = await _sendTokenToServer(newToken);
      if (res['ok'] != true) {
        print('Token refresh registration failed: ${res['error']} status=${res['status']} body=${res['body']}');
      }
    });

    // Message handlers
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _onMessageController.add(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _onMessageOpenedController.add(message);
    });

    // Handle case where app was opened from a terminated state via notification
    try {
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _onMessageOpenedController.add(initial);
    } catch (e) {}

    // If already logged in, try to send to server
    if (AuthService.currentUser != null && _token != null) {
      await _sendTokenToServer(_token!);
    }

    // Foreground message handler can be set by app using FirebaseMessaging.onMessage
  }

  static Future<void> ensureRegisteredAfterLogin() async {
    // Call this after a successful login so server gets the token stored with session or via login route
    if (_token == null) {
      _token = await _messaging.getToken();
      if (_token != null) await _saveTokenLocally(_token!);
    }

    if (_token != null) {
      final res = await _sendTokenToServer(_token!);
      if (res['ok'] != true) {
        print('ensureRegisteredAfterLogin: registration failed: ${res['error']} status=${res['status']} body=${res['body']}');
      }
    }
  }

  /// Force-fetch a fresh token from FCM and return it (also saves locally)
  static Future<String?> fetchFreshToken() async {
    // Ensure Firebase is initialized first
    if (!_initialized) {
      await initialize();
    }
    
    try {
      final newToken = await _messaging.getToken();
      if (newToken != null) {
        _token = newToken;
        await _saveTokenLocally(newToken);
      }
      return newToken;
    } catch (e) {
      return null;
    }
  }

  /// Attempt to register currently-known token with server immediately
  /// Attempts to register the current token with the server and returns the result map
  static Future<Map<String, dynamic>> registerTokenNow() async {
    // Try to get token from memory first
    if (_token == null) _token = await getLocalToken();
    
    // If still no token, fetch fresh from FCM
    if (_token == null) {
      _token = await fetchFreshToken();
    }
    
    if (_token == null) {
      return {'ok': false, 'error': 'no_token', 'status': 'no-status'};
    }
    
    final res = await _sendTokenToServer(_token!);
    return res['ok'] == true ? {'ok': true} : res;
  }

  static Future<void> _saveTokenLocally(String t) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_token', t);
  }

  static Future<String?> getLocalToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('fcm_token');
  }

  static Stream<RemoteMessage> get onMessage => _onMessageController.stream;
  static Stream<RemoteMessage> get onMessageOpened => _onMessageOpenedController.stream;

  static Future<Map<String, dynamic>> _sendTokenToServer(String t) async {
    final base = apiBaseUrl;

    final Map<String, dynamic> result = {'ok': false, 'status': null, 'body': null, 'error': null};

    try {
      final cookie = await AuthService.getSessionCookie();
      final url = Uri.parse('${base}register_fcm_token.php');
      final headers = <String,String>{'Content-Type':'application/json'};
      if (cookie != null && cookie.isNotEmpty) headers['Cookie'] = cookie;

      final resp = await http.post(url, headers: headers, body: jsonEncode({'fcm_token': t})).timeout(const Duration(seconds: 10));
      result['status'] = resp.statusCode;
      result['body'] = resp.body;
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map && decoded['success'] == true) {
          result['ok'] = true;
          return result;
        }
        result['error'] = decoded['error'] ?? 'unknown';
        return result;
      } else {
        result['error'] = 'http_${resp.statusCode}';
        return result;
      }
    } catch (e) {
      result['error'] = e.toString();
      return result;
    }
  }
}
