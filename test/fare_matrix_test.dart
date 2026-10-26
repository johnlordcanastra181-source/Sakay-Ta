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
      expect(RideConfig.baseFareFor(VehicleType.tricycle), 10.0);
      expect(RideConfig.perKmFor(VehicleType.tricycle), 5.0);
      expect(VehicleType.tricycle.baseFare, 10.0);
      expect(VehicleType.tricycle.perKm, 5.0);

      expect(RideConfig.baseFareFor(VehicleType.habal), 20.0);
      expect(RideConfig.perKmFor(VehicleType.habal), 5.0);
      expect(VehicleType.habal.baseFare, 20.0);
      expect(VehicleType.habal.perKm, 5.0);
    });

    test('Calculates default fares correctly with exact distance charges', () {
      final matching = DriverMatchingService.instance;

      // Tricycle: 0 + 2*5 = 10 (meets min fare 10)
      expect(
        matching.calculateFare(
          vehicleType: VehicleType.tricycle,
          distanceKm: 2.0,
        ),
        10.0,
      );

      // Habal: 20 + 2*5 = 30
      expect(
        matching.calculateFare(
          vehicleType: VehicleType.habal,
          distanceKm: 2.0,
        ),
        30.0,
      );
    });

    test('Distance charge accurately adds to driver fare with decimal distance and rates', () {
      final tricycleMatrix = FareMatrix(
        id: 'tricycle',
        vehicleType: VehicleType.tricycle,
        baseFare: 15.0,
        includedBaseDistance: 2.5,
        perKmRate: 5.5,
        perMinuteRate: 0,
        minimumFare: 15.0,
        bookingFee: 0,
        surgeMultiplier: 1,
        commissionPercent: 0,
        isActive: true,
        updatedAt: DateTime(2026),
      );

      // At 2.8 km: chargeable is 2.8 - 2.5 = 0.3 km
      // Distance charge = 0.3 * 5.5 = 1.65
      // Total fare = 15.0 + 1.65 = 16.65
      final fare = FareCalculator.calculateFare(
        matrix: tricycleMatrix,
        distanceKm: 2.8,
        durationMinutes: 0,
      );

      expect(fare, 16.65);
      expect(fare, greaterThan(15.0));
    });

    test('Configured matrix values drive DriverMatchingService and RideConfig',
        () {
      final matching = DriverMatchingService.instance;

      expect(RideConfig.baseFareFor(VehicleType.tricycle), 10.0);
      expect(RideConfig.perKmFor(VehicleType.tricycle), 5.0);
      expect(VehicleType.tricycle.baseFare, 10.0);
      expect(VehicleType.tricycle.perKm, 5.0);

      // Calculation: 0 + 3*5 = 15.
      final trikFare = matching.calculateFare(
        vehicleType: VehicleType.tricycle,
        distanceKm: 3.0,
      );
      expect(trikFare, 15.0);

      expect(RideConfig.baseFareFor(VehicleType.habal), 20.0);
      expect(RideConfig.perKmFor(VehicleType.habal), 5.0);
      expect(VehicleType.habal.baseFare, 20.0);
      expect(VehicleType.habal.perKm, 5.0);

      // Calculation: 20 + 4*5 = 40.
      final habalFare = matching.calculateFare(
        vehicleType: VehicleType.habal,
        distanceKm: 4.0,
      );
      expect(habalFare, 40.0);
    });

    test('Fare uses minimum fare if distance is within included base distance', () {
      final fare = RideConfig.fareFor(VehicleType.tricycle, 0.1);
      // 0 + 0.1*5 = 0.5 -> minimum fare is 10.0
      expect(fare, 10.0);
    });

    test('Minimum fare + Distance charge strictly equals total fare', () {
      final matrix = FareMatrix(
        id: 'tricycle',
        vehicleType: VehicleType.tricycle,
        baseFare: 12.0,
        includedBaseDistance: 5.0,
        perKmRate: 10.0,
        perMinuteRate: 0,
        minimumFare: 12.0,
        bookingFee: 0,
        surgeMultiplier: 1,
        commissionPercent: 0,
        isActive: true,
        updatedAt: DateTime(2026),
      );

      // 1.4 km is within 5.0 km: Minimum Fare 12 + Distance Charge 0 = 12.0
      expect(
        FareCalculator.calculateFare(
          matrix: matrix,
          distanceKm: 1.4,
          durationMinutes: 0,
        ),
        12.0,
      );

      // 6.0 km exceeds 5.0 km by 1.0 km: 12.0 + (1.0 * 10.0) = 22.0
      expect(
        FareCalculator.calculateFare(
          matrix: matrix,
          distanceKm: 6.0,
          durationMinutes: 0,
        ),
        22.0,
      );
    });

    test('Exact 19.7 km matches between app matching service and matrix calculation', () {
      final trikMatrix = FareMatrix(
        id: 'tricycle',
        vehicleType: VehicleType.tricycle,
        baseFare: 15.0,
        includedBaseDistance: 4.0,
        perKmRate: 10.0,
        perMinuteRate: 0,
        minimumFare: 15.0,
        bookingFee: 0,
        surgeMultiplier: 1,
        commissionPercent: 0,
        isActive: true,
        updatedAt: DateTime(2026),
      );

      // 19.7 km - 4.0 km = 15.7 km chargeable
      // 15.7 km * 10.0 = 157.0
      // Total fare = 15.0 + 157.0 = 172.0 (Strictly 172, NEVER rounded to 170!)
      final fare = FareCalculator.calculateFare(
        matrix: trikMatrix,
        distanceKm: 19.7,
        durationMinutes: 26,
      );
      expect(fare, 172.0);
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
