import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final database =
      File('lib/services/supabase_database_service.dart').readAsStringSync();
  final realtime =
      File('lib/services/supabase/realtime_query.dart').readAsStringSync();
  final migration = File(
    'supabase/migrations/202610040001_realtime_connection_hardening.sql',
  ).readAsStringSync();

  test('active Supabase services use the explicit channel adapter', () {
    expect(database, contains("import 'supabase/realtime_query.dart';"));
    expect(database, contains('realtimeQueryStream<List<NearbyDriver>>'));
    expect(database, contains("feature: 'driver_incoming_requests'"));
    expect(database, contains("feature: 'admin_all_rides'"));
    expect(database, isNot(contains('.stream(')));
  });

  test('the adapter performs initial fetch, status logging, and cleanup', () {
    expect(realtime, contains('status=AUTH_NOT_READY'));
    expect(realtime, contains('onPostgresChanges'));
    expect(realtime, contains('SUBSCRIBED'));
    expect(realtime, contains('CHANNEL_ERROR'));
    expect(realtime, contains('TIMED_OUT'));
    expect(realtime, contains('CLOSED'));
    expect(realtime, contains("unawaited(refresh('initial'))"));
    expect(realtime, contains('activeChannel.unsubscribe()'));
  });

  test('migration publishes only discovery-safe live tables and keeps RLS', () {
    for (final table in [
      'rides',
      'driver_presence',
      'profiles',
      'notifications',
      'chat_messages',
      'payments',
    ]) {
      expect(migration, contains("'$table'"));
    }
    expect(migration, isNot(contains("'drivers'")));
    expect(migration, contains('driver_presence_approved_authenticated_read'));
    expect(
      migration,
      contains(
          'drop policy if exists driver_presence_approved_authenticated_read'),
    );
    expect(migration, isNot(contains('disable row level security')));
  });

  test('acceptance uses the canonical text ride ID and is idempotent', () {
    expect(migration, contains('where id = accept_ride.ride_id'));
    expect(migration, isNot(contains('ride_id::uuid')));
    expect(
      migration,
      contains("current_ride.status = 'accepted'"),
    );
    expect(migration, contains('grant execute on function public.accept_ride'));
    expect(
        migration, contains('grant execute on function public.decline_ride'));
  });
}
