import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sakay_ta/core/constants.dart';
import 'package:sakay_ta/services/supabase_database_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('pending applications use driver and profile rows for the review queue',
      () async {
    final paths = <String>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-publishable-key',
      httpClient: MockClient((request) async {
        paths.add(request.url.path);
        if (request.url.path.endsWith('/drivers')) {
          expect(
              request.url.queryParameters['application_status'], 'eq.pending');
          return http.Response(
              '''[{
            "user_id":"00000000-0000-0000-0000-000000000001",
            "application_status":"pending",
            "vehicle_type":"tricycle",
            "plate_number":"ABC-123",
            "license_number":"LTO-456",
            "vehicle_make":"Bajaj",
            "vehicle_model":"RE",
            "toda_id":"toda-1",
            "municipality":"Legazpi",
            "submitted_at":"2026-09-29T08:00:00Z"
          }]''',
              200,
              headers: {'content-type': 'application/json'},
              request: request);
        }
        if (request.url.path.endsWith('/profiles')) {
          return http.Response(
              '''[{
            "id":"00000000-0000-0000-0000-000000000001",
            "full_name":"Driver One",
            "mobile":"09123456789",
            "address":"Legazpi City",
            "account_status":"pending",
            "created_at":"2026-09-28T08:00:00Z"
          }]''',
              200,
              headers: {'content-type': 'application/json'},
              request: request);
        }
        if (request.url.path.endsWith('/todas')) {
          return http.Response('[{"id":"toda-1","name":"Legazpi TODA"}]', 200,
              headers: {'content-type': 'application/json'}, request: request);
        }
        if (request.url.path.contains('/driver-applications')) {
          return http.Response('[]', 200,
              headers: {'content-type': 'application/json'}, request: request);
        }
        return http.Response('{}', 404, request: request);
      }),
    );

    final applications = await SupabaseDatabaseService.test(client)
        .streamPendingDriverApplications()
        .first;

    expect(paths, [
      '/rest/v1/drivers',
      '/rest/v1/profiles',
      '/rest/v1/todas',
      '/functions/v1/driver-applications',
    ]);
    expect(applications, hasLength(1));
    expect(applications.single.user.fullName, 'Driver One');
    expect(applications.single.user.role, UserRole.driver);
    expect(applications.single.profile.plateNumber, 'ABC-123');
    expect(applications.single.profile.licenseNumber, 'LTO-456');
    expect(applications.single.profile.make, 'Bajaj');
    expect(applications.single.profile.address, 'Legazpi City');
    expect(applications.single.profile.todaName, 'Legazpi TODA');
    expect(applications.single.profile.submittedAt,
        DateTime.parse('2026-09-29T08:00:00Z'));
    client.dispose();
  });

  test('a failed pending-driver read remains an error', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-publishable-key',
      httpClient: MockClient((request) async => http.Response(
            '{"message":"database unavailable","code":"XX000"}',
            500,
            headers: {'content-type': 'application/json'},
            request: request,
          )),
    );

    await expectLater(
      SupabaseDatabaseService.test(client).streamPendingDriverApplications(),
      emitsError(isA<PostgrestException>()),
    );
    client.dispose();
  });
}
