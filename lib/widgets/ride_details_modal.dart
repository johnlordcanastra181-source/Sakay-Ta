import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../services/fare_calculator.dart';
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
    debugPrint('[SakayTa][Perf][Receipt] open rideId=${entry.trip.id} '
        'source=preloaded_entry durationMs=0');
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

  static Future<void> showForWalletEntry(
    BuildContext context, {
    required WalletEntry walletEntry,
    required AppState app,
  }) {
    final rideId = walletEntry.rideId?.trim() ?? '';
    if (rideId.isNotEmpty) {
      final cached = app.getCachedRideEntryById(rideId);
      if (cached != null) {
        return show(context, entry: cached);
      }
    }
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _WalletEntryReceiptSheet(
        walletEntry: walletEntry,
        app: app,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trip = entry.trip;
    final isCompleted = trip.status == RideStatus.completed;
    final dateFormatted = DateFormat('MMM dd, yyyy • hh:mm a')
        .format(trip.completedAt ?? trip.createdAt);
    final driverDisplay = entry.driverName.isNotEmpty
        ? entry.driverName
        : (isCompleted || (trip.driverId?.trim().isNotEmpty ?? false)
            ? 'Assigned Driver'
            : 'Driver Assignment Pending');
    final passengerDisplay =
        trip.passengerName.trim().isNotEmpty ? trip.passengerName.trim() : null;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardColor(isDark),
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
                          driverDisplay,
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
                        if (passengerDisplay != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Passenger: $passengerDisplay',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
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
                    'Minimum Fare (${trip.vehicleType == VehicleType.tricycle ? "Tricycle" : "Habal"})',
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
                        FareCalculator.formatFare(trip.fare),
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

class _WalletEntryReceiptSheet extends StatefulWidget {
  const _WalletEntryReceiptSheet({
    required this.walletEntry,
    required this.app,
  });

  final WalletEntry walletEntry;
  final AppState app;

  @override
  State<_WalletEntryReceiptSheet> createState() =>
      _WalletEntryReceiptSheetState();
}

class _WalletEntryReceiptSheetState extends State<_WalletEntryReceiptSheet> {
  Future<RideEntry?>? _rideEntryFuture;

  @override
  void initState() {
    super.initState();
    final rideId = widget.walletEntry.rideId?.trim() ?? '';
    if (rideId.isNotEmpty) {
      _rideEntryFuture = widget.app.getOrFetchRideEntryById(rideId);
    }
  }

  @override
  Widget build(BuildContext context) {

    final entry = widget.walletEntry;
    if (_rideEntryFuture != null) {
      return FutureBuilder<RideEntry?>(
        future: _rideEntryFuture,
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            return RideDetailsModal(entry: snapshot.data!);
          }
          return _buildImmediateWalletReceipt(
            context,
            entry,
            isLoadingTrip: snapshot.connectionState == ConnectionState.waiting,
          );
        },
      );
    }
    return _buildImmediateWalletReceipt(
      context,
      entry,
      isLoadingTrip: false,
    );
  }

  Widget _buildImmediateWalletReceipt(
    BuildContext context,
    WalletEntry entry, {
    required bool isLoadingTrip,
  }) {

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formatter = NumberFormat('#,##0.00', 'en_US');
    final dateFormatted =
        DateFormat('MMM dd, yyyy • hh:mm a').format(entry.createdAt);
    final isIncome = entry.type == 'income';
    final statusText = (entry.status ?? 'Completed').toUpperCase();
    final refCode = (entry.rideId ?? entry.reference ?? entry.id);
    final shortRef =
        refCode.substring(0, refCode.length > 8 ? 8 : refCode.length).toUpperCase();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardColor(isDark),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isIncome ? 'Trip Receipt & Details' : 'Transaction Receipt',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E1E1E),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Receipt: ST-$shortRef',
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
                      isIncome
                          ? Icons.payments_rounded
                          : Icons.account_balance_wallet_rounded,
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
                          entry.description,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E1E1E),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dateFormatted,
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
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusText,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (isLoadingTrip) ...[
              const SizedBox(height: 14),
              const LinearProgressIndicator(minHeight: 2),
            ],
            const SizedBox(height: 18),
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
                  if (entry.rideId != null && entry.rideId!.isNotEmpty) ...[
                    _kvRow('Ride Reference', entry.rideId!),
                    const SizedBox(height: 6),
                  ],
                  _kvRow('Payment Method', entry.method.toUpperCase()),
                  if (entry.grossFare != null) ...[
                    const SizedBox(height: 6),
                    _kvRow(
                      'Gross Fare',
                      '₱${formatter.format(entry.grossFare!)}',
                    ),
                  ],
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(height: 1),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isIncome ? 'Total Amount' : 'Withdrawal Amount',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E1E1E),
                        ),
                      ),
                      Text(
                        '${entry.amount >= 0 ? "+" : "-"}₱${formatter.format(entry.amount.abs())}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kvRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E1E1E),
            ),
          ),
        ),
      ],
    );
  }
}
