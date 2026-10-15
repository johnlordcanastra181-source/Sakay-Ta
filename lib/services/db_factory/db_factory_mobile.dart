import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as mobile;
import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as desktop;

Future<Database> openAppDatabase(
  String path, {
  required int version,
  required Function(Database) onConfigure,
  required Function(Database, int) onCreate,
  required Function(Database, int, int) onUpgrade,
  required Function(Database) onOpen,
}) async {
  if (defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux) {
    desktop.sqfliteFfiInit();
    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, 'sakay_ta.db');
    return desktop.databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: version,
        onConfigure: (db) => onConfigure(db),
        onCreate: (db, v) => onCreate(db, v),
        onUpgrade: (db, oldV, newV) => onUpgrade(db, oldV, newV),
        onOpen: (db) => onOpen(db),
      ),
    );
  }

  final dbPath = p.join(await mobile.getDatabasesPath(), 'sakay_ta.db');
  return mobile.openDatabase(
    dbPath,
    version: version,
    onConfigure: (db) => onConfigure(db),
    onCreate: (db, v) => onCreate(db, v),
    onUpgrade: (db, oldV, newV) => onUpgrade(db, oldV, newV),
    onOpen: (db) => onOpen(db),
  );
}
