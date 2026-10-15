import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/constants.dart';
import '../../../models/trip.dart';
import '../../../state/app_state.dart';
import '../admin_theme.dart';
import '../widgets/admin_widgets.dart';

/// Module 2: Monitor Rides — Search, filter, inspect ongoing, completed, cancelled, and scheduled rides.
class AdminRidesView extends StatefulWidget {
  const AdminRidesView({super.key});

  @override
  State<AdminRidesView> createState() => _AdminRidesViewState();
}

class _AdminRidesViewState extends State<AdminRidesView> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () => setState(() {}));
  }

  String _selectedStatus = 'all';
  String _selectedVehicle = 'all';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _inspectRideDetails(Trip trip) {
    final app = context.read<AppState>();
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = (screenWidth * 0.94).clamp(280.0, 580.0);

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminTheme.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AdminTheme.border),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AdminTheme.terracotta.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.route_rounded,
                  color: AdminTheme.terracotta, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ride #${trip.id.length > 12 ? trip.id.substring(0, 12) : trip.id}',
                    style: const TextStyle(
                      color: AdminTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Created ${DateFormat('MMMM d, yyyy • h:mm:ss a').format(trip.createdAt)}',
                    style: const TextStyle(
                        color: AdminTheme.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            AdminStatusBadge(status: trip.status),
          ],
        ),
        content: SizedBox(
          width: dialogWidth,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(color: AdminTheme.borderLight),
                const SizedBox(height: 8),

                // Route Section
                _buildSectionTitle('Route Information'),
                _buildInfoRow(Icons.my_location_rounded, 'Pickup Address',
                    trip.effectivePickupAddress),
                _buildInfoRow(Icons.location_on_rounded, 'Destination',
                    trip.effectiveDropoffAddress),
                _buildInfoRow(
                  Icons.straighten_rounded,
                  'Distance & Duration',
                  '${trip.distanceKm.toStringAsFixed(2)} km  •  ~${trip.durationMin} mins',
                ),

                const SizedBox(height: 16),
                _buildSectionTitle('Participants'),
                _buildInfoRow(
                    Icons.person_rounded, 'Passenger ID', trip.passengerId),
                _buildInfoRow(
                  Icons.drive_eta_rounded,
                  'Driver ID',
                  trip.driverId != null && trip.driverId!.isNotEmpty
                      ? trip.driverId!
                      : 'Unassigned / Searching',
                ),
                _buildInfoRow(Icons.electric_rickshaw_rounded, 'Vehicle Type',
                    trip.vehicleType.key.toUpperCase()),

                const SizedBox(height: 16),
                _buildSectionTitle('Financial & Payment Breakdown'),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AdminTheme.bgInput,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AdminTheme.border),
                  ),
                  child: Column(
                    children: [
                      _buildFareRow('Calculated Fare',
                          '₱${NumberFormat('#,##0.00').format(trip.fare)}',
                          bold: true),
                      const Divider(color: AdminTheme.borderLight, height: 12),
                      _buildFareRow(
                          'Payment Method', trip.paymentMethod.toUpperCase()),
                      const SizedBox(height: 4),
                      _buildFareRow(
                          'Payment Status', trip.paymentStatus.toUpperCase()),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                _buildSectionTitle('Timeline Timestamps'),
                if (trip.acceptedAt != null)
                  _buildInfoRow(Icons.check_circle_outline, 'Driver Accepted',
                      DateFormat('h:mm:ss a').format(trip.acceptedAt!)),
                if (trip.arrivedAt != null)
                  _buildInfoRow(
                      Icons.pin_drop_outlined,
                      'Driver Arrived at Pickup',
                      DateFormat('h:mm:ss a').format(trip.arrivedAt!)),
                if (trip.startedAt != null)
                  _buildInfoRow(Icons.play_circle_outline, 'Trip Started',
                      DateFormat('h:mm:ss a').format(trip.startedAt!)),
                if (trip.completedAt != null)
                  _buildInfoRow(Icons.flag_outlined, 'Trip Completed',
                      DateFormat('h:mm:ss a').format(trip.completedAt!)),

                if (trip.rating != null) ...[
                  const SizedBox(height: 16),
                  _buildSectionTitle('Passenger Review'),
                  Row(
                    children: [
                      Row(
                        children: List.generate(5, (i) {
                          return Icon(
                            i < trip.rating!
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: AdminTheme.gold,
                            size: 18,
                          );
                        }),
                      ),
                      const SizedBox(width: 8),
                      Text('${trip.rating}/5 Stars',
                          style: const TextStyle(
                              color: AdminTheme.textPrimary,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  if (trip.ratingComment != null &&
                      trip.ratingComment!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('"${trip.ratingComment}"',
                        style: const TextStyle(
                            color: AdminTheme.textSecondary,
                            fontStyle: FontStyle.italic)),
                  ],
                ],
              ],
            ),
          ),
        ),
        actions: [
          if (trip.status == 'searching' ||
              trip.status == 'accepted' ||
              trip.status == 'started')
            OutlinedButton.icon(
              onPressed: () => _showCancelDialog(trip, app),
              icon: const Icon(Icons.cancel_outlined,
                  size: 15, color: AdminTheme.terracotta),
              label: const Text('Force Cancel',
                  style: TextStyle(color: AdminTheme.terracotta, fontSize: 12)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AdminTheme.terracotta),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
          if (trip.status == 'completed')
            OutlinedButton.icon(
              onPressed: () => _showRefundDialog(trip, app),
              icon: const Icon(Icons.replay_rounded,
                  size: 15, color: AdminTheme.gold),
              label: const Text('Issue Refund',
                  style: TextStyle(color: AdminTheme.gold, fontSize: 12)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AdminTheme.gold),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child:
                const Text('Close', style: TextStyle(color: AdminTheme.slate)),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog(Trip trip, AppState app) {
    final reasonCtrl =
        TextEditingController(text: 'Administrative cancellation');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminTheme.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AdminTheme.border),
        ),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded,
                color: AdminTheme.terracotta, size: 22),
            SizedBox(width: 8),
            Text('Force Cancel Trip',
                style: TextStyle(color: AdminTheme.textPrimary, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to administratively cancel Ride #${trip.id.length > 8 ? trip.id.substring(0, 8) : trip.id}?',
              style: const TextStyle(
                  color: AdminTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 2,
              style:
                  const TextStyle(color: AdminTheme.textPrimary, fontSize: 13),
              decoration: AdminTheme.inputDecoration(
                hintText:
                    'Cancellation reason (e.g. Passenger no-show, emergency)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child:
                const Text('Back', style: TextStyle(color: AdminTheme.slate)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminTheme.terracotta,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
              try {
                await app.adminCancelTrip(trip.id, reasonCtrl.text.trim());
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Trip #${trip.id.substring(0, 8)} cancelled successfully'),
                      backgroundColor: AdminTheme.navyLight,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('An error occurred: $e'),
                        backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Confirm Cancel'),
          ),
        ],
      ),
    );
  }

  void _showRefundDialog(Trip trip, AppState app) {
    final reasonCtrl = TextEditingController(text: 'Disputed ride refund');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminTheme.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AdminTheme.border),
        ),
        title: Row(
          children: const [
            Icon(Icons.currency_exchange_rounded,
                color: AdminTheme.gold, size: 22),
            SizedBox(width: 8),
            Text('Issue Refund',
                style: TextStyle(color: AdminTheme.textPrimary, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Issue refund of ₱${trip.fare.toStringAsFixed(2)} for Ride #${trip.id.length > 8 ? trip.id.substring(0, 8) : trip.id} to passenger ${trip.passengerId}?',
              style: const TextStyle(
                  color: AdminTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 2,
              style:
                  const TextStyle(color: AdminTheme.textPrimary, fontSize: 13),
              decoration: AdminTheme.inputDecoration(
                hintText: 'Refund reason (e.g. Overcharged, route dispute)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child:
                const Text('Cancel', style: TextStyle(color: AdminTheme.slate)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminTheme.gold,
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
              try {
                await app.adminRefundPayment(
                    trip.id, trip.fare, reasonCtrl.text.trim());
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Refund of ₱${trip.fare.toStringAsFixed(2)} processed'),
                      backgroundColor: AdminTheme.navyLight,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('An error occurred: $e'),
                        backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Process Refund'),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileRideCard(BuildContext context, Trip trip, AppState app) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AdminTheme.cardDecoration(),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _inspectRideDetails(trip),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AdminTheme.bgInput,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AdminTheme.border),
                          ),
                          child: Text(
                            '#${trip.id.length > 8 ? trip.id.substring(0, 8) : trip.id}',
                            style: const TextStyle(
                              color: AdminTheme.slateLight,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AdminTheme.navyLight,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            trip.vehicleType.key.toUpperCase(),
                            style: const TextStyle(
                              color: AdminTheme.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    AdminStatusBadge(status: trip.status),
                  ],
                ),
                const SizedBox(height: 12),

                // Pickup & Dropoff
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        const Icon(Icons.circle,
                            color: AdminTheme.successText, size: 10),
                        Container(
                            width: 1.5, height: 18, color: AdminTheme.border),
                        const Icon(Icons.location_on,
                            color: AdminTheme.terracotta, size: 12),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trip.effectivePickupAddress,
                            style: TextStyle(
                                color: trip.pickupAddress.isNotEmpty
                                    ? AdminTheme.textPrimary
                                    : AdminTheme.textMuted,
                                fontSize: 13,
                                fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            trip.effectiveDropoffAddress,
                            style: TextStyle(
                                color: trip.dropoffAddress.isNotEmpty
                                    ? AdminTheme.textPrimary
                                    : AdminTheme.textMuted,
                                fontSize: 13,
                                fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(color: AdminTheme.borderLight, height: 1),
                const SizedBox(height: 10),

                // Meta row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          '₱${NumberFormat('#,##0.00').format(trip.fare)}',
                          style: const TextStyle(
                            color: AdminTheme.successText,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${trip.distanceKm.toStringAsFixed(1)} km',
                          style: const TextStyle(
                              color: AdminTheme.textMuted, fontSize: 11),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '• ${trip.paymentMethod.toUpperCase()}',
                          style: const TextStyle(
                              color: AdminTheme.slate,
                              fontSize: 10,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          DateFormat('MMM d, h:mm a').format(trip.createdAt),
                          style: const TextStyle(
                              color: AdminTheme.textMuted, fontSize: 10),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.chevron_right_rounded,
                            color: AdminTheme.slate, size: 16),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AdminTheme.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AdminTheme.slate),
          const SizedBox(width: 8),
          SizedBox(
            width: 140,
            child: Text(label,
                style:
                    const TextStyle(color: AdminTheme.textMuted, fontSize: 12)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: AdminTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildFareRow(String label, String value,
      {bool bold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                color: AdminTheme.textSecondary,
                fontSize: 12,
                fontWeight: bold ? FontWeight.w600 : FontWeight.normal)),
        Text(value,
            style: TextStyle(
                color: color ?? AdminTheme.textPrimary,
                fontSize: 12,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminSectionHeader(
          title: 'Monitor Rides',
          subtitle:
              'Live trip tracking, ride status inspection, fare audit, and route management.',
        ),

        // ── Search & Filter Controls ─────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: AdminTheme.cardDecoration(),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Search Input
              SizedBox(
                width: isMobile ? double.infinity : 280,
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  style: const TextStyle(
                      color: AdminTheme.textPrimary, fontSize: 13),
                  decoration: AdminTheme.inputDecoration(
                    hintText: 'Search by Ride ID, location, user...',
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: AdminTheme.slate, size: 18),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded,
                                size: 16, color: AdminTheme.slate),
                            onPressed: () =>
                                setState(() => _searchCtrl.clear()),
                          )
                        : null,
                  ),
                ),
              ),

              // Status Filter
              DropdownButtonHideUnderline(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  decoration: BoxDecoration(
                    color: AdminTheme.bgInput,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AdminTheme.border),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedStatus,
                    dropdownColor: AdminTheme.bgCard,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: AdminTheme.slate),
                    style: const TextStyle(
                        color: AdminTheme.textPrimary, fontSize: 13),
                    items: const [
                      DropdownMenuItem(
                          value: 'all', child: Text('All Statuses')),
                      DropdownMenuItem(
                          value: 'searching',
                          child: Text('Searching / Requested')),
                      DropdownMenuItem(
                          value: 'accepted', child: Text('Accepted')),
                      DropdownMenuItem(
                          value: 'started', child: Text('In Progress')),
                      DropdownMenuItem(
                          value: 'completed', child: Text('Completed')),
                      DropdownMenuItem(
                          value: 'cancelled', child: Text('Cancelled')),
                    ],
                    onChanged: (val) =>
                        setState(() => _selectedStatus = val ?? 'all'),
                  ),
                ),
              ),

              // Vehicle Type Filter
              DropdownButtonHideUnderline(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  decoration: BoxDecoration(
                    color: AdminTheme.bgInput,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AdminTheme.border),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedVehicle,
                    dropdownColor: AdminTheme.bgCard,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: AdminTheme.slate),
                    style: const TextStyle(
                        color: AdminTheme.textPrimary, fontSize: 13),
                    items: const [
                      DropdownMenuItem(
                          value: 'all', child: Text('All Vehicles')),
                      DropdownMenuItem(
                          value: 'tricycle', child: Text('Tricycle')),
                      DropdownMenuItem(
                          value: 'habal', child: Text('Habal-Habal')),
                    ],
                    onChanged: (val) =>
                        setState(() => _selectedVehicle = val ?? 'all'),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Rides List / Table ─────────────────────────
        AdminDataStreamBuilder<List<Trip>>(
          key: ValueKey(
              'rides_source_${_selectedStatus}_${_searchCtrl.text.trim()}'),
          section: 'rides_list',
          streamFactory: () => app.allRidesStream(
            status: _selectedStatus == 'all' ? null : _selectedStatus,
            searchQuery: _searchCtrl.text,
            limit: 200,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                    child: CircularProgressIndicator(
                        color: AdminTheme.terracotta)),
              );
            }

            var rides = snapshot.data ?? [];
            if (_selectedVehicle != 'all') {
              rides = rides
                  .where((r) => r.vehicleType.key
                      .toLowerCase()
                      .contains(_selectedVehicle))
                  .toList();
            }

            if (rides.isEmpty) {
              return Container(
                decoration: AdminTheme.cardDecoration(),
                padding: const EdgeInsets.all(40),
                child: const AdminEmptyState(
                  icon: Icons.route_rounded,
                  title: 'No Rides Found',
                  subtitle:
                      'No rides matching your search criteria or status filter were found.',
                ),
              );
            }

            // Android / Mobile Card View
            if (isMobile) {
              return Column(
                children: rides
                    .map((t) => _buildMobileRideCard(context, t, app))
                    .toList(),
              );
            }

            // Desktop Data Table View
            return Container(
              decoration: AdminTheme.cardDecoration(),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor:
                      WidgetStateProperty.all(AdminTheme.bgSecondary),
                  horizontalMargin: 16,
                  columnSpacing: 24,
                  columns: const [
                    DataColumn(
                        label: Text('RIDE ID',
                            style: TextStyle(
                                color: AdminTheme.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700))),
                    DataColumn(
                        label: Text('STATUS',
                            style: TextStyle(
                                color: AdminTheme.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700))),
                    DataColumn(
                        label: Text('PICKUP',
                            style: TextStyle(
                                color: AdminTheme.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700))),
                    DataColumn(
                        label: Text('DROPOFF',
                            style: TextStyle(
                                color: AdminTheme.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700))),
                    DataColumn(
                        label: Text('VEHICLE',
                            style: TextStyle(
                                color: AdminTheme.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700))),
                    DataColumn(
                        label: Text('DISTANCE',
                            style: TextStyle(
                                color: AdminTheme.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700))),
                    DataColumn(
                        label: Text('FARE',
                            style: TextStyle(
                                color: AdminTheme.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700))),
                    DataColumn(
                        label: Text('PAYMENT',
                            style: TextStyle(
                                color: AdminTheme.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700))),
                    DataColumn(
                        label: Text('DATE',
                            style: TextStyle(
                                color: AdminTheme.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700))),
                    DataColumn(
                        label: Text('ACTIONS',
                            style: TextStyle(
                                color: AdminTheme.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700))),
                  ],
                  rows: rides.map((trip) {
                    return DataRow(
                      cells: [
                        DataCell(
                          Text(
                            trip.id.length > 10
                                ? '${trip.id.substring(0, 10)}…'
                                : trip.id,
                            style: const TextStyle(
                                color: AdminTheme.slateLight,
                                fontFamily: 'monospace',
                                fontSize: 12),
                          ),
                        ),
                        DataCell(AdminStatusBadge(status: trip.status)),
                        DataCell(
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 160),
                            child: Text(trip.effectivePickupAddress,
                                style: TextStyle(
                                    color: trip.pickupAddress.isNotEmpty
                                        ? AdminTheme.textPrimary
                                        : AdminTheme.textMuted,
                                    fontSize: 12),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ),
                        DataCell(
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 160),
                            child: Text(trip.effectiveDropoffAddress,
                                style: TextStyle(
                                    color: trip.dropoffAddress.isNotEmpty
                                        ? AdminTheme.textPrimary
                                        : AdminTheme.textMuted,
                                    fontSize: 12),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ),
                        DataCell(Text(trip.vehicleType.key.toUpperCase(),
                            style: const TextStyle(
                                color: AdminTheme.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600))),
                        DataCell(Text(
                            '${trip.distanceKm.toStringAsFixed(1)} km',
                            style: const TextStyle(
                                color: AdminTheme.textMuted, fontSize: 12))),
                        DataCell(Text(
                            '₱${NumberFormat('#,##0.00').format(trip.fare)}',
                            style: const TextStyle(
                                color: AdminTheme.successText,
                                fontSize: 12,
                                fontWeight: FontWeight.w700))),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AdminTheme.bgInput,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AdminTheme.border),
                            ),
                            child: Text(trip.paymentMethod.toUpperCase(),
                                style: const TextStyle(
                                    color: AdminTheme.textSecondary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                        DataCell(Text(
                            DateFormat('MMM d, h:mm a').format(trip.createdAt),
                            style: const TextStyle(
                                color: AdminTheme.textMuted, fontSize: 12))),
                        DataCell(
                          ElevatedButton.icon(
                            onPressed: () => _inspectRideDetails(trip),
                            icon:
                                const Icon(Icons.visibility_rounded, size: 14),
                            label: const Text('Inspect'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AdminTheme.navyLight,
                              foregroundColor: AdminTheme.textPrimary,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              textStyle: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w600),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
