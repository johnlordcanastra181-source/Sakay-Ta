import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final page =
      File('lib/pages/admin/views/payments_view.dart').readAsStringSync();

  test('admin payments is backed by completed ride fares', () {
    expect(page, contains("status: RideStatus.completed"));
    expect(page, contains('ride.status != RideStatus.completed'));
    expect(page, contains('ride.fare'));
    expect(page, contains("title: 'Total Gross Fares'"));
    expect(page, contains("title: 'Settled Transactions'"));
    expect(page, contains("'No completed transactions recorded.'"));
    expect(page, contains('_optionalEarningsStream'));
    expect(page, contains('optional driver earnings unavailable'));
  });

  test('admin payments deduplicates ride IDs and has no online-ledger math',
      () {
    expect(page, contains('unique.putIfAbsent(rideId, () => ride)'));
    for (final obsolete in [
      'Platform Commission',
      'Net Driver Payout',
      'allPaymentsStream',
      'FirePayment',
      'adminRefundPayment',
      '_selectedStatus',
      '_selectedMethod',
    ]) {
      expect(page, isNot(contains(obsolete)), reason: obsolete);
    }
  });
}
