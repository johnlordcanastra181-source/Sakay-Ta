import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../models/payment_method_model.dart';
import '../services/driver_matching_service.dart';
import '../services/payment_service.dart';

class BookingConfirmationModal extends StatefulWidget {
  const BookingConfirmationModal({
    super.key,
    required this.driver,
    required this.pickupAddress,
    required this.destination,
    required this.distanceKm,
    required this.durationMins,
    required this.fare,
    required this.onConfirm,
  });

  final NearbyDriver driver;
  final String pickupAddress;
  final Place destination;
  final double distanceKm;
  final int durationMins;
  final double fare;
  final Future<bool> Function() onConfirm;

  @override
  State<BookingConfirmationModal> createState() =>
      _BookingConfirmationModalState();
}

class _BookingConfirmationModalState extends State<BookingConfirmationModal> {
  final PaymentService _paymentService = PaymentService.instance;
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final isTricycle = widget.driver.vehicleType == VehicleType.tricycle;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Confirm Ride Booking',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E1E1E),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Driver Profile Card Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFD600),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_rounded,
                      color: Color(0xFF1E1E1E), size: 32),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.driver.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E1E1E),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${isTricycle ? "Standard Tricycle" : "Motorcycle (Habal-Habal)"} · ${widget.driver.plateNumber}',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded,
                              color: Color(0xFFD97706), size: 16),
                          const SizedBox(width: 2),
                          Text(
                            '${widget.driver.rating.toStringAsFixed(1)} (${widget.driver.completedTrips} rides)',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${widget.driver.acceptanceRate}% match',
                            style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF059669),
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Trip Route Details
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  const Icon(Icons.location_on_rounded,
                      color: Color(0xFF6E5600), size: 18),
                  Container(
                      width: 2, height: 28, color: const Color(0xFFD8D8D8)),
                  const Icon(Icons.location_on_rounded,
                      color: Color(0xFFDC2626), size: 18),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('PICKUP LOCATION',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF808080))),
                    const SizedBox(height: 2),
                    Text(widget.pickupAddress,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E1E1E))),
                    const SizedBox(height: 14),
                    const Text('DESTINATION',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF808080))),
                    const SizedBox(height: 2),
                    Text(widget.destination.name,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E1E1E))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Payment Method Selector
          ListenableBuilder(
            listenable: _paymentService,
            builder: (ctx, _) {
              final currentMethod = _paymentService.defaultMethod;
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    _buildPaymentIcon(currentMethod),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PAYMENT METHOD',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          Text(
                            '${currentMethod.title} • ${currentMethod.accountIdentifier}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E1E1E),
                            ),
                          ),
                        ],
                      ),
                    ),

                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 18),

          // Fare Summary & Action Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('TOTAL FARE',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF808080))),
                  const SizedBox(height: 2),
                  Text(
                    '₱${widget.fare.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1E1E1E),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6E5600),
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _isSubmitting
                          ? null
                          : () async {
                              setState(() => _isSubmitting = true);
                              final confirmed = await widget.onConfirm();
                              if (!mounted) return;
                              Navigator.pop(context, confirmed);
                            },
                      child: Text(
                        _isSubmitting
                            ? 'Booking...'
                            : _paymentService.defaultMethod.isGcash
                                ? 'Book with GCash'
                                : (_paymentService.defaultMethod.isMaya
                                    ? 'Book with Maya'
                                    : 'Confirm Booking'),
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentIcon(PassengerPaymentMethod m) {
    if (m.isGcash) {
      return Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(
          color: Color(0xFF0066FF),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Text('G',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14)),
        ),
      );
    }
    if (m.isMaya) {
      return Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(
          color: Color(0xFF00C389),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Text('M',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14)),
        ),
      );
    }
    return const Icon(Icons.payments_rounded,
        size: 24, color: Color(0xFF059669));
  }
}


