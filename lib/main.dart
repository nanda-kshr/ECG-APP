import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'services/push_service.dart';
import 'services/task_service.dart';
import 'screens/task_detail_screen.dart';
import 'screens/login_screen.dart';
import 'screens/user_dashboard.dart';
import 'screens/admin_dashboard.dart';
import 'screens/doctor_dashboard.dart';
import 'models/user.dart';

void main() {
  runApp(const MyApp());
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Saveetha Cardio App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blue[600],
          foregroundColor: Colors.white,
          elevation: 4,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Initialize push service first so FCM token is available during login
    try {
      await PushService.initialize();
    } catch (e) {
      // ignore
    }

    await AuthService.initializeAuth();

    // Add a small delay for splash effect
    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      final isLoggedIn = await AuthService.isLoggedIn();

      // Wire push listeners to show in-app notifications and handle taps
      PushService.onMessage.listen((message) {
        final title = message.notification?.title ?? 'Notification';
        final body = message.notification?.body ?? '';
        final ctx = navigatorKey.currentContext;
        if (ctx != null) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: Text('$title — $body'),
              action: SnackBarAction(
                label: 'Open',
                onPressed: () => _handleNotificationTap(message.data),
              ),
            ),
          );
        }
      });

      PushService.onMessageOpened.listen((message) {
        _handleNotificationTap(message.data);
      });

      if (isLoggedIn) {
        _navigateToRoleBasedScreen();
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  Future<void> _handleNotificationTap(Map<String, dynamic> data) async {
    final taskIdStr = data['task_id']?.toString();
    if (taskIdStr != null) {
      final tid = int.tryParse(taskIdStr);
      if (tid != null) {
        // Try to fetch task details
        try {
          final t = await TaskService.getTaskById(tid);
          if (t != null) {
            navigatorKey.currentState?.push(
                MaterialPageRoute(builder: (_) => TaskDetailScreen(task: t)));
            return;
          }
        } catch (e) {
          // Task fetch failed, fall through to dashboard
        }
      }
    }

    // Fallback: navigate to dashboard based on role
    final user = AuthService.currentUser;
    if (user != null) {
      Widget screen;
      switch (user.role) {
        case UserRole.user:
          screen = const UserDashboard();
          break;
        case UserRole.admin:
          screen = const AdminDashboard();
          break;
        case UserRole.doctor:
        case UserRole.pg:
        default:
          screen = const DoctorDashboard();
          break;
      }
      navigatorKey.currentState
          ?.push(MaterialPageRoute(builder: (_) => screen));
    } else {
      // If no authorized user, go to login
      navigatorKey.currentState?.pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  void _navigateToRoleBasedScreen() {
    final user = AuthService.currentUser;
    if (user == null) {
      // If user unexpectedly null, navigate to login instead of crashing
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
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
      case UserRole.doctor || UserRole.pg:
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
      backgroundColor: Colors.blue[600],
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite,
              size: 80,
              color: Colors.white,
            ),
            SizedBox(height: 24),
            Text(
              'Saveetha Cardio App',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 16),
            CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          ],
        ),
      ),
    );
  }
}
