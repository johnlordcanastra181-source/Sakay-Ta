import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sakay_ta/core/constants.dart';
import 'package:sakay_ta/services/auth_service.dart';
import 'package:sakay_ta/services/database_service.dart';
import 'package:sakay_ta/services/prefs_service.dart';

void main() {
  late DatabaseService dbService;
  late PrefsService prefsService;
  late AuthService authService;

  setUpAll(() async {
    DatabaseService.allowTestAccountsOverride = true;
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    dbService = DatabaseService.instance;
    await dbService.database;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    prefsService = PrefsService.instance;
    authService = AuthService(dbService, prefsService);
  });

  group('SQLite Test Accounts for Web & Localhost Testing', () {
    test('seedTestAccounts populates all default test accounts', () async {
      await dbService.seedTestAccounts();
      final db = await dbService.database;

      final passengerRows = await db.query(
        'users',
        where: 'id = ?',
        whereArgs: ['test-passenger-1'],
      );
      expect(passengerRows.isNotEmpty, isTrue);
      expect(passengerRows.first['role'], equals('passenger'));
      expect(passengerRows.first['mobile'], equals('09123456789'));
      expect(passengerRows.first['email'], equals('passenger@sakayta.ph'));

      final driverRows = await db.query(
        'users',
        where: 'id = ?',
        whereArgs: ['test-driver-1'],
      );
      expect(driverRows.isNotEmpty, isTrue);
      expect(driverRows.first['role'], equals('driver'));
      expect(driverRows.first['mobile'], equals('09987654321'));
      expect(driverRows.first['status'], equals(AccountStatus.approved));

      final driverProfileRows = await db.query(
        'drivers',
        where: 'user_id = ?',
        whereArgs: ['test-driver-1'],
      );
      expect(driverProfileRows.isNotEmpty, isTrue);
      expect(driverProfileRows.first['vehicle_type'], equals('tricycle'));
      expect(driverProfileRows.first['plate_number'], equals('CEB-1234'));

      final habalDriverRows = await db.query(
        'users',
        where: 'id = ?',
        whereArgs: ['test-driver-2'],
      );
      expect(habalDriverRows.isNotEmpty, isTrue);
      expect(habalDriverRows.first['role'], equals('driver'));
      expect(habalDriverRows.first['mobile'], equals('09981112233'));

      final adminRows = await db.query(
        'users',
        where: 'id = ?',
        whereArgs: ['test-admin-1'],
      );
      expect(adminRows.isNotEmpty, isTrue);
      expect(adminRows.first['role'], equals('admin'));
      expect(adminRows.first['email'], equals('admin@sakayta.ph'));
    });

    test('Passenger test account logs in successfully via mobile and email', () async {
      // Login via mobile
      final mobileLogin = await authService.login(
        mobile: '09123456789',
        password: 'password123',
        role: 'passenger',
      );
      expect(mobileLogin.error, isNull);
      expect(mobileLogin.user, isNotNull);
      expect(mobileLogin.user!.role, equals('passenger'));
      expect(mobileLogin.user!.fullName, contains('Passenger'));

      // Login via email
      final emailLogin = await authService.login(
        mobile: 'passenger@sakayta.ph',
        password: 'password123',
        role: 'passenger',
      );
      expect(emailLogin.error, isNull);
      expect(emailLogin.user, isNotNull);
      expect(emailLogin.user!.role, equals('passenger'));
    });

    test('Driver test accounts log in successfully and can retrieve driver profiles', () async {
      // Login Tricycle Driver
      final driver1Login = await authService.login(
        mobile: '09987654321',
        password: 'password123',
        role: 'driver',
      );
      expect(driver1Login.error, isNull);
      expect(driver1Login.user, isNotNull);
      expect(driver1Login.user!.role, equals('driver'));

      final profile1 = await authService.getDriverProfile(driver1Login.user!.id);
      expect(profile1, isNotNull);
      expect(profile1!.vehicleType, equals(VehicleType.tricycle));
      expect(profile1.plateNumber, equals('CEB-1234'));

      // Login Habal-Habal Driver
      final driver2Login = await authService.login(
        mobile: '09981112233',
        password: 'password123',
        role: 'driver',
      );
      expect(driver2Login.error, isNull);
      expect(driver2Login.user, isNotNull);
      expect(driver2Login.user!.role, equals('driver'));

      final profile2 = await authService.getDriverProfile(driver2Login.user!.id);
      expect(profile2, isNotNull);
      expect(profile2!.vehicleType, equals(VehicleType.habal));
    });

    test('Admin test account logs in successfully via email and mobile across any role mode (passenger/driver)', () async {
      // Login under passenger role toggle
      final adminLoginAsPassenger = await authService.login(
        mobile: 'admin@sakayta.ph',
        password: 'admin123',
        role: 'passenger',
      );
      expect(adminLoginAsPassenger.error, isNull);
      expect(adminLoginAsPassenger.user, isNotNull);
      expect(adminLoginAsPassenger.user!.role, equals('admin'));
      expect(adminLoginAsPassenger.user!.isAdmin, isTrue);

      // Login under driver role toggle
      final adminLoginAsDriver = await authService.login(
        mobile: '09000000000',
        password: 'admin123',
        role: 'driver',
      );
      expect(adminLoginAsDriver.error, isNull);
      expect(adminLoginAsDriver.user, isNotNull);
      expect(adminLoginAsDriver.user!.isAdmin, isTrue);

      // Login under admin role
      final adminLogin = await authService.login(
        mobile: 'admin@sakayta.ph',
        password: 'admin123',
        role: 'admin',
      );
      expect(adminLogin.error, isNull);
      expect(adminLogin.user, isNotNull);
      expect(adminLogin.user!.isAdmin, isTrue);
    });

    test('Wrong password or role rejects test account login properly', () async {
      final badPassResult = await authService.login(
        mobile: '09123456789',
        password: 'wrong_password_xyz',
        role: 'passenger',
      );
      expect(badPassResult.user, isNull);
      expect(badPassResult.error, equals('wrong_password'));

      final wrongRoleResult = await authService.login(
        mobile: '09123456789',
        password: 'password123',
        role: 'driver',
      );
      expect(wrongRoleResult.user, isNull);
      expect(wrongRoleResult.error, equals('wrong_role'));
    });

    test('On APK build (allowTestAccounts = false), test accounts are purged and cannot log in', () async {
      DatabaseService.allowTestAccountsOverride = false;
      await dbService.purgeTestAccounts();

      final db = await dbService.database;
      final passengerRows = await db.query('users', where: 'id = ?', whereArgs: ['test-passenger-1']);
      expect(passengerRows.isEmpty, isTrue);

      final loginResult = await authService.login(
        mobile: '09123456789',
        password: 'password123',
        role: 'passenger',
      );
      expect(loginResult.user, isNull);
      expect(loginResult.error, equals('no_user'));

      // Restore override
      DatabaseService.allowTestAccountsOverride = true;
    });
  });
}
