import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase/migrations/202609300002_stable_driver_request_acceptance.sql',
  ).readAsStringSync();
  final appState = File('lib/state/app_state.dart').readAsStringSync();
  final driverHome = File('lib/pages/driver_home.dart').readAsStringSync();
  final database =
      File('lib/services/supabase_database_service.dart').readAsStringSync();

  test('profile Realtime uses the canonical explicit channel adapter', () {
    expect(
      migration,
      contains('alter publication supabase_realtime add table public.profiles'),
    );
    expect(database, contains("feature: 'user_profile'"));
    expect(database, contains("table: 'profiles'"));
    expect(database, contains('fetch: () => getUser(userId)'));
  });

  test('visible request survives empty or failed transient snapshots', () {
    expect(appState, contains('_stableIncomingTripsByDriver'));
    expect(appState, contains('AUTHORITATIVE_REFRESH'));
    expect(appState, contains('byId[prior.id] = prior'));
    expect(driverHome, contains('_lastIncomingRequests'));
    expect(driverHome, contains('_stableIncomingStream'));
  });

  test('selected-driver booking does not reserve availability before accept',
      () {
    final bookingFunctionEnd = migration.indexOf(
      '-- The same driver may safely repeat Accept',
    );
    final bookingFunction = migration.substring(0, bookingFunctionEnd);

    expect(
      bookingFunction,
      isNot(contains('set is_available = false')),
    );
    expect(
      bookingFunction,
      contains("r.status in ('searching', 'accepted', 'arrived', 'started')"),
    );
  });

  test('accept is exact-ID, atomic, and same-driver idempotent', () {
    expect(migration, contains('where id = ride_id\n  for update'));
    expect(
      migration,
      contains(
        "current_ride.status = 'accepted' and "
        'current_ride.driver_id = auth.uid()',
      ),
    );
    expect(
      migration,
      contains('r.id <> current_ride.id'),
    );
    final rideUpdate = migration.indexOf('update public.rides');
    final busyUpdate = migration.indexOf(
      'update public.drivers\n  set is_available = false',
    );
    expect(rideUpdate, greaterThan(-1));
    expect(busyUpdate, greaterThan(rideUpdate));
  });

  test('accept failure re-fetches exact ride and does not pre-clear UI', () {
    final acceptStart = appState.indexOf('Future<bool> acceptTripAtomic');
    final acceptEnd = appState.indexOf('Future<void> declineTrip', acceptStart);
    final accept = appState.substring(acceptStart, acceptEnd);

    expect(accept, contains('getTrip(trip.id)'));
    expect(accept, contains('authoritative?.status == RideStatus.searching'));
    expect(accept, contains('activeTrip = acceptedTrip'));
    expect(accept, isNot(contains('activeTrip = null')));
    expect(driverHome, contains("'This trip is no longer available.'"));
    expect(
      driverHome,
      isNot(contains('your driver account is temporarily unavailable')),
    );
  });

  test('accept and decline are both disabled during one acceptance', () {
    expect(
      RegExp(r'onPressed: _isProcessingAccept\s*\? null')
          .allMatches(driverHome),
      hasLength(greaterThanOrEqualTo(2)),
    );
  });

  test('migration preserves RLS and authenticated-only RPC execution', () {
    expect(migration, isNot(contains('disable row level security')));
    expect(
      migration,
      contains('grant execute on function public.accept_ride(text) '
          'to authenticated'),
    );
    expect(
      migration,
      contains('revoke all on function public.accept_ride(text) from public'),
    );
  });
}
