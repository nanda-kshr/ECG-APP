import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart';
import 'push_service.dart';

enum LoginStatus {
  success,
  invalidCredentials,
  accountNotFound,
  serverError,
  unknown
}

class AuthService {
  static const String apiBase = apiBaseUrl;
  static const String _currentUserKey = 'current_user_id';
  static const String _currentUserJsonKey =
      'current_user_json'; // new: store full user json

  static User? _currentUser;
  static String? _sessionCookie;

  static User? get currentUser => _currentUser;

  // Use new API spec: login.php expects { email, password }
  static Future<LoginStatus> login(String email, String password,
      {String? role}) async {
    final String apiUrl = '${apiBase}login.php';
    try {
      // Prefer JSON body. Include fcm_token if available
      final token = PushService.token ?? await PushService.getLocalToken();
      final jsonBody = {
        'email': email,
        'password': password,
        if (role != null) 'role': role,
        if (token != null) 'fcm_token': token,
      };

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(jsonBody),
      );

      // Capture session cookie if provided
      _captureSessionCookieFromResponse(response);
      final status = _handleLoginResponse(response);
      if (status == LoginStatus.success) return status;
      if (status == LoginStatus.accountNotFound) return status;

      // Fallback: form encoded (Only if previous attempt wasn't a definitive 404/Success)
      // Actually, if we got a 404, we shouldn't fallback, we know the account is missing.
      // But keeping fallback logic safe:
      if (status != LoginStatus.accountNotFound) {
        final formResponse = await http.post(
          Uri.parse(apiUrl),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body:
              'email=${Uri.encodeQueryComponent(email)}&password=${Uri.encodeQueryComponent(password)}${role != null ? '&role=${Uri.encodeQueryComponent(role)}' : ''}',
        );
        _captureSessionCookieFromResponse(formResponse);
        return _handleLoginResponse(formResponse);
      }
      return status;
    } catch (e, st) {
      // Better logging for web XMLHttpRequest errors
      print('Exception during login: $e');
      print(st);
      return LoginStatus.unknown;
    }
  }

  static LoginStatus _handleLoginResponse(http.Response response) {
    try {
      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.isEmpty || !(body.startsWith('{') || body.startsWith('['))) {
          print(
              'Non-JSON response: ${body.substring(0, body.length.clamp(0, 200))}');
          return LoginStatus.serverError;
        }
        final data = jsonDecode(body);
        if (data['success'] == true && data['user'] != null) {
          _currentUser = User.fromJson(data['user']);
          SharedPreferences.getInstance().then((prefs) {
            // Persist both id and full user json for restoration after app restart
            prefs.setString(_currentUserKey, _currentUser!.id.toString());
            prefs.setString(
                _currentUserJsonKey, jsonEncode(_currentUser!.toJson()));
          });
          return LoginStatus.success;
        } else {
          // Should ideally check data['code'] here too if 200 OK has business error
          return LoginStatus.invalidCredentials;
        }
      } else if (response.statusCode == 404) {
        // We explicitly return 404 from PHP for "account not found"
        return LoginStatus.accountNotFound;
      } else if (response.statusCode == 401) {
        return LoginStatus.invalidCredentials;
      } else {
        print('HTTP error: ${response.statusCode}');
        return LoginStatus.serverError;
      }
    } catch (e) {
      print('Login parse error: $e');
      return LoginStatus.unknown;
    }
  }

  static Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentUserKey);
    await prefs.remove(_currentUserJsonKey); // clear full user json as well
    await prefs.remove('session_cookie');
  }

  static Future<void> _captureSessionCookieFromResponse(
      http.Response response) async {
    try {
      final sc = response.headers['set-cookie'];
      if (sc != null && sc.isNotEmpty) {
        _sessionCookie = sc.split(';').first; // keep only cookie=value
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('session_cookie', _sessionCookie!);
      }
    } catch (e) {
      // ignore
    }
  }

  static Future<String?> getSessionCookie() async {
    if (_sessionCookie != null) return _sessionCookie;
    final prefs = await SharedPreferences.getInstance();
    final sc = prefs.getString('session_cookie');
    _sessionCookie = sc;
    return sc;
  }

  static Future<bool> isLoggedIn() async {
    if (_currentUser != null) return true;

    final prefs = await SharedPreferences.getInstance();

    // Attempt to restore full user json first
    final userJson = prefs.getString(_currentUserJsonKey);
    if (userJson != null && userJson.isNotEmpty) {
      try {
        final map = jsonDecode(userJson);
        if (map is Map<String, dynamic>) {
          _currentUser = User.fromJson(map);
          return true;
        }
      } catch (e) {
        print('Failed to restore user json: $e');
      }
    }

    // Legacy fallback: only id stored (cannot build full user -> treat as logged out)
    final userId = prefs.getString(_currentUserKey);
    if (userId != null) {
      // In future: fetch profile via API using userId, for now consider not logged in until full data restored
      print(
          'Found stored user id without profile; clearing to avoid null access');
      await prefs.remove(_currentUserKey);
      return false;
    }
    return false;
  }

  static Future<void> initializeAuth() async {
    await isLoggedIn(); // attempts restoration now
  }
}
