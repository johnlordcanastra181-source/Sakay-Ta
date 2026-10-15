import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../core/time_utils.dart';
import '../main.dart' hide Brand, Avatar;
import '../models/app_user.dart';
import '../models/firestore_models.dart';
import '../models/trip.dart';
import '../services/driver_earnings_summary.dart';
import '../services/supabase_service.dart';
import '../state/app_state.dart';
import '../widgets/connectivity_banner.dart';
import '../widgets/driver_osm_card.dart';
import '../widgets/user_avatar.dart';
import '../widgets/weather_badge.dart';

class DriverHome extends StatefulWidget {
  const DriverHome({super.key, required this.onNavigate});
  final Function(AppScreen) onNavigate;

  @override
  State<DriverHome> createState() => _DriverHomeState();
}

class _DriverHomeState extends State<DriverHome> with TickerProviderStateMixin {
  Timer? _clockTimer;
  AnimationController? _countdownController;
  String? _currentRequestId;
  bool _isProcessingAccept = false;
  bool _isProcessingPickupArrival = false;
  bool _isProcessingStart = false;
  bool _isProcessingComplete = false;
  List<IncomingRideRequest> _lastIncomingRequests = const [];
  Stream<List<IncomingRideRequest>>? _incomingRequestStream;
  String? _incomingRequestStreamKey;
  Stream<AppUser?>? _userStream;
  String? _userStreamKey;
  Stream<DriverDailyEarningsSummary>? _driverDailyEarningsStream;
  String? _driverDailyEarningsStreamKey;
  Stream<Trip?>? _activeTripStream;
  String? _activeTripStreamKey;
  Stream<FirePayment?>? _paymentStream;
  String? _paymentStreamKey;
  String? _activePassengerId;
  Future<AppUser?>? _activePassengerFuture;

  @override
  void initState() {
    super.initState();
    // Periodically tick to refresh time-based greetings and stats
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        unawaited(context.read<AppState>().refreshTodayDrivingHours());
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _countdownController?.dispose();
    super.dispose();
  }

