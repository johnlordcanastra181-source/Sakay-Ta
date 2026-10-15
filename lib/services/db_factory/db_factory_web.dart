import 'package:flutter/foundation.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

Future<Database> openAppDatabase(
  String path, {
  required int version,
  required Function(Database) onConfigure,
  required Function(Database, int) onCreate,
  required Function(Database, int, int) onUpgrade,
  required Function(Database) onOpen,
}) async {
  final openOptions = OpenDatabaseOptions(
    version: version,
    onConfigure: (db) => onConfigure(db),
    onCreate: (db, v) => onCreate(db, v),
    onUpgrade: (db, oldV, newV) => onUpgrade(db, oldV, newV),
    onOpen: (db) => onOpen(db),
  );

  final dbPath = path.isEmpty ? inMemoryDatabasePath : path;

  // 1. Try no-worker factory first (most stable for web/Chrome)
  try {
    final db = await databaseFactoryFfiWebNoWebWorker.openDatabase(
      dbPath,
      options: openOptions,
    );
    await db.rawQuery('SELECT 1');
    return db;
  } catch (e) {
    debugPrint(
        'SqfliteWeb: no-worker factory failed ($e). Attempting standard factory...');
  }

  // 2. Try standard factory (with sqflite_sw.js & sqlite3.wasm)
  try {
    final db = await databaseFactoryFfiWeb.openDatabase(
      dbPath,
      options: openOptions,
    );
    await db.rawQuery('SELECT 1');
    return db;
  } catch (e) {
    debugPrint(
        'SqfliteWeb: default factory failed ($e). Falling back to in-memory web SQLite...');
  }

  // 3. Fallback to in-memory web database
  try {
    final inMemoryFactory = createDatabaseFactoryFfiWeb(
      options: SqfliteFfiWebOptions(
        inMemory: true,
      ),
    );
    final db = await inMemoryFactory.openDatabase(
      inMemoryDatabasePath,
      options: openOptions,
    );
    await db.rawQuery('SELECT 1');
    return db;
  } catch (e) {
    debugPrint(
        'SqfliteWeb: in-memory web factory failed ($e). Falling back to no-worker in-memory...');
  }

  // 4. Ultimate fallback: no-worker in-memory database
  return await databaseFactoryFfiWebNoWebWorker.openDatabase(
    inMemoryDatabasePath,
    options: openOptions,
  );
}
