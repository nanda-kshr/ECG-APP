import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart';
import 'login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  _ResetPasswordScreenState createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  String email = '';
  String phone = '';
  String newPassword = '';
  String confirmPassword = '';
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  Future<void> _resetPassword() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final response = await http.post(
        Uri.parse('${apiBaseUrl}reset_password.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'phone': phone,
          'new_password': newPassword,
        }),
      );

      final result = jsonDecode(response.body);

      if (response.statusCode == 200 && result['success'] == true) {
        setState(() {
          _successMessage = 'Password reset successfully! Please login.';
          _isLoading = false;
        });
        // Delay to show success message before navigating
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
            );
          }
        });
      } else {
        setState(() {
          _errorMessage = result['error'] ?? 'Failed to reset password';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Connection error. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50],
      appBar: AppBar(
        title: const Text('Reset Password'),
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
                    Icon(Icons.lock_reset, size: 48, color: Colors.blue[600]),
                    const SizedBox(height: 24),
                    const Text(
                      'Enter your details to reset password',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 24),

                    // Email Field
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

                    // Phone Field
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        prefixIcon: const Icon(Icons.phone),
                        prefixText: '+91 ',
                        prefixStyle:
                            const TextStyle(color: Colors.black, fontSize: 16),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      keyboardType: TextInputType.number,
                      maxLength: 10,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (val) => phone = val,
                      validator: (val) {
                        if (val == null || val.isEmpty)
                          return 'Enter phone number';
                        if (val.length != 10)
                          return 'Phone number must be exactly 10 digits';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // New Password Field
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      obscureText: true,
                      onChanged: (val) => newPassword = val,
                      validator: (val) {
                        if (val == null || val.isEmpty)
                          return 'Enter new password';
                        if (val.length < 8)
                          return 'Password must be at least 8 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Confirm Password Field
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        prefixIcon: const Icon(Icons.lock),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      obscureText: true,
                      onChanged: (val) => confirmPassword = val,
                      validator: (val) {
                        if (val == null || val.isEmpty)
                          return 'Confirm new password';
                        if (val != newPassword) return 'Passwords do not match';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    if (_successMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          _successMessage!,
                          style: const TextStyle(color: Colors.green),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    SizedBox(
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
                                if (_formKey.currentState!.validate()) {
                                  _resetPassword();
                                }
                              },
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text('Reset Password',
                                style: TextStyle(
                                    fontSize: 18, color: Colors.white)),
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
