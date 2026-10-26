import 'package:flutter_test/flutter_test.dart';
import 'package:sakay_ta/core/constants.dart';
import 'package:sakay_ta/models/trip.dart';
import 'package:sakay_ta/services/auth_service.dart';
import 'package:sakay_ta/services/database_service.dart';
import 'package:sakay_ta/services/prefs_service.dart';
import 'package:sakay_ta/services/trip_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseService dbService;
  late PrefsService prefsService;
  late AuthService authService;
  late TripService tripService;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
    await PrefsService.initialize();
    dbService = DatabaseService.instance;
    await dbService.database;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    prefsService = PrefsService.instance;
    authService = AuthService(dbService, prefsService);
    tripService = TripService(dbService, authService);
  });

  group('Fare Consistency & Road Distance Preservation Tests', () {
    test('requestTrip preserves road distance, duration, and exact estimated fare', () async {
      const passengerId = 'p-test-123';
      const pickupAddress = 'Clarin Municipal Hall, Bohol';
      const dropoffAddress = 'Tubigon Port, Bohol';
      const pickup = Geo(9.9610, 124.0240);
      const dropoff = Geo(9.9520, 123.9580);
      const roadDistanceKm = 12.5;
      const roadDurationMin = 25;
      const confirmedEstimatedFare = 60.0;

      final trip = await tripService.requestTrip(
        passengerId: passengerId,
        vehicleType: VehicleType.habal,
        pickupAddress: pickupAddress,
        dropoffAddress: dropoffAddress,
        pickup: pickup,
        dropoff: dropoff,
        estimatedFare: confirmedEstimatedFare,
        distanceKm: roadDistanceKm,
        durationMin: roadDurationMin,
        paymentMethod: PaymentMethod.cash,
        queued: true,
      );

      // Verify road distance is preserved instead of straight-line crow-flies
      expect(trip.distanceKm, equals(roadDistanceKm));
      expect(trip.durationMin, equals(roadDurationMin));

      // Verify fare strictly equals confirmed estimate and 100% credited to driver net
      expect(trip.fare, equals(60.0));
      expect(trip.commission, equals(0.0));
      expect(trip.net, equals(60.0));
      expect(trip.paymentMethod, equals(PaymentMethod.cash));
    });

    test('Trip status normalization correctly recognizes active statuses', () {
      expect(RideStatus.normalize('searching'), equals(RideStatus.searching));
      expect(RideStatus.normalize('accepted'), equals(RideStatus.accepted));
      expect(RideStatus.normalize('arrived'), equals(RideStatus.arrived));
      expect(RideStatus.normalize('started'), equals(RideStatus.started));
      expect(RideStatus.normalize('completed'), equals(RideStatus.completed));
      expect(RideStatus.normalize('cancelled'), equals(RideStatus.cancelled));

      // Active statuses in RideStatus.active
      expect(RideStatus.active.contains(RideStatus.searching), isTrue);
      expect(RideStatus.active.contains(RideStatus.accepted), isTrue);
      expect(RideStatus.active.contains(RideStatus.arrived), isTrue);
      expect(RideStatus.active.contains(RideStatus.started), isTrue);
      expect(RideStatus.active.contains(RideStatus.completed), isFalse);
      expect(RideStatus.active.contains(RideStatus.cancelled), isFalse);
    });
  });
}

