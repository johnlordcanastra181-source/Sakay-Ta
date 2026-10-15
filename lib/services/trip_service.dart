import 'package:flutter/foundation.dart' show debugPrint;
import 'package:uuid/uuid.dart';

import '../core/constants.dart';
import '../models/app_user.dart';
import '../models/transaction.dart';
import '../models/trip.dart';
import 'auth_service.dart';
import 'database_service.dart';
import 'supabase_service.dart';

class TripService {
  final DatabaseService db;
  final AuthService auth;
  const TripService(this.db, this.auth);

  static const _uuid = Uuid();

  Future<double> estimateFare(VehicleType type, Geo from, Geo to) {
    final km = Geo.distanceKm(from, to);
    return Future.value(RideConfig.fareFor(type, km));
  }

  Future<Trip> requestTrip({
    required String passengerId,
    required VehicleType vehicleType,
    required String pickupAddress,
    required String dropoffAddress,
    required Geo pickup,
    required Geo dropoff,
    required double estimatedFare,
    String paymentMethod = PaymentMethod.cash,
    bool queued = false,
    String? driverId,
  }) async {
    final database = await db.database;
    final id = _uuid.v4();
    final km = Geo.distanceKm(pickup, dropoff);
    final fare = estimatedFare;
    final duration = (km / 25 * 60).ceil().clamp(2, 180);

    final passenger = await auth.getUser(passengerId);
    final trip = Trip(
      id: id,
      passengerId: passengerId,
      passengerName: passenger?.fullName ?? '',
      passengerPhone: passenger?.mobile ?? '',
      driverId: driverId,
      vehicleType: vehicleType,
      pickupAddress: pickupAddress,
      dropoffAddress: dropoffAddress,
      pickup: pickup,
      dropoff: dropoff,
      distanceKm: km,
      durationMin: duration,
      fare: fare,
      // Legacy storage columns remain for compatibility. New rides use the
      // full confirmed fare for driver earnings.
      commission: 0,
      net: fare,
      paymentMethod: paymentMethod,
      createdAt: DateTime.now(),
      queued: queued,
    );

    var authoritativeTrip = trip;

    if (!queued) {
      // Persist remotely first. A rejected or raced booking must not leave a
      // fake active trip in the passenger's local database.
      authoritativeTrip = await SupabaseService.instance.saveTrip(trip) ?? trip;
    }

    try {
      // Use the fare returned by the secured RPC so passenger cache, driver
      // requests, and the stored ride all show the same confirmed amount.
      await database.insert('trip', authoritativeTrip.toMap());
      await database.insert(
        'booking',
        Booking(
          id: _uuid.v4(),
          passengerId: passengerId,
          vehicleType: vehicleType,
          pickupAddress: pickupAddress,
          dropoffAddress: dropoffAddress,
          pickup: pickup,
          dropoff: dropoff,
          paymentMethod: paymentMethod,
          queued: queued,
          createdAt: authoritativeTrip.createdAt,
        ).toMap(),
      );
    } catch (error) {
      if (queued) rethrow;
      // The secured RPC already created the authoritative ride. A local cache
      // failure must not turn it into a false booking failure.
      debugPrint('TripService: persisted ride local cache note ($error)');
    }
    return authoritativeTrip;
  }

  Future<Trip> _assign(Trip trip, AppUser driver) async {
    final database = await db.database;
    final updated = trip.copyWith(driverId: driver.id);
    await database
        .update('trip', updated.toMap(), where: 'id = ?', whereArgs: [trip.id]);
    await SupabaseService.instance.updateTrip(trip.id, {
      'driver_id': driver.id,
    });
    return updated;
  }

