import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/auth_state.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../services/fcm_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {

  final TextEditingController _usernameController =
      TextEditingController();
  final TextEditingController _passwordController =
      TextEditingController();

  bool hidePassword = true;
  bool isLoading = false;
  bool rememberMe = false;

  @override
  void initState() {
    super.initState();
    _loadRememberedUser();
  }

  /// 🔥 Load Saved Credentials
  Future<void> _loadRememberedUser() async {
    final prefs = await SharedPreferences.getInstance();

    final savedRemember = prefs.getBool('remember_me') ?? false;

    if (savedRemember) {
      setState(() {
        rememberMe = true;
        _usernameController.text =
            prefs.getString('saved_username') ?? '';
        _passwordController.text =
            prefs.getString('saved_password') ?? '';
      });
    }
  }



Future<void> _loginWithUsername() async {

  if (_usernameController.text.trim().isEmpty ||
      _passwordController.text.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Enter username & password")),
    );
    return;
  }

  setState(() => isLoading = true);

  String? fcmToken;

  if (!kIsWeb) {
  try {
    final messaging = FirebaseMessaging.instance;

    // 🔥 Request permission FIRST
    NotificationSettings settings =
        await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    print("🔔 Permission status: ${settings.authorizationStatus}");

    if (settings.authorizationStatus ==
        AuthorizationStatus.authorized) {

      String? token = await messaging.getToken();
      print("📲 LOGIN TOKEN: $token");

      fcmToken = token;
    } else {
      print("❌ Notification permission not granted");
      fcmToken = null;
    }
  } catch (e) {
    print("FCM token error: $e");
    fcmToken = null;
  }
}


  final result = await AuthService().loginWithUsername(
    username: _usernameController.text.trim(),
    password: _passwordController.text,
    fcmToken: fcmToken, // 👈 send token here
  );

  setState(() => isLoading = false);

  if (result['success'] == true) {

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('user_id', result['user']['id']);

    // 🔥 Debug before FCM
    await AuthService().postDebug({
      "step": "before_fcm_init",
      "user": result['user']['id']
    });

    // 🔥 Init FCM
    FCMService.init(result['user']['id']); // remove await

    // 🔥 Debug after FCM
    await AuthService().postDebug({
      "step": "after_fcm_init",
      "user": result['user']['id']
    });

    // 🔥 ONLY NOW change state
    AuthState.backendReady.value = true;
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result['error'] ?? "Login failed")),
    );
  }
}
  

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }



Future<void> _updateFCMToken(int userId) async {
  try {
    final messaging = FirebaseMessaging.instance;

    NotificationSettings settings =
        await messaging.requestPermission();

    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      return;
    }

    String? token = await messaging
        .getToken()
        .timeout(const Duration(seconds: 5));

    if (token != null) {
      await AuthService().updateFcmToken(userId, token);
    }

  } catch (e) {
    print("FCM update failed: $e");
  }
}



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4FF),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

Row(
  mainAxisAlignment: MainAxisAlignment.center,
  crossAxisAlignment: CrossAxisAlignment.center,
  children: [


    const Text(
      'TaskIQ',
      style: TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
      ),
    ),
  ],
),


 

                const Text(
                  'Organize smarter. Work faster.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),

                const SizedBox(height: 40),


                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await AuthService().signInWithGoogle();
                    },
                    icon: const FaIcon(
                      FontAwesomeIcons.google,
                      size: 20,
                      color: Colors.red,
                    ),
                    label: const Text(
                      'Continue with Google',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                /// DIVIDER
                Row(
                  children: [
                    Expanded(
                        child: Divider(color: Colors.grey.shade400)),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        "Or login with username",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                    Expanded(
                        child: Divider(color: Colors.grey.shade400)),
                  ],
                ),

                const SizedBox(height: 30),

                /// USERNAME FIELD
                TextField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    hintText: "Username",
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                /// PASSWORD FIELD
                TextField(
                  controller: _passwordController,
                  obscureText: hidePassword,
                  decoration: InputDecoration(
                    hintText: "Password",
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        hidePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          hidePassword = !hidePassword;
                        });
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                /// REMEMBER ME
                Row(
                  children: [
                    Checkbox(
                      value: rememberMe,
                      activeColor: Colors.green,
                      onChanged: (value) {
                        setState(() {
                          rememberMe = value ?? false;
                        });
                      },
                    ),
                    const Text(
                      "Remember me",
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                /// LOGIN BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _loginWithUsername,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            "Login",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
