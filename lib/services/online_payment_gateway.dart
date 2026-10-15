import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/payment_gateway_config.dart';

/// Structured result returned by the payment gateway.
class GatewayPaymentResult {
  final String sessionId;
  final String? paymentId;
  final String
      status; // 'paid', 'pending_payment', 'failed', 'cancelled', 'expired'
  final double amount;
  final String currency;
  final String paymentMethodType; // 'gcash', 'paymaya', 'card'
  final String referenceNumber;
  final String? checkoutUrl;
  final DateTime? paidAt;
  final Map<String, dynamic>? metadata;

  const GatewayPaymentResult({
    required this.sessionId,
    this.paymentId,
    required this.status,
    required this.amount,
    this.currency = 'PHP',
    required this.paymentMethodType,
    required this.referenceNumber,
    this.checkoutUrl,
    this.paidAt,
    this.metadata,
  });

  bool get isPaid => status == 'paid' || status == 'succeeded';
  bool get isPending =>
      status == 'pending_payment' ||
      status == 'processing' ||
      status == 'awaiting_payment_method';
  bool get isFailed =>
      status == 'failed' || status == 'cancelled' || status == 'expired';

  Map<String, dynamic> toMap() => {
        'sessionId': sessionId,
        'paymentId': paymentId,
        'status': status,
        'amount': amount,
        'currency': currency,
        'paymentMethodType': paymentMethodType,
        'referenceNumber': referenceNumber,
        'checkoutUrl': checkoutUrl,
        'paidAt': paidAt?.toIso8601String(),
        'metadata': metadata,
      };

  factory GatewayPaymentResult.fromMap(Map<String, dynamic> map) =>
      GatewayPaymentResult(
        sessionId: map['sessionId'] as String? ?? '',
        paymentId: map['paymentId'] as String?,
        status: map['status'] as String? ?? 'pending_payment',
        amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
        currency: map['currency'] as String? ?? 'PHP',
        paymentMethodType: map['paymentMethodType'] as String? ?? 'gcash',
        referenceNumber: map['referenceNumber'] as String? ?? '',
        checkoutUrl: map['checkoutUrl'] as String?,
        paidAt: map['paidAt'] != null
            ? DateTime.tryParse(map['paidAt'] as String)
            : null,
        metadata: map['metadata'] as Map<String, dynamic>?,
      );
}

/// Abstract contract for Philippine online payment gateways.
abstract class OnlinePaymentGatewayInterface {
  Future<GatewayPaymentResult> createCheckoutSession({
    required String tripId,
    required String passengerId,
    required double amount,
    required String paymentMethodType, // 'gcash' | 'maya'
    String? customerName,
    String? customerEmail,
    String? customerPhone,
    String? pickupAddress,
    String? dropoffAddress,
  });

  Future<GatewayPaymentResult> verifyPaymentStatus(String sessionId);

  Future<GatewayPaymentResult> refundPayment({
    required String paymentId,
    required double amount,
    String? reason,
  });

  Future<GatewayPaymentResult> cancelPaymentSession(String sessionId);

  Future<Map<String, dynamic>> createDisbursement({
    required String driverId,
    required double amount,
    required String recipientMobile,
    required String recipientName,
    required String method, // 'gcash' | 'maya'
  });

  Future<GatewayPaymentResult?> processWebhookEvent(
      Map<String, dynamic> payload);
}

/// Implementation of PayMongo & Maya Online Payment Gateway.
class PayMongoGatewayService implements OnlinePaymentGatewayInterface {
  PayMongoGatewayService({
    PaymentGatewayConfig? config,
    http.Client? httpClient,
    String? secretKey,
  })  : _config = config ?? PaymentGatewayConfig.instance,
        _client = httpClient ?? http.Client(),
        _secretKey = secretKey;

  final PaymentGatewayConfig _config;
  final http.Client _client;
  final String? _secretKey;

  // Cache of sessions actually returned by the provider.
  final Map<String, GatewayPaymentResult> _activeSessions = {};

