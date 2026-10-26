import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../l10n/app_localizations.dart';
import '../main.dart' hide Brand, Avatar;
import '../models/trip.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/passenger_bottom_nav.dart';
import '../widgets/submit_report_dialog.dart';
import '../widgets/ride_details_modal.dart';
import '../widgets/user_avatar.dart';
import '../core/neumorphic_theme.dart';
import '../widgets/neumorphic_widgets.dart';

class MyRides extends StatefulWidget {
  const MyRides({super.key, required this.onNavigate});
  final Function(AppScreen) onNavigate;

  @override
  State<MyRides> createState() => _MyRidesState();
}

class _MyRidesState extends State<MyRides> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String _historyFilter = 'all';
  int _visibleHistoryCount = 20;
  Stream<Trip?>? _upcomingStream;
  String? _upcomingStreamKey;
  Stream<List<RideEntry>>? _historyStream;
  String? _historyStreamKey;
  final Set<String> _promptedRatingRideIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Stream<Trip?> _stableUpcomingStream(AppState app) {
    final user = app.currentUser!;
    final key = '${user.id}|${user.isDriver}';
    if (_upcomingStream == null || _upcomingStreamKey != key) {
      _upcomingStreamKey = key;
      _upcomingStream = user.isDriver
          ? app.streamActiveTripForDriver(user.id)
          : app.streamActiveTripForPassenger(user.id);
    }
    return _upcomingStream!;
  }

  Stream<List<RideEntry>> _stableHistoryStream(AppState app) {
    final user = app.currentUser!;
    final key = '${user.id}|${user.isDriver}';
    if (_historyStream == null || _historyStreamKey != key) {
      _historyStreamKey = key;
      _historyStream = app.rideHistoryStream();
    }
    return _historyStream!;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final app = context.watch<AppState>();
    final isDark =
        app.darkMode || Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: NeumorphicColors.canvas(isDark),
      body: SafeArea(
        child: Column(
          children: [
            // Top Header: Brand on left, Profile Avatar on right
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Brand(dark: isDark, size: 30),
                  GestureDetector(
                    onTap: () => widget.onNavigate(AppScreen.profile),
                    child: Stack(
                      children: [
                        UserAvatar(
                          photoUrl: app.currentUser?.profilePhotoUrl,
                          name: app.currentUser?.fullName ?? 'Passenger',
                          avatarColorIndex: app.currentUser?.avatarColor ?? 0,
                          radius: 19,
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF2E3D56)
                                : Colors.white,
                            width: 2,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark
                                    ? NeumorphicColors.canvas(isDark)
                                    : Colors.white,
                                width: 1.5,
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

            // Segmented Neumorphic Tab Bar: "Upcoming" & "History"
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              padding: const EdgeInsets.all(4),
              decoration: NeumorphicDecorations.inset(
                isDark: isDark,
                radius: 24,
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: isDark ? const Color(0xFF26334D) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: NeumorphicColors.shadowDark(isDark),
                      offset: const Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: NeumorphicColors.brandPrimary,
                unselectedLabelColor: NeumorphicColors.textSecondary(isDark),
                labelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                tabs: [
                  Tab(text: l10n.ridesUpcoming),
                  Tab(text: l10n.ridesHistory),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildUpcomingTab(app, l10n),
                  _buildHistoryTab(app, l10n),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: PassengerBottomNav(
        currentIndex: 1,
        onNavigate: widget.onNavigate,
      ),
    );
  }

  // --- UPCOMING TAB ---
  Widget _buildUpcomingTab(AppState app, AppLocalizations l10n) {
    final user = app.currentUser;
    if (user == null) {
      return _buildEmptyUpcoming(l10n);
    }

    return StreamBuilder<Trip?>(
      stream: _stableUpcomingStream(app),
      initialData: app.activeTrip,
      builder: (context, snap) {
        final activeTrip = snap.data;
        final hasActiveUpcoming = activeTrip != null &&
            (activeTrip.isActive || activeTrip.status == RideStatus.searching);

        if (!hasActiveUpcoming) {
          return _buildEmptyUpcoming(l10n);
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildActiveRideCard(activeTrip, app),
          ],
        );
      },
    );
  }

  Widget _buildEmptyUpcoming(AppLocalizations l10n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: NeumorphicDecorations.inset(
              isDark: isDark,
              radius: 38,
            ),
            child: const Icon(
              Icons.directions_car_outlined,
              size: 40,
              color: NeumorphicColors.brandPrimary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.ridesEmptyUpcoming,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: NeumorphicColors.textPrimary(isDark),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            l10n.ridesEmptyUpcomingSubtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: NeumorphicColors.textSecondary(isDark),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          NeumorphicButton(
            text: l10n.bookingBookNow,
            icon: Icons.add_location_alt_outlined,
            onPressed: () => widget.onNavigate(AppScreen.passengerHome),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveRideCard(Trip trip, AppState app) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSearching = trip.status == RideStatus.searching;

    return NeumorphicCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: NeumorphicDecorations.pill(
                  isDark: isDark,
                  color: isSearching
                      ? const Color(0xFFD97706).withValues(alpha: 0.15)
                      : const Color(0xFF059669).withValues(alpha: 0.15),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isSearching
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isSearching
                          ? 'LOOKING FOR DRIVER'
                          : 'ACTIVE RIDE: ${trip.status.toUpperCase()}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isSearching
                            ? const Color(0xFFD97706)
                            : const Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '₱${trip.fare.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: NeumorphicColors.textPrimary(isDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Route Details
          Container(
            padding: const EdgeInsets.all(12),
            decoration: NeumorphicDecorations.inset(
              isDark: isDark,
              radius: 14,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    const Icon(Icons.circle,
                        color: Color(0xFF10B981), size: 12),
                    Container(
                        width: 2,
                        height: 24,
                        color: NeumorphicColors.border(isDark)),
                    const Icon(Icons.location_on,
                        color: Color(0xFFDC2626), size: 14),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip.pickupAddress,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: NeumorphicColors.textPrimary(isDark)),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        trip.dropoffAddress,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: NeumorphicColors.textPrimary(isDark)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Vehicle & Payment badges
          Row(
            children: [
              _badge(
                trip.vehicleType == VehicleType.tricycle
                    ? 'TRICYCLE'
                    : 'HABAL-HABAL',
                isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
              ),
              const SizedBox(width: 6),
              _badge(
                trip.paymentMethod.toUpperCase(),
                const Color(0xFF3B82F6),
              ),
              const Spacer(),
              Text(
                DateFormat('hh:mm a').format(trip.createdAt),
                style: TextStyle(
                    fontSize: 11,
                    color: NeumorphicColors.textSecondary(isDark)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: NeumorphicButton(
                  text: 'Track Ride',
                  icon: Icons.navigation_rounded,
                  onPressed: () => widget.onNavigate(AppScreen.tracking),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 110,
                child: NeumorphicButton(
                  text: 'Cancel',
                  isSecondary: true,
                  accentColor: const Color(0xFFDC2626),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: NeumorphicColors.card(isDark),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        title: Text('Cancel Ride?',
                            style: TextStyle(
                                color: NeumorphicColors.textPrimary(isDark))),
                        content: Text(
                            'Are you sure you want to cancel this booking?',
                            style: TextStyle(
                                color: NeumorphicColors.textSecondary(isDark))),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Keep Ride'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDC2626),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Cancel Booking'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await app.cancelActiveTrip();
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- HISTORY TAB ---
  Widget _buildHistoryTab(AppState app, AppLocalizations l10n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (app.currentUser == null) {
      return _buildEmptyUpcoming(l10n);
    }
    return Column(
      children: [
        // Filter Chips
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              _filterChip(l10n.walletFilterAll, 'all'),
              const SizedBox(width: 8),
              _filterChip(l10n.ridesCompleted, RideStatus.completed),
              const SizedBox(width: 8),
              _filterChip(l10n.ridesCancelled, RideStatus.cancelled),
            ],
          ),
        ),

        // History Stream List
        Expanded(
          child: StreamBuilder<List<RideEntry>>(
            stream: _stableHistoryStream(app),
            initialData: app.getCachedRideHistory(),
            builder: (context, snapshot) {
              final hasLoadedData = snapshot.data != null;
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !hasLoadedData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError && !hasLoadedData) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          size: 40,
                          color: NeumorphicColors.textSecondary(isDark),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Unable to load ride history.',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: NeumorphicColors.textPrimary(isDark),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _historyStream = null;
                            });
                          },
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final allRides = snapshot.data ?? const <RideEntry>[];
              final rides = (_historyFilter == 'all')
                  ? allRides
                  : allRides
                      .where((e) => e.trip.status == _historyFilter)
                      .toList();

              if (!(app.currentUser?.isDriver ?? false)) {
                final prompt = allRides.cast<RideEntry?>().firstWhere(
                  (entry) {
                    if (entry == null ||
                        entry.trip.status != RideStatus.completed ||
                        entry.trip.rating != null ||
                        _promptedRatingRideIds.contains(entry.trip.id)) {
                      return false;
                    }
                    final completedAt =
                        entry.trip.completedAt ?? entry.trip.createdAt;
                    return DateTime.now().difference(completedAt).inHours < 24;
                  },
                  orElse: () => null,
                );
                if (prompt != null) {
                  _promptedRatingRideIds.add(prompt.trip.id);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      _showRateDialog(
                        prompt.trip.id,
                        prompt.driverName.isEmpty
                            ? 'Driver'
                            : prompt.driverName,
                        driverPhotoUrl: prompt.driverPhotoUrl,
                        driverAvatarColor: prompt.driverAvatarColor,
                        vehicleLabel:
                            prompt.trip.vehicleType == VehicleType.habal
                                ? 'Motorcycle'
                                : 'Tricycle',
                      );
                    }
                  });
                }
              }

              if (rides.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: NeumorphicDecorations.inset(
                          isDark: isDark,
                          radius: 32,
                        ),
                        child: Icon(Icons.receipt_long_outlined,
                            size: 32,
                            color: NeumorphicColors.textSecondary(isDark)),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        l10n.ridesEmptyCompleted,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: NeumorphicColors.textPrimary(isDark)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.ridesEmptyCompletedSubtitle,
                        style: TextStyle(
                            fontSize: 13,
                            color: NeumorphicColors.textSecondary(isDark)),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              final visibleRides = rides.take(_visibleHistoryCount).toList();
              final hasMore = rides.length > visibleRides.length;

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: visibleRides.length + (hasMore ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  if (i == visibleRides.length) {
                    return Center(
                      child: TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _visibleHistoryCount += 20;
                          });
                        },
                        icon: const Icon(Icons.expand_more_rounded),
                        label: Text(
                            'Load More (${rides.length - visibleRides.length} more)'),
                      ),
                    );
                  }
                  return _buildHistoryCard(visibleRides[i]);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = _historyFilter == value;
    return GestureDetector(
      onTap: () => setState(() {
        _historyFilter = value;
        _visibleHistoryCount = 20;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: NeumorphicDecorations.pill(
          isDark: isDark,
          isSelected: selected,
          activeColor: NeumorphicColors.brandPrimary,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            color: selected
                ? Colors.white
                : NeumorphicColors.textSecondary(isDark),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryCard(RideEntry entry) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trip = entry.trip;
    final isCompleted = trip.status == RideStatus.completed;
    final canRate = isCompleted &&
        trip.rating == null &&
        !(context.read<AppState>().currentUser?.isDriver ?? false);

    final dateFormatted = DateFormat('dd/MM/yyyy • hh:mm a')
        .format(trip.completedAt ?? trip.createdAt);

    return NeumorphicCard(
      padding: const EdgeInsets.all(16),
      onTap: () {
        RideDetailsModal.show(
          context,
          entry: entry,
          onRateTrip: canRate
              ? () => _showRateDialog(
                    trip.id,
                    entry.driverName.isEmpty ? 'Driver' : entry.driverName,
                    driverPhotoUrl: entry.driverPhotoUrl,
                    driverAvatarColor: entry.driverAvatarColor,
                    vehicleLabel: trip.vehicleType == VehicleType.habal
                        ? 'Motorcycle'
                        : 'Tricycle',
                  )
              : null,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Vehicle Icon + Driver Name + Plate + Fare
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: NeumorphicDecorations.inset(
                  isDark: isDark,
                  radius: 21,
                ),
                child: Icon(
                  trip.vehicleType.icon,
                  color: const Color(0xFF10B981),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.driverName.isEmpty
                          ? 'Driver assignment pending'
                          : entry.driverName,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: NeumorphicColors.textPrimary(isDark)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${entry.plateNumber.isEmpty ? "No plate" : entry.plateNumber} • $dateFormatted',
                      style: TextStyle(
                          fontSize: 11,
                          color: NeumorphicColors.textSecondary(isDark)),
                    ),
                  ],
                ),
              ),
              Text(
                '₱${trip.fare.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: NeumorphicColors.brandPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Route text
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: NeumorphicDecorations.inset(
              isDark: isDark,
              radius: 10,
            ),
            child: Row(
              children: [
                const Icon(Icons.route_rounded,
                    size: 16, color: NeumorphicColors.brandPrimary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${trip.pickupAddress} → ${trip.dropoffAddress}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: NeumorphicColors.textSecondary(isDark),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Badges & Rating
          Row(
            children: [
              _badge(
                  trip.paymentMethod.toUpperCase(), const Color(0xFF3B82F6)),
              const SizedBox(width: 6),
              _badge(
                trip.status.toUpperCase(),
                isCompleted
                    ? const Color(0xFF10B981)
                    : const Color(0xFFDC2626),
              ),
              const Spacer(),
              if (trip.rating != null)
                Row(
                  children: List.generate(
                    5,
                    (i) => Icon(
                      i < trip.rating!
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 16,
                      color: const Color(0xFFF59E0B),
                    ),
                  ),
                ),
            ],
          ),

          if (canRate) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _showRateDialog(
                  trip.id,
                  entry.driverName.isEmpty ? 'Driver' : entry.driverName,
                  driverPhotoUrl: entry.driverPhotoUrl,
                  driverAvatarColor: entry.driverAvatarColor,
                  vehicleLabel: trip.vehicleType == VehicleType.habal
                      ? 'Motorcycle'
                      : 'Tricycle',
                ),
                icon: const Icon(Icons.star_outline_rounded,
                    size: 16, color: Color(0xFFD97706)),
                label: const Text(
                  'Rate this trip',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFD97706)),
                ),
              ),
            ),
          ],
          if (trip.status == RideStatus.completed ||
              trip.status == RideStatus.cancelled) ...[
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  final viewerIsDriver =
                      context.read<AppState>().currentUser?.isDriver ??
                          false;
                  showSubmitReportDialog(
                    context,
                    dialogTitle: 'Report Ride Issue',
                    rideId: trip.id,
                    reportedUserId:
                        viewerIsDriver ? trip.passengerId : trip.driverId,
                    reportedUserName: viewerIsDriver
                        ? trip.passengerName
                        : (entry.driverName.isEmpty
                            ? null
                            : entry.driverName),
                    reportedUserRole:
                        viewerIsDriver ? 'passenger' : 'driver',
                  );
                },
                icon: const Icon(Icons.flag_outlined,
                    size: 16, color: Color(0xFFDC2626)),
                label: const Text(
                  'Report issue',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFDC2626)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showRateDialog(
    String tripId,
    String driverName, {
    String? driverPhotoUrl,
    int driverAvatarColor = 0,
    required String vehicleLabel,
  }) async {
    final submission = await showDialog<_RatingSubmission>(
      context: context,
      builder: (_) => _RateDialog(
        driverName: driverName,
        driverPhotoUrl: driverPhotoUrl,
        driverAvatarColor: driverAvatarColor,
        vehicleLabel: vehicleLabel,
      ),
    );
    if (submission == null) return;
    final app = context.read<AppState>();
    try {
      await app.rateTrip(
        tripId: tripId,
        rating: submission.stars,
        comment: submission.comment,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thanks! Your rating has been saved.'),
            backgroundColor: Color(0xFF059669),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to save the rating. Please try again.'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: NeumorphicDecorations.pill(
          isDark: Theme.of(context).brightness == Brightness.dark,
          color: color.withValues(alpha: 0.12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
}

class _RatingSubmission {
  const _RatingSubmission({required this.stars, required this.comment});

  final int stars;
  final String comment;
}

class _RateDialog extends StatefulWidget {
  const _RateDialog({
    required this.driverName,
    required this.vehicleLabel,
    this.driverPhotoUrl,
    this.driverAvatarColor = 0,
  });
  final String driverName;
  final String vehicleLabel;
  final String? driverPhotoUrl;
  final int driverAvatarColor;

  @override
  State<_RateDialog> createState() => _RateDialogState();
}

class _RateDialogState extends State<_RateDialog> {
  int _stars = 5;
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          UserAvatar(
            photoUrl: widget.driverPhotoUrl,
            name: widget.driverName,
            avatarColorIndex: widget.driverAvatarColor,
            radius: 24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rate ${widget.driverName}'),
                const SizedBox(height: 2),
                Text(
                  widget.vehicleLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final star = i + 1;
              return IconButton(
                onPressed: () => setState(() => _stars = star),
                icon: Icon(
                  i < _stars ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 36,
                  color: const Color(0xFFF59E0B),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _comment,
            maxLength: 200,
            decoration: const InputDecoration(
              hintText: 'Add a comment (optional)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6E5600),
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(context).pop(
            _RatingSubmission(
              stars: _stars,
              comment: _comment.text.trim(),
            ),
          ),
          child: const Text('Submit Rating'),
        ),
      ],
    );
  }
}
