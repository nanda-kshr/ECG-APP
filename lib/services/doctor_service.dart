import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/doctor.dart';
import '../config.dart';

class DoctorService {
  static const String apiBase = kApiBaseUrl;

  // List doctors (optionally filter duty=1)
  static Future<Map<String, dynamic>> listDoctors({
    String? search,
    int limit = 50,
    int offset = 0,
    bool dutyOnly = false,
  }) async {
    final queryParams = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
      if (search != null && search.isNotEmpty) 'search': search,
      if (dutyOnly) 'duty': '1',
    };

    final url = Uri.parse('${apiBase}doctors.php')
        .replace(queryParameters: queryParams);

    try {
      final resp = await http.get(url).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        if (decoded['success'] == true && decoded['doctors'] != null) {
          final doctors = (decoded['doctors'] as List)
              .map((json) => Doctor.fromJson(json))
              .toList();
          return {
            'success': true,
            'doctors': doctors,
            'total': decoded['total'] ?? doctors.length,
          };
        }
        return {
          'success': false,
          'error': decoded['error'] ?? 'Failed to load doctors'
        };
      }
      return {
        'success': false,
        'error': 'HTTP ${resp.statusCode}: ${resp.body}'
      };
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // Create doctor
  static Future<Map<String, dynamic>> addDoctor({
    required int adminId,
    required String name,
    required String email,
    required String password,
    String? department,
  }) async {
    final url = Uri.parse('${apiBase}doctors.php');
    try {
      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'admin_id': adminId,
          'name': name,
          'email': email,
          'password': password,
          if (department != null) 'department': department,
        }),
      );
      final decoded = jsonDecode(resp.body);
      if (resp.statusCode == 200 && decoded['success'] == true) {
        return {
          'success': true,
          'doctor_id': decoded['doctor_id'],
          'message': decoded['message'] ?? 'Doctor added'
        };
      }
      return {
        'success': false,
        'error': decoded['error'] ?? 'Failed to add doctor'
      };
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // Update doctor
  static Future<Map<String, dynamic>> updateDoctor({
    required int adminId,
    required int id,
    String? name,
    String? email,
    String? password,
    String? department,
    bool? isActive,
  }) async {
    final url = Uri.parse('${apiBase}doctors.php');
    try {
      final resp = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'admin_id': adminId,
          'id': id,
          if (name != null) 'name': name,
          if (email != null) 'email': email,
          if (password != null) 'password': password,
          if (department != null) 'department': department,
          if (isActive != null) 'is_active': isActive ? 1 : 0,
        }),
      );
      final decoded = jsonDecode(resp.body);
      if (resp.statusCode == 200 && decoded['success'] == true) {
        return {'success': true};
      }
      return {
        'success': false,
        'error': decoded['error'] ?? 'Failed to update doctor'
      };
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // Delete doctor
  static Future<Map<String, dynamic>> deleteDoctor({
    required int adminId,
    required int id,
  }) async {
    final url = Uri.parse('${apiBase}doctors.php');
    try {
      final resp = await http.delete(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'admin_id': adminId, 'id': id}),
      );
      final decoded = jsonDecode(resp.body);
      if (resp.statusCode == 200 && decoded['success'] == true) {
        return {'success': true};
      }
      return {
        'success': false,
        'error': decoded['error'] ?? 'Failed to delete doctor'
      };
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // Set duty doctor using new API (preferred)
  static Future<Map<String, dynamic>> setDutyDoctor({
    required int adminId,
    required int doctorId,
  }) async {
    try {
      // Preferred: doctors.php PUT with set_duty
      final putUrl = Uri.parse('${apiBase}doctors.php');
      final putResp = await http.put(
        putUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'admin_id': adminId, 'id': doctorId, 'set_duty': 1}),
      );
      if (putResp.statusCode == 200) {
        final decoded = jsonDecode(putResp.body);
        if (decoded['success'] == true) {
          return {'success': true, 'duty_doctor_id': doctorId};
        }
      }

      // Fallback legacy endpoint
      final url = Uri.parse('${apiBase}set_duty_doctor.php');
      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'admin_id': adminId, 'doctor_id': doctorId}),
      );
      final decoded = jsonDecode(resp.body);
      if (resp.statusCode == 200 && decoded['success'] == true) {
        return {
          'success': true,
          'duty_doctor_id': decoded['duty_doctor_id'] ?? doctorId
        };
      }
      return {
        'success': false,
        'error': decoded['error'] ?? 'Failed to set duty doctor'
      };
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // List only duty doctors (helper)
  static Future<List<Doctor>> listDutyDoctors() async {
    final result = await listDoctors(dutyOnly: true);
    if (result['success'] == true) return (result['doctors'] as List<Doctor>);
    return [];
  }
}
