import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';

class FCMService {

static Future<void> init(int userId) async {
  try {
    final messaging = FirebaseMessaging.instance;

    await messaging.setAutoInitEnabled(true);

    final settings = await messaging.requestPermission();

    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      return;
    }

    // Get FCM token
    final token = await messaging.getToken();
    if (token == null) return;

    final prefs = await SharedPreferences.getInstance();
    final oldToken = prefs.getString('fcm_token');

    if (token != oldToken) {
      await AuthService().updateFcmToken(userId, token);
      await prefs.setString('fcm_token', token);
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      await AuthService().updateFcmToken(userId, newToken);
      await prefs.setString('fcm_token', newToken);
    });

    /* ---------------------------
       HANDLE NOTIFICATION TAP
    ----------------------------*/

    // When app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _openNotificationsScreen();
    });

    // When app is terminated
    final initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();

    if (initialMessage != null) {
      _openNotificationsScreen();
    }

  } catch (_) {
    // Silent fail
  }
}


static void _openNotificationsScreen() {
  navigatorKey.currentState?.pushNamedAndRemoveUntil(
    "/notifications",
    (route) => false,
  );
}


static Future<void> debugToServer(Map<String, dynamic> data) async {
  try {
    await AuthService().postDebug(data); // we’ll create this next
  } catch (_) {}
}


}