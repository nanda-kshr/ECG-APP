import 'package:flutter/material.dart';
import '../services/task_service.dart';
import '../services/auth_service.dart';
import '../services/patient_service.dart';
import '../models/patient.dart';
import 'create_patient_screen.dart';

class AssignTaskScreen extends StatefulWidget {
  const AssignTaskScreen({super.key});

  @override
  State<AssignTaskScreen> createState() => _AssignTaskScreenState();
}

class _AssignTaskScreenState extends State<AssignTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final _patientSearchController = TextEditingController();
  String _selectedPriority = 'normal';
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  Patient? _selectedPatient;
  List<Patient> _options = [];
  bool _searching = false;

  Future<void> _searchPatients(String query) async {
    setState(() {
      _searching = true;
    });
    final results = await PatientService.searchPatients(query: query);
    setState(() {
      _options = results;
      _searching = false;
    });
  }

  Future<void> _createTask() async {
    if (_selectedPatient == null) {
      setState(() {
        _errorMessage = 'Select a patient';
      });
      return;
    }
    final currentUser = AuthService.currentUser;
    if (currentUser == null) {
      setState(() => _errorMessage = 'Not logged in');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final result = await TaskService.createTask(
      patientId: _selectedPatient!.id,
      userId: currentUser.id,
      notes: _notesController.text.trim(),
      priority: _selectedPriority,
    );
    setState(() {
      _isLoading = false;
      if (result['success'] == true) {
        _successMessage =
            'ECG created (ID: ${result['task_id']}) and auto-assigned to duty doctor';
        _selectedPatient = null;
        _patientSearchController.clear();
        _notesController.clear();
        _selectedPriority = 'normal';
      } else {
        _errorMessage = result['error'] ?? 'Failed to create task';
      }
    });
  }

  Future<void> _openCreatePatient() async {
    final created = await Navigator.push<Patient>(
      context,
      MaterialPageRoute(builder: (_) => const CreatePatientScreen()),
    );
    if (created != null) {
      setState(() {
        _selectedPatient = created;
        _patientSearchController.text = created.displayInfo;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Create Task for Patient'),
          backgroundColor: Colors.blue),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Text('Existing Patient Task',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              // Patient searchable dropdown
              TextField(
                controller: _patientSearchController,
                decoration: InputDecoration(
                  labelText: 'Patient *',
                  hintText: 'Search by name or ID',
                  border: const OutlineInputBorder(),
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2)))
                      : IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: () => _searchPatients(
                              _patientSearchController.text.trim()),
                        ),
                ),
                onSubmitted: (q) => _searchPatients(q.trim()),
              ),
              const SizedBox(height: 8),
              if (_options.isNotEmpty)
                Container(
                  decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    children: [
                      ..._options.map((p) => ListTile(
                            title: Text(p.name),
                            subtitle: Text(p.displayInfo),
                            onTap: () {
                              setState(() {
                                _selectedPatient = p;
                                _options = [];
                                _patientSearchController.text = p.displayInfo;
                              });
                            },
                          )),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.person_add),
                        title: const Text('Create new patient'),
                        onTap: _openCreatePatient,
                      ),
                    ],
                  ),
                )
              else
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _openCreatePatient,
                    icon: const Icon(Icons.person_add),
                    label: const Text('Create new'),
                  ),
                ),

              const SizedBox(height: 16),

              // DropdownButtonFormField<String>(
              //   initialValue: _selectedPriority,
              //   decoration: const InputDecoration(
              //       labelText: 'Priority', border: OutlineInputBorder()),
              //   items: const [
              //     DropdownMenuItem(value: 'low', child: Text('Low')),
              //     DropdownMenuItem(value: 'normal', child: Text('Normal')),
              //     DropdownMenuItem(value: 'high', child: Text('High')),
              //     DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
              //   ],
              //   onChanged: (val) =>
              //       setState(() => _selectedPriority = val ?? 'normal'),
              // ),
              // const SizedBox(height: 16),

              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    border: OutlineInputBorder(),
                    hintText: 'Additional context'),
                maxLines: 3,
              ),
              const SizedBox(height: 20),

              if (_errorMessage != null)
                Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    color: Colors.red.shade100,
                    child: Text(_errorMessage!,
                        style: const TextStyle(color: Colors.red))),
              if (_successMessage != null)
                Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    color: Colors.green.shade100,
                    child: Text(_successMessage!,
                        style: const TextStyle(color: Colors.green))),

              ElevatedButton(
                onPressed: _isLoading ? null : _createTask,
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: Colors.blue),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Create Task'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    _patientSearchController.dispose();
    super.dispose();
  }
}