  String get _authHeader {
    final secretKey = _secretKey ?? _config.paymongoSecretKey;
    if (secretKey.isEmpty) throw StateError('Online payments are unavailable.');
    final encoded = base64Encode(utf8.encode('$secretKey:'));
    return 'Basic $encoded';
  }

  /// Step 1: Creates an actual PayMongo / Maya Checkout Session via REST API.
  @override
  Future<GatewayPaymentResult> createCheckoutSession({
    required String tripId,
    required String passengerId,
    required double amount,
    required String paymentMethodType, // 'gcash' | 'maya'
    String? customerName,
    String? customerEmail,
    String? customerPhone,
    String? pickupAddress,
    String? dropoffAddress,
  }) async {
    final now = DateTime.now();
    final normalizedMethod = paymentMethodType.toLowerCase().trim();
    final providerCode =
        normalizedMethod.contains('maya') ? 'paymaya' : 'gcash';
    final providerPrefix = normalizedMethod.contains('maya') ? 'MAYA' : 'GCASH';

    // Generate unique official reference number (e.g. ST-GCASH-20260823-8821)
    final ref =
        'ST-$providerPrefix-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${1000 + Random().nextInt(9000)}';

    // Amount in centavos (PHP 150.00 = 15000)
    final amountCentavos = (amount * 100).round();

    final allowedMethodTypes = normalizedMethod.contains('maya')
        ? ['paymaya', 'gcash', 'card']
        : ['gcash', 'paymaya', 'card'];

    final description = pickupAddress != null && dropoffAddress != null
        ? 'Sakay Ta Ride: $pickupAddress to $dropoffAddress'
        : 'Sakay Ta Ride Booking #$tripId';

    final requestBody = {
      'data': {
        'attributes': {
          'billing': {
            if (customerName?.isNotEmpty == true) 'name': customerName,
            if (customerEmail?.isNotEmpty == true) 'email': customerEmail,
            if (customerPhone?.isNotEmpty == true) 'phone': customerPhone,
          },
          'send_email_receipt': false,
          'show_description': true,
          'show_line_items': true,
          'description': description,
          'line_items': [
            {
              'currency': PaymentGatewayConfig.currency,
              'amount': amountCentavos,
              'name': 'Sakay Ta Ride Fare',
              'quantity': 1,
              'description':
                  'Verified Philippine e-Wallet payment ($providerPrefix)',
            }
          ],
          'payment_method_types': allowedMethodTypes,
          'reference_number': ref,
          'success_url':
              '${PaymentGatewayConfig.paymentSuccessRedirectUrl}?session_id={CHECKOUT_SESSION_ID}&trip_id=$tripId&status=success',
          'cancel_url':
              '${PaymentGatewayConfig.paymentCancelRedirectUrl}?trip_id=$tripId&status=cancelled',
          'metadata': {
            'trip_id': tripId,
            'passenger_id': passengerId,
            'provider': providerCode,
            'source': 'sakay_ta_flutter',
          },
        }
      }
    };

    try {
      final response = await _client
          .post(
            Uri.parse('${_config.paymongoApiBaseUrl}/checkout_sessions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': _authHeader,
            },
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final data = decoded['data'] as Map<String, dynamic>;
        final id = data['id'] as String;
        final attributes = data['attributes'] as Map<String, dynamic>;
        final checkoutUrl = attributes['checkout_url'] as String?;
        if (checkoutUrl == null || checkoutUrl.isEmpty) {
          throw StateError(
              'The payment provider did not return a checkout URL.');
        }
        final status = attributes['status'] as String? ?? 'pending_payment';

        final result = GatewayPaymentResult(
          sessionId: id,
          status: status == 'paid' || status == 'succeeded'
              ? 'paid'
              : 'pending_payment',
          amount: amount,
          currency: 'PHP',
          paymentMethodType: providerCode,
          referenceNumber: ref,
          checkoutUrl: checkoutUrl,
          metadata: {
            'trip_id': tripId,
            'passenger_id': passengerId,
            'raw_status': status,
          },
        );

        _activeSessions[id] = result;
        return result;
      } else {
        debugPrint(
            'PayMongo API response (${response.statusCode}): ${response.body}');
        throw StateError('Unable to create checkout (${response.statusCode}).');
      }
    } catch (e) {
      debugPrint('PayMongo createCheckoutSession exception: $e');
      throw StateError(
          'Unable to create payment checkout. Please try again later.');
    }
  }

