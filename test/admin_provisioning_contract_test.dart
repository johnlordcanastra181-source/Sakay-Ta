import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Admin Web provisions staff without replacing the caller session', () {
    final state = File('lib/state/app_state.dart').readAsStringSync();
    final service =
        File('lib/services/supabase_database_service.dart').readAsStringSync();
    final createFlow = state
        .split('Future<void> createAdminAccount({')[1]
        .split('/// Updates an existing administrator')[0];

    expect(createFlow, contains('createAdminAccountSecure(request, password)'));
    expect(createFlow, isNot(contains('createAdminAuthAccount(')));
    expect(createFlow, isNot(contains('saveAdminAccount(admin)')));
    expect(service, contains("functions.invoke('admin-users'"));
  });
}
