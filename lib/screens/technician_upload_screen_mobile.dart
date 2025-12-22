import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../services/auth_service.dart';
import '../services/patient_service.dart';
import '../models/patient.dart';
import '../services/task_service.dart';

class TechnicianUploadScreen extends StatefulWidget {
  const TechnicianUploadScreen({super.key});

  @override
  State<TechnicianUploadScreen> createState() => _TechnicianUploadScreenState();
}

class _TechnicianUploadScreenState extends State<TechnicianUploadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final _patientSearchController = TextEditingController();

  // New controllers for create patient
  final _nameController = TextEditingController();
  final _contactController = TextEditingController(text: '+91 ');

  String _selectedPriority = 'normal';
  final ImagePicker _picker = ImagePicker();
  List<XFile> _selectedImages = [];

  bool _isUploading = false;
  String? _errorMessage;
  String? _successMessage;

  // patient search state
  List<Patient> _options = [];
  bool _searching = false;
  Patient? _selectedPatient;

  // create patient state
  String _gender = 'male';
  bool _isCreatingPatient = false;
  String? _createError;

  // pending images count
  int _pendingCount = 0;
  bool _loadingPendingCount = false;

  @override
  void initState() {
    super.initState();
    _fetchPendingCount();
  }

  Future<void> _fetchPendingCount() async {
    setState(() => _loadingPendingCount = true);
    final count = await TaskService.getPendingImagesCount();
    setState(() {
      _pendingCount = count;
      _loadingPendingCount = false;
    });
  }

  String _formatEstimatedTime(int count) {
    final totalMinutes = count * 15;
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  Future<void> _captureFromCamera() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 90,
      );
      if (image != null) {
        setState(() {
          _selectedImages = [..._selectedImages, image];
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() => _errorMessage = 'Camera error: $e');
    }
  }

  Future<void> _searchPatients(String query) async {
    setState(() => _searching = true);
    final results = await PatientService.searchPatients(query: query);
    setState(() {
      _options = results;
      _searching = false;
    });
  }

  Future<void> _createPatient() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _createError = 'Name is required');
      return;
    }
    setState(() {
      _isCreatingPatient = true;
      _createError = null;
    });
    // normalize phone: if starts with '+', keep (but strip spaces);
    // otherwise, remove leading zeros/spaces and prefix +91
    String? contactRaw = _contactController.text.trim();
    String? contactToSend;
    if (contactRaw.isNotEmpty) {
      // remove internal spaces
      final compact = contactRaw.replaceAll(RegExp(r'\s+'), '');
      if (compact.startsWith('+')) {
        contactToSend = compact;
      } else {
        var digits = compact.replaceFirst(RegExp(r'^0+'), '');
        if (digits.isNotEmpty)
          contactToSend = '+91' + digits;
        else
          contactToSend = null;
      }
    } else {
      contactToSend = null;
    }

    final res = await PatientService.createPatient(
      name: _nameController.text.trim(),
      age: null, // not using age
      gender: _gender.trim().isNotEmpty ? _gender : null,
      contact: contactToSend,
      createdBy: AuthService.currentUser?.id,
    );
    setState(() => _isCreatingPatient = false);
    if (res['success'] == true) {
      Patient? p;
      if (res['patient'] is Patient) {
        p = res['patient'] as Patient;
      } else if (res['patient_id'] != null || res['id'] != null) {
        final providedId =
            res['id'] != null ? int.tryParse(res['id'].toString()) : null;
        p = Patient(
          id: providedId ?? 0,
          patientId:
              res['patient_id'] != null ? res['patient_id'].toString() : '',
          name: _nameController.text.trim(),
          age: null,
          gender: _gender.isNotEmpty ? _gender : null,
          contact: contactToSend,
          createdAt: DateTime.now(),
        );
      }
      setState(() {
        _selectedPatient = p;
        _patientSearchController.text = p?.displayInfo ?? '';
        _options = [];
        _nameController.clear();
        _contactController.text = '+91 ';
        _gender = 'male';
      });
    } else {
      setState(() {
        _createError = res['error'] ?? 'Failed to create patient';
      });
    }
  }

  Future<void> _uploadECG() async {
    if (_selectedPatient == null) {
      setState(() => _errorMessage = 'Please select a patient');
      return;
    }
    if (_selectedImages.isEmpty) {
      setState(() => _errorMessage = 'Please select at least one ECG image');
      return;
    }

    final currentUser = AuthService.currentUser;
    if (currentUser == null) {
      setState(() => _errorMessage = 'Not logged in');
      return;
    }

    setState(() {
      _isUploading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final files = <http.MultipartFile>[];
      for (final x in _selectedImages) {
        final bytes = await x.readAsBytes();
        final lower = x.name.toLowerCase();
        MediaType? ct;
        if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
          ct = MediaType('image', 'jpeg');
        } else if (lower.endsWith('.png')) {
          ct = MediaType('image', 'png');
        } else if (lower.endsWith('.gif')) {
          ct = MediaType('image', 'gif');
        }
        files.add(http.MultipartFile.fromBytes(
          'image[]',
          bytes,
          filename: x.name,
          contentType: ct,
        ));
      }

      final result = await TaskService.createTaskMultipart(
        patientId: _selectedPatient!.id,
        technicianId: currentUser.id,
        notes: _notesController.text.trim(),
        priority: _selectedPriority,
        files: files,
      );

      setState(() {
        _isUploading = false;
        if (result['success'] == true) {
          _successMessage = 'ECG uploaded';
          _fetchPendingCount(); // Refresh queue count after upload
          _notesController.clear();
          _selectedImages = [];
          _selectedPatient = null;
          _patientSearchController.clear();
          _selectedPriority = 'normal';
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          });
        } else {
          _errorMessage = result['error'] ?? 'Upload failed';
        }
      });
    } catch (e) {
      setState(() {
        _isUploading = false;
        _errorMessage = 'Upload error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload ECG'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Patient',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _patientSearchController,
                        decoration: InputDecoration(
                          labelText: 'Search patient *',
                          hintText: 'Search by name or ID',
                          border: const OutlineInputBorder(),
                          suffixIcon: _searching
                              ? const Padding(
                                  padding: EdgeInsets.all(10),
                                  child: SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2)),
                                )
                              : IconButton(
                                  icon: const Icon(Icons.search),
                                  onPressed: () => _searchPatients(
                                      _patientSearchController.text.trim()),
                                ),
                        ),
                        onSubmitted: (q) => _searchPatients(q.trim()),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            if (_options.isNotEmpty) ...[
                              ..._options.map((p) => ListTile(
                                    title: Text(p.name),
                                    subtitle: Text(p.displayInfo),
                                    onTap: () {
                                      setState(() {
                                        _selectedPatient = p;
                                        _options = [];
                                        _patientSearchController.text =
                                            p.displayInfo;
                                      });
                                    },
                                  )),
                              const Divider(height: 1),
                            ],
                          ],
                        ),
                      ),
                      if (_selectedPatient == null) ...[
                        const SizedBox(height: 16),
                        const Text('Or Enter Patient Details',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Full Name *',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _contactController,
                          decoration: const InputDecoration(
                            labelText: 'Contact',
                            border: OutlineInputBorder(),
                            hintText: 'Phone or email',
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_createError != null)
                          Text(_createError!,
                              style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _isCreatingPatient ? null : _createPatient,
                          child: _isCreatingPatient
                              ? const CircularProgressIndicator()
                              : const Text('Add Patient'),
                        ),
                      ],
                      const SizedBox(height: 30),
                      const Text('ECG Images',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _captureFromCamera,
                          icon: const Icon(Icons.camera_alt, size: 28),
                          label: Text(
                            _selectedImages.isEmpty
                                ? 'Capture ECG'
                                : 'Capture ECG (${_selectedImages.length} selected)',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                vertical: 16, horizontal: 24),
                            backgroundColor: Colors.blue.shade600,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ),
                      if (_selectedImages.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Selected Images:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: _selectedImages
                              .map((file) => Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: Colors.grey.shade300),
                                    ),
                                    child: Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: Image.file(
                                            File(file.path),
                                            fit: BoxFit.cover,
                                            width: 100,
                                            height: 100,
                                          ),
                                        ),
                                        Positioned(
                                          top: 4,
                                          right: 4,
                                          child: GestureDetector(
                                            onTap: () {
                                              setState(() =>
                                                  _selectedImages.remove(file));
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: const BoxDecoration(
                                                color: Colors.red,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.close,
                                                size: 16,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ))
                              .toList(),
                        ),
                      ],
                    ],
                  ),
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

              const SizedBox(height: 16),

              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Short Clinical History',
                  border: OutlineInputBorder(),
                  hintText: 'Additional information or observations',
                ),
                maxLines: 3,
              ),

              const SizedBox(height: 20),

              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  color: Colors.red.shade100,
                  child: Text(_errorMessage!,
                      style: const TextStyle(color: Colors.red)),
                ),

              if (_successMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  color: Colors.green.shade100,
                  child: Text(_successMessage!,
                      style: const TextStyle(color: Colors.green)),
                ),

              if (!_isUploadAllowed()) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.yellow.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  // child: Row(
                  //   children: [
                  //     const Icon(Icons.info, color: Colors.orange),
                  //     const SizedBox(width: 8),
                  //     Expanded(
                  //       child: Text(
                  //         'Uploads are allowed Mon–Fri 08:00–15:00 IST. Current IST time: ${_currentIstString()}',
                  //         style: const TextStyle(color: Colors.black87),
                  //       ),
                  //     ),
                  //   ],
                  // ),
                ),
              ],

              // Emergency warning: concise and fits the section

              ElevatedButton(
                onPressed: _isUploading
                    ? null
                    : (_isUploadAllowed()
                        ? _uploadECG
                        : _showUploadDisabledDialog),
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    backgroundColor:
                        _isUploadAllowed() ? Colors.blue : Colors.grey),
                child: _isUploading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Upload & Submit',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        )),
              ),

              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade100),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.red),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'If this is an emergency, call Emergency Department: (044) 6672 6612',
                        style: TextStyle(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isUploadAllowed() {
    final ist =
        DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
    final weekday = ist.weekday;
    if (weekday < DateTime.monday || weekday > DateTime.friday) return false;
    final hour = ist.hour;
    return hour >= 8 && hour < 15;
  }

  String _currentIstString() {
    final ist =
        DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
    return '${ist.hour.toString().padLeft(2, '0')}:${ist.minute.toString().padLeft(2, '0')} IST';
  }

  void _showUploadDisabledDialog() {
    // final now = _currentIstString();
    // showDialog<void>(
    //   context: context,
    //   barrierDismissible: true,
    //   builder: (context) => AlertDialog(
    //     title: const Text('Upload Disabled'),
    //     content: Text('Uploads are allowed Mon–Fri 08:00–15:00 IST. Current IST time: $now'),
    //     actions: [
    //       TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
    //     ],
    //   ),
    // );
  }

  @override
  void dispose() {
    _notesController.dispose();
    _patientSearchController.dispose();
    _nameController.dispose();
    _contactController.dispose();
    super.dispose();
  }
}
