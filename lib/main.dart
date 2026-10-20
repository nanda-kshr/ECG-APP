import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/push_service.dart';
import 'services/task_service.dart';
import 'screens/task_detail_screen.dart';
import 'screens/login_screen.dart';
import 'screens/user_dashboard.dart';
import 'screens/admin_dashboard.dart';
import 'screens/doctor_dashboard.dart';
import 'models/user.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('🔥 FCM BACKGROUND MESSAGE: ${message.messageId}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('🔥🔥 FCM MESSAGE RECEIVED');
        print('Message ID: ${message.messageId}');
        print('Title: ${message.notification?.title}');
        print('Body: ${message.notification?.body}');
        print('Data: ${message.data}');
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('🔥🔥 FCM MESSAGE OPENED');
        print('Message ID: ${message.messageId}');
      });

      FirebaseMessaging.instance.onTokenRefresh.listen((String token) {
        print('🔥🔥 FCM TOKEN REFRESHED: $token');
      });

      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      final messaging = FirebaseMessaging.instance;

      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      print('Permission: ${settings.authorizationStatus}');

      await Future.delayed(const Duration(seconds: 2));

      final apnsToken = await messaging.getAPNSToken();
      print('APNs Token: $apnsToken');

      if (apnsToken != null) {
        try {
          final fcmToken = await messaging.getToken();
          print('FCM Token: $fcmToken');
        } catch (e) {
          print('FCM error: $e');
        }
      }
    } catch (e) {
      print('Firebase initialization failed: $e');
    }
  }

  runApp(const MyApp());
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF3A418E);

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Simats Cardio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: primaryColor,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          primary: primaryColor,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryColor,
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
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
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
      backgroundColor: const Color(0xFF3A418E),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/logo/logo.png',
              width: 120,
              height: 120,
            ),
            const SizedBox(height: 24),
            const Text(
              'Simats Cardio',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          ],
        ),
      ),
    );
  }
}
