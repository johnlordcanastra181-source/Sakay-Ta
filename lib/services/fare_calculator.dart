import '../models/fare_matrix.dart';

class FareCalculator {
  /// Computes the ride fare from the active Fare Matrix.
  ///
  /// Transparent Formula: Total Fare = Minimum Fare + Distance Charge
  /// where Distance Charge = max(0, distanceKm - includedBaseDistance) * perKmRate.
  static double calculateFare({
    required FareMatrix matrix,
    required double distanceKm,
    required int durationMinutes,
  }) {
    final validKm = chargeableDistanceKm(matrix, distanceKm);
    final distanceCharge = validKm * matrix.perKmRate;
    final total = matrix.baseFare + distanceCharge;
    return double.parse(total.toStringAsFixed(2));
  }

  static double chargeableDistanceKm(FareMatrix matrix, double distanceKm) {
    final chargeableKm = distanceKm - matrix.includedBaseDistance;
    return chargeableKm < 0 ? 0.0 : chargeableKm;
  }
}
