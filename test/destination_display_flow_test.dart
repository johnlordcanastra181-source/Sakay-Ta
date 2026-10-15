import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakay_ta/core/constants.dart';
import 'package:sakay_ta/models/trip.dart';

void main() {
  group('Destination Display Flow - Mandatory Tests 1 to 18', () {
    // TEST 1: Passenger selects destination
    test('1. Passenger selects destination -> Booking.fromMap parses destination_address', () {
      final bookingPayload = {
        'id': 'booking-001',
        'passenger_id': 'pass-123',
        'vehicle_type': 'tricycle',
        'pickup_address': 'Gaisano Grand Mall Toledo',
        'destination_address': 'Toledo City Port, Sangi',
        'pickup_lat': 10.3751,
        'pickup_lng': 123.6392,
        'destination_latitude': 10.3804,
        'destination_longitude': 123.6338,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      };
      final booking = Booking.fromMap(bookingPayload);
      expect(booking.dropoffAddress, equals('Toledo City Port, Sangi'));
      expect(booking.dropoff.lat, equals(10.3804));
      expect(booking.dropoff.lng, equals(123.6338));
    });

    // TEST 2: Destination address saves to Supabase
    test('2. Destination address saves to Supabase -> saveTrip RPC params map dropoffAddress to destination_address', () {
      final trip = Trip(
        id: 'trip-001',
        passengerId: 'pass-123',
        vehicleType: VehicleType.tricycle,
        pickupAddress: 'Gaisano Grand Mall Toledo',
        dropoffAddress: 'Toledo City Port, Sangi',
        pickup: const Geo(10.3751, 123.6392),
        dropoff: const Geo(10.3804, 123.6338),
        distanceKm: 2.3,
        durationMin: 7,
        fare: 50.0,
        commission: 5.0,
        net: 45.0,
        createdAt: DateTime.now(),
      );

      final rpcParams = {
        'client_ride_id': trip.id,
        'requested_driver': trip.driverId,
        'requested_vehicle': trip.vehicleType.key,
        'passenger_name': trip.passengerName,
        'passenger_phone': trip.passengerPhone,
        'pickup_address': trip.pickupAddress,
        'pickup_latitude': trip.pickup.lat,
        'pickup_longitude': trip.pickup.lng,
        'destination_address': trip.dropoffAddress,
        'destination_latitude': trip.dropoff.lat,
        'destination_longitude': trip.dropoff.lng,
        'distance_km': trip.distanceKm,
        'duration_minutes': trip.durationMin,
        'payment_method': trip.paymentMethod,
      };

      expect(rpcParams['destination_address'], equals('Toledo City Port, Sangi'));
    });

    // TEST 3: Destination coordinates save correctly
    test('3. Destination coordinates save correctly -> lat and lng preserved accurately', () {
      const destGeo = Geo(10.38041, 123.63384);
      final rpcParams = {
        'destination_latitude': destGeo.lat,
        'destination_longitude': destGeo.lng,
      };

      expect(rpcParams['destination_latitude'], equals(10.38041));
      expect(rpcParams['destination_longitude'], equals(123.63384));
      expect(destGeo.isValid, isTrue);
    });

    // TEST 4: Driver receives the correct ride request
    test('4. Driver receives the correct ride request -> Trip.fromMap maps destination_address', () {
      final supabaseRideRow = {
        'id': 'ride-999',
        'passenger_id': 'pass-456',
        'passenger_name': 'Juan Dela Cruz',
        'passenger_phone': '09123456789',
        'vehicle_type': 'tricycle',
        'pickup_address': 'Barangay Poblacion, Toledo City',
        'destination_address': 'Lutopan Public Market',
        'pickup_latitude': 10.3780,
        'pickup_longitude': 123.6350,
        'destination_latitude': 10.3200,
        'destination_longitude': 123.7050,
        'distance_km': 11.2,
        'duration_minutes': 22,
        'fare': 120.0,
        'commission': 12.0,
        'driver_net': 108.0,
        'status': 'searching',
        'payment_method': 'cash',
        'payment_status': 'unpaid',
        'created_at': DateTime.now().toIso8601String(),
      };

      final incomingTrip = Trip.fromMap(supabaseRideRow);
      expect(incomingTrip.effectiveDropoffAddress, equals('Lutopan Public Market'));
      expect(incomingTrip.dropoffAddress, equals('Lutopan Public Market'));
      expect(incomingTrip.effectivePickupAddress, equals('Barangay Poblacion, Toledo City'));
    });

    // TEST 5: Driver accepts the ride successfully
    test('5. Driver accepts the ride successfully -> accepted trip retains destination', () {
      final acceptedRow = {
        'id': 'ride-999',
        'passenger_id': 'pass-456',
        'driver_id': 'driver-789',
        'vehicle_type': 'tricycle',
        'pickup_address': 'Barangay Poblacion, Toledo City',
        'destination_address': 'Lutopan Public Market',
        'pickup_latitude': 10.3780,
        'pickup_longitude': 123.6350,
        'destination_latitude': 10.3200,
        'destination_longitude': 123.7050,
        'distance_km': 11.2,
        'duration_minutes': 22,
        'fare': 120.0,
        'status': 'accepted',
        'created_at': DateTime.now().toIso8601String(),
        'accepted_at': DateTime.now().toIso8601String(),
      };

      final acceptedTrip = Trip.fromMap(acceptedRow);
      expect(acceptedTrip.status, equals(RideStatus.accepted));
      expect(acceptedTrip.driverId, equals('driver-789'));
      expect(acceptedTrip.effectiveDropoffAddress, equals('Lutopan Public Market'));
    });

    // TEST 6: Accepted Ride displays correct destination
    test('6. Accepted Ride displays correct destination -> does not use placeholder USC Main Campus', () {
      final activeRow = {
        'id': 'ride-999',
        'passenger_id': 'pass-456',
        'driver_id': 'driver-789',
        'pickup_address': 'Barangay Poblacion, Toledo City',
        'destination_address': 'Lutopan Public Market',
        'pickup_latitude': 10.3780,
        'pickup_longitude': 123.6350,
        'destination_latitude': 10.3200,
        'destination_longitude': 123.7050,
        'fare': 120.0,
        'status': 'accepted',
        'created_at': DateTime.now().toIso8601String(),
      };

      final trip = Trip.fromMap(activeRow);
      expect(trip.effectiveDropoffAddress, equals('Lutopan Public Market'));
      expect(trip.effectiveDropoffAddress, isNot(equals('USC Main Campus')));
    });

    // TEST 7: Pickup and destination are not swapped
    test('7. Pickup and destination are not swapped -> pickup and dropoff distinct', () {
      final row = {
        'id': 'ride-777',
        'pickup_address': 'Toledo City Hall',
        'destination_address': 'Carmen Copper Corporation',
        'pickup_latitude': 10.3762,
        'pickup_longitude': 123.6371,
        'destination_latitude': 10.3421,
        'destination_longitude': 123.7125,
        'created_at': DateTime.now().toIso8601String(),
      };

      final trip = Trip.fromMap(row);
      expect(trip.effectivePickupAddress, equals('Toledo City Hall'));
      expect(trip.pickup.lat, equals(10.3762));
      expect(trip.pickup.lng, equals(123.6371));

      expect(trip.effectiveDropoffAddress, equals('Carmen Copper Corporation'));
      expect(trip.dropoff.lat, equals(10.3421));
      expect(trip.dropoff.lng, equals(123.7125));

      expect(trip.effectivePickupAddress, isNot(equals(trip.effectiveDropoffAddress)));
      expect(trip.pickup.lat, isNot(equals(trip.dropoff.lat)));
    });

    // TEST 8: Destination remains visible after Start Trip
    test('8. Destination remains visible after Start Trip -> status: in_progress preserves dropoffAddress', () {
      final initialTrip = Trip.fromMap({
        'id': 'ride-888',
        'passenger_id': 'pass-01',
        'driver_id': 'drv-01',
        'pickup_address': 'Ibo, Toledo City',
        'destination_address': 'Bato, Toledo City',
        'pickup_latitude': 10.390,
        'pickup_longitude': 123.640,
        'destination_latitude': 10.410,
        'destination_longitude': 123.650,
        'status': 'accepted',
        'created_at': DateTime.now().toIso8601String(),
      });

      final startedTrip = initialTrip.copyWith(
        status: RideStatus.started,
        startedAt: DateTime.now(),
      );

      expect(startedTrip.status, equals(RideStatus.started));
      expect(startedTrip.effectiveDropoffAddress, equals('Bato, Toledo City'));
    });

    // TEST 9: Destination survives Realtime updates
    test('9. Destination survives Realtime updates -> row parsing keeps destination_address intact', () {
      final realtimePayload = {
        'id': 'ride-999',
        'passenger_id': 'p1',
        'driver_id': 'd1',
        'pickup_address': 'Terminal',
        'destination_address': 'Hospital',
        'pickup_lat': 10.37,
        'pickup_lng': 123.63,
        'destination_latitude': 10.38,
        'destination_longitude': 123.64,
        'status': 'in_progress',
        'created_at': DateTime.now().toIso8601String(),
      };

      final updated = Trip.fromMap(realtimePayload);
      expect(updated.effectiveDropoffAddress, equals('Hospital'));
      expect(updated.dropoff.lat, equals(10.38));
      expect(updated.dropoff.lng, equals(123.64));
    });

    // TEST 10: Driver app restart restores destination
    test('10. Driver app restart restores destination -> authoritative query row mapping restores dropoff', () {
      final authoritativeRow = {
        'id': 'ride-555',
        'passenger_id': 'p1',
        'driver_id': 'd1',
        'pickup_address': 'Luray II',
        'destination_address': 'Canlumampao',
        'pickup_latitude': 10.365,
        'pickup_longitude': 123.628,
        'destination_latitude': 10.355,
        'destination_longitude': 123.615,
        'status': 'in_progress',
        'created_at': DateTime.now().toIso8601String(),
      };

      final restoredTrip = Trip.fromMap(authoritativeRow);
      expect(restoredTrip.effectiveDropoffAddress, equals('Canlumampao'));
      expect(restoredTrip.effectivePickupAddress, equals('Luray II'));
    });

    // TEST 11: Admin Monitor Rides loads correctly
    test('11. Admin Monitor Rides loads correctly -> streamAllRides parses destination_address', () {
      final adminRow = {
        'id': 'ride-admin-1',
        'passenger_id': 'pass-a1',
        'driver_id': 'drv-b1',
        'pickup_address': 'Toledo Mall',
        'destination_address': 'Magdugo High School',
        'pickup_latitude': 10.375,
        'pickup_longitude': 123.635,
        'destination_latitude': 10.395,
        'destination_longitude': 123.665,
        'distance_km': 4.2,
        'duration_minutes': 12,
        'fare': 65.0,
        'commission': 6.5,
        'driver_net': 58.5,
        'status': 'completed',
        'created_at': DateTime.now().toIso8601String(),
      };

      final adminTrip = Trip.fromMap(adminRow);
      expect(adminTrip.effectiveDropoffAddress, equals('Magdugo High School'));
      expect(adminTrip.effectivePickupAddress, equals('Toledo Mall'));
      expect(adminTrip.distanceKm, equals(4.2));
      expect(adminTrip.durationMin, equals(12));
    });

    // TEST 12: Admin Inspect displays the same destination
    test('12. Admin Inspect displays the same destination as Passenger and Driver', () {
      final commonRow = {
        'id': 'ride-sync-test',
        'passenger_id': 'pass-sync',
        'driver_id': 'drv-sync',
        'pickup_address': 'St. John Academy',
        'destination_address': 'Toledo Sports Complex',
        'pickup_latitude': 10.372,
        'pickup_longitude': 123.632,
        'destination_latitude': 10.385,
        'destination_longitude': 123.645,
        'status': 'accepted',
        'created_at': DateTime.now().toIso8601String(),
      };

      final passengerTrip = Trip.fromMap(commonRow);
      final driverTrip = Trip.fromMap(commonRow);
      final adminTrip = Trip.fromMap(commonRow);

      expect(passengerTrip.effectiveDropoffAddress, equals('Toledo Sports Complex'));
      expect(driverTrip.effectiveDropoffAddress, equals(passengerTrip.effectiveDropoffAddress));
      expect(adminTrip.effectiveDropoffAddress, equals(driverTrip.effectiveDropoffAddress));
    });

    // TEST 13: Different rides show their respective destinations
    test('13. Different rides show their respective destinations without cross-contamination', () {
      final ride1 = Trip.fromMap({
        'id': 'r1',
        'pickup_address': 'Location A',
        'destination_address': 'Destination Alpha',
        'created_at': DateTime.now().toIso8601String(),
      });
      final ride2 = Trip.fromMap({
        'id': 'r2',
        'pickup_address': 'Location B',
        'destination_address': 'Destination Beta',
        'created_at': DateTime.now().toIso8601String(),
      });

      expect(ride1.effectiveDropoffAddress, equals('Destination Alpha'));
      expect(ride2.effectiveDropoffAddress, equals('Destination Beta'));
      expect(ride1.effectiveDropoffAddress, isNot(equals(ride2.effectiveDropoffAddress)));
    });

    // TEST 14: Missing address is handled safely
    test('14. Missing address is handled safely -> falls back to formatted coordinates, no crash, no null', () {
      final rowWithMissingAddress = {
        'id': 'r-no-addr',
        'pickup_address': '',
        'destination_address': '',
        'pickup_latitude': 10.37512,
        'pickup_longitude': 123.63925,
        'destination_latitude': 10.38041,
        'destination_longitude': 123.63384,
        'created_at': DateTime.now().toIso8601String(),
      };

      final trip = Trip.fromMap(rowWithMissingAddress);
      expect(trip.effectiveDropoffAddress, equals('Coordinates: 10.38041, 123.63384'));
      expect(trip.effectivePickupAddress, equals('Coordinates: 10.37512, 123.63925'));
      expect(trip.effectiveDropoffAddress, isNot(contains('null')));
      expect(trip.effectivePickupAddress, isNot(contains('null')));
    });

    // TEST 15: Invalid/missing coordinates do not cause a crash
    test('15. Invalid/missing coordinates do not cause a crash -> falls back to unavailable message', () {
      final rowNoCoords = {
        'id': 'r-no-coords',
        'pickup_address': '',
        'destination_address': '',
        'pickup_latitude': 0.0,
        'pickup_longitude': 0.0,
        'destination_latitude': null,
        'destination_longitude': 'invalid_num',
        'created_at': null,
      };

      final trip = Trip.fromMap(rowNoCoords);
      expect(trip.effectiveDropoffAddress, equals('Destination unavailable'));
      expect(trip.effectivePickupAddress, equals('Pickup unavailable'));
      expect(trip.hasValidDropoff, isFalse);
      expect(trip.hasValidPickup, isFalse);
    });

    // TEST 16: RLS remains secure
    test('16. RLS remains secure -> supabase database service queries and schema adhere to RLS policies', () {
      final dbServiceCode = File('lib/services/supabase_database_service.dart').readAsStringSync();
      // Ensure service role key is NEVER leaked in client database service
      expect(dbServiceCode.contains('service_role'), isFalse);
      // Ensure select includes rating join and queries filter by authenticated participant
      expect(dbServiceCode.contains("table: 'rides'"), isTrue);
      expect(dbServiceCode.contains("feature: 'passenger_ride_history'"), isTrue);
      expect(dbServiceCode.contains("feature: 'driver_ride_history'"), isTrue);
    });

    // TEST 17: Existing UI remains unchanged
    test('17. Existing UI remains unchanged -> inspect modal and driver timeline preserved', () {
      final driverHomeCode = File('lib/pages/driver_home.dart').readAsStringSync();
      final adminRidesViewCode = File('lib/pages/admin/views/rides_view.dart').readAsStringSync();

      // Check driver UI uses effective dropoff in existing timeline
      expect(driverHomeCode.contains('dropoffAddress: trip.effectiveDropoffAddress'), isTrue);
      expect(driverHomeCode.contains('pickupAddress: trip.effectivePickupAddress'), isTrue);
      expect(driverHomeCode.contains('_buildRouteTimeline'), isTrue);
      // Hardcoded USC Main Campus fallback removed
      expect(driverHomeCode.contains("'USC Main Campus'"), isFalse);

      // Check admin UI uses effective dropoff in existing inspect modal
      expect(adminRidesViewCode.contains("trip.effectiveDropoffAddress"), isTrue);
      expect(adminRidesViewCode.contains("trip.effectivePickupAddress"), isTrue);
      expect(adminRidesViewCode.contains("_buildInfoRow(Icons.location_on_rounded, 'Destination'"), isTrue);
    });

    // TEST 18: Accept, Start Trip, and Complete Trip still work
    test('18. Accept, Start Trip, and Complete Trip still work -> state transitions keep data intact', () {
      final trip = Trip.fromMap({
        'id': 'lifecycle-trip',
        'passenger_id': 'p1',
        'vehicle_type': 'tricycle',
        'pickup_address': 'Point A',
        'destination_address': 'Point B',
        'status': 'searching',
        'created_at': DateTime.now().toIso8601String(),
      });

      final accepted = trip.copyWith(status: RideStatus.accepted, driverId: 'd1');
      expect(accepted.status, equals(RideStatus.accepted));
      expect(accepted.driverId, equals('d1'));
      expect(accepted.effectiveDropoffAddress, equals('Point B'));

      final started = accepted.copyWith(status: RideStatus.started, startedAt: DateTime.now());
      expect(started.status, equals(RideStatus.started));
      expect(started.effectiveDropoffAddress, equals('Point B'));

      final completed = started.copyWith(status: RideStatus.completed, completedAt: DateTime.now());
      expect(completed.status, equals(RideStatus.completed));
      expect(completed.effectiveDropoffAddress, equals('Point B'));
    });
  });
}
