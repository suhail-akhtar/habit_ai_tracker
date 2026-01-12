import 'package:flutter/foundation.dart';

class AppLog {
  static void d(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  static void e(String message, [Object? error]) {
    if (kDebugMode) {
      debugPrint(error == null ? message : '$message\n$error');
    }
  }
}
