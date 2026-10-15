import 'package:flutter_test/flutter_test.dart';
import 'package:sakay_ta/core/constants.dart';
import 'package:sakay_ta/core/philippine_time.dart';
import 'package:sakay_ta/models/firestore_models.dart';
import 'package:sakay_ta/models/trip.dart';
import 'package:sakay_ta/services/driver_earnings_summary.dart';

Trip ride({
  required String id,
  required DateTime? completedAt,
  String status = RideStatus.completed,
  String paymentStatus = PaymentStatus.unpaid,
  double fare = 15,
}) =>
    Trip(
      id: id,
      passengerId: 'passenger-1',
      driverId: 'driver-1',
      vehicleType: VehicleType.tricycle,
      pickupAddress: 'Pickup',
      dropoffAddress: 'Dropoff',
      pickup: const Geo(10, 10),
      dropoff: const Geo(10.01, 10.01),
      distanceKm: 1,
      durationMin: 5,
      fare: fare,
      commission: 0,
      net: fare,
      status: status,
      paymentStatus: paymentStatus,
      createdAt: DateTime.utc(2026, 10, 10, 17),
      completedAt: completedAt,
    );

void main() {
  test('PhilippineTime.now returns the current instant without an added offset',
      () {
    final before = DateTime.now().subtract(const Duration(seconds: 1));
    final now = PhilippineTime.now();
    final after = DateTime.now().add(const Duration(seconds: 1));

    expect(now.isBefore(before), isFalse);
    expect(now.isAfter(after), isFalse);
  });

  test('UTC query bounds map a Philippine day to a half-open interval', () {
    final bounds = PhilippineTime.utcBoundsForPhilippineDay(
      value: DateTime.parse('2026-10-11T10:00:00Z'),
    );

    expect(bounds.startUtc, DateTime.parse('2026-10-10T16:00:00Z'));
    expect(bounds.endUtc, DateTime.parse('2026-10-11T16:00:00Z'));
    expect(
      PhilippineTime.isSameDay(bounds.startUtc, DateTime.utc(2026, 10, 11)),
      isTrue,
    );
    expect(
      PhilippineTime.isSameDay(bounds.endUtc, DateTime.utc(2026, 10, 11)),
      isFalse,
    );
  });

  test('counts completed fares once on the Philippine calendar day', () {
    final todayStart = DateTime.utc(2026, 10, 10, 16); // Oct 11, 00:00 PHT
    final summary = summarizeDriverEarningsToday(
      [
        ride(
          id: 'cash-15',
          completedAt: todayStart,
          fare: 15,
          paymentStatus: PaymentStatus.paid,
        ),
        // A completed online-payment ride is still a completed fare while
        // payment settlement is pending.
        ride(
          id: 'digital-65',
          completedAt: DateTime.utc(2026, 10, 11, 7),
          fare: 65,
        ),
        ride(
          id: 'cash-15',
          completedAt: todayStart,
          fare: 15,
        ),
        ride(
          id: 'yesterday',
          completedAt: DateTime.utc(2026, 10, 10, 15, 59, 59),
          fare: 100,
        ),
        ride(
          id: 'tomorrow',
          completedAt: DateTime.utc(2026, 10, 11, 16),
          fare: 200,
        ),
        ride(
          id: 'in-progress',
          completedAt: todayStart,
          status: RideStatus.started,
          fare: 300,
        ),
        // A missing completed_at must not fall back to created_at.
        ride(id: 'missing-completion-time', completedAt: null, fare: 400),
      ],
      now: DateTime.utc(2026, 10, 11, 8),
    );

    expect(summary.earnings, 80);
    expect(summary.trips, 2);
  });

  test('refunded completed rides count as trips but not earnings', () {
    final summary = summarizeDriverEarningsToday(
      [
        ride(
          id: 'completed-refunded',
          completedAt: DateTime.parse('2026-10-11T06:46:35Z'),
          paymentStatus: 'refunded',
          fare: 40,
        ),
        ride(
          id: 'completed-cash',
          completedAt: DateTime.parse('2026-10-11T07:00:00Z'),
          fare: 15,
        ),
      ],
      now: DateTime.parse('2026-10-11T08:00:00Z'),
    );

    expect(summary.earnings, 15);
    expect(summary.trips, 2);
  });

  test(
      'Home ledger summary includes the ride completed today and excludes old/refunded rides',
      () {
    final summary = summarizeDriverLedgerEarningsToday(
      [
        DriverEarning(
          id: 'earning-today',
          driverId: 'driver-1',
          rideId: 'ride-today',
          fare: 40,
          commission: 0,
          net: 40,
          settlementStatus: 'confirmed',
          createdAt: DateTime.parse('2026-10-11T06:46:35Z'),
        ),
        // A repeated Realtime row for the same ride must not double-count.
        DriverEarning(
          id: 'earning-today-duplicate',
          driverId: 'driver-1',
          rideId: 'ride-today',
          fare: 40,
          commission: 0,
          net: 40,
          settlementStatus: 'confirmed',
          createdAt: DateTime.parse('2026-10-11T06:46:35Z'),
        ),
        DriverEarning(
          id: 'earning-yesterday',
          driverId: 'driver-1',
          rideId: 'ride-yesterday',
          fare: 95.20,
          commission: 0,
          net: 95.20,
          settlementStatus: 'confirmed',
          createdAt: DateTime.parse('2026-10-10T15:03:55Z'),
        ),
        DriverEarning(
          id: 'earning-refunded',
          driverId: 'driver-1',
          rideId: 'ride-refunded',
          fare: 25,
          commission: 0,
          net: 25,
          settlementStatus: 'refunded',
          createdAt: DateTime.parse('2026-10-11T07:00:00Z'),
        ),
      ],
      now: DateTime.parse('2026-10-11T08:00:00Z'),
    );

    expect(summary.earnings, 40);
    expect(summary.trips, 1);
  });

  test('Home includes a same-day ride during the late Manila afternoon', () {
    final summary = summarizeDriverLedgerEarningsToday(
      [
        DriverEarning(
          id: 'earning-40',
          driverId: 'driver-1',
          rideId: 'ride-40',
          fare: 40,
          commission: 0,
          net: 40,
          settlementStatus: 'confirmed',
          createdAt: DateTime.parse('2026-10-11T06:46:35Z'),
        ),
      ],
      // 5:30 PM in Manila; the ride completed at 2:46 PM Manila time.
      now: DateTime.parse('2026-10-11T09:30:00Z'),
    );

    expect(summary.earnings, 40);
    expect(summary.trips, 1);
  });

  test('today gross includes completed fares still pending settlement', () {
    final summary = summarizeDriverLedgerEarningsToday(
      [
        DriverEarning(
          id: 'earning-pending',
          driverId: 'driver-1',
          rideId: 'ride-pending',
          fare: 15,
          commission: 0,
          net: 15,
          settlementStatus: 'pending',
          createdAt: DateTime.parse('2026-10-11T06:00:00Z'),
        ),
      ],
      now: DateTime.parse('2026-10-11T08:00:00Z'),
    );

    expect(summary.earnings, 15);
    expect(summary.trips, 1);
  });
}
