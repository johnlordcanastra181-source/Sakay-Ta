import 'package:uuid/uuid.dart';

import '../models/transaction.dart';
import 'database_service.dart';

class NotificationService {
  final DatabaseService db;
  const NotificationService(this.db);

  static const _uuid = Uuid();

  Future<void> add({
    required String userId,
    required String title,
    required String body,
  }) async {
    await addFrom(AppNotification(
      id: _uuid.v4(),
      userId: userId,
      title: title,
      body: body,
      createdAt: DateTime.now(),
    ));
  }

  /// Inserts an already-constructed [AppNotification] into the local database
  /// (used when the same notification is mirrored to Firestore).
  Future<void> addFrom(AppNotification notification) async {
    try {
      final database = await db.database;
      await database.insert('notifications', {
        'id': notification.id,
        'user_id': notification.userId,
        'title': notification.title,
        'body': notification.body,
        'type': 'general',
        'is_read': notification.read ? 1 : 0,
        'created_at': notification.createdAt.millisecondsSinceEpoch,
      });
    } catch (_) {}
  }

  Future<List<AppNotification>> listFor(String userId) async {
    try {
      final database = await db.database;
      final rows = await database.query(
        'notifications',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'created_at DESC',
      );
      return rows
          .map((r) => AppNotification.fromMap({
                'id': r['id'],
                'user_id': r['user_id'],
                'title': r['title'],
                'body': r['body'],
                'read': (r['is_read'] as int? ?? r['read'] as int? ?? 0),
                'created_at': r['created_at'],
              }))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<int> unreadCount(String userId) async {
    try {
      final database = await db.database;
      final rows = await database.rawQuery(
        'SELECT COUNT(*) AS c FROM notifications WHERE user_id = ? AND is_read = 0',
        [userId],
      );
      if (rows.isEmpty) return 0;
      final c = rows.first['c'];
      return (c is num) ? c.toInt() : 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> markAllRead(String userId) async {
    try {
      final database = await db.database;
      await database.update(
        'notifications',
        {'is_read': 1},
        where: 'user_id = ?',
        whereArgs: [userId],
      );
    } catch (_) {}
  }
}
