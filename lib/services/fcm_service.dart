import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';

class FCMService {
  static Future<void> init(int userId) async {
    try {
      final messaging = FirebaseMessaging.instance;

      await messaging.setAutoInitEnabled(true);

      // 🔥 Ask permission (important for iOS)
      NotificationSettings settings =
          await messaging.requestPermission();

      debugPrint("🔔 Permission: ${settings.authorizationStatus}");

      // 🔥 Check APNS token (iOS only)
      String? apnsToken = await messaging.getAPNSToken();
      debugPrint("🍎 APNS TOKEN: $apnsToken");

      // 🔥 Get FCM token
      String? token = await messaging.getToken();
      debugPrint("🔥 FCM TOKEN: $token");

      if (token != null) {
        await AuthService().updateFcmToken(userId, token);
        debugPrint("✅ FCM token sent to backend");
      }

      // 🔥 Listen for token refresh
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        await AuthService().updateFcmToken(userId, newToken);
        debugPrint("🔄 FCM token refreshed");
      });

    } catch (e) {
      debugPrint("❌ FCM init error: $e");
    }
  }

static Future<void> debugToServer(Map<String, dynamic> data) async {
  try {
    await AuthService().postDebug(data); // we’ll create this next
  } catch (_) {}
}

  
}