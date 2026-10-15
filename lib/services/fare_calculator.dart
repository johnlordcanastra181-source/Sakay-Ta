import '../models/fare_matrix.dart';

class FareCalculator {
  /// Computes the ride fare from the active Fare Matrix.
  ///
  /// The base fare includes the configured base distance. The current
  /// configured rounding rule is the existing nearest-5-pesos rule. Legacy
  /// time, surge, booking, and payment-split columns are deliberately ignored.
  static double calculateFare({
    required FareMatrix matrix,
    required double distanceKm,
    required int durationMinutes,
  }) {
    final validKm = chargeableDistanceKm(matrix, distanceKm);
    final raw = matrix.baseFare + (validKm * matrix.perKmRate);

    // Keep the established nearest-5-pesos rounding rule.
    double rounded = (raw / 5).round() * 5.0;
    if (rounded < matrix.minimumFare) {
      rounded = matrix.minimumFare;
    }

    return rounded;
  }

  static double chargeableDistanceKm(FareMatrix matrix, double distanceKm) {
    final chargeableKm = distanceKm - matrix.includedBaseDistance;
    return chargeableKm < 0 ? 0.0 : chargeableKm;
  }
}
