import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('admin dashboard uses the canonical server-side authorization contract',
      () {
    final migration = File(
      'supabase/migrations/202609230004_admin_dashboard_authorization_contract.sql',
    ).readAsStringSync();
    final adminService =
        File('lib/services/supabase/admin_service.dart').readAsStringSync();
    final dashboardService =
        File('lib/services/supabase_database_service.dart').readAsStringSync();

    expect(migration, contains("ar.role = 'super_admin'"));
    expect(migration, contains('admin_dashboard_authorization'));
    expect(
        migration,
        contains('grant execute on function '
            'public.admin_dashboard_authorization() to authenticated'));
    expect(adminService, contains("rpc('admin_dashboard_authorization')"));
    expect(dashboardService, contains("'admin_dashboard_authorization() RPC'"));
  });
}
