import 'package:flutter/foundation.dart';

class AuthState {
  static final ValueNotifier<bool> backendReady =
      ValueNotifier<bool>(false);
}
