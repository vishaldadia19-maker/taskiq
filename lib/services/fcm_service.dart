import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';

class FCMService {

static Future<void> init(int userId) async {
  try {
    final messaging = FirebaseMessaging.instance;

    await debugToServer({"step": "init_start", "user": userId});

    await messaging.setAutoInitEnabled(true);

    NotificationSettings settings =
        await messaging.requestPermission();

    await debugToServer({
      "step": "permission_status",
      "status": settings.authorizationStatus.toString()
    });

    String? apnsToken;

    for (int i = 0; i < 10; i++) {
      apnsToken = await messaging.getAPNSToken();
      if (apnsToken != null) break;
      await Future.delayed(const Duration(seconds: 1));
    }

    await debugToServer({
      "step": "apns_token_after_wait",
      "value": apnsToken
    });

    await debugToServer({
      "step": "apns_token",
      "value": apnsToken
    });

    String? token;

    if (apnsToken != null) {
      token = await messaging.getToken();
    }    

    await debugToServer({
      "step": "fcm_token",
      "value": token
    });

    if (token != null) {
      await AuthService().updateFcmToken(userId, token);
      await debugToServer({"step": "token_sent_to_backend"});
    } else {
      await debugToServer({"step": "token_null"});
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      await AuthService().updateFcmToken(userId, newToken);
      await debugToServer({
        "step": "token_refreshed",
        "value": newToken
      });
    });

  } catch (e) {
    await debugToServer({
      "step": "init_error",
      "error": e.toString()
    });
  }
}


static Future<void> debugToServer(Map<String, dynamic> data) async {
  try {
    await AuthService().postDebug(data); // we’ll create this next
  } catch (_) {}
}


}