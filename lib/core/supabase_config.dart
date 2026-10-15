import 'package:supabase_flutter/supabase_flutter.dart';

/// Public client configuration. The publishable key must be supplied at build
/// time with `--dart-define=SUPABASE_PUBLISHABLE_KEY=...`.
abstract final class SupabaseConfig {
  static bool _isInitialized = false;
  static const _defaultProjectUrl = 'https://kasgyeaedfbcsrhzcnax.supabase.co';

  static const projectUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: _defaultProjectUrl,
  );

  static const _envKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  // Hardcoded key for direct IDE running without --dart-define
  static const _hardcodedKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imthc2d5ZWFlZGZiY3NyaHpjbmF4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODk4ODcyOTksImV4cCI6MjEwNTQ2MzI5OX0._w7ApQ0kB4wQl9zg48dO_ad-u8RaS-IZ4lsLUj3EEvo';

  // A custom URL must never silently retain the default project's key.
  static String get publishableKey => _envKey.isNotEmpty
      ? _envKey
      : projectUrl == _defaultProjectUrl
          ? _hardcodedKey
          : '';

  static bool get isConfigured =>
      projectUrl.startsWith('https://') && publishableKey.isNotEmpty;

  /// Whether the SDK completed initialization in this process.
  static bool get isInitialized => _isInitialized;

  static Future<void> initialize() async {
    if (_isInitialized) return;
    if (!isConfigured) {
      throw StateError(
        'Missing SUPABASE_PUBLISHABLE_KEY. Build with the client-safe '
        '--dart-define value documented in SUPABASE_MIGRATION.md.',
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
