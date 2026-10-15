import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase/migrations/202610110001_reconcile_driver_availability_booking_and_earnings.sql',
  ).readAsStringSync();
  final appState = File('lib/state/app_state.dart').readAsStringSync();
  final database =
      File('lib/services/supabase_database_service.dart').readAsStringSync();
  final realtime =
      File('lib/services/supabase/realtime_query.dart').readAsStringSync();
  final matching =
      File('lib/services/driver_matching_service.dart').readAsStringSync();
  final persistentOffersMigration = File(
    'supabase/migrations/202610110003_persistent_online_offers_and_daily_activity.sql',
  ).readAsStringSync();

  test('live presence is separate from saved Online preference', () {
    expect(migration, contains('public.driver_has_live_session'));
    expect(
      migration,
      contains(
        'CREATE OR REPLACE FUNCTION public.is_driver_bookable(target_driver uuid)',
      ),
    );
    expect(migration, contains('public.set_driver_offline()'));
    expect(migration, contains('PERFORM public.stop_driver_online_session()'));
    expect(migration, contains('live_online := NEW.is_online AND'));
    expect(appState, contains('SupabaseService.instance.setDriverOffline()'));
    expect(appState,
        contains('await SupabaseService.instance.stopDriverOnlineSession()'));
  });

  test('booking and discovery check live session, fresh GPS and ride conflicts',
      () {
    expect(migration, contains("interval '5 minutes'"));
    expect(migration, contains("interval '30 seconds'"));
    expect(
        migration, contains("r.status IN ('accepted', 'arrived', 'started')"));
    expect(migration, contains("r.status = 'searching'"));
    expect(
      migration,
      contains('public.driver_has_conflicting_ride(d.user_id, NULL)'),
    );
    expect(migration, contains('FOR UPDATE OF d, dp'));
    expect(database, contains("_client.rpc('is_driver_bookable'"));
    expect(
      database,
      isNot(contains(".select('is_online,is_available,last_location_at')")),
    );
    expect(
      migration,
      contains(
          'existing_ride.driver_id IS NOT DISTINCT FROM p_requested_driver'),
    );
    expect(migration, contains('has_active_ride boolean'));
    expect(matching, contains("row['has_active_ride']"));
  });

  test(
      'decline, cancellation and completion recalculate availability from rides',
      () {
    expect(migration, contains('rides_reconcile_driver_state_update'));
    expect(migration,
        contains('public.recalculate_driver_availability(OLD.driver_id'));
    expect(migration, contains("cancellation_reason, 'request_expired'"));
    expect(migration, contains("r.status = 'searching'"));
    expect(migration, contains("interval '90 seconds'"));
    expect(
      migration,
      contains(
        'PERFORM public.recalculate_driver_availability(driver_record.user_id',
      ),
    );
  });

  test(
      'completed fares are retained once with completion time and settlement status',
      () {
    expect(migration, contains('rides_record_completed_driver_earning'));
    expect(migration, contains('NEW.completed_at'));
    expect(migration, contains('ON CONFLICT DO NOTHING'));
    expect(migration, contains('payments_sync_driver_earning_status'));
    expect(migration, contains("settlement_status = CASE"));
    expect(migration, contains('r.completed_at IS NOT NULL'));
  });

  test('Realtime discards stale fetches and periodically refreshes presence',
      () {
    expect(realtime, contains('requestedRefreshVersion'));
    expect(realtime, contains('fetchVersion == requestedRefreshVersion'));
    expect(realtime, contains('_pollTimer = Timer.periodic'));
    expect(database, contains('pollInterval: const Duration(seconds: 30)'));
  });

  test('saved Online preference can receive a persisted offer after logout',
      () {
    final stopSession = migration
        .split('CREATE OR REPLACE FUNCTION public.stop_driver_online_session()')
        .last
        .split('CREATE OR REPLACE FUNCTION public.set_driver_offline()')
        .first;
    final requestFunction = persistentOffersMigration
        .split('CREATE OR REPLACE FUNCTION public.request_ride_with_id')
        .last
        .split('REVOKE ALL ON FUNCTION public.request_ride_with_id')
        .first;

    expect(stopSession, isNot(contains('SET is_online = false')));
    expect(persistentOffersMigration, contains('driver_is_requestable'));
    expect(persistentOffersMigration, contains('d.is_online'));
    expect(persistentOffersMigration, contains('has_live_session boolean'));
    expect(
        requestFunction, contains('public.driver_is_requestable(d.user_id)'));
    expect(requestFunction,
        isNot(contains('public.driver_has_live_session(d.user_id)')));
    expect(requestFunction, contains("'searching'"));
    expect(requestFunction, contains("'ride_request'"));
    expect(requestFunction, contains('p_pickup_latitude'));
    expect(requestFunction, contains('))) <= 15.0'));
    expect(
      persistentOffersMigration,
      contains('CREATE OR REPLACE FUNCTION public.is_driver_requestable'),
    );
    expect(persistentOffersMigration,
        contains('public.driver_is_reachable_and_approved(p_driver_id)'));
    expect(database, contains("rpc('is_driver_requestable'"));
    expect(appState, contains('isDriverRequestable(driverId)'));
    expect(matching, contains('hasLiveSession'));
    expect(matching, contains('canSubmitRideRequest'));
    expect(appState,
        contains('await SupabaseService.instance.stopDriverOnlineSession()'));
  });

  test('pending requests expire on the server and recover on driver login', () {
    expect(persistentOffersMigration, contains("interval '90 seconds'"));
    expect(persistentOffersMigration,
        contains('CREATE EXTENSION IF NOT EXISTS pg_cron'));
    expect(persistentOffersMigration, contains('cron.schedule('));
    expect(persistentOffersMigration, contains("'request_expired'"));
    expect(persistentOffersMigration, contains("'ride_request_expired'"));
    expect(database, contains("rpc('expire_driver_pending_requests')"));
    expect(database, contains('pollInterval: const Duration(seconds: 15)'));
    expect(database, contains("feature: 'driver_incoming_requests'"));
  });
}
