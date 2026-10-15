import 'package:uuid/uuid.dart';

import '../core/constants.dart';
import '../models/transaction.dart';
import 'database_service.dart';

class EarningsService {
  final DatabaseService db;
  const EarningsService(this.db);

  static const _uuid = Uuid();

  Future<void> recordTripIncome({
    required String driverId,
    required String tripId,
    required double fare,
    required String method,
    String description = 'Trip earnings',
  }) async {
    final database = await db.database;
    await database.insert(
        'transactions',
        WalletTransaction(
          id: _uuid.v4(),
          driverId: driverId,
          tripId: tripId,
          type: 'income',
          method: method,
          amount: fare,
          description: description,
          createdAt: DateTime.now(),
        ).toMap());
    // Accumulate lifetime earnings (the previous code overwrote with a single
    // fare, losing the running total).
    await database.rawUpdate(
      'UPDATE users SET lifetime_earnings = '
      'COALESCE(lifetime_earnings, 0) + ? WHERE id = ?',
      [fare, driverId],
    );
  }

  Future<List<WalletTransaction>> transactionsFor(
    String driverId, {
    String? filter,
  }) async {
    final database = await db.database;
    final rows = filter == null
        ? await database.query(
            'transactions',
            where: 'driver_id = ?',
            whereArgs: [driverId],
            orderBy: 'created_at DESC',
          )
        : await database.query(
            'transactions',
            where: 'driver_id = ? AND type = ?',
            whereArgs: [driverId, filter],
            orderBy: 'created_at DESC',
          );
    return rows.map(WalletTransaction.fromMap).toList();
  }

  /// Every wallet entry across all drivers (admin overview/reports).
  Future<List<WalletTransaction>> allTransactions() async {
    final database = await db.database;
    final rows =
        await database.query('transactions', orderBy: 'created_at DESC');
    return rows.map(WalletTransaction.fromMap).toList();
  }

  Future<double> balanceFor(String driverId) async {
    final database = await db.database;
    final rows = await database.rawQuery(
      'SELECT COALESCE(SUM(CASE WHEN type = "income" THEN amount ELSE -amount END), 0) AS bal '
      'FROM transactions WHERE driver_id = ?',
      [driverId],
    );
    return (rows.first['bal'] as num?)?.toDouble() ?? 0;
  }

  Future<double> earnedToday(String driverId) async {
    final start = DateTime.now();
    final today = DateTime(start.year, start.month, start.day);
    return _earnedBetween(driverId, today, DateTime.now());
  }

  Future<double> earnedThisWeek(String driverId) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    return _earnedBetween(driverId, start, now);
  }

  Future<double> earnedThisMonth(String driverId) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    return _earnedBetween(driverId, start, now);
  }

  Future<double> _earnedBetween(
    String driverId,
    DateTime from,
    DateTime to,
  ) async {
    final database = await db.database;
    final rows = await database.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS total FROM transactions '
      'WHERE driver_id = ? AND type = "income" AND created_at >= ? AND created_at <= ?',
      [driverId, from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
    );
    return (rows.first['total'] as num?)?.toDouble() ?? 0;
  }

  Future<List<double>> dailySeries(String driverId, {int days = 7}) async {
    final database = await db.database;
    final now = DateTime.now();
    final out = <double>[];
    for (var i = days - 1; i >= 0; i--) {
      final day =
          DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final next = day.add(const Duration(days: 1));
      final rows = await database.rawQuery(
        'SELECT COALESCE(SUM(amount), 0) AS total FROM transactions '
        'WHERE driver_id = ? AND type = "income" AND created_at >= ? AND created_at < ?',
        [driverId, day.millisecondsSinceEpoch, next.millisecondsSinceEpoch],
      );
      out.add((rows.first['total'] as num?)?.toDouble() ?? 0);
    }
    return out;
  }

  Future<int> tripsToday(String driverId) async {
    final start = DateTime.now();
    final today = DateTime(start.year, start.month, start.day);
    final database = await db.database;
    final rows = await database.rawQuery(
      'SELECT COUNT(*) AS c FROM trip WHERE driver_id = ? '
      'AND status = ? AND completed_at >= ?',
      [
        driverId,
        RideStatus.completed,
        today.millisecondsSinceEpoch,
      ],
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  Future<double> yesterdayEarnings(String driverId) async {
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 1));
    final today = DateTime(now.year, now.month, now.day);
    final database = await db.database;
    final rows = await database.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS total FROM transactions '
      'WHERE driver_id = ? AND type = "income" AND created_at >= ? AND created_at < ?',
      [
        driverId,
        yesterday.millisecondsSinceEpoch,
        today.millisecondsSinceEpoch
      ],
    );
    return (rows.first['total'] as num?)?.toDouble() ?? 0;
  }

  Future<void> withdraw({
    required String driverId,
    required double amount,
    required String method,
  }) async {
    final database = await db.database;
    await database.insert(
        'transactions',
        WalletTransaction(
          id: _uuid.v4(),
          driverId: driverId,
          type: 'withdrawal',
          method: method,
          amount: amount,
          description:
              method == 'gcash' ? 'Withdrawal to GCash' : 'Bank transfer',
          createdAt: DateTime.now(),
        ).toMap());
  }
}
