import 'package:flutter/foundation.dart';

class AppLog {
  const AppLog._();

  static void debug(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (!kDebugMode) return;
    debugPrint(error == null ? message : '$message: $error');
    if (stackTrace != null) {
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
