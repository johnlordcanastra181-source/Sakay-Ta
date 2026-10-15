import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sakay_ta/services/supabase_database_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('TODA save uses the canonical Supabase row and confirms the response',
      () async {
    final requests = <http.Request>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-publishable-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET') {
          return http.Response(
            '[]',
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        expect(request.method, 'POST');
        expect(request.url.path, '/rest/v1/todas');
        expect(request.url.queryParameters['on_conflict'], 'id');

        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        expect(payload['id'], 'toda-test-1');
        expect(payload['name'], 'Test TODA');
        expect(payload['code'], 'toda-test-1');
        expect(payload['city'], 'Cebu City');
        expect(payload.containsKey('province'), isFalse);

        return http.Response(
          jsonEncode({
            ...payload,
            'created_at': '2026-10-08T00:00:00Z',
            'updated_at': '2026-10-08T00:00:00Z',
          }),
          201,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );

    final saved = await SupabaseDatabaseService.test(client).saveToda({
      'id': 'toda-test-1',
      'name': 'Test TODA',
      'municipality': 'Cebu City',
      'province': 'Cebu',
    });

    expect(saved['id'], 'toda-test-1');
    expect(requests.where((request) => request.method == 'GET'), hasLength(1));
    expect(requests.where((request) => request.method == 'POST'), hasLength(1));
    client.dispose();
  });

  test('TODA save rethrows database failures instead of reporting success',
      () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-publishable-key',
      httpClient: MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(
            '[]',
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        return http.Response(
          jsonEncode({
            'code': '42501',
            'message': 'new row violates row-level security policy',
            'details': 'admin authorization required',
            'hint': null,
          }),
          403,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );

    await expectLater(
      SupabaseDatabaseService.test(client).saveToda({
        'id': 'toda-denied',
        'name': 'Denied TODA',
        'municipality': 'Cebu City',
      }),
      throwsA(isA<PostgrestException>()),
    );
    client.dispose();
  });

  test('TODA save rejects a duplicate name within the same city', () async {
    final requests = <http.Request>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-publishable-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode([
            {'id': 'toda-existing', 'name': 'Test TODA', 'city': 'Cebu City'},
          ]),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );

    await expectLater(
      SupabaseDatabaseService.test(client).saveToda({
        'id': 'toda-new',
        'name': ' test toda ',
        'municipality': 'cebu city',
      }),
      throwsA(
        predicate((error) =>
            error is StateError &&
            error.message.toString().contains('already exists')),
      ),
    );
    expect(requests, hasLength(1));
    expect(requests.single.method, 'GET');
    client.dispose();
  });

  test('local cache insert matches its actual SQLite schema', () {
    final databaseSource =
        File('lib/services/database_service.dart').readAsStringSync();
    final start = databaseSource.indexOf('Future<void> saveToda');
    final end = databaseSource.indexOf(
      'Future<void> deleteToda',
      start,
    );
    final saveMethod = databaseSource.substring(start, end);

    expect(saveMethod, contains("'id':"));
    expect(saveMethod, contains("'city':"));
    expect(saveMethod, isNot(contains("'created_at':")));
    expect(saveMethod, isNot(contains("'updated_at':")));
  });

  test('admin form guards repeated saves and required database fields', () {
    final form =
        File('lib/pages/admin/views/todas_view.dart').readAsStringSync();
    final driverApplication =
        File('lib/pages/driver_registration.dart').readAsStringSync();
    final driverDatabase =
        File('lib/services/supabase_database_service.dart').readAsStringSync();
    final appState = File('lib/state/app_state.dart').readAsStringSync();
    final migration = File(
      'supabase/migrations/202609200002_rls.sql',
    ).readAsStringSync();
    final accessMigration = File(
      'supabase/migrations/202610080002_admin_toda_access.sql',
    ).readAsStringSync();

    expect(form, contains('StatefulBuilder'));
    expect(form, contains('saving'));
    expect(form, contains('Enter a municipality or city.'));
    expect(form, contains('_formatTodaError'));
    expect(driverApplication, contains('SupabaseService.instance.todasOnce()'));
    expect(
        driverApplication, contains('DriverApplicationRules.todaIdForVehicle'));
    expect(driverApplication, contains("return 'Please select a TODA.'"));
    expect(driverDatabase,
        contains("'toda_id': DriverApplicationRules.todaIdForVehicle("));
    expect(driverDatabase, contains('already exists'));
    expect(
      appState.indexOf('SupabaseService.instance.saveToda(todaData)'),
      lessThan(appState.indexOf('DatabaseService.instance.saveToda(saved)')),
    );
    expect(migration, contains('create policy todas_admin_write'));
    expect(
      migration,
      contains('using (public.is_admin()) with check (public.is_admin())'),
    );
    expect(
      accessMigration,
      contains(
        'GRANT SELECT, INSERT, UPDATE, DELETE ON public.todas TO authenticated',
      ),
    );
  });
}
