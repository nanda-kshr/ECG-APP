import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/task.dart';
import '../config.dart';

class TaskService {
  static const String apiBase = kApiBaseUrl;

  // List tasks with filters (admin view)
  static Future<List<Task>> listTasks({
    String? status,
    int? doctorId,
    int? technicianId,
    int limit = 50,
    int offset = 0,
  }) async {
    final queryParams = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
      if (status != null) 'status': status,
      if (doctorId != null) 'doctor_id': doctorId.toString(),
      if (technicianId != null) 'technician_id': technicianId.toString(),
    };
    final url = Uri.parse('${apiBase}list_tasks.php')
        .replace(queryParameters: queryParams);
    try {
      final resp = await http.get(url).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        if (decoded['success'] == true && decoded['tasks'] != null) {
          return (decoded['tasks'] as List)
              .map((json) => Task.fromJson(json))
              .toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Doctor: update comment/feedback for an individual image
  static Future<Map<String, dynamic>> updateImageComment({
    required int taskId,
    required int imageId,
    required int doctorId,
    String comment = '',
  }) async {
    // Uses update_task.php with image-specific feedback
    final url = Uri.parse('${apiBase}update_task.php');
    try {
      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'task_id': taskId,
          'user_id': doctorId,
          'feedback': comment,
          'image_id': imageId,
        }),
      );
      final decoded = jsonDecode(resp.body);
      if (resp.statusCode == 200 && decoded['success'] == true) {
        return {
          'success': true,
          'message': decoded['message'] ?? 'Image comment updated'
        };
      }
      return {
        'success': false,
        'error': decoded['error'] ?? 'Failed to update image comment'
      };
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // Doctor: get tasks assigned to current duty doctor
  static Future<List<Task>> listDutyTasks(
      {int? doctorId, String? status}) async {
    final queryParams = <String, String>{
      'limit': '50',
      'offset': '0',
      if (status != null) 'status': status,
      if (doctorId != null) 'doctor_id': doctorId.toString(),
    };
    final url = Uri.parse('${apiBase}list_tasks.php')
        .replace(queryParameters: queryParams);
    try {
      final resp = await http.get(url).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        if (decoded['success'] == true && decoded['tasks'] != null) {
          return (decoded['tasks'] as List)
              .map((json) => Task.fromJson(json))
              .toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Doctor: update a duty task (mark complete with comment)
  static Future<Map<String, dynamic>> dutyUpdateTask({
    required int taskId,
    required int doctorId,
    String comment = '',
  }) async {
    final url = Uri.parse('${apiBase}duty_update_task.php');
    try {
      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(
            {'task_id': taskId, 'doctor_id': doctorId, 'comment': comment}),
      );
      final decoded = jsonDecode(resp.body);
      if (resp.statusCode == 200 && decoded['success'] == true) {
        return {'success': true, 'message': decoded['message'] ?? 'Updated'};
      }
      return {
        'success': false,
        'error': decoded['error'] ?? 'Failed to update'
      };
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // Generic status/feedback update
  static Future<Map<String, dynamic>> updateTask({
    required int taskId,
    required int userId,
    required String status,
    String feedback = '',
  }) async {
    final url = Uri.parse('${apiBase}update_task.php');
    try {
      final resp = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'task_id': taskId,
              'user_id': userId,
              'status': status,
              'feedback': feedback
            }),
          )
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(resp.body);
      if (resp.statusCode == 200 && decoded['success'] == true) {
        return {'success': true, 'message': decoded['message']};
      }
      return {
        'success': false,
        'error': decoded['error'] ?? 'Failed to update task'
      };
    } catch (e) {
      return {'success': false, 'error': 'Exception: $e'};
    }
  }

  // Technician: create task for existing patient (JSON)
  static Future<Map<String, dynamic>> createTask({
    required int patientId,
    required int technicianId,
    String notes = '',
    String priority = 'normal',
  }) async {
    final url = Uri.parse('${apiBase}create_task.php');
    try {
      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'patient_id': patientId,
          'technician_id': technicianId,
          'notes': notes,
          'priority': priority,
        }),
      );
      final decoded = jsonDecode(resp.body);
      if (resp.statusCode == 200 && decoded['success'] == true) {
        return {'success': true, 'task_id': decoded['task_id']};
      }
      return {
        'success': false,
        'error': decoded['error'] ?? 'Failed to create task'
      };
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // Technician: create task for existing patient (Multipart with optional images)
  static Future<Map<String, dynamic>> createTaskMultipart({
    required int patientId,
    required int technicianId,
    String notes = '',
    String priority = 'normal',
    List<http.MultipartFile> files = const [],
  }) async {
    final uri = Uri.parse('${apiBase}create_task.php');
    try {
      if (files.isEmpty) {
        return {
          'success': false,
          'error': 'At least one image is required'
        };
      }
      final req = http.MultipartRequest('POST', uri);
      req.fields['patient_id'] = patientId.toString();
      req.fields['technician_id'] = technicianId.toString();
      // API expects 'technician_notes' and file field 'image[]'
      req.fields['technician_notes'] = notes;
      req.fields['priority'] = priority;
      for (final f in files) {
        // Ensure field name matches API: image[]
        if (f.field != 'image[]') {
          req.files.add(http.MultipartFile(
            'image[]',
            f.finalize(),
            f.length,
            filename: f.filename,
            contentType: f.contentType,
          ));
        } else {
          req.files.add(f);
        }
      }
      final streamed = await req.send();
      final resp = await http.Response.fromStream(streamed);
      final decoded = jsonDecode(resp.body);
      if (resp.statusCode == 200 && decoded['success'] == true) {
        return {'success': true, 'task_id': decoded['task_id']};
      }
      return {
        'success': false,
        'error': decoded['error'] ?? 'Failed to create task'
      };
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }
}
