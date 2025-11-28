import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/pg.dart';
import '../config.dart';

class PGService {
  static const String apiBase = kApiBaseUrl;

  /// Create a new PG (doctor can create) - POST /pgs.php
  static Future<Map<String, dynamic>> createPG({
    required String name,
    required String email,
    required String password,
    required int createdBy, // doctor_id
  }) async {
    final url = Uri.parse('${apiBase}pgs.php');
    try {
      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'doctor_id': createdBy,
          'name': name,
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 10));

      final decoded = jsonDecode(resp.body);
      if (resp.statusCode == 200 && decoded['success'] == true) {
        return {
          'success': true,
          'pg_id': decoded['pg_id'],
          'message': decoded['message'] ?? 'PG created successfully',
        };
      }
      return {
        'success': false,
        'error': decoded['error'] ?? 'Failed to create PG',
      };
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  /// List all PGs - GET /pgs.php
  static Future<Map<String, dynamic>> listPGs({
    String? search,
    int? createdBy,
    int limit = 50,
    int offset = 0,
    bool dutyOnly = false,
  }) async {
    final queryParams = <String, String>{};
    
    // Only add query params if they're specified
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (limit != 50) queryParams['limit'] = limit.toString();
    if (offset > 0) queryParams['offset'] = offset.toString();
    if (createdBy != null) queryParams['doctor_id'] = createdBy.toString();
    if (dutyOnly) queryParams['duty'] = '1';

    final url = queryParams.isEmpty
        ? Uri.parse('${apiBase}pgs.php')
        : Uri.parse('${apiBase}pgs.php').replace(queryParameters: queryParams);

    try {
      final resp = await http.get(url).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        if (decoded['success'] == true && decoded['pgs'] != null) {
          final pgs =
              (decoded['pgs'] as List).map((json) => PG.fromJson(json)).toList();
          return {
            'success': true,
            'pgs': pgs,
            'total': decoded['total'] ?? pgs.length,
          };
        }
        return {
          'success': false,
          'error': decoded['error'] ?? 'Failed to load PGs',
        };
      }
      return {
        'success': false,
        'error': 'HTTP ${resp.statusCode}: ${resp.body}',
      };
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  /// Update PG - PUT /pgs.php
  static Future<Map<String, dynamic>> updatePG({
    required int doctorId,
    required int pgId,
    String? name,
    String? email,
    String? password,
  }) async {
    final url = Uri.parse('${apiBase}pgs.php');
    try {
      final resp = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'doctor_id': doctorId,
          'id': pgId,
          if (name != null) 'name': name,
          if (email != null) 'email': email,
          if (password != null) 'password': password,
        }),
      ).timeout(const Duration(seconds: 10));

      final decoded = jsonDecode(resp.body);
      if (resp.statusCode == 200 && decoded['success'] == true) {
        return {
          'success': true,
          'message': decoded['message'] ?? 'PG updated successfully',
        };
      }
      return {
        'success': false,
        'error': decoded['error'] ?? 'Failed to update PG',
      };
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  /// Set PG as duty PG - PUT /pgs.php with set_duty
  static Future<Map<String, dynamic>> setDutyPG({
    required int doctorId,
    required int pgId,
  }) async {
    final url = Uri.parse('${apiBase}pgs.php');
    try {
      final resp = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'doctor_id': doctorId,
          'id': pgId,
          'set_duty': 1,
        }),
      ).timeout(const Duration(seconds: 10));

      final decoded = jsonDecode(resp.body);
      if (resp.statusCode == 200 && decoded['success'] == true) {
        return {
          'success': true,
          'message': decoded['message'] ?? 'PG set as duty PG',
        };
      }
      return {
        'success': false,
        'error': decoded['error'] ?? 'Failed to set duty PG',
      };
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  /// Delete PG - DELETE /pgs.php
  static Future<Map<String, dynamic>> deletePG({
    required int doctorId,
    required int pgId,
  }) async {
    final url = Uri.parse('${apiBase}pgs.php');
    try {
      final resp = await http.delete(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'doctor_id': doctorId,
          'id': pgId,
        }),
      ).timeout(const Duration(seconds: 10));

      final decoded = jsonDecode(resp.body);
      if (resp.statusCode == 200 && decoded['success'] == true) {
        return {
          'success': true,
          'message': decoded['message'] ?? 'PG deleted successfully',
        };
      }
      return {
        'success': false,
        'error': decoded['error'] ?? 'Failed to delete PG',
      };
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  /// Doctor assigns a PG to a task (kept for backward compatibility)
  static Future<Map<String, dynamic>> assignPGToTask({
    required int taskId,
    required int pgId,
    required int doctorId,
  }) async {
    final url = Uri.parse('${apiBase}doctor_assign_pg.php');
    try {
      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'task_id': taskId,
          'pg_id': pgId,
          'doctor_id': doctorId,
        }),
      ).timeout(const Duration(seconds: 10));

      final decoded = jsonDecode(resp.body);
      if (resp.statusCode == 200 && decoded['success'] == true) {
        return {
          'success': true,
          'message': decoded['message'] ?? 'PG assigned to task',
        };
      }
      return {
        'success': false,
        'error': decoded['error'] ?? 'Failed to assign PG',
      };
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  /// List duty PGs (helper)
  static Future<List<PG>> listDutyPGs() async {
    final result = await listPGs(dutyOnly: true);
    if (result['success'] == true) return (result['pgs'] as List<PG>);
    return [];
  }
}
