import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart';

class AuthService {
  static const String apiBase = kApiBaseUrl;
  static const String _currentUserKey = 'current_user_id';
  static const String _currentUserJsonKey =
      'current_user_json'; // new: store full user json

  static User? _currentUser;

  static User? get currentUser => _currentUser;

  // Use new API spec: login.php expects { email, password }
  static Future<bool> login(String email, String password,
      {String? role}) async {
    final String apiUrl = '${apiBase}login.php';
    try {
      // Prefer JSON body
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          if (role != null) 'role': role
        }),
      );
      if (_handleLoginResponse(response)) return true;

      // Fallback: form encoded
      final formResponse = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body:
            'email=${Uri.encodeQueryComponent(email)}&password=${Uri.encodeQueryComponent(password)}${role != null ? '&role=${Uri.encodeQueryComponent(role)}' : ''}',
      );
      if (_handleLoginResponse(formResponse)) return true;
    } catch (e, st) {
      // Better logging for web XMLHttpRequest errors
      print('Exception during login: $e');
      print(st);
    }
    return false;
  }

  static bool _handleLoginResponse(http.Response response) {
    try {
      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.isEmpty || !(body.startsWith('{') || body.startsWith('['))) {
          print(
              'Non-JSON response: ${body.substring(0, body.length.clamp(0, 200))}');
          return false;
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
          return true;
        } else {
          print(
              'Login failed: ${data['error'] ?? data['detail'] ?? 'Unknown error'}');
        }
      } else {
        print('HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      print('Login parse error: $e');
    }
    return false;
  }

  static Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentUserKey);
    await prefs.remove(_currentUserJsonKey); // clear full user json as well
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
