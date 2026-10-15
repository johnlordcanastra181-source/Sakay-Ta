import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
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

  group('Admin Account Management Backend & Model Verification', () {
    test('AdminAccount.toFirestoreMap stores uid, name, email, role, status, timestamps and NEVER passwords', () {
      final now = DateTime.now();
      final admin = AdminAccount(
        id: 'firebase_auth_uid_12345',
        fullName: 'Maria Clara Administrator',
        email: 'MARIA.CLARA@sakayta.ph',
        mobile: '09171234567',
        passwordHash: 'secret_hash_not_for_cloud',
        role: 'super_admin',
        status: AccountStatus.active,
        permissions: AdminPermissions.all,
        department: 'Operations',
        createdAt: now,
        updatedAt: now,
      );

      final firestoreMap = admin.toFirestoreMap();

      // Verify required fields
      expect(firestoreMap['uid'], equals('firebase_auth_uid_12345'));
      expect(firestoreMap['name'], equals('Maria Clara Administrator'));
      expect(firestoreMap['email'], equals('maria.clara@sakayta.ph'));
      expect(firestoreMap['role'], equals('super_admin'));
      expect(firestoreMap['status'], equals('active'));
      expect(firestoreMap['department'], equals('Operations'));
      expect(firestoreMap['permissions'], equals(AdminPermissions.all));
      expect(firestoreMap['createdAt'], isA<Timestamp>());
      expect(firestoreMap['updatedAt'], isA<Timestamp>());

      // CRITICAL SECURITY: Never store passwords in Firestore
      expect(firestoreMap.containsKey('password'), isFalse);
      expect(firestoreMap.containsKey('password_hash'), isFalse);
      expect(firestoreMap.containsKey('passwordHash'), isFalse);
    });

    test('AdminAccount.fromMap parses Firestore documents with uid, name, and timestamps', () {
      final now = DateTime.now();
      final firestoreDoc = <String, Object?>{
        'uid': 'auth_uid_98765',
        'name': 'Jose Rizal Admin',
        'email': 'jose.rizal@sakayta.ph',
        'role': 'admin',
        'status': 'active',
        'department': 'Compliance',
        'permissions': 'verify_drivers,manage_reports',
        'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 5))),
        'updatedAt': Timestamp.fromDate(now),
      };

      final admin = AdminAccount.fromMap(firestoreDoc);

      expect(admin.id, equals('auth_uid_98765'));
      expect(admin.uid, equals('auth_uid_98765'));
      expect(admin.fullName, equals('Jose Rizal Admin'));
      expect(admin.name, equals('Jose Rizal Admin'));
      expect(admin.email, equals('jose.rizal@sakayta.ph'));
      expect(admin.role, equals('admin'));
      expect(admin.isSuperAdmin, isFalse);
      expect(admin.isActive, isTrue);
      expect(admin.department, equals('Compliance'));
      expect(admin.hasPermission('verify_drivers'), isTrue);
      expect(admin.hasPermission('delete_system'), isFalse);
    });

    test('Super Admin vs Regular Admin role checks and permissions', () {
      final superAdmin = AdminAccount(
        id: 'super_uid_1',
        fullName: 'Super Admin User',
        email: 'super@sakayta.ph',
        role: 'super_admin',
        permissions: AdminPermissions.all,
        createdAt: DateTime.now(),
      );

      final regularAdmin = AdminAccount(
        id: 'admin_uid_2',
        fullName: 'Reviewer Admin User',
        email: 'reviewer@sakayta.ph',
        role: 'admin',
        permissions: 'verify_drivers,manage_reports',
        createdAt: DateTime.now(),
      );

      expect(superAdmin.isSuperAdmin, isTrue);
      expect(superAdmin.hasPermission('anything'), isTrue);

      expect(regularAdmin.isSuperAdmin, isFalse);
      expect(regularAdmin.hasPermission('verify_drivers'), isTrue);
      expect(regularAdmin.hasPermission('all'), isFalse);

      final superAppUser = superAdmin.toUser();
      expect(superAppUser.isAdmin, isTrue);
      expect(superAppUser.isSuperAdmin, isTrue);

      final regAppUser = regularAdmin.toUser();
      expect(regAppUser.isAdmin, isTrue);
      expect(regAppUser.isSuperAdmin, isFalse);
    });

    test('AppUser helper getters accurately identify Super Admin and Admin', () {
      final now = DateTime.now();
      final superUser = AppUser(
        id: 'uid-super',
        fullName: 'Super Lead',
        role: 'super_admin',
        passwordHash: '',
        createdAt: now,
      );

      final regularUser = AppUser(
        id: 'uid-admin',
        fullName: 'Regular Admin',
        role: UserRole.admin,
        passwordHash: '',
        createdAt: now,
      );

      final passengerUser = AppUser(
        id: 'uid-pass',
        fullName: 'Passenger One',
        role: UserRole.passenger,
        passwordHash: '',
        createdAt: now,
      );

      expect(superUser.isAdmin, isTrue);
      expect(superUser.isSuperAdmin, isTrue);

      expect(regularUser.isAdmin, isTrue);
      expect(regularUser.isSuperAdmin, isFalse);

      expect(passengerUser.isAdmin, isFalse);
      expect(passengerUser.isSuperAdmin, isFalse);
    });

    test('Role-Based Access Control in AppState guards admin management', () async {
      final app = AppState.instance;
      final now = DateTime.now();

      // 1. Regular non-super admin attempts to create an admin -> Access Denied
      app.currentUser = AppUser(
        id: 'regular-admin-uid',
        fullName: 'Non-Super Admin',
        email: 'regular@sakayta.ph',
        role: UserRole.admin, // Not super_admin
        passwordHash: '',
        createdAt: now,
      );

      expect(
        () => app.createAdminAccount(
          fullName: 'Target Admin',
          email: 'target@sakayta.ph',
          password: 'Password123!',
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Only authorized Super Administrators'),
        )),
      );

      // 2. Regular admin attempts to toggle status -> Access Denied
      expect(
        () => app.toggleAdminAccountStatus('other-id', AccountStatus.active),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Only authorized Super Administrators'),
        )),
      );

      // 3. Regular admin attempts to delete admin -> Access Denied
      expect(
        () => app.deleteAdminAccount('other-id'),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Only authorized Super Administrators'),
        )),
      );

      // 4. Super Admin self-protection: cannot deactivate or delete their own account
      app.currentUser = AppUser(
        id: 'super-admin-uid',
        fullName: 'Super Admin Chief',
        email: 'chief@sakayta.ph',
        role: 'super_admin',
        passwordHash: '',
        createdAt: now,
      );

      expect(
        () => app.toggleAdminAccountStatus('super-admin-uid', AccountStatus.active),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('You cannot deactivate your own'),
        )),
      );

      expect(
        () => app.deleteAdminAccount('super-admin-uid'),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('You cannot delete your own'),
        )),
      );
    });

    test('Duplicate email checking blocks duplicate admin account creation', () async {
      final db = DatabaseService.instance;
      final prefs = PrefsService.instance;
      final auth = AuthService(db, prefs);

      final uniqueEmail = 'duplicate_test_${DateTime.now().millisecondsSinceEpoch}@sakayta.ph';

      // Create an admin with this email in the database
      final existingAdmin = AdminAccount(
        id: 'existing-admin-1',
        fullName: 'Existing Admin',
        email: uniqueEmail,
        passwordHash: DatabaseService.hashPassword('Pass123!'),
        role: UserRole.admin,
        status: AccountStatus.active,
        createdAt: DateTime.now(),
      );
      await db.createAdminAccount(existingAdmin);

      // Verify isEmailRegistered identifies it as already used
      final isUsed = await auth.isEmailRegistered(uniqueEmail);
      expect(isUsed, isTrue);

      final unusedEmail = 'unused_${DateTime.now().millisecondsSinceEpoch}@sakayta.ph';
      final isUnused = await auth.isEmailRegistered(unusedEmail);
      expect(isUnused, isFalse);
    });
  });
}
