import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Central debug logger for the Sakay Ta app.
///
/// Use [AppLog] and [AppLogger] throughout the app so that diagnostics,
/// caught exceptions, and API flows can be traced consistently.
class AppLog {
  AppLog._();

  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 6,
      lineLength: 120,
      colors: true,
      printEmojis: false,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  static void d(String tag, String message) => _logger.d('[$tag] $message');

  static void i(String tag, String message) => _logger.i('[$tag] $message');

  static void w(String tag, String message) => _logger.w('[$tag] $message');

  static void e(String tag, String message,
          [Object? error, StackTrace? stack]) =>
      _logger.e('[$tag] $message', error: error, stackTrace: stack);
}

/// Structured application logger used across services and state managers.
abstract final class AppLogger {
  static void debug(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (kDebugMode) {
      debugPrint('[SakayTa][DEBUG] $message');
    }
  }

  static void info(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    debugPrint('[SakayTa][INFO] $message');
  }

  static void warn(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    debugPrint('[SakayTa][WARN] $message${error != null ? ' ($error)' : ''}');
  }

  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    debugPrint('[SakayTa][ERROR] $message${error != null ? ' ($error)' : ''}');
  }
}
