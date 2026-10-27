import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../models/trip.dart';
import '../services/fare_calculator.dart';
import '../services/online_payment_gateway.dart';
import '../services/payment_service.dart';
import '../state/app_state.dart';

/// Interactive modal for real-time GCash and Maya payments.
class OnlineCheckoutModal extends StatefulWidget {
  const OnlineCheckoutModal({
    super.key,
    required this.trip,
    this.onPaymentSuccess,
  });

  final Trip trip;
  final VoidCallback? onPaymentSuccess;

  static Future<bool?> show(
    BuildContext context, {
    required Trip trip,
    VoidCallback? onPaymentSuccess,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => OnlineCheckoutModal(
        trip: trip,
        onPaymentSuccess: onPaymentSuccess,
      ),
    );
  }

  @override
  State<OnlineCheckoutModal> createState() => _OnlineCheckoutModalState();
}

class _OnlineCheckoutModalState extends State<OnlineCheckoutModal> {
  final PaymentService _paymentService = PaymentService.instance;

  bool _isInitiating = true;
  bool _isVerifying = false;
  bool _isPaid = false;
  String? _errorMessage;
  GatewayPaymentResult? _sessionResult;
  StreamSubscription<GatewayPaymentResult>? _pollSub;

  @override
  void initState() {
    super.initState();
    _startCheckoutFlow();
  }

  @override
  void dispose() {
    _pollSub?.cancel();
    super.dispose();
  }

