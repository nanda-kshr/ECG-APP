import 'package:flutter/material.dart';
import '../services/patient_service.dart';
import '../models/patient.dart';
import '../services/auth_service.dart';

class CreatePatientScreen extends StatefulWidget {
  const CreatePatientScreen({super.key});

  @override
  State<CreatePatientScreen> createState() => _CreatePatientScreenState();
}

class _CreatePatientScreenState extends State<CreatePatientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _contactController = TextEditingController(text: '+91 ');
  String _gender = 'male';
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // place cursor at end of default +91 prefix
    _contactController.selection = TextSelection.fromPosition(
        TextPosition(offset: _contactController.text.length));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    final currentUser = AuthService.currentUser;
    final age = int.tryParse(_ageController.text.trim());
    // normalize contact/phone before sending: if starts with + keep (compact), else prefix +91
    String? contactRaw = _contactController.text.trim();
    String? contactToSend;
    if (contactRaw.isNotEmpty) {
      final compact = contactRaw.replaceAll(RegExp(r'\s+'), '');
      if (compact.startsWith('+')) {
        contactToSend = compact;
      } else {
        var digits = compact.replaceFirst(RegExp(r'^0+'), '');
        if (digits.isNotEmpty) contactToSend = '+91' + digits;
        else contactToSend = null;
      }
    } else {
      contactToSend = null;
    }

    final res = await PatientService.createPatient(
      name: _nameController.text.trim(),
      age: age,
      gender: _gender.trim().isNotEmpty ? _gender : null,
      contact: contactToSend,
      createdBy: currentUser?.id,
    );
    setState(() {
      _isSaving = false;
    });
    if (res['success'] == true) {
      Patient? p;
      if (res['patient'] is Patient) {
        p = res['patient'] as Patient;
      } else if (res['patient_id'] != null) {
        // fallback minimal object
        // Use numeric 'id' from the API when available. Some APIs return only
        // a `patient_id` string (PAT...) along with a numeric `id` field; avoid
        // attempting to parse the PAT string as an int.
        final providedId = res['id'] != null ? int.tryParse(res['id'].toString()) : null;
        p = Patient(
          id: providedId ?? 0,
          patientId: res['patient_id'].toString(),
          name: _nameController.text.trim(),
          age: age,
          gender: _gender.isNotEmpty ? _gender : null,
          contact: contactToSend,
          createdAt: DateTime.now(),
        );
      }
      Navigator.pop(context, p);
    } else {
      setState(() {
        _error = res['error'] ?? 'Failed to create patient';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Patient')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                    labelText: 'Full Name *', border: OutlineInputBorder()),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Name required' : null,
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _ageController,
                    decoration: const InputDecoration(
                        labelText: 'Age', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _gender,
                    items: const [
                      DropdownMenuItem(value: 'male', child: Text('Male')),
                      DropdownMenuItem(value: 'female', child: Text('Female')),
                      DropdownMenuItem(value: 'other', child: Text('Other')),
                    ],
                    onChanged: (val) => setState(() => _gender = val ?? 'male'),
                    decoration: const InputDecoration(
                        labelText: 'Gender', border: OutlineInputBorder()),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contactController,
                decoration: const InputDecoration(
                    labelText: 'Contact',
                    border: OutlineInputBorder(),
                    hintText: 'Phone or email'),
              ),
              const SizedBox(height: 16),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child:
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
              ElevatedButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Create Patient'),
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _contactController.dispose();
    super.dispose();
  }
}
