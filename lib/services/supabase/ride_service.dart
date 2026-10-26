import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import '../../models/app_user.dart';
import '../../models/trip.dart';
import '../../models/transaction.dart';
import '../supabase_database_service.dart';

class SupabaseRideService {
  SupabaseRideService._();
  static final SupabaseRideService instance = SupabaseRideService._();

  SupabaseClient get _db => Supabase.instance.client;

  SupabaseQueryBuilder get _tripsRef => _db.from('rides');
  SupabaseQueryBuilder get _chatRef => _db.from('chat_messages');
  SupabaseQueryBuilder get _usersRef => _db.from('profiles');
  SupabaseQueryBuilder get _driversRef => _db.from('drivers');

  Future<List<Trip>> getPassengerTrips(String passengerId) async {
    try {
      final snap = await _tripsRef
          .select()
          .eq('passenger_id', passengerId)
          .order('created_at', ascending: false);
      return snap.map((doc) => Trip.fromMap(doc)).toList();
    } catch (e) {
      return const [];
    }
  }

  Future<void> saveTrip(Trip trip) async {
    try {
      final tripMap = trip.toMap();
      await _tripsRef.upsert({
        ...tripMap,
        'id': trip.id,
        'passenger_id': trip.passengerId,
        'driver_id': trip.driverId,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[Ride] create failed $e');
      rethrow;
    }
  }

  Future<void> updateTrip(String tripId, Map<String, Object?> fields) async {
    try {
      final now = DateTime.now().toIso8601String();
      await _tripsRef.update({
        ...fields,
        'updated_at': now,
      }).eq('id', tripId);
    } catch (e) {
      debugPrint('[Ride] updateTrip note: $e');
    }
  }

  Stream<Trip?> streamActiveTripForPassenger(String passengerId) =>
      SupabaseDatabaseService.instance
          .streamActiveTripForPassenger(passengerId);

  Stream<Trip?> streamActiveTripForDriver(String driverId) =>
      SupabaseDatabaseService.instance.streamActiveTripForDriver(driverId);

  Future<bool> atomicAcceptBooking({
    required String rideId,
    required AppUser driver,
  }) async {
    try {
      final now = DateTime.now().toIso8601String();
      final List result = await _tripsRef
          .update({
            'driver_id': driver.id,
            'driverId': driver.id,
            'status': 'accepted',
            'accepted_at': now,
            'updated_at': now,
          })
          .eq('id', rideId)
          .eq('status', 'searching')
          .isFilter('driver_id', null)
          .select();

      if (result.isNotEmpty) {
        await _usersRef.update({
          'isAvailable': false,
          'activeRideId': rideId,
        }).eq('id', driver.id);

        await _driversRef.update({
          'isAvailable': false,
          'activeRideId': rideId,
        }).eq('id', driver.id);

        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[RideAccept] failed: $e');
      return false;
    }
  }

  Future<bool> transitionDriverRide({
    required String rideId,
    required String driverId,
    required Set<String> fromStatuses,
    required String toStatus,
  }) async {
    if (rideId.isEmpty || driverId.isEmpty) return false;
    try {
      final now = DateTime.now().toIso8601String();
      final updates = <String, Object?>{
        'status': toStatus,
        'updated_at': now,
        if (toStatus == 'arrived') 'arrived_at': now,
        if (toStatus == 'started') 'started_at': now,
        if (toStatus == 'completed') 'completed_at': now,
      };

      final snap = await _tripsRef.select().eq('id', rideId).maybeSingle();
      if (snap == null) return false;

      final currentDriver = snap['driver_id'] ?? snap['driverId'];
      final currentStatus = snap['status'];

      if (currentDriver != driverId || !fromStatuses.contains(currentStatus)) {
        return false;
      }

      await _tripsRef.update(updates).eq('id', rideId);

      if (['completed', 'cancelled'].contains(toStatus)) {
        final available = {
          'isAvailable': true,
          'activeRideId': null,
          'updated_at': now,
        };
        await _usersRef.update(available).eq('id', driverId);
        await _driversRef.update(available).eq('id', driverId);
      }
      return true;
    } catch (e) {
      debugPrint('[Ride] transition failed id=$rideId $e');
      return false;
    }
  }

  Future<bool> cancelRide({required String rideId}) async {
    if (rideId.isEmpty) return false;
    try {
      final authUid = Supabase.instance.client.auth.currentUser?.id;
      if (authUid == null) return false;

      final snap = await _tripsRef.select().eq('id', rideId).maybeSingle();
      if (snap == null) return false;

      final passengerId = snap['passenger_id'] ?? snap['passengerId'];
      final driverId = snap['driver_id'] ?? snap['driverId'];
      final status = snap['status'];

      if ((authUid != passengerId && authUid != driverId) ||
          ['completed', 'cancelled'].contains(status)) {
        return false;
      }

      final now = DateTime.now().toIso8601String();
      await _tripsRef.update({
        'status': 'cancelled',
        'cancelled_at': now,
        'cancelledBy': authUid,
        'updated_at': now,
      }).eq('id', rideId);

      if (driverId != null && driverId.toString().isNotEmpty) {
        final available = {
          'isAvailable': true,
          'activeRideId': null,
          'updated_at': now,
        };
        await _usersRef.update(available).eq('id', driverId);
        await _driversRef.update(available).eq('id', driverId);
      }
      return true;
    } catch (e) {
      debugPrint('[Ride] cancellation failed id=$rideId $e');
      return false;
    }
  }

  Future<void> declineBooking({
    required String rideId,
    required String driverId,
  }) async {
    try {
      await _tripsRef
          .update({
            'driver_id': null,
            'driverId': null,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', rideId)
          .eq('driver_id', driverId);
    } catch (e) {
      debugPrint('declineBooking skipped ($e)');
    }
  }

  Stream<Trip?> streamTrip(String rideId) =>
      SupabaseDatabaseService.instance.streamTrip(rideId);

  Future<Trip?> getTrip(String tripId) async {
    try {
      final snap = await _tripsRef.select().eq('id', tripId).maybeSingle();
      if (snap == null) return null;
      return Trip.fromMap(snap);
    } catch (e) {
      return null;
    }
  }

  Future<void> saveBooking(Map<String, dynamic> bookingMap) async {
    try {
      final id = bookingMap['id'] as String?;
      if (id != null) {
        await _tripsRef.upsert(bookingMap);
      }
    } catch (e) {
      debugPrint('RideService non-fatal note: $e');
    }
  }

  Future<void> saveChatMessage(ChatMessage message) async {
    try {
      await _chatRef.upsert(message.toMap());
    } catch (e) {
      // Ignore
    }
  }

  Future<void> acceptRide({
    required String rideId,
    required AppUser driver,
  }) async {
    try {
      await _tripsRef.update({
        'driver_id': driver.id,
        'driverId': driver.id,
        'status': 'accepted',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', rideId);
    } catch (e) {
      debugPrint('acceptRide skipped ($e)');
    }
  }

  Future<void> startTrip({
    required String rideId,
    double? driverLat,
    double? driverLng,
  }) async {
    try {
      await _tripsRef.update({
        'status': 'started',
        'started_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', rideId);
    } catch (e) {
      debugPrint('startTrip skipped ($e)');
    }
  }

  Future<void> completeTrip({
    required String rideId,
    required double actualFare,
  }) async {
    try {
      final driverId = Supabase.instance.client.auth.currentUser?.id;
      if (driverId == null) {
        throw StateError('No authenticated driver.');
      }
      final changed = await transitionDriverRide(
        rideId: rideId,
        driverId: driverId,
        fromStatuses: const {'started'},
        toStatus: 'completed',
      );
      if (!changed) {
        throw StateError('This ride can no longer be completed.');
      }
      await _tripsRef.update({
        'actual_fare': actualFare,
        'actualFare': actualFare,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', rideId);
    } catch (e) {
      debugPrint('completeTrip error: $e');
      rethrow;
    }
  }

  Future<void> adminCancelTrip(String tripId, String reason) async {
    try {
      await _tripsRef.update({
        'status': 'cancelled',
        'cancelled_at': DateTime.now().toIso8601String(),
        'cancellation_reason': 'Admin Cancelled: $reason',
      }).eq('id', tripId);
    } catch (e) {
      debugPrint('adminCancelTrip error: $e');
    }
  }
}
