import 'package:flutter/foundation.dart';

/// Configuration and credentials for Philippine Payment Gateways (PayMongo & Maya).
///
/// Supports Sandbox (Test Mode) and Live (Production Mode) credentials.
/// Credentials can be overridden at runtime or compiled with `--dart-define` flags:
/// - `--dart-define=PAYMONGO_SECRET_KEY=sk_live_...`
/// - `--dart-define=PAYMONGO_PUBLIC_KEY=pk_live_...`
/// - `--dart-define=PAYMENT_GATEWAY_ENV=production`
enum PaymentGatewayEnvironment {
  sandbox,
  production,
}

class PaymentGatewayConfig {
  PaymentGatewayConfig._();
  static final PaymentGatewayConfig instance = PaymentGatewayConfig._();

  /// Default environment mode. Defaults to sandbox during development.
  PaymentGatewayEnvironment _environment = const String.fromEnvironment(
              'PAYMENT_GATEWAY_ENV',
              defaultValue: 'production') ==
          'production'
      ? PaymentGatewayEnvironment.production
      : PaymentGatewayEnvironment.sandbox;

  PaymentGatewayEnvironment get environment => _environment;
  bool get isSandbox => _environment == PaymentGatewayEnvironment.sandbox;
  bool get isProduction => _environment == PaymentGatewayEnvironment.production;

  /// Allows toggling between Sandbox and Production dynamically (e.g. from Admin Settings)
  void setEnvironment(PaymentGatewayEnvironment env) {
    _environment = env;
    debugPrint(
        'PaymentGatewayConfig: environment switched to ${env.name.toUpperCase()}');
  }

  // --- PayMongo Credentials & Endpoints ---
  String get paymongoPublicKey =>
      const String.fromEnvironment('PAYMONGO_PUBLIC_KEY');
  String get paymongoSecretKey =>
      const String.fromEnvironment('PAYMONGO_SECRET_KEY');
  String get paymongoWebhookSecret =>
      const String.fromEnvironment('PAYMONGO_WEBHOOK_SECRET');

  String get paymongoApiBaseUrl => 'https://api.paymongo.com/v1';

  // --- Maya (PayMaya) Direct Gateway Credentials & Endpoints ---
  String get mayaPublicKey => const String.fromEnvironment('MAYA_PUBLIC_KEY');
  String get mayaSecretKey => const String.fromEnvironment('MAYA_SECRET_KEY');

  String get mayaApiBaseUrl => isSandbox
      ? 'https://pg-sandbox.paymaya.com/checkout/v1'
      : 'https://pg.paymaya.com/checkout/v1';

  // --- App Return URLs & Deep Link Callbacks ---
  static const String appScheme = 'sakayta';
  static const String paymentSuccessRedirectUrl =
      'https://sakay-ta.web.app/payment-success.html';
  static const String paymentCancelRedirectUrl =
      'https://sakay-ta.web.app/payment-cancelled.html';

  static const String currency = 'PHP';
  static const String merchantName = 'Sakay Ta Philippines';
}
