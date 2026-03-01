import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'services/auth_state.dart';
import 'screens/notifications_screen.dart';




final GlobalKey<NavigatorState> navigatorKey =
    GlobalKey<NavigatorState>();


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await _setupNotificationTapHandling(); // 👈 ADD THIS


  if (kIsWeb) {
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
    await FirebaseAuth.instance.getRedirectResult();
  }

  runApp(const MyApp());
}


Future<void> _setupNotificationTapHandling() async {
  // When app is in background
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    navigatorKey.currentState?.pushNamedAndRemoveUntil(
      "/notifications",
      (route) => false,
    );
  });

  // When app is terminated
  final initialMessage =
      await FirebaseMessaging.instance.getInitialMessage();

  if (initialMessage != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        "/notifications",
        (route) => false,
      );
    });
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      routes: {
      "/notifications": (context) => const NotificationsScreen(),
      },
      home: const AuthGate(),
    );    
  }
}

/// 🔐 AUTH GATE (Firebase + Backend)
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}


class _AuthGateState extends State<AuthGate> {

  @override
  void initState() {
    super.initState();
    _initBackendState(); // ✅ NOW it is called
  }

  Future<void> _initBackendState() async {
    print('🟡 Checking backend login state');

    final prefs = await SharedPreferences.getInstance();
    final hasUser = prefs.getInt('user_id') != null;

    print('🟢 Backend logged in: $hasUser');

    // ✅ ONLY mirror stored state
    AuthState.backendReady.value = hasUser;
  }
  

@override
Widget build(BuildContext context) {
  return StreamBuilder<User?>(
    stream: FirebaseAuth.instance.authStateChanges(),
    builder: (context, snapshot) {

      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }

      return ValueListenableBuilder<bool>(
        valueListenable: AuthState.backendReady,
        builder: (context, backendReady, _) {

          if (!backendReady) {
            return const LoginScreen();
          }

          return const DashboardScreen();
        },
      );      
    },
  );
}
  
}

