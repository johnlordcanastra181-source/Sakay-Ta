import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sakay_ta/core/constants.dart';
import 'package:sakay_ta/models/admin_account.dart';
import 'package:sakay_ta/models/app_user.dart';
import 'package:sakay_ta/services/auth_service.dart';
import 'package:sakay_ta/services/database_service.dart';
import 'package:sakay_ta/services/prefs_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Database-Driven Admin Account System', () {
    test('Can create, retrieve, and query admin accounts from database',
        () async {
      final db = DatabaseService.instance;
      final uniqueEmail =
          'admin_${DateTime.now().millisecondsSinceEpoch}@sakayta.ph';
      final uniqueMobile =
          '0917${DateTime.now().microsecondsSinceEpoch % 10000000}';
      final passwordHash = DatabaseService.hashPassword('SuperAdminSecret123!');

      final admin = AdminAccount(
        id: 'admin-test-${DateTime.now().millisecondsSinceEpoch}',
        fullName: 'Operations Lead Admin',
        email: uniqueEmail,
        mobile: uniqueMobile,
        passwordHash: passwordHash,
        role: UserRole.admin,
        status: AccountStatus.active,
        permissions: AdminPermissions.all,
        department: 'Operations',
        createdAt: DateTime.now(),
      );

      // Save directly to database
      await db.createAdminAccount(admin);

      // Query by ID
      final byId = await db.getAdminById(admin.id);
      expect(byId, isNotNull);
      expect(byId!.email, equals(uniqueEmail));
      expect(byId.fullName, equals('Operations Lead Admin'));
      expect(byId.role, equals(UserRole.admin));
      expect(byId.isActive, isTrue);

      // Query by Identifier (email)
      final byEmail = await db.getAdminByIdentifier(uniqueEmail);
      expect(byEmail, isNotNull);
      expect(byEmail!.id, equals(admin.id));

      // Query by Identifier (mobile)
      final byMobile = await db.getAdminByIdentifier(uniqueMobile);
      expect(byMobile, isNotNull);
      expect(byMobile!.id, equals(admin.id));
    });

    test(
        'Admin can authenticate from Passenger login interface (role: passenger)',
        () async {
      final db = DatabaseService.instance;
      final prefs = PrefsService.instance;
      final auth = AuthService(db, prefs);

      final uniqueEmail =
          'passenger_login_admin_${DateTime.now().millisecondsSinceEpoch}@sakayta.ph';
      const password = 'AdminPassword123!';
      final passwordHash = DatabaseService.hashPassword(password);

      final uniqueMobile =
          '0918${DateTime.now().microsecondsSinceEpoch % 10000000}';
      final admin = AdminAccount(
        id: 'admin-${DateTime.now().millisecondsSinceEpoch}',
        fullName: 'Admin Logging in via Passenger UI',
        email: uniqueEmail,
        mobile: uniqueMobile,
        passwordHash: passwordHash,
        role: UserRole.admin,
        status: AccountStatus.active,
        permissions: AdminPermissions.all,
        createdAt: DateTime.now(),
      );

      await db.createAdminAccount(admin);

      // Attempt login with role: UserRole.passenger
      final result = await auth.login(
        mobile: uniqueEmail,
        password: password,
        role: UserRole.passenger,
      );

      expect(result.error, isNull);
      expect(result.user, isNotNull);
      expect(result.user!.isAdmin, isTrue);
      expect(result.user!.role, equals(UserRole.admin));
      expect(result.user!.email, equals(uniqueEmail));

      // Check session was saved as admin role
      final sessionRole = await prefs.sessionRole;
      expect(sessionRole, equals(UserRole.admin));
    });

    test('Admin can authenticate from Driver login interface (role: driver)',
        () async {
      final db = DatabaseService.instance;
      final prefs = PrefsService.instance;
      final auth = AuthService(db, prefs);

      final uniqueEmail =
          'driver_login_admin_${DateTime.now().millisecondsSinceEpoch}@sakayta.ph';
      const password = 'SecureDriverLogin123!';
      final passwordHash = DatabaseService.hashPassword(password);

      final uniqueMobile =
          '0919${DateTime.now().microsecondsSinceEpoch % 10000000}';
      final admin = AdminAccount(
        id: 'admin-${DateTime.now().millisecondsSinceEpoch}',
        fullName: 'Admin Logging in via Driver UI',
        email: uniqueEmail,
        mobile: uniqueMobile,
        passwordHash: passwordHash,
        role: UserRole.admin,
        status: AccountStatus.active,
        permissions: AdminPermissions.all,
        createdAt: DateTime.now(),
      );

      await db.createAdminAccount(admin);

      // Attempt login with role: UserRole.driver
      final result = await auth.login(
        mobile: uniqueEmail,
        password: password,
        role: UserRole.driver,
      );

      expect(result.error, isNull);
      expect(result.user, isNotNull);
      expect(result.user!.isAdmin, isTrue);
      expect(result.user!.role, equals(UserRole.admin));
    });

    test('Rejects invalid password with wrong_password', () async {
      final db = DatabaseService.instance;
      final prefs = PrefsService.instance;
      final auth = AuthService(db, prefs);

      final uniqueEmail =
          'pass_test_${DateTime.now().millisecondsSinceEpoch}@sakayta.ph';
      final passwordHash = DatabaseService.hashPassword('CorrectPassword123!');

      final admin = AdminAccount(
        id: 'admin-${DateTime.now().millisecondsSinceEpoch}',
        fullName: 'Password Test Admin',
        email: uniqueEmail,
        passwordHash: passwordHash,
        role: UserRole.admin,
        status: AccountStatus.active,
        createdAt: DateTime.now(),
      );

      await db.createAdminAccount(admin);

      final result = await auth.login(
        mobile: uniqueEmail,
        password: 'IncorrectPassword',
        role: UserRole.admin,
      );

      expect(result.user, isNull);
      expect(result.error, equals('wrong_password'));
    });

    test(
        'Deactivated admin account is blocked from login with account_deactivated',
        () async {
      final db = DatabaseService.instance;
      final prefs = PrefsService.instance;
      final auth = AuthService(db, prefs);

      final uniqueEmail =
          'deactivated_admin_${DateTime.now().millisecondsSinceEpoch}@sakayta.ph';
      const password = 'ValidPassword123!';
      final passwordHash = DatabaseService.hashPassword(password);

      final admin = AdminAccount(
        id: 'admin-${DateTime.now().millisecondsSinceEpoch}',
        fullName: 'Deactivated Administrator',
        email: uniqueEmail,
        passwordHash: passwordHash,
        role: UserRole.admin,
        status: AccountStatus.active,
        createdAt: DateTime.now(),
      );

      await db.createAdminAccount(admin);

      // Deactivate account
      await db.updateAdminStatus(admin.id, AccountStatus.deactivated);

      final result = await auth.login(
        mobile: uniqueEmail,
        password: password,
        role: UserRole.admin,
      );

      expect(result.user, isNull);
      expect(result.error, equals('account_deactivated'));
    });

    test('Toggling admin status reactivates access in database', () async {
      final db = DatabaseService.instance;
      final prefs = PrefsService.instance;
      final auth = AuthService(db, prefs);

      final uniqueEmail =
          'reactivate_admin_${DateTime.now().millisecondsSinceEpoch}@sakayta.ph';
      const password = 'ReactivatePassword123!';
      final passwordHash = DatabaseService.hashPassword(password);

      final admin = AdminAccount(
        id: 'admin-${DateTime.now().millisecondsSinceEpoch}',
        fullName: 'Toggle Admin',
        email: uniqueEmail,
        passwordHash: passwordHash,
        role: UserRole.admin,
        status: AccountStatus.deactivated,
        createdAt: DateTime.now(),
      );

      await db.createAdminAccount(admin);

      // Verify deactivated
      var result = await auth.login(
        mobile: uniqueEmail,
        password: password,
        role: UserRole.admin,
      );
      expect(result.error, equals('account_deactivated'));

      // Reactivate
      await db.updateAdminStatus(admin.id, AccountStatus.active);

      result = await auth.login(
        mobile: uniqueEmail,
        password: password,
        role: UserRole.admin,
      );
      expect(result.error, isNull);
      expect(result.user, isNotNull);
      expect(result.user!.isAdmin, isTrue);
    });

    test(
        'AppUser helper getters correctly reflect admin role and active status',
        () {
      final activeAdmin = AppUser(
        id: 'admin-1',
        fullName: 'Active Admin',
        passwordHash: 'hash',
        role: UserRole.admin,
        status: AccountStatus.active,
        createdAt: DateTime.now(),
      );
      expect(activeAdmin.isAdmin, isTrue);
      expect(activeAdmin.isPassenger, isFalse);
      expect(activeAdmin.isDriver, isFalse);
      expect(activeAdmin.isActive, isTrue);
      expect(activeAdmin.isDeactivated, isFalse);

      final deactivatedAdmin = AppUser(
        id: 'admin-2',
        fullName: 'Disabled Admin',
        passwordHash: 'hash',
        role: UserRole.admin,
        status: AccountStatus.deactivated,
        createdAt: DateTime.now(),
      );
      expect(deactivatedAdmin.isAdmin, isTrue);
      expect(deactivatedAdmin.isActive, isFalse);
      expect(deactivatedAdmin.isDeactivated, isTrue);
    });

    test('Admin permissions check works accurately', () {
      final superAdmin = AdminAccount(
        id: 'admin-super',
        fullName: 'Super Admin',
        email: 'super@sakayta.ph',
        passwordHash: 'hash',
        permissions: AdminPermissions.all,
        createdAt: DateTime.now(),
      );
      expect(superAdmin.hasPermission(AdminPermissions.manageDrivers), isTrue);
      expect(superAdmin.hasPermission(AdminPermissions.manageFares), isTrue);
      expect(superAdmin.hasPermission(AdminPermissions.viewReports), isTrue);

      final driverOpsAdmin = AdminAccount(
        id: 'admin-ops',
        fullName: 'Driver Ops Admin',
        email: 'ops@sakayta.ph',
        passwordHash: 'hash',
        permissions:
            '${AdminPermissions.manageDrivers},${AdminPermissions.viewReports}',
        createdAt: DateTime.now(),
      );
      expect(
          driverOpsAdmin.hasPermission(AdminPermissions.manageDrivers), isTrue);
      expect(
          driverOpsAdmin.hasPermission(AdminPermissions.viewReports), isTrue);
      expect(
          driverOpsAdmin.hasPermission(AdminPermissions.manageFares), isFalse);
    });

    test('Can update admin password and delete admin account in database',
        () async {
      final db = DatabaseService.instance;
      final uniqueEmail =
          'delete_me_${DateTime.now().millisecondsSinceEpoch}@sakayta.ph';
      final originalHash = DatabaseService.hashPassword('OriginalPass123!');
      final newHash = DatabaseService.hashPassword('NewPass456!');

      final admin = AdminAccount(
        id: 'admin-delete-${DateTime.now().millisecondsSinceEpoch}',
        fullName: 'Ephemeral Admin',
        email: uniqueEmail,
        passwordHash: originalHash,
        role: UserRole.admin,
        status: AccountStatus.active,
        createdAt: DateTime.now(),
      );

      await db.createAdminAccount(admin);

      // Update password
      await db.updateAdminPassword(admin.id, newHash);
      final updated = await db.getAdminById(admin.id);
      expect(updated, isNotNull);
      expect(updated!.passwordHash, equals(newHash));

      // Delete admin
      await db.deleteAdminAccount(admin.id);
      final deleted = await db.getAdminById(admin.id);
      expect(deleted, isNull);
    });
  });
}
