import '../../models/transaction.dart';
import '../../models/firestore_models.dart';

import '../../models/firestore_models.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/firestore_models.dart';

class SupabaseNotificationService {
  SupabaseNotificationService._();
  static final SupabaseNotificationService instance =
      SupabaseNotificationService._();
  SupabaseClient get _db => Supabase.instance.client;

  Future<void> saveNotification(AppNotification notification) async {
    await _db.from('notifications').upsert(notification.toMap());
  }

  Future<void> pushNotification({
    required String userId,
    required String title,
    required String body,
    String? senderId,
    String? tripId,
  }) async {
    final timestamp = DateTime.now().toIso8601String();
    await _db.from('notifications').insert({
      'userId': userId,
      'title': title,
      'body': body,
      'senderId': senderId,
      'tripId': tripId,
      'isRead': false,
      'createdAt': timestamp,
    });
  }

  Future<void> markNotificationsRead(String userId) async {
    await _db
        .from('notifications')
        .update({
          'isRead': true,
          'updatedAt': DateTime.now().toIso8601String(),
        })
        .eq('userId', userId)
        .eq('isRead', false);
  }
}
