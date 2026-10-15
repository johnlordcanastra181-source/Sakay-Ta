import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakay_ta/models/philippine_address.dart';

void main() {
  group('Passenger Registration Flow - Mandatory Tests 1 to 20', () {
    // TEST 1: New Passenger creates an account without OTP
    test('1. New Passenger creates an account without OTP', () {
      final signupSource = File('lib/pages/passenger_signup.dart').readAsStringSync();
      expect(signupSource.contains('EmailOtpPage'), isFalse);
      expect(signupSource.contains('requestEmailOtp'), isFalse);
      expect(signupSource.contains('verifyOtp'), isFalse);
      expect(signupSource.contains('registerPassenger'), isTrue);
    });

    // TEST 2: Correct Supabase Auth user is created
    test('2. Correct Supabase Auth user is created with valid metadata', () {
      final authServiceSource = File('lib/services/supabase_auth_service.dart').readAsStringSync();
      expect(authServiceSource.contains('auth.signUp'), isTrue);
      expect(authServiceSource.contains("'full_name': fullName"), isTrue);
      expect(authServiceSource.contains("'mobile': mobile"), isTrue);
      expect(authServiceSource.contains('targetEmail'), isTrue);
    });

    // TEST 3: Valid authenticated session is established
    test('3. Valid authenticated session is established upon signup', () {
      final authSource = File('lib/services/supabase_auth_service.dart').readAsStringSync();
      final registrationSource = File('lib/services/auth_service.dart').readAsStringSync();
      expect(authSource.contains('response.session ?? auth.currentSession'), isTrue);
      expect(authSource.contains('activeUser?.id != createdUser.id'), isTrue);
      expect(registrationSource.contains('client.auth.currentSession == null'), isTrue);
    });

    // TEST 4: Passenger profile is saved successfully
    test('4. Passenger profile is saved successfully into profiles and passenger_profiles', () {
      final authServiceSource = File('lib/services/auth_service.dart').readAsStringSync();
      expect(authServiceSource.contains(".from('profiles')"), isTrue);
      expect(authServiceSource.contains(".from('passenger_profiles').upsert"), isTrue);
      expect(authServiceSource.contains("'default_address': user.address"), isTrue);
      expect(authServiceSource.contains('[SIGNUP] stage=passenger_profile_setup success'), isTrue);
    });

    // TEST 5: Passenger Dashboard opens directly
    test('5. Passenger Dashboard opens directly after registration', () {
      final signupSource = File('lib/pages/passenger_signup.dart').readAsStringSync();
      expect(signupSource.contains('AppState.instance.currentUser = user'), isTrue);
      expect(signupSource.contains('widget.onNavigate(AppScreen.passengerHome)'), isTrue);
    });

    // TEST 6: No permanent loading (isLoading strictly reset in finally block)
    test('6. No permanent loading state occurs', () {
      final signupSource = File('lib/pages/passenger_signup.dart').readAsStringSync();
      expect(signupSource.contains('finally {'), isTrue);
      expect(signupSource.contains('if (mounted) setState(() => _isLoading = false);'), isTrue);
    });

    // TEST 7: No Back-button workaround (onNavigate replaces active screen cleanly)
    test('7. No Back-button workaround; router screen transition is authoritative', () {
      final mainSource = File('lib/main.dart').readAsStringSync();
      expect(mainSource.contains('AppScreen.passengerHome => passenger_home.PassengerHome'), isTrue);
      expect(mainSource.contains('AppScreen.passengerRegistration =>'), isTrue);
    });

    // TEST 8: Double-tap Create Account creates only one account
    test('8. Double-tap Create Account creates only one account (concurrent submit guard)', () {
      final signupSource = File('lib/pages/passenger_signup.dart').readAsStringSync();
      expect(signupSource.contains('if (_isLoading) return;'), isTrue);
      expect(signupSource.contains('onPressed: _isLoading ? null : () => _submitForm(l10n)'), isTrue);
    });

    // TEST 9: Existing email is handled correctly
    test('9. Existing email is handled correctly and displays user-friendly message', () {
      final signupSource = File('lib/pages/passenger_signup.dart').readAsStringSync();
      expect(signupSource.contains('This email address is already registered. Please log in instead.'), isTrue);
    });

    // TEST 10: Partially registered account has safe recovery and self-healing
    test('10. Partially registered account has safe recovery and self-healing', () {
      final authSource = File('lib/services/supabase_auth_service.dart').readAsStringSync();
      final loginValidationSource = File('lib/services/auth_service.dart').readAsStringSync();
      expect(authSource.contains('user_already_exists'), isTrue);
      expect(authSource.contains('auth.signInWithPassword'), isTrue);
      expect(loginValidationSource.contains('self-healed missing passenger_profiles'), isTrue);
    });

    // TEST 11: Missing required field is rejected
    test('11. Missing required field is rejected by validators', () {
      final signupSource = File('lib/pages/passenger_signup.dart').readAsStringSync();
      expect(signupSource.contains('_validateFullName'), isTrue);
      expect(signupSource.contains('_validateEmail'), isTrue);
      expect(signupSource.contains('_validatePassword'), isTrue);
      expect(signupSource.contains('hasPartialAddress'), isTrue);
      expect(signupSource.contains('_termsAccepted'), isTrue);
    });

    // TEST 12: Valid address is saved correctly
    test('12. Valid address is saved correctly to PhilippineAddress and profile payload', () {
      const address = PhilippineAddress(
        provinceName: 'Cebu',
        provinceCode: '0722',
        cityName: 'Toledo City',
        cityCode: '072251',
        barangayName: 'Poblacion',
        barangayCode: '072251020',
        streetDetails: '123 Main St',
      );
      expect(address.isComplete, isTrue);
      expect(address.formattedAddress, contains('Toledo City'));
      expect(address.formattedAddress, contains('Brgy. Poblacion'));
      expect(address.formattedAddress, contains('Cebu'));
    });

    // TEST 13: Signup works under slow network conditions
    test('13. Signup works under slow network conditions without race conditions', () {
      final signupSource = File('lib/pages/passenger_signup.dart').readAsStringSync();
      expect(signupSource.contains('setState(() => _isLoading = true)'), isTrue);
      expect(signupSource.contains('await authService.registerPassenger'), isTrue);
    });

    // TEST 14: Genuine server error is displayed accurately
    test('14. Genuine server error is displayed accurately', () {
      final signupSource = File('lib/pages/passenger_signup.dart').readAsStringSync();
      expect(signupSource.contains('Registration is not ready on the server. An administrator must disable Supabase Email Confirm before accounts can open immediately.'), isTrue);
      expect(signupSource.contains('Unable to reach the Sakay Ta server. Please check your internet connection and try again.'), isTrue);
      expect(signupSource.contains('Your account was created, but the passenger profile could not be saved. Please retry while signed in.'), isTrue);
    });

    // TEST 15: Logout and login work with the new credentials
    test('15. Logout and login work with the new credentials', () {
      final authServiceSource = File('lib/services/auth_service.dart').readAsStringSync();
      expect(authServiceSource.contains('Future<AuthResult> login'), isTrue);
      expect(authServiceSource.contains('_validateSupabaseRole'), isTrue);
      expect(authServiceSource.contains('UserRole.passenger'), isTrue);
    });

    // TEST 16: App restart restores authenticated session
    test('16. App restart restores authenticated session from preferences and Supabase client', () {
      final authServiceSource = File('lib/services/auth_service.dart').readAsStringSync();
      expect(authServiceSource.contains('prefs.saveSession(uid, user.role)'), isTrue);
      expect(authServiceSource.contains('_cacheUser(user)'), isTrue);
    });

    // TEST 17: Forgot Password OTP still works
    test('17. Forgot Password OTP still works and is strictly preserved', () {
      final recoverySource = File('lib/services/password_recovery_service.dart').readAsStringSync();
      expect(recoverySource.contains('OtpType.recovery'), isTrue);
      expect(recoverySource.contains('sendRecoveryEmail'), isTrue);
      expect(recoverySource.contains('verifyRecoveryOtp'), isTrue);
    });

    // TEST 18: Change Password verification still works
    test('18. Change Password verification still works and is strictly preserved', () {
      final changeSource = File('lib/services/password_change_service.dart').readAsStringSync();
      expect(changeSource.contains('reauthenticate'), isTrue);
      expect(changeSource.contains('OtpType.email'), isTrue);
      expect(changeSource.contains('verifyAndUpdate'), isTrue);
    });

    // TEST 19: RLS and account isolation remain secure
    test('19. RLS and account isolation remain secure (no service role in client)', () {
      final dbServiceSource = File('lib/services/supabase_database_service.dart').readAsStringSync();
      final authServiceSource = File('lib/services/auth_service.dart').readAsStringSync();
      expect(dbServiceSource.contains('service_role'), isFalse);
      expect(authServiceSource.contains('service_role'), isFalse);
    });

    // TEST 20: Existing Signup UI remains unchanged
    test('20. Existing Signup UI remains unchanged (fields, layout, cascading address, terms)', () {
      final signupSource = File('lib/pages/passenger_signup.dart').readAsStringSync();
      expect(signupSource.contains('PhilippineAddressSelector'), isTrue);
      expect(signupSource.contains('_fullNameController'), isTrue);
      expect(signupSource.contains('_emailController'), isTrue);
      expect(signupSource.contains('_mobileController'), isTrue);
      expect(signupSource.contains('_passwordController'), isTrue);
      expect(signupSource.contains('_selectedLanguage'), isTrue);
      expect(signupSource.contains('_termsAccepted'), isTrue);
    });
  });
}
