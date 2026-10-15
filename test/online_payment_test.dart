import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sakay_ta/services/online_payment_gateway.dart';
import 'package:sakay_ta/services/payment_webhook_handler.dart';

void main() {
  Future<GatewayPaymentResult> checkout(PayMongoGatewayService gateway) =>
      gateway.createCheckoutSession(
          tripId: 'ride-1',
          passengerId: 'passenger-1',
          amount: 100,
          paymentMethodType: 'gcash');

  test('Checkout uses the actual provider session and URL', () async {
    final gateway = PayMongoGatewayService(
        secretKey: 'test-key',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/v1/checkout_sessions');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final billing = body['data']['attributes']['billing'] as Map;
          expect(billing, isEmpty);
          return http.Response(
              jsonEncode({
                'data': {
                  'id': 'cs_provider_1',
                  'attributes': {
                    'checkout_url': 'https://provider.example/checkout/1',
                    'status': 'pending_payment',
                  }
                }
              }),
              201);
        }));
    final result = await checkout(gateway);
    expect(result.sessionId, 'cs_provider_1');
    expect(result.checkoutUrl, 'https://provider.example/checkout/1');
    expect(result.isPaid, isFalse);
  });

  test(
      'Provider failures never create fake checkout, refund, cancellation or payout results',
      () async {
    final gateway = PayMongoGatewayService(
        secretKey: 'test-key',
        httpClient: MockClient((_) async => http.Response('{}', 503)));
    await expectLater(checkout(gateway), throwsStateError);
    await expectLater(
        gateway.verifyPaymentStatus('cs_unknown'), throwsStateError);
    await expectLater(gateway.refundPayment(paymentId: 'pay_1', amount: 100),
        throwsStateError);
    await expectLater(gateway.cancelPaymentSession('cs_1'), throwsStateError);
    await expectLater(
        gateway.createDisbursement(
            driverId: 'driver-1',
            amount: 100,
            recipientMobile: '09170000000',
            recipientName: 'Driver',
            method: 'gcash'),
        throwsStateError);
  });

  test('A missing checkout URL is an error', () async {
    final gateway = PayMongoGatewayService(
        secretKey: 'test-key',
        httpClient: MockClient((_) async => http.Response(
            jsonEncode({
              'data': {
                'id': 'cs_provider_1',
                'attributes': {'status': 'pending_payment'}
              }
            }),
            201)));
    await expectLater(checkout(gateway), throwsStateError);
  });

  test(
      'A provider response confirms payment, while a later failed verification stays an error',
      () async {
    var unavailable = false;
    final gateway = PayMongoGatewayService(
        secretKey: 'test-key',
        httpClient: MockClient((_) async {
          if (unavailable) return http.Response('{}', 503);
          return http.Response(
              jsonEncode({
                'data': {
                  'id': 'cs_1',
                  'attributes': {
                    'status': 'paid',
                    'reference_number': 'provider-ref',
                    'line_items': [
                      {'amount': 10000}
                    ],
                    'payments': [
                      {
                        'id': 'pay_provider_1',
                        'attributes': {
                          'paid_at': 1789280000,
                          'source': {'type': 'gcash'}
                        }
                      }
                    ],
                  }
                }
              }),
              200);
        }));
    final result = await gateway.verifyPaymentStatus('cs_1');
    expect(result.isPaid, isTrue);
    expect(result.paymentId, 'pay_provider_1');
    expect(result.amount, 100);
    unavailable = true;
    await expectLater(gateway.verifyPaymentStatus('cs_1'), throwsStateError);
  });

  test('Unsigned webhooks cannot claim successful payment', () async {
    final handler = PaymentWebhookHandler();
    expect(
        await handler.handleIncomingWebhook({
          'data': {
            'attributes': {'type': 'payment.paid'}
          }
        }),
        isFalse);
  });
}
