import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FCMService {

static Future<void> init(int userId) async {
  try {
    final messaging = FirebaseMessaging.instance;

    await messaging.setAutoInitEnabled(true);

    // Request permission (important for iOS)
    final settings = await messaging.requestPermission();

    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      return;
    }

    // Get FCM token
    final token = await messaging.getToken();
    if (token == null) return;

    final prefs = await SharedPreferences.getInstance();
    final oldToken = prefs.getString('fcm_token');

    // Update backend only if token changed
    if (token != oldToken) {
      await AuthService().updateFcmToken(userId, token);
      await prefs.setString('fcm_token', token);
    }

    // Listen for token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      await AuthService().updateFcmToken(userId, newToken);
      await prefs.setString('fcm_token', newToken);
    });

  } catch (_) {
    // Silent fail — no need to crash app
  }
}


static Future<void> debugToServer(Map<String, dynamic> data) async {
  try {
    await AuthService().postDebug(data); // we’ll create this next
  } catch (_) {}
}


}