  /// Step 2: Verifies transaction status directly with the gateway API.
  @override
  Future<GatewayPaymentResult> verifyPaymentStatus(String sessionId) async {
    try {
      final response = await _client.get(
        Uri.parse('${_config.paymongoApiBaseUrl}/checkout_sessions/$sessionId'),
        headers: {
          'Authorization': _authHeader,
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final data = decoded['data'] as Map<String, dynamic>;
        final attributes = data['attributes'] as Map<String, dynamic>;
        final rawStatus =
            (attributes['status'] as String? ?? 'pending').toLowerCase();

        final payments = attributes['payments'] as List<dynamic>? ?? [];
        String? paymentId;
        DateTime? paidAt;
        String detectedMethod = 'gcash';

        if (payments.isNotEmpty) {
          final firstPayment = payments.first as Map<String, dynamic>;
          paymentId = firstPayment['id'] as String?;
          final pAttr = (firstPayment['attributes'] ?? firstPayment)
              as Map<String, dynamic>;
          final paidAtTimestamp = pAttr['paid_at'] as int?;
          if (paidAtTimestamp != null) {
            paidAt =
                DateTime.fromMillisecondsSinceEpoch(paidAtTimestamp * 1000);
          }
          final source = pAttr['source'] as Map<String, dynamic>?;
          if (source != null && source['type'] != null) {
            detectedMethod = source['type'] as String;
          }
        }

        final lineItems = attributes['line_items'] as List<dynamic>? ?? [];
        double amount = 0.0;
        if (lineItems.isNotEmpty) {
          final item = lineItems.first as Map<String, dynamic>;
          final centavos = (item['amount'] as num?)?.toDouble() ?? 0.0;
          amount = centavos / 100.0;
        }

        final ref = attributes['reference_number'] as String? ??
            'ST-PM-${DateTime.now().millisecondsSinceEpoch}';

        final isPaid = rawStatus == 'paid' ||
            rawStatus == 'succeeded' ||
            payments.any((payment) {
              final item = payment as Map<String, dynamic>;
              final attributes =
                  (item['attributes'] ?? item) as Map<String, dynamic>;
              return attributes['status'] == 'paid' ||
                  attributes['status'] == 'succeeded';
            });

        final result = GatewayPaymentResult(
          sessionId: sessionId,
          paymentId: paymentId,
          status: isPaid
              ? 'paid'
              : (rawStatus == 'cancelled' ? 'cancelled' : 'pending_payment'),
          amount:
              amount > 0 ? amount : (_activeSessions[sessionId]?.amount ?? 0.0),
          currency: 'PHP',
          paymentMethodType: detectedMethod,
          referenceNumber: ref,
          checkoutUrl: attributes['checkout_url'] as String?,
          paidAt: paidAt,
          metadata: attributes['metadata'] as Map<String, dynamic>?,
        );

        _activeSessions[sessionId] = result;
        return result;
      }
    } catch (e) {
      debugPrint('PayMongo verifyPaymentStatus error: $e');
    }

    throw StateError('Unable to verify payment with the provider.');
  }

  /// Dispatches refund request to PayMongo API (/v1/refunds)
  @override
  Future<GatewayPaymentResult> refundPayment({
    required String paymentId,
    required double amount,
    String? reason,
  }) async {
    final centavos = (amount * 100).round();
    final url = Uri.parse('${_config.paymongoApiBaseUrl}/refunds');

    try {
      final response = await _client.post(
        url,
        headers: {
          'Authorization': _authHeader,
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'data': {
            'attributes': {
              'amount': centavos,
              'payment_id': paymentId,
              'reason': reason ?? 'requested_by_customer',
              'notes': 'Refund for Sakay Ta ride cancellation',
            },
          },
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final data = body['data'] as Map<String, dynamic>;
        final attributes = data['attributes'] as Map<String, dynamic>;
        final refundStatus = attributes['status'] as String? ?? 'processing';

        return GatewayPaymentResult(
          sessionId: paymentId,
          paymentId: data['id'] as String?,
          status: refundStatus == 'succeeded' ? 'refunded' : refundStatus,
          amount: amount,
          currency: (attributes['currency'] as String? ?? 'PHP').toUpperCase(),
          paymentMethodType: 'gcash',
          referenceNumber: 'REF-$paymentId',
          paidAt: DateTime.now(),
        );
      }
    } catch (e) {
      debugPrint('PayMongo refundPayment error: $e');
    }

    throw StateError('Refund was not confirmed by the payment provider.');
  }

  /// Cancels an in-flight checkout session / payment request
  @override
  Future<GatewayPaymentResult> cancelPaymentSession(String sessionId) async {
    try {
      final url = Uri.parse(
          '${_config.paymongoApiBaseUrl}/checkout_sessions/$sessionId/expire');
      final response = await _client.post(
        url,
        headers: {
          'Authorization': _authHeader,
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('The provider did not cancel this checkout.');
      }
    } catch (e) {
      throw StateError('Unable to cancel checkout with the provider.');
    }

    if (_activeSessions.containsKey(sessionId)) {
      final prev = _activeSessions[sessionId]!;
      final updated = GatewayPaymentResult(
        sessionId: sessionId,
        paymentId: prev.paymentId,
        status: 'cancelled',
        amount: prev.amount,
        currency: prev.currency,
        paymentMethodType: prev.paymentMethodType,
        referenceNumber: prev.referenceNumber,
        checkoutUrl: prev.checkoutUrl,
        metadata: prev.metadata,
      );
      _activeSessions[sessionId] = updated;
      return updated;
    }

    return GatewayPaymentResult(
      sessionId: sessionId,
      status: 'cancelled',
      amount: 0,
      currency: 'PHP',
      paymentMethodType: 'gcash',
      referenceNumber: 'CANCELLED',
    );
  }

  /// Securely handles and parses incoming webhook events from PayMongo / Maya.
  @override
  Future<GatewayPaymentResult?> processWebhookEvent(
      Map<String, dynamic> payload) async {
    try {
      final data = payload['data'] as Map<String, dynamic>?;
      if (data == null) return null;

      final attributes = data['attributes'] as Map<String, dynamic>?;
      if (attributes == null) return null;

      final type = attributes['type'] as String? ?? '';
      final eventData = attributes['data'] as Map<String, dynamic>? ?? {};
      final eventAttr = eventData['attributes'] as Map<String, dynamic>? ?? {};

      final status = switch (type) {
        'checkout_session.payment.paid' => 'paid',
        'payment.paid' => 'paid',
        'payment.failed' => 'failed',
        'payment.refunded' => 'refunded',
        _ => eventAttr['status'] as String? ?? 'pending_payment',
      };

      final amount = ((eventAttr['amount'] as num?)?.toDouble() ?? 0.0) / 100.0;
      final currency =
          (eventAttr['currency'] as String? ?? 'PHP').toUpperCase();
      final ref = eventAttr['reference_number'] as String? ??
          eventData['id'] as String? ??
          'ST-WEBHOOK';

      return GatewayPaymentResult(
        sessionId: eventData['id'] as String? ?? '',
        paymentId: eventData['id'] as String?,
        status: status,
        amount: amount,
        currency: currency,
        paymentMethodType: 'gcash',
        referenceNumber: ref,
        paidAt: DateTime.now(),
        metadata: eventAttr['metadata'] as Map<String, dynamic>?,
      );
    } catch (e) {
      debugPrint('PayMongo processWebhookEvent error: $e');
      return null;
    }
  }

  /// Payouts must be confirmed by a connected disbursement provider.
  @override
  Future<Map<String, dynamic>> createDisbursement({
    required String driverId,
    required double amount,
    required String recipientMobile,
    required String recipientName,
    required String method,
  }) async =>
      throw StateError(
          'Payout provider unavailable. No funds have been disbursed.');
}
