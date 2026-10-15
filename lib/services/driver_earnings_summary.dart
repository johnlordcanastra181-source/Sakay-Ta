import '../core/constants.dart';
import '../core/philippine_time.dart';
import '../models/firestore_models.dart';
import '../models/trip.dart';

class DriverDailyEarningsSummary {
  final double earnings;
  final int trips;

  const DriverDailyEarningsSummary({
    required this.earnings,
    required this.trips,
  });
}

/// Counts only canonical completed rides whose completion timestamp falls
/// within the current Philippine calendar day. Ride IDs are counted once even
/// when a Realtime snapshot repeats a row.
DriverDailyEarningsSummary summarizeDriverEarningsToday(
  Iterable<Trip> rides, {
  DateTime? now,
}) {
  final localNow = now ?? PhilippineTime.now();
  final completedById = <String, Trip>{};

  for (final ride in rides) {
    final completedAt = ride.completedAt;
    if (ride.status != RideStatus.completed ||
        completedAt == null ||
        !PhilippineTime.isSameDay(completedAt, localNow)) {
      continue;
    }
    completedById[ride.id] = ride;
  }

  final eligibleRides = completedById.values.where(
    (ride) => ride.paymentStatus.toLowerCase().trim() != 'refunded',
  );
  return DriverDailyEarningsSummary(
    earnings: eligibleRides.fold<double>(
      0,
      (sum, ride) => sum + ride.fare,
    ),
    trips: completedById.length,
  );
}

/// Builds the Home card from the same authoritative ledger used by Wallet.
/// Ledger rows are timestamped when the ride completes, so pending settlement
/// does not hide a completed fare from today's gross earnings. Refunded rides
/// are excluded, and duplicate snapshots count each ride only once.
DriverDailyEarningsSummary summarizeDriverLedgerEarningsToday(
  Iterable<DriverEarning> earnings, {
  DateTime? now,
}) {
  final localNow = now ?? PhilippineTime.now();
  final earningsByRideId = <String, DriverEarning>{};

  for (final earning in earnings) {
    final rideId = earning.rideId.trim();
    if (rideId.isEmpty ||
        earning.settlementStatus.toLowerCase().trim() == 'refunded' ||
        !PhilippineTime.isSameDay(earning.createdAt, localNow)) {
      continue;
    }
    earningsByRideId.putIfAbsent(rideId, () => earning);
  }

  return DriverDailyEarningsSummary(
    earnings: earningsByRideId.values.fold<double>(
      0,
      (sum, earning) => sum + earning.fare,
    ),
    trips: earningsByRideId.length,
  );
}
