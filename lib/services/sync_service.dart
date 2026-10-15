import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/constants.dart';
import '../models/firestore_models.dart';
import '../models/transaction.dart';
import 'database_service.dart';
import 'supabase_service.dart';
import 'trip_service.dart';

class SyncResult {
  final int synced;
  final int failed;
  final int remaining;
  const SyncResult({
    required this.synced,
    required this.failed,
    required this.remaining,
  });
}

class SyncService {
  final DatabaseService db;
  final TripService tripService;
  const SyncService(this.db, this.tripService);

  static const _uuid = Uuid();

  Future<void> queueBooking({
    required String passengerId,
    required VehicleType vehicleType,
    required String pickupAddress,
    required String dropoffAddress,
    required Geo pickup,
    required Geo dropoff,
    String paymentMethod = PaymentMethod.cash,
    String? driverId,
    String? tripId,
  }) async {
    final database = await db.database;
    final payload = jsonEncode({
      'trip_id': tripId,
      'passenger_id': passengerId,
      'driver_id': driverId,
      'vehicle_type': vehicleType.key,
      'pickup_address': pickupAddress,
      'dropoff_address': dropoffAddress,
      'pickup_lat': pickup.lat,
      'pickup_lng': pickup.lng,
      'dropoff_lat': dropoff.lat,
      'dropoff_lng': dropoff.lng,
      'payment_method': paymentMethod,
    });
    await database.insert('sync_queue', {
      'id': _uuid.v4(),
      'type': 'booking',
      'payload': payload,
      'retry_count': 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> queueTripStatus({
    required String tripId,
    required String status,
    double? latitude,
    double? longitude,
    double? fare,
  }) async {
    final database = await db.database;
    final payload = jsonEncode({
      'trip_id': tripId,
      'status': status,
      'latitude': latitude,
      'longitude': longitude,
      'fare': fare,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    await database.insert('sync_queue', {
      'id': _uuid.v4(),
      'type': 'trip_status',
      'payload': payload,
      'retry_count': 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> queueRating({
    required String tripId,
    required String fromUserId,
    required String toUserId,
    required int rating,
    required String comment,
  }) async {
    final database = await db.database;
    final payload = jsonEncode({
      'trip_id': tripId,
      'from_user_id': fromUserId,
      'to_user_id': toUserId,
      'rating': rating,
      'comment': comment,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    await database.insert('sync_queue', {
      'id': _uuid.v4(),
      'type': 'rating',
      'payload': payload,
      'retry_count': 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> queuePayment({
    required String paymentId,
    required String tripId,
    required String payerId,
    required String payeeId,
    required double amount,
    required String method,
    required String reference,
  }) async {
    final database = await db.database;
    final payload = jsonEncode({
      'payment_id': paymentId,
      'trip_id': tripId,
      'payer_id': payerId,
      'payee_id': payeeId,
      'amount': amount,
      'method': method,
      'reference': reference,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    await database.insert('sync_queue', {
      'id': _uuid.v4(),
      'type': 'payment',
      'payload': payload,
      'retry_count': 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> queueChat({
    required String tripId,
    required String senderId,
    required String senderRole,
    required String text,
  }) async {
    final database = await db.database;
    final payload = jsonEncode({
      'trip_id': tripId,
      'sender_id': senderId,
      'sender_role': senderRole,
      'text': text,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    await database.insert('sync_queue', {
      'id': _uuid.v4(),
      'type': 'chat',
      'payload': payload,
      'retry_count': 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<int> pendingCount() async {
    try {
      final database = await db.database;
      final rows =
          await database.rawQuery('SELECT COUNT(*) AS c FROM sync_queue');
      return (rows.first['c'] as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<List<Map<String, Object?>>> pendingItems() async {
    try {
      final database = await db.database;
      return database.query('sync_queue', orderBy: 'created_at ASC');
    } catch (_) {
      return const [];
    }
  }

  Future<void> removeQueueItem(String id) async {
    final database = await db.database;
    await database.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearQueue() async {
    final database = await db.database;
    await database.delete('sync_queue');
  }

  Future<SyncResult> syncAll() async {
    final database = await db.database;
    final items = await pendingItems();
    var synced = 0;
    var failed = 0;

    for (final item in items) {
      final id = item['id'] as String;
      final type = item['type'] as String;
      final retryCount = (item['retry_count'] as int?) ?? 0;
      final payload =
          jsonDecode(item['payload'] as String) as Map<String, dynamic>;

      try {
        switch (type) {
          case 'booking':
            final tripId = payload['trip_id'] as String?;
            final existingTrip =
                tripId != null ? await tripService.getById(tripId) : null;
            if (existingTrip == null) {
              await tripService.requestTrip(
                passengerId: payload['passenger_id'] as String,
                vehicleType:
                    VehicleTypeX.fromKey(payload['vehicle_type'] as String),
                pickupAddress: payload['pickup_address'] as String,
                dropoffAddress: payload['dropoff_address'] as String,
                pickup: Geo(
                  (payload['pickup_lat'] as num).toDouble(),
                  (payload['pickup_lng'] as num).toDouble(),
                ),
                dropoff: Geo(
                  (payload['dropoff_lat'] as num).toDouble(),
                  (payload['dropoff_lng'] as num).toDouble(),
                ),
                paymentMethod: (payload['payment_method'] as String?) ??
                    PaymentMethod.cash,
                driverId: payload['driver_id'] as String?,
                estimatedFare: RideConfig.fareFor(
                  VehicleTypeX.fromKey(payload['vehicle_type'] as String),
                  Geo.distanceKm(
                    Geo((payload['pickup_lat'] as num).toDouble(),
                        (payload['pickup_lng'] as num).toDouble()),
                    Geo((payload['dropoff_lat'] as num).toDouble(),
                        (payload['dropoff_lng'] as num).toDouble()),
                  ),
                ),
              );
            } else {
              // Ensure trip is pushed to Firestore
              await SupabaseService.instance.saveTrip(existingTrip);
            }
            break;

          case 'trip_status':
            final tripId = payload['trip_id'] as String;
            final status = payload['status'] as String;
            final lat = (payload['latitude'] as num?)?.toDouble();
            final lng = (payload['longitude'] as num?)?.toDouble();
            final fare = (payload['fare'] as num?)?.toDouble();

            // The local cache is updated here, while the remote transition is
            // issued exactly once by the secured operation below.
            await tripService.setStatusLocally(tripId, status);
            if (status == RideStatus.started) {
              await SupabaseService.instance.startTrip(
                rideId: tripId,
                driverLat: lat,
                driverLng: lng,
              );
            } else if (status == RideStatus.completed) {
              await SupabaseService.instance.completeTrip(
                rideId: tripId,
                actualFare: fare ?? 0.0,
              );
            } else {
              await SupabaseService.instance.updateTrip(tripId, {
                'status': status,
                'updated_at': DateTime.now().millisecondsSinceEpoch,
              });
            }
            break;

          case 'rating':
            final tripId = payload['trip_id'] as String;
            final fromUserId = payload['from_user_id'] as String;
            final toUserId = payload['to_user_id'] as String;
            final rating = payload['rating'] as int;
            final comment = (payload['comment'] as String?) ?? '';

            await SupabaseService.instance.saveRating(FireRating(
              id: 'rate_${tripId}_$fromUserId',
              rideId: tripId,
              fromUserId: fromUserId,
              toUserId: toUserId,
              stars: rating,
              comment: comment,
              createdAt: DateTime.now(),
            ));
            break;

          case 'payment':
            final tripId = payload['trip_id'] as String;
            final remoteTrip = await SupabaseService.instance.getTrip(tripId);
            if (remoteTrip?.status != RideStatus.completed ||
                remoteTrip?.paymentStatus != PaymentStatus.paid) {
              throw StateError(
                  'Payment replay is waiting for authoritative ride completion.');
            }
            break;

          case 'chat':
            final tripId = payload['trip_id'] as String;
            final senderId = payload['sender_id'] as String;
            final senderRole = payload['sender_role'] as String;
            final text = payload['text'] as String;

            await SupabaseService.instance.saveChatMessage(ChatMessage(
              id: 'chat_${DateTime.now().millisecondsSinceEpoch}_$senderId',
              tripId: tripId,
              senderId: senderId,
              senderName: senderRole == 'driver' ? 'Driver' : 'Passenger',
              isDriver: senderRole == 'driver',
              text: text,
              createdAt: DateTime.now(),
            ));
            break;
        }

        await database.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
        synced++;
      } catch (e) {
        debugPrint('SyncService: error processing item $id ($type): $e');
        failed++;
        if (retryCount > 10) {
          // Drop stale poisoned messages after 10 retries
          await database.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
        } else {
          await database.update(
            'sync_queue',
            {'retry_count': retryCount + 1},
            where: 'id = ?',
            whereArgs: [id],
          );
        }
      }
    }

    try {
      await SupabaseService.instance.syncAllFromLocal(db);
    } catch (_) {}

    final remaining = await pendingCount();
    return SyncResult(
      synced: synced,
      failed: failed,
      remaining: remaining,
    );
  }
}
