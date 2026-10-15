import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sakay_ta/core/constants.dart';
import 'package:sakay_ta/models/app_user.dart';

void main() {
  test('active passenger status remains active when parsed from Supabase', () {
    final passenger = AppUser.fromMap({
      'id': '00000000-0000-0000-0000-000000000001',
      'full_name': 'Passenger One',
      'account_status': AccountStatus.active,
      'status': AccountStatus.active,
      'created_at': '2026-09-24T00:00:00Z',
    });

    expect(passenger.role, UserRole.passenger);
    expect(passenger.status, AccountStatus.active);
  });

  test('admin passenger reader uses the canonical profile/capability keys', () {
    final source =
        File('lib/services/supabase_database_service.dart').readAsStringSync();
    final legacySource =
        File('lib/services/supabase/profile_service.dart').readAsStringSync();
    final migration = File(
      'supabase/migrations/202609240002_passenger_admin_contract.sql',
    ).readAsStringSync();

    expect(
        source,
        contains(
            'passenger_profiles.user_id -> profiles.id canonical passenger contract'));
    expect(source, contains('(await streamPassengers().first).length'));
    expect(source, contains("'status': row['account_status']"));
    expect(source,
        contains("'profile_photo_path,avatar_color,created_at,updated_at'"));
    expect(legacySource,
        contains('SupabaseDatabaseService.instance.streamPassengers'));
    expect(legacySource, isNot(contains(".eq('role', UserRole.passenger)")));
    expect(migration,
        contains('auth.users.id = profiles.id = passenger_profiles.user_id'));
    expect(migration,
        contains('revoke update on public.profiles from authenticated'));
    expect(migration, isNot(contains('  email,\n  mobile,')));
    expect(migration, contains('return new;'));
    expect(migration,
        isNot(contains('insert into public.passenger_profiles (user_id)')));
    expect(migration, contains('admin_passenger_account_integrity_issues'));
    expect(migration,
        contains('create or replace function public.admin_passenger_count()'));
  });
}
