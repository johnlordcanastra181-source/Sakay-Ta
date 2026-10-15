import 'package:flutter_test/flutter_test.dart';
import 'package:sakay_ta/core/constants.dart';
import 'package:sakay_ta/models/fare_matrix.dart';
import 'package:sakay_ta/services/driver_matching_service.dart';
import 'package:sakay_ta/services/fare_calculator.dart';

void main() {
  group('Dynamic Fare Matrix Tests', () {
    setUp(() {
      // Reset to standard Philippine defaults before each test
      // RideConfig.setFare(VehicleType.tricycle, baseFare: 15.0, perKm: 5.0);
      // RideConfig.setFare(VehicleType.habal, baseFare: 20.0, perKm: 8.0);
    });

    test('Defaults are properly configured', () {
      expect(RideConfig.baseFareFor(VehicleType.tricycle), 15.0);
      expect(RideConfig.perKmFor(VehicleType.tricycle), 5.0);
      expect(VehicleType.tricycle.baseFare, 15.0);
      expect(VehicleType.tricycle.perKm, 5.0);

      expect(RideConfig.baseFareFor(VehicleType.habal), 20.0);
      expect(RideConfig.perKmFor(VehicleType.habal), 8.0);
      expect(VehicleType.habal.baseFare, 20.0);
      expect(VehicleType.habal.perKm, 8.0);
    });

    test('Calculates default fares correctly with rounding to nearest 5', () {
      final matching = DriverMatchingService.instance;

      // Tricycle: 15 covers the first km, then 1*5 = 20.
      expect(
        matching.calculateFare(
          vehicleType: VehicleType.tricycle,
          distanceKm: 2.0,
        ),
        20.0,
      );

      // Habal: 20 covers the first km, then 1*8 = 28 -> 30.
      expect(
        matching.calculateFare(
          vehicleType: VehicleType.habal,
          distanceKm: 2.0,
        ),
        30.0,
      );
    });

    test('Configured matrix values drive DriverMatchingService and RideConfig',
        () {
      final matching = DriverMatchingService.instance;

      expect(RideConfig.baseFareFor(VehicleType.tricycle), 15.0);
      expect(RideConfig.perKmFor(VehicleType.tricycle), 5.0);
      expect(VehicleType.tricycle.baseFare, 15.0);
      expect(VehicleType.tricycle.perKm, 5.0);

      // New calculation: 15 + (3 - 1)*5 = 25.
      final trikFare = matching.calculateFare(
        vehicleType: VehicleType.tricycle,
        distanceKm: 3.0,
      );
      expect(trikFare, 25.0);

      expect(RideConfig.baseFareFor(VehicleType.habal), 20.0);
      expect(RideConfig.perKmFor(VehicleType.habal), 8.0);
      expect(VehicleType.habal.baseFare, 20.0);
      expect(VehicleType.habal.perKm, 8.0);

      // New calculation: 20 + (4 - 1)*8 = 44 -> 45.
      final habalFare = matching.calculateFare(
        vehicleType: VehicleType.habal,
        distanceKm: 4.0,
      );
      expect(habalFare, 45.0);
    });

    test('Fare clamps to base fare if distance is minimal or zero', () {
      // RideConfig.setFare(VehicleType.tricycle, baseFare: 18.0, perKm: 6.0);
      final fare = RideConfig.fareFor(VehicleType.tricycle, 0.1);
      // A trip shorter than the included distance still costs the base fare.
      expect(fare, 15.0);
    });

    test('Driver earnings use the full confirmed fare', () {
      final matrix = FareMatrix(
        id: 'tricycle',
        vehicleType: VehicleType.tricycle,
        baseFare: 15,
        includedBaseDistance: 1,
        perKmRate: 5,
        perMinuteRate: 0,
        minimumFare: 15,
        bookingFee: 0,
        surgeMultiplier: 1,
        commissionPercent: 0,
        isActive: true,
        updatedAt: DateTime(2026),
      );

      final fare = FareCalculator.calculateFare(
        matrix: matrix,
        distanceKm: 5,
        durationMinutes: 0,
      );

      expect(fare, 35.0);
      expect(fare, equals(15 + (5 - 1) * 5));
    });
  });
}
