import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase/migrations/202610100003_admin_account_deletion_direct.sql',
  ).readAsStringSync();
  final function = File(
    'supabase/functions/admin-delete-account/index.ts',
  ).readAsStringSync();
  final adminService = File(
    'lib/services/supabase/admin_service.dart',
  ).readAsStringSync();
  final passengers = File(
    'lib/pages/admin/views/passengers_view.dart',
  ).readAsStringSync();
  final drivers = File(
    'lib/pages/admin/views/drivers_view.dart',
  ).readAsStringSync();

  test('deletion migration preserves shared financial rows safely', () {
    expect(migration, contains('admin_prepare_account_deletion'));
    expect(migration, contains('can_delete_accounts'));
    expect(migration, contains('cancelled_active_ride_count'));
    expect(migration, contains('status = \'cancelled\''));
    expect(migration, contains('ride_status_history'));
    expect(migration, contains("'ride_cancelled'"));
    expect(migration, isNot(contains('unresolved payment')));
    expect(migration, isNot(contains('unsettled withdrawal')));
    expect(migration, isNot(contains('Type DELETE')));
    expect(migration, contains("SET passenger_id = NULL"));
    expect(migration, contains("SET driver_id = NULL"));
    expect(migration, contains("DELETE FROM public.driver_documents"));
    expect(migration, contains("DELETE FROM public.passenger_profiles"));
    expect(migration, contains("'Deleted passenger'"));
    expect(migration, contains('account_deletion_audit'));
    expect(migration, contains('storage_paths jsonb'));
    expect(migration, contains('target_storage_paths'));
  });

  test('Edge Function owns Auth and Storage deletion', () {
    expect(function, contains("SUPABASE_SERVICE_ROLE_KEY"));
    expect(function, contains('auth.admin.deleteUser'));
    expect(function, contains("admin_prepare_account_deletion"));
    expect(function, isNot(contains("confirmation: 'DELETE'")));
    expect(function, isNot(contains('Type DELETE')));
    expect(function, contains('storage.from(bucket).remove'));
    expect(function, contains('storageObjectsFromPreparation'));
    expect(function, contains('storage_cleanup_incomplete'));
    expect(function, contains("delete_accounts"));
    expect(function, contains('partial: true'));
  });

  test('admin UI starts secure deletion from the existing dialog action', () {
    expect(adminService, contains("'admin-delete-account'"));
    expect(adminService, isNot(contains("'confirmation': 'DELETE'")));
    expect(passengers, contains('Delete Passenger Account?'));
    expect(passengers, contains('_deletePassenger'));
    expect(passengers, isNot(contains("Type DELETE to confirm.")));
    expect(drivers, contains('Delete Driver Account?'));
    expect(drivers, contains('_deleteDriver'));
    expect(drivers, isNot(contains("Type DELETE to confirm.")));
  });
}
