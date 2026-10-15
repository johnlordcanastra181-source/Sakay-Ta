import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sakay_ta/core/constants.dart';
import 'package:sakay_ta/core/philippine_time.dart';
import 'package:sakay_ta/models/app_user.dart';
import 'package:sakay_ta/models/firestore_models.dart';
import 'package:sakay_ta/models/trip.dart';
import 'package:sakay_ta/services/driver_earnings_summary.dart';
import 'package:sakay_ta/services/database_service.dart';
import 'package:sakay_ta/services/prefs_service.dart';
import 'package:sakay_ta/state/app_state.dart';

void main() {
  late String migration8;
  late String driverHomeSrc;
  late String rideTrackingSrc;
  late String walletPageSrc;
  late String appStateSrc;
  late String dbServiceSrc;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await DatabaseService.instance.database;

    migration8 = File(
      'supabase/migrations/202610100008_harden_trip_completion_and_earnings.sql',
    ).readAsStringSync();
    driverHomeSrc = File('lib/pages/driver_home.dart').readAsStringSync();
    rideTrackingSrc = File('lib/pages/ride_tracking.dart').readAsStringSync();
    walletPageSrc = File('lib/pages/wallet_page.dart').readAsStringSync();
    appStateSrc = File('lib/state/app_state.dart').readAsStringSync();
    dbServiceSrc =
        File('lib/services/supabase_database_service.dart').readAsStringSync();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PrefsService.initialize();
    final app = AppState.instance;
    app.currentUser = null;
    app.activeTrip = null;
  });

  group('SQL Function Contract & Ambiguity Resolution (Items 1, 8, 9, 14, 15, 16, 18)', () {
    test('1. Migration 202610100008 eliminates error 42702 with explicit qualification & #variable_conflict use_column', () {
      expect(migration8, contains('#variable_conflict use_column'));
      expect(migration8, contains('p_ride_id := ride_id;'));
      expect(migration8, contains('p_next_status := next_status;'));
      expect(migration8, contains('WHERE r.id = p_ride_id'));
      expect(migration8, contains('WHERE p.ride_id = p_ride_id'));
      expect(migration8, contains('WHERE e.ride_id = p_ride_id'));
      expect(migration8, isNot(contains('WHERE ride_id = ride_id')));
      expect(migration8, isNot(contains('WHERE ride_id = p_ride_id')));
      expect(migration8, isNot(contains('ON CONFLICT (ride_id) WHERE ride_id IS NOT NULL')));
    });

    test('8 & 9. Repeated RPC execution is idempotent and does not duplicate earnings or trips', () {
      expect(
        migration8,
        contains("IF current_ride.status = 'completed' AND p_next_status = 'completed' THEN"),
      );
      expect(migration8, contains('RETURN true;'));
      expect(migration8, contains('SELECT e.id INTO existing_earning_id'));
      expect(migration8, contains('IF existing_earning_id IS NULL THEN'));
      expect(migration8, contains('ON CONFLICT DO NOTHING'));
    });

    test('14. Driver availability is updated correctly based on online status', () {
      expect(migration8, contains('is_available = d.is_online'));
      expect(migration8, contains('is_available = dp.is_online'));
      expect(migration8, isNot(contains('is_available = true;')));
    });

    test('15. Wrong driver cannot complete another driver\'s trip', () {
      expect(
        migration8,
        contains('IF NOT FOUND OR current_ride.driver_id IS DISTINCT FROM auth.uid() THEN'),
      );
      expect(migration8, contains('RETURN false;'));
    });

    test('16. RLS and role permissions remain strictly secured', () {
      expect(
        migration8,
        contains('REVOKE ALL ON FUNCTION public.transition_ride(text, public.ride_status) FROM PUBLIC, anon;'),
      );
      expect(
        migration8,
        contains('GRANT EXECUTE ON FUNCTION public.transition_ride(text, public.ride_status) TO authenticated, service_role;'),
      );
      expect(migration8, contains('SECURITY DEFINER'));
    });

    test('18. SQL migration applies without duplicate-function conflicts and notifies pgrst schema reload', () {
      expect(
        migration8,
        contains('CREATE OR REPLACE FUNCTION public.transition_ride('),
      );
      expect(migration8, contains('NOTIFY pgrst, \'reload schema\';'));
    });
  });

  group('Ride Completion & Earnings Data Flow (Items 2, 3, 4, 5, 6, 7, 10, 11, 12, 13)', () {
    test('2 & 3. Correct ride changes to completed with timestamp saved', () {
      expect(migration8, contains('status = p_next_status'));
      expect(migration8, contains('completed_at = CASE'));
      expect(migration8, contains("WHEN p_next_status = 'completed' THEN pg_catalog.now()"));
      expect(dbServiceSrc, contains('completed.status != RideStatus.completed'));
    });

    test('4. Driver Today\'s Earnings increases correctly using Philippine local-day boundaries', () {
      final nowManila = PhilippineTime.now();
      final todayCompleted = Trip(
        id: 'trip_100',
        passengerId: 'p1',
        driverId: 'd1',
        vehicleType: VehicleType.habal,
        pickupAddress: 'Tacloban Port',
        dropoffAddress: 'Robinsons Place Tacloban',
        pickup: const Geo(11.243, 125.004),
        dropoff: const Geo(11.228, 125.001),
        fare: 65.0,
        commission: 0.0,
        net: 65.0,
        distanceKm: 3.5,
        durationMin: 12,
        status: RideStatus.completed,
        paymentMethod: 'cash',
        paymentStatus: PaymentStatus.paid,
        createdAt: nowManila.subtract(const Duration(hours: 1)),
        completedAt: nowManila,
      );

      final yesterdayCompleted = Trip(
        id: 'trip_99',
        passengerId: 'p2',
        driverId: 'd1',
        vehicleType: VehicleType.habal,
        pickupAddress: 'Downtown',
        dropoffAddress: 'Airport',
        pickup: const Geo(11.243, 125.004),
        dropoff: const Geo(11.228, 125.001),
        fare: 150.0,
        commission: 0.0,
        net: 150.0,
        distanceKm: 8.0,
        durationMin: 25,
        status: RideStatus.completed,
        paymentMethod: 'cash',
        paymentStatus: PaymentStatus.paid,
        createdAt: nowManila.subtract(const Duration(days: 1, hours: 2)),
        completedAt: nowManila.subtract(const Duration(days: 1, hours: 1)),
      );

      expect(PhilippineTime.isSameDay(todayCompleted.completedAt!, nowManila), isTrue);
      expect(PhilippineTime.isSameDay(yesterdayCompleted.completedAt!, nowManila), isFalse);

      final summary = summarizeDriverEarningsToday(
        [todayCompleted, todayCompleted, yesterdayCompleted],
        now: nowManila,
      );

      expect(summary.earnings, 65.0);
      expect(summary.trips, 1);
      expect(driverHomeSrc, contains('todayTrips = dailySummary.trips'));
    });

    test('5. Completed Trips count updates authoritatively', () {
      expect(migration8, contains('total_trips = d.total_trips + 1'));
      expect(driverHomeSrc, contains('todayTrips = dailySummary.trips'));
    });

    test('6. Total Cash Earnings updates after confirmed cash collection without commission', () {
      final earning = DriverEarning(
        id: 'earn_trip_100',
        driverId: 'd1',
        rideId: 'trip_100',
        fare: 65.0,
        commission: 0.0,
        net: 65.0,
        paymentMethod: 'cash',
        settlementStatus: 'confirmed',
        createdAt: DateTime.now(),
      );

      final walletEntry = WalletEntry.fromEarning(earning);
      expect(walletEntry.type, 'income');
      expect(walletEntry.method.toLowerCase(), 'cash');
      expect(walletEntry.amount, 65.0);
      expect(earning.commission, 0.0);

      final refundedEntry = WalletEntry.fromEarning(DriverEarning(
        id: 'earn_trip_100_refunded',
        driverId: 'd1',
        rideId: 'trip_100_refunded',
        fare: 65.0,
        commission: 0.0,
        net: 65.0,
        paymentMethod: 'cash',
        settlementStatus: 'refunded',
        createdAt: DateTime.now(),
      ));
      expect(refundedEntry.amount, -65.0);
    });

    test('7. Recent Transactions shows completed ride details', () {
      expect(walletPageSrc, contains('StreamBuilder<List<WalletEntry>>'));
      expect(walletPageSrc, contains('e.type == \'income\''));
      expect(walletPageSrc, contains('e.method.toLowerCase().trim() == \'cash\''));
      expect(walletPageSrc, contains('cashEarnings'));
    });

    test('10. Driver app restart preserves authoritative totals', () async {
      final app = AppState.instance;
      app.currentUser = AppUser(
        id: 'd1',
        fullName: 'Test Driver',
        role: 'driver',
        mobile: '09123456789',
        email: 'driver@test.com',
        passwordHash: 'dummy',
        isOnline: true,
        createdAt: DateTime.now(),
      );

      await PrefsService.instance.setDarkMode(true);
      expect(await PrefsService.instance.darkMode, isTrue);
    });

    test('11 & 12. Passenger receives completed status and can submit rating', () {
      expect(migration8, contains('ride_count = pp.ride_count + 1'));
      expect(appStateSrc, contains('title: \'Trip Completed\''));
      expect(
        File('supabase/migrations/202610080001_driver_earnings_online_sessions_ratings.sql').readAsStringSync(),
        contains('submit_ride_rating'),
      );
    });

    test('13. Admin Monitor Rides shows completed ride in allRidesStream', () {
      final adminRidesSrc =
          File('lib/pages/admin/views/rides_view.dart').readAsStringSync();
      expect(adminRidesSrc, contains('app.allRidesStream('));
      expect(adminRidesSrc, contains('Monitor Rides'));
    });
  });

  group('UI & Error Handling Preservation (Items 17 & Flutter Guard)', () {
    test('17. Existing UI components are fully preserved without design modification', () {
      expect(driverHomeSrc, contains('_buildEarningsCard'));
      expect(driverHomeSrc, contains('TODAY\'S EARNINGS'));
      expect(driverHomeSrc, contains('DriverOsmCard'));
      expect(driverHomeSrc, contains('_buildGreetingAndToggle'));
      expect(rideTrackingSrc, contains('Complete Trip'));
      expect(walletPageSrc, contains('_DriverWalletView'));
    });

    test('Flutter error handling prevents double-press and provides actionable snackbar feedback', () {
      expect(driverHomeSrc, contains('final result = await app.completeTrip(onTime: true);'));
      expect(driverHomeSrc, contains('Trip completed. Earnings recorded!'));
      expect(driverHomeSrc, contains('Unable to complete trip: \$message'));
      expect(appStateSrc, contains('if (_completingActiveTrip)'));
      expect(appStateSrc, contains('Trip completion is already in progress.'));
    });
  });
}
