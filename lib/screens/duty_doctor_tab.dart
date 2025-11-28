import 'dart:async';
import 'package:flutter/material.dart';
import '../models/doctor.dart';
import '../services/doctor_service.dart';
import '../services/auth_service.dart';
import 'add_doctor_screen.dart';

class DutyDoctorTab extends StatefulWidget {
  const DutyDoctorTab({super.key});

  @override
  State<DutyDoctorTab> createState() => _DutyDoctorTabState();
}

class _DutyDoctorTabState extends State<DutyDoctorTab> {
  final _searchController = TextEditingController();
  List<Doctor> _doctors = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _total = 0;
  String _searchQuery = '';
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _loadDoctors();
  }

  Future<void> _loadDoctors({String? search}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    print('DutyDoctorTab: Loading doctors with search: $search');
    final result = await DoctorService.listDoctors(
      search: search,
      limit: 100,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success'] == true) {
          _doctors = result['doctors'] as List<Doctor>;
          _total = result['total'] ?? _doctors.length;
          print('DutyDoctorTab: Loaded ${_doctors.length} doctors');
        } else {
          _errorMessage = result['error'] ?? 'Failed to load doctors';
          print('DutyDoctorTab: Error - $_errorMessage');
        }
      });
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query != _searchQuery) {
      // update UI immediately so the clear icon appears/disappears
      setState(() {
        _searchQuery = query;
      });
      // debounce to avoid sending a request for every keystroke
      _searchDebounce?.cancel();
      _searchDebounce = Timer(const Duration(milliseconds: 350), () {
        _loadDoctors(search: query.isEmpty ? null : query);
      });
    }
  }

  Future<void> _setDutyDoctor(Doctor doctor) async {
    final currentUser = AuthService.currentUser;
    if (currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not logged in')),
        );
      }
      return;
    }

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Duty Doctor'),
        content: Text('Set ${doctor.name} as the current duty doctor?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    final result = await DoctorService.setDutyDoctor(
      adminId: currentUser.id,
      doctorId: doctor.id,
    );

    setState(() => _isLoading = false);

    if (mounted) {
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${doctor.name} is now on duty')),
        );
        _loadDoctors(search: _searchQuery.isEmpty ? null : _searchQuery);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Failed to set duty doctor'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToAddDoctor() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddDoctorScreen()),
    );

    if (result == true) {
      // Refresh the list after adding a doctor
      _loadDoctors(search: _searchQuery.isEmpty ? null : _searchQuery);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Duty Doctors'),
        leading: const BackButton(),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search doctors',
                      hintText: 'Search by name or email',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                // ensure UI updates immediately
                                setState(() {
                                  _searchQuery = '';
                                });
                                _loadDoctors();
                              },
                            )
                          : null,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => _onSearchChanged(),
                    onSubmitted: (_) => _loadDoctors(
                        search: _searchController.text.trim().isEmpty
                            ? null
                            : _searchController.text.trim()),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => _loadDoctors(
                    search: _searchQuery.isEmpty ? null : _searchQuery,
                  ),
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ),

          // Count Badge
          if (!_isLoading && _doctors.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Total Doctors: $_total',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

          const SizedBox(height: 8),

          // Loading or Error
          if (_isLoading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_errorMessage != null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(_errorMessage!,
                        style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _loadDoctors(
                        search: _searchQuery.isEmpty ? null : _searchQuery,
                      ),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else if (_doctors.isEmpty)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_off, size: 48, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No doctors found', style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            )
          else
            // Doctor List
            Expanded(
              child: ListView.builder(
                itemCount: _doctors.length,
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                itemBuilder: (context, index) {
                  final doctor = _doctors[index];
                  return _DoctorCard(
                    doctor: doctor,
                    onSetDuty: () => _setDutyDoctor(doctor),
                    onViewProfile: () {
                      showDialog<void>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(doctor.name),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Email: ${doctor.email}'),
                              if (doctor.department != null)
                                Text('Department: ${doctor.department}'),
                              if (doctor.dutyDate != null)
                                Text(
                                    'Duty: ${doctor.dutyDate} ${doctor.shift ?? ''}'),
                            ],
                          ),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Close')),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddDoctor,
        tooltip: 'Add New Doctor',
        child: const Icon(Icons.add),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }
}

class _DoctorCard extends StatelessWidget {
  final Doctor doctor;
  final VoidCallback onSetDuty;
  final VoidCallback? onViewProfile;

  const _DoctorCard({
    required this.doctor,
    required this.onSetDuty,
    this.onViewProfile,
  });

  @override
  Widget build(BuildContext context) {
    final isOnDuty = doctor.isOnDutyToday;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isOnDuty ? Colors.green : Colors.blue,
          child: Text(
            doctor.name.isNotEmpty ? doctor.name[0].toUpperCase() : 'D',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          doctor.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.email, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    doctor.email,
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
            if (doctor.department != null && doctor.department!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.local_hospital,
                      size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    doctor.department!,
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  isOnDuty ? Icons.check_circle : Icons.cancel,
                  size: 14,
                  color: isOnDuty ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  doctor.dutyStatusDisplay,
                  style: TextStyle(
                    fontSize: 13,
                    color: isOnDuty ? Colors.green : Colors.grey[600],
                    fontWeight: isOnDuty ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (val) {
            if (val == 'setDuty') onSetDuty();
            if (val == 'profile' && onViewProfile != null) onViewProfile!();
          },
          itemBuilder: (ctx) => [
            if (!isOnDuty)
              const PopupMenuItem(
                  value: 'setDuty',
                  child: ListTile(
                      leading: Icon(Icons.assignment_ind),
                      title: Text('Set Duty'))),
            const PopupMenuItem(
                value: 'profile',
                child: ListTile(
                    leading: Icon(Icons.person), title: Text('Profile'))),
          ],
          child: isOnDuty
              ? Chip(
                  label: const Text('On Duty'),
                  backgroundColor: Colors.green.shade50,
                  labelStyle: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                )
              : OutlinedButton.icon(
                  onPressed: onSetDuty,
                  icon: const Icon(Icons.assignment_ind, size: 16),
                  label: const Text('Set Duty'),
                  style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
        ),
        isThreeLine: true,
      ),
    );
  }
}
