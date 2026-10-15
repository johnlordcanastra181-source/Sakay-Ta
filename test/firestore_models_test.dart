import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter_test/flutter_test.dart';

import 'package:sakay_ta/models/firestore_models.dart';

void main() {
  final now = DateTime(2026, 8, 13, 10, 30);

  group('FireRating', () {
    test('round-trips through toMap/fromMap', () {
      final rating = FireRating(
        id: 'r1',
        rideId: 'trip_1',
        fromUserId: 'u_passenger',
        toUserId: 'u_driver',
        stars: 5,
        comment: 'Great ride!',
        createdAt: now,
      );

      final restored = FireRating.fromMap(rating.toMap());

      expect(restored.id, 'r1');
      expect(restored.rideId, 'trip_1');
      expect(restored.fromUserId, 'u_passenger');
      expect(restored.toUserId, 'u_driver');
      expect(restored.stars, 5);
      expect(restored.comment, 'Great ride!');
      expect(restored.createdAt, now);
    });

    test('parses Firestore Timestamp dates', () {
      final map = FireRating(
        id: 'r2',
        rideId: 't',
        fromUserId: 'a',
        toUserId: 'b',
        stars: 4,
        createdAt: now,
      ).toMap()..['createdAt'] = Timestamp.fromDate(now);

      expect(FireRating.fromMap(map).createdAt, now);
    });

    test('defaults stars to 5 when missing', () {
      final restored = FireRating.fromMap({'id': 'r3'});
      expect(restored.stars, 5);
      expect(restored.comment, '');
    });
  });

  group('FirePayment', () {
    test('round-trips through toMap/fromMap', () {
      final payment = FirePayment(
        id: 'p1',
        rideId: 'trip_1',
        payerId: 'u_passenger',
        payeeId: 'u_driver',
        amount: 120,
        method: 'gcash',
        status: 'paid',
        createdAt: now,
      );

      final restored = FirePayment.fromMap(payment.toMap());

      expect(restored.id, 'p1');
      expect(restored.rideId, 'trip_1');
      expect(restored.payerId, 'u_passenger');
      expect(restored.payeeId, 'u_driver');
      expect(restored.amount, 120);
      expect(restored.method, 'gcash');
      expect(restored.status, 'paid');
      expect(restored.createdAt, now);
    });

    test('parses epoch-millis dates', () {
      final map = FirePayment(
        id: 'p2',
        rideId: 't',
        payerId: 'a',
        payeeId: 'b',
        amount: 50,
        method: 'cash',
        status: 'unpaid',
        createdAt: now,
      ).toMap()..['createdAt'] = now.millisecondsSinceEpoch;

      expect(FirePayment.fromMap(map).createdAt, now);
    });
  });

  group('DriverEarning', () {
    test('round-trips through toMap/fromMap', () {
      final earning = DriverEarning(
        id: 'e1',
        driverId: 'u_driver',
        rideId: 'trip_1',
        fare: 120,
        commission: 14,
        net: 106,
        createdAt: now,
      );

      final restored = DriverEarning.fromMap(earning.toMap());

      expect(restored.id, 'e1');
      expect(restored.driverId, 'u_driver');
      expect(restored.rideId, 'trip_1');
      expect(restored.fare, 120);
      expect(restored.commission, 14);
      expect(restored.net, 106);
      expect(restored.createdAt, now);
    });
  });

  group('Withdrawal', () {
    test('round-trips through toMap/fromMap', () {
      final withdrawal = Withdrawal(
        id: 'w1',
        driverId: 'u_driver',
        amount: 500,
        method: 'gcash',
        status: 'processing',
        reference: 'REF-123',
        note: 'Weekly payout',
        createdAt: now,
        processedAt: now,
      );

      final restored = Withdrawal.fromMap(withdrawal.toMap());

      expect(restored.id, 'w1');
      expect(restored.driverId, 'u_driver');
      expect(restored.amount, 500);
      expect(restored.method, 'gcash');
      expect(restored.status, 'processing');
      expect(restored.reference, 'REF-123');
      expect(restored.note, 'Weekly payout');
      expect(restored.createdAt, now);
      expect(restored.processedAt, now);
    });

    test('defaults status to pending when missing', () {
      final restored = Withdrawal.fromMap({'id': 'w2', 'driverId': 'u'});
      expect(restored.status, 'pending');
      expect(restored.processedAt, isNull);
    });
  });

  group('FareMatrix', () {
    test('round-trips through toMap/fromMap', () {
      final matrix = FareMatrix(
        id: 'tricycle',
        vehicleType: 'tricycle',
        baseFare: 15,
        perKm: 12,
        minimumFare: 15,
        commissionRate: 0.12,
        updatedAt: now,
      );

      final restored = FareMatrix.fromMap(matrix.toMap());

      expect(restored.id, 'tricycle');
      expect(restored.vehicleType, 'tricycle');
      expect(restored.baseFare, 15);
      expect(restored.perKm, 12);
      expect(restored.minimumFare, 15);
      expect(restored.commissionRate, 0.12);
      expect(restored.updatedAt, now);
    });
  });

  group('TodaAssociation', () {
    test('round-trips through toMap/fromMap', () {
      final association = TodaAssociation(
        id: 'a1',
        todaId: 'toda_1',
        driverId: 'u_driver',
        status: 'approved',
        role: 'member',
        createdAt: now,
      );

      final restored = TodaAssociation.fromMap(association.toMap());

      expect(restored.id, 'a1');
      expect(restored.todaId, 'toda_1');
      expect(restored.driverId, 'u_driver');
      expect(restored.status, 'approved');
      expect(restored.role, 'member');
      expect(restored.createdAt, now);
    });

    test('defaults status/role when missing', () {
      final restored =
          TodaAssociation.fromMap({'id': 'a2', 'todaId': 't', 'driverId': 'd'});
      expect(restored.status, 'approved');
      expect(restored.role, 'member');
    });
  });
}
