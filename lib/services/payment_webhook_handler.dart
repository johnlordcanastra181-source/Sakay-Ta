import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../core/payment_gateway_config.dart';
import '../models/transaction.dart';
import 'database_service.dart';
import 'supabase_service.dart';
import 'online_payment_gateway.dart';

/// Handles incoming webhooks from PayMongo & Maya payment gateways.
class PaymentWebhookHandler {
  PaymentWebhookHandler({
    PaymentGatewayConfig? config,
    PayMongoGatewayService? gateway,
  })  : _config = config ?? PaymentGatewayConfig.instance,
        _gateway = gateway ?? PayMongoGatewayService();

  final PaymentGatewayConfig _config;
  final PayMongoGatewayService _gateway;

  /// Verifies webhook signature using HMAC SHA256 (PayMongo standard).
  bool verifyWebhookSignature({
    required String rawPayload,
    required String signatureHeader,
  }) {
    final webhookSecret = _config.paymongoWebhookSecret;
    if (webhookSecret.isEmpty) return false;

    try {
      // Signature header format: "t=1498560000,te=...,li=..."
      final pairs = signatureHeader.split(',');
      String? timestamp;
      String? testSignature;
      String? liveSignature;

      for (final pair in pairs) {
        final kv = pair.split('=');
        if (kv.length == 2) {
          final key = kv[0].trim();
          final val = kv[1].trim();
          if (key == 't') timestamp = val;
          if (key == 'te') testSignature = val;
          if (key == 'li') liveSignature = val;
        }
      }

      if (timestamp == null) return false;

      final expectedSignature =
          _config.isSandbox ? testSignature : liveSignature;
      if (expectedSignature == null) return false;

      final message = '$timestamp.$rawPayload';
      final hmac = Hmac(sha256, utf8.encode(webhookSecret));
      final digest = hmac.convert(utf8.encode(message)).toString();

      return digest == expectedSignature;
    } catch (e) {
      debugPrint('Webhook signature verification error: $e');
      return false;
    }
  }

  /// Processes incoming webhook event payload and synchronizes payment, ride, and driver earnings.
  Future<bool> handleIncomingWebhook(
    Map<String, dynamic> payload, {
    String? signatureHeader,
    String? rawPayload,
  }) async {
    if (signatureHeader == null || rawPayload == null) return false;
    final isValid = verifyWebhookSignature(
      rawPayload: rawPayload,
      signatureHeader: signatureHeader,
    );
    if (!isValid) {
      debugPrint('Rejected webhook: invalid signature.');
      return false;
    }

    final result = await _gateway.processWebhookEvent(payload);
    if (result == null) return false;

    final tripId = result.metadata?['trip_id'] as String?;
    final passengerId = result.metadata?['passenger_id'] as String?;
    final driverId = result.metadata?['driver_id'] as String?;

    debugPrint(
        'PaymentWebhookHandler: processed event for sessionId=${result.sessionId}, status=${result.status}');

    // If payment was verified as paid via webhook, atomically settle in Firestore & local DB
    if (result.isPaid && tripId != null) {
      try {
        if (SupabaseService.isConfigured) {
          final firePayment =
              await SupabaseService.instance.getPaymentForRide(tripId);
          if (firePayment != null && driverId != null && driverId.isNotEmpty) {
            final fare = result.amount;

            final settled =
                await SupabaseService.instance.atomicSettleRidePayment(
              paymentId: firePayment.id,
              rideId: tripId,
              passengerId: passengerId ?? firePayment.payerId,
              driverId: driverId,
              fare: fare,
              commission: 0,
              net: fare,
              method: result.paymentMethodType,
              reference: result.referenceNumber,
            );
            if (!settled) {
              throw StateError('Trusted payment settlement was not completed.');
            }
          }
        }

        // Record locally
        if (driverId != null && driverId.isNotEmpty) {
          final tx = WalletTransaction(
            id: 'tx_wh_${result.sessionId}',
            driverId: driverId,
            tripId: tripId,
            type: 'income',
            method: result.paymentMethodType,
            amount: result.amount,
            description:
                'Webhook confirmed ${result.paymentMethodType.toUpperCase()} payment (Ref: ${result.referenceNumber})',
            createdAt: DateTime.now(),
          );
          final database = await DatabaseService.instance.database;
          await database.insert('transactions', tx.toMap());
        }

        return true;
      } catch (e) {
        debugPrint('PaymentWebhookHandler settlement error: $e');
        return false;
      }
    }

    return true;
  }
}
