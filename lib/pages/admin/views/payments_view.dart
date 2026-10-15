import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/constants.dart';
import '../../../models/firestore_models.dart';
import '../../../models/trip.dart';
import '../../../state/app_state.dart';
import '../admin_theme.dart';
import '../widgets/admin_widgets.dart';

/// Admin payment activity is currently based on completed driver rides.
///
/// The ride row is the source of truth for the stored fare and completion
/// state. Payment-provider records remain available elsewhere for future
/// integrations, but are intentionally not required by this view.
class AdminPaymentsView extends StatefulWidget {
  const AdminPaymentsView({super.key});

  @override
  State<AdminPaymentsView> createState() => _AdminPaymentsViewState();
}

class _AdminPaymentsViewState extends State<AdminPaymentsView> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  Stream<List<DriverEarning>>? _earningsStream;
  String _selectedVehicle = 'all';

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() {});
    });
  }

  /// Keeps the metrics idempotent if a refresh/realtime event ever contains
  /// the same ride more than once.
  List<Trip> _validCompletedRides(Iterable<Trip> rides) {
    final unique = <String, Trip>{};
    for (final ride in rides) {
      final rideId = ride.id.trim();
      final driverId = ride.driverId?.trim();
      if (rideId.isEmpty ||
          ride.status != RideStatus.completed ||
          driverId == null ||
          driverId.isEmpty) {
        continue;
      }
      unique.putIfAbsent(rideId, () => ride);
    }

    final result = unique.values.toList();
    result.sort((a, b) => _completedAt(b).compareTo(_completedAt(a)));
    return result;
  }

  DateTime _completedAt(Trip ride) => ride.completedAt ?? ride.createdAt;

  /// Driver earnings only supplies the settled-count metric. Completed rides
  /// remain the authoritative payment-page data, so an unavailable earnings
  /// table/realtime channel must not blank the whole screen.
  Stream<List<DriverEarning>> _optionalEarningsStream(AppState app) async* {
    var lastValue = const <DriverEarning>[];
    try {
      await for (final value in app.allEarningsStream()) {
        lastValue = value;
        yield value;
      }
    } catch (error, stackTrace) {
      debugPrint('[ADMIN PAYMENTS] optional driver earnings unavailable: '
          'type=${error.runtimeType} message=$error');
      debugPrintStack(stackTrace: stackTrace);
      yield lastValue;
    }
  }

  bool _matchesFilters(Trip ride) {
    if (_selectedVehicle != 'all' && ride.vehicleType.key != _selectedVehicle) {
      return false;
    }

    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) return true;

    return ride.id.toLowerCase().contains(query) ||
        (ride.driverId?.toLowerCase().contains(query) ?? false) ||
        ride.passengerName.toLowerCase().contains(query) ||
        ride.passengerId.toLowerCase().contains(query) ||
        ride.vehicleType.key.toLowerCase().contains(query);
  }

  String _driverLabel(Trip ride) {
    final id = ride.driverId?.trim();
    if (id == null || id.isEmpty) return 'Unassigned';
    return id;
  }

  String _passengerLabel(Trip ride) {
    final name = ride.passengerName.trim();
    if (name.isNotEmpty) return name;
    return ride.passengerId.trim().isEmpty ? 'Unknown' : ride.passengerId;
  }

  String _compactId(String value, {int length = 12}) {
    if (value.length <= length) return value;
    return '${value.substring(0, length)}…';
  }

  void _inspectCompletedRide(Trip ride) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = (screenWidth * 0.94).clamp(280.0, 520.0);
    final completedAt = _completedAt(ride);

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
              child: const Icon(Icons.receipt_long_rounded,
                  color: AdminTheme.terracotta, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ride #${_compactId(ride.id)}',
                    style: const TextStyle(
                      color: AdminTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    DateFormat('MMMM d, yyyy • h:mm a').format(completedAt),
                    style: const TextStyle(
                        color: AdminTheme.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            AdminStatusBadge(status: ride.status),
          ],
        ),
        content: SizedBox(
          width: dialogWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(color: AdminTheme.borderLight),
              const SizedBox(height: 8),
              _buildDetailRow('Ride ID', ride.id),
              _buildDetailRow('Driver', _driverLabel(ride)),
              _buildDetailRow('Passenger', _passengerLabel(ride)),
              _buildDetailRow(
                  'Vehicle Type', ride.vehicleType.key.toUpperCase()),
              _buildDetailRow('Ride Status', ride.status.toUpperCase()),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AdminTheme.bgInput,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AdminTheme.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Gross Driver Fare',
                        style: TextStyle(
                            color: AdminTheme.textSecondary, fontSize: 12)),
                    Text(
                      '₱${NumberFormat('#,##0.00').format(ride.fare)}',
                      style: const TextStyle(
                        color: AdminTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child:
                const Text('Close', style: TextStyle(color: AdminTheme.slate)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  const TextStyle(color: AdminTheme.textMuted, fontSize: 12)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                  color: AdminTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileRideCard(Trip ride) {
    final completedAt = _completedAt(ride);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AdminTheme.cardDecoration(),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _inspectCompletedRide(ride),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '#${_compactId(ride.id, length: 14)}',
                      style: const TextStyle(
                          color: AdminTheme.slateLight,
                          fontFamily: 'monospace',
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                    AdminStatusBadge(status: ride.status),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('DRIVER',
                              style: TextStyle(
                                  color: AdminTheme.textMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700)),
                          Text(_compactId(_driverLabel(ride)),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: AdminTheme.textSecondary,
                                  fontSize: 12)),
                          const SizedBox(height: 6),
                          const Text('PASSENGER',
                              style: TextStyle(
                                  color: AdminTheme.textMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700)),
                          Text(_passengerLabel(ride),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: AdminTheme.textSecondary,
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('GROSS FARE',
                            style: TextStyle(
                                color: AdminTheme.textMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w700)),
                        Text(
                          '₱${NumberFormat('#,##0.00').format(ride.fare)}',
                          style: const TextStyle(
                              color: AdminTheme.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(ride.vehicleType.key.toUpperCase(),
                            style: const TextStyle(
                                color: AdminTheme.slateLight,
                                fontSize: 10,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(color: AdminTheme.borderLight, height: 1),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('MMM d, h:mm a').format(completedAt),
                      style: const TextStyle(
                          color: AdminTheme.textMuted, fontSize: 10),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: AdminTheme.slate, size: 16),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterControls(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: AdminTheme.cardDecoration(),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: isMobile ? double.infinity : 300,
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              style:
                  const TextStyle(color: AdminTheme.textPrimary, fontSize: 13),
              decoration: AdminTheme.inputDecoration(
                hintText: 'Search Ride ID, Driver, Passenger...',
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AdminTheme.slate, size: 18),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded,
                            size: 16, color: AdminTheme.slate),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
            ),
          ),
          DropdownButtonHideUnderline(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
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
                  DropdownMenuItem(value: 'all', child: Text('All Vehicles')),
                  DropdownMenuItem(value: 'tricycle', child: Text('Tricycle')),
                  DropdownMenuItem(value: 'habal', child: Text('Habal-habal')),
                ],
                onChanged: (value) =>
                    setState(() => _selectedVehicle = value ?? 'all'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTable(List<Trip> rides) {
    return Container(
      decoration: AdminTheme.cardDecoration(),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(AdminTheme.bgSecondary),
          horizontalMargin: 16,
          columnSpacing: 24,
          columns: const [
            DataColumn(label: _HeaderLabel('RIDE ID')),
            DataColumn(label: _HeaderLabel('DRIVER')),
            DataColumn(label: _HeaderLabel('PASSENGER')),
            DataColumn(label: _HeaderLabel('VEHICLE')),
            DataColumn(label: _HeaderLabel('COMPLETED DATE & TIME')),
            DataColumn(label: _HeaderLabel('GROSS FARE')),
            DataColumn(label: _HeaderLabel('STATUS')),
            DataColumn(label: _HeaderLabel('ACTIONS')),
          ],
          rows: rides.map((ride) {
            final completedAt = _completedAt(ride);
            return DataRow(
              cells: [
                DataCell(Text(ride.id,
                    style: const TextStyle(
                        color: AdminTheme.slateLight,
                        fontFamily: 'monospace',
                        fontSize: 12))),
                DataCell(Text(_compactId(_driverLabel(ride)),
                    style: const TextStyle(
                        color: AdminTheme.textSecondary, fontSize: 12))),
                DataCell(Text(_passengerLabel(ride),
                    style: const TextStyle(
                        color: AdminTheme.textSecondary, fontSize: 12))),
                DataCell(Text(ride.vehicleType.key.toUpperCase(),
                    style: const TextStyle(
                        color: AdminTheme.textSecondary, fontSize: 12))),
                DataCell(Text(
                    DateFormat('MMM d, yyyy • h:mm a').format(completedAt),
                    style: const TextStyle(
                        color: AdminTheme.textMuted, fontSize: 12))),
                DataCell(Text('₱${NumberFormat('#,##0.00').format(ride.fare)}',
                    style: const TextStyle(
                        color: AdminTheme.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold))),
                DataCell(AdminStatusBadge(status: ride.status)),
                DataCell(
                  ElevatedButton.icon(
                    onPressed: () => _inspectCompletedRide(ride),
                    icon: const Icon(Icons.visibility_rounded, size: 14),
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
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminSectionHeader(
          title: 'Completed Ride Earnings',
          subtitle:
              'Review completed driver rides using the fare stored on each ride.',
        ),
        _buildFilterControls(isMobile),
        AdminDataStreamBuilder<List<DriverEarning>>(
          section: 'confirmed_driver_earnings',
          stream: _earningsStream ??= _optionalEarningsStream(app),
          initialData: const [],
          builder: (context, earningSnapshot) {
            final settledRideIds =
                (earningSnapshot.data ?? const <DriverEarning>[])
                    .where((earning) =>
                        earning.settlementStatus.toLowerCase() == 'confirmed')
                    .map((earning) => earning.rideId)
                    .toSet();

            return AdminDataStreamBuilder<List<Trip>>(
              section: 'completed_ride_earnings',
              streamFactory: () => app.allRidesStream(
                status: RideStatus.completed,
                limit: 10000,
              ),
              builder: (context, snapshot) {
                final rides = _validCompletedRides(snapshot.data ?? const []);
                final visibleRides = rides.where(_matchesFilters).toList();
                final totalGross =
                    rides.fold<double>(0, (sum, ride) => sum + ride.fare);
                final settledCount = rides
                    .where((ride) => settledRideIds.contains(ride.id))
                    .length;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final crossAxisCount =
                            constraints.maxWidth < 600 ? 1 : 2;
                        return GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio:
                              constraints.maxWidth < 600 ? 2.6 : 2.4,
                          children: [
                            AdminStatCard(
                              title: 'Total Gross Fares',
                              value:
                                  '₱${NumberFormat('#,##0.00').format(totalGross)}',
                              icon: Icons.account_balance_wallet_rounded,
                              accentColor: AdminTheme.terracotta,
                              subtitle:
                                  'Accumulated fares from completed rides',
                            ),
                            AdminStatCard(
                              title: 'Settled Transactions',
                              value: '$settledCount',
                              icon: Icons.check_circle_outline_rounded,
                              accentColor: AdminTheme.info,
                              subtitle:
                                  'Completed rides with confirmed driver earnings',
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    if (visibleRides.isEmpty)
                      Container(
                        decoration: AdminTheme.cardDecoration(),
                        padding: const EdgeInsets.all(40),
                        child: AdminEmptyState(
                          icon: Icons.payments_outlined,
                          title: rides.isEmpty
                              ? 'No completed transactions recorded.'
                              : 'No matching completed transactions.',
                          subtitle: rides.isEmpty
                              ? 'Completed driver ride activity will appear here.'
                              : 'Try changing the search or vehicle filter.',
                        ),
                      )
                    else if (isMobile)
                      Column(
                        children: visibleRides
                            .map(_buildMobileRideCard)
                            .toList(growable: false),
                      )
                    else
                      _buildDesktopTable(visibleRides),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _HeaderLabel extends StatelessWidget {
  const _HeaderLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            color: AdminTheme.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700));
  }
}
