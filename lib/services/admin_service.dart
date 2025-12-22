import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/admin_dashboard.dart';
import '../config.dart';

class AdminService {
  static const String apiBase = apiBaseUrl;

  static Future<AdminDashboard?> fetchDashboard() async {
    // Use new API location if routed via base: admin_dashboard.php
    final url = Uri.parse('${apiBase}admin_dashboard.php');
    try {
      final resp = await http.get(url).timeout(const Duration(seconds: 10));
      final body = resp.body.trim();
      if (resp.statusCode == 200) {
        if (body.isEmpty || !(body.startsWith('{') || body.startsWith('['))) {
          throw Exception(
              'Non-JSON response from API: ${body.substring(0, body.length.clamp(0, 200))}');
        }
        final Map<String, dynamic> decoded = jsonDecode(body);
        if (decoded['success'] == true) {
          final payload = decoded['data'] ?? <String, dynamic>{};
          return AdminDashboard.fromJson(payload);
        } else {
          throw Exception(
              'API returned error: ${decoded['error']?.toString() ?? body}');
        }
      } else {
        throw Exception(
            'HTTP ${resp.statusCode}: ${body.substring(0, body.length.clamp(0, 200))}');
      }
    } catch (e) {
      rethrow;
    }
  }
}
