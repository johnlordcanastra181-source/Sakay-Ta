import 'package:uuid/uuid.dart';

import '../models/toda.dart';
import 'database_service.dart';

class TodaService {
  final DatabaseService db;
  const TodaService(this.db);

  static const _uuid = Uuid();

  Future<List<Toda>> listAll() async {
    final database = await db.database;
    final rows = await database.query('toda', orderBy: 'name ASC');
    return rows.map(Toda.fromMap).toList();
  }

  Future<List<Toda>> listActive() async {
    final database = await db.database;
    final rows = await database.query(
      'toda',
      where: 'active = 1',
      orderBy: 'name ASC',
    );
    return rows.map(Toda.fromMap).toList();
  }

  Future<Toda?> getById(String id) async {
    final database = await db.database;
    final rows = await database.query(
      'toda',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Toda.fromMap(rows.first);
  }

  Future<void> add(Toda toda) async {
    final database = await db.database;
    await database.insert('toda', toda.toMap());
  }

  Future<void> addNew({
    required String name,
    String leader = '',
    String contact = '',
    String area = '',
  }) async {
    await add(Toda(
      id: _uuid.v4(),
      name: name,
      leader: leader,
      contact: contact,
      area: area,
      createdAt: DateTime.now(),
    ));
  }

  Future<void> update(Toda toda) async {
    final database = await db.database;
    await database.update(
      'toda',
      toda.toMap(),
      where: 'id = ?',
      whereArgs: [toda.id],
    );
  }

  Future<void> delete(String id) async {
    final database = await db.database;
    await database.delete('toda', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> memberCount(String todaId) async {
    final database = await db.database;
    final result = await database.rawQuery(
      'SELECT COUNT(*) AS c FROM drivers WHERE toda_id = ?',
      [todaId],
    );
    return (result.first['c'] as int?) ?? 0;
  }

  Future<List<LguPartnership>> listPartnerships() async {
    final database = await db.database;
    final rows = await database.query('lgu_partnership', orderBy: 'name ASC');
    return rows.map(LguPartnership.fromMap).toList();
  }

  Future<void> addPartnership({required String name}) async {
    final database = await db.database;
    await database.insert(
      'lgu_partnership',
      LguPartnership(
        id: _uuid.v4(),
        name: name,
        createdAt: DateTime.now(),
      ).toMap(),
    );
  }

  Future<void> updatePartnership(LguPartnership p) async {
    final database = await db.database;
    await database.update(
      'lgu_partnership',
      p.toMap(),
      where: 'id = ?',
      whereArgs: [p.id],
    );
  }

  Future<void> deletePartnership(String id) async {
    final database = await db.database;
    await database.delete(
      'lgu_partnership',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
