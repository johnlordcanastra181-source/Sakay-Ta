import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sakay_ta/core/constants.dart';
import 'package:sakay_ta/models/admin_account.dart';
import 'package:sakay_ta/models/app_user.dart';
import 'package:sakay_ta/models/driver_profile.dart';
import 'package:sakay_ta/models/philippine_address.dart';
import 'package:sakay_ta/services/account_remote_store.dart';
import 'package:sakay_ta/services/auth_service.dart';
import 'package:sakay_ta/services/database_service.dart';
import 'package:sakay_ta/services/prefs_service.dart';
import 'package:sakay_ta/services/supabase_auth_service.dart';
import 'support/isolated_database.dart';

class _Remote extends AccountRemoteStore {
  final credentials = <String, ({String uid, String password})>{};
  final users = <String, AppUser>{};
  final drivers = <String, DriverProfile>{};
  bool offline = false;
  bool failSave = false;
  bool failDriverSave = false;
  int userWrites = 0;
  int adminReads = 0;

  @override
  bool get isConfigured => true;

  @override
  Future<String> signIn(String identifier, String password,
      {List<String>? alternateIdentifiers}) async {
    if (offline) {
      throw const AuthException('Network unavailable',
          code: 'network-request-failed');
    }
    for (final id in [identifier, ...?alternateIdentifiers]) {
      final credential = credentials[SupabaseAuthService.emailFor(id)];
      if (credential?.password == password) return credential!.uid;
    }
    throw const AuthException('Invalid credentials',
        code: 'invalid-credential');
  }

  @override
  Future<String> createAccount(
      String mobile, String password, String? email) async {
    if (offline) {
      throw const AuthException('Network unavailable',
          code: 'network-request-failed');
    }
    final id = email ?? SupabaseAuthService.emailFor(mobile);
    if (credentials.containsKey(id)) return signIn(id, password);
    final uid = 'cloud-${credentials.length + 1}';
    credentials[id] = (uid: uid, password: password);
    return uid;
  }

  @override
  Future<AppUser?> getUser(String uid) async => users[uid];
  @override
  Future<AdminAccount?> getAdmin(String uid) async {
    adminReads++;
    return null;
  }

  @override
  Future<void> saveUser(AppUser user) async {
    if (failSave) throw StateError('Server rejected profile write');
    userWrites++;
    users[user.id] = user.copyWith(passwordHash: '');
  }

  @override
  Future<void> saveDriverProfile(DriverProfile profile) async {
    if (failDriverSave) throw StateError('Server rejected driver profile');
    drivers[profile.userId] = profile;
  }

  @override
  Future<DriverProfile?> getDriverProfile(String uid) async => drivers[uid];
  @override
  Future<void> savePassengerProfile(String uid, PhilippineAddress? address,
      {bool initialize = true}) async {}
}

