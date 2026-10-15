import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/firestore_models.dart';

class SupabaseRatingService {
  SupabaseRatingService._();
  static final SupabaseRatingService instance = SupabaseRatingService._();
  SupabaseClient get _db => Supabase.instance.client;

  Future<void> saveRating(FireRating rating) async {
    await _db.rpc('submit_ride_rating', params: {
      'target_ride': rating.rideId,
      'target_rating': rating.stars,
      'target_comment': rating.comment,
    });
  }

  Future<void> rateDriver({
    required String rideId,
    required String passengerId,
    required String driverId,
    required double rating,
    String? comment,
  }) async {
    // The RPC derives passenger_id and driver_id from the authenticated ride
    // row.  Client-provided identities are retained in this compatibility API
    // but are intentionally never trusted by the database.
    await saveRating(FireRating(
      id: 'rating_$rideId',
      rideId: rideId,
      fromUserId: passengerId,
      toUserId: driverId,
      stars: rating.round().clamp(1, 5),
      comment: comment ?? '',
      createdAt: DateTime.now(),
    ));
  }
}
