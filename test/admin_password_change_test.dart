import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sakay_ta/core/constants.dart';
import 'package:sakay_ta/models/admin_account.dart';
import 'package:sakay_ta/models/app_user.dart';
import 'package:sakay_ta/services/auth_service.dart';
import 'package:sakay_ta/services/database_service.dart';
import 'package:sakay_ta/services/prefs_service.dart';
import 'package:sakay_ta/state/app_state.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Admin Password Change Self-Service', () {
    test('Throws StateError if no active administrator is signed in', () async {
      final appState = AppState.instance;

      // No user logged in
      appState.currentUser = null;
      expect(
        () => appState.changeAdminPassword('NewPassword123!',
            currentPassword: 'OldPass'),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('active administrator'),
        )),
      );

      // Passenger user logged in
      appState.currentUser = AppUser(
        id: 'passenger-1',
        fullName: 'Passenger User',
        email: 'passenger@test.ph',
        role: UserRole.passenger,
        passwordHash: '',
        createdAt: DateTime.now(),
      );

      expect(
        () => appState.changeAdminPassword('NewPassword123!',
            currentPassword: 'OldPass'),
        throwsA(isA<StateError>()),
      );
    });

    test(
        'Validates password constraints: minimum length and difference from current',
        () async {
      final appState = AppState.instance;
      const initialPassword = 'InitialAdmin123!';
      final initialHash = DatabaseService.hashPassword(initialPassword);

      appState.currentUser = AppUser(
        id: 'admin-test-uid-1',
        fullName: 'Sub Admin Test',
        email: 'subadmin@sakayta.ph',
        role: UserRole.admin,
        passwordHash: initialHash,
        createdAt: DateTime.now(),
      );

      // Reject too short (< 6 chars)
      expect(
        () => appState.changeAdminPassword('12345',
            currentPassword: initialPassword),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('at least 6 characters'),
        )),
      );

      // Reject identical to current password
      expect(
        () => appState.changeAdminPassword(initialPassword,
            currentPassword: initialPassword),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('different from your current password'),
        )),
      );
    });

    test('Rejects incorrect current password in local/offline environment',
        () async {
      final appState = AppState.instance;
      const initialPassword = 'InitialAdmin123!';
      final initialHash = DatabaseService.hashPassword(initialPassword);

      appState.currentUser = AppUser(
        id: 'admin-test-uid-2',
        fullName: 'Sub Admin Test 2',
        email: 'subadmin2@sakayta.ph',
        role: UserRole.admin,
        passwordHash: initialHash,
        createdAt: DateTime.now(),
      );

      expect(
        () => appState.changeAdminPassword('BrandNewPass123!',
            currentPassword: 'WrongPassword!'),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('current password you entered is incorrect'),
        )),
      );
    });

    test(
        'Successfully updates password across AppState, SQLite admin_accounts and users',
        () async {
      final db = DatabaseService.instance;
      final prefs = PrefsService.instance;
      final auth = AuthService(db, prefs);
      final appState = AppState.instance;

      final adminId = 'admin-change-${DateTime.now().millisecondsSinceEpoch}';
      final email =
          'change_test_${DateTime.now().millisecondsSinceEpoch}@sakayta.ph';
      final mobile = '0917${DateTime.now().microsecondsSinceEpoch % 10000000}';
      const initialPassword = 'ProvisionedBySuperAdmin123!';
      const newPassword = 'MyOwnPrivatePassword456!';
      final initialHash = DatabaseService.hashPassword(initialPassword);

      final admin = AdminAccount(
        id: adminId,
        fullName: 'Dispatched Administrator',
        email: email,
        mobile: mobile,
        passwordHash: initialHash,
        role: UserRole.admin,
        status: AccountStatus.active,
        createdAt: DateTime.now(),
      );

      // Persist to SQLite
      await db.createAdminAccount(admin);

      // Set current session
      appState.currentUser = AppUser(
        id: adminId,
        fullName: admin.fullName,
        email: email,
        mobile: mobile,
        role: UserRole.admin,
        passwordHash: initialHash,
        createdAt: DateTime.now(),
      );

      // Perform password change
      await appState.changeAdminPassword(newPassword,
          currentPassword: initialPassword);

      final expectedNewHash = DatabaseService.hashPassword(newPassword);

      // Verify in-memory currentUser was updated
      expect(appState.currentUser!.passwordHash, equals(expectedNewHash));

      // Verify SQLite admin_accounts was updated
      final updatedAdmin = await db.getAdminById(adminId);
      expect(updatedAdmin, isNotNull);
      expect(updatedAdmin!.passwordHash, equals(expectedNewHash));

      // Verify login with old credentials fails
      final oldLoginResult = await auth.login(
        mobile: email,
        password: initialPassword,
        role: UserRole.admin,
      );
      expect(oldLoginResult.user, isNull);
      expect(oldLoginResult.error, isNotNull);

      // Verify login with new credentials succeeds
      final newLoginResult = await auth.login(
        mobile: email,
        password: newPassword,
        role: UserRole.admin,
      );
      expect(newLoginResult.user, isNotNull);
      expect(newLoginResult.user!.email, equals(email));
      expect(newLoginResult.user!.id, equals(adminId));
    });
  });
}
