import 'package:flutter/material.dart';
import '../models/patient.dart';
import '../models/dummy_data.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

class PatientDetailScreen extends StatefulWidget {
  final Patient patient;

  const PatientDetailScreen({super.key, required this.patient});

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> {
  final TextEditingController _responseController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final request = DummyData.getPatientRequest(widget.patient.id);
    if (request?.doctorResponse != null) {
      _responseController.text = request!.doctorResponse!;
    }
  }

  @override
  void dispose() {
    _responseController.dispose();
    super.dispose();
  }

  void _submitResponse() {
    if (_responseController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a response')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    // Simulate API call
    Future.delayed(const Duration(seconds: 1), () {
      DummyData.updatePatientResponse(
          widget.patient.id, _responseController.text.trim());

      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Response submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final request = DummyData.getPatientRequest(widget.patient.id);
    final currentUser = AuthService.currentUser;
    final isDoctor = currentUser?.role == UserRole.doctor;
    final assignedDoctor = request?.assignedDoctorId != null
        ? DummyData.users.firstWhere(
            (user) => user.id == request!.assignedDoctorId,
            orElse: () => DummyData.users.first,
          )
        : null;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Patient Details'),
        backgroundColor: Colors.blue[600],
        elevation: 4,
        actions: [
          if (isDoctor && request?.status != 'completed')
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _isSubmitting ? null : _submitResponse,
              tooltip: 'Save Response',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Patient Info Card
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with Avatar
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.blue[100],
                          child: Text(
                            _getInitials(widget.patient.name),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[800],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.patient.name,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(
                                      request?.status ?? 'pending'),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _getStatusText(request?.status ?? 'pending'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const Divider(height: 32),

                    // Patient Information
                    const Text(
                      'Patient Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildInfoRow(
                        Icons.badge, 'Patient ID', widget.patient.patientId),
                    _buildInfoRow(Icons.cake, 'Age',
                        widget.patient.age?.toString() ?? 'N/A'),
                    _buildInfoRow(Icons.person, 'Gender',
                        _capitalizeFirst(widget.patient.gender ?? 'N/A')),
                    _buildInfoRow(Icons.phone, 'Contact',
                        widget.patient.contact ?? 'N/A'),
                    _buildInfoRow(Icons.calendar_today, 'Registered',
                        _formatDate(widget.patient.createdAt)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Assignment Info Card (if assigned)
            if (request?.assignedDoctorId != null) ...[
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Assignment Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow(Icons.medical_services, 'Assigned Doctor',
                          assignedDoctor?.name ?? 'Unknown'),
                      if (request?.assignedAt != null)
                        _buildInfoRow(Icons.access_time, 'Assigned At',
                            _formatDateTime(request!.assignedAt!)),
                      if (request?.responseAt != null)
                        _buildInfoRow(Icons.check_circle, 'Responded At',
                            _formatDateTime(request!.responseAt!)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Doctor Response Section
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.medical_information,
                          color: Colors.blue[600],
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Doctor\'s Response',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (isDoctor &&
                        request?.assignedDoctorId == currentUser?.id) ...[
                      // Editable for assigned doctor
                      TextField(
                        controller: _responseController,
                        maxLines: 6,
                        decoration: InputDecoration(
                          hintText:
                              'Enter your medical diagnosis and recommendations...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        enabled: request?.status != 'completed',
                      ),
                      if (request?.status != 'completed') ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isSubmitting ? null : _submitResponse,
                            icon: _isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : const Icon(Icons.send),
                            label: Text(_isSubmitting
                                ? 'Submitting...'
                                : 'Submit Response'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.all(16),
                              backgroundColor: Colors.blue[600],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ] else if (request?.doctorResponse != null) ...[
                      // Read-only for others
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green[200]!),
                        ),
                        child: Text(
                          request!.doctorResponse!,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ] else ...[
                      // No response yet
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange[200]!),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.pending_actions,
                              size: 48,
                              color: Colors.orange[600],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              request?.status == 'pending'
                                  ? 'Waiting for doctor assignment'
                                  : 'Waiting for doctor\'s response',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.orange[800],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blue[600]),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    List<String> names = name.split(' ');
    if (names.length >= 2) {
      return '${names[0][0]}${names[1][0]}'.toUpperCase();
    } else if (names.isNotEmpty) {
      return names[0][0].toUpperCase();
    }
    return 'U';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'assigned':
      case 'in_progress':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Pending Assignment';
      case 'assigned':
        return 'Assigned';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      default:
        return 'Unknown';
    }
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final day = date.day.toString().padLeft(2, '0');
    return '$day - ${months[date.month - 1]} - ${date.year}';
  }

  String _formatDateTime(DateTime date) {
    final dateStr = _formatDate(date);
    return '$dateStr ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
