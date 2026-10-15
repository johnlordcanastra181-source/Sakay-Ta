import 'dart:async';
import '../../models/firestore_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/transaction.dart';
import '../supabase_database_service.dart';

class SupabaseFinanceService {
  SupabaseFinanceService._();
  static final SupabaseFinanceService instance = SupabaseFinanceService._();
  SupabaseClient get _db => Supabase.instance.client;

  Future<void> savePayment(FirePayment payment) async {
    await SupabaseDatabaseService.instance.savePayment(payment);
  }

  Future<FirePayment?> getPayment(String paymentId) async {
    final res =
        await _db.from('payments').select().eq('id', paymentId).maybeSingle();
    return res != null ? FirePayment.fromMap(res) : null;
  }

  Future<FirePayment?> getPaymentForRide(String rideId) async {
    final res =
        await _db.from('payments').select().eq('ride_id', rideId).maybeSingle();
    return res != null ? FirePayment.fromMap(res) : null;
  }

  Stream<FirePayment?> streamPayment(String paymentId) =>
      SupabaseDatabaseService.instance.streamPayment(paymentId);

  Stream<FirePayment?> streamPaymentForRide(String rideId) =>
      SupabaseDatabaseService.instance.streamPaymentForRide(rideId);

  Future<bool> atomicSettleRidePayment({
    required String paymentId,
    required String rideId,
    required String driverId,
    required String passengerId,
    required double fare,
    required double commission,
    required double net,
    required String method,
    required String reference,
    String? gatewayPaymentId,
  }) async {
    try {
      await _db.rpc('settle_ride_payment', params: {
        'payment_id': paymentId,
        'ride_id': rideId,
        'provider_reference': gatewayPaymentId ?? reference,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> saveWithdrawal(Withdrawal withdrawal) async {
    await SupabaseDatabaseService.instance.saveWithdrawal(withdrawal);
  }

  Future<void> requestWithdrawal({
    required String driverId,
    required String driverName,
    required double amount,
    required String method,
    Map<String, dynamic>? accountDetails,
  }) async {
    await _db.from('withdrawals').insert({
      'id': 'withdrawal_${driverId}_${DateTime.now().microsecondsSinceEpoch}',
      'driver_id': driverId,
      'amount': amount,
      'method': method,
      'account_details': {
        'driver_name': driverName,
        ...?accountDetails,
      },
      'status': 'pending',
      'requested_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> adminRefundPayment(
      String paymentId, double amount, String reason) async {
    await _db.from('payments').update({
      'status': 'refunded',
      'metadata': {
        'refund_amount': amount,
        'refund_reason': reason,
        'refunded_at': DateTime.now().toUtc().toIso8601String(),
      },
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', paymentId);
  }

  Future<void> saveTransaction(WalletTransaction transaction) async {
    await SupabaseDatabaseService.instance.saveTransaction(transaction);
  }
}
