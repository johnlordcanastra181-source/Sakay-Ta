import 'package:logger/logger.dart';

/// Central debug logger for the Sakay Ta app.
///
/// Use [AppLog] throughout the OTP flow so that the full chain
/// (button press -> API request -> SMS send -> response) can be traced
/// in the Flutter console / logcat regardless of where the code runs.
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
