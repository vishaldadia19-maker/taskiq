import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool backendReady = false;

  @override
  void initState() {
    super.initState();
    checkPrefs();
  }

  Future<void> checkPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    backendReady = prefs.getInt('user_id') != null;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        return Scaffold(
          body: Center(
            child: Text(
              "AuthGate OK\nfirebaseUser: ${snapshot.hasData}\nbackendReady: $backendReady",
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
    );
  }
}