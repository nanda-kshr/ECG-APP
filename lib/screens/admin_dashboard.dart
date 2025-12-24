import 'package:flutter/material.dart';
import '../services/admin_service.dart';
import '../models/admin_dashboard.dart' as admin_model; // alias
import 'task_list_screen.dart';
import 'login_screen.dart';
import 'duty_doctor_tab.dart';
import 'admin_profile_screen.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import 'task_detail_screen.dart';
import 'patient_tasks_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  // Default to Home tab
  int _selectedIndex = 2;

  Future<bool> _onWillPop() async {
    if (_selectedIndex != 2) {
      setState(() => _selectedIndex = 2);
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            // 0: Duty Doctors
            const DutyDoctorTab(),
            // 1: Pending
            const TaskListScreen(
              title: 'Pending Tasks',
              filterStatus: 'pending',
            ),
            // 2: Home (default)
            const AdminHomeTab(),
            // 3: Completed
            const TaskListScreen(
              title: 'Completed Tasks',
              filterStatus: 'completed',
            ),
            // 4: Profile
            const AdminProfileScreen(),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.blue[600],
          unselectedItemColor: Colors.grey[600],
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.medical_services),
              label: 'Duty Doctors',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.pending_actions),
              label: 'Pending',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.check_circle),
              label: 'Completed',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

class AdminHomeTab extends StatefulWidget {
  const AdminHomeTab({super.key});

  @override
  State<AdminHomeTab> createState() => _AdminHomeTabState();
}

class _AdminHomeTabState extends State<AdminHomeTab> {
  admin_model.AdminDashboard? _dashboard;
  List<Task> _recentTasks = [];
  bool _loading = true;
  String? _errorText;

  int get _totalTasks =>
      _recentTasks.fold(0, (sum, task) => sum + task.patientLastImages.length);
  int get _pendingTasks => _recentTasks.fold(
      0,
      (sum, task) =>
          sum +
          task.patientLastImages
              .where((img) => img.status != 'completed')
              .length);
  int get _completedTasks => _recentTasks.fold(
      0,
      (sum, task) =>
          sum +
          task.patientLastImages
              .where((img) => img.status == 'completed')
              .length);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final admin_model.AdminDashboard? data =
          await AdminService.fetchDashboard();
      final tasks =
          await TaskService.listTasks(limit: 100); // get more tasks for stats
      setState(() {
        _dashboard = data;
        _recentTasks = tasks;
        _errorText = null;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _dashboard = null;
        _errorText = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cardio App'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          IconButton(
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _dashboard == null
              ? Center(child: Text(_errorText ?? 'Failed to load dashboard'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Statistics',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'Total Tasks',
                              _totalTasks.toString(),
                              Colors.blue,
                              Icons.assignment,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              'Pending Tasks',
                              _pendingTasks.toString(),
                              Colors.orange,
                              Icons.pending_actions,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              'Completed Tasks',
                              _completedTasks.toString(),
                              Colors.green,
                              Icons.check_circle,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Pending Patients',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const TaskListScreen(
                                    title: 'Pending Tasks',
                                    filterStatus: 'pending',
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.arrow_forward),
                            label: const Text('View All'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _recentTasks.where((t) => t.status == 'pending').isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32.0),
                                child: Text('No pending patients',
                                    style: TextStyle(color: Colors.grey)),
                              ),
                            )
                          : Builder(
                              builder: (context) {
                                // Group tasks by Patient ID
                                final pendingTasks = _recentTasks
                                    .where((t) => t.status == 'pending')
                                    .toList();
                                final groupedTasks = <int, List<Task>>{};
                                for (var task in pendingTasks) {
                                  groupedTasks
                                      .putIfAbsent(task.patientId, () => [])
                                      .add(task);
                                }
                                final patientIds =
                                    groupedTasks.keys.take(10).toList();

                                return ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: patientIds.length,
                                  itemBuilder: (context, index) {
                                    final patientId = patientIds[index];
                                    final tasks = groupedTasks[patientId]!;
                                    tasks.sort((a, b) =>
                                        b.createdAt.compareTo(a.createdAt));
                                    return _buildPatientCard(tasks);
                                  },
                                );
                              },
                            ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
    );
  }

  Widget _buildTaskCardCompact(Task task) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        isThreeLine: true,
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: Colors.blue[100],
          child: Text(
            _getInitials(task.patientName ?? 'Patient'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue[800],
            ),
          ),
        ),
        title: Text(
          task.patientName ?? 'Unknown Patient',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'ID: ${task.patientIdStr ?? task.patientId}',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Text(
              'Clinic Doctor: ${task.userName ?? 'Unknown'}${task.doctorName != null ? '  •  Doctor: ${task.doctorName}' : ''}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => TaskDetailScreen(task: task)),
          );
        },
      ),
    );
  }

  String _getInitials(String name) {
    final names = name.split(' ');
    if (names.length >= 2) {
      return '${names[0][0]}${names[1][0]}'.toUpperCase();
    } else if (names.isNotEmpty) {
      return names[0][0].toUpperCase();
    }
    return 'U';
  }

  Widget _buildStatCard(
      String label, String value, Color color, IconData icon) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            Text(
              value,
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientCard(List<Task> tasks) {
    if (tasks.isEmpty) return const SizedBox.shrink();

    final patientName = tasks.first.patientName ?? 'Unknown';
    final patientIdStr = tasks.first.patientIdStr ?? 'N/A';
    final pendingCount = tasks
        .expand((t) => t.patientLastImages)
        .where((i) => i.status == 'pending')
        .length;
    final latestTask = tasks.first;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PatientTasksScreen(
                tasks: tasks,
                patientName: patientName,
                patientIdStr: patientIdStr,
              ),
            ),
          );
          _load();
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.blue.shade50,
                child: Text(
                  _getInitials(patientName),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patientName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: $patientIdStr',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Last update: ${_formatDate(latestTask.createdAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: pendingCount > 0
                          ? Colors.orange.shade50
                          : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: pendingCount > 0
                            ? Colors.orange.shade200
                            : Colors.green.shade200,
                      ),
                    ),
                    child: Text(
                      pendingCount > 0
                          ? '$pendingCount Pending'
                          : 'All Reviewed',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: pendingCount > 0
                            ? Colors.orange.shade700
                            : Colors.green.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${tasks.length} Records',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) return '';
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
    return '${months[dateTime.month - 1]} ${dateTime.day}';
  }
}
