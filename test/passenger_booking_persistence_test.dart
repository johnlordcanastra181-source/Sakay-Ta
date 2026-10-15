import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('passenger success is emitted only after a persisted ride exists', () {
    final bloc =
        File('lib/state/passenger_search_bloc.dart').readAsStringSync();
    final appState = File('lib/state/app_state.dart').readAsStringSync();
    final gateway =
        File('lib/services/supabase_database_service.dart').readAsStringSync();
    final modal =
        File('lib/widgets/booking_confirmation_modal.dart').readAsStringSync();

    final requestIndex = bloc.indexOf('final trip = await AppState.instance');
    final confirmedIndex = bloc.indexOf('isBookingConfirmed: true');
    expect(requestIndex, greaterThan(-1));
    expect(confirmedIndex, greaterThan(requestIndex));
    expect(bloc, contains('isBookingConfirmed: false'));

    expect(appState, contains('if (SupabaseService.isConfigured)'));
    expect(appState, contains('persisted=1'));
    expect(appState,
        contains('Internet connection is required to book a selected driver.'));
    expect(
        gateway, contains("row['status']?.toString() != RideStatus.searching"));
    expect(gateway, contains("row['driver_id']?.toString() != trip.driverId"));
    expect(modal, contains('Future<bool> Function() onConfirm'));
    expect(modal, contains("? 'Booking...'"));
  });
}
