import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sakay_ta/core/constants.dart';
import 'package:sakay_ta/models/driver_application_rules.dart';
import 'package:sakay_ta/models/driver_profile.dart';
import 'package:sakay_ta/services/supabase_database_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('TODA is required only for Tricycle and never carried by Habal-Habal',
      () {
    expect(DriverApplicationRules.requiresToda(VehicleType.tricycle), isTrue);
    expect(DriverApplicationRules.requiresToda(VehicleType.habal), isFalse);
    expect(
      DriverApplicationRules.todaIdForVehicle(
          VehicleType.tricycle, ' toda-123 '),
      'toda-123',
    );
    expect(
      DriverApplicationRules.todaIdForVehicle(VehicleType.tricycle, '  '),
      isNull,
    );
    expect(
      DriverApplicationRules.todaIdForVehicle(
          VehicleType.habal, 'stale-toda-id'),
      isNull,
    );
  });

  test('vehicle color accepts descriptive colors and trims surrounding space',
      () {
    for (final color in [
      'Black',
      'White',
      'Blue',
      'Metallic Blue',
      'Dark Gray',
      'Pearl White',
      'Black and Red',
    ]) {
      expect(DriverApplicationRules.normalizeVehicleColor(color), color);
    }
    expect(
      DriverApplicationRules.normalizeVehicleColor('  Metallic Blue  '),
      'Metallic Blue',
    );
    expect(DriverApplicationRules.normalizeVehicleColor('  '), isNull);
    expect(
      DriverApplicationRules.normalizeVehicleColor(List.filled(61, 'x').join()),
      isNull,
    );
  });

  test('eligible TODA RPC exposes active Admin-managed signup records',
      () async {
    http.Request? captured;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-publishable-key',
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          '[{"id":"toda-a","name":"Active TODA","city":"Clarín"}]',
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );

    final todas =
        await SupabaseDatabaseService.test(client).eligibleDriverTodasOnce();

    expect(captured?.url.path, '/rest/v1/rpc/get_driver_signup_todas');
    expect(captured?.method, 'POST');
    expect(todas.single['id'], 'toda-a');
    client.dispose();
  });

  test('eligible TODA query propagates Supabase errors for retry UI', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-publishable-key',
      httpClient: MockClient((request) async => http.Response(
            '{"code":"42501","message":"permission denied"}',
            403,
            headers: {'content-type': 'application/json'},
            request: request,
          )),
    );

    await expectLater(
      SupabaseDatabaseService.test(client).eligibleDriverTodasOnce(),
      throwsA(isA<PostgrestException>()),
    );
    client.dispose();
  });

  test('unlicensed application serializes absent license fields as SQL NULL',
      () async {
    Map<String, dynamic>? submitted;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-publishable-key',
      httpClient: MockClient((request) async {
        submitted = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          '[{"user_id":"00000000-0000-0000-0000-000000000001"}]',
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    final profile = DriverProfile(
      userId: '00000000-0000-0000-0000-000000000001',
      vehicleType: VehicleType.habal,
      todaId: 'stale-toda-id',
      submittedAt: DateTime.utc(2026, 10, 11),
    );

    await SupabaseDatabaseService.test(client).saveDriverProfile(profile);

    expect(submitted?['license_type'], isNull);
    expect(submitted?['license_number'], isNull);
    expect(submitted?['license_expiry'], isNull);
    expect(submitted?['dl_codes'], isNull);
    expect(submitted?['condition_codes'], isNull);
    expect(submitted?['toda_id'], isNull);
    client.dispose();
  });

  test('driver profile lookup includes the Admin TODA name for review',
      () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-publishable-key',
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/drivers')) {
          return http.Response(
            '[{"user_id":"00000000-0000-0000-0000-000000000001","vehicle_type":"tricycle","toda_id":"toda-1","application_status":"pending","submitted_at":"2026-10-11T00:00:00Z"}]',
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        if (request.url.path.endsWith('/driver_documents')) {
          return http.Response('[]', 200,
              headers: {'content-type': 'application/json'}, request: request);
        }
        if (request.url.path.endsWith('/todas')) {
          expect(request.url.queryParameters['id'], 'eq.toda-1');
          return http.Response('[{"name":"Admin-created TODA"}]', 200,
              headers: {'content-type': 'application/json'}, request: request);
        }
        return http.Response('{}', 404, request: request);
      }),
    );

    final profile = await SupabaseDatabaseService.test(client).getDriverProfile(
      '00000000-0000-0000-0000-000000000001',
    );

    expect(profile?.todaId, 'toda-1');
    expect(profile?.todaName, 'Admin-created TODA');
    client.dispose();
  });

  test('missing license is parsed honestly without a Professional default', () {
    final profile = DriverProfile.fromMap({
      'user_id': 'driver-1',
      'vehicle_type': 'habal',
      'license_type': null,
      'license_number': null,
      'license_expiry': null,
      'dl_codes': null,
      'condition_codes': null,
      'submitted_at': '2026-10-11T00:00:00Z',
    });

    expect(profile.licenseType, isNull);
    expect(profile.licenseNumber, isEmpty);
    expect(profile.licenseExpiry, isEmpty);
    expect(profile.dlCodes, isEmpty);
    expect(profile.conditionCodes, isEmpty);
    expect(profile.copyWith(licenseType: 'Professional').licenseType,
        'Professional');
    expect(profile.copyWith(licenseType: null).licenseType, isNull);
  });

  test('database trigger protects vehicle-specific TODA and active status', () {
    final migration = File(
      'supabase/migrations/202610110004_enforce_driver_application_toda_rules.sql',
    ).readAsStringSync();
    final rls =
        File('supabase/migrations/202609200002_rls.sql').readAsStringSync();

    expect(
        migration,
        contains(
            'CREATE OR REPLACE FUNCTION public.get_driver_signup_todas()'));
    expect(
        migration, contains('RETURNS TABLE (id text, name text, city text)'));
    expect(migration,
        contains('GRANT EXECUTE ON FUNCTION public.get_driver_signup_todas()'));
    expect(migration, contains('WHERE t.is_active = true'));
    expect(migration, contains("NEW.vehicle_type = 'tricycle'"));
    expect(migration, contains('t.is_active = true'));
    expect(migration, contains("NEW.vehicle_type = 'habal'"));
    expect(migration, contains('NEW.toda_id IS NOT NULL'));
    expect(migration,
        contains('BEFORE INSERT OR UPDATE OF vehicle_type, toda_id'));
    expect(rls, contains('create policy todas_authenticated_read'));
    expect(rls, contains('is_active or public.is_admin()'));
    expect(rls, contains('create policy todas_admin_write'));
  });

  test('Admin verification represents a missing license without approval', () {
    final view = File('lib/pages/admin/views/driver_verification_view.dart')
        .readAsStringSync();
    expect(view, contains('No License Submitted'));
    expect(view, contains('Submitted — not verified'));
  });
}
