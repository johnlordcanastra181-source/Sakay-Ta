import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../main.dart' hide Brand, Avatar;
import '../models/trip.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/passenger_bottom_nav.dart';
import '../widgets/submit_report_dialog.dart';
import '../widgets/ride_details_modal.dart';
import '../widgets/user_avatar.dart';

class MyRides extends StatefulWidget {
  const MyRides({super.key, required this.onNavigate});
  final Function(AppScreen) onNavigate;

  @override
  State<MyRides> createState() => _MyRidesState();
}

class _MyRidesState extends State<MyRides> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String _historyFilter = 'all';
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
    final key = '${user.id}|${user.isDriver}|$_historyFilter';
    if (_historyStream == null || _historyStreamKey != key) {
      _historyStreamKey = key;
      _historyStream = app.rideHistoryStream(status: _historyFilter);
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
      backgroundColor: AppColors.canvasColor(isDark),
      body: SafeArea(
        child: Column(
          children: [
            // Top Header: Brand (Logo + Sakay Ta) on left, Profile Avatar on right
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: AppColors.cardColor(isDark),
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
                          radius: 18,
                          border: Border.all(
                              color:
                                  isDark ? AppColors.darkBorder : Colors.white,
                              width: 2),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: const Color(0xFF059669),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: isDark
                                      ? AppColors.darkCard
                                      : Colors.white,
                                  width: 1.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Tab Bar: "Upcoming" & "History" with Golden/Olive Underline
            Container(
              color: AppColors.cardColor(isDark),
              child: TabBar(
                controller: _tabController,
                indicatorColor: isDark ? AppColors.gold : AppColors.terracotta,
                indicatorWeight: 3,
                labelColor: isDark ? AppColors.gold : AppColors.terracotta,
                unselectedLabelColor: AppColors.subtextColor(isDark),
                labelStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                tabs: [
                  Tab(text: l10n.ridesUpcoming),
                  Tab(text: l10n.ridesHistory),
                ],
              ),
            ),

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
          // Vehicle Outline Icon in muted Gold/Beige
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.gold.withValues(alpha: 0.15)
                  : const Color(0xFFFBF4E6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.directions_car_outlined,
              size: 40,
              color: isDark ? AppColors.gold : const Color(0xFFC5A059),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            l10n.ridesEmptyUpcoming,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textColor(isDark),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            l10n.ridesEmptyUpcomingSubtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.subtextColor(isDark),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.terracotta,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => widget.onNavigate(AppScreen.passengerHome),
              child: Text(
                l10n.bookingBookNow,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveRideCard(Trip trip, AppState app) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSearching = trip.status == RideStatus.searching;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardColor(isDark),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark
              ? AppColors.gold.withValues(alpha: 0.3)
              : const Color(0xFF6E5600).withValues(alpha: 0.25),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: isSearching
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF059669),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isSearching
                        ? 'LOOKING FOR DRIVER'
                        : 'ACTIVE RIDE: ${trip.status.toUpperCase()}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: isSearching
                          ? const Color(0xFFD97706)
                          : const Color(0xFF059669),
                    ),
                  ),
                ],
              ),
              Text(
                '₱${trip.fare.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textColor(isDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Route Details
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  const Icon(Icons.circle, color: Color(0xFF059669), size: 12),
                  Container(
                      width: 2,
                      height: 26,
                      color: AppColors.borderColor(isDark)),
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
                          color: AppColors.textColor(isDark)),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      trip.dropoffAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textColor(isDark)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Vehicle & Payment badges
          Row(
            children: [
              _badge(
                trip.vehicleType == VehicleType.tricycle
                    ? 'TRICYCLE'
                    : 'HABAL-HABAL',
                isDark ? AppColors.gold : const Color(0xFF6E5600),
              ),
              const SizedBox(width: 6),
              _badge(
                trip.paymentMethod.toUpperCase(),
                const Color(0xFF4F46E5),
              ),
              const Spacer(),
              Text(
                DateFormat('hh:mm a').format(trip.createdAt),
                style: TextStyle(
                    fontSize: 11, color: AppColors.subtextColor(isDark)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.terracotta,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => widget.onNavigate(AppScreen.tracking),
                  icon: const Icon(Icons.navigation_rounded, size: 18),
                  label: const Text('Track Ride'),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                  side: const BorderSide(color: Color(0xFFEF4444)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Cancel Ride?'),
                      content: const Text(
                          'Are you sure you want to cancel this booking?'),
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
                child: const Text('Cancel'),
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
    return Column(
      children: [
        // Filter Chips
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
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
            initialData: const [],
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final rides = snapshot.data ?? const [];

              if (!(app.currentUser?.isDriver ?? false)) {
                final prompt = rides.cast<RideEntry?>().firstWhere(
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
                      Icon(Icons.receipt_long_outlined,
                          size: 48, color: AppColors.subtextColor(isDark)),
                      const SizedBox(height: 10),
                      Text(
                        l10n.ridesEmptyCompleted,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textColor(isDark)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.ridesEmptyCompletedSubtitle,
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.subtextColor(isDark)),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: rides.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _buildHistoryCard(rides[i]),
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
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          color: selected ? Colors.white : AppColors.textColor(isDark),
        ),
      ),
      selected: selected,
      selectedColor: AppColors.terracotta,
      backgroundColor:
          isDark ? AppColors.darkCardElevated : const Color(0xFFF3F4F6),
      side: BorderSide(
          color: isDark ? AppColors.borderColor(isDark) : Colors.transparent),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (_) => setState(() => _historyFilter = value),
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

    return InkWell(
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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardColor(isDark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderColor(isDark)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Vehicle Icon + Driver Name + Plate + Fare
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669)
                        .withValues(alpha: isDark ? 0.2 : 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(trip.vehicleType.icon,
                      color: isDark
                          ? const Color(0xFF10B981)
                          : const Color(0xFF059669),
                      size: 22),
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
                            color: AppColors.textColor(isDark)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${entry.plateNumber.isEmpty ? "No plate" : entry.plateNumber} • $dateFormatted',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.subtextColor(isDark)),
                      ),
                    ],
                  ),
                ),
                Text(
                  '₱${trip.fare.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: isDark ? AppColors.gold : const Color(0xFFD97706),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Route text
            Text(
              '${trip.pickupAddress} → ${trip.dropoffAddress}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.subtextColor(isDark),
                fontWeight: FontWeight.w500,
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
                      ? const Color(0xFF059669)
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
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
