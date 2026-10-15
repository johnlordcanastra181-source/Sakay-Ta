import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _source(String path) => File(path).readAsStringSync();

void main() {
  test('passenger signup has no signup OTP request or route', () {
    final source = _source('lib/pages/passenger_signup.dart');
    expect(source, isNot(contains('EmailOtpPage')));
    expect(source, isNot(contains('requestEmailOtp')));
    expect(source, isNot(contains("purpose: 'signup'")));
    expect(source, contains('registerPassenger'));
    expect(source, contains('AppScreen.passengerHome'));
  });

  test('driver application submits without OTP or preapproval Auth signup', () {
    final source = _source('lib/pages/driver_registration.dart');
    expect(source, isNot(contains('EmailOtpPage')));
    expect(source, isNot(contains('requestEmailOtp')));
    expect(source, isNot(contains('Verify Email Code')));
    expect(source, isNot(contains('prepareDriverApplicant')));
    expect(source, isNot(contains('submitDriverApplication')));
    expect(source, isNot(contains('auth.signUp')));
    expect(source, contains('submitUnlinkedDriverApplication'));
    expect(source, contains('driverPendingApproval'));
    expect(source, contains('No driver login account was created yet'));
  });

  test('legacy signup Edge Function is retired instead of issuing OTPs', () {
    final source = _source('supabase/functions/passenger-signup/index.ts');
    expect(source, contains('signup_flow_retired'));
    expect(source, contains('status: 410'));
    expect(source, isNot(contains('SIGNUP_OTP_PEPPER')));
    expect(source, isNot(contains('sendOtpEmail')));
  });

  test('registration requires an authenticated Supabase session', () {
    final auth = _source('lib/services/supabase_auth_service.dart');
    final registration = _source('lib/services/auth_service.dart');
    expect(auth, contains('createAuthenticatedAccount'));
    expect(auth, contains('currentSession'));
    expect(auth, contains('Confirm Email'));
    expect(registration, contains('client.auth.currentSession'));
  });

  test('password OTP boundaries remain recovery and reauthentication only', () {
    final recovery = _source('lib/services/password_recovery_service.dart');
    final change = _source('lib/services/password_change_service.dart');
    expect(recovery, contains('OtpType.recovery'));
    expect(change, contains('reauthenticate'));
    expect(change, contains('OtpType.email'));
    expect(change, contains('updateUser'));
  });
}
