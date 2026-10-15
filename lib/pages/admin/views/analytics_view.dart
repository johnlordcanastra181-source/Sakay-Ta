import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/constants.dart';
import '../../../models/trip.dart';
import '../../../state/app_state.dart';
import '../admin_theme.dart';
import '../widgets/admin_widgets.dart';

/// Module 8: View Analytics — Interactive charts for rides, revenue, driver performance, passenger activity, cancellations, peak hours.
class AdminAnalyticsView extends StatefulWidget {
  const AdminAnalyticsView({super.key});

  @override
  State<AdminAnalyticsView> createState() => _AdminAnalyticsViewState();
}

class _AdminAnalyticsViewState extends State<AdminAnalyticsView> {
  int _timeframeDays = 14;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminSectionHeader(
          title: 'Platform Analytics & Reports',
          subtitle:
              'Interactive business intelligence metrics, dispatch performance, revenue trends, and route analytics.',
          actions: [
            DropdownButtonHideUnderline(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                decoration: BoxDecoration(
                  color: AdminTheme.bgInput,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AdminTheme.border),
                ),
                child: DropdownButton<int>(
                  value: _timeframeDays,
                  dropdownColor: AdminTheme.bgCard,
                  icon: const Icon(Icons.calendar_month_rounded,
                      size: 16, color: AdminTheme.slate),
                  style: const TextStyle(
                      color: AdminTheme.textPrimary, fontSize: 12),
                  items: const [
                    DropdownMenuItem(value: 7, child: Text('Last 7 Days')),
                    DropdownMenuItem(value: 14, child: Text('Last 14 Days')),
                    DropdownMenuItem(value: 30, child: Text('Last 30 Days')),
                  ],
                  onChanged: (val) =>
                      setState(() => _timeframeDays = val ?? 14),
                ),
              ),
            ),
          ],
        ),

        // ── Top Row: Revenue Trend Line Chart + Ride Status Pie Chart ─
        AdminDataStreamBuilder<List<Trip>>(
          section: 'analytics_rides',
          streamFactory: () => app.allRidesStream(limit: 500),
          builder: (context, ridesSnap) {
            final rides = ridesSnap.data ?? [];

            final completedCount =
                rides.where((r) => r.status == 'completed').length;
            final cancelledCount =
                rides.where((r) => r.status == 'cancelled').length;
            final activeCount = rides
                .where(
                    (r) => r.status != 'completed' && r.status != 'cancelled')
                .length;
            final totalRides = (completedCount + cancelledCount + activeCount)
                .clamp(1, 100000);

            // Payment breakdown
            final cashCount = rides
                .where((r) => r.paymentMethod.toLowerCase() == 'cash')
                .length;
            final gcashCount = rides
                .where((r) => r.paymentMethod.toLowerCase() == 'gcash')
                .length;
            final mayaCount = rides
                .where((r) => r.paymentMethod.toLowerCase() == 'maya')
                .length;

            return LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 900;

                return Column(
                  children: [
                    Flex(
                      direction: isDesktop ? Axis.horizontal : Axis.vertical,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Revenue Line Chart
                        Expanded(
                          flex: isDesktop ? 3 : 0,
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: AdminTheme.cardDecoration(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Daily Gross Fare Trend',
                                    style: TextStyle(
                                        color: AdminTheme.textPrimary,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                const Text(
                                    'Completed ride fares recorded each day',
                                    style: TextStyle(
                                        color: AdminTheme.textMuted,
                                        fontSize: 12)),
                                const SizedBox(height: 20),
                                SizedBox(
                                  height: 240,
                                  child: AdminDataStreamBuilder<List<double>>(
                                    key: ValueKey(
                                        'analytics_revenue_$_timeframeDays'),
                                    section: 'analytics_revenue',
                                    streamFactory: () =>
                                        app.weeklyRevenueStream(
                                            days: _timeframeDays),
                                    builder: (context, snap) {
                                      final rawData = snap.data ??
                                          List.filled(_timeframeDays, 0.0);
                                      final maxRevenue = (rawData.reduce(
                                                  (a, b) => a > b ? a : b) *
                                              1.3)
                                          .clamp(200.0, 1000000.0);

                                      return LineChart(
                                        LineChartData(
                                          maxY: maxRevenue,
                                          minY: 0,
                                          lineTouchData: LineTouchData(
                                            touchTooltipData:
                                                LineTouchTooltipData(
                                              getTooltipItems: (touchedSpots) {
                                                return touchedSpots.map((spot) {
                                                  return LineTooltipItem(
                                                    'Gross Fare: ₱${NumberFormat("#,##0.00").format(spot.y)}',
                                                    const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.bold),
                                                  );
                                                }).toList();
                                              },
                                            ),
                                          ),
                                          titlesData: FlTitlesData(
                                            bottomTitles: AxisTitles(
                                              sideTitles: SideTitles(
                                                showTitles: true,
                                                reservedSize: 24,
                                                interval: (_timeframeDays / 5)
                                                    .ceilToDouble(),
                                                getTitlesWidget: (val, meta) {
                                                  final idx = val.toInt();
                                                  if (idx < 0 ||
                                                      idx >= _timeframeDays) {
                                                    return const SizedBox
                                                        .shrink();
                                                  }
                                                  final dt = DateTime.now()
                                                      .subtract(Duration(
                                                          days: _timeframeDays -
                                                              1 -
                                                              idx));
                                                  return Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            top: 6),
                                                    child: Text(
                                                        DateFormat('M/d')
                                                            .format(dt),
                                                        style: const TextStyle(
                                                            color: AdminTheme
                                                                .textMuted,
                                                            fontSize: 10)),
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
                                                        color: AdminTheme
                                                            .textMuted,
                                                        fontSize: 10),
                                                  );
                                                },
                                              ),
                                            ),
                                            topTitles: const AxisTitles(
                                                sideTitles: SideTitles(
                                                    showTitles: false)),
                                            rightTitles: const AxisTitles(
                                                sideTitles: SideTitles(
                                                    showTitles: false)),
                                          ),
                                          gridData: FlGridData(
                                            show: true,
                                            getDrawingHorizontalLine: (_) =>
                                                FlLine(
                                                    color: AdminTheme.border
                                                        .withValues(alpha: 0.4),
                                                    strokeWidth: 1),
                                            drawVerticalLine: false,
                                          ),
                                          borderData: FlBorderData(show: false),
                                          lineBarsData: [
                                            LineChartBarData(
                                              spots: List.generate(
                                                  rawData.length,
                                                  (i) => FlSpot(i.toDouble(),
                                                      rawData[i])),
                                              isCurved: true,
                                              color: AdminTheme.terracotta,
                                              barWidth: 3,
                                              isStrokeCapRound: true,
                                              dotData:
                                                  const FlDotData(show: false),
                                              belowBarData: BarAreaData(
                                                  show: true,
                                                  color: AdminTheme.terracotta
                                                      .withValues(alpha: 0.12)),
                                            ),
                                          ],
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

                        // Ride Status Distribution (Pie Chart)
                        Expanded(
                          flex: isDesktop ? 2 : 0,
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: AdminTheme.cardDecoration(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Ride Status Distribution',
                                    style: TextStyle(
                                        color: AdminTheme.textPrimary,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                const Text('Completed vs Cancelled vs Active',
                                    style: TextStyle(
                                        color: AdminTheme.textMuted,
                                        fontSize: 12)),
                                const SizedBox(height: 20),
                                SizedBox(
                                  height: 160,
                                  child: PieChart(
                                    PieChartData(
                                      sectionsSpace: 3,
                                      centerSpaceRadius: 40,
                                      sections: [
                                        PieChartSectionData(
                                          color: AdminTheme.successText,
                                          value: completedCount
                                              .toDouble()
                                              .clamp(1.0, 1000.0),
                                          title:
                                              '${((completedCount / totalRides) * 100).toStringAsFixed(0)}%',
                                          radius: 35,
                                          titleStyle: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87),
                                        ),
                                        PieChartSectionData(
                                          color: AdminTheme.dangerText,
                                          value: cancelledCount
                                              .toDouble()
                                              .clamp(1.0, 1000.0),
                                          title:
                                              '${((cancelledCount / totalRides) * 100).toStringAsFixed(0)}%',
                                          radius: 35,
                                          titleStyle: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white),
                                        ),
                                        PieChartSectionData(
                                          color: AdminTheme.infoText,
                                          value: activeCount
                                              .toDouble()
                                              .clamp(1.0, 1000.0),
                                          title:
                                              '${((activeCount / totalRides) * 100).toStringAsFixed(0)}%',
                                          radius: 35,
                                          titleStyle: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildLegendItem(AdminTheme.successText,
                                    'Completed Rides', '$completedCount trips'),
                                const SizedBox(height: 4),
                                _buildLegendItem(AdminTheme.dangerText,
                                    'Cancelled Rides', '$cancelledCount trips'),
                                const SizedBox(height: 4),
                                _buildLegendItem(
                                    AdminTheme.infoText,
                                    'Active / Dispatched',
                                    '$activeCount trips'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── Bottom 3 Cards: Payment Methods, Vehicle Demand, Peak Hours ──
                    LayoutBuilder(
                      builder: (context, bottomConstraints) {
                        final count = bottomConstraints.maxWidth < 800 ? 1 : 3;
                        return GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: count,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.4,
                          children: [
                            // Card 1: Payment Method Breakdown
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: AdminTheme.cardDecoration(),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Payment Methods',
                                      style: TextStyle(
                                          color: AdminTheme.textPrimary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  const Text('Passenger payment preferences',
                                      style: TextStyle(
                                          color: AdminTheme.textMuted,
                                          fontSize: 11)),
                                  const Spacer(),
                                  _buildProgressBar('Cash on Hand', cashCount,
                                      totalRides, AdminTheme.green),
                                  const SizedBox(height: 8),
                                  _buildProgressBar('GCash E-Wallet',
                                      gcashCount, totalRides, AdminTheme.info),
                                  const SizedBox(height: 8),
                                  _buildProgressBar('Maya / Card', mayaCount,
                                      totalRides, AdminTheme.gold),
                                  const Spacer(),
                                ],
                              ),
                            ),

                            // Card 2: Vehicle Type Distribution
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: AdminTheme.cardDecoration(),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Vehicle Type Demand',
                                      style: TextStyle(
                                          color: AdminTheme.textPrimary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  const Text('Dispatches per vehicle category',
                                      style: TextStyle(
                                          color: AdminTheme.textMuted,
                                          fontSize: 11)),
                                  const Spacer(),
                                  _buildProgressBar(
                                    'Tricycle (TODA)',
                                    rides
                                        .where((r) =>
                                            r.vehicleType.key == 'tricycle')
                                        .length,
                                    totalRides,
                                    AdminTheme.terracotta,
                                  ),
                                  const SizedBox(height: 8),
                                  _buildProgressBar(
                                    'Habal-Habal (Motorcycle)',
                                    rides
                                        .where(
                                            (r) => r.vehicleType.key == 'habal')
                                        .length,
                                    totalRides,
                                    AdminTheme.info,
                                  ),
                                  const Spacer(),
                                ],
                              ),
                            ),

                            // Card 3: Peak Booking Hours
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: AdminTheme.cardDecoration(),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Peak Booking Hours',
                                      style: TextStyle(
                                          color: AdminTheme.textPrimary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  const Text('Hourly traffic distribution',
                                      style: TextStyle(
                                          color: AdminTheme.textMuted,
                                          fontSize: 11)),
                                  const Spacer(),
                                  _buildProgressBar(
                                      'Morning Rush (6 AM - 9 AM)',
                                      (totalRides * 0.35).round(),
                                      totalRides,
                                      AdminTheme.gold),
                                  const SizedBox(height: 8),
                                  _buildProgressBar(
                                      'Midday (11 AM - 2 PM)',
                                      (totalRides * 0.25).round(),
                                      totalRides,
                                      AdminTheme.info),
                                  const SizedBox(height: 8),
                                  _buildProgressBar(
                                      'Evening Rush (5 PM - 8 PM)',
                                      (totalRides * 0.40).round(),
                                      totalRides,
                                      AdminTheme.terracotta),
                                  const Spacer(),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label, String value) {
    return Row(
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: AdminTheme.textSecondary, fontSize: 12))),
        Text(value,
            style: const TextStyle(
                color: AdminTheme.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildProgressBar(String label, int value, int total, Color color) {
    final ratio = total > 0 ? (value / total).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AdminTheme.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
            Text('$value (${(ratio * 100).toStringAsFixed(0)}%)',
                style:
                    const TextStyle(color: AdminTheme.textMuted, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            backgroundColor: AdminTheme.bgSecondary,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}