void main() {
  late _Remote remote;
  late AuthService auth;
  final db = DatabaseService.instance;
  final prefs = PrefsService.instance;
  const email = 'recovery@example.com';
  const mobile = '09171234567';
  const password = 'RecoveryPassword123!';

  setUp(() async {
    await useIsolatedDatabase();
    SharedPreferences.setMockInitialValues({});
    await PrefsService.initialize();
    remote = _Remote();
    auth = AuthService(db, prefs, remoteStore: remote);
  });

  Future<AppUser> passenger() async => (await auth.registerPassenger(
      fullName: 'Original Passenger',
      mobile: mobile,
      password: password,
      email: email))!;

  DriverProfile profile() => DriverProfile(
      userId: '',
      vehicleType: VehicleType.tricycle,
      plateNumber: 'ABC-123',
      licenseNumber: 'LICENSE-123',
      licenseExpiry: '2030-01-01',
      submittedAt: DateTime(2026));

  DriverProfile blankLicenseProfile() => DriverProfile(
      userId: '',
      vehicleType: VehicleType.habal,
      plateNumber: 'XYZ-456',
      licenseNumber: '',
      licenseExpiry: '',
      submittedAt: DateTime(2026));

  Future<void> clearPhoneData() async {
    await (await db.database).delete('users');
    await prefs.clearSession();
    SharedPreferences.setMockInitialValues({});
  }

  test('Clear data then email login restores the original passenger account',
      () async {
    final original = await passenger();
    final writes = remote.userWrites;
    await clearPhoneData();
    expect(await auth.restoreSession(), isNull);
    final result = await auth.login(
        mobile: email, password: password, role: UserRole.passenger);
    expect(result.error, isNull);
    expect(result.user?.id, original.id);
    expect(result.user?.fullName, original.fullName);
    expect(result.user?.role, UserRole.passenger);
    expect(await prefs.sessionUserId, original.id);
    expect((await auth.getUser(original.id))?.id, original.id);
    expect(remote.users, hasLength(1));
    expect(remote.userWrites, writes);
    expect(remote.adminReads, 0);
  });

  test('Clear data then mobile driver login keeps original ID and approval',
      () async {
    final original = (await auth.registerDriver(
        fullName: 'Original Driver',
        mobile: mobile,
        password: password,
        profile: profile()))!;
    remote.users[original.id] =
        remote.users[original.id]!.copyWith(status: AccountStatus.approved);
    await clearPhoneData();
    final result = await auth.login(
        mobile: '+639171234567', password: password, role: UserRole.driver);
    expect(result.error, isNull);
    expect(result.user?.id, original.id);
    expect(result.user?.status, AccountStatus.approved);
    expect(result.user?.isAdmin, isFalse);
    expect(remote.adminReads, 0);
  });

  test('Repeated signup after Clear data preserves the existing cloud profile',
      () async {
    final original = await passenger();
    await clearPhoneData();
    final restored = await auth.registerPassenger(
        fullName: 'Changed Name',
        mobile: mobile,
        password: password,
        email: email);
    expect(restored?.id, original.id);
    expect(restored?.fullName, original.fullName);
    expect(remote.userWrites, 1);
  });

  test('Driver signup retry does not reset approval or vehicle', () async {
    final original = (await auth.registerDriver(
        fullName: 'Original Driver',
        mobile: mobile,
        password: password,
        profile: profile()))!;
    remote.users[original.id] =
        remote.users[original.id]!.copyWith(status: AccountStatus.approved);
    await clearPhoneData();
    final restored = await auth.registerDriver(
        fullName: 'Changed Driver',
        mobile: mobile,
        password: password,
        profile: profile());
    expect(restored?.id, original.id);
    expect(restored?.status, AccountStatus.approved);
    expect(remote.userWrites, 1);
    expect(remote.drivers[original.id]?.plateNumber, 'ABC-123');
  });

  test(
      'Failed online signup creates no local-only account and retries same UID',
      () async {
    remote.failSave = true;
    await expectLater(passenger(), throwsStateError);
    expect(await (await db.database).query('users'), isEmpty);
    expect(await prefs.sessionUserId, isNull);
    remote.failSave = false;
    final original = await passenger();
    expect(original.id, 'cloud-1');
    expect(remote.credentials, hasLength(1));
    expect(remote.users, hasLength(1));
  });

  test('Driver signup accepts a blank license number without error', () async {
    final created = await auth.registerDriver(
      fullName: 'No License Driver',
      mobile: '09181234567',
      password: password,
      profile: blankLicenseProfile(),
    );

    expect(created, isNotNull);
    expect(created?.id, isNotEmpty);
    expect(remote.drivers[created!.id]?.licenseNumber, isEmpty);
    expect(remote.drivers[created.id]?.plateNumber, 'XYZ-456');
  });

  test(
      'No connection after Clear data keeps cloud account and reports network error',
      () async {
    final original = await passenger();
    await clearPhoneData();
    remote.offline = true;
    final result = await auth.login(
        mobile: email, password: password, role: UserRole.passenger);
    expect(result.error, 'network_unavailable');
    expect(await prefs.sessionUserId, isNull);
    expect(remote.users[original.id]?.fullName, original.fullName);
  });

  test('Missing cloud profile is not recreated or promoted to administrator',
      () async {
    await passenger();
    remote.users.clear();
    await clearPhoneData();
    final result = await auth.login(
        mobile: email, password: password, role: UserRole.passenger);
    expect(result.error, 'profile_not_found');
    expect(remote.users, isEmpty);
    expect(remote.userWrites, 1);
    expect(await prefs.sessionUserId, isNull);
  });

  test('Invalid credentials cannot use a cached profile as authentication',
      () async {
    await passenger();
    await prefs.clearSession();
    final result = await auth.login(
        mobile: email, password: 'WrongPassword', role: UserRole.passenger);
    expect(result.error, 'wrong_password');
    expect(result.user, isNull);
    expect(await prefs.sessionUserId, isNull);
  });

  for (final entry in {
    AccountStatus.pending: 'pending',
    AccountStatus.rejected: 'rejected',
    AccountStatus.deactivated: 'account_deactivated',
    'suspended': 'account_deactivated',
  }.entries) {
    test('Clear data preserves ${entry.key} driver restrictions', () async {
      final original = await passenger();
      remote.users[original.id] = remote.users[original.id]!
          .copyWith(role: UserRole.driver, status: entry.key);
      await clearPhoneData();
      final result = await auth.login(
          mobile: email, password: password, role: UserRole.driver);
      expect(result.error, entry.value);
      expect(result.user, isNull);
      expect(await prefs.sessionUserId, isNull);
      expect(remote.users[original.id]?.status, entry.key);
    });
  }

  test('Logging in again preserves records linked to the cached user',
      () async {
    final original = await passenger();
    final database = await db.database;
    await database.insert('emergency_contacts', {
      'id': 'contact-1',
      'user_id': original.id,
      'name': 'Family',
      'phone': '09181111111',
      'relationship': 'Family'
    });
    final result = await auth.login(
        mobile: email, password: password, role: UserRole.passenger);
    expect(result.error, isNull);
    expect(await database.query('emergency_contacts'), hasLength(1));
  });
}