  void _startCountdownForRequest(String requestId) {
    if (_currentRequestId == requestId && _countdownController != null) return;
    _currentRequestId = requestId;
    _countdownController?.dispose();
    _countdownController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 35),
    );
    _countdownController!.forward();
  }

  Stream<List<IncomingRideRequest>> _stableIncomingStream(
    AppState app,
    AppUser user,
    Trip? activeTrip,
  ) {
    final canReceive = user.isOnline &&
        (activeTrip == null || activeTrip.status == RideStatus.searching);
    final key = '${user.id}|$canReceive|${activeTrip?.id}|'
        '${activeTrip?.status}|${activeTrip?.driverId}';
    if (_incomingRequestStream == null || _incomingRequestStreamKey != key) {
      _incomingRequestStreamKey = key;
      _incomingRequestStream = canReceive
          ? app.streamIncomingRequestsForDriver(
              user,
              assignedTrip: activeTrip,
            )
          : Stream.value(const <IncomingRideRequest>[]);
    }
    return _incomingRequestStream!;
  }

  Stream<AppUser?> _stableUserStream(AppState app, String userId) {
    if (_userStream == null || _userStreamKey != userId) {
      _userStreamKey = userId;
      _userStream = app.streamUserProfile(userId);
    }
    return _userStream!;
  }

  Stream<DriverDailyEarningsSummary> _stableDriverDailyEarningsStream(
      AppState app, String userId) {
    if (_driverDailyEarningsStream == null ||
        _driverDailyEarningsStreamKey != userId) {
      _driverDailyEarningsStreamKey = userId;
      _driverDailyEarningsStream = app.streamDriverDailyEarningsToday(userId);
    }
    return _driverDailyEarningsStream!;
  }

  Stream<Trip?> _stableActiveTripStream(AppState app, String userId) {
    if (_activeTripStream == null || _activeTripStreamKey != userId) {
      _activeTripStreamKey = userId;
      _activeTripStream = app.streamActiveTripForDriver(userId);
    }
    return _activeTripStream!;
  }

  Stream<FirePayment?> _stablePaymentStream(String rideId) {
    if (_paymentStream == null || _paymentStreamKey != rideId) {
      _paymentStreamKey = rideId;
      _paymentStream = SupabaseService.isConfigured
          ? SupabaseService.instance.streamPaymentForRide(rideId)
          : const Stream<FirePayment?>.empty();
    }
    return _paymentStream!;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final isDark =
        app.darkMode || Theme.of(context).brightness == Brightness.dark;
    String? currentId;
    try {
      currentId = Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {}
    final resolvedId = currentId ?? app.currentUser?.id;

    if (resolvedId == null) {
      return Scaffold(
        backgroundColor: AppColors.canvasColor(isDark),
        body: Center(
          child: Text(
            'Sign in to start driving.',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textColor(isDark),
            ),
          ),
        ),
      );
    }
    final id = resolvedId;

    return StreamBuilder<AppUser?>(
      stream: _stableUserStream(app, id),
      initialData: app.currentUser,
      builder: (context, userSnapshot) {
        if (userSnapshot.hasError) {
          debugPrint(
              '[SakayTa][ERROR][DriverHome] user stream error: ${userSnapshot.error}');
          final fallbackUser = app.currentUser;
          if (fallbackUser == null) {
            return Scaffold(
              backgroundColor: AppColors.canvasColor(isDark),
              body: Center(
                child: Text('Your driver session needs to be refreshed.',
                    style: TextStyle(
                        fontSize: 15, color: AppColors.subtextColor(isDark))),
              ),
            );
          }
          return _scaffold(context, fallbackUser, 0, 0, app.todayDrivingHours,
              app.activeTrip, const [], null, null);
        }

        final user = userSnapshot.data ?? app.currentUser;
        if (user == null) {
          return Scaffold(
            backgroundColor: AppColors.canvasColor(isDark),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        return StreamBuilder<DriverDailyEarningsSummary>(
          stream: _stableDriverDailyEarningsStream(app, id),
          initialData: const DriverDailyEarningsSummary(earnings: 0, trips: 0),
          builder: (context, earningsSnapshot) {
            final dailySummary = earningsSnapshot.data ??
                const DriverDailyEarningsSummary(earnings: 0, trips: 0);
            final todayFare = dailySummary.earnings;
            final todayTrips = dailySummary.trips;

            return StreamBuilder<Trip?>(
              stream: _stableActiveTripStream(app, id),
              builder: (context, activeTripSnapshot) {
                final activeTrip = activeTripSnapshot.data;

                return StreamBuilder<List<IncomingRideRequest>>(
                  stream: _stableIncomingStream(app, user, activeTrip),
                  initialData: activeTrip != null &&
                          activeTrip.status == RideStatus.searching &&
                          activeTrip.driverId == user.id
                      ? [app.incomingRequestFallback(activeTrip, user)]
                      : _lastIncomingRequests,
                  builder: (context, incomingSnapshot) {
                    var incomingRequests =
                        incomingSnapshot.data ?? _lastIncomingRequests;
                    if (incomingSnapshot.hasData &&
                        incomingSnapshot.connectionState !=
                            ConnectionState.waiting) {
                      _lastIncomingRequests = incomingRequests;
                    } else if (incomingRequests.isEmpty &&
                        _lastIncomingRequests.isNotEmpty) {
                      incomingRequests = _lastIncomingRequests;
                    }
                    return _scaffold(
                      context,
                      user,
                      todayFare,
                      todayTrips,
                      app.todayDrivingHours,
                      activeTrip,
                      incomingRequests,
                      incomingSnapshot.error,
                      earningsSnapshot.error,
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _scaffold(
    BuildContext context,
    AppUser user,
    double todayFare,
    int todayTrips,
    double todayHours,
    Trip? activeTrip,
    List<IncomingRideRequest> incomingRequests,
    Object? streamError,
    Object? dataError,
  ) {
    final isDark = context.watch<AppState>().darkMode ||
        Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: AppColors.canvasColor(isDark),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            _buildTopBar(context, user),
            const SizedBox(height: 10),
            const ConnectivityBanner(compact: true),
            const SizedBox(height: 14),
            _buildGreetingAndToggle(context, user),
            const SizedBox(height: 20),
            _buildEarningsCard(todayFare, todayTrips, todayHours),
            if (dataError != null) ...[
              const SizedBox(height: 8),
              _buildDashboardDataError(context, dataError),
            ],
            const SizedBox(height: 20),
            DriverOsmCard(
              height: 190,
              isOnline: user.isOnline,
            ),
            const SizedBox(height: 24),
            _buildIncomingSection(
              context,
              user,
              activeTrip,
              incomingRequests,
              streamError,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildDashboardDataError(BuildContext context, Object error) {
    debugPrint('[SakayTa][DriverHome] earnings ledger error: $error');
    final isDark = context.watch<AppState>().darkMode ||
        Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF451A03) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF92400E) : const Color(0xFFF59E0B),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded,
              size: 17,
              color:
                  isDark ? const Color(0xFFFBBF24) : const Color(0xFF92400E)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Unable to load earnings activity right now.',
              style: TextStyle(
                fontSize: 12,
                color:
                    isDark ? const Color(0xFFFDE68A) : const Color(0xFF78350F),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              _driverDailyEarningsStream = null;
              _driverDailyEarningsStreamKey = null;
              if (mounted) setState(() {});
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // --- Top Navigation Bar with Brand and Driver Photo ---
  Widget _buildTopBar(BuildContext context, AppUser user) {
    final isDark = context.watch<AppState>().darkMode ||
        Theme.of(context).brightness == Brightness.dark;
    final driverProfile = context.read<AppState>().driverProfile;
    // Prefer the profile photo set from the in-app Edit Profile flow, falling
    // back to the photo uploaded during driver registration.
    final photoUrl =
        (user.profilePhotoUrl != null && user.profilePhotoUrl!.isNotEmpty)
            ? user.profilePhotoUrl
            : driverProfile?.docProfile;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Brand logo and title
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: Color(0xFF1E2B45),
                shape: BoxShape.circle,
              ),
              child: const Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    bottom: 2,
                    child: Icon(
                      Icons.location_on_rounded,
                      size: 24,
                      color: Color(0xFF142036),
                    ),
                  ),
                  Icon(
                    Icons.electric_rickshaw_rounded,
                    size: 19,
                    color: Color(0xFFFFD600),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Sakay Ta',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: isDark ? AppColors.gold : const Color(0xFF6E5600),
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),

        // Weather Badge and Avatar on right
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: WeatherBadge(
                  location: (user.latitude != null && user.longitude != null)
                      ? Geo(user.latitude!, user.longitude!)
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              UserAvatar(
                photoUrl: photoUrl,
                name: user.fullName,
                avatarColorIndex: user.avatarColor,
                radius: 18,
                border: Border.all(
                    color: isDark ? AppColors.darkBorder : Colors.white,
                    width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
                onTap: () => widget.onNavigate(AppScreen.profile),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Dynamic Greeting & Real Online Toggle ---
  Widget _buildGreetingAndToggle(BuildContext context, AppUser user) {
    final isDark = context.watch<AppState>().darkMode ||
        Theme.of(context).brightness == Brightness.dark;
    final firstName = user.fullName.trim().split(' ').first;
    final greeting = TimeGreeting.getGreeting();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting, $firstName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textColor(isDark),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                user.isOnline
                    ? 'Ready for your next trip?'
                    : 'You are currently offline',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: user.isOnline
                      ? AppColors.subtextColor(isDark)
                      : (isDark
                          ? const Color(0xFF64748B)
                          : const Color(0xFF94A3B8)),
                ),
              ),
            ],
          ),
        ),

        // Online Switch with Online/Offline indicator label
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Transform.scale(
              scale: 0.88,
              child: Switch(
                value: user.isOnline,
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.emerald,
                inactiveThumbColor: Colors.white,
                inactiveTrackColor:
                    isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                onChanged: (online) async {
                  try {
                    // Start loading state implicitly by awaiting
                    await context.read<AppState>().setOnline(online);
                  } on AuthException catch (e, stackTrace) {
                    debugPrint('[DriverStatus][Firebase] '
                        'code=${e.code} message=${e.message}');
                    debugPrintStack(stackTrace: stackTrace);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Unable to update online status. Check your connection.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  } catch (e, stackTrace) {
                    debugPrint('[DriverStatus][ERROR] '
                        '${e.runtimeType}: $e');
                    debugPrintStack(stackTrace: stackTrace);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Unable to update online status. Check your connection.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(
                user.isOnline ? 'Online' : 'Offline',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: user.isOnline
                      ? AppColors.emerald
                      : (isDark
                          ? const Color(0xFF64748B)
                          : const Color(0xFF94A3B8)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- Today's Earnings Card Matching Reference Design ---
  Widget _buildEarningsCard(double fareAmount, int trips, double hours) {
    final isDark = context.watch<AppState>().darkMode ||
        Theme.of(context).brightness == Brightness.dark;
    final formatter = NumberFormat('#,##0.00', 'en_US');
    final formattedTotal = formatter.format(fareAmount);
    final parts = formattedTotal.split('.');
    final integerPart = parts[0];
    final decimalPart = parts.length > 1 ? parts[1] : '00';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardColor(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor(isDark), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: TODAY'S EARNINGS + Trending Up Arrow
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "TODAY'S EARNINGS",
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: AppColors.subtextColor(isDark),
                ),
              ),
              Icon(
                Icons.trending_up_rounded,
                color: isDark
                    ? AppColors.gold
                    : const Color(0xFFB45309), // Amber/Mustard arrow
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Big bold Peso Amount: ₱ 1,250.00
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '₱ ',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textColor(isDark),
                ),
              ),
              Text(
                integerPart,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textColor(isDark),
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                '.$decimalPart',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.subtextColor(isDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Two Sub-cards: Trips & Hours
          Row(
            children: [
              // Trips Box
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkCardElevated
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderColor(isDark)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trips',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.subtextColor(isDark),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$trips',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textColor(isDark),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Hours Box
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkCardElevated
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderColor(isDark)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hours',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.subtextColor(isDark),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hours.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textColor(isDark),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Incoming Request / Active Trip Section ---
  Widget _buildIncomingSection(
    BuildContext context,
    AppUser user,
    Trip? activeTrip,
    List<IncomingRideRequest> incomingRequests,
    Object? streamError,
  ) {
    final isDark = context.watch<AppState>().darkMode ||
        Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          activeTrip != null && activeTrip.status != RideStatus.searching
              ? 'Active Trip'
              : 'Incoming Request',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textColor(isDark),
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 12),
        if (streamError != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Error connecting to ride requests.\n$streamError',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          )
        // If driver has an active trip already in accepted/started status
        else if (activeTrip != null &&
            activeTrip.status != RideStatus.searching)
          _buildActiveTripCard(context, activeTrip)
        // If an incoming real-time ride request is received
        else if (incomingRequests.isNotEmpty)
          _buildIncomingRequestCard(context, incomingRequests.first)
        // If driver is online and waiting for requests
        else if (user.isOnline)
          _buildWaitingCard()
        // If driver is offline
        else
          _buildOfflineCard(context),
      ],
    );
  }

  // --- Real-Time Incoming Request Card Matching Reference Design ---
  Widget _buildIncomingRequestCard(
    BuildContext context,
    IncomingRideRequest request,
  ) {
    final isDark = context.watch<AppState>().darkMode ||
        Theme.of(context).brightness == Brightness.dark;
    final trip = request.trip;
    _startCountdownForRequest(trip.id);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardColor(isDark),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderColor(isDark), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Passenger Avatar, Name, Rating & Est. Fare
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0),
                        border: Border.all(
                            color: isDark ? AppColors.darkBorder : Colors.white,
                            width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: UserAvatar(
                        photoUrl: request.passengerPhoto,
                        name: request.passengerName,
                        radius: 22,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Passenger Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            request.passengerName.isNotEmpty
                                ? request.passengerName
                                : 'Passenger',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textColor(isDark),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.star_rounded,
                                  size: 14, color: Color(0xFFEAB308)),
                              const SizedBox(width: 2),
                              Text(
                                request.passengerTag.isNotEmpty
                                    ? request.passengerTag
                                    : 'Passenger',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.subtextColor(isDark),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Top-right Activity Badge & Estimated Fare
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 12,
                              color: AppColors.subtextColor(isDark),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'ACTIVITY',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppColors.subtextColor(isDark),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₱${trip.fare.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: isDark
                                ? AppColors.gold
                                : const Color(0xFF6E5600),
                          ),
                        ),
                        Text(
                          'Est. Fare',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.subtextColor(isDark),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Route Indicators with vertical timeline
                _buildRouteTimeline(
                  pickupLabel: 'PICKUP • ${request.durationMins} MINS AWAY',
                  pickupAddress: trip.effectivePickupAddress,
                  dropoffLabel:
                      'DROPOFF • ${trip.distanceKm > 0 ? trip.distanceKm.toStringAsFixed(1) : "4.5"} KM',
                  dropoffAddress: trip.effectiveDropoffAddress,
                ),
                const SizedBox(height: 18),

                // Decline & Accept Action Buttons
                Row(
                  children: [
                    // Decline Button
                    Expanded(
                      flex: 4,
                      child: SizedBox(
                        height: 46,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFF1F5F9),
                            foregroundColor:
                                isDark ? Colors.white : const Color(0xFF334155),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _isProcessingAccept
                              ? null
                              : () async {
                                  await context
                                      .read<AppState>()
                                      .declineTrip(trip);
                                  if (mounted) setState(() {});
                                },
                          child: const Text(
                            'Decline',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Accept Button
                    Expanded(
                      flex: 5,
                      child: SizedBox(
                        height: 46,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.terracotta,
                            foregroundColor: Colors.white,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _isProcessingAccept
                              ? null
                              : () async {
                                  setState(() {
                                    _isProcessingAccept = true;
                                  });
                                  try {
                                    final success = await context
                                        .read<AppState>()
                                        .acceptTripAtomic(trip);
                                    if (!mounted) return;
                                    setState(() {
                                      _isProcessingAccept = false;
                                    });

                                    if (success) {
                                      // The driver remains on DriverHome. Its
                                      // active-trip stream owns the one UI
                                      // transition from request to accepted.
                                    } else {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'This trip is no longer available.'),
                                          behavior: SnackBarBehavior.floating,
                                          backgroundColor: Color(0xFFDC2626),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      setState(() {
                                        _isProcessingAccept = false;
                                      });
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(e is StateError
                                              ? e.message
                                              : 'Unable to accept trip. Please try again.'),
                                          behavior: SnackBarBehavior.floating,
                                          backgroundColor:
                                              const Color(0xFFDC2626),
                                        ),
                                      );
                                    }
                                  }
                                },
                          child: _isProcessingAccept
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Accept',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    SizedBox(width: 4),
                                    Icon(Icons.arrow_forward_rounded, size: 16),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Bottom Timeout Countdown Progress Bar
          if (_countdownController != null)
            AnimatedBuilder(
              animation: _countdownController!,
              builder: (context, child) {
                return LinearProgressIndicator(
                  value: 1.0 - _countdownController!.value,
                  backgroundColor: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFF1F5F9),
                  valueColor: AlwaysStoppedAnimation<Color>(
                      isDark ? AppColors.gold : AppColors.terracotta),
                  minHeight: 4,
                );
              },
            ),
        ],
      ),
    );
  }

  // --- Route Points Timeline Widget ---
  Widget _buildRouteTimeline({
    required String pickupLabel,
    required String pickupAddress,
    required String dropoffLabel,
    required String dropoffAddress,
  }) {
    final isDark = context.watch<AppState>().darkMode ||
        Theme.of(context).brightness == Brightness.dark;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline Indicator
          Column(
            children: [
              const SizedBox(height: 3),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.gold
                      : const Color(0xFF6E5600), // Gold dot for pickup
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Container(
                  width: 2,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  color: AppColors.borderColor(isDark),
                ),
              ),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.emerald
                      : const Color(0xFF1E293B), // Dropoff indicator
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 3),
            ],
          ),
          const SizedBox(width: 14),

          // Addresses & Labels
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pickup
                Text(
                  pickupLabel,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.subtextColor(isDark),
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  pickupAddress,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textColor(isDark),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 14),

                // Dropoff
                Text(
                  dropoffLabel,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.subtextColor(isDark),
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dropoffAddress,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textColor(isDark),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Active Trip in Progress Card ---
  Widget _buildActiveTripCard(BuildContext context, Trip trip) {
    final isDark = context.watch<AppState>().darkMode ||
        Theme.of(context).brightness == Brightness.dark;
    final app = context.read<AppState>();
    final status = trip.status;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardColor(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor(isDark)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                status == RideStatus.accepted
                    ? 'Head to the pickup point'
                    : status == RideStatus.arrived
                        ? 'Waiting for passenger'
                        : 'Trip in progress',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textColor(isDark),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.gold.withValues(alpha: 0.18)
                      : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '₱${trip.fare.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.gold : const Color(0xFF92400E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildActivePassengerSummary(app, trip, isDark),
          const SizedBox(height: 14),
          _buildRouteTimeline(
            pickupLabel: 'PICKUP',
            pickupAddress: trip.effectivePickupAddress,
            dropoffLabel: 'DROPOFF',
            dropoffAddress: trip.effectiveDropoffAddress,
          ),
          const SizedBox(height: 14),

          // Real-time Payment Status Indicator for GCash / Maya
          if (trip.paymentMethod.toLowerCase() != PaymentMethod.cash)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: StreamBuilder<FirePayment?>(
                stream: _stablePaymentStream(trip.id),
                builder: (context, paySnap) {
                  final firePayment = paySnap.data;
                  final isPaid = firePayment?.status == 'paid' ||
                      trip.status == RideStatus.completed;
                  final isGcash =
                      trip.paymentMethod.toLowerCase() == PaymentMethod.gcash;
                  final providerName = isGcash ? 'GCash' : 'Maya';
                  final providerColor = isGcash
                      ? const Color(0xFF0066FF)
                      : const Color(0xFF00C389);

                  if (isPaid) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF064E3B).withValues(alpha: 0.5)
                            : const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: isDark
                                ? const Color(0xFF059669)
                                : const Color(0xFFA7F3D0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              color: Color(0xFF10B981), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '✓ $providerName payment received (Ref: ${firePayment?.reference ?? trip.id})',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? const Color(0xFFA7F3D0)
                                    : const Color(0xFF065F46),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF78350F).withValues(alpha: 0.4)
                          : const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: isDark
                              ? const Color(0xFFD97706)
                              : const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: providerColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Awaiting passenger $providerName payment (₱${trip.fare.toStringAsFixed(0)})',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? const Color(0xFFFDE68A)
                                  : const Color(0xFF92400E),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

          // Actions
          if (status == RideStatus.accepted) ...[
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _isProcessingPickupArrival
                    ? null
                    : () async {
                        setState(() => _isProcessingPickupArrival = true);
                        try {
                          final changed = await app.arriveAtPickup();
                          if (!changed && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'The ride could not be marked as arrived. Refresh and try again.'),
                              ),
                            );
                          }
                        } catch (error) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Unable to update the pickup status. Please try again.'),
                              ),
                            );
                          }
                        } finally {
                          if (mounted) {
                            setState(() => _isProcessingPickupArrival = false);
                          }
                        }
                      },
                icon: _isProcessingPickupArrival
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.location_on_rounded, size: 18),
                label: Text(
                  _isProcessingPickupArrival
                      ? 'Updating...'
                      : 'Arrived at Pickup',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ] else if (status == RideStatus.arrived) ...[
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _isProcessingStart
                    ? null
                    : () async {
                        setState(() => _isProcessingStart = true);
                        try {
                          final changed = await app.startActiveTrip();
                          if (!changed && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'The trip was not started. Refresh and try again.'),
                              ),
                            );
                          }
                        } catch (error) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Unable to start the trip. Please try again.'),
                              ),
                            );
                          }
                        } finally {
                          if (mounted) {
                            setState(() => _isProcessingStart = false);
                          }
                        }
                      },
                icon: _isProcessingStart
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.play_arrow_rounded, size: 18),
                label: Text(
                  _isProcessingStart ? 'Starting...' : 'Start Trip',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ] else if (status == RideStatus.started) ...[
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.terracotta,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _isProcessingComplete
                    ? null
                    : () async {
                        setState(() => _isProcessingComplete = true);
                        try {
                          final result = await app.completeTrip(onTime: true);
                          if (context.mounted) {
                            final confirmed =
                                result == TripCompletionResult.confirmed;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(confirmed
                                    ? 'Trip completed. Earnings recorded!'
                                    : 'Trip completed offline. Earnings will sync when you reconnect.'),
                                backgroundColor: confirmed
                                    ? const Color(0xFF16A34A)
                                    : Colors.orange,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } catch (error) {
                          if (context.mounted) {
                            final message = error
                                .toString()
                                .replaceFirst('Bad state: ', '');
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    Text('Unable to complete trip: $message'),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } finally {
                          if (mounted) {
                            setState(() => _isProcessingComplete = false);
                          }
                        }
                      },
                icon: _isProcessingComplete
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_rounded, size: 18),
                label: Text(
                  _isProcessingComplete ? 'Completing...' : 'Complete Trip',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActivePassengerSummary(AppState app, Trip trip, bool isDark) {
    if (_activePassengerId != trip.passengerId ||
        _activePassengerFuture == null) {
      _activePassengerId = trip.passengerId;
      _activePassengerFuture = SupabaseService.isConfigured
          ? SupabaseService.instance.getUser(trip.passengerId)
          : app.auth.getUser(trip.passengerId);
    }
    return FutureBuilder<AppUser?>(
      future: _activePassengerFuture,
      builder: (context, snapshot) {
        final passenger = snapshot.data;
        final name = passenger?.fullName.trim().isNotEmpty == true
            ? passenger!.fullName.trim()
            : (trip.passengerName.trim().isNotEmpty
                ? trip.passengerName.trim()
                : 'Passenger');
        final phone = passenger?.mobile.trim().isNotEmpty == true
            ? passenger!.mobile.trim()
            : trip.passengerPhone.trim();
        return Row(
          children: [
            UserAvatar(
              photoUrl: passenger?.profilePhotoUrl,
              name: name,
              avatarColorIndex: passenger?.avatarColor ?? 0,
              radius: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textColor(isDark),
                    ),
                  ),
                  Text(
                    phone.isEmpty ? 'Passenger contact unavailable' : phone,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.subtextColor(isDark),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // --- Online Waiting Card ---
  Widget _buildWaitingCard() {
    final isDark = context.watch<AppState>().darkMode ||
        Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.cardColor(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor(isDark)),
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.gold.withValues(alpha: 0.2)
                  : const Color(0xFFFEF3C7),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                Icons.radar_rounded,
                color: isDark ? AppColors.gold : const Color(0xFF6E5600),
                size: 26,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Waiting for ride requests...',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textColor(isDark),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "You're online and searching for passengers nearby within your service area.",
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: AppColors.subtextColor(isDark),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // --- Offline Card ---
  Widget _buildOfflineCard(BuildContext context) {
    final isDark = context.watch<AppState>().darkMode ||
        Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.cardColor(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor(isDark)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.power_settings_new_rounded,
              color: AppColors.subtextColor(isDark),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You are offline',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textColor(isDark),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Turn on the switch above to start receiving ride requests.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.subtextColor(isDark),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 4-Tab Bottom Navigation Bar Matching Reference Design ---
  Widget _buildBottomNav() {
    final isDark = context.watch<AppState>().darkMode ||
        Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.navBgColor(isDark),
        border: Border(
          top: BorderSide(color: AppColors.navBorderColor(isDark), width: 1),
        ),
      ),
      child: NavigationBar(
        selectedIndex: 0,
        backgroundColor: AppColors.navBgColor(isDark),
        indicatorColor: Colors.transparent,
        elevation: 0,
        height: 62,
        onDestinationSelected: (i) {
          if (i == 1) widget.onNavigate(AppScreen.wallet);
          if (i == 2) widget.onNavigate(AppScreen.performance);
          if (i == 3) widget.onNavigate(AppScreen.profile);
        },
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.home_outlined,
                color: AppColors.navActiveColor(isDark)),
            selectedIcon: Icon(Icons.home_rounded,
                color: AppColors.navActiveColor(isDark)),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined,
                color: AppColors.navInactiveColor(isDark)),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded,
                color: AppColors.navActiveColor(isDark)),
            label: 'Wallet',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined,
                color: AppColors.navInactiveColor(isDark)),
            selectedIcon: Icon(Icons.bar_chart_rounded,
                color: AppColors.navActiveColor(isDark)),
            label: 'Stats',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded,
                color: AppColors.navInactiveColor(isDark)),
            selectedIcon: Icon(Icons.person_rounded,
                color: AppColors.navActiveColor(isDark)),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
