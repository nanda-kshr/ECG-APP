import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/push_service.dart';
import 'signup_screen.dart';

// Make sure you import your dashboard screens and UserRole enum
import '../models/user.dart';
import 'admin_dashboard.dart';
import 'doctor_dashboard.dart';
import 'user_dashboard.dart';
import 'reset_password_screen.dart';

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
    final status = await AuthService.login(email, password);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    switch (status) {
      case LoginStatus.success:
        try {
          await PushService.ensureRegisteredAfterLogin();
        } catch (e) {
          // non-fatal
        }
        _navigateToRoleBasedScreen();
        break;

      case LoginStatus.accountNotFound:
        _showAccountNotFoundDialog();
        break;

      case LoginStatus.invalidCredentials:
        setState(() {
          _errorMessage = 'Invalid email or password';
        });
        break;

      case LoginStatus.serverError:
        setState(() {
          _errorMessage = 'Server error. Please try again later.';
        });
        break;

      default:
        setState(() {
          _errorMessage = 'An unknown error occurred.';
        });
    }
  }

  void _showAccountNotFoundDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Account Not Found'),
        content: const Text(
            "We couldn't find an account with that email. Would you like to create a new one?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop(); // close dialog
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (context) =>
                        const SignUpScreen(forceRole: 'user')),
              );
            },
            child: const Text('Sign Up'),
          ),
        ],
      ),
    );
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
      case UserRole.user:
        screen = const UserDashboard();
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
                    Icon(Icons.login, size: 48, color: Colors.blue[600]),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Email or Phone Number',
                        prefixIcon: const Icon(Icons.person),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (val) => email = val,
                      validator: (val) {
                        if (val == null || val.isEmpty)
                          return 'Enter email or phone';
                        // Basic validation: Contains '@' (email) OR is digits (phone)
                        bool isEmail = val.contains('@');
                        bool isPhone = RegExp(r'^\d+$').hasMatch(val);
                        if (!isEmail && !isPhone)
                          return 'Enter a valid email or phone number';
                        return null;
                      },
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
                                style: TextStyle(
                                    fontSize: 18, color: Colors.white)),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (context) =>
                                    const ResetPasswordScreen()),
                          );
                        },
                        child: const Text('Forgot Password?',
                            style: TextStyle(color: Colors.blue)),
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
                            style: TextStyle(
                                fontSize: 14, color: Colors.blue[600])),
                        onPressed: () {
                          // Only allow user self-signup from the login screen.
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (context) =>
                                    const SignUpScreen(forceRole: 'user')),
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
