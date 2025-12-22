import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/patient.dart';

class PatientService {
  static const String apiBase = apiBaseUrl;

  // Search patients by name/id string
  static Future<List<Patient>> searchPatients(
      {String query = '', int limit = 20, int offset = 0}) async {
    final params = <String, String>{
      if (query.isNotEmpty) 'q': query,
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    final url =
        Uri.parse('${apiBase}patients.php').replace(queryParameters: params);
    try {
      final resp = await http.get(url).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        if (decoded['success'] == true && decoded['patients'] is List) {
          return (decoded['patients'] as List)
              .map((e) => Patient.fromJson(e))
              .toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // Create a new patient record
  static Future<Map<String, dynamic>> createPatient({
    required String name,
    int? age,
    String? gender,
    String? contact,
    int? createdBy, // technician/admin id if required by backend
  }) async {
    final url = Uri.parse('${apiBase}patients.php');
    try {
      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          if (age != null) 'age': age,
          if (gender != null) 'gender': gender,
          if (contact != null) 'contact': contact,
          // Some APIs expect `phone` key. Send both to be defensive.
          if (contact != null) 'phone': contact,
          if (createdBy != null) 'created_by': createdBy,
        }),
      );
      final decoded = jsonDecode(resp.body);
      if (resp.statusCode == 200 && decoded['success'] == true) {
        // Some APIs return the created object, others just id
        if (decoded['patient'] != null) {
          return {
            'success': true,
            'patient': Patient.fromJson(decoded['patient'])
          };
        }
        // Some endpoints return an id and a patient_id string (PAT...)
        // Return both if available so callers can safely construct a Patient
        // without attempting to parse the PAT... string as an integer.
        return {
          'success': true,
          if (decoded['id'] != null) 'id': decoded['id'],
          if (decoded['patient_id'] != null)
            'patient_id': decoded['patient_id']
        };
      }
      return {
        'success': false,
        'error': decoded['error'] ?? 'Failed to create patient'
      };
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }
}
