import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/task.dart';
import '../models/pg.dart';
import '../widgets/common_app_bar.dart';
import 'login_screen.dart';
import '../services/task_service.dart';
import '../services/push_service.dart';
import '../config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/pg_service.dart';
import 'task_detail_screen.dart';

class DoctorDashboard extends StatefulWidget {
  const DoctorDashboard({Key? key}) : super(key: key);

  @override
  State<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  List<Task> _tasks = [];
  List<PG> _pgs = [];
  bool _loading = true;
  bool _loadingPGs = false;
  String? _error;
  String? _pgError;
  String _pgSearchQuery = '';
  final _pgSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAssignedTasks();
    _loadPGs();
  }



  Future<void> _loadAssignedTasks() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        setState(() {
          _error = 'Not logged in';
          _loading = false;
        });
        return;
      }
      
      // If PG, load tasks assigned to this PG; otherwise load by doctor_id
      final tasks = currentUser.role.name == 'pg'
          ? await TaskService.listDutyTasks(pgId: currentUser.id)
          : await TaskService.listDutyTasks(doctorId: currentUser.id);
      
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

  Future<void> _loadPGs({String? search}) async {
    final currentUser = AuthService.currentUser;
    if (currentUser == null) return;

    setState(() {
      _loadingPGs = true;
      _pgError = null;
    });

    final result = await PGService.listPGs(
      search: search,
      createdBy: currentUser.id,
    );
    
    if (mounted) {
      setState(() {
        _loadingPGs = false;
        if (result['success'] == true) {
          _pgs = result['pgs'] as List<PG>;
        } else {
          _pgError = result['error'] ?? 'Failed to load PGs';
        }
      });
    }
  }

  Future<void> _showCreatePGDialog() async {
    final currentUser = AuthService.currentUser;
    if (currentUser == null) return;

    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create New PG'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Name *',
                  hintText: 'Enter full name (2-100 characters)',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Email *',
                  hintText: 'example@domain.com',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                maxLength: 128,
                decoration: const InputDecoration(
                  labelText: 'Password *',
                  hintText: 'Min 8 chars: letters, numbers, symbols',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final email = emailController.text.trim();
              final password = passwordController.text;

              // Name validation
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Name is required')),
                );
                return;
              }
              if (name.length < 2 || name.length > 100) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Name must be 2-100 characters')),
                );
                return;
              }
              if (!RegExp(r'^[a-zA-Z\s.]+$').hasMatch(name)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Name can only contain letters, spaces, and dots')),
                );
                return;
              }

              // Email validation
              if (email.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Email is required')),
                );
                return;
              }
              if (!RegExp(
                r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
              ).hasMatch(email)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid email address')),
                );
                return;
              }

              // Password validation
              if (password.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password is required')),
                );
                return;
              }
              if (password.length < 8) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password must be at least 8 characters')),
                );
                return;
              }
              if (!RegExp(r'[a-z]').hasMatch(password)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password must contain lowercase letters')),
                );
                return;
              }
              if (!RegExp(r'[A-Z]').hasMatch(password)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password must contain uppercase letters')),
                );
                return;
              }
              if (!RegExp(r'[0-9]').hasMatch(password)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password must contain numbers')),
                );
                return;
              }

              Navigator.pop(ctx, true);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result != true) return;

    // Create PG
    final createResult = await PGService.createPG(
      name: nameController.text.trim(),
      email: emailController.text.trim(),
      password: passwordController.text.trim(),
      doctorId: currentUser.id,
    );

    if (mounted) {
      if (createResult['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PG created successfully')),
        );
        _loadPGs(search: _pgSearchQuery.isEmpty ? null : _pgSearchQuery);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(createResult['error'] ?? 'Failed to create PG'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
  }

  Future<void> _showAssignPGDialog(Task task) async {
    if (_pgs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No PGs available. Create one first.')),
      );
      return;
    }

    final currentUser = AuthService.currentUser;
    if (currentUser == null) return;

    PG? selectedPG;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Assign PG to ${task.patientName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<PG>(
                decoration: const InputDecoration(
                  labelText: 'Select PG',
                  border: OutlineInputBorder(),
                ),
                value: selectedPG,
                items: _pgs
                    .map((pg) => DropdownMenuItem(
                          value: pg,
                          child: Text('${pg.name} (${pg.email})'),
                        ))
                    .toList(),
                onChanged: (pg) {
                  setDialogState(() {
                    selectedPG = pg;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedPG == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select a PG')),
                  );
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Assign'),
            ),
          ],
        ),
      ),
    );

    if (result != true || selectedPG == null) return;

    // Assign PG to task
    final assignResult = await PGService.assignPGToTask(
      taskId: task.id,
      pgId: selectedPG!.id,
      doctorId: currentUser.id,
    );

    if (mounted) {
      if (assignResult['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${selectedPG!.name} assigned to task'),
          ),
        );
        _loadAssignedTasks();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(assignResult['error'] ?? 'Failed to assign PG'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showPGOptionsDialog(PG pg) async {
    final currentUser = AuthService.currentUser;
    if (currentUser == null) return;

    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(pg.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Email: ${pg.email}'),
            Text('Status: ${pg.isDuty ? 'On Duty' : 'Off Duty'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'edit'),
            child: const Text('Edit'),
          ),
          if (!pg.isDuty)
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'setDuty'),
              child: const Text('Set Duty'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'delete'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (action == null) return;

    switch (action) {
      case 'edit':
        await _editPG(pg);
        break;
      case 'setDuty':
        await _setDutyPG(pg);
        break;
      case 'delete':
        await _deletePG(pg);
        break;
    }
  }

  Future<void> _editPG(PG pg) async {
    final currentUser = AuthService.currentUser;
    if (currentUser == null) return;

    final nameController = TextEditingController(text: pg.name);
    final emailController = TextEditingController(text: pg.email);

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit PG'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Name *',
                  hintText: 'Enter full name (2-100 characters)',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Email *',
                  hintText: 'example@domain.com',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final email = emailController.text.trim();

              // Name validation
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Name is required')),
                );
                return;
              }
              if (name.length < 2 || name.length > 100) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Name must be 2-100 characters')),
                );
                return;
              }
              if (!RegExp(r'^[a-zA-Z\s.]+$').hasMatch(name)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Name can only contain letters, spaces, and dots')),
                );
                return;
              }

              // Email validation
              if (email.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Email is required')),
                );
                return;
              }
              if (!RegExp(
                r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
              ).hasMatch(email)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid email address')),
                );
                return;
              }

              Navigator.pop(ctx, true);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (result != true) {
      nameController.dispose();
      emailController.dispose();
      return;
    }

    final updateResult = await PGService.updatePG(
      doctorId: currentUser.id,
      pgId: pg.id,
      name: nameController.text.trim(),
      email: emailController.text.trim(),
    );

    nameController.dispose();
    emailController.dispose();

    if (mounted) {
      if (updateResult['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PG updated successfully')),
        );
        _loadPGs(search: _pgSearchQuery.isEmpty ? null : _pgSearchQuery);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(updateResult['error'] ?? 'Failed to update PG'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _setDutyPG(PG pg) async {
    final currentUser = AuthService.currentUser;
    if (currentUser == null) return;

    final result = await PGService.setDutyPG(
      doctorId: currentUser.id,
      pgId: pg.id,
    );

    if (mounted) {
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${pg.name} set as duty PG')),
        );
        _loadPGs(search: _pgSearchQuery.isEmpty ? null : _pgSearchQuery);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Failed to set duty PG'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deletePG(PG pg) async {
    final currentUser = AuthService.currentUser;
    if (currentUser == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete PG'),
        content: Text('Are you sure you want to delete ${pg.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final result = await PGService.deletePG(
      doctorId: currentUser.id,
      pgId: pg.id,
    );

    if (mounted) {
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PG deleted successfully')),
        );
        _loadPGs(search: _pgSearchQuery.isEmpty ? null : _pgSearchQuery);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Failed to delete PG'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  int get _totalAssigned => _tasks.length;
  int get _pendingReview {
    int count = 0;
    for (var task in _tasks) {
      for (var image in task.patientLastImages) {
        if (image.status == 'pending') {
          count++;
        }
      }
    }
    return count;
  }
  int get _completed {
    int count = 0;
    for (var task in _tasks) {
      for (var image in task.patientLastImages) {
        if (image.status == 'completed') {
          count++;
        }
      }
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = AuthService.currentUser;
    final isPG = currentUser?.role.name == 'pg';
    return Scaffold(
      appBar: CommonAppBar(
        title: 'Home',
        user: currentUser!,
        onLogout: () {
          AuthService.logout();
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        },
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadAssignedTasks();
          if (!isPG) {
            await _loadPGs();
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Total Patients',
                        _totalAssigned.toString(),
                        Colors.blue,
                        Icons.assignment,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Pending Review',
                        _pendingReview.toString(),
                        Colors.orange,
                        Icons.pending_actions,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Completed Review',
                        _completed.toString(),
                        Colors.green,
                        Icons.check_circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // PG Management Section - only show if user is a doctor, not a PG
                if (!isPG) ...[
                  _buildPGManagementSection(),
                  const SizedBox(height: 24),
                ],
                 Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                     const Text(
                       'Assigned Patients',
                       style: TextStyle(
                         fontSize: 20,
                         fontWeight: FontWeight.bold,
                       ),
                     ),
                     Text(
                       '${_tasks.length} tasks',
                       style: TextStyle(
                         fontSize: 14,
                         color: Colors.grey[600],
                       ),
                     ),
                   ],
                 ),
                const SizedBox(height: 12),
                if (_loading)
                  _buildLoading()
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
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPGManagementSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'PG Management',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _showCreatePGDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Create PG'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Search Bar
            TextField(
              controller: _pgSearchController,
              decoration: InputDecoration(
                labelText: 'Search PGs',
                hintText: 'Search by name or email',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _pgSearchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _pgSearchController.clear();
                          setState(() {
                            _pgSearchQuery = '';
                          });
                          _loadPGs();
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onChanged: (value) {
                setState(() {
                  _pgSearchQuery = value;
                });
              },
              onSubmitted: (value) {
                _loadPGs(search: value.trim().isEmpty ? null : value.trim());
              },
            ),
            const SizedBox(height: 12),
            if (_loadingPGs)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_pgError != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _pgError!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _loadPGs,
                      tooltip: 'Retry',
                    ),
                  ],
                ),
              )
            else if (_pgs.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                child: const Center(
                  child: Column(
                    children: [
                      Icon(Icons.person_off, size: 40, color: Colors.grey),
                      SizedBox(height: 8),
                      Text(
                        'No PGs created yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )
            else
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _pgs.length,
                  itemBuilder: (context, index) {
                    final sortedPgs = _pgs.toList()..sort((a, b) => b.isDuty ? 1 : -1);
                    final pg = sortedPgs[index];
                    // Minimal horizontal PG chip
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: InkWell(
                        onTap: () => _showPGOptionsDialog(pg),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 160,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: pg.isDuty ? Colors.green.withOpacity(0.08) : Colors.grey.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: pg.isDuty ? Colors.green.withOpacity(0.18) : Colors.grey.withOpacity(0.12)),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: pg.isDuty ? Colors.green.shade100 : Colors.blue.shade50,
                                child: Text(
                                  pg.name.isNotEmpty ? pg.name[0].toUpperCase() : 'P',
                                  style: TextStyle(
                                    color: pg.isDuty ? Colors.green.shade700 : Colors.blue.shade700,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      pg.name,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      pg.email,
                                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              if (pg.isDuty)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8.0),
                                  child: Icon(Icons.circle, color: Colors.green.shade400, size: 10),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() => const Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: CircularProgressIndicator(),
        ),
      );

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
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(Task task) {
    final hasResponse =
        (task.doctorFeedback != null && task.doctorFeedback!.isNotEmpty) ||
            task.status == 'completed';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: hasResponse
            ? const BorderSide(color: Colors.green, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TaskDetailScreen(task: task),
            ),
          );
          _loadAssignedTasks();
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.blue[100],
                    child: Text(
                      _getInitials(task.patientName ?? 'Patient'),
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.patientName ?? 'Unknown Patient',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          task.patientIdStr ?? 'ID Unknown',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    task.createdAt.toString().substring(0, 16),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.assignment_ind, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Technician: ${task.technicianName ?? 'Unknown'}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              if (hasResponse) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle, size: 16, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Reviewed',
                              style: TextStyle(fontSize: 13, color: Colors.green[700]),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (task.status == 'completed' && (task.doctorFeedback != null && task.doctorFeedback!.isNotEmpty))
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.green.withOpacity(0.12)),
                          ),
                          child: Text(
                            task.doctorFeedback!,
                            style: const TextStyle(fontSize: 13),
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
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            Icon(
              Icons.assignment,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            const Text(
              'No patients assigned yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

}
