import 'package:sqflite_common/sqlite_api.dart';

Future<Database> openAppDatabase(
  String path, {
  required int version,
  required Function(Database) onConfigure,
  required Function(Database, int) onCreate,
  required Function(Database, int, int) onUpgrade,
  required Function(Database) onOpen,
}) {
  throw UnsupportedError(
      'Cannot create database without platform implementation.');
}
