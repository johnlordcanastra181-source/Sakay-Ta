import 'package:flutter/material.dart';
import '../../../models/firestore_models.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/constants.dart';
import '../../../models/trip.dart';
import '../../../models/admin_dashboard.dart';
import '../../../state/app_state.dart';
import '../../../services/supabase/admin_service.dart';
import '../admin_theme.dart';
import '../widgets/admin_widgets.dart';

/// Module 1: View Dashboard — Real-time stats, revenue chart, pending driver reviews, recent rides.
class AdminOverviewView extends StatefulWidget {
  const AdminOverviewView({super.key, required this.onNavigateTab});
  final Function(int) onNavigateTab;

  @override
  State<AdminOverviewView> createState() => _AdminOverviewViewState();
}

class _AdminOverviewViewState extends State<AdminOverviewView> {
  int _refreshGeneration = 0;
  AdminOverviewResponse? _overviewData;
  bool _isLoadingOverview = true;
  String? _overviewError;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    setState(() {
      _isLoadingOverview = _overviewData == null;
      _overviewError = null;
    });

    try {
      final data = await SupabaseAdminService.instance
          .getAdminOverview(forceRefresh: forceRefresh);
      if (mounted) {
        setState(() {
          _overviewData = data;
          _isLoadingOverview = false;
          _overviewError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingOverview = false;
          _overviewError = e.toString();
        });
      }
    }
  }

  void _refreshAll() {
    setState(() {
      _refreshGeneration++;
    });
    _loadData(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminSectionHeader(
          title: 'Platform Overview',
          subtitle:
              'Real-time metrics, active rides, driver verification queue, and financial performance.',
          actions: [
            if (_isLoadingOverview && _overviewData != null)
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AdminTheme.terracotta,
                  ),
                ),
              ),
            OutlinedButton.icon(
              onPressed: _isLoadingOverview ? null : _refreshAll,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Refresh'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AdminTheme.textSecondary,
                side: const BorderSide(color: AdminTheme.border),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),

        if (_overviewError != null && _overviewData == null)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AdminTheme.danger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AdminTheme.danger.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: AdminTheme.dangerText, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Failed to load metrics: $_overviewError',
                    style: const TextStyle(
                        color: AdminTheme.dangerText, fontSize: 13),
                  ),
                ),
                TextButton(
                  onPressed: _refreshAll,
                  child: const Text('Retry',
                      style: TextStyle(
                          color: AdminTheme.dangerText,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
            // ── Real-Time Metrics Grid ───────────────────────────
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                int crossAxisCount = 4;
                if (width < 600) {
                  crossAxisCount = 1;
                } else if (width < 1000) {
                  crossAxisCount = 2;
                }

                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: width < 600 ? 2.5 : 1.8,
                  children: [
                    AdminStatCard(
                      title: 'Total Rides',
                      value: _overviewData != null
                          ? '${_overviewData!.totalRides}'
                          : '—',
                      icon: Icons.route_rounded,
                      accentColor: AdminTheme.terracotta,
                      subtitle: 'Total platform trips',
                      onTap: () => widget.onNavigateTab(1),
                    ),
                    AdminStatCard(
                      title: 'Active Rides',
                      value: _overviewData != null
                          ? '${_overviewData!.activeRides}'
                          : '—',
                      icon: Icons.electric_rickshaw_rounded,
                      accentColor: AdminTheme.info,
                      subtitle: 'Currently active on road',
                      onTap: () => widget.onNavigateTab(1),
                    ),
                    AdminStatCard(
                      title: 'Total Drivers',
                      value: _overviewData != null
                          ? '${_overviewData!.totalDrivers}'
                          : '—',
                      icon: Icons.drive_eta_rounded,
                      accentColor: AdminTheme.green,
                      subtitle: 'Registered drivers',
                      onTap: () => widget.onNavigateTab(4),
                    ),
                    AdminStatCard(
                      title: 'Total Passengers',
                      value: _overviewData != null
                          ? '${_overviewData!.totalPassengers}'
                          : '—',
                      icon: Icons.people_alt_rounded,
                      accentColor: const Color(0xFF9B51E0),
                      subtitle: 'Registered platform riders',
                      onTap: () => widget.onNavigateTab(3),
                    ),
                    AdminStatCard(
                      title: 'Pending Registrations',
                      value: _overviewData != null
                          ? '${_overviewData!.pendingDrivers}'
                          : '—',
                      icon: Icons.how_to_reg_rounded,
                      accentColor: AdminTheme.gold,
                      subtitle: 'Driver documents for review',
                      onTap: () => widget.onNavigateTab(5),
                    ),
                    AdminStatCard(
                      title: 'Open Reports',
                      value: _overviewData != null
                          ? '${_overviewData!.openReports}'
                          : '—',
                      icon: Icons.report_problem_rounded,
                      accentColor: AdminTheme.danger,
                      subtitle: 'Customer service & safety issues',
                      onTap: () => widget.onNavigateTab(2),
                    ),
                    AdminStatCard(
                      title: 'Revenue Today',
                      value: _overviewData != null
                          ? '₱${NumberFormat('#,##0.00').format(_overviewData!.revenueToday)}'
                          : '—',
                      icon: Icons.account_balance_wallet_rounded,
                      accentColor: const Color(0xFF27AE60),
                      subtitle: 'Gross fares from completed rides today',
                      onTap: () => widget.onNavigateTab(7),
                    ),
                    AdminDataStreamBuilder<bool>(
                      key: ValueKey('platform-status-$_refreshGeneration'),
                      section: 'platform_status',
                      streamFactory: app.adminHealthStream,
                      builder: (context, statusSnap) => AdminStatCard(
                        title: 'Platform Status',
                        value: statusSnap.requireData ? 'Live' : 'Local',
                        icon: Icons.cloud_done_rounded,
                        accentColor: statusSnap.requireData
                            ? AdminTheme.successText
                            : AdminTheme.warningText,
                        subtitle: statusSnap.requireData
                            ? 'Supabase synchronized'
                            : 'Local data mode',
                        onTap: () => widget.onNavigateTab(6),
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 24),

            // ── 2-Column Section: Weekly Revenue Chart + Pending Reviews ─
            LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 900;
                return Flex(
                  direction: isDesktop ? Axis.horizontal : Axis.vertical,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Revenue Bar Chart
                    Expanded(
                      flex: isDesktop ? 3 : 0,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: AdminTheme.cardDecoration(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Weekly Revenue Trend',
                                      style: TextStyle(
                                        color: AdminTheme.textPrimary,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Gross fares from completed rides over the last 7 days',
                                      style: TextStyle(
                                        color: AdminTheme.textMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                TextButton.icon(
                                  onPressed: () =>
                                      widget.onNavigateTab(6), // Analytics
                                  icon: const Icon(Icons.insights_rounded,
                                      size: 16),
                                  label: const Text('Full Analytics'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AdminTheme.terracotta,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              height: 220,
                              child: Builder(
                                builder: (context) {
                                  if (_overviewData == null) {
                                    return const Center(
                                      child: SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AdminTheme.terracotta,
                                        ),
                                      ),
                                    );
                                  }
                                  final chartData = _overviewData!.weeklyRevenue.isNotEmpty
                                      ? _overviewData!.weeklyRevenue
                                      : List.filled(7, 0.0);
                                  final maxRevenue = chartData.fold<double>(
                                      0.0, (max, v) => v > max ? v : max);
                                  final maxVal = (maxRevenue * 1.25)
                                      .clamp(100.0, 1000000.0);

                                  return BarChart(
                                    BarChartData(
                                      alignment: BarChartAlignment.spaceAround,
                                      maxY: maxVal,
                                      barTouchData: BarTouchData(
                                        touchTooltipData: BarTouchTooltipData(
                                          getTooltipItem: (group, groupIndex,
                                              rod, rodIndex) {
                                            return BarTooltipItem(
                                              '₱${NumberFormat('#,##0.00').format(rod.toY)}',
                                              const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      titlesData: FlTitlesData(
                                        show: true,
                                        bottomTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            getTitlesWidget: (val, meta) {
                                              final daysAgo = 6 - val.toInt();
                                              final dt = DateTime.now()
                                                  .subtract(
                                                      Duration(days: daysAgo));
                                              return Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 8),
                                                child: Text(
                                                  DateFormat('E').format(dt),
                                                  style: const TextStyle(
                                                    color: AdminTheme.textMuted,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        leftTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            reservedSize: 45,
                                            getTitlesWidget: (val, meta) {
                                              return Text(
                                                val >= 1000
                                                    ? '₱${(val / 1000).toStringAsFixed(0)}k'
                                                    : '₱${val.toInt()}',
                                                style: const TextStyle(
                                                  color: AdminTheme.textMuted,
                                                  fontSize: 10,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        topTitles: const AxisTitles(
                                            sideTitles:
                                                SideTitles(showTitles: false)),
                                        rightTitles: const AxisTitles(
                                            sideTitles:
                                                SideTitles(showTitles: false)),
                                      ),
                                      gridData: FlGridData(
                                        show: true,
                                        drawVerticalLine: false,
                                        getDrawingHorizontalLine: (val) =>
                                            FlLine(
                                          color: AdminTheme.border
                                              .withValues(alpha: 0.5),
                                          strokeWidth: 1,
                                        ),
                                      ),
                                      borderData: FlBorderData(show: false),
                                      barGroups:
                                          List.generate(chartData.length, (i) {
                                        return BarChartGroupData(
                                          x: i,
                                          barRods: [
                                            BarChartRodData(
                                              toY: chartData[i],
                                              color: AdminTheme.terracotta,
                                              width: 18,
                                              borderRadius:
                                                  const BorderRadius.vertical(
                                                      top: Radius.circular(6)),
                                            ),
                                          ],
                                        );
                                      }),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (isDesktop)
                      const SizedBox(width: 16)
                    else
                      const SizedBox(height: 16),

                    // Pending Reviews Queue
                    Expanded(
                      flex: isDesktop ? 2 : 0,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: AdminTheme.cardDecoration(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Verification Queue',
                                  style: TextStyle(
                                    color: AdminTheme.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      widget.onNavigateTab(5), // Verification
                                  child: const Text('View All',
                                      style: TextStyle(
                                          color: AdminTheme.terracotta,
                                          fontSize: 12)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            AdminDataStreamBuilder<List<DriverApplication>>(
                              key: ValueKey(
                                  'verification-queue-$_refreshGeneration'),
                              section: 'verification_queue',
                              streamFactory: () =>
                                  app.pendingDriverApplicationsStream(limit: 4),
                              builder: (context, snapshot) {
                                final apps = snapshot.requireData;
                                if (apps.isEmpty) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 32),
                                    child: AdminEmptyState(
                                      icon: Icons.check_circle_outline_rounded,
                                      title: 'Queue Clear',
                                      subtitle:
                                          'All driver registration documents have been verified.',
                                    ),
                                  );
                                }

                                return ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: apps.length,
                                  separatorBuilder: (_, __) => const Divider(
                                      color: AdminTheme.borderLight,
                                      height: 16),
                                  itemBuilder: (context, index) {
                                    final item = apps[index];
                                    return Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: AdminTheme.navyLight,
                                          radius: 18,
                                          child: Text(
                                            item.user.fullName.isNotEmpty
                                                ? item.user.fullName[0]
                                                    .toUpperCase()
                                                : 'D',
                                            style: const TextStyle(
                                                color: AdminTheme.gold,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.user.fullName,
                                                style: const TextStyle(
                                                  color: AdminTheme.textPrimary,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              Text(
                                                '${item.profile.vehicleType.key.toUpperCase()} • ${item.profile.plateNumber}',
                                                style: const TextStyle(
                                                  color: AdminTheme.textMuted,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        ElevatedButton(
                                          onPressed: () =>
                                              widget.onNavigateTab(5),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                AdminTheme.terracotta,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 6),
                                            textStyle: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                          ),
                                          child: const Text('Review'),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 24),

            // ── Recent Rides Monitoring Table ────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AdminTheme.cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recent Platform Rides',
                            style: TextStyle(
                              color: AdminTheme.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Live trip dispatching across all operating municipalities',
                            style: TextStyle(
                                color: AdminTheme.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: () =>
                            widget.onNavigateTab(1), // Monitor Rides
                        icon: const Icon(Icons.open_in_new_rounded, size: 14),
                        label: const Text('Monitor Rides'),
                        style: TextButton.styleFrom(
                            foregroundColor: AdminTheme.terracotta),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AdminDataStreamBuilder<List<Trip>>(
                    key: ValueKey('recent-rides-$_refreshGeneration'),
                    section: 'recent_rides',
                    streamFactory: () => app.allRidesStream(limit: 8),
                    builder: (context, snapshot) {
                      final rides = snapshot.requireData;
                      if (rides.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(32),
                          child: AdminEmptyState(
                            icon: Icons.directions_car_outlined,
                            title: 'No Rides Dispatched Yet',
                            subtitle:
                                'Live trip bookings from mobile apps will appear here automatically.',
                          ),
                        );
                      }

                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor:
                              WidgetStateProperty.all(AdminTheme.bgSecondary),
                          horizontalMargin: 12,
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
                                label: Text('PICKUP LOCATION',
                                    style: TextStyle(
                                        color: AdminTheme.textMuted,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700))),
                            DataColumn(
                                label: Text('DESTINATION',
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
                                label: Text('FARE',
                                    style: TextStyle(
                                        color: AdminTheme.textMuted,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700))),
                            DataColumn(
                                label: Text('DATE & TIME',
                                    style: TextStyle(
                                        color: AdminTheme.textMuted,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700))),
                          ],
                          rows: rides.map((t) {
                            return DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    t.id.length > 10
                                        ? '${t.id.substring(0, 10)}…'
                                        : t.id,
                                    style: const TextStyle(
                                        color: AdminTheme.slateLight,
                                        fontFamily: 'monospace',
                                        fontSize: 12),
                                  ),
                                ),
                                DataCell(AdminStatusBadge(status: t.status)),
                                DataCell(
                                  ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 180),
                                    child: Text(
                                      t.pickupAddress,
                                      style: const TextStyle(
                                          color: AdminTheme.textPrimary,
                                          fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 180),
                                    child: Text(
                                      t.dropoffAddress,
                                      style: const TextStyle(
                                          color: AdminTheme.textPrimary,
                                          fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    t.vehicleType.key.toUpperCase(),
                                    style: const TextStyle(
                                        color: AdminTheme.textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    '₱${NumberFormat('#,##0.00').format(t.fare)}',
                                    style: const TextStyle(
                                        color: AdminTheme.successText,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    DateFormat('MMM d, h:mm a')
                                        .format(t.createdAt),
                                    style: const TextStyle(
                                        color: AdminTheme.textMuted,
                                        fontSize: 12),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        );
  }
}
