import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sakay_ta/core/constants.dart';
import 'package:sakay_ta/models/admin_account.dart';
import 'package:sakay_ta/services/auth_service.dart';
import 'package:sakay_ta/services/database_service.dart';
import 'package:sakay_ta/services/prefs_service.dart';

class _SlowAuditDatabase implements DatabaseService {
  final auditStarted = Completer<void>();
  final auditFinished = Completer<void>();
  final admin = AdminAccount(
    id: 'performance-admin',
    fullName: 'Performance Admin',
    email: 'performance-admin@example.com',
    passwordHash: DatabaseService.hashPassword('ValidPassword123!'),
    role: UserRole.admin,
    status: AccountStatus.active,
    createdAt: DateTime(2026),
  );

  @override
  Future<Database> get database => DatabaseService.instance.database;

  @override
  Future<AdminAccount?> getAdminByIdentifier(String identifier) async => admin;

  @override
  Future<void> updateAdminLastLogin(String id, int timestamp) async {
    auditStarted.complete();
    await auditFinished.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.setDatabasesPath('tmp/admin_login_performance_db');
    await DatabaseService.instance.database;
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('admin login completes within one second while audit is stalled',
      () async {
    final db = _SlowAuditDatabase();
    final prefs = PrefsService.instance;
    final auth = AuthService(db, prefs);
    try {
      final result = await auth
          .login(
            mobile: db.admin.email,
            password: 'ValidPassword123!',
            role: UserRole.admin,
          )
          .timeout(const Duration(seconds: 1));

      expect(result.error, isNull);
      expect(result.user?.isAdmin, isTrue);
      expect(await prefs.sessionUserId, db.admin.id);
      final cached = await (await db.database)
          .query('users', where: 'id = ?', whereArgs: [db.admin.id]);
      expect(cached, hasLength(1));
      expect(db.auditStarted.isCompleted, isTrue);
      expect(db.auditFinished.isCompleted, isFalse);
    } finally {
      db.auditFinished.complete();
    }
  });

  test('invalid admin password does not save a session or record a login',
      () async {
    final db = _SlowAuditDatabase();
    final prefs = PrefsService.instance;
    final result = await AuthService(db, prefs).login(
      mobile: db.admin.email,
      password: 'IncorrectPassword',
      role: UserRole.admin,
    );
    expect(result.error, 'wrong_password');
    expect(result.user, isNull);
    expect(await prefs.sessionUserId, isNull);
    expect(db.auditStarted.isCompleted, isFalse);
  });
}
