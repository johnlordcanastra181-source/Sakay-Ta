import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sakay_ta/core/constants.dart';
import 'package:sakay_ta/models/app_user.dart';
import 'package:sakay_ta/services/database_service.dart';
import 'package:sakay_ta/state/app_state.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await DatabaseService.instance.database;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final db = await DatabaseService.instance.database;
    await db.delete('transactions');
    await db.delete('ratings');
    await db.delete('trip');
    final app = AppState.instance;
    await app.init();
  });

  group('Driver Performance Stats Real-Time Calculations & Streams', () {
    test('Calculates Rating, Acceptance, and Cancellation rates correctly from AppUser', () async {
      final driver = AppUser(
        id: 'perf_driver_1',
        fullName: 'Juan Dela Cruz',
        mobile: '09170000010',
        passwordHash: 'hash',
        role: UserRole.driver,
        isOnline: true,
        rating: 4.9,
        ratingCount: 150,
        acceptanceCount: 92,
        acceptanceTotal: 100,
        totalTrips: 92,
        createdAt: DateTime.now(),
      );

      expect(driver.ratingLabel, '4.9');
      expect(driver.acceptanceRate, 92.0);

      final cancellationRate = driver.acceptanceTotal == 0
          ? 0
          : (((driver.acceptanceTotal - driver.acceptanceCount) /
                      driver.acceptanceTotal) *
                  100)
              .round();
      expect(cancellationRate, 8);
    });

    test('Aggregates weekly 7-day trips and earnings accurately', () async {
      final app = AppState.instance;
      final driverId = 'perf_driver_2';

      final driver = AppUser(
        id: driverId,
        fullName: 'Emilio Aguinaldo',
        mobile: '09170000011',
        passwordHash: 'hash',
        role: UserRole.driver,
        isOnline: true,
        createdAt: DateTime.now(),
      );
      app.currentUser = driver;

      // Record 2 income transactions today
      await app.earnings.recordTripIncome(
        driverId: driverId,
        tripId: 'trip_perf_1',
        fare: 150.0,
        method: 'gcash',
      );

      await app.earnings.recordTripIncome(
        driverId: driverId,
        tripId: 'trip_perf_2',
        fare: 200.0,
        method: 'cash',
      );

      final weeklyStats = await app.streamWeeklyPerformanceStats(driverId).first;

      expect(weeklyStats.dailyBreakdown.length, 7);
      expect(weeklyStats.totalEarningsThisWeek, 350.0);
      expect(weeklyStats.periodLabel, contains('This week:'));
    });

    test('Passenger reviews stream returns real reviews for driver', () async {
      final app = AppState.instance;
      final driverId = 'perf_driver_3';

      final db = await DatabaseService.instance.database;
      await db.insert('ratings', {
        'id': 'rev_1',
        'trip_id': 'trip_101',
        'from_user_id': 'pass_1',
        'to_user_id': driverId,
        'rating': 5.0,
        'review': 'Very safe driving despite the heavy rain. Kuya was very polite!',
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });

      final reviews = await app.streamDriverReviews(driverId).first;
      expect(reviews.length, 1);
      expect(reviews.first.rating, 5);
      expect(reviews.first.comment, contains('Very safe driving'));
    });
  });
}
