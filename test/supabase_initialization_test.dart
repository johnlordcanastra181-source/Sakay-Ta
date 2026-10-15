import 'package:flutter_test/flutter_test.dart';
import 'package:sakay_ta/core/supabase_config.dart';
import 'package:sakay_ta/services/supabase_auth_service.dart';
import 'package:sakay_ta/services/supabase_service.dart';
import 'package:sakay_ta/services/supabase_storage_service.dart';

void main() {
  test('service singletons are safe before Supabase initialization', () {
    expect(SupabaseConfig.isInitialized, isFalse);
    expect(SupabaseService.isConfigured, isFalse);
    expect(SupabaseAuthService.isConfigured, isFalse);
    expect(SupabaseStorageService.isConfigured, isFalse);
    expect(() => SupabaseService.instance, returnsNormally);
  });
}
