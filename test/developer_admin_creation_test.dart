import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sakay_ta/core/constants.dart';
import 'package:sakay_ta/models/admin_account.dart';
import 'package:sakay_ta/models/app_user.dart';
import 'package:sakay_ta/services/admin_backend_service.dart';
import 'package:sakay_ta/state/app_state.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Developer Admin Account Creation & Provisioning Workflow', () {
    test('Firestore schema compliance: uid, name, email, role, status, timestamps, and NEVER passwords', () {
      final now = DateTime.now();
      final admin = AdminAccount(
        id: 'auth_uid_developer_created',
        fullName: 'Dev Created Admin',
        email: 'devadmin@sakayta.ph',
        role: 'super_admin',
        status: AccountStatus.active,
        createdAt: now,
        updatedAt: now,
      );

      final firestoreMap = admin.toFirestoreMap();

      expect(firestoreMap['uid'], equals('auth_uid_developer_created'));
      expect(firestoreMap['name'], equals('Dev Created Admin'));
      expect(firestoreMap['email'], equals('devadmin@sakayta.ph'));
      expect(firestoreMap['role'], equals('super_admin'));
      expect(firestoreMap['status'], equals('active'));
      expect(firestoreMap['createdAt'], isA<Timestamp>());
      expect(firestoreMap['updatedAt'], isA<Timestamp>());

      // CRITICAL: NEVER store passwords in Firestore
      expect(firestoreMap.containsKey('password'), isFalse);
      expect(firestoreMap.containsKey('password_hash'), isFalse);
      expect(firestoreMap.containsKey('passwordHash'), isFalse);
    });

    test('Support both Active and Disabled initial status in AdminAccount', () {
      final activeAdmin = AdminAccount(
        id: 'uid-active',
        fullName: 'Active Admin',
        email: 'active@sakayta.ph',
        role: 'admin',
        status: AccountStatus.active,
        createdAt: DateTime.now(),
      );

      final disabledAdmin = AdminAccount(
        id: 'uid-disabled',
        fullName: 'Disabled Admin',
        email: 'disabled@sakayta.ph',
        role: 'admin',
        status: AccountStatus.deactivated,
        createdAt: DateTime.now(),
      );

      expect(activeAdmin.isActive, isTrue);
      expect(activeAdmin.isDeactivated, isFalse);

      expect(disabledAdmin.isActive, isFalse);
      expect(disabledAdmin.isDeactivated, isTrue);
    });

    test('AdminBackendService validates required parameters before provisioning', () async {
      final backend = AdminBackendService.instance;

      // Name too short
      expect(
        () => backend.createAdminAccount(
          name: 'A',
          email: 'admin@sakayta.ph',
          password: 'Password123!',
        ),
        throwsA(isA<Exception>().having((e) => e.toString(), 'msg', contains('at least 2 characters'))),
      );

      // Invalid email
      expect(
        () => backend.createAdminAccount(
          name: 'Valid Name',
          email: 'invalid-email-no-at',
          password: 'Password123!',
        ),
        throwsA(isA<Exception>().having((e) => e.toString(), 'msg', contains('valid email'))),
      );

      // Password too short (< 6 chars)
      expect(
        () => backend.createAdminAccount(
          name: 'Valid Name',
          email: 'valid@sakayta.ph',
          password: '123',
        ),
        throwsA(isA<Exception>().having((e) => e.toString(), 'msg', contains('at least 6 characters'))),
      );
    });

    test('AppState.createAdminAccount accepts status and provisions properly for Super Admin', () async {
      final app = AppState.instance;
      final now = DateTime.now();

      // Set Super Admin as caller
      app.currentUser = AppUser(
        id: 'root-super-admin-uid',
        fullName: 'Root Super Admin',
        email: 'superadmin@sakayta.ph',
        role: 'super_admin',
        passwordHash: '',
        createdAt: now,
      );

      final uniqueSuffix = DateTime.now().millisecondsSinceEpoch;
      final email = 'new_admin_$uniqueSuffix@sakayta.ph';

      await app.createAdminAccount(
        fullName: 'New Staff Admin',
        email: email,
        password: 'Password123!',
        role: 'admin',
        status: AccountStatus.active,
        department: 'Operations',
      );

      // Verify email is registered in system
      final isReg = await app.isEmailAlreadyUsed(email);
      expect(isReg, isTrue);

      // Check duplicate creation attempt throws
      expect(
        () => app.createAdminAccount(
          fullName: 'New Staff Admin 2',
          email: email,
          password: 'Password123!',
        ),
        throwsA(isA<Exception>().having((e) => e.toString(), 'msg', contains('already exists'))),
      );
    });
  });
}