  Future<Trip> _accept(Trip trip, AppUser driver) async {
    final database = await db.database;
    final updated = trip.copyWith(
      driverId: driver.id,
      status: RideStatus.accepted,
      acceptedAt: DateTime.now(),
    );
    await database
        .update('trip', updated.toMap(), where: 'id = ?', whereArgs: [trip.id]);
    final acceptanceTotal = driver.acceptanceTotal + 1;
    final acceptanceCount = driver.acceptanceCount + 1;
    await database.update(
      'users',
      {
        'acceptance_total': acceptanceTotal,
        'acceptance_count': acceptanceCount,
      },
      where: 'id = ?',
      whereArgs: [driver.id],
    );
    if (SupabaseService.isConfigured) {
      await SupabaseService.instance.updateTrip(trip.id, {
        'driver_id': driver.id,
        'status': RideStatus.accepted,
        'accepted_at': updated.acceptedAt!.millisecondsSinceEpoch,
      });
      // Notify the passenger that their ride has been accepted.
      await SupabaseService.instance.pushNotification(
        userId: trip.passengerId,
        title: 'Driver Accepted',
        body: '${driver.fullName} accepted your ride.',
        senderId: driver.id,
        tripId: trip.id,
      );
    }
    return updated;
  }

  Future<void> acceptIncoming(String tripId, String driverId) async {
    final driver = await auth.getUser(driverId);
    final trip = await getById(tripId);
    if (trip == null || driver == null) return;
    await _accept(trip, driver);
  }

  Future<void> declineIncoming(String tripId, String driverId) async {
    final database = await db.database;
    final driver = await auth.getUser(driverId);
    final trip = await getById(tripId);
    if (driver == null || trip == null || trip.driverId != driverId) return;
    await database.update(
      'users',
      {'acceptance_total': driver.acceptanceTotal + 1},
      where: 'id = ?',
      whereArgs: [driverId],
    );
  }

  Future<void> setStatus(String tripId, String status) async {
    await setStatusLocally(tripId, status);
    await SupabaseService.instance.updateTrip(tripId, {'status': status});
  }

