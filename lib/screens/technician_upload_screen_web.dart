import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:async';
import 'dart:ui' as ui; // ignore: unnecessary_import
import 'package:http_parser/http_parser.dart';
import '../services/auth_service.dart';
import 'package:http/http.dart' as http;
import '../services/patient_service.dart';
import '../models/patient.dart';
import '../services/task_service.dart';
import 'create_patient_screen.dart';

class TechnicianUploadScreen extends StatefulWidget {
  const TechnicianUploadScreen({super.key});

  @override
  State<TechnicianUploadScreen> createState() => _TechnicianUploadScreenState();
}

class _TechnicianUploadScreenState extends State<TechnicianUploadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final _patientSearchController = TextEditingController();

  String _selectedPriority = 'normal';
  List<html.File> _selectedImages = [];

  bool _isUploading = false;
  String? _errorMessage;
  String? _successMessage;

  // Camera state (Web)
  html.VideoElement? _video;
  html.MediaStream? _stream;
  bool _cameraReady = false;
  bool _isCapturing = false;
  String? _cameraError;
  late final String _cameraViewId;

  // patient search state
  List<Patient> _options = [];
  bool _searching = false;
  Patient? _selectedPatient;

  // Safely derive a MediaType for selected files across browsers (handles undefined/null type)
  MediaType _guessMediaType(html.File file) {
    String typeStr = '';
    try {
      final dynamic t = (file as dynamic).type; // some browsers may yield undefined
      if (t != null) {
        final s = t.toString();
        if (s.isNotEmpty && s != 'undefined') {
          typeStr = s;
        }
      }
    } catch (_) {}

    if (typeStr.isNotEmpty) {
      try {
        return MediaType.parse(typeStr);
      } catch (_) {}
    }

    final name = file.name.toLowerCase();
    if (name.endsWith('.png')) return MediaType('image', 'png');
    if (name.endsWith('.jpg') || name.endsWith('.jpeg')) {
      return MediaType('image', 'jpeg');
    }
    if (name.endsWith('.gif')) return MediaType('image', 'gif');
    if (name.endsWith('.bmp')) return MediaType('image', 'bmp');
    if (name.endsWith('.webp')) return MediaType('image', 'webp');

    return MediaType('application', 'octet-stream');
  }

  @override
  void initState() {
    super.initState();
    _cameraViewId = 'camera-preview-${DateTime.now().millisecondsSinceEpoch}';
    _setupCameraElement();
  }

  void _setupCameraElement() {
    _video = html.VideoElement()
      ..autoplay = true
      ..muted = true
      ..controls = false
      ..style.objectFit = 'cover'
      ..setAttribute('playsinline', 'true');
    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(_cameraViewId, (int viewId) {
      return _video!;
    });
  }

  Future<void> _startCamera() async {
    setState(() {
      _cameraError = null;
    });
    try {
      final mediaDevices = html.window.navigator.mediaDevices;
      if (mediaDevices == null) {
        setState(() => _cameraError = 'Media devices not supported');
        return;
      }
      final stream = await mediaDevices.getUserMedia({
        'video': {
          'facingMode': {'ideal': 'environment'}
        },
        'audio': false
      });
      _stream = stream;
      _video?.srcObject = stream;
      await _video?.play();
      setState(() => _cameraReady = true);
    } catch (e) {
      setState(() => _cameraError = 'Unable to access camera: $e');
    }
  }

  void _stopCamera() {
    try {
      _video?.pause();
      _video?.srcObject = null;
      _stream?.getTracks().forEach((t) => t.stop());
      _stream = null;
    } catch (_) {}
    setState(() => _cameraReady = false);
  }

  Future<void> _capturePhoto() async {
    if (_video == null) return;
    final video = _video!;
    if (!(video.readyState >= 2)) {
      setState(() => _cameraError = 'Camera not ready');
      return;
    }
    setState(() => _isCapturing = true);
    try {
      final width = video.videoWidth;
      final height = video.videoHeight;
      if (width == 0 || height == 0) {
        setState(() => _cameraError = 'Invalid video dimensions');
        return;
      }
      final canvas = html.CanvasElement(width: width, height: height);
      final ctx = canvas.context2D;
      ctx.drawImageScaled(video, 0, 0, width, height);

      final blob = await canvas.toBlob('image/jpeg', 0.92);
      final fileName = 'ecg_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = html.File([blob], fileName, {'type': 'image/jpeg'});
      setState(() {
        _selectedImages = [..._selectedImages, file];
        _errorMessage = null;
      });
    } catch (e) {
      setState(() => _cameraError = 'Capture failed: $e');
    } finally {
      setState(() => _isCapturing = false);
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

  Future<void> _openCreatePatient() async {
    final created = await Navigator.push<Patient>(
      context,
      MaterialPageRoute(builder: (_) => const CreatePatientScreen()),
    );
    if (created != null) {
      setState(() {
        _selectedPatient = created;
        _patientSearchController.text = created.displayInfo;
        _options = [];
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
      for (final file in _selectedImages) {
        final reader = html.FileReader();
        reader.readAsArrayBuffer(file);
        await reader.onLoad.first;
        List<int> bytes;
        final result = reader.result;
        if (result is ByteBuffer) {
          bytes = result.asUint8List();
        } else if (result is Uint8List) {
          bytes = result;
        } else if (result is List<int>) {
          bytes = result;
        } else {
          bytes = (result as List).cast<int>();
        }
        final contentType = _guessMediaType(file);
        files.add(http.MultipartFile.fromBytes('image[]', bytes,
            filename: file.name, contentType: contentType));
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
          _successMessage =
              'ECG uploaded and task auto-assigned to duty doctor. Task ID: ${result['task_id']}, Patient: ${_selectedPatient!.displayInfo}';
          _notesController.clear();
          _selectedImages = [];
          _selectedPatient = null;
          _patientSearchController.clear();
          _selectedPriority = 'normal';
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
              const Text('Patient',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              // Patient search/select UI
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
                              child: CircularProgressIndicator(strokeWidth: 2)),
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
              if (_options.isNotEmpty)
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
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

              const SizedBox(height: 20),

              const Text('ECG Images',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Camera preview area
                    AspectRatio(
                      aspectRatio: 3 / 4,
                      child: Container(
                        clipBehavior: Clip.hardEdge,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _cameraReady
                            ? HtmlElementView(viewType: _cameraViewId)
                            : Center(
                                child: Text(
                                  _cameraError == null
                                      ? 'Camera not started'
                                      : _cameraError!,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _cameraReady ? null : _startCamera,
                          icon: const Icon(Icons.videocam),
                          label: const Text('Open Camera'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: (!_cameraReady || _isCapturing) ? null : _capturePhoto,
                          icon: _isCapturing
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.camera_alt),
                          label: const Text('Capture'),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: _cameraReady ? _stopCamera : null,
                          icon: const Icon(Icons.stop_circle_outlined),
                          label: const Text('Stop'),
                        ),
                      ],
                    ),
                    if (_selectedImages.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _selectedImages
                            .map((file) => Chip(
                                  label: Text(file.name,
                                      overflow: TextOverflow.ellipsis),
                                  onDeleted: () {
                                    setState(() => _selectedImages.remove(file));
                                  },
                                ))
                            .toList(),
                      ),
                    ],
                  ],
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
                  labelText: 'Notes (optional)',
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

              ElevatedButton(
                onPressed: _isUploading ? null : _uploadECG,
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: Colors.blue),
                child: _isUploading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Upload & Submit',
                        style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _stopCamera();
    _notesController.dispose();
    _patientSearchController.dispose();
    super.dispose();
  }
}
