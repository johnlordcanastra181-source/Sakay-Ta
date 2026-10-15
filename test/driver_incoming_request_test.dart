import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sakay_ta/core/constants.dart';
import 'package:sakay_ta/models/trip.dart';
import 'package:sakay_ta/services/supabase_database_service.dart';
import 'package:sakay_ta/state/app_state.dart';

Trip ride({
  String id = 'ride-1',
  String? driverId,
  VehicleType vehicleType = VehicleType.habal,
  String status = RideStatus.searching,
  Geo pickup = const Geo(11.0, 124.0),
}) =>
    Trip(
      id: id,
      passengerId: 'passenger-1',
      passengerName: 'Maria Santos',
      driverId: driverId,
      vehicleType: vehicleType,
      pickupAddress: 'Pickup',
      dropoffAddress: 'Destination',
      pickup: pickup,
      dropoff: const Geo(11.1, 124.1),
      distanceKm: 2,
      durationMin: 8,
      fare: 50,
      commission: 6,
      net: 44,
      status: status,
      createdAt: DateTime(2026),
    );

void main() {
  test('an assigned searching ride bypasses discovery-only filters', () {
    final assigned = ride(driverId: 'driver-1');

    expect(
      isIncomingRideVisibleToDriver(
        trip: assigned,
        driverId: 'driver-1',
        // Simulates DriverHome briefly using its default profile while the
        // actual Habal profile is still loading.
        vehicleType: VehicleType.tricycle,
        latitude: 1,
        longitude: 1,
        radiusKm: 1,
      ),
      isTrue,
    );
    expect(
      isIncomingRideVisibleToDriver(
        trip: assigned,
        driverId: 'driver-2',
        vehicleType: VehicleType.habal,
      ),
      isFalse,
    );
  });

  test('unassigned requests still obey vehicle and distance matching', () {
    final unassigned = ride();

    expect(
      isIncomingRideVisibleToDriver(
        trip: unassigned,
        driverId: 'driver-1',
        vehicleType: VehicleType.tricycle,
      ),
      isFalse,
    );
    expect(
      isIncomingRideVisibleToDriver(
        trip: unassigned,
        driverId: 'driver-1',
        vehicleType: VehicleType.habal,
        latitude: 11,
        longitude: 124,
      ),
      isTrue,
    );
  });

  test('assigned active-trip data fills an empty Realtime result', () {
    final assigned = ride(driverId: 'driver-1');

    final merged = mergeAssignedSearchingRide(
      const [],
      assigned,
      'driver-1',
    );

    expect(merged, hasLength(1));
    expect(merged.single.id, assigned.id);
  });

  test('fallback does not duplicate a ride already received from Realtime', () {
    final assigned = ride(driverId: 'driver-1');

    final merged = mergeAssignedSearchingRide(
      [assigned],
      assigned,
      'driver-1',
    );

    expect(merged, hasLength(1));
  });

  test('request row is emitted before passenger profile enrichment', () {
    final source = File('lib/state/app_state.dart').readAsStringSync();
    final immediateIndex = source.indexOf('yield immediateRequests;');
    final profileIndex = source.indexOf(
      'final passengers = await Future.wait',
      immediateIndex,
    );

    expect(immediateIndex, greaterThan(-1));
    expect(profileIndex, greaterThan(immediateIndex));
  });
}