  Future<void> _startCheckoutFlow() async {
    setState(() {
      _isInitiating = true;
      _errorMessage = null;
    });

    try {
      final app = context.read<AppState>();
      final result = await app.initiateTripOnlinePayment(trip: widget.trip);

      if (!mounted) return;

      setState(() {
        _sessionResult = result;
        _isInitiating = false;
      });

      if (result.isPaid) {
        _handleSuccess(result);
        return;
      }

      // Automatically launch checkout URL
      if (result.checkoutUrl != null) {
        _launchCheckoutUrl(result.checkoutUrl!);
      }

      // Start real-time background status verification listener
      _startStatusPolling(result.sessionId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isInitiating = false;
        _errorMessage =
            'Unable to initialize online payment session. Please try again.';
      });
    }
  }

  Future<void> _launchCheckoutUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not launch payment URL: $e');
    }
  }

  void _startStatusPolling(String sessionId) {
    _pollSub?.cancel();

    final app = context.read<AppState>();
    final passengerId = app.currentUser?.id ?? widget.trip.passengerId;
    final driverId = widget.trip.driverId ?? '';

    _pollSub = _paymentService
        .pollPaymentVerification(
      sessionId: sessionId,
      tripId: widget.trip.id,
      passengerId: passengerId,
      driverId: driverId,
      fare: widget.trip.fare,
      commission: 0,
      net: widget.trip.fare,
      method: widget.trip.paymentMethod,
    )
        .listen((result) {
      if (!mounted) return;

      setState(() {
        _sessionResult = result;
      });

      if (result.isPaid) {
        _handleSuccess(result);
      } else if (result.isFailed) {
        setState(() {
          _errorMessage = 'Payment was cancelled or expired. Please try again.';
        });
      }
    });
  }

  Future<void> _manualCheckStatus() async {
    if (_sessionResult == null) return;

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final app = context.read<AppState>();
      final result = await app.verifyAndSettleTripOnlinePayment(
        sessionId: _sessionResult!.sessionId,
        trip: widget.trip,
      );

      if (!mounted) return;

      setState(() {
        _sessionResult = result;
        _isVerifying = false;
      });

      if (result.isPaid) {
        _handleSuccess(result);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Payment not completed yet. Please complete payment in GCash / Maya.'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _errorMessage = 'Verification error. Please check your connection.';
      });
    }
  }

  void _handleSuccess(GatewayPaymentResult result) {
    _pollSub?.cancel();
    setState(() {
      _isPaid = true;
    });
    widget.onPaymentSuccess?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isGcash =
        widget.trip.paymentMethod.toLowerCase() == PaymentMethod.gcash;
    final isMaya =
        widget.trip.paymentMethod.toLowerCase() == PaymentMethod.maya;
    final providerTitle =
        isGcash ? 'GCash' : (isMaya ? 'Maya' : 'Online Payment');
    final primaryColor = isGcash
        ? const Color(0xFF0066FF)
        : (isMaya ? const Color(0xFF00C389) : const Color(0xFF6E5600));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardColor(isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppColors.borderColor(isDark)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _buildProviderBadge(isGcash, isMaya),
                  const SizedBox(width: 10),
                  Text(
                    '$providerTitle Payment',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textColor(isDark),
                    ),
                  ),
                ],
              ),
              if (!_isPaid)
                IconButton(
                  icon: Icon(Icons.close_rounded,
                      color: AppColors.textColor(isDark)),
                  onPressed: () => Navigator.pop(context, false),
                ),
            ],
          ),
          const SizedBox(height: 16),

          if (_isPaid)
            _buildSuccessReceipt(primaryColor, isDark)
          else if (_isInitiating)
            _buildLoadingView(providerTitle, primaryColor, isDark)
          else if (_errorMessage != null)
            _buildErrorView(primaryColor)
          else
            _buildPendingCheckoutView(providerTitle, primaryColor, isDark),

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildProviderBadge(bool isGcash, bool isMaya) {
    if (isGcash) {
      return Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: Color(0xFF0066FF),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Text('G',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16)),
        ),
      );
    }
    if (isMaya) {
      return Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: Color(0xFF00C389),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Text('M',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16)),
        ),
      );
    }
    return const Icon(Icons.payment_rounded,
        color: Color(0xFF6E5600), size: 28);
  }

  Widget _buildLoadingView(String provider, Color primaryColor, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          CircularProgressIndicator(color: primaryColor),
          const SizedBox(height: 16),
          Text(
            'Connecting to $provider Gateway...',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textColor(isDark),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Creating secure payment session',
            style:
                TextStyle(fontSize: 12, color: AppColors.subtextColor(isDark)),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingCheckoutView(
      String provider, Color primaryColor, bool isDark) {
    final ref = _sessionResult?.referenceNumber ?? 'ST-${widget.trip.id}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Amount Summary Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardElevatedColor(isDark),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderColor(isDark)),
          ),
          child: Column(
            children: [
              Text(
                'AMOUNT TO PAY',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.subtextColor(isDark),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                FareCalculator.formatFare(widget.trip.fare),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textColor(isDark),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.goldVibrant.withValues(alpha: 0.15)
                      : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Ref: $ref',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.goldVibrant
                        : const Color(0xFF92400E),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Live Status Pulse Bar
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1E3A8A).withValues(alpha: 0.25)
                : const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF3B82F6).withValues(alpha: 0.3)
                  : const Color(0xFFBFDBFE),
            ),
          ),
          child: Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Waiting for $provider payment confirmation...',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? const Color(0xFF93C5FD)
                        : const Color(0xFF1E40AF),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Action Buttons
        if (_sessionResult?.checkoutUrl != null)
          SizedBox(
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => _launchCheckoutUrl(_sessionResult!.checkoutUrl!),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.open_in_browser_rounded, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Open $provider Checkout',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 10),

        SizedBox(
          height: 44,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: primaryColor),
              foregroundColor: primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _isVerifying ? null : _manualCheckStatus,
            child: _isVerifying
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.refresh_rounded, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'I have paid / Check Status',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessReceipt(Color primaryColor, bool isDark) {
    final ref = _sessionResult?.referenceNumber ??
        'ST-${DateTime.now().millisecondsSinceEpoch}';
    final dateStr = DateFormat('MMM dd, yyyy • hh:mm a').format(DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Success Icon
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.emeraldVibrant.withValues(alpha: 0.2)
                  : const Color(0xFFDCFCE7),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_rounded,
              color:
                  isDark ? AppColors.emeraldVibrant : const Color(0xFF16A34A),
              size: 48,
            ),
          ),
        ),
        const SizedBox(height: 14),

        Text(
          'Payment Confirmed!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: AppColors.textColor(isDark),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Verified via ${_sessionResult?.paymentMethodType.toUpperCase() ?? "ONLINE GATEWAY"}',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.emeraldVibrant : const Color(0xFF16A34A),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),

        // Receipt Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardElevatedColor(isDark),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderColor(isDark)),
          ),
          child: Column(
            children: [
              _buildReceiptRow('Reference No.', ref,
                  isBold: true, isDark: isDark),
              Divider(height: 16, color: AppColors.borderColor(isDark)),
              _buildReceiptRow('Date & Time', dateStr, isDark: isDark),
              Divider(height: 16, color: AppColors.borderColor(isDark)),
              _buildReceiptRow('Pickup', widget.trip.pickupAddress,
                  isDark: isDark),
              Divider(height: 16, color: AppColors.borderColor(isDark)),
              _buildReceiptRow('Dropoff', widget.trip.dropoffAddress,
                  isDark: isDark),
              Divider(height: 16, color: AppColors.borderColor(isDark)),
              _buildReceiptRow(
                'Total Paid',
                FareCalculator.formatFare(widget.trip.fare),
                valueColor:
                    isDark ? AppColors.emeraldVibrant : const Color(0xFF16A34A),
                isBold: true,
                fontSize: 16,
                isDark: isDark,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        SizedBox(
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isDark ? AppColors.emeraldVibrant : const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Done',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptRow(
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
    double fontSize = 12.5,
    required bool isDark,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.subtextColor(isDark),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: valueColor ?? AppColors.textColor(isDark),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorView(Color primaryColor) {
    return Column(
      children: [
        const Icon(Icons.error_outline_rounded,
            color: Color(0xFFDC2626), size: 42),
        const SizedBox(height: 12),
        Text(
          _errorMessage ?? 'Payment failed.',
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 14,
              color: Color(0xFFDC2626),
              fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: _startCheckoutFlow,
                child: const Text('Retry Payment'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
