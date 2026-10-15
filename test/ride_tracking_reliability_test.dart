import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart'
    show FirebaseException, GeoPoint;
import 'package:flutter_test/flutter_test.dart';
import 'package:sakay_ta/core/constants.dart';
import 'package:sakay_ta/models/trip.dart';

void main() {
  group('RideStatus Lifecycle & Alias Normalization', () {
    test('normalizes legacy and alternative status strings correctly', () {
      expect(RideStatus.normalize('requested'), RideStatus.searching);
      expect(RideStatus.normalize('pending'), RideStatus.searching);
      expect(RideStatus.normalize('assigned'), RideStatus.accepted);
      expect(RideStatus.normalize('confirmed'), RideStatus.accepted);
      expect(RideStatus.normalize('on_the_way'), RideStatus.accepted);
      expect(RideStatus.normalize('driver_arriving'), RideStatus.accepted);
      expect(RideStatus.normalize('ongoing'), RideStatus.started);
      expect(RideStatus.normalize('in_progress'), RideStatus.started);
      expect(RideStatus.normalize('canceled'), RideStatus.cancelled);
      expect(RideStatus.normalize('completed'), RideStatus.completed);
      expect(RideStatus.normalize(null), RideStatus.searching);
    });

    test('isActive identifies active vs terminal states correctly', () {
      expect(RideStatus.isActive(RideStatus.searching), isTrue);
      expect(RideStatus.isActive(RideStatus.accepted), isTrue);
      expect(RideStatus.isActive(RideStatus.arrived), isTrue);
      expect(RideStatus.isActive(RideStatus.started), isTrue);
      expect(RideStatus.isActive('in_progress'), isTrue);
      expect(RideStatus.isActive('requested'), isTrue);

      expect(RideStatus.isActive(RideStatus.completed), isFalse);
      expect(RideStatus.isActive(RideStatus.cancelled), isFalse);
    });
  });

  group('Trip Model Dual Schema & Null Safety', () {
    final now = DateTime(2026, 9, 15, 20, 0);

    test('correctly parses Firestore document with snake_case fields', () {
      final map = {
        'id': 'trip-001',
        'passenger_id': 'pass-uid-123',
        'driver_id': 'driver-uid-456',
        'vehicle_type': 'tricycle',
        'pickup_address': 'Ayala Center Cebu',
        'dropoff_address': 'IT Park Cebu',
        'pickup_lat': 10.3173,
        'pickup_lng': 123.9058,
        'dropoff_lat': 10.3297,
        'dropoff_lng': 123.9068,
        'distance_km': 2.5,
        'duration_min': 8,
        'fare': 35.0,
        'commission': 4.2,
        'net': 30.8,
        'status': 'accepted',
        'payment_method': 'cash',
        'payment_status': 'unpaid',
        'created_at': now.millisecondsSinceEpoch,
      };

      final trip = Trip.fromMap(map);
      expect(trip.id, 'trip-001');
      expect(trip.passengerId, 'pass-uid-123');
      expect(trip.driverId, 'driver-uid-456');
      expect(trip.vehicleType, VehicleType.tricycle);
      expect(trip.status, RideStatus.accepted);
      expect(trip.isActive, isTrue);
      expect(trip.pickup.lat, closeTo(10.3173, 0.001));
      expect(trip.pickup.lng, closeTo(123.9058, 0.001));
    });

    test(
        'correctly parses Firestore document with camelCase and GeoPoint fields',
        () {
      final map = {
        'id': 'trip-002',
        'passengerId': 'pass-uid-789',
        'driverId': 'driver-uid-999',
        'vehicleType': 'habal',
        'pickupAddress': 'SM City Cebu',
        'destinationAddress': 'Fuente Osmeña Circle',
        'pickupLocation': const GeoPoint(10.3117, 123.9184),
        'destinationLocation': const GeoPoint(10.3128, 123.8931),
        'distanceKm': 3.8,
        'durationMin': 12,
        'fare': 55.0,
        'status': 'in_progress',
        'paymentMethod': 'gcash',
        'createdAt': now,
      };

      final trip = Trip.fromMap(map);
      expect(trip.id, 'trip-002');
      expect(trip.passengerId, 'pass-uid-789');
      expect(trip.driverId, 'driver-uid-999');
      expect(trip.vehicleType, VehicleType.habal);
      expect(trip.status, RideStatus.started);
      expect(trip.isActive, isTrue);
      expect(trip.pickup.lat, closeTo(10.3117, 0.001));
      expect(trip.pickup.lng, closeTo(123.9184, 0.001));
    });

    test('toMap mirrors both snake_case and essential fields safely', () {
      final trip = Trip(
        id: 'trip-003',
        passengerId: 'p-1',
        driverId: 'd-1',
        vehicleType: VehicleType.tricycle,
        pickupAddress: 'A',
        dropoffAddress: 'B',
        pickup: const Geo(10.0, 123.0),
        dropoff: const Geo(10.1, 123.1),
        distanceKm: 2.0,
        durationMin: 5,
        fare: 25.0,
        commission: 3.0,
        net: 22.0,
        createdAt: now,
      );

      final map = trip.toMap();
      expect(map['id'], 'trip-003');
      expect(map['passenger_id'], 'p-1');
      expect(map['driver_id'], 'd-1');
      expect(map['fare'], 25.0);
      expect(map['status'], RideStatus.searching);
    });

    test('handles unassigned driverId safely without throwing null assertion',
        () {
      final map = {
        'id': 'trip-004',
        'passenger_id': 'pass-uid-123',
        'driver_id': null,
        'status': 'searching',
        'pickup_lat': 10.0,
        'pickup_lng': 123.0,
        'dropoff_lat': 10.1,
        'dropoff_lng': 123.1,
      };

      final trip = Trip.fromMap(map);
      expect(trip.driverId, isNull);
      expect(trip.status, RideStatus.searching);
      expect(trip.isActive, isTrue);
    });
  });

  group('Error Diagnostics & Classification Logic', () {
    String classifyError(Object? error) {
      if (error is FirebaseException) {
        if (error.code == 'permission-denied') return 'permission_error';
        if (error.code == 'failed-precondition') return 'index_error';
        if (error.code == 'unavailable') return 'service_unavailable';
        if (error.code == 'unauthenticated') return 'auth_error';
      } else if (error is SocketException) {
        return 'network_error';
      }
      return 'generic_error';
    }

    test('distinguishes permission-denied from network connection failure', () {
      final permError = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Missing or insufficient permissions.',
      );

      expect(classifyError(permError), 'permission_error');
      expect(classifyError(permError), isNot('network_error'));
    });

    test('distinguishes failed-precondition (missing index) from network error',
        () {
      final indexError = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'failed-precondition',
        message: 'The query requires an index.',
      );

      expect(classifyError(indexError), 'index_error');
      expect(classifyError(indexError), isNot('network_error'));
    });

    test('distinguishes real SocketException as network error', () {
      const socketError = SocketException('Failed host lookup');
      expect(classifyError(socketError), 'network_error');
    });
  });
}
