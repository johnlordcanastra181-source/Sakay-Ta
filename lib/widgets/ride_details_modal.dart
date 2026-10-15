import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../state/app_state.dart';

class RideDetailsModal extends StatelessWidget {
  const RideDetailsModal({
    super.key,
    required this.entry,
    this.onRateTrip,
  });

  final RideEntry entry;
  final VoidCallback? onRateTrip;

  static Future<void> show(
    BuildContext context, {
    required RideEntry entry,
    VoidCallback? onRateTrip,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RideDetailsModal(
        entry: entry,
        onRateTrip: onRateTrip,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trip = entry.trip;
    final isCompleted = trip.status == RideStatus.completed;
    final dateFormatted = DateFormat('MMM dd, yyyy • hh:mm a')
        .format(trip.completedAt ?? trip.createdAt);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Trip Receipt & Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E1E1E),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Receipt: ST-${trip.id.substring(0, trip.id.length > 8 ? 8 : trip.id.length).toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Driver & Vehicle Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.terracotta.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      trip.vehicleType.icon,
                      color: AppColors.terracotta,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.driverName.isNotEmpty
                              ? entry.driverName
                              : 'Driver Assignment Pending',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E1E1E),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${trip.vehicleType == VehicleType.tricycle ? "Tricycle" : "Motorcycle (Habal)"} • ${entry.plateNumber.isNotEmpty ? entry.plateNumber : "Plate not assigned"}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? const Color(0xFFECFDF5)
                          : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      trip.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isCompleted
                            ? const Color(0xFF059669)
                            : const Color(0xFFD97706),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Route details
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    const Icon(Icons.circle,
                        color: Color(0xFF059669), size: 14),
                    Container(
                        width: 2, height: 38, color: Colors.grey.shade300),
                    const Icon(Icons.location_on,
                        color: Color(0xFFDC2626), size: 18),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PICKUP',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                      Text(
                        trip.pickupAddress,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E1E1E),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'DROP-OFF',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                      Text(
                        trip.dropoffAddress,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E1E1E),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Trip metrics stats row
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _metricItem(
                    label: 'Distance',
                    value: '${trip.distanceKm.toStringAsFixed(1)} km',
                    icon: Icons.straighten_rounded,
                  ),
                  Container(width: 1, height: 28, color: Colors.grey.shade300),
                  _metricItem(
                    label: 'Duration',
                    value: '${trip.durationMin} mins',
                    icon: Icons.timer_outlined,
                  ),
                  Container(width: 1, height: 28, color: Colors.grey.shade300),
                  _metricItem(
                    label: 'Date',
                    value: DateFormat('MM/dd/yy').format(trip.createdAt),
                    icon: Icons.calendar_today_rounded,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Fare & Payment Breakdown
            const Text(
              'Payment Summary',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E1E1E),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE5E7EB)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  _receiptRow(
                    'Base Fare (${trip.vehicleType == VehicleType.tricycle ? "Tricycle" : "Habal"})',
                    '₱${trip.vehicleType.baseFare.toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 6),
                  _receiptRow(
                    'Distance Charge (${trip.distanceKm.toStringAsFixed(1)} km)',
                    '₱${(trip.fare - trip.vehicleType.baseFare).clamp(0, double.infinity).toStringAsFixed(2)}',
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(height: 1),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Amount Paid',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E1E1E),
                        ),
                      ),
                      Text(
                        '₱${trip.fare.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Paid via ${trip.paymentMethod.toUpperCase()}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4F46E5),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        dateFormatted,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Rating Stars
            if (trip.rating != null) ...[
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    5,
                    (i) => Icon(
                      i < trip.rating!
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: const Color(0xFFF59E0B),
                      size: 26,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ] else if (isCompleted && onRateTrip != null) ...[
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  onRateTrip!();
                },
                icon: const Icon(Icons.star_rounded),
                label: const Text('Rate this Trip'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metricItem({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF6B7280)),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E1E1E),
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  Widget _receiptRow(String title, String amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
        ),
        Text(
          amount,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E1E1E),
          ),
        ),
      ],
    );
  }
}
