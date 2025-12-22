import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/task.dart';
import '../widgets/common_app_bar.dart';
import 'login_screen.dart';
import 'technician_upload_screen.dart';
import 'task_detail_screen.dart';
import '../services/task_service.dart';

class TechnicianDashboard extends StatefulWidget {
  const TechnicianDashboard({super.key});

  @override
  State<TechnicianDashboard> createState() => _TechnicianDashboardState();
}

class _TechnicianDashboardState extends State<TechnicianDashboard> {
  List<Task> _tasks = [];
  bool _loading = true;
  String? _error;
  

  @override
  void initState() {
    super.initState();
    _loadTasks();
    // Consent dialog will be shown when navigating to the Upload screen.
  }

  Future<void> _loadTasks() async {
    final currentUser = AuthService.currentUser;
    if (currentUser == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tasks = await TaskService.listTasks(technicianId: currentUser.id);
      setState(() {
        _tasks = tasks;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load tasks';
        _loading = false;
      });
    }
  }

  int get _submittedCount => _tasks.length;
  int get _feedbackReceivedCount => _tasks.fold(
      0,
      (sum, task) =>
          sum + task.patientLastImages.where((img) => img.status == 'completed').length);
  int get _underReviewCount => _tasks
      .where((t) => t.status == 'assigned' || t.status == 'in_progress')
      .fold(0, (sum, task) => sum + task.patientLastImages.where((img) => img.status != 'completed').length);

  void _navigateToUpload() async {
    // Always show consent dialog when user taps Upload
    final agreed = await _showConsentDialog();
    if (agreed != true) return;

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const TechnicianUploadScreen(),
      ),
    );
    if (result == true) {
      _loadTasks();
    }
  }

  Future<bool?> _showConsentDialog() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool _agreed = false;
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Text('ECG Submission Terms'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Please review and accept the terms below before capturing an ECG image.'),
                  const SizedBox(height: 12),
                  const Text('Sending of case for opinion is purely voluntary.'),
                  const SizedBox(height: 8),
                  const Text('The opinion expressed has to be analysed in context of the symptoms & signed by the treating physician.'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Checkbox(
                        value: _agreed,
                        onChanged: (v) => setState(() {
                          _agreed = v ?? false;
                        }),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('I agree to the terms and consent to submit ECG images.'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: _agreed ? () => Navigator.of(context).pop(true) : null,
                child: const Text('Agree & Capture ECG'),
              ),
            ],
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser!;
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: CommonAppBar(
        title: 'Cardio',
        user: user,
        onLogout: () {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        },
      ),
      body: RefreshIndicator(
        onRefresh: _loadTasks,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                height: 80,
                child: Builder(builder: (context) {
                  final uploadAllowed = _isUploadAllowed();
                  return ElevatedButton.icon(
                    onPressed: uploadAllowed ? _navigateToUpload : () => _showUploadDisabledSnackbar(context),
                    icon: const Icon(Icons.upload_file, size: 32),
                    label: Text(
                      uploadAllowed ? 'Upload ECG' : 'Upload\n(Mon–Fri, 8–3 PM IST)',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: uploadAllowed ? Colors.green : Colors.grey,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),
              const Text('Statistics',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                      child: _buildStatCard(
                          'Total Patients',
                          _submittedCount.toString(),
                          Colors.blue,
                          Icons.file_upload)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _buildStatCard(
                          'Pending Tasks',
                          _underReviewCount.toString(),
                          Colors.orange,
                          Icons.rate_review)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _buildStatCard(
                          'Completed Tasks',
                          _feedbackReceivedCount.toString(),
                          Colors.green,
                          Icons.check_circle)),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Uploaded Patient Records',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text('${_tasks.length} tasks',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                ],
              ),
              const SizedBox(height: 12),
              if (_loading)
                const Center(
                    child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator()))
              else if (_error != null)
                Center(
                    child: Text(_error!,
                        style: const TextStyle(color: Colors.red)))
              else if (_tasks.isEmpty)
                _buildEmptyState()
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _tasks.length,
                  itemBuilder: (context, index) {
                    final task = _tasks[index];
                    return _buildTaskCard(task);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
      String label, String value, Color color, IconData icon) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(Task task) {
    final hasFeedback =
        task.doctorFeedback != null && task.doctorFeedback!.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: hasFeedback
            ? const BorderSide(color: Colors.green, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => TaskDetailScreen(task: task)),
          );
          _loadTasks();
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.blue[100],
                    child: Text(
                      _getInitials(task.patientName ?? 'Unknown'),
                      style: TextStyle(
                          color: Colors.blue[700],
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(task.patientName ?? 'Unknown Patient',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(task.patientIdStr ?? 'ID ',
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Image count badge
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Colors.blue, Colors.lightBlueAccent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        '${task.patientLastImages.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                  // const SizedBox(width: 12),
                  // Status chip (uses helper functions)
                  // Container(
                  //   padding:
                  //       const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  //   decoration: BoxDecoration(
                  //     color: _getStatusColor(status).withOpacity(0.1),
                  //     borderRadius: BorderRadius.circular(20),
                  //     border: Border.all(color: _getStatusColor(status)),
                  //   ),
                  //   child: Text(_getStatusText(status),
                  //       style: TextStyle(
                  //           color: _getStatusColor(status),
                  //           fontSize: 12,
                  //           fontWeight: FontWeight.w600)),
                  // ),
                  // Container(
                  //   padding:
                  //       const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  //   decoration: BoxDecoration(
                  //     color: _getStatusColor(status).withOpacity(0.1),
                  //     borderRadius: BorderRadius.circular(20),
                  //     border: Border.all(color: _getStatusColor(status)),
                  //   ),
                  //   child: Text(_getStatusText(status),
                  //       style: TextStyle(
                  //           color: _getStatusColor(status),
                  //           fontSize: 12,
                  //           fontWeight: FontWeight.w600)),
                  // ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(task.createdAt.toString().substring(0, 16),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(width: 16),
                  // Text('Priority: ${task.priorityDisplay}',
                  //     style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
              if (hasFeedback) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Row(
                    children: [
                      Icon(Icons.feedback, size: 16, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Doctor feedback received',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.green,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  bool _isUploadAllowed() {
    final ist = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
    final weekday = ist.weekday; // 1 = Monday
    if (weekday < DateTime.monday || weekday > DateTime.friday) return false;
    final hour = ist.hour;
    return hour >= 8 && hour < 15;
  }

  void _showUploadDisabledSnackbar(BuildContext context) {
    final ist = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
    // final timeStr = '${ist.hour.toString().padLeft(2, '0')}:${ist.minute.toString().padLeft(2, '0')} IST';
    // ScaffoldMessenger.of(context).showSnackBar(
    //   SnackBar(content: Text('Uploads allowed Mon–Fri 08:00–15:00 IST. Current IST time: $timeStr')),
    // );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            Icon(
              Icons.inbox,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            const Text(
              'No patient records uploaded yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Upload your first ECG to get started',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
