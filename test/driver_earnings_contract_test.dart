import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:sakay_ta/core/philippine_time.dart';
import 'package:sakay_ta/models/firestore_models.dart';

void main() {
  final migration = File(
    'supabase/migrations/202610080001_driver_earnings_online_sessions_ratings.sql',
  ).readAsStringSync();
  final completionMigration = File(
    'supabase/migrations/202610100004_harden_driver_complete_trip.sql',
  ).readAsStringSync();
  final completionAmbiguityFixMigration = File(
    'supabase/migrations/202610100005_fix_driver_completion_ride_id_ambiguity.sql',
  ).readAsStringSync();
  final completeTripHardFixMigration = File(
    'supabase/migrations/202610100006_eliminate_transition_ride_name_collisions.sql',
  ).readAsStringSync();
  final completeTripPermissionsMigration = File(
    'supabase/migrations/202610100007_restrict_transition_ride_execution.sql',
  ).readAsStringSync();
  final dashboard = File('lib/pages/driver_home.dart').readAsStringSync();
  final dailyActivityMigration = File(
    'supabase/migrations/202610110003_persistent_online_offers_and_daily_activity.sql',
  ).readAsStringSync();
  final rideTracking = File('lib/pages/ride_tracking.dart').readAsStringSync();
  final appState = File('lib/state/app_state.dart').readAsStringSync();
  final database =
      File('lib/services/supabase_database_service.dart').readAsStringSync();
  final ratingsPage = File('lib/pages/my_rides.dart').readAsStringSync();

  test('Philippine local-day boundaries are not UTC calendar boundaries', () {
    final beforeMidnightUtc = DateTime.parse('2026-10-07T15:59:59Z');
    final atMidnightUtc = DateTime.parse('2026-10-07T16:00:00Z');
    final octoberSeventh = DateTime(2026, 10, 7);
    final octoberEighth = DateTime(2026, 10, 8);

    expect(PhilippineTime.isSameDay(beforeMidnightUtc, octoberSeventh), isTrue);
    expect(PhilippineTime.isSameDay(beforeMidnightUtc, octoberEighth), isFalse);
    expect(PhilippineTime.isSameDay(atMidnightUtc, octoberEighth), isTrue);
  });

  test('earning model preserves confirmed settlement and zero commission', () {
    final earning = DriverEarning(
      id: 'earn_ride_1',
      driverId: 'driver-1',
      rideId: 'ride-1',
      fare: 100,
      commission: 0,
      net: 100,
      paymentMethod: 'cash',
      settlementStatus: 'confirmed',
      createdAt: DateTime.utc(2026, 10, 8),
    );

    expect(earning.toMap()['commission'], 0);
    expect(earning.toMap()['settlementStatus'], 'confirmed');
    expect(earning.toMap()['paymentMethod'], 'cash');
  });

  test('Supabase completion, online sessions, and ratings are secured', () {
    expect(migration, contains('driver_earnings_one_row_per_ride'));
    expect(migration, contains('driver_online_sessions_one_open'));
    expect(migration, contains('driver_online_hours_today'));
    expect(migration, contains('driver_online_sessions_one_open'));
    expect(
      migration,
      contains(
        "ended_at = LEAST(now(), last_heartbeat_at + interval '90 seconds')",
      ),
    );
    expect(migration, contains('IS DISTINCT FROM auth.uid()'));
    expect(
      migration,
      contains('ON CONFLICT (ride_id) WHERE ride_id IS NOT NULL DO NOTHING'),
    );
    expect(
      migration,
      contains(
        'REVOKE INSERT, UPDATE, DELETE ON public.driver_earnings FROM anon, authenticated',
      ),
    );
    expect(
      migration,
      contains(
        'REVOKE INSERT, UPDATE, DELETE ON public.ratings FROM anon, authenticated',
      ),
    );
    expect(migration, contains('submit_ride_rating'));
    expect(migration, contains('current_ride.passenger_id <> auth.uid()'));
    expect(migration, contains('current_ride.status <> \'completed\''));
  });

  test('driver completion is server-confirmed and idempotent', () {
    expect(
      completionMigration,
      contains(
          "current_ride.status = 'completed' AND next_status = 'completed'"),
    );
    expect(
      completionMigration,
      contains('ON CONFLICT (ride_id) WHERE ride_id IS NOT NULL DO NOTHING'),
    );
    expect(completionAmbiguityFixMigration, contains('target_ride_id'));
    expect(completionAmbiguityFixMigration, contains('ON CONFLICT DO NOTHING'));
    expect(completeTripHardFixMigration, contains('target_ride_id := \$1'));
    expect(completeTripHardFixMigration, contains('target_status := \$2'));
    expect(completeTripHardFixMigration, contains('FROM public.rides AS r'));
    expect(
        completeTripHardFixMigration, contains('WHERE r.id = target_ride_id'));
    expect(
        completeTripHardFixMigration, contains('UPDATE public.payments AS p'));
    expect(completeTripHardFixMigration,
        contains('WHERE p.ride_id = target_ride_id'));
    expect(completeTripHardFixMigration, contains('ON CONFLICT DO NOTHING'));
    expect(
      completeTripHardFixMigration,
      isNot(contains('ON CONFLICT (ride_id)')),
    );
    expect(
        completeTripHardFixMigration, contains('SET search_path = pg_catalog'));
    expect(
      completeTripHardFixMigration,
      contains(
        'REVOKE ALL ON FUNCTION public.transition_ride(text, public.ride_status)',
      ),
    );
    expect(
      completeTripHardFixMigration,
      contains(
        'GRANT EXECUTE ON FUNCTION public.transition_ride(text, public.ride_status)',
      ),
    );
    expect(
      completeTripPermissionsMigration,
      contains('FROM PUBLIC, anon'),
    );
    expect(
      completeTripPermissionsMigration,
      contains('TO authenticated, service_role'),
    );
    expect(appState, contains('TripCompletionResult.confirmed'));
    expect(appState, contains('_completingActiveTrip'));
    expect(appState, contains('activeTrip = null;'));
    expect(database, contains('final completed = await getTrip(rideId)'));
    expect(database, contains('completed.driverId != driverId'));
    expect(dashboard, contains('streamDriverDailyEarningsToday(userId)'));
    expect(database, contains('get_driver_daily_activity_today'));
    expect(dailyActivityMigration, contains("'Asia/Manila'"));
    expect(
      dailyActivityMigration,
      contains('r.completed_at >= manila_day_start_utc'),
    );
    expect(
      dailyActivityMigration,
      contains('r.completed_at < manila_day_end_utc'),
    );
    expect(dashboard, contains('Completing...'));
    expect(dashboard, contains('Unable to complete trip:'));
    expect(rideTracking, contains('Unable to complete trip:'));
  });

  test('Flutter uses authoritative streams and never reintroduces commission',
      () {
    expect(dashboard, contains('dailySummary.earnings'));
    expect(
      File('lib/services/driver_earnings_summary.dart').readAsStringSync(),
      contains('PhilippineTime.isSameDay'),
    );
    expect(appState, contains('streamDriverRideHistory'));
    expect(appState, contains('_driverRatingsSub'));
    expect(appState, contains("'confirmed', 'completed'"));
    expect(database, contains("feature: 'driver_earnings'"));
    expect(database, contains("feature: 'user_ratings'"));
    expect(
      File('lib/pages/admin/views/payments_view.dart').readAsStringSync(),
      contains('_earningsStream'),
    );
    expect(
      File('lib/pages/wallet_page.dart').readAsStringSync(),
      contains('_transactionsStream'),
    );
    expect(ratingsPage, contains('vehicleLabel'));
    expect(ratingsPage, contains('_RatingSubmission'));
  });
}
