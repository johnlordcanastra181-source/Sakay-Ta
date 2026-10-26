import 'package:supabase_flutter/supabase_flutter.dart';

/// Public client configuration.
///
/// Uses the `--dart-define=SUPABASE_PUBLISHABLE_KEY=...` build parameter when
/// provided, and falls back to the client-safe `sb_publishable_` key for the
/// default project so `flutter run` works out-of-the-box in development.
abstract final class SupabaseConfig {
  static bool _isInitialized = false;
  static const _defaultProjectUrl = 'https://kasgyeaedfbcsrhzcnax.supabase.co';
  static const _defaultPublishableKey =
      'sb_publishable_DkWAQ4tOIrC2U4vOra7zaQ_mX313zjR';

  static const projectUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: _defaultProjectUrl,
  );

  static const _envKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static bool get _hasValidEnvKey =>
      _envKey.isNotEmpty &&
      _envKey != 'YOUR_SUPABASE_ANON_KEY' &&
      !_envKey.startsWith('<');

  /// Returns the publishable key passed via `--dart-define`, or the default
  /// project's client-safe `sb_publishable_` key when targeting `_defaultProjectUrl`.
  static String get publishableKey => _hasValidEnvKey
      ? _envKey
      : projectUrl == _defaultProjectUrl
          ? _defaultPublishableKey
          : '';

  static bool get isConfigured =>
      projectUrl.startsWith('https://') && publishableKey.isNotEmpty;

  /// Whether the SDK completed initialization in this process.
  static bool get isInitialized => _isInitialized;

  static Future<void> initialize() async {
    if (_isInitialized) return;
    if (!isConfigured) {
      throw StateError(
        'Missing SUPABASE_PUBLISHABLE_KEY. Build or run with the client-safe '
        '--dart-define=SUPABASE_PUBLISHABLE_KEY=<your_publishable_key> flag.',
      );
    }
    await Supabase.initialize(
      url: projectUrl,
      publishableKey: publishableKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
    _isInitialized = true;
  }
}