  /// Updates the offline cache after a secured remote transition or queueing.
  /// This deliberately does not issue another Supabase status transition.
  Future<void> setStatusLocally(String tripId, String status) async {
    final database = await db.database;
    final rows = await database.query(
      'trip',
      where: 'id = ?',
      whereArgs: [tripId],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final trip = Trip.fromMap(rows.first);
    final now = DateTime.now();
    final updated = trip.copyWith(
      status: status,
      paymentStatus: status == RideStatus.completed &&
              trip.paymentMethod.toLowerCase() == PaymentMethod.cash
          ? PaymentStatus.paid
          : trip.paymentStatus,
      arrivedAt: status == RideStatus.arrived ? now : trip.arrivedAt,
      startedAt: status == RideStatus.started ? now : trip.startedAt,
      completedAt: status == RideStatus.completed ? now : trip.completedAt,
    );
    await database
        .update('trip', updated.toMap(), where: 'id = ?', whereArgs: [tripId]);
  }

  Future<void> markOnTime(String tripId) async {
    final database = await db.database;
    final trip = await getById(tripId);
    if (trip == null || trip.driverId == null) return;
    final driver = await auth.getUser(trip.driverId!);
    if (driver == null) return;
    await database.update(
      'users',
      {
        'on_time_count': driver.onTimeCount + 1,
        'total_trips': driver.totalTrips + 1,
      },
      where: 'id = ?',
      whereArgs: [driver.id],
    );
  }

  Future<void> cancelTrip(String tripId) async {
    final database = await db.database;
    final trip = await getById(tripId);
    if (trip == null) return;
    final updated = trip.copyWith(status: RideStatus.cancelled);
    await database
        .update('trip', updated.toMap(), where: 'id = ?', whereArgs: [tripId]);
    await SupabaseService.instance.updateTrip(tripId, {
      'status': RideStatus.cancelled,
    });
  }

  Future<void> rateTrip({
    required String tripId,
    required int rating,
    required String comment,
  }) async {
    final database = await db.database;
    final trip = await getById(tripId);
    if (trip == null ||
        trip.driverId == null ||
        trip.status != RideStatus.completed ||
        trip.rating != null) {
      return;
    }
    final updated = trip.copyWith(rating: rating, ratingComment: comment);
    await database
        .update('trip', updated.toMap(), where: 'id = ?', whereArgs: [tripId]);

    final driver = await auth.getUser(trip.driverId!);
    if (driver != null) {
      final newCount = driver.ratingCount + 1;
      final newRating =
          (driver.rating * driver.ratingCount + rating) / newCount;
      await database.update(
        'users',
        {'rating': newRating, 'rating_count': newCount},
        where: 'id = ?',
        whereArgs: [driver.id],
      );
    }

    await database.insert(
        'review',
        Review(
          id: _uuid.v4(),
          tripId: tripId,
          driverId: trip.driverId!,
          passengerId: trip.passengerId,
          passengerName: '',
          rating: rating,
          comment: comment,
          createdAt: DateTime.now(),
        ).toMap());
  }

  Future<Trip?> getById(String id) async {
    if (SupabaseService.isConfigured) {
      try {
        final cloudTrip = await SupabaseService.instance.getTrip(id);
        if (cloudTrip != null) return cloudTrip;
      } catch (_) {}
    }
    try {
      final database = await db.database;
      final rows = await database.query(
        'trip',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isNotEmpty) return Trip.fromMap(rows.first);
    } catch (e) {
      debugPrint('TripService: getById local db note ($e)');
    }
    return null;
  }

  Future<Trip?> activeTripForPassenger(String passengerId) async {
    if (SupabaseService.isConfigured) {
      try {
        final trip = await SupabaseService.instance
            .streamActiveTripForPassenger(passengerId)
            .first
            .timeout(const Duration(seconds: 4));
        if (trip != null) return trip;
      } catch (_) {}
    }
    try {
      final database = await db.database;
      final rows = await database.query(
        'trip',
        where: 'passenger_id = ? AND status IN (?, ?, ?, ?)',
        whereArgs: [
          passengerId,
          RideStatus.searching,
          RideStatus.accepted,
          RideStatus.arrived,
          RideStatus.started,
        ],
        orderBy: 'created_at DESC',
        limit: 1,
      );
      if (rows.isNotEmpty) return Trip.fromMap(rows.first);
    } catch (_) {}
    return null;
  }

  Future<Trip?> activeTripForDriver(String driverId) async {
    if (SupabaseService.isConfigured) {
      try {
        final trip = await SupabaseService.instance
            .streamActiveTripForDriver(driverId)
            .first
            .timeout(const Duration(seconds: 4));
        if (trip != null) return trip;
      } catch (_) {}
    }
    try {
      final database = await db.database;
      final rows = await database.query(
        'trip',
        where: 'driver_id = ? AND status IN (?, ?, ?, ?)',
        whereArgs: [
          driverId,
          RideStatus.searching,
          RideStatus.accepted,
          RideStatus.arrived,
          RideStatus.started,
        ],
        orderBy: 'created_at DESC',
        limit: 1,
      );
      if (rows.isNotEmpty) return Trip.fromMap(rows.first);
    } catch (_) {}
    return null;
  }

  Future<Trip?> incomingTripForDriver(String driverId) async {
    if (SupabaseService.isConfigured) {
      try {
        final snap = await SupabaseService.instance
            .streamIncomingRequestsForDriver(
                driverId: driverId, vehicleType: VehicleType.tricycle)
            .first
            .timeout(const Duration(seconds: 4));
        if (snap.isNotEmpty) return snap.first;
      } catch (_) {}
    }
    try {
      final database = await db.database;
      final rows = await database.query(
        'trip',
        where: 'driver_id = ? AND status = ?',
        whereArgs: [driverId, RideStatus.searching],
        orderBy: 'created_at DESC',
        limit: 1,
      );
      if (rows.isNotEmpty) return Trip.fromMap(rows.first);
    } catch (_) {}
    return null;
  }

  Future<List<Trip>> listIncomingTripsForDriver(
    String driverId,
    VehicleType vehicleType, {
    Geo? driverLocation,
    double radiusKm = 10.0,
  }) async {
    if (SupabaseService.isConfigured) {
      try {
        final cloudTrips = await SupabaseService.instance
            .streamIncomingRequestsForDriver(
              driverId: driverId,
              vehicleType: vehicleType,
              lat: driverLocation?.lat,
              lng: driverLocation?.lng,
              radiusKm: radiusKm,
            )
            .first
            .timeout(const Duration(seconds: 4));
        if (cloudTrips.isNotEmpty) return cloudTrips;
      } catch (_) {}
    }
    try {
      final database = await db.database;
      final rows = await database.query(
        'trip',
        where: 'status = ?',
        whereArgs: [RideStatus.searching],
        orderBy: 'created_at DESC',
      );
      final all = rows.map(Trip.fromMap).toList();
      final eligible = <Trip>[];
      for (final trip in all) {
        if (trip.driverId == driverId) {
          eligible.add(trip);
          continue;
        }
        if (trip.driverId == null || trip.driverId!.isEmpty) {
          if (trip.vehicleType != vehicleType) continue;
          if (driverLocation != null) {
            final dist = Geo.distanceKm(driverLocation, trip.pickup);
            if (dist > radiusKm) continue;
          }
          eligible.add(trip);
        }
      }
      return eligible;
    } catch (_) {
      return [];
    }
  }

  Future<bool> atomicAccept(String tripId, AppUser driver) async {
    if (SupabaseService.isConfigured) {
      final cloudSuccess = await SupabaseService.instance
          .atomicAcceptBooking(rideId: tripId, driver: driver);
      if (cloudSuccess) return true;
    }
    final trip = await getById(tripId);
    if (trip == null) return false;
    if (trip.status != RideStatus.searching) return false;
    if (trip.driverId != null &&
        trip.driverId!.isNotEmpty &&
        trip.driverId != driver.id) {
      return false;
    }

    await _accept(trip, driver);
    return true;
  }

  Future<List<Trip>> tripsForPassenger(String passengerId) async {
    if (SupabaseService.isConfigured) {
      try {
        final cloud =
            await SupabaseService.instance.getPassengerTrips(passengerId);
        if (cloud.isNotEmpty) return cloud;
      } catch (_) {}
    }
    try {
      final database = await db.database;
      final rows = await database.query(
        'trip',
        where: 'passenger_id = ?',
        whereArgs: [passengerId],
        orderBy: 'created_at DESC',
      );
      return rows.map(Trip.fromMap).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Trip>> tripsForDriver(String driverId) async {
    if (SupabaseService.isConfigured) {
      try {
        final cloud = await SupabaseService.instance
            .streamRideHistoryForDriver(driverId)
            .first
            .timeout(const Duration(seconds: 4));
        if (cloud.isNotEmpty) return cloud;
      } catch (_) {}
    }
    try {
      final database = await db.database;
      final rows = await database.query(
        'trip',
        where: 'driver_id = ?',
        whereArgs: [driverId],
        orderBy: 'created_at DESC',
      );
      return rows.map(Trip.fromMap).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Trip>> allTrips() async {
    try {
      final database = await db.database;
      final rows = await database.query('trip', orderBy: 'created_at DESC');
      return rows.map(Trip.fromMap).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Trip>> tripsByVehicle(VehicleType type) async {
    try {
      final database = await db.database;
      final rows = await database.query(
        'trip',
        where: 'vehicle_type = ?',
        whereArgs: [type.key],
        orderBy: 'created_at DESC',
      );
      return rows.map(Trip.fromMap).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> sendMessage({
    required String tripId,
    required String senderId,
    required String senderName,
    required bool isDriver,
    required String text,
  }) async {
    final database = await db.database;
    final msg = ChatMessage(
      id: _uuid.v4(),
      tripId: tripId,
      senderId: senderId,
      senderName: senderName,
      isDriver: isDriver,
      text: text,
      createdAt: DateTime.now(),
    );
    await database.insert('chat_message', msg.toMap());
    await SupabaseService.instance.saveChatMessage(msg);
  }

  Future<List<ChatMessage>> messagesForTrip(String tripId) async {
    final database = await db.database;
    final rows = await database.query(
      'chat_message',
      where: 'trip_id = ?',
      whereArgs: [tripId],
      orderBy: 'created_at ASC',
    );
    return rows.map(ChatMessage.fromMap).toList();
  }

  Future<List<Review>> reviewsForDriver(String driverId) async {
    final database = await db.database;
    final rows = await database.query(
      'review',
      where: 'driver_id = ?',
      whereArgs: [driverId],
      orderBy: 'created_at DESC',
    );
    return rows.map(Review.fromMap).toList();
  }
}
