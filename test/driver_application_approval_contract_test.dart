import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('new applications are separate and inaccessible to client roles', () {
    final migration = _read(
      'supabase/migrations/202610130001_driver_application_approval_workflow.sql',
    );
    expect(migration,
        contains('create table if not exists public.driver_applications'));
    expect(migration, contains('enable row level security'));
    expect(migration, contains('force row level security'));
    expect(migration, contains('revoke all on public.driver_applications'));
    expect(migration,
        contains('grant all on public.driver_applications to service_role'));
    expect(migration,
        contains('revoke insert on public.drivers from anon, authenticated'));
    expect(migration, contains('drivers_approved_application_unique'));
    expect(migration, contains('on delete set null'));
  });

  test('deleted TODA references can be nulled without deleting applications',
      () {
    final migration = _read(
      'supabase/migrations/202610130002_allow_deleted_toda_driver_applications.sql',
    );
    expect(
        migration,
        contains(
            'drop constraint if exists driver_applications_toda_vehicle_check'));
    expect(migration, contains('vehicle_type = \'tricycle\' or'));
    expect(migration.toLowerCase(), contains('on delete set null'));
  });

  test(
      'legacy rejection transition is admin-only, conditional, and unambiguous',
      () {
    final migration = _read(
      'supabase/migrations/202610130001_driver_application_approval_workflow.sql',
    );
    expect(migration, contains('if not public.is_admin() then'));
    expect(migration,
        contains('where user_id = \$1 and application_status = \'pending\''));
    expect(migration,
        contains('rejection_reason = case when \$2 then null else \$3 end'));
    expect(migration, isNot(contains('else rejection_reason end')));
    expect(migration, contains('reviewed_at = now()'));
    expect(migration, contains('reviewed_by = auth.uid()'));
  });

  test('driver registration collects password and creates authenticated account', () {
    final registration = _read('lib/pages/driver_registration.dart');
    final auth = _read('lib/services/auth_service.dart');
    expect(registration, contains('submitUnlinkedDriverApplication'));
    expect(registration, contains('_passwordCtrl'));
    expect(registration, contains('_confirmPasswordCtrl'));
    expect(registration, contains('createAuthenticatedAccount'));
    expect(auth, contains('createAuthenticatedAccount'));
    expect(registration, contains('_isoDateOnly(_dobCtrl.text)!'));
  });

  test('Edge review gates provisioning and rejection to authorized Admins', () {
    final edge = _read('supabase/functions/driver-applications/index.ts');
    expect(edge, contains("case 'approve':"));
    expect(edge, contains("case 'reject':"));
    expect(edge, contains('await requireAdmin(request, admin, anonKey)'));
    expect(edge, contains('inviteUserByEmail'));
    expect(
        edge, contains(".eq('status', 'pending').select('*').maybeSingle()"));
    expect(edge, contains("status: 'rejected'"));
    expect(edge, contains('auth_user_id: authUserId'));
    expect(
        edge,
        contains(
            "if (!isUuid(id)) throw new HttpError('Application ID is invalid.')"));
    expect(edge, contains("rejection_reason: reason.trim()"));
    expect(edge, contains('reviewed_by: reviewerId'));
    expect(edge, contains('reviewed_at: new Date().toISOString()'));
  });

  test('invalid optional submit sessions fall back to anonymous only on begin',
      () {
    final edge = _read('supabase/functions/driver-applications/index.ts');
    expect(edge, contains('allowUnverifiedOptionalSession = false'));
    expect(edge, contains('!required && allowUnverifiedOptionalSession'));
    expect(
        edge,
        contains(
            'await authenticatedUser(request, admin, anonKey, false, true)'));
    expect(edge,
        contains('await authenticatedUser(request, admin, anonKey, true)'));
    expect(edge,
        contains('unverifiable optional session; continuing anonymously'));
  });

  test('vehicle color is collected, validated, and sent as a description', () {
    final registration = _read('lib/pages/driver_registration.dart');
    final database = _read('lib/services/supabase_database_service.dart');
    final edge = _read('supabase/functions/driver-applications/index.ts');

    expect(registration, contains('controller: _colorCtrl'));
    expect(registration, contains('l10n.regColor'));
    expect(registration, contains('_validateVehicleStep()'));
    expect(database, contains("'vehicle_color': profile.color.trim()"));
    expect(edge,
        contains('vehicle_color: requiredVehicleColor(body.vehicle_color)'));
    expect(edge, contains('Vehicle color must be 60 characters or fewer.'));
    expect(edge, isNot(contains('allowedVehicleColors')));
  });

  test('license and OR/CR documents remain optional while profile is required',
      () {
    final edge = _read('supabase/functions/driver-applications/index.ts');
    final migration = _read(
      'supabase/migrations/202610130001_driver_application_approval_workflow.sql',
    );

    expect(edge, contains('if (!result.profile)'));
    expect(edge, contains('doc_license_front: paths.license_front ?? null'));
    expect(edge, contains('doc_or_cr: paths.or_cr ?? null'));
    expect(edge, contains('if (!path) continue;'));
    expect(migration, contains('doc_profile text not null'));
    expect(migration, contains('doc_license_front text'));
    expect(migration, contains('doc_or_cr text'));
  });

  test('TODA is shown only for tricycle applications', () {
    final view = _read('lib/pages/admin/views/driver_verification_view.dart');
    expect(view, contains('if (profile.vehicleType == VehicleType.tricycle)'));
    expect(view, contains('_todaAffiliationLabel(profile)'));
    expect(view, contains('_municipalityTodaLabel(p)'));
    expect(view, isNot(contains('Independent Operator')));
    expect(view, isNot(contains('"Ind."')));
  });

  test('failed provisioning and activation email remain retryable and truthful',
      () {
    final edge = _read('supabase/functions/driver-applications/index.ts');
    final view = _read('lib/pages/admin/views/driver_verification_view.dart');
    expect(edge, contains('status.eq.provisioning_failed'));
    expect(edge, contains('applicant_notification_status.neq.sent'));
    expect(edge, contains("type: 'recovery'"));
    expect(
        edge, contains('activationEmailSent: notificationStatus === \'sent\''));
    expect(edge, contains("applicant_notification_status: 'sending'"));
    expect(view, contains('the activation email was not sent'));
    expect(view, contains('Check the server email configuration'));
  });

  test('Admin rejection dialog reports failure and history is rendered', () {
    final view = _read('lib/pages/admin/views/driver_verification_view.dart');
    expect(view, contains('Confirm Rejection'));
    expect(view, contains('Rejection failed: \$error'));
    expect(view, contains("result['status'] != 'rejected'"));
    expect(view, contains('Rejected Application History'));
    expect(view, contains('Reason: \$reason'));
  });
}
