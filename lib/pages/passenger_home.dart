import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../core/time_utils.dart';
import '../l10n/app_localizations.dart';
import '../main.dart' hide Brand, Avatar;
import '../state/app_state.dart';
import '../state/passenger_search_bloc.dart';
import '../widgets/booking_confirmation_modal.dart';
import '../widgets/common.dart';
import '../widgets/connectivity_banner.dart';
import '../widgets/driver_matching_bottom_sheet.dart';
import '../widgets/live_osm_map_widget.dart';
import '../widgets/rate_driver_modal.dart';
import '../widgets/map_export_modal.dart';
import '../widgets/passenger_bottom_nav.dart';
import '../widgets/user_avatar.dart';

class PassengerHome extends StatefulWidget {
  const PassengerHome({super.key, required this.onNavigate});
  final Function(AppScreen) onNavigate;

  @override
  State<PassengerHome> createState() => _PassengerHomeState();
}

class _PassengerHomeState extends State<PassengerHome> {
  late final PassengerSearchBloc _searchBloc;
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  StreamSubscription<PassengerSearchState>? _searchSub;
  String? _lastShownError;
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _minuteTicker;

  @override
  void initState() {
    super.initState();
    _searchBloc = PassengerSearchBloc();
    AppState.instance.addListener(_onAppStateChanged);
    _searchSub = _searchBloc.stream.listen((state) {
      final error = state.errorMessage;
      if (error != null && mounted && error != _lastShownError) {
        _lastShownError = error;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(error),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFFDC2626),
          ));
      }
    });

    // Auto-update time-based greeting dynamically as local time ticks
    _minuteTicker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _onAppStateChanged() {
    if (!mounted) return;
    _searchBloc.recomputeFares();
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_onAppStateChanged);
    _minuteTicker?.cancel();
    _searchSub?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _sheetController.dispose();
    _searchBloc.dispose();
    super.dispose();
  }

  void _toggleSheetExpansion() {
    if (!_sheetController.isAttached) return;
    final currentSize = _sheetController.size;
    if (currentSize < 0.30) {
      _sheetController.animateTo(
        0.44,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else if (currentSize < 0.65) {
      _sheetController.animateTo(
        0.85,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else {
      _sheetController.animateTo(
        0.16,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _showBookingConfirmationModal(PassengerSearchState state) {
    if (state.selectedDriver == null || state.selectedDestination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a destination and driver first.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final currentFare = state.selectedVehicle == VehicleType.tricycle
        ? state.tricycleFare
        : state.habalFare;

    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BookingConfirmationModal(
        driver: state.selectedDriver!,
        pickupAddress: state.currentAddressLabel,
        destination: state.selectedDestination!,
        distanceKm: state.routeDistanceKm,
        durationMins: state.routeDurationMins,
        fare: currentFare,
        onConfirm: _searchBloc.confirmSelectedBooking,
      ),
    ).then((confirmed) {
      if (confirmed == true && mounted) {
        widget.onNavigate(AppScreen.tracking);
      }
    });
  }

  void _showExportMapModal(PassengerSearchState state) {
    if (!state.hasLocation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Detect your location before sharing it.')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MapExportModal(
        location: state.passengerLocation,
        currentAddress: state.currentAddressLabel,
        destination: state.selectedDestination,
        routePoints: state.routePoints,
      ),
    );
  }

  void _showWeatherDetailsSheet(PassengerSearchState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        state.weatherEmoji.isNotEmpty
                            ? state.weatherEmoji
                            : '🌤️',
                        style: const TextStyle(fontSize: 28),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              state.weatherTemperatureLabel,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            Text(
                              state.weatherCondition,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh weather',
                  onPressed: () {
                    _searchBloc.add(RefreshWeatherEvent());
                    Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.refresh_rounded,
                      color: Color(0xFF2563EB)),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 18, color: Color(0xFF6E5600)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.currentAddressLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.gps_fixed_rounded,
                    size: 16, color: Color(0xFF94A3B8)),
                const SizedBox(width: 8),
                Text(
                  'Lat: ${state.passengerLocation.lat.toStringAsFixed(4)}, Lng: ${state.passengerLocation.lng.toStringAsFixed(4)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final isDark =
        app.darkMode || Theme.of(context).brightness == Brightness.dark;
    final currentLocaleCode =
        context.watch<LocaleProvider>().locale.languageCode;
    final media = MediaQuery.of(context);
    final isDesktop = media.size.width > 768;
    final currentUser = app.currentUser;
    final pendingRatingTrip = app.pendingRatingTrip;
    if (pendingRatingTrip != null &&
        app.shouldPromptRatingFor(pendingRatingTrip.id)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(RateDriverModal.show(context, trip: pendingRatingTrip));
      });
    }

    return StreamBuilder<PassengerSearchState>(
      stream: _searchBloc.stream,
      initialData: _searchBloc.state,
      builder: (context, snapshot) {
        final state = snapshot.data ?? _searchBloc.state;

        return Scaffold(
          backgroundColor: AppColors.canvasColor(isDark),
          resizeToAvoidBottomInset: false,
          body: SafeArea(
            child: Stack(
              children: [
                // Layer 1: Real-Time Interactive OpenStreetMap Map (Full background)
                Positioned.fill(
                  child: state.hasLocation
                      ? LiveOsmMapWidget(
                          passengerLocation: state.passengerLocation,
                          currentAddress: state.currentAddressLabel,
                          destination: state.selectedDestination,
                          routePoints: state.routePoints,
                          nearbyDrivers: state.nearbyDrivers,
                          selectedDriver: state.selectedDriver,
                          isLocating: state.isLoadingLocation,
                          routeDistanceKm: state.routeDistanceKm,
                          routeDurationMins: state.routeDurationMins,
                          onRecenter: () =>
                              _searchBloc.add(DetectLocationEvent()),
                          onDriverSelected: (driver) {
                            _searchBloc.add(SelectDriverEvent(driver));
                          },
                          onMapTap: (geo) {
                            _searchBloc.add(SelectDestinationEvent(
                              Place('Pinned Location', geo, 'Custom map pin'),
                            ));
                            _searchCtrl.text = 'Pinned Location';
                            _searchFocus.unfocus();
                          },
                        )
                      : Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                state.isLoadingLocation
                                    ? 'Detecting your location...'
                                    : 'Location unavailable',
                                style: TextStyle(
                                    color: AppColors.textColor(isDark)),
                              ),
                              TextButton.icon(
                                onPressed: () =>
                                    _searchBloc.add(DetectLocationEvent()),
                                icon: const Icon(Icons.my_location),
                                label: const Text('Detect location'),
                              ),
                            ],
                          ),
                        ),
                ),

                // Layer 2: Floating Header Bar & Search Console
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Top Brand & Dynamic Real-Time Weather Header
                      Container(
                        color: isDark
                            ? AppColors.darkBg.withValues(alpha: 0.95)
                            : Colors.white.withValues(alpha: 0.94),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Brand(dark: isDark),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  // Dynamic GPS Location-Aware Weather Badge
                                  Flexible(
                                    child: Tooltip(
                                      message:
                                          'Live weather at current GPS position (Tap for details)',
                                      child: GestureDetector(
                                        onTap: () =>
                                            _showWeatherDetailsSheet(state),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? const Color(0xFF78350F)
                                                    .withValues(alpha: 0.3)
                                                : const Color(0xFFFFFBEB),
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            border: Border.all(
                                                color: isDark
                                                    ? const Color(0xFFD97706)
                                                        .withValues(alpha: 0.4)
                                                    : const Color(0xFFFDE68A)),
                                          ),
                                          child: state.isLoadingWeather
                                              ? Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    SizedBox(
                                                      width: 12,
                                                      height: 12,
                                                      child:
                                                          CircularProgressIndicator(
                                                        strokeWidth: 1.8,
                                                        color: isDark
                                                            ? AppColors.gold
                                                            : const Color(
                                                                0xFFB45309),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 5),
                                                    Text(
                                                      'Weather...',
                                                      style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: isDark
                                                              ? const Color(
                                                                  0xFFFDE68A)
                                                              : const Color(
                                                                  0xFF92400E)),
                                                    ),
                                                  ],
                                                )
                                              : Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      state.weatherEmoji
                                                              .isNotEmpty
                                                          ? state.weatherEmoji
                                                          : '🌤️',
                                                      style: const TextStyle(
                                                          fontSize: 13),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Flexible(
                                                      child: Text(
                                                        state.weatherCondition,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: isDark
                                                                ? const Color(
                                                                    0xFFFDE68A)
                                                                : const Color(
                                                                    0xFF92400E)),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      state
                                                          .weatherTemperatureLabel,
                                                      style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w900,
                                                          color: isDark
                                                              ? AppColors.gold
                                                              : const Color(
                                                                  0xFFB45309)),
                                                    ),
                                                  ],
                                                ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Profile Avatar Button
                                  UserAvatar(
                                    photoUrl: currentUser?.profilePhotoUrl,
                                    name: currentUser?.fullName ?? 'Passenger',
                                    avatarColorIndex:
                                        currentUser?.avatarColor ?? 0,
                                    radius: 17,
                                    border: Border.all(
                                        color: isDark
                                            ? AppColors.darkBorder
                                            : Colors.white,
                                        width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.08),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                    onTap: () =>
                                        widget.onNavigate(AppScreen.profile),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Location Permission Warning Banner (if denied)
                      if (state.isLocationPermissionDenied)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          color: const Color(0xFFFEF2F2),
                          child: Row(
                            children: [
                              const Icon(Icons.location_off_rounded,
                                  color: Color(0xFFDC2626), size: 16),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'GPS access is denied. Showing default location. Tap to grant permission.',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF991B1B),
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(50, 24),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () =>
                                    _searchBloc.add(DetectLocationEvent()),
                                child: const Text('Enable',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFDC2626))),
                              ),
                            ],
                          ),
                        ),

                      // Offline & Limited Connectivity Resilient Banner
                      const ConnectivityBanner(),

                      // Floating Destination Search Card & Shortcuts
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          isDesktop ? media.size.width * 0.2 : 16,
                          10,
                          isDesktop ? media.size.width * 0.2 : 16,
                          0,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.cardColor(isDark),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                                color: AppColors.borderColor(isDark)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black
                                    .withValues(alpha: isDark ? 0.3 : 0.1),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  // Time-Aware Dynamic Greeting
                                  Expanded(
                                    child: Text(
                                      '${TimeGreeting.getLocalizedGreeting(localeCode: currentLocaleCode)}!',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textColor(isDark),
                                      ),
                                    ),
                                  ),
                                  // Map Export / Share Action Button
                                  if (state.selectedDestination != null)
                                    GestureDetector(
                                      onTap: () => _showExportMapModal(state),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 9, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? const Color(0xFF312E81)
                                                  .withValues(alpha: 0.5)
                                              : const Color(0xFFF2F4FB),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                              color: isDark
                                                  ? const Color(0xFF4F46E5)
                                                      .withValues(alpha: 0.5)
                                                  : Colors.transparent),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.share_location_rounded,
                                                size: 13,
                                                color: isDark
                                                    ? const Color(0xFFA5B4FC)
                                                    : const Color(0xFF4F46E5)),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Share Trip',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: isDark
                                                      ? const Color(0xFFA5B4FC)
                                                      : const Color(
                                                          0xFF4F46E5)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                AppLocalizations.of(context).homeWhereTo,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.subtextColor(isDark)),
                              ),
                              const SizedBox(height: 10),

                              // Nominatim "Search location" Input Field
                              TextFormField(
                                controller: _searchCtrl,
                                focusNode: _searchFocus,
                                onChanged: (val) {
                                  _searchBloc.add(SearchDestinationEvent(val));
                                },
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textColor(isDark),
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: InputDecoration(
                                  prefixIcon: Icon(
                                    Icons.search_rounded,
                                    color: isDark
                                        ? AppColors.gold
                                        : const Color(0xFF6E5600),
                                    size: 22,
                                  ),
                                  suffixIcon: state.isSearching
                                      ? Padding(
                                          padding: const EdgeInsets.all(12.0),
                                          child: SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: isDark
                                                  ? AppColors.gold
                                                  : const Color(0xFF6E5600),
                                            ),
                                          ),
                                        )
                                      : _searchCtrl.text.isNotEmpty
                                          ? IconButton(
                                              icon: Icon(
                                                Icons.clear_rounded,
                                                size: 18,
                                                color: AppColors.subtextColor(
                                                    isDark),
                                              ),
                                              onPressed: () {
                                                _searchCtrl.clear();
                                                _searchBloc.add(
                                                    ClearDestinationEvent());
                                              },
                                            )
                                          : null,
                                  hintText: AppLocalizations.of(context)
                                      .homeSearchDestination,
                                  hintStyle: TextStyle(
                                    color: AppColors.subtextColor(isDark),
                                    fontSize: 13,
                                  ),
                                  filled: true,
                                  fillColor: AppColors.inputBgColor(isDark),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 12),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                        color: AppColors.borderColor(isDark)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                        color: AppColors.borderColor(isDark)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: AppColors.terracotta,
                                        width: 1.5),
                                  ),
                                ),
                              ),

                              // Autocomplete Suggestion Dropdown List Overlay
                              if (state.autocompleteSuggestions.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(top: 8),
                                  constraints:
                                      const BoxConstraints(maxHeight: 200),
                                  decoration: BoxDecoration(
                                    color: AppColors.cardColor(isDark),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                        color: AppColors.borderColor(isDark)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                            alpha: isDark ? 0.35 : 0.12),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ListView.separated(
                                    shrinkWrap: true,
                                    itemCount:
                                        state.autocompleteSuggestions.length,
                                    separatorBuilder: (ctx, i) => Divider(
                                        height: 1,
                                        color: AppColors.borderColor(isDark)),
                                    itemBuilder: (ctx, i) {
                                      final place =
                                          state.autocompleteSuggestions[i];
                                      return ListTile(
                                        dense: true,
                                        leading: Icon(
                                            Icons.location_on_outlined,
                                            color: isDark
                                                ? AppColors.gold
                                                : const Color(0xFF6E5600),
                                            size: 18),
                                        title: Text(
                                          place.name,
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color:
                                                  AppColors.textColor(isDark)),
                                        ),
                                        subtitle: Text(
                                          place.address,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: AppColors.subtextColor(
                                                  isDark)),
                                        ),
                                        onTap: () {
                                          _searchCtrl.text = place.name;
                                          _searchBloc.add(
                                              SelectDestinationEvent(place));
                                          _searchFocus.unfocus();
                                        },
                                      );
                                    },
                                  ),
                                ),

                              // Genuine Recent Destination Chips (displayed only when the passenger has completed ride history)
                              if (state.recentDestinations.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children:
                                        state.recentDestinations.map((place) {
                                      final isSelected =
                                          state.selectedDestination?.name ==
                                              place.name;
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(right: 8),
                                        child: ActionChip(
                                          backgroundColor: isSelected
                                              ? (isDark
                                                  ? AppColors.terracotta
                                                      .withValues(alpha: 0.35)
                                                  : const Color(0xFFEFF6FF))
                                              : (isDark
                                                  ? AppColors.darkCardElevated
                                                  : const Color(0xFFF1F5F9)),
                                          side: isSelected
                                              ? BorderSide(
                                                  color: isDark
                                                      ? AppColors.terracotta
                                                      : const Color(0xFF2563EB))
                                              : BorderSide(
                                                  color: AppColors.borderColor(
                                                      isDark)),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10)),
                                          avatar: Icon(
                                            Icons.history_rounded,
                                            size: 14,
                                            color: isSelected
                                                ? (isDark
                                                    ? AppColors.gold
                                                    : const Color(0xFF2563EB))
                                                : AppColors.subtextColor(
                                                    isDark),
                                          ),
                                          label: Text(
                                            place.name,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: isSelected
                                                  ? (isDark
                                                      ? AppColors.gold
                                                      : const Color(0xFF1E40AF))
                                                  : AppColors.textColor(isDark),
                                            ),
                                          ),
                                          onPressed: () {
                                            _searchCtrl.text = place.name;
                                            _searchBloc.add(
                                                SelectDestinationEvent(place));
                                            _searchFocus.unfocus();
                                          },
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Layer 3: Draggable Sliding Driver Matching & Booking Bottom Sheet Panel
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: DraggableScrollableSheet(
                      controller: _sheetController,
                      initialChildSize: 0.44,
                      minChildSize: 0.16,
                      maxChildSize: 0.85,
                      snap: true,
                      snapSizes: const [0.16, 0.44, 0.85],
                      builder: (context, scrollController) {
                        return DriverMatchingBottomSheet(
                          scrollController: scrollController,
                          nearbyDrivers: state.nearbyDrivers,
                          selectedDriver: state.selectedDriver,
                          searchRadiusKm: state.searchRadiusKm,
                          selectedVehicle: state.selectedVehicle,
                          routeDistanceKm: state.routeDistanceKm,
                          routeDurationMins: state.routeDurationMins,
                          tricycleFare: state.tricycleFare,
                          habalFare: state.habalFare,
                          onToggleExpand: _toggleSheetExpansion,
                          onSelectDriver: (driver) {
                            _searchBloc.add(SelectDriverEvent(driver));
                          },
                          onSelectVehicle: (vType) {
                            _searchBloc.add(SelectVehicleTypeEvent(vType));
                          },
                          onUpdateRadius: (radius) {
                            _searchBloc.add(UpdateSearchRadiusEvent(radius));
                          },
                          onConfirmBooking: () {
                            _showBookingConfirmationModal(state);
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Passenger Bottom Navigation Bar
          bottomNavigationBar: PassengerBottomNav(
            currentIndex: 0,
            onNavigate: widget.onNavigate,
          ),
        );
      },
    );
  }
}

