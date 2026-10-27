import '../models/fare_matrix.dart';

class FareCalculator {
  /// Automatic rounding rule inside the app:
  /// If the fractional part is .50 or greater, it rounds up (e.g. 45.50 -> 46).
  /// If it is below .50 (e.g. 45.45), it rounds down to 45.
  static double roundFare(num fare) {
    final parsed = double.parse(fare.toStringAsFixed(2));
    return parsed.roundToDouble();
  }

  /// Formats fare for display inside the app (e.g. '₱45' or '₱46').
  static String formatFare(num fare) {
    return '₱${roundFare(fare).toInt()}';
  }

  /// Computes the ride fare from the active Fare Matrix.
  ///
  /// Transparent Formula: Total Fare = Minimum Fare + Distance Charge
  /// where Distance Charge = max(0, distanceKm - includedBaseDistance) * perKmRate.
  /// Automatically rounded to whole pesos (.50+ rounds up, <.50 rounds down).
  static double calculateFare({
    required FareMatrix matrix,
    required double distanceKm,
    required int durationMinutes,
  }) {
    final validKm = chargeableDistanceKm(matrix, distanceKm);
    final distanceCharge = validKm * matrix.perKmRate;
    final total = matrix.baseFare + distanceCharge;
    return roundFare(total);
  }

  static double chargeableDistanceKm(FareMatrix matrix, double distanceKm) {
    final chargeableKm = distanceKm - matrix.includedBaseDistance;
    return chargeableKm < 0 ? 0.0 : chargeableKm;
  }
}
