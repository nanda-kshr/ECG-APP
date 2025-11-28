import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'signup_screen.dart';

// Make sure you import your dashboard screens and UserRole enum
import '../models/user.dart';
import 'admin_dashboard.dart';
import 'doctor_dashboard.dart';
import 'technician_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key}); // Add const constructor

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  String email = '', password = '';
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Use updated AuthService signature (email/password)
    final success = await AuthService.login(email, password);

    setState(() {
      _isLoading = false;
    });

    if (success) {
      _navigateToRoleBasedScreen();
    } else {
      setState(() {
        _errorMessage = 'Invalid email or password';
      });
    }
  }

  void _navigateToRoleBasedScreen() {
    // Use static property
    final user = AuthService.currentUser;
    if (user == null) {
      setState(() {
        _errorMessage = 'User not found after login.';
      });
      return;
    }
    Widget screen;

    switch (user.role) {
      case UserRole.technician:
        screen = const TechnicianDashboard();
        break;
      case UserRole.admin:
        screen = const AdminDashboard();
        break;
      case UserRole.doctor:
        screen = const DoctorDashboard();
        break;
      case UserRole.pg:
        screen = const DoctorDashboard();
        break;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50],
      appBar: AppBar(
        title: const Text('Sign In'),
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
                  children: [
                    Icon(Icons.favorite, size: 48, color: Colors.blue[600]),
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
                      validator: (val) =>
                          val == null || val.isEmpty ? 'Enter password' : null,
                    ),
                    const SizedBox(height: 16),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(_errorMessage!,
                          style: const TextStyle(color: Colors.red)),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _isLoading
                            ? null
                            : () {
                                if (_formKey.currentState!.validate()) _login();
                              },
                        child: _isLoading
                          ? const CircularProgressIndicator(
                            color: Colors.white)
                          : const Text('Sign In',
                            style: TextStyle(fontSize: 18, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.blue[600],
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                        icon: const Icon(Icons.person_add, size: 18),
                        label: Text('Sign Up',
                            style: TextStyle(fontSize: 14, color: Colors.blue[600])),
                        onPressed: () {
                          // Only allow technician self-signup from the login screen.
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (context) => const SignUpScreen(
                                    forceRole: 'technician')),
                          );
                        },
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
