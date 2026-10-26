import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../services/driver_matching_service.dart';
import 'user_avatar.dart';

class DriverMatchingBottomSheet extends StatelessWidget {
  const DriverMatchingBottomSheet({
    super.key,
    this.scrollController,
    required this.nearbyDrivers,
    required this.selectedDriver,
    required this.searchRadiusKm,
    required this.selectedVehicle,
    required this.routeDistanceKm,
    required this.routeDurationMins,
    required this.tricycleFare,
    required this.habalFare,
    required this.onSelectDriver,
    required this.onSelectVehicle,
    required this.onUpdateRadius,
    required this.onConfirmBooking,
    this.onToggleExpand,
  });

  final ScrollController? scrollController;
  final List<NearbyDriver> nearbyDrivers;
  final NearbyDriver? selectedDriver;
  final double searchRadiusKm;
  final VehicleType selectedVehicle;
  final double routeDistanceKm;
  final int routeDurationMins;
  final double tricycleFare;
  final double habalFare;

  final Function(NearbyDriver) onSelectDriver;
  final Function(VehicleType) onSelectVehicle;
  final Function(double) onUpdateRadius;
  final VoidCallback onConfirmBooking;
  final VoidCallback? onToggleExpand;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final top5Drivers = nearbyDrivers.take(5).toList();
    final currentFare =
        selectedVehicle == VehicleType.tricycle ? tricycleFare : habalFare;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardColor(isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.1),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        controller: scrollController,
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle drag indicator (with tap to expand/collapse)
            Center(
              child: GestureDetector(
                onTap: onToggleExpand,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 24),
                  child: Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF475569)
                          : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Vehicle Selection Tabs & Search Radius Control Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Vehicle Tabs (Tricycle vs Motor)
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildVehicleTab(
                          context,
                          type: VehicleType.tricycle,
                          title: 'Tricycle',
                          subtitle: '3-4 pax',
                          fare: tricycleFare,
                          isSelected: selectedVehicle == VehicleType.tricycle,
                        ),
                        const SizedBox(width: 10),
                        _buildVehicleTab(
                          context,
                          type: VehicleType.habal,
                          title: 'Motor',
                          subtitle: '1 pax',
                          fare: habalFare,
                          isSelected: selectedVehicle == VehicleType.habal,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Radius Pill Button (5km / 10km / 15km)
                PopupMenuButton<double>(
                  initialValue: searchRadiusKm,
                  onSelected: onUpdateRadius,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkCardElevated
                          : const Color(0xFFF2F4F7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderColor(isDark)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.radar_rounded,
                            size: 14,
                            color: isDark
                                ? AppColors.gold
                                : const Color(0xFF6E5600)),
                        const SizedBox(width: 4),
                        Text(
                          '${searchRadiusKm.toInt()} km ▾',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.gold
                                : const Color(0xFF6E5600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                        value: 5.0, child: Text('5 km radius (Default)')),
                    PopupMenuItem(value: 10.0, child: Text('10 km radius')),
                    PopupMenuItem(value: 15.0, child: Text('15 km radius')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Section Header: Top Nearest Drivers
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Top Nearest Drivers (${top5Drivers.length})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textColor(isDark),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    routeDistanceKm > 0
                        ? '${routeDistanceKm.toStringAsFixed(1)} km · $routeDurationMins mins'
                        : '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.subtextColor(isDark),
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Top 5 Nearest Drivers List or No Drivers Friendly Card
            if (top5Drivers.isEmpty)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF78350F).withValues(alpha: 0.3)
                      : const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: isDark
                          ? const Color(0xFFD97706).withValues(alpha: 0.4)
                          : const Color(0xFFFDE68A)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: Color(0xFFD97706), size: 32),
                    const SizedBox(height: 8),
                    Text(
                      'No drivers available nearby within search radius.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isDark
                              ? const Color(0xFFFDE68A)
                              : const Color(0xFF92400E)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Please try expanding your search radius to 10 km or 15 km.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? const Color(0xFFFBBF24)
                              : const Color(0xFFB45309)),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            isDark ? AppColors.gold : const Color(0xFF6E5600),
                        side: BorderSide(
                            color: isDark
                                ? AppColors.gold
                                : const Color(0xFF6E5600)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => onUpdateRadius(10.0),
                      child: const Text('Expand Search Radius to 10 km'),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: top5Drivers.map((driver) {
                  final isSelected = selectedDriver?.id == driver.id;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildDriverCard(context, driver, isSelected),
                  );
                }).toList(),
              ),

            const SizedBox(height: 14),

            // Fare Breakdown & Confirm Booking Button
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkCardElevated
                    : const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderColor(isDark)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ESTIMATED FARE',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.subtextColor(isDark)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            currentFare % 1 == 0
                                ? '₱${currentFare.toInt()}'
                                : '₱${currentFare.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textColor(isDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.terracotta,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: top5Drivers.isEmpty ||
                                selectedDriver?.canSubmitRideRequest != true
                            ? null
                            : onConfirmBooking,
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Confirm & Book Ride',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleTab(
    BuildContext context, {
    required VehicleType type,
    required String title,
    required String subtitle,
    required double fare,
    required bool isSelected,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => onSelectVehicle(type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.terracotta
              : (isDark ? AppColors.darkCardElevated : const Color(0xFFF2F4F7)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppColors.terracotta
                : AppColors.borderColor(isDark),
          ),
        ),
        child: Row(
          children: [
            Text(
              type == VehicleType.tricycle ? '🛺' : '🏍️',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color:
                        isSelected ? Colors.white : AppColors.textColor(isDark),
                  ),
                ),
                Text(
                  '${fare % 1 == 0 ? '₱${fare.toInt()}' : '₱${fare.toStringAsFixed(2)}'} · $subtitle',
                  style: TextStyle(
                    fontSize: 11,
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.8)
                        : AppColors.subtextColor(isDark),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverCard(
      BuildContext context, NearbyDriver driver, bool isSelected) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTricycle = driver.vehicleType == VehicleType.tricycle;

    return GestureDetector(
      onTap: driver.canSubmitRideRequest
          ? () => onSelectDriver(driver)
          : () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        '${driver.availabilityLabel}. This driver cannot receive a request right now.')),
              ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCardElevated : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.terracotta
                : AppColors.borderColor(isDark),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Driver Avatar / Icon with downscaled bitmap decode
            UserAvatar(
              photoUrl: driver.photoUrl,
              name: driver.name,
              radius: 22,
            ),
            const SizedBox(width: 12),

            // Driver Info Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          driver.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textColor(isDark),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isTricycle ? '🛺' : '🏍️',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${driver.plateNumber} · ${driver.completedTrips} trips',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.subtextColor(isDark)),
                  ),
                ],
              ),
            ),

            // Rating & Proximity Info
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (driver.ratingCount > 0) ...[
                        const Icon(Icons.star_rounded,
                            color: Color(0xFFD97706), size: 16),
                        const SizedBox(width: 2),
                        Text(
                          driver.rating.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textColor(isDark),
                          ),
                        ),
                      ] else ...[
                        Text(
                          'New',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.subtextColor(isDark),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    driver.availabilityLabel,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: driver.isBookable
                          ? AppColors.emerald
                          : AppColors.subtextColor(isDark),
                    ),
                  ),
                  if (!driver.isBookable && driver.locationUpdatedAt != null)
                    Text(
                      'Last location ${_lastLocationLabel(driver.locationUpdatedAt!)}',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.subtextColor(isDark),
                      ),
                    ),
                  const SizedBox(height: 2),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF064E3B).withValues(alpha: 0.5)
                          : const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: isDark
                              ? const Color(0xFF059669)
                              : Colors.transparent),
                    ),
                    child: Text(
                      '${driver.distanceKm.toStringAsFixed(1)} km${driver.isBookable ? ' (${driver.etaMinutes}m)' : ' (last known)'}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? const Color(0xFFA7F3D0)
                            : const Color(0xFF15803D),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _lastLocationLabel(DateTime timestamp) {
    final minutes = DateTime.now().difference(timestamp).inMinutes;
    if (minutes < 1) return 'just now';
    if (minutes == 1) return '1 min ago';
    return '$minutes min ago';
  }
}
