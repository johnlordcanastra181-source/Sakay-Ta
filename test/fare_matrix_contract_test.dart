import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final farePage =
      File('lib/pages/admin/views/fare_matrix_view.dart').readAsStringSync();
  final fareModel = File('lib/models/fare_matrix.dart').readAsStringSync();
  final calculator =
      File('lib/services/fare_calculator.dart').readAsStringSync();
  final repository =
      File('lib/services/fare_repository.dart').readAsStringSync();
  final tripService = File('lib/services/trip_service.dart').readAsStringSync();
  final settingsPage =
      File('lib/pages/admin/views/admin_profile_view.dart').readAsStringSync();
  final ridesPage =
      File('lib/pages/admin/views/rides_view.dart').readAsStringSync();
  final analyticsPage =
      File('lib/pages/admin/views/analytics_view.dart').readAsStringSync();
  final migration = File(
    'supabase/migrations/202610070001_simplify_fare_configuration.sql',
  ).readAsStringSync();

  test('Fare Matrix exposes only ride fare inputs in the admin editor', () {
    for (final obsolete in [
      'Commission Percent',
      'Sakay Ta Fee',
      'Driver Net Earnings',
      'Per Minute Rate',
      'Booking Fee',
      'Surge Multiplier',
    ]) {
      expect(farePage, isNot(contains(obsolete)), reason: obsolete);
    }
    expect(farePage, contains('Included Base Distance (km)'));
    expect(farePage, contains('Distance Charge'));
    expect(farePage, contains('Total Fare'));
  });

  test('Settings is read-only and admin reporting has no fare split', () {
    expect(settingsPage, contains('FARE MATRIX (READ-ONLY)'));
    expect(
        settingsPage, contains('Go to Fare Matrix page to edit these rates.'));
    for (final obsolete in [
      'Commission',
      'Per Minute',
      'Surge',
      'Platform Commission',
      'Net Driver Payout',
    ]) {
      expect(settingsPage, isNot(contains(obsolete)), reason: obsolete);
      expect(ridesPage, isNot(contains(obsolete)), reason: obsolete);
      expect(analyticsPage, isNot(contains(obsolete)), reason: obsolete);
    }
  });

  test('shared fare formula uses included distance and has no split math', () {
    expect(fareModel, contains('includedBaseDistance'));
    expect(calculator, contains('matrix.includedBaseDistance'));
    expect(
        calculator, contains('matrix.baseFare + (validKm * matrix.perKmRate)'));
    expect(calculator, isNot(contains('calculateCommission')));
    expect(calculator, isNot(contains('commissionPercent')));
    expect(tripService, contains('commission: 0'));
    expect(tripService, contains('net: fare'));
  });

  test('Admin writes only editable fare inputs', () {
    expect(repository, contains("'base_fare': matrix.baseFare"));
    expect(repository,
        contains("'included_base_distance': matrix.includedBaseDistance"));
    expect(repository, contains("'per_km_rate': matrix.perKmRate"));
    expect(repository, isNot(contains('commission_percent')));
  });

  test('new Supabase rides store full fare and preserve legacy columns', () {
    expect(migration, contains('included_base_distance'));
    expect(migration,
        contains('GREATEST(distance_km - config.included_base_distance, 0)'));
    expect(migration, contains('calculated_fare, 0,\n    calculated_fare'));
    expect(migration, contains('ALTER TABLE public.fare_matrix'));
    expect(migration, isNot(contains('platform_commission')));
  });
}
