import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sakay_ta/core/constants.dart';
import 'package:sakay_ta/core/time_utils.dart';
import 'package:sakay_ta/models/app_user.dart';
import 'package:sakay_ta/models/driver_profile.dart';
import 'package:sakay_ta/models/trip.dart';
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
    final app = AppState.instance;
    await app.init();
  });

  group('Driver Home Data & Real-Time Sync Tests', () {
    test('Dynamic Time-based Greeting returns proper greeting based on time', () {
      final morning = DateTime(2026, 8, 19, 8, 30);
      final afternoon = DateTime(2026, 8, 19, 14, 15);
      final evening = DateTime(2026, 8, 19, 19, 45);

      expect(TimeGreeting.getGreeting(time: morning), 'Good Morning');
      expect(TimeGreeting.getGreeting(time: afternoon), 'Good Afternoon');
      expect(TimeGreeting.getGreeting(time: evening), 'Good Evening');
    });

    test('Incoming ride request stream matches driver vehicle type and location', () async {
      final app = AppState.instance;

      final driver = AppUser(
        id: 'test_driver_1',
        fullName: 'Juan Dela Cruz',
        mobile: '09171234567',
        passwordHash: 'hash',
        role: UserRole.driver,
        isOnline: true,
        createdAt: DateTime.fromMillisecondsSinceEpoch(1600000000000),
        latitude: 10.3288,
        longitude: 123.9064,
      );

      app.currentUser = driver;
      app.driverProfile = DriverProfile(
        userId: driver.id,
        vehicleType: VehicleType.tricycle,
        submittedAt: DateTime.now(),
      );

      // Create a test trip in local DB
      final trip = Trip(
        id: 'test_trip_incoming_1',
        passengerId: 'passenger_1',
        vehicleType: VehicleType.tricycle,
        pickupAddress: 'Ayala Center Cebu',
        dropoffAddress: 'USC Main Campus',
        pickup: const Geo(10.3200, 123.9060),
        dropoff: const Geo(10.3000, 123.8900),
        distanceKm: 4.5,
        durationMin: 12,
        fare: 85.0,
        commission: 10.2,
        net: 74.8,
        status: RideStatus.searching,
        createdAt: DateTime.now(),
      );

      final db = await DatabaseService.instance.database;
      await db.insert('trip', trip.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

      // Check streamIncomingRequestsForDriver
      final stream = app.streamIncomingRequestsForDriver(
        driver,
        driverLocation: const Geo(10.3288, 123.9064),
      );

      final requests = await stream.first;
      expect(requests.any((r) => r.trip.id == trip.id), true);

      final incoming = requests.firstWhere((r) => r.trip.id == trip.id);
      expect(incoming.trip.pickupAddress, 'Ayala Center Cebu');
      expect(incoming.trip.fare, 85.0);
    });

    test('Atomic trip accept updates status and assigns driver', () async {
      final app = AppState.instance;

      final driver = AppUser(
        id: 'test_driver_accept',
        fullName: 'Pedro Penduko',
        mobile: '09181234567',
        passwordHash: 'hash',
        role: UserRole.driver,
        isOnline: true,
        createdAt: DateTime.fromMillisecondsSinceEpoch(1600000000000),
      );
      app.currentUser = driver;

      final trip = Trip(
        id: 'test_trip_atomic_accept',
        passengerId: 'passenger_2',
        vehicleType: VehicleType.tricycle,
        pickupAddress: 'Lahug',
        dropoffAddress: 'IT Park',
        pickup: const Geo(10.3288, 123.9064),
        dropoff: const Geo(10.3300, 123.9080),
        distanceKm: 1.2,
        durationMin: 5,
        fare: 45.0,
        commission: 5.4,
        net: 39.6,
        status: RideStatus.searching,
        createdAt: DateTime.now(),
      );

      final db = await DatabaseService.instance.database;
      await db.insert('trip', trip.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

      final accepted = await app.acceptTripAtomic(trip);
      expect(accepted, true);

      final updated = await app.trips.getById(trip.id);
      expect(updated?.status, RideStatus.accepted);
      expect(updated?.driverId, driver.id);
    });

    test('Declining a trip excludes it from incoming requests stream', () async {
      final app = AppState.instance;

      final driver = AppUser(
        id: 'test_driver_decline',
        fullName: 'Kardo Dalisay',
        mobile: '09191234567',
        passwordHash: 'hash',
        role: UserRole.driver,
        isOnline: true,
        createdAt: DateTime.fromMillisecondsSinceEpoch(1600000000000),
      );
      app.currentUser = driver;
      app.driverProfile = DriverProfile(
        userId: driver.id,
        vehicleType: VehicleType.tricycle,
        submittedAt: DateTime.now(),
      );

      final trip = Trip(
        id: 'test_trip_decline_1',
        passengerId: 'passenger_3',
        vehicleType: VehicleType.tricycle,
        pickupAddress: 'Colon St.',
        dropoffAddress: 'Fuente Osmena',
        pickup: const Geo(10.2980, 123.8990),
        dropoff: const Geo(10.3110, 123.8930),
        distanceKm: 2.0,
        durationMin: 8,
        fare: 50.0,
        commission: 6.0,
        net: 44.0,
        status: RideStatus.searching,
        createdAt: DateTime.now(),
      );

      final db = await DatabaseService.instance.database;
      await db.insert('trip', trip.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

      // Decline trip
      await app.declineTrip(trip);

      // Verify stream does not include declined trip
      final stream = app.streamIncomingRequestsForDriver(driver);
      final requests = await stream.first;
      expect(requests.any((r) => r.trip.id == trip.id), false);
    });

    test('Reverse geocode helper caches and returns address for location', () async {
      final app = AppState.instance;
      const testGeo = Geo(10.3288, 123.9064);

      final address = await app.getAddressForLocation(testGeo);
      expect(address.isNotEmpty, true);
    });
  });
}
