import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'services/auth_state.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (kIsWeb) {
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
    await FirebaseAuth.instance.getRedirectResult();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AuthGate(),
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

