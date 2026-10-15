import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('Approved Driver Dashboard Access & Authentication Flow', () {
    test('AppState exposes initializeApprovedDriverSession and clearDriverApplicationReceipt', () {
      final appState = _read('lib/state/app_state.dart');
      expect(appState, contains('Future<bool> initializeApprovedDriverSession() async'));
      expect(appState, contains('Future<void> clearDriverApplicationReceipt() async'));
      expect(appState, contains('currentUser = resolvedUser;'));
      expect(appState, contains('driverProfile = freshDriverProfile;'));
      expect(appState, contains('await prefs.saveSession(resolvedUser.id, resolvedUser.role);'));
      expect(appState, contains('await clearDriverApplicationReceipt();'));
      expect(appState, contains('await _loadUserData(resolvedUser.id);'));
    });

    test('AuthService restoreSession checks Supabase currentUser as fallback and saves session', () {
      final auth = _read('lib/services/auth_service.dart');
      expect(auth, contains('var userId = await prefs.sessionUserId;'));
      expect(auth, contains('userId = Supabase.instance.client.auth.currentUser?.id;'));
      expect(auth, contains('await prefs.saveSession(cloudUser.id, cloudUser.role);'));
    });

    test('PrefsService includes clearDriverApplicationReceipt', () {
      final prefs = _read('lib/services/prefs_service.dart');
      expect(prefs, contains('Future<void> clearDriverApplicationReceipt() async'));
      expect(prefs, contains('await _p.remove(kDriverApplicationId);'));
      expect(prefs, contains('await _p.remove(kDriverApplicationStatusToken);'));
      expect(prefs, contains('await _p.remove(kDriverApplicationEmail);'));
    });

    test('Driver pending approval screen uses initializeApprovedDriverSession with fallback to login', () {
      final pending = _read('lib/pages/driver_pending_approval.dart');
      expect(pending, contains('await app.initializeApprovedDriverSession()'));
      expect(pending, contains('widget.onNavigate(AppScreen.driverHome)'));
      expect(pending, contains('widget.onNavigate(AppScreen.login)'));
      expect(pending, contains('Your session could not be verified. Please sign in to access your dashboard.'));
    });

    test('Driver pending approval screen displays exact approval copy', () {
      final pending = _read('lib/pages/driver_pending_approval.dart');
      expect(pending, contains("'Your driver application has been approved!'"));
      expect(pending, contains("'Application approved'"));
    });

    test('Admin driver verification view displays exact approval toast', () {
      final view = _read('lib/pages/admin/views/driver_verification_view.dart');
      expect(view, contains("'Driver approved successfully!'"));
    });

    test('Driver registration persists session when account is created', () {
      final registration = _read('lib/pages/driver_registration.dart');
      expect(registration, contains('await AppState.instance.prefs.saveSession(authUser.id, UserRole.driver);'));
    });
  });
}

