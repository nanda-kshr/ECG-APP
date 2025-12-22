import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart';

class SignUpScreen extends StatefulWidget {
  // If forceRole is provided, the signup form will be locked to that role and
  // the role selector will be hidden. Use this to allow only technician signups
  // from the home/login screen.
  final String? forceRole;

  const SignUpScreen({super.key, this.forceRole});

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  static const String apiBase = apiBaseUrl;
  final _formKey = GlobalKey<FormState>();
  String name = '', email = '', password = '';
  String? role;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // If sign-up is forced to a specific role, initialize the form value.
    if (widget.forceRole != null) {
      role = widget.forceRole;
    }
  }

  Future<void> _register() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final response = await http.post(
      Uri.parse('${apiBase}register.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(
          {'name': name, 'email': email, 'password': password, 'role': role}),
    );

    setState(() {
      _isLoading = false;
    });

    if (response.statusCode == 200 &&
        jsonDecode(response.body)['success'] == true) {
      Navigator.of(context).pop(); // Go back to login
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registered successfully')));
    } else {
      // Try to parse server error for a friendlier message
      String? serverMessage;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map)
          serverMessage =
              decoded['error']?.toString() ?? decoded['detail']?.toString();
      } catch (_) {}
      setState(() {
        _errorMessage = serverMessage ?? 'Registration failed';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50],
      appBar: AppBar(
        title: const Text('Sign Up'),
        backgroundColor: Colors.blue[600],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 8,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.person_add, size: 48, color: Colors.blue[600]),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Name',
                        prefixIcon: const Icon(Icons.person),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (val) => name = val,
                      validator: (val) =>
                          val == null || val.isEmpty ? 'Enter name' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: const Icon(Icons.email),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (val) => email = val,
                      validator: (val) =>
                          val == null || val.isEmpty ? 'Enter email' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      obscureText: true,
                      onChanged: (val) => password = val,
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Enter password';
                        if (val.length < 8)
                          return 'Password must be at least 8 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // If a forceRole was provided (e.g. from Login), lock the signup to that role
                    if (widget.forceRole == null) ...[
                        DropdownButtonFormField<String>(
                        initialValue: role,
                        items: ['doctor', 'technician']
                          .map((r) => DropdownMenuItem(
                              value: r,
                              child: Text(r == 'technician'
                                ? 'Clinic Doctor'
                                : (r == 'doctor' ? 'Doctor' : r)),
                            ))
                          .toList(),
                        onChanged: (val) => setState(() => role = val),
                        decoration: InputDecoration(
                          labelText: 'Role',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        validator: (val) =>
                            val == null || val.isEmpty ? 'Select role' : null,
                      ),
                    ] else ...[
                      // Show a read-only field indicating the forced role
                      TextFormField(
                        initialValue: widget.forceRole == 'technician'
                            ? 'Clinic Doctor'
                            : (widget.forceRole == 'doctor'
                                ? 'Doctor'
                                : widget.forceRole),
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Role',
                          prefixIcon: const Icon(Icons.admin_panel_settings),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _isLoading
                            ? null
                            : () {
                                if (_formKey.currentState!.validate()) _register();
                              },
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Sign Up', style: TextStyle(fontSize: 18, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
