import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sakay_ta/models/philippine_address.dart';
import 'package:sakay_ta/services/auth_service.dart';
import 'package:sakay_ta/services/database_service.dart';
import 'package:sakay_ta/services/prefs_service.dart';
import 'package:sakay_ta/state/auth_bloc.dart';

void main() {
  late DatabaseService dbService;
  late PrefsService prefsService;
  late AuthService authService;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
    await PrefsService.initialize();
    dbService = DatabaseService.instance;
    await dbService.database;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    prefsService = PrefsService.instance;
    authService = AuthService(dbService, prefsService);
  });

  group('AuthService User Registration & Unique Constraint Tests', () {
    test('registerPassenger succeeds for new user', () async {
      final uniqueMobile =
          '9${DateTime.now().microsecondsSinceEpoch.toString().substring(7, 16)}';
      final user = await authService.registerPassenger(
        fullName: 'Juan Dela Cruz',
        mobile: uniqueMobile,
        password: 'password123',
        email: 'juan_test_${DateTime.now().microsecondsSinceEpoch}@example.com',
      );

      expect(user, isNotNull);
      expect(user!.fullName, equals('Juan Dela Cruz'));
      expect(user.mobile, equals(uniqueMobile));
    });

    test(
        'registerPassenger with existing mobile number updates user without UNIQUE constraint crash',
        () async {
      final mobile =
          '9${DateTime.now().microsecondsSinceEpoch.toString().substring(7, 16)}';
      final email1 =
          'johnlord_initial_${DateTime.now().microsecondsSinceEpoch}@gmail.com';
      final email2 =
          'johnlord_updated_${DateTime.now().microsecondsSinceEpoch}@gmail.com';

      // 1. Initial registration
      final initialUser = await authService.registerPassenger(
        fullName: 'John Lord Cañastra',
        mobile: mobile,
        password: 'password123',
        email: email1,
      );
      expect(initialUser, isNotNull);

      // 2. Re-register / verify with the same mobile and new email - must not throw SQLite UNIQUE constraint exception
      final updatedUser = await authService.registerPassenger(
        fullName: 'John Lord Cañastra',
        mobile: mobile,
        password: 'password123',
        email: email2,
      );

      expect(updatedUser, isNotNull);
      expect(updatedUser!.id, equals(initialUser!.id));
      expect(updatedUser.email, equals(email2));
      expect(updatedUser.mobile, equals(mobile));
      expect(updatedUser.emailVerified, isTrue);
    });

    test('multiple passengers registering without mobile number do not collide',
        () async {
      final email1 =
          'passenger_nomobile_1_${DateTime.now().microsecondsSinceEpoch}@example.com';
      final email2 =
          'passenger_nomobile_2_${DateTime.now().microsecondsSinceEpoch}@example.com';

      final user1 = await authService.registerPassenger(
        fullName: 'Passenger One',
        mobile: '',
        password: 'password123',
        email: email1,
      );

      final user2 = await authService.registerPassenger(
        fullName: 'Passenger Two',
        mobile: '',
        password: 'password123',
        email: email2,
      );

      expect(user1, isNotNull);
      expect(user2, isNotNull);
      expect(user1!.id, isNot(equals(user2!.id)));
    });

    test('isEmailRegistered and isMobileRegistered return accurate results',
        () async {
      final mobile =
          '9${DateTime.now().microsecondsSinceEpoch.toString().substring(7, 16)}';
      final email =
          'check_${DateTime.now().microsecondsSinceEpoch}@example.com';

      expect(await authService.isEmailRegistered(email), isFalse);
      expect(await authService.isMobileRegistered(mobile), isFalse);
      expect(await authService.isEmailRegistered(''), isFalse);
      expect(await authService.isMobileRegistered(''), isFalse);

      await authService.registerPassenger(
        fullName: 'Test Check User',
        mobile: mobile,
        password: 'password123',
        email: email,
      );

      expect(await authService.isEmailRegistered(email), isTrue);
      expect(await authService.isMobileRegistered(mobile), isTrue);
    });

    test(
        'registerPassenger with PhilippineAddress saves address and does not fail on address update',
        () async {
      final mobile =
          '9${DateTime.now().microsecondsSinceEpoch.toString().substring(7, 16)}';
      final email =
          'bonbon_${DateTime.now().microsecondsSinceEpoch}@example.com';
      final address = const PhilippineAddress(
        provinceName: 'Bohol',
        provinceCode: '071200000',
        cityName: 'Clarin',
        cityCode: '071215000',
        barangayName: 'Bonbon',
        barangayCode: '071215004',
        streetDetails: 'Purok 2',
      );

      final user = await authService.registerPassenger(
        fullName: 'John Lord Cañastra',
        mobile: mobile,
        password: 'password123',
        email: email,
        address: address,
      );

      expect(user, isNotNull);
      expect(user!.address, contains('Bonbon'));
      expect(user.address, contains('Clarin'));
      expect(user.address, contains('Bohol'));

      // Re-register / update existing user with new address
      final updatedAddress = address.copyWith(streetDetails: 'Purok 3');
      final updatedUser = await authService.registerPassenger(
        fullName: 'John Lord Cañastra',
        mobile: mobile,
        password: 'password123',
        email: email,
        address: updatedAddress,
      );

      expect(updatedUser, isNotNull);
      expect(updatedUser!.address, contains('Purok 3'));
    });
  });

  group('AuthBloc direct signup flow tests', () {
    test('passenger signup completes without an OTP state', () async {
      final email =
          'bloc_signup_${DateTime.now().microsecondsSinceEpoch}@example.com';
      final mobile =
          '9${DateTime.now().microsecondsSinceEpoch.toString().substring(7, 16)}';
      final authBloc = AuthBloc(authService: authService);

      final states = <AuthState>[];
      authBloc.stream.listen(states.add);

      await authBloc.add(SignUpPassengerSubmitted(
        email: email,
        fullName: 'Bloc Test User',
        password: 'password123',
        mobile: mobile,
        language: 'en',
      ));

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(authBloc.state is AuthPassengerSignedUp, isTrue);
      expect(states.any((s) => s is AuthPassengerSignedUp), isTrue);

      authBloc.dispose();
    });
  });

  group('AuthService Login & Identifier Resolution Tests', () {
    test('login with email succeeds for registered passenger', () async {
      final email =
          'jlcaparas204_test_${DateTime.now().microsecondsSinceEpoch}@gmail.com';
      final mobile =
          '9${DateTime.now().microsecondsSinceEpoch.toString().substring(7, 16)}';
      final password = 'password123';

      await authService.registerPassenger(
        fullName: 'John Lord Caparas',
        mobile: mobile,
        password: password,
        email: email,
      );

      final result = await authService.login(
        mobile: email,
        password: password,
        role: 'passenger',
      );

      expect(result.error, isNull);
      expect(result.user, isNotNull);
      expect(result.user!.email, equals(email));
      expect(result.user!.fullName, equals('John Lord Caparas'));
    });

    test(
        'login with mobile formats (09..., +63..., 9...) resolves and succeeds',
        () async {
      final email =
          'mobile_login_${DateTime.now().microsecondsSinceEpoch}@gmail.com';
      final baseDigits =
          DateTime.now().microsecondsSinceEpoch.toString().substring(7, 16);
      final rawMobile = '9$baseDigits';
      final password = 'password123';

      await authService.registerPassenger(
        fullName: 'Mobile Format User',
        mobile: rawMobile,
        password: password,
        email: email,
      );

      // Try logging in with '09...'
      final res1 = await authService.login(
        mobile: '0$rawMobile',
        password: password,
        role: 'passenger',
      );
      expect(res1.error, isNull);
      expect(res1.user, isNotNull);

      // Try logging in with '+639...'
      final res2 = await authService.login(
        mobile: '+63$rawMobile',
        password: password,
        role: 'passenger',
      );
      expect(res2.error, isNull);
      expect(res2.user, isNotNull);

      // Try logging in with '9...'
      final res3 = await authService.login(
        mobile: rawMobile,
        password: password,
        role: 'passenger',
      );
      expect(res3.error, isNull);
      expect(res3.user, isNotNull);
    });

    test('login with incorrect password returns wrong_password error',
        () async {
      final email =
          'wrong_pass_${DateTime.now().microsecondsSinceEpoch}@gmail.com';
      final password = 'correct_password_123';

      await authService.registerPassenger(
        fullName: 'Password Test User',
        mobile:
            '9${DateTime.now().microsecondsSinceEpoch.toString().substring(7, 16)}',
        password: password,
        email: email,
      );

      final result = await authService.login(
        mobile: email,
        password: 'incorrect_password',
        role: 'passenger',
      );

      expect(result.user, isNull);
      expect(result.error, equals('wrong_password'));
    });

    test('login with incorrect role returns wrong_role error', () async {
      final email =
          'wrong_role_${DateTime.now().microsecondsSinceEpoch}@gmail.com';
      final password = 'password123';

      await authService.registerPassenger(
        fullName: 'Role Test User',
        mobile:
            '9${DateTime.now().microsecondsSinceEpoch.toString().substring(7, 16)}',
        password: password,
        email: email,
      );

      final result = await authService.login(
        mobile: email,
        password: password,
        role: 'driver',
      );

      expect(result.user, isNull);
      expect(result.error, equals('wrong_role'));
    });

    test('login with non-existent credentials returns no_user error', () async {
      final result = await authService.login(
        mobile:
            'nonexistent_${DateTime.now().microsecondsSinceEpoch}@gmail.com',
        password: 'any_password',
        role: 'passenger',
      );

      expect(result.user, isNull);
      expect(result.error, equals('no_user'));
    });
  });
}
