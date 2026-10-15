import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('Issue 1: Approved Driver Application Reflects Approved Status', () {
    test('Edge Function provisions approved status immediately upon admin approval', () {
      final edge = _read('supabase/functions/driver-applications/index.ts');
      expect(edge, contains("const driverStatus = 'approved';"));
      expect(edge, contains("const profileStatus = (profile && ['deactivated', 'suspended'].includes(profile.account_status))"));
      expect(edge, contains("const finalStatus = existingIdentity ? 'approved' : 'awaiting_activation';"));
      expect(edge, contains("if (application.status === 'active' || application.status === 'approved')"));
      expect(edge, contains("title: 'Driver Application Approved'"));
    });

    test('SQL get_admin_drivers_paginated returns approved status for approved drivers', () {
      final migration = _read('supabase/migrations/202610140002_driver_account_lifecycle_hard_fix.sql');
      expect(migration, contains("WHEN d.application_status::text IN ('approved', 'active') THEN 'approved'"));
      expect(migration, contains("CREATE OR REPLACE FUNCTION public.get_admin_drivers_paginated"));
    });
  });

  group('Issue 2: Admin Delete Driver Button and Account Deletion', () {
    test('SQL can_delete_accounts authorizes active admins and super admins', () {
      final migration = _read('supabase/migrations/202610140002_driver_account_lifecycle_hard_fix.sql');
      expect(migration, contains("CREATE OR REPLACE FUNCTION public.can_delete_accounts(check_user uuid DEFAULT auth.uid())"));
      expect(migration, contains("AND ar.role IN ('admin', 'super_admin')"));
      expect(migration, contains("AND ar.status = 'active'"));
    });

    test('Edge Function admin-delete-account permits active admins', () {
      final edge = _read('supabase/functions/admin-delete-account/index.ts');
      expect(edge, contains("callerRole.role === 'super_admin' ||"));
      expect(edge, contains("callerRole.role === 'admin' ||"));
    });

    test('admin-delete-account supports both targetUserId and applications storage paths', () {
      final edge = _read('supabase/functions/admin-delete-account/index.ts');
      expect(edge, contains("(path.startsWith(`\${targetUserId}/`) || path.startsWith('applications/'))"));
    });

    test('SQL admin_prepare_account_deletion cleans up driver applications and driver operational records', () {
      final migration = _read('supabase/migrations/202610140002_driver_account_lifecycle_hard_fix.sql');
      expect(migration, contains("UPDATE public.driver_applications"));
      expect(migration, contains("SET auth_user_id = NULL, status = 'deleted', updated_at = now()"));
      expect(migration, contains("DELETE FROM public.driver_online_sessions WHERE driver_id = target_user;"));
      expect(migration, contains("DELETE FROM public.driver_documents WHERE driver_id = target_user;"));
      expect(migration, contains("DELETE FROM public.driver_presence WHERE driver_id = target_user;"));
      expect(migration, contains("DELETE FROM public.drivers WHERE user_id = target_user;"));
    });
  });

  group('Issue 3: Password Registration for Driver Applicants', () {
    test('Driver registration form includes password and confirm password controllers and inputs', () {
      final registration = _read('lib/pages/driver_registration.dart');
      expect(registration, contains('final _passwordCtrl = TextEditingController(text: \'\');'));
      expect(registration, contains('final _confirmPasswordCtrl = TextEditingController(text: \'\');'));
      expect(registration, contains('bool _showPassword = false;'));
      expect(registration, contains('bool _showConfirmPassword = false;'));
      expect(registration, contains('l10n.signUpPassword'));
      expect(registration, contains('l10n.signUpConfirmPassword'));
    });

    test('Driver registration validates password length >= 6 and match', () {
      final registration = _read('lib/pages/driver_registration.dart');
      expect(registration, contains('_passwordCtrl.text.length < 6'));
      expect(registration, contains('_passwordCtrl.text != _confirmPasswordCtrl.text'));
      expect(registration, contains('signUpPasswordError'));
      expect(registration, contains('signUpConfirmPasswordError'));
    });

    test('Driver registration creates authenticated account with password before submitting application', () {
      final registration = _read('lib/pages/driver_registration.dart');
      expect(registration, contains('SupabaseAuthService.createAuthenticatedAccount'));
      expect(registration, contains('password: _passwordCtrl.text'));
      expect(registration, contains('submitUnlinkedDriverApplication'));
    });

    test('AuthService registers driver without obsolete provisioning error', () {
      final auth = _read('lib/services/auth_service.dart');
      expect(auth, isNot(contains('Driver accounts are provisioned only after Admin approval. Submit a driver application without creating a password.')));
      expect(auth, contains('SupabaseAuthService.createAuthenticatedAccount'));
    });
  });

  group('Issue 4: Revocation on Rejection & Retaining Rejected History', () {
    test('Edge Function cleans up rejected pending accounts while preserving rejected application record', () {
      final edge = _read('supabase/functions/driver-applications/index.ts');
      expect(edge, contains("status: 'rejected'"));
      expect(edge, contains('deleteUser(authUserId)'));
      expect(edge, contains("from('driver_online_sessions').delete()"));
      expect(edge, contains("from('driver_presence').delete()"));
      expect(edge, contains("from('drivers').delete()"));
      expect(edge, contains("from('driver_documents').delete()"));
      expect(edge, contains("from('profiles').delete()"));
    });

    test('SQL get_admin_drivers_paginated returns rejected driver applications', () {
      final migration = _read('supabase/migrations/202610140002_driver_account_lifecycle_hard_fix.sql');
      expect(migration, contains("FROM public.driver_applications da"));
      expect(migration, contains("WHERE da.status = 'rejected'"));
      expect(migration, contains("'rejected' AS status"));
    });

    test('Admin drivers view includes Rejected and Approved in status filter dropdown', () {
      final view = _read('lib/pages/admin/views/drivers_view.dart');
      expect(view, contains("value: 'approved', child: Text('Approved')"));
      expect(view, contains("value: 'rejected', child: Text('Rejected')"));
    });
  });

  group('Automatic Approval Access & Navigation', () {
    test('DriverPendingApproval detects approved status and auto-navigates', () {
      final page = _read('lib/pages/driver_pending_approval.dart');
      expect(page, contains("status == 'active' || status == 'approved'"));
      expect(page, contains('_checkApprovalAndNavigate()'));
      expect(page, contains('widget.onNavigate(AppScreen.driverHome)'));
      expect(page, contains('Go to Driver Dashboard'));
    });
  });
}

