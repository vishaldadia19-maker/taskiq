import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_state.dart';
import '../config/api_config.dart';
import 'package:firebase_messaging/firebase_messaging.dart';



class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  


Future<Map<String, dynamic>> loginWithUsername({
  required String username,
  required String password,
  String? fcmToken,   // 👈 NEW
}) async {

  debugPrint("📲 Sending FCM Token: $fcmToken");
  
  try {
    final response = await http.post(
      Uri.parse('${baseUrl}login_username.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
        'fcm_token': fcmToken ?? '',   // 👈 send token
      }),
    );

    debugPrint('🟢 Auth ${response.body}');

    return jsonDecode(response.body);

  } catch (e) {
    return {
      'success': false,
      'error': 'Network error'
    };
  }
}



  Future<void> signInWithGoogle() async {
    try {
      UserCredential userCredential;

      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        provider.setCustomParameters({'prompt': 'select_account'});
        userCredential = await _auth.signInWithPopup(provider);
      } else {
        await _googleSignIn.signOut();
        final googleUser = await _googleSignIn.signIn();
        if (googleUser == null) return;

        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        userCredential =
            await _auth.signInWithCredential(credential);
      }

      final user = userCredential.user;
      if (user != null) {
        await _syncAndStoreUser(user); // 🔥 IMPORTANT
      }
    } catch (e) {
      debugPrint('❌ Google sign-in error: $e');
    }
  }

  /// 🔥 BACKEND SYNC + LOCAL STORAGE
  Future<void> _syncAndStoreUser(User user) async {

    String? fcmToken;

    if (!kIsWeb) {
      await FirebaseMessaging.instance.requestPermission();
      fcmToken = await FirebaseMessaging.instance.getToken();
      debugPrint("📲 Google Login FCM: $fcmToken");
    }

    final res = await http.post(
      Uri.parse('${baseUrl}auth_user.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'firebase_uid': user.uid,
        'email': user.email,
        'full_name': user.displayName,
        'photo_url': user.photoURL,
        'fcm_token': fcmToken ?? '',   // 👈 NEW
      }),
    );

    final body = jsonDecode(res.body);

    if (body['success'] == true) {
      final backendUser = body['user'];

      final prefs = await SharedPreferences.getInstance();

      // 🔥 THIS IS WHAT AUTHGATE IS WAITING FOR
      await prefs.setInt('user_id', backendUser['id']);
      await prefs.setString('user_email', backendUser['email'] ?? '');
      await prefs.setString('user_name', backendUser['full_name'] ?? '');
      await prefs.setString('firebase_uid', backendUser['firebase_uid'] ?? '');

      AuthState.backendReady.value = true; // 🔥 NOTIFY UI


      debugPrint("✅ Backend user saved: ${backendUser['id']}");
    } else {
      throw Exception('Backend sync failed');
    }
  }

static Future<Map<String, dynamic>> checkUsername({
  required String username,
  required int userId,
}) async {

  debugPrint('🌍 Sending to API: username=$username, user_id=$userId');


  final response = await http.post(
    Uri.parse('$baseUrl/check_username.php'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'username': username,
      'user_id': userId,
    }),
  );

  debugPrint('🌍 Raw response: ${response.body}');


  return jsonDecode(response.body);
}




static Future<Map<String, dynamic>> setUsernamePassword({
  required String firebaseUid,
  required String username,
  required String password,
}) async {
  final response = await http.post(
    Uri.parse('$baseUrl/set_credentials.php'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'firebase_uid': firebaseUid,
      'username': username,
      'password': password,
    }),
  );

  return jsonDecode(response.body);
}


  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (kIsWeb) {
      await _auth.signOut();
    } else {
      await _googleSignIn.disconnect();
      await _googleSignIn.signOut();
      await _auth.signOut();
    }
  }
}
