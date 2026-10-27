import '../models/fare_matrix.dart';
import '../services/fare_repository.dart';
import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../core/constants.dart';
import '../core/logger.dart';
import '../core/philippine_time.dart';
import '../models/admin_account.dart';
import '../models/app_user.dart';
import '../models/driver_profile.dart';
import '../models/firestore_models.dart' hide FareMatrix;
import '../models/report_model.dart';
import '../models/transaction.dart';
import '../models/trip.dart';
import '../services/auth_service.dart';
import '../services/connectivity_service.dart';
import '../services/database_service.dart';
import '../services/driver_matching_service.dart';
import '../services/driver_earnings_summary.dart';
import '../services/earnings_service.dart';
import '../services/supabase_auth_service.dart';
import '../services/supabase_service.dart';
import '../services/supabase/admin_service.dart';
import '../services/notification_service.dart';
import '../services/online_payment_gateway.dart';
import '../services/osm_map_service.dart';
import '../services/password_change_service.dart';
import '../services/payment_service.dart';
import '../services/prefs_service.dart';
import '../services/sync_service.dart';
import '../services/toda_service.dart';
import '../services/trip_service.dart';

enum TripCompletionResult {
  confirmed,
  queuedOffline,
}

@visibleForTesting
List<Trip> mergeAssignedSearchingRide(
  List<Trip> streamedTrips,
  Trip? assignedTrip,
  String driverId,
) {
  final merged = List<Trip>.from(streamedTrips);
  if (assignedTrip != null &&
      assignedTrip.status == RideStatus.searching &&
      assignedTrip.driverId == driverId &&
      !merged.any((trip) => trip.id == assignedTrip.id)) {
    merged.insert(0, assignedTrip);
  }
  return merged;
}

@visibleForTesting
bool isIncomingRideVisibleToDriver({
  required Trip trip,
  required String driverId,
  required VehicleType vehicleType,
  double? latitude,
  double? longitude,
  double radiusKm = 10.0,
}) {
  if (trip.status != RideStatus.searching) return false;
  if (trip.driverId != null && trip.driverId!.isNotEmpty) {
    // An explicitly assigned request is authoritative while profile/GPS
    // enrichment is still loading on Driver Home.
    return trip.driverId == driverId;
  }
  if (trip.vehicleType != vehicleType) return false;
  if (latitude != null && longitude != null) {
    if (Geo.distanceKm(Geo(latitude, longitude), trip.pickup) > radiusKm) {
      return false;
    }
  }
  return true;
}

@visibleForTesting
bool isTransientNetworkError(Object error) {
  if (error is AuthException || error is StateError) return false;
  final raw = error.toString();
  return raw.contains('SocketException') ||
      raw.contains('TimeoutException') ||
      raw.contains('ClientException') ||
      raw.contains('Failed host lookup') ||
      raw.contains('Connection closed') ||
      raw.contains('Connection refused') ||
      raw.contains('Connection reset') ||
      raw.contains('HandshakeException') ||
      raw.contains('Network is unreachable') ||
      raw.contains('Software caused connection abort') ||
      raw.contains('XMLHttpRequest error') ||
      raw.contains('FetchException');
}

class AppState extends ChangeNotifier {
  AppState._();
  @visibleForTesting
  AppState.forTesting();
  static AppState? _instance;

  factory AppState() => instance;

  static AppState get instance {
    _instance ??= AppState._();
    return _instance!;
  }

  @visibleForTesting
  static void reset() {
    _instance = null;
  }

  late final DatabaseService databaseService = DatabaseService.instance;
  late final PrefsService prefs = PrefsService.instance;
  late final AuthService auth = AuthService(databaseService, prefs);
  late final TripService trips = TripService(databaseService, auth);
  late final EarningsService earnings = EarningsService(databaseService);
  late final TodaService toda = TodaService(databaseService);
  late final SyncService sync = SyncService(databaseService, trips);
  late final NotificationService notifications =
      NotificationService(databaseService);
  late final ConnectivityService connectivity = ConnectivityService();
  late final FareMatrixRepository fareMatrixRepo = FareMatrixRepository();
  List<FareMatrix> currentFareMatrices = [];

  void forceUpdateFareMatrix(FareMatrix updated) {
    final idx = currentFareMatrices
        .indexWhere((m) => m.vehicleType == updated.vehicleType);
    if (idx >= 0) {
      currentFareMatrices[idx] = updated;
    } else {
      currentFareMatrices.add(updated);
    }
    notifyListeners();
  }

  FareMatrix getFareMatrixFor(VehicleType type) {
    return currentFareMatrices.firstWhere((m) => m.vehicleType == type,
        orElse: () => FareMatrix(
              id: 'default',
              vehicleType: type,
              baseFare: type == VehicleType.tricycle ? 10.0 : 20.0,
              includedBaseDistance: type == VehicleType.tricycle ? 2.0 : 0.0,
              perKmRate: 5.0,
              perMinuteRate: 0.0,
              minimumFare: type == VehicleType.tricycle ? 10.0 : 20.0,
              bookingFee: 0.0,
              surgeMultiplier: 1.0,
              commissionPercent: 0.0,
              isActive: true,
              updatedAt: DateTime.now(),
            ));
  }

  bool initialized = false;
  bool isOnline = true;
  int pendingSyncCount = 0;
  bool darkMode = false;
  Locale locale = const Locale('en');
  bool notificationsEnabled = true;
  bool soundAlertsEnabled = true;
  bool autoAcceptRides = false;
  double pickupRadiusKm = 5.0;

  ConnectionQuality get connectionQuality => connectivity.quality;
  bool get isIntermittent => connectivity.isIntermittent;
  bool get isOffline => !isOnline;

  AppUser? currentUser;
  DriverProfile? driverProfile;
  String? pendingDriverApplicationId;
  String? pendingDriverApplicationStatusToken;
  String? pendingDriverApplicationEmail;
  String pendingDriverApplicationStatus = 'pending';
  String? pendingDriverApplicationRejectionReason;
  String? pendingDriverApplicationStatusError;
  Trip? activeTrip;
  List<Trip> activeTrips = [];

  int get activePassengersCount => activeTrips.fold(
      0, (sum, t) => sum + (t.passengerCount > 0 ? t.passengerCount : 1));

  int get maxCapacity {
    final vType = driverProfile?.vehicleType;
    if (vType == VehicleType.habal) {
      return 1;
    }
    return 4;
  }

  int get availableSeats =>
      (maxCapacity - activePassengersCount).clamp(0, maxCapacity);

  bool get hasCapacityForMore => availableSeats > 0;

  List<WalletTransaction> transactions = [];
  List<ChatMessage> chatMessages = [];
  List<AppNotification> notificationList = [];
  int unreadNotifications = 0;
  bool syncing = false;
  bool initializing = true;
  bool signingIn = false;

  /// Live driver location streaming (only active while a driver is online).
  StreamSubscription<Position>? _positionSub;
  StreamSubscription? _fareMatrixSub;
  StreamSubscription<AppUser?>? _userSub;
  StreamSubscription<Trip?>? _activeTripSub;
  StreamSubscription<List<Trip>>? _activeTripsSub;
  StreamSubscription<List<FireRating>>? _driverRatingsSub;

  /// Last known driver coordinates (used when a trip starts so the rides
  /// document and the drivers location GeoPoint stay in sync).
  double? _lastLatitude;
  double? _lastLongitude;
  DateTime? _lastLocationWriteAt;
  bool _requestingRide = false;
  bool _startingActiveTrip = false;
  bool _completingActiveTrip = false;

  final Set<String> _declinedTripIds = {};
  final Set<String> _promptedRatingTripIds = {};
  Trip? pendingRatingTrip;
  final Map<String, List<Trip>> _stableIncomingTripsByDriver = {};
  DateTime? _onlineStartedAt;
  Timer? _onlineHeartbeatTimer;
  int _locationUpdateGeneration = 0;
  double _todayOnlineHours = 0;
  bool _hasServerTodayOnlineHours = false;
  final Map<String, String> _locationAddressCache = {};
  final Map<String,
          ({String name, String plate, String? photoUrl, int avatarColor})>
      _driverDisplayCache = {};
  String? _cachedRideHistoryUserId;
  List<RideEntry>? _cachedRideHistory;
  final Map<String, RideEntry> _rideEntryByIdCache = {};
  String? _cachedWalletDriverId;
  List<WalletEntry>? _cachedWalletEntries;

  String? lastError;

  String get roleLabel => currentUser?.role ?? UserRole.passenger;

  bool shouldPromptRatingFor(String tripId) =>
      tripId.isNotEmpty && !_promptedRatingTripIds.contains(tripId);

  void markRatingPrompted(String tripId) {
    if (tripId.isEmpty) return;
    _promptedRatingTripIds.add(tripId);
    if (pendingRatingTrip?.id == tripId) {
      pendingRatingTrip = null;
      notifyListeners();
    }
  }

  void clearPendingRatingTrip([String? tripId]) {
    if (tripId == null || pendingRatingTrip?.id == tripId) {
      if (pendingRatingTrip != null) {
        _promptedRatingTripIds.add(pendingRatingTrip!.id);
        pendingRatingTrip = null;
        notifyListeners();
      }
    }
  }

  /// Non-credential system root identifier used only for role/UI visibility checks.
  /// Never stores a hardcoded password or personal email.
  static final AdminAccount defaultSuperAdmin = AdminAccount(
    id: 'super-admin-root',
    fullName: 'System Root Administrator',
    email: '',
    mobile: '',
    passwordHash: '',
    role: 'super_admin',
    status: AccountStatus.active,
    permissions: AdminPermissions.all,
    department: 'HQ Management',
    createdAt: DateTime(2024, 1, 1),
    updatedAt: DateTime(2024, 1, 1),
  );

  @override
  void dispose() {
    _locationUpdateGeneration++;
    _positionSub?.cancel();
    _positionSub = null;
    _fareMatrixSub?.cancel();
    _fareMatrixSub = null;
    _userSub?.cancel();
    _userSub = null;
    _activeTripSub?.cancel();
    _activeTripSub = null;
    _driverRatingsSub?.cancel();
    _driverRatingsSub = null;
    _onlineHeartbeatTimer?.cancel();
    _onlineHeartbeatTimer = null;
    super.dispose();
  }

  final List<AdminAccount> _inMemoryAdmins = [];
  List<AdminAccount> get adminAccounts => List.unmodifiable(_inMemoryAdmins);

  AdminAccount? getAdminByIdentifier(String identifier) {
    final clean = identifier.trim().toLowerCase();
    final digits = clean.replaceAll(RegExp(r'\D'), '');
    for (final admin in _inMemoryAdmins) {
      if (admin.id.toLowerCase() == clean ||
          admin.email.toLowerCase() == clean ||
          (admin.mobile.isNotEmpty && admin.mobile == clean) ||
          (digits.isNotEmpty &&
              admin.mobile.replaceAll(RegExp(r'\D'), '') == digits)) {
        return admin;
      }
    }
    return null;
  }

  Future<void> _loadAdminsFromStorage() async {
    try {
      final dbAdmins = await DatabaseService.instance.getAdminAccounts();
      if (dbAdmins.isNotEmpty) {
        final map = {for (final a in _inMemoryAdmins) a.id: a};
        for (final a in dbAdmins) {
          map[a.id] = a;
        }
        _inMemoryAdmins
          ..clear()
          ..addAll(map.values);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Admin local load note: $e');
    }

    if (SupabaseService.isConfigured &&
        (currentUser?.isAdmin == true || currentUser?.isSuperAdmin == true)) {
      try {
        final cloudAdmins =
            await SupabaseService.instance.getAdminAccountsOnce();
        if (cloudAdmins.isNotEmpty) {
          final map = {for (final a in _inMemoryAdmins) a.id: a};
          for (final a in cloudAdmins) {
            map[a.id] = a;
          }
          _inMemoryAdmins
            ..clear()
            ..addAll(map.values);
          notifyListeners();
        }
      } catch (e) {
        debugPrint('Admin cloud load note: $e');
      }
    }
  }

  Future<void> _loadFareMatrix() async {
    try {
      if (SupabaseService.isConfigured) {
        currentFareMatrices = await fareMatrixRepo.fetchMatrix();
        notifyListeners();
        _fareMatrixSub?.cancel();
        _fareMatrixSub = fareMatrixRepo.streamMatrix().listen((matrices) {
          currentFareMatrices = matrices;
          notifyListeners();
        });
      }
    } catch (e, s) {
      AppLogger.debug('AppState non-fatal note: $e', error: e, stackTrace: s);
    }
  }

  Future<void> init() async {
    if (initialized) return;
    initialized = true;

    // _doInit bounds its individual external reads. Do not return before it
    // finishes: a late cache/session restoration can otherwise overwrite a
    // user who signed in after the old three-second outer timeout.
    try {
      await _doInit();
    } catch (error, stackTrace) {
      debugPrint('[APP INIT] type=${error.runtimeType} error=$error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      if (initializing) {
        initializing = false;
        notifyListeners();
      }
    }
  }

  Future<void> _doInit() async {
    // Load all preferences and services concurrently rather than sequentially.
    // On Flutter Web, IndexedDB/SharedPreferences reads are slow; running them
    // in parallel cuts startup time from ~3 s to < 150 ms.
    try {
      final results = await Future.wait([
        prefs.locale
            .timeout(const Duration(milliseconds: 500), onTimeout: () => 'en'),
        prefs.darkMode
            .timeout(const Duration(milliseconds: 500), onTimeout: () => false),
        prefs.notificationsEnabled
            .timeout(const Duration(milliseconds: 500), onTimeout: () => true),
        prefs.soundAlertsEnabled
            .timeout(const Duration(milliseconds: 500), onTimeout: () => true),
        prefs.autoAcceptRides
            .timeout(const Duration(milliseconds: 500), onTimeout: () => false),
        prefs.pickupRadiusKm
            .timeout(const Duration(milliseconds: 500), onTimeout: () => 5.0),
        prefs.driverApplicationReceipt.timeout(
            const Duration(milliseconds: 500), onTimeout: () => null),
        connectivity
            .init()
            .timeout(const Duration(milliseconds: 800), onTimeout: () {})
            .then((_) => null),
        sync
            .pendingCount()
            .timeout(const Duration(milliseconds: 800), onTimeout: () => 0),
      ]);
      locale = Locale(results[0] as String);
      darkMode = results[1] as bool;
      notificationsEnabled = results[2] as bool;
      soundAlertsEnabled = results[3] as bool;
      autoAcceptRides = results[4] as bool;
      pickupRadiusKm = results[5] as double;
      pendingSyncCount = results[8] as int;
      final driverReceipt = results[6]
          as ({String applicationId, String statusToken, String email})?;
      if (driverReceipt != null) {
        pendingDriverApplicationId = driverReceipt.applicationId;
        pendingDriverApplicationStatusToken = driverReceipt.statusToken;
        pendingDriverApplicationEmail = driverReceipt.email;
      }
    } catch (e, s) {
      AppLogger.debug('AppState non-fatal note: $e', error: e, stackTrace: s);
    }
    isOnline = connectivity.isOnline;

    unawaited(_loadAdminsFromStorage());
    unawaited(_loadFareMatrix());

    connectivity.onQualityChanged.listen((quality) async {
      isOnline = quality != ConnectionQuality.offline;
      try {
        pendingSyncCount = await sync.pendingCount();
      } catch (e, s) {
      AppLogger.debug('AppState non-fatal note: $e', error: e, stackTrace: s);
    }
      notifyListeners();
      if (isOnline && pendingSyncCount > 0) {
        await flushSyncQueue();
      }
    });

    connectivity.onChanged.listen((online) async {
      isOnline = online;
      try {
        pendingSyncCount = await sync.pendingCount();
      } catch (e, s) {
      AppLogger.debug('AppState non-fatal note: $e', error: e, stackTrace: s);
    }
      notifyListeners();
      if (online && pendingSyncCount > 0) {
        await flushSyncQueue();
      }
    });

    try {
      final restored = await auth
          .restoreSession()
          .timeout(const Duration(seconds: 2), onTimeout: () => null);
      if (restored != null) {
        if (restored.isDeactivated) {
          await logout();
        } else {
          currentUser = restored;
          unawaited(_loadFareMatrix());
          unawaited(_loadAdminsFromStorage());
          try {
            await _loadUserData(restored.id)
                .timeout(const Duration(seconds: 1), onTimeout: () {});
          } catch (e, s) {
      AppLogger.debug('AppState non-fatal note: $e', error: e, stackTrace: s);
    }
          if (currentUser != null && currentUser!.isDeactivated) {
            await logout();
          }
        }
      }
    } catch (e, s) {
      AppLogger.debug('AppState non-fatal note: $e', error: e, stackTrace: s);
    }

    initializing = false;
    notifyListeners();
  }

  Future<void> login({
    String? email,
    String? mobile,
    required String password,
    required String role,
  }) async {
    final identifier = (email != null && email.trim().isNotEmpty)
        ? email.trim()
        : (mobile?.trim() ?? '');
    signingIn = true;
    lastError = null;
    notifyListeners();
    final result =
        await auth.login(mobile: identifier, password: password, role: role);
    if (result.error != null) {
      lastError = result.error;
      signingIn = false;
      notifyListeners();
      return;
    }
    currentUser = result.user;
    unawaited(_loadFareMatrix());
    unawaited(_loadAdminsFromStorage());
    // ── Non-blocking navigation ────────────────────────────────────────────
    // Release the loading spinner immediately so the UI transitions to home
    // while the rest of the user data loads in the background.
    signingIn = false;
    notifyListeners();
    // Background-load user data; UI reacts reactively as state updates arrive.
    unawaited(_loadUserData(currentUser!.id));
  }

  Future<void> _loadUserData(String userId) async {
    // Admin views load their own data streams. The authenticated admin profile
    // is already available; passenger trips and notifications delay entry.
    if (currentUser?.isAdmin == true) return;

    // Fetch user profile and driver profile concurrently.
    try {
      final fetchResults = await Future.wait([
        auth.getUser(userId),
        auth.getDriverProfile(userId),
      ]);
      final freshUser = fetchResults[0] as AppUser?;
      if (fetchResults.length > 1) {
        driverProfile = fetchResults[1] as DriverProfile?;
      }
      if (freshUser != null) {
        var resolvedUser = freshUser;
        if ((resolvedUser.profilePhotoUrl == null ||
                resolvedUser.profilePhotoUrl!.isEmpty) &&
            driverProfile?.docProfile != null &&
            driverProfile!.docProfile!.isNotEmpty) {
          resolvedUser =
              resolvedUser.copyWith(profilePhotoUrl: driverProfile!.docProfile);
        }
        currentUser = resolvedUser;
        notifyListeners();
      } else if (driverProfile != null) {
        notifyListeners();
      }
    } catch (e, s) {
      AppLogger.debug('AppState non-fatal note: $e', error: e, stackTrace: s);
    }

    // Load feed data concurrently.
    try {
      await Future.wait([
        refreshTrips(),
        refreshNotifications(),
        if (currentUser?.isDriver == true) refreshTransactions(),
      ]);
      notifyListeners();
    } catch (e, s) {
      AppLogger.debug('AppState non-fatal note: $e', error: e, stackTrace: s);
    }

    if (currentUser != null) {
      _attachRealtimeListeners(currentUser!);
      if (currentUser!.isDriver && currentUser!.isOnline) {
        if (SupabaseService.isConfigured) {
          try {
            await SupabaseService.instance.startDriverOnlineSession();
          } catch (error) {
            debugPrint('SakayTa: online session restore note: $error');
          }
          await refreshTodayDrivingHours();
        }
        unawaited(_startLocationUpdates());
      }
    }
  }

  void _attachRealtimeListeners(AppUser user) {
    _detachRealtimeListeners();
    if (!SupabaseService.isConfigured) return;

    _userSub = SupabaseService.instance
        .streamUser((user as dynamic).id)
        .listen((updatedUser) {
      if (updatedUser != null && currentUser?.id == (user as dynamic).id) {
        currentUser = updatedUser;
        notifyListeners();
      }
    });

    if (user.isDriver) {
      _activeTripsSub = SupabaseService.instance
          .streamActiveTripsForDriver((user as dynamic).id)
          .listen((tripList) {
        if (currentUser?.id == (user as dynamic).id) {
          activeTrips = tripList;
          activeTrip = tripList.firstOrNull;
          notifyListeners();
        }
      }, onError: (Object error) {
        debugPrint('[RideTracking] driver active trips listener error: $error');
      });
    } else {
      final tripStream = SupabaseService.instance
          .streamActiveTripForPassenger((user as dynamic).id);

      _activeTripSub = tripStream.listen((trip) {
        if (currentUser?.id == (user as dynamic).id) {
          final previousTrip = activeTrip;
          activeTrip = trip;
          activeTrips = trip == null ? [] : [trip];
          if (trip != null &&
              RideStatus.normalize(trip.status) == RideStatus.completed &&
              trip.rating == null &&
              shouldPromptRatingFor(trip.id)) {
            pendingRatingTrip = trip;
          } else if (trip == null && previousTrip != null) {
            final prevId = previousTrip.id;
            unawaited(trips.getById(prevId).then((latest) {
              if (latest != null &&
                  currentUser?.id == user.id &&
                  RideStatus.normalize(latest.status) == RideStatus.completed &&
                  latest.rating == null &&
                  shouldPromptRatingFor(latest.id)) {
                pendingRatingTrip = latest;
                notifyListeners();
              }
            }).catchError((Object _) {}));
          }
          notifyListeners();
        }
      }, onError: (Object error) {
        debugPrint('[RideTracking] active ride listener error: $error');
      });
    }

    if (user.isDriver) {
      _driverRatingsSub = SupabaseService.instance
          .streamRatingsFor((user as dynamic).id)
          .listen(
        (_) => unawaited(_refreshDriverRating(user.id)),
        onError: (Object error) {
          debugPrint('[DriverRating] ratings listener error: $error');
        },
      );
    }
  }

  void _detachRealtimeListeners() {
    _userSub?.cancel();
    _userSub = null;
    _activeTripSub?.cancel();
    _activeTripSub = null;
    _activeTripsSub?.cancel();
    _activeTripsSub = null;
    _driverRatingsSub?.cancel();
    _driverRatingsSub = null;
  }

  Future<void> _refreshDriverRating(String driverId) async {
    if (currentUser?.id != driverId) return;
    try {
      final updated = await auth.getUser(driverId);
      if (updated != null && currentUser?.id == driverId) {
        currentUser = updated;
        notifyListeners();
      }
    } catch (error) {
      debugPrint('[DriverRating] profile refresh error: $error');
    }
  }

  Future<void> refreshUser() async {
    final id = currentUser?.id;
    if (id == null) return;
    try {
      final user = await auth.getUser(id);
      if (user != null) currentUser = user;
    } catch (e, s) {
      AppLogger.debug('AppState non-fatal note: $e', error: e, stackTrace: s);
    }
    if (currentUser?.isDriver == true && SupabaseService.isConfigured) {
      await refreshTodayDrivingHours();
    }
    notifyListeners();
  }

  Future<void> refreshTrips() async {
    final user = currentUser;
    if (user == null) return;
    try {
      if (user.isDriver) {
        activeTrip = await trips.activeTripForDriver((user as dynamic).id);
      } else {
        activeTrip = await trips.activeTripForPassenger((user as dynamic).id);
      }
    } catch (e, s) {
      AppLogger.debug('AppState non-fatal note: $e', error: e, stackTrace: s);
    }
    notifyListeners();
  }

  Future<void> refreshTransactions() async {
    final user = currentUser;
    if (user == null || !user.isDriver) return;
    try {
      transactions = await earnings.transactionsFor((user as dynamic).id);
    } catch (e, s) {
      AppLogger.debug('AppState non-fatal note: $e', error: e, stackTrace: s);
    }
    notifyListeners();
  }

  Future<void> refreshNotifications() async {
    final user = currentUser;
    if (user == null) return;
    try {
      notificationList = await notifications.listFor((user as dynamic).id);
      unreadNotifications =
          await notifications.unreadCount((user as dynamic).id);
    } catch (e, s) {
      AppLogger.debug('AppState non-fatal note: $e', error: e, stackTrace: s);
    }
    notifyListeners();
  }

  Future<void> setLocale(Locale value) async {
    locale = value;
    await prefs.setLocale(value.languageCode);
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    darkMode = value;
    await prefs.setDarkMode(value);
    notifyListeners();
  }

  Future<void> updateDriverPreferences({
    bool? notifications,
    bool? soundAlerts,
    bool? autoAccept,
    double? radius,
  }) async {
    if (notifications != null) {
      notificationsEnabled = notifications;
      await prefs.setNotificationsEnabled(notifications);
    }
    if (soundAlerts != null) {
      soundAlertsEnabled = soundAlerts;
      await prefs.setSoundAlertsEnabled(soundAlerts);
    }
    if (autoAccept != null) {
      autoAcceptRides = autoAccept;
      await prefs.setAutoAcceptRides(autoAccept);
    }
    if (radius != null) {
      pickupRadiusKm = radius;
      await prefs.setPickupRadiusKm(radius);
    }
    notifyListeners();
  }

  @Deprecated('Driver registered vehicle details are locked and read-only.')
  Future<void> updateDriverVehicleInfo({
    required String plateNumber,
    required String make,
    required String model,
    required String color,
    String? todaName,
    VehicleType? vehicleType,
  }) async {
    throw UnsupportedError(
      'Registered vehicle details cannot be modified after registration.',
    );
  }

  Future<void> updateDriverDocProfile(String? photoUrl) async {
    final current = driverProfile;
    if (current == null) return;
    final updated = current.copyWith(docProfile: photoUrl);
    driverProfile = updated;
    await auth.updateDriverProfile(updated);
    notifyListeners();
  }

  Future<void> refreshDriverProfile() async {
    final id = currentUser?.id;
    if (id == null) return;
    try {
      final profile = await auth.getDriverProfile(id);
      if (profile != null) driverProfile = profile;
    } catch (e, s) {
      AppLogger.debug('AppState non-fatal note: $e', error: e, stackTrace: s);
    }
    notifyListeners();
  }

  Future<void> setDriverOnline(bool online) => setOnline(online);

  Future<({bool success, String? errorMessage})> changeUserPassword(
    String newPassword, {
    String? currentPassword,
  }) async {
    final trimmed = newPassword.trim();
    if (trimmed.length < 6) {
      return (
        success: false,
        errorMessage: 'Password must be at least 6 characters long.',
      );
    }
    if (currentUser == null) {
      return (success: false, errorMessage: 'No active session found.');
    }
    // This legacy API intentionally cannot change a password. Password
    // updates must go through PasswordChangeService, which verifies the
    // Supabase reauthentication OTP immediately before updateUser(). Keeping
    // this method as a failed result prevents older callers from bypassing
    // that backend security boundary.
    return (
      success: false,
      errorMessage:
          'Verify the password-change code before updating your password.',
    );
  }

  Future<void> logout() async {
    if (currentUser != null && currentUser!.isDriver) {
      if (SupabaseService.isConfigured) {
        try {
          await SupabaseService.instance.stopDriverOnlineSession();
        } catch (error) {
          debugPrint('SakayTa: online session stop on logout note: $error');
        }
      }
      // DO NOT override is_online to false on logout! The driver's explicit bookability preference (Online toggle) must persist.
    }
    _stopLocationUpdates();
    _detachRealtimeListeners();
    _fareMatrixSub?.cancel();
    _fareMatrixSub = null;
    await auth.logout();
    currentUser = null;
    driverProfile = null;
    pendingDriverApplicationId = null;
    pendingDriverApplicationEmail = null;
    pendingDriverApplicationStatus = 'pending';
    pendingDriverApplicationRejectionReason = null;
    pendingDriverApplicationStatusError = null;
    activeTrip = null;
    pendingRatingTrip = null;
    _promptedRatingTripIds.clear();
    transactions = [];
    _onlineStartedAt = null;
    _todayOnlineHours = 0;
    _hasServerTodayOnlineHours = false;
    _lastLatitude = null;
    _lastLongitude = null;
    _lastLocationWriteAt = null;
    _requestingRide = false;
    _startingActiveTrip = false;
    _completingActiveTrip = false;
    _declinedTripIds.clear();
    _stableIncomingTripsByDriver.clear();
    _locationAddressCache.clear();
    chatMessages = [];
    notificationList = [];
    unreadNotifications = 0;
    _driverDisplayCache.clear();
    _cachedRideHistoryUserId = null;
    _cachedRideHistory = null;
    _rideEntryByIdCache.clear();
    _cachedWalletDriverId = null;
    _cachedWalletEntries = null;
    lastError = null;
    notifyListeners();
  }

  /// Clears local cache without deleting database or signing out.
  Future<String> clearCache() async {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    _driverDisplayCache.clear();
    _cachedRideHistory = null;
    _rideEntryByIdCache.clear();
    _cachedWalletEntries = null;
    notifyListeners();
    return '12.4 MB';
  }

  /// Clears local session and cached data, keeping the user's account safely in the cloud.
  Future<void> clearLocalDataAndSignOut() async {
    await logout();
  }

  /// Permanently deletes the passenger or driver account from servers and local database.
  Future<void> deleteAccount() async {
    final user = currentUser;
    if (user == null) return;
    if (user.isDriver) {
      _stopLocationUpdates();
    }
    _detachRealtimeListeners();
    await auth.deleteAccount((user as dynamic).id);
    currentUser = null;
    driverProfile = null;
    activeTrip = null;
    pendingRatingTrip = null;
    _promptedRatingTripIds.clear();
    transactions = [];
    chatMessages = [];
    notificationList = [];
    unreadNotifications = 0;
    notifyListeners();
  }

  Future<void> registerPassenger({
    required String fullName,
    required String mobile,
    required String password,
  }) async {
    final user = await auth.registerPassenger(
      fullName: fullName,
      mobile: mobile,
      password: password,
    );
    currentUser = user;
    await _loadUserData(user!.id);
    notifyListeners();
  }

  Future<void> registerDriver({
    required String fullName,
    required String mobile,
    required String password,
    required DriverProfile profile,
  }) async {
    await auth.registerDriver(
      fullName: fullName,
      mobile: mobile,
      password: password,
      profile: profile,
    );
  }

  Future<int> availableDrivers(VehicleType type) async {
    final drivers = await auth.findDrivers(vehicleType: type.key);
    return drivers.length;
  }

  bool _isUpdatingOnlineStatus = false;

  Future<void> setOnline(bool online) async {
    if (_isUpdatingOnlineStatus) return;
    _isUpdatingOnlineStatus = true;
    try {
      final user = currentUser;
      if (user == null) return;

      if (online) {
        // Prevent suspended/unapproved driver from going online
        if (user.status != AccountStatus.approved &&
            user.status != AccountStatus.active) {
          throw AuthException(
              'Your account must be approved and active to go online.');
        }

        // Must have location permission to go online
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          throw AuthException(
              'Location permission is required to go online. Passengers need to see your location.');
        }

        // Ensure we can actually get a location before marking online
        try {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 10),
          );
          // Publish the location before changing availability. This prevents
          // a driver from briefly appearing online with no usable GPS fix.
          await updateDriverLocation(
            latitude: position.latitude,
            longitude: position.longitude,
          );
        } catch (e) {
          throw AuthException(
              'Unable to get your current location. Please check your GPS signal.');
        }

        _onlineStartedAt = DateTime.now();
      } else {
        _onlineStartedAt = null;
      }

      // The RPC owns the session and the driver's availability in one
      // transaction. The client never fabricates an online duration.
      if (SupabaseService.isConfigured) {
        if (online) {
          await SupabaseService.instance.startDriverOnlineSession();
        } else {
          final changed = await SupabaseService.instance.setDriverOffline();
          if (!changed) throw StateError('Could not save Offline status.');
        }
      }

      // If Firestore succeeded, update SQLite to stay locally synced
      await auth.setOnline((user as dynamic).id, online);

      if (online && user.isDriver) {
        unawaited(_startLocationUpdates());
      } else {
        _stopLocationUpdates();
      }
      if (!online) await refreshTodayDrivingHours();
      await refreshUser();
    } finally {
      _isUpdatingOnlineStatus = false;
    }
  }

  Future<void> _startLocationUpdates() async {
    _stopLocationUpdates();
    final generation = ++_locationUpdateGeneration;
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (generation != _locationUpdateGeneration ||
          currentUser?.isDriver != true) {
        return;
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('SakayTa: location permission denied - '
            'nearby-driver updates are off');
        return;
      }

      // Push an immediate fix so the driver shows up right away.
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
        if (generation != _locationUpdateGeneration ||
            currentUser?.isDriver != true) {
          return;
        }
        await updateDriverLocation(
          latitude: position.latitude,
          longitude: position.longitude,
        );
      } catch (e) {
        debugPrint('SakayTa: initial location fix unavailable ($e)');
      }

      if (generation != _locationUpdateGeneration ||
          currentUser?.isDriver != true) {
        return;
      }

      // Then stream fixes while the driver stays online.
      _positionSub?.cancel();
      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 25,
        ),
      ).listen((position) {
        if (generation != _locationUpdateGeneration) return;
        updateDriverLocation(
          latitude: position.latitude,
          longitude: position.longitude,
        );
      }, onError: (Object e) {
        debugPrint('SakayTa: location stream error ($e)');
      });
      _startOnlineHeartbeat();
    } catch (e) {
      debugPrint('SakayTa: location updates unavailable ($e)');
    }
  }

  void _startOnlineHeartbeat() {
    _onlineHeartbeatTimer?.cancel();
    if (!SupabaseService.isConfigured) return;
    _onlineHeartbeatTimer =
        Timer.periodic(const Duration(seconds: 30), (_) async {
      final user = currentUser;
      if (user == null || !user.isDriver || !user.isOnline) return;
      try {
        final alive =
            await SupabaseService.instance.heartbeatDriverOnlineSession();
        if (!alive) {
          await SupabaseService.instance.startDriverOnlineSession();
        }
        await refreshTodayDrivingHours();
      } catch (error) {
        debugPrint('SakayTa: online session heartbeat note: $error');
      }
    });
  }

  void _stopLocationUpdates() {
    _locationUpdateGeneration++;
    _positionSub?.cancel();
    _positionSub = null;
    _onlineHeartbeatTimer?.cancel();
    _onlineHeartbeatTimer = null;
  }

  /// Publishes a driver's live coordinates to Firestore (for the
  /// nearby-drivers query) and to the local database (offline source of
  /// truth). No-op when Firebase is not configured.
  Future<void> updateDriverLocation({
    required double latitude,
    required double longitude,
  }) async {
    final user = currentUser;
    if (user == null || !user.isDriver) return;
    final now = DateTime.now();
    if (_lastLatitude != null &&
        _lastLongitude != null &&
        _lastLocationWriteAt != null) {
      final movedKm = Geo.distanceKm(
        Geo(_lastLatitude!, _lastLongitude!),
        Geo(latitude, longitude),
      );
      if (movedKm < 0.025 &&
          now.difference(_lastLocationWriteAt!) < const Duration(seconds: 15)) {
        return;
      }
    }
    _lastLatitude = latitude;
    _lastLongitude = longitude;
    _lastLocationWriteAt = now;
    await auth.saveDriverLocation(
      userId: (user as dynamic).id,
      latitude: latitude,
      longitude: longitude,
    );
    if (isOnline && SupabaseService.isConfigured) {
      try {
        await SupabaseService.instance.saveDriverLocation(
          userId: (user as dynamic).id,
          latitude: latitude,
          longitude: longitude,
        );
      } catch (e) {
        debugPrint('AppState updateDriverLocation cloud note: $e');
      }
    }
    if (currentUser != null) {
      currentUser = currentUser!.copyWith(
        latitude: latitude,
        longitude: longitude,
      );
    }
  }

  /// Stream of approved drivers near a point - the real data behind
  /// the passenger booking search. Uses Firestore when configured (live
  /// updates); otherwise falls back to the local database.
  Stream<List<NearbyDriver>> streamNearbyDrivers({
    double? lat,
    double? lng,
    double radiusKm = 5,
    VehicleType? vehicleType,
  }) {
    if (SupabaseService.isConfigured && lat != null && lng != null) {
      return SupabaseService.instance
          .streamNearbyDrivers(
              lat: lat, lng: lng, radiusKm: radiusKm, vehicleType: vehicleType)
          .map((drivers) {
        final cards = drivers.where((d) {
          if (vehicleType != null && d.vehicleType != vehicleType) return false;
          return true;
        }).toList();

        cards.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
        return cards;
      });
    }
    return Stream.fromFuture(_nearbyDriversLocal(
      lat: lat,
      lng: lng,
      radiusKm: radiusKm,
      vehicleType: vehicleType,
    ));
  }

  Future<List<NearbyDriver>> _nearbyDriversLocal({
    double? lat,
    double? lng,
    required double radiusKm,
    VehicleType? vehicleType,
  }) async {
    final database = await databaseService.database;
    final rows = await database.rawQuery(
      'SELECT u.*, d.vehicle_type, d.plate_number, d.doc_profile '
      'FROM users u JOIN drivers d ON d.user_id = u.id '
      'WHERE u.role = ? AND (u.status = ? OR u.status = ?)',
      [UserRole.driver, AccountStatus.approved, AccountStatus.active],
    );
    final out = <NearbyDriver>[];
    for (final row in rows) {
      final user = AppUser.fromMap(row);
      final profile = DriverProfile.fromMap(row);
      if (vehicleType != null && profile.vehicleType != vehicleType) continue;
      if (lat != null && lng != null) {
        if (user.latitude == null || user.longitude == null) continue;
        final dist =
            Geo.distanceKm(Geo(lat, lng), Geo(user.latitude!, user.longitude!));
        if (dist > radiusKm) continue;
      }
      out.add(NearbyDriver.fromUserAndProfile(
        user: user,
        profile: profile,
        passenger: (lat != null && lng != null) ? Geo(lat, lng) : null,
      ));
    }
    out.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return out;
  }

  /// Stream of the current user's profile document. Firestore when
  /// configured (live updates); otherwise the local database, re-emitted
  /// whenever the app state changes so edits show up immediately.
  Stream<AppUser?> streamUserProfile(String userId) {
    if (SupabaseService.isConfigured) {
      // AppState owns the authenticated user's profile channel in
      // _attachRealtimeListeners. Screen builders read that shared state so
      // a rebuild cannot open a second profile channel for the same UID.
      if (currentUser?.id == userId) {
        return _localNotifyingStream(() async => currentUser);
      }
      return SupabaseService.instance.streamUser(userId);
    }
    return _localNotifyingStream(() => auth.getUser(userId));
  }

  /// Stream of the passenger's saved-addresses profile. Firestore when
  /// configured; otherwise an empty local profile (addresses live in the
  /// cloud `passengers` collection).
  Stream<PassengerCloudProfile?> streamPassengerProfile(String userId) {
    if (SupabaseService.isConfigured) {
      return SupabaseService.instance.streamPassengerProfile(userId);
    }
    return _localNotifyingStream(
      () async => PassengerCloudProfile(userId: userId),
    );
  }

  /// Stream of a driver's verification profile. Firestore when configured;
  /// otherwise the local database.
  Stream<DriverProfile?> streamDriverProfile(String userId) {
    if (SupabaseService.isConfigured) {
      return SupabaseService.instance.streamDriverProfile(userId);
    }
    return _localNotifyingStream(() => auth.getDriverProfile(userId));
  }

  /// Stream of the passenger's active trip. When online + Firestore configured,
  /// streams Firestore with seamless fallback to local SQLite; when offline,
  /// streams local database with state change notifications.
  Stream<Trip?> streamActiveTripForPassenger(String passengerId) {
    if (!SupabaseService.isConfigured) {
      return _localNotifyingStream(
        () => trips.activeTripForPassenger(passengerId),
      );
    }
    return Stream<Trip?>.multi((controller) {
      StreamSubscription<Trip?>? cloudSub;
      StreamSubscription<Trip?>? localSub;
      var hasEmittedFromCloud = false;
      Trip? lastEmittedActiveTrip;

      // 1. Immediately emit from in-memory activeTrip or local SQLite (0ms)
      if (activeTrip?.passengerId == passengerId &&
          activeTrip?.isActive == true) {
        lastEmittedActiveTrip = activeTrip;
        if (!controller.isClosed) controller.add(activeTrip);
      } else {
        trips.activeTripForPassenger(passengerId).then((localTrip) {
          if (!controller.isClosed &&
              !hasEmittedFromCloud &&
              localTrip != null) {
            lastEmittedActiveTrip = localTrip;
            controller.add(localTrip);
          }
        }).catchError((_) {});
      }

      // 2. Listen to Firestore cloud stream with local fallback on error
      try {
        cloudSub = SupabaseService.instance
            .streamActiveTripForPassenger(passengerId)
            .listen(
          (cloudTrip) {
            hasEmittedFromCloud = true;
            if (cloudTrip != null) {
              lastEmittedActiveTrip = cloudTrip;
              if (currentUser?.id == passengerId) {
                activeTrip = cloudTrip;
              }
              if (!controller.isClosed) {
                controller.add(cloudTrip);
              }
              return;
            }
            // When active trip query emits null after an active ride was tracked,
            // check if that ride just transitioned to 'completed' so the passenger
            // immediately sees the Completed / Rate Driver UI instead of 'No Active Ride'.
            final prev = lastEmittedActiveTrip ?? activeTrip;
            if (prev != null && prev.passengerId == passengerId) {
              final prevId = prev.id;
              lastEmittedActiveTrip = null;
              trips.getById(prevId).then((latest) {
                if (latest != null &&
                    RideStatus.normalize(latest.status) ==
                        RideStatus.completed) {
                  if (currentUser?.id == passengerId &&
                      latest.rating == null &&
                      shouldPromptRatingFor(latest.id)) {
                    pendingRatingTrip = latest;
                    notifyListeners();
                  }
                  if (!controller.isClosed) {
                    controller.add(latest);
                  }
                } else {
                  if (currentUser?.id == passengerId) {
                    activeTrip = null;
                  }
                  if (!controller.isClosed) {
                    controller.add(null);
                  }
                }
              }).catchError((_) {
                if (currentUser?.id == passengerId) {
                  activeTrip = null;
                }
                if (!controller.isClosed) {
                  controller.add(null);
                }
              });
              return;
            }
            if (currentUser?.id == passengerId) {
              activeTrip = cloudTrip;
              activeTrip = null;
            }
            if (!controller.isClosed) {
              controller.add(cloudTrip);
              controller.add(null);
            }
          },
          onError: (Object error) {
            debugPrint(
                '[SakayTa][RideTracking] passenger active trip cloud stream note: $error');
            if (!controller.isClosed && localSub == null) {
              localSub = _localNotifyingStream(
                () => trips.activeTripForPassenger(passengerId),
              ).listen((localTrip) {
                if (!controller.isClosed) controller.add(localTrip);
              }, onError: (Object err) {
                if (!controller.isClosed) controller.addError(err);
              });
            }
          },
        );
      } catch (e) {
        debugPrint(
            '[SakayTa][RideTracking] failed to attach passenger cloud stream: $e');
        if (!controller.isClosed && localSub == null) {
          localSub = _localNotifyingStream(
            () => trips.activeTripForPassenger(passengerId),
          ).listen((localTrip) {
            if (!controller.isClosed) controller.add(localTrip);
          }, onError: (Object err) {
            if (!controller.isClosed) controller.addError(err);
          });
        }
      }

      controller.onCancel = () {
        cloudSub?.cancel();
        localSub?.cancel();
      };
    });
  }

  Stream<Trip?> streamTrip(String rideId) {
    if (!SupabaseService.isConfigured) {
      return _localNotifyingStream(() => trips.getById(rideId));
    }
    return Stream<Trip?>.multi((controller) {
      StreamSubscription<Trip?>? cloudSub;
      StreamSubscription<Trip?>? localSub;
      var hasEmittedFromCloud = false;

      // 1. Immediately emit in-memory active trip or local DB trip if matching
      if (activeTrip?.id == rideId) {
        if (!controller.isClosed) controller.add(activeTrip);
      } else {
        trips.getById(rideId).then((localTrip) {
          if (!controller.isClosed &&
              !hasEmittedFromCloud &&
              localTrip != null) {
            controller.add(localTrip);
          }
        }).catchError((_) {});
      }

      // 2. Listen to Firestore cloud stream with local fallback on error
      try {
        cloudSub = SupabaseService.instance.streamTrip(rideId).listen(
          (cloudTrip) {
            hasEmittedFromCloud = true;
            if (!controller.isClosed) {
              controller.add(cloudTrip);
            }
          },
          onError: (Object error) {
            debugPrint(
                '[SakayTa][RideTracking] trip cloud stream note: $error');
            if (!controller.isClosed && localSub == null) {
              localSub = _localNotifyingStream(
                () => trips.getById(rideId),
              ).listen((localTrip) {
                if (!controller.isClosed) controller.add(localTrip);
              }, onError: (Object err) {
                if (!controller.isClosed) controller.addError(err);
              });
            }
          },
        );
      } catch (e) {
        debugPrint(
            '[SakayTa][RideTracking] failed to attach cloud trip stream: $e');
        if (!controller.isClosed && localSub == null) {
          localSub = _localNotifyingStream(
            () => trips.getById(rideId),
          ).listen((localTrip) {
            if (!controller.isClosed) controller.add(localTrip);
          }, onError: (Object err) {
            if (!controller.isClosed) controller.addError(err);
          });
        }
      }

      controller.onCancel = () {
        cloudSub?.cancel();
        localSub?.cancel();
      };
    });
  }

  Stream<DriverLiveLocation?> streamDriverLocation(String driverId) {
    if (SupabaseService.isConfigured) {
      return SupabaseService.instance.streamDriverLocation(driverId);
    }
    return const Stream.empty();
  }

  /// Stream of the driver's active trip with Firestore + local SQLite fallback.
  Stream<Trip?> streamActiveTripForDriver(String driverId) {
    return streamActiveTripsForDriver(driverId).map((list) => list.firstOrNull);
  }

  /// Stream of all active trips for a multi-passenger driver (e.g. Tricycle up to 4 pax).
  Stream<List<Trip>> streamActiveTripsForDriver(String driverId) {
    if (!SupabaseService.isConfigured) {
      return _localNotifyingStream(() => trips.activeTripsForDriver(driverId));
    }
    if (currentUser?.id == driverId) {
      return _localNotifyingStream(() async {
        return activeTrips
            .where((t) => t.driverId == driverId && t.isActive)
            .toList();
      });
    }
    return Stream<List<Trip>>.multi((controller) {
      StreamSubscription<List<Trip>>? cloudSub;
      StreamSubscription<List<Trip>>? localSub;
      var hasEmittedFromCloud = false;

      if (currentUser?.id == driverId && activeTrips.isNotEmpty) {
        if (!controller.isClosed) controller.add(activeTrips);
      } else {
        trips.activeTripsForDriver(driverId).then((localTrips) {
          if (!controller.isClosed && !hasEmittedFromCloud && localTrips.isNotEmpty) {
            controller.add(localTrips);
          }
        }).catchError((_) {});
      }

      try {
        cloudSub = SupabaseService.instance
            .streamActiveTripsForDriver(driverId)
            .listen(
          (cloudTrips) {
            hasEmittedFromCloud = true;
            if (!controller.isClosed) {
              controller.add(cloudTrips);
            }
          },
          onError: (Object error) {
            debugPrint(
                '[SakayTa][RideTracking] driver active trips cloud stream note: $error');
            if (!controller.isClosed && localSub == null) {
              localSub = _localNotifyingStream(
                () => trips.activeTripsForDriver(driverId),
              ).listen((localTrips) {
                if (!controller.isClosed) controller.add(localTrips);
              }, onError: (Object err) {
                if (!controller.isClosed) controller.addError(err);
              });
            }
          },
        );
      } catch (e) {
        debugPrint(
            '[SakayTa][RideTracking] failed to attach driver cloud trips stream: $e');
        if (!controller.isClosed && localSub == null) {
          localSub = _localNotifyingStream(
            () => trips.activeTripsForDriver(driverId),
          ).listen((localTrips) {
            if (!controller.isClosed) controller.add(localTrips);
          }, onError: (Object err) {
            if (!controller.isClosed) controller.addError(err);
          });
        }
      }

      controller.onCancel = () {
        cloudSub?.cancel();
        localSub?.cancel();
      };
    });
  }

  /// Stream of the driver's earnings ledger. Firestore when configured
  /// (updates in real time as trips are completed); otherwise computed from
  /// the local transactions table.
  Stream<List<DriverEarning>> streamDriverEarnings(String driverId) {
    if (SupabaseService.isConfigured) {
      return SupabaseService.instance.streamDriverEarnings(driverId);
    }
    return _localNotifyingStream(() async {
      final all = await earnings.transactionsFor(driverId);
      return all
          .where((t) => t.type == 'income')
          .map((t) => DriverEarning(
                id: t.id,
                driverId: driverId,
                rideId: t.tripId ?? '',
                fare: t.amount,
                commission: 0,
                net: t.amount,
                createdAt: t.createdAt,
              ))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    });
  }

  Stream<List<Trip>> streamDriverRideHistory(String driverId) {
    if (SupabaseService.isConfigured) {
      return SupabaseService.instance.streamRideHistoryForDriver(driverId);
    }
    return _localNotifyingStream(() => trips.tripsForDriver(driverId));
  }

  Stream<DriverDailyEarningsSummary> streamDriverDailyEarningsToday(
      String driverId) {
    if (SupabaseService.isConfigured) {
      return SupabaseService.instance.streamDriverDailyEarningsToday(driverId);
    }
    return streamDriverRideHistory(driverId).map(summarizeDriverEarningsToday);
  }

  Stream<List<DriverEarning>> allEarningsStream() {
    if (SupabaseService.isConfigured) {
      return SupabaseService.instance.streamAllEarnings();
    }
    return _localNotifyingStream(() async {
      final rows = await earnings.allTransactions();
      return rows
          .where((t) => t.type == 'income')
          .map((t) => DriverEarning(
                id: t.id,
                driverId: t.driverId,
                rideId: t.tripId ?? '',
                fare: t.amount,
                commission: 0,
                net: t.amount,
                paymentMethod: t.method,
                createdAt: t.createdAt,
              ))
          .toList();
    });
  }

  /// Wraps a one-shot local read into a stream that re-emits the latest value
  /// whenever [AppState] notifies (login/logout/trip updates/earnings writes),
  /// so offline mode still behaves like a live stream.
  Stream<T> _localNotifyingStream<T>(Future<T> Function() read) {
    return Stream<T>.multi((controller) {
      var done = false;
      Future<void> emit() async {
        if (done) {
          return;
        }
        try {
          final value = await read();
          if (done) {
            return;
          }
          controller.add(value);
        } catch (e, stackTrace) {
          debugPrint('[SakayTa][ERROR][LocalStream] local read failed: $e');
          if (!done) {
            controller.addError(e, stackTrace);
          }
        }
      }

      unawaited(emit());
      void listener() => unawaited(emit());
      addListener(listener);
      controller.onCancel = () {
        done = true;
        removeListener(listener);
      };
    });
  }

  List<RideEntry>? getCachedRideHistory({String? status}) {
    final user = currentUser;
    if (user == null ||
        _cachedRideHistory == null ||
        _cachedRideHistoryUserId != user.id) {
      return null;
    }
    final all = _cachedRideHistory!;
    if (status == null || status == 'all') return all;
    return all.where((e) => e.trip.status == status).toList();
  }

  List<WalletEntry>? getCachedWalletEntries(String driverId) {
    if (_cachedWalletEntries == null || _cachedWalletDriverId != driverId) {
      return null;
    }
    return _cachedWalletEntries;
  }

  RideEntry? getCachedRideEntryById(String rideId) {
    final cached = _rideEntryByIdCache[rideId];
    if (cached != null) return cached;
    final history = _cachedRideHistory;
    if (history != null) {
      for (final entry in history) {
        if (entry.trip.id == rideId) {
          _rideEntryByIdCache[rideId] = entry;
          return entry;
        }
      }
    }
    return null;
  }

  Future<RideEntry?> getOrFetchRideEntryById(String rideId) async {
    final trimmed = rideId.trim();
    if (trimmed.isEmpty) return null;
    final cached = getCachedRideEntryById(trimmed);
    if (cached != null) {
      debugPrint('[SakayTa][Perf][Receipt] rideId=$trimmed source=memory_cache '
          'durationMs=0');
      return cached;
    }
    final sw = Stopwatch()..start();
    Trip? trip;
    if (SupabaseService.isConfigured) {
      try {
        trip = await SupabaseService.instance.getTrip(trimmed);
      } catch (e) {
        debugPrint('[SakayTa][Perf][Receipt] remote getTrip failed: $e');
      }
    }
    trip ??= await trips.getById(trimmed);
    if (trip == null) return null;
    final enriched = await _withDriverInfo([trip]);
    if (enriched.isEmpty) return null;
    final entry = enriched.first;
    _rideEntryByIdCache[trimmed] = entry;
    sw.stop();
    debugPrint('[SakayTa][Perf][Receipt] rideId=$trimmed source=fetch '
        'durationMs=${sw.elapsedMilliseconds}');
    return entry;
  }

  /// Stream of the current user's ride history with driver display info
  /// (name + plate). Supabase when configured, local otherwise.
  Stream<List<RideEntry>> rideHistoryStream({String? status}) {
    final user = currentUser;
    if (user == null) return const Stream.empty();
    final userId = user.id;
    if (SupabaseService.isConfigured) {
      return Stream<List<RideEntry>>.multi((controller) {
        final cached = getCachedRideHistory(status: status);
        if (cached != null) {
          controller.add(cached);
        }
        final tripsStream = user.isDriver
            ? SupabaseService.instance.streamRideHistoryForDriver(userId)
            : SupabaseService.instance.streamRideHistoryForPassenger(userId);
        final sub = tripsStream.asyncMap((allTrips) async {
          final allEntries = await _withDriverInfo(allTrips);
          _cachedRideHistoryUserId = userId;
          _cachedRideHistory = allEntries;
          if (status != null && status != 'all') {
            return allEntries
                .where((e) => e.trip.status == status)
                .toList();
          }
          return allEntries;
        }).listen(
          (entries) {
            if (!controller.isClosed) {
              controller.add(entries);
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!controller.isClosed && getCachedRideHistory(status: status) == null) {
              controller.addError(error, stackTrace);
            }
          },
        );
        controller.onCancel = () => sub.cancel();
      });
    }
    return _localNotifyingStream(() => _rideHistoryLocal(status: status));
  }

  Future<List<RideEntry>> _rideHistoryLocal({String? status}) async {
    final user = currentUser;
    if (user == null) return const [];
    final historyTrips = user.isDriver
        ? await trips.tripsForDriver(user.id)
        : await trips.tripsForPassenger(user.id);
    final allEntries = await _withDriverInfo(historyTrips);
    _cachedRideHistoryUserId = user.id;
    _cachedRideHistory = allEntries;
    if (status != null && status != 'all') {
      return allEntries.where((e) => e.trip.status == status).toList();
    }
    return allEntries;
  }

  Future<List<RideEntry>> _withDriverInfo(List<Trip> tripsList) async {
    if (tripsList.isEmpty) return const [];
    final sw = Stopwatch()..start();

    final self = currentUser;
    if (self != null && self.isDriver) {
      final selfPhoto =
          (self.profilePhotoUrl != null && self.profilePhotoUrl!.trim().isNotEmpty)
              ? self.profilePhotoUrl
              : driverProfile?.docProfile;
      _driverDisplayCache[self.id] = (
        name: self.fullName,
        plate: driverProfile?.plateNumber ?? '',
        photoUrl: selfPhoto,
        avatarColor: self.avatarColor,
      );
    }

    final uncachedDriverIds = tripsList
        .map((t) => t.driverId?.trim() ?? '')
        .where((id) => id.isNotEmpty && !_driverDisplayCache.containsKey(id))
        .toSet()
        .toList();

    if (uncachedDriverIds.isNotEmpty) {
      if (SupabaseService.isConfigured) {
        final batch = await SupabaseService.instance
            .getDriverDisplayInfoBatch(uncachedDriverIds);
        for (final entry in batch.entries) {
          _driverDisplayCache[entry.key] = entry.value;
        }
        for (final id in uncachedDriverIds) {
          _driverDisplayCache.putIfAbsent(
            id,
            () => (name: '', plate: '', photoUrl: null, avatarColor: 0),
          );
        }
      } else {
        await Future.wait(uncachedDriverIds.map((driverId) async {
          var name = '';
          var plate = '';
          String? photoUrl;
          var avatarColor = 0;
          try {
            final localUser = await auth.getUser(driverId);
            final localProfile = await auth.getDriverProfile(driverId);
            if (localUser != null) {
              name = localUser.fullName;
              photoUrl = localUser.profilePhotoUrl;
              avatarColor = localUser.avatarColor;
            }
            if (localProfile != null) {
              plate = localProfile.plateNumber;
              if (photoUrl == null || photoUrl.trim().isEmpty) {
                photoUrl = localProfile.docProfile;
              }
            }
          } catch (e, s) {
      AppLogger.debug('AppState non-fatal note: $e', error: e, stackTrace: s);
    }
          _driverDisplayCache[driverId] = (
            name: name,
            plate: plate,
            photoUrl: photoUrl,
            avatarColor: avatarColor,
          );
        }));
      }
    }

    final entries = <RideEntry>[];
    for (final trip in tripsList) {
      final driverId = trip.driverId?.trim();
      final info = (driverId != null && driverId.isNotEmpty)
          ? _driverDisplayCache[driverId]
          : null;
      final isAssignedOrCompleted = (driverId != null && driverId.isNotEmpty) ||
          trip.status == RideStatus.completed;
      final resolvedName = (info != null && info.name.isNotEmpty)
          ? info.name
          : (isAssignedOrCompleted ? 'Assigned Driver' : '');
      final entry = RideEntry(
        trip: trip,
        driverName: resolvedName,
        plateNumber: info?.plate ?? '',
        driverPhotoUrl: info?.photoUrl,
        driverAvatarColor: info?.avatarColor ?? 0,
      );
      _rideEntryByIdCache[trip.id] = entry;
      entries.add(entry);
    }

    sw.stop();
    debugPrint('[SakayTa][Perf][History] _withDriverInfo '
        'trips=${tripsList.length} uncachedDrivers=${uncachedDriverIds.length} '
        'durationMs=${sw.elapsedMilliseconds}');
    return entries;
  }

  /// Stream of wallet history from the authoritative earning and withdrawal
  /// ledgers. Pending/refunded rides remain visible, but only confirmed rows
  /// contribute to spendable balance and cash-collection totals.
  Stream<List<WalletEntry>> transactionsStream() {
    final user = currentUser;
    if (user == null) return const Stream.empty();
    final driverId = user.id;
    if (SupabaseService.isConfigured) {
      return Stream<List<WalletEntry>>.multi((controller) {
        final sw = Stopwatch()..start();
        final cached = getCachedWalletEntries(driverId);
        if (cached != null) {
          controller.add(cached);
        }

        List<DriverEarning>? latestEarnings;
        List<Withdrawal>? latestWithdrawals;
        Object? earningsError;
        StackTrace? earningsStack;
        var earningsResolved = false;
        var withdrawalsResolved = false;

        void emitIfReady(String trigger) {
          if (controller.isClosed) return;
          if (!earningsResolved || !withdrawalsResolved) return;
          if (latestEarnings == null &&
              earningsError != null &&
              getCachedWalletEntries(driverId) == null) {
            controller.addError(
              earningsError!,
              earningsStack ?? StackTrace.current,
            );
            return;
          }
          final earningRows = (latestEarnings ?? const <DriverEarning>[])
              .map(WalletEntry.fromEarning)
              .toList();
          final withdrawalRows = (latestWithdrawals ?? const <Withdrawal>[])
              .map(WalletEntry.fromWithdrawal)
              .toList();
          final all = <WalletEntry>[...earningRows, ...withdrawalRows]
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          _cachedWalletDriverId = driverId;
          _cachedWalletEntries = all;
          if (sw.isRunning) {
            sw.stop();
            debugPrint('[SakayTa][Perf][Wallet] initialLoad '
                'driverId=$driverId entries=${all.length} '
                'totalMs=${sw.elapsedMilliseconds}');
          } else {
            debugPrint('[SakayTa][Perf][Wallet] liveUpdate '
                'driverId=$driverId trigger=$trigger entries=${all.length}');
          }
          controller.add(all);
        }

        final earningsSub =
            SupabaseService.instance.streamDriverEarnings(driverId).listen(
          (rows) {
            latestEarnings = rows;
            earningsError = null;
            earningsResolved = true;
            emitIfReady('earnings');
          },
          onError: (Object error, StackTrace stackTrace) {
            earningsError = error;
            earningsStack = stackTrace;
            earningsResolved = true;
            emitIfReady('earnings_error');
          },
        );

        final withdrawalsSub =
            SupabaseService.instance.streamWithdrawals(driverId).listen(
          (rows) {
            latestWithdrawals = rows;
            withdrawalsResolved = true;
            emitIfReady('withdrawals');
          },
          onError: (Object error, StackTrace stackTrace) {
            debugPrint('[SakayTa][Perf][Wallet] withdrawals error '
                '(non-fatal if earnings succeeded): $error');
            latestWithdrawals ??= const <Withdrawal>[];
            withdrawalsResolved = true;
            emitIfReady('withdrawals_error');
          },
        );

        controller.onCancel = () async {
          await earningsSub.cancel();
          await withdrawalsSub.cancel();
        };
      });
    }
    return _localNotifyingStream(() async {
      await refreshTransactions();
      final list = transactions.map(WalletEntry.fromTransaction).toList();
      _cachedWalletDriverId = driverId;
      _cachedWalletEntries = list;
      return list;
    });
  }

  /// Stream of total available balance for a driver (earnings minus withdrawals)
  Stream<double> streamAvailableBalance(String driverId) {
    return transactionsStream()
        .map((entries) => entries.fold<double>(0.0, (sum, entry) {
              final confirmedIncome = entry.type == 'income' &&
                  const {'confirmed', 'completed'}
                      .contains(entry.status?.toLowerCase().trim());
              final settledWithdrawal = entry.type == 'withdrawal' &&
                  const {'paid', 'completed'}
                      .contains(entry.status?.toLowerCase().trim());
              return sum +
                  (confirmedIncome || settledWithdrawal ? entry.amount : 0);
            }));
  }

  /// Stream of total cash earnings
  Stream<double> streamCashEarnings(String driverId) {
    return transactionsStream().map((entries) => entries
        .where((e) =>
            e.type == 'income' && e.method.toLowerCase().trim() == 'cash')
        .where((e) => const {'confirmed', 'completed'}
            .contains(e.status?.toLowerCase().trim()))
        .fold<double>(0.0, (sum, e) => sum + e.amount));
  }

  /// Stream of total digital (GCash / Maya) earnings
  Stream<double> streamDigitalEarnings(String driverId) {
    return transactionsStream().map((entries) => entries
        .where((e) =>
            e.type == 'income' && e.method.toLowerCase().trim() != 'cash')
        .where((e) => const {'confirmed', 'completed'}
            .contains(e.status?.toLowerCase().trim()))
        .fold<double>(0.0, (sum, e) => sum + e.amount));
  }

  /// Stream of weekly performance stats (daily trips & earnings for current week Mon-Sun).
  Stream<WeeklyPerformanceStats> streamWeeklyPerformanceStats(String driverId) {
    if (SupabaseService.isConfigured) {
      return SupabaseService.instance
          .streamRideHistoryForDriver(driverId)
          .map((driverTrips) {
        final monday = PhilippineTime.startOfCurrentWeek();
        final sunday = monday.add(const Duration(days: 6));
        final periodLabel =
            'This week: ${DateFormat('MMM d').format(monday)}-${DateFormat('MMM d').format(sunday)}';

        final days = <DailyTripStat>[];
        int maxTrips = 0;
        int peakIndex = -1;
        double weekEarnings = 0.0;
        int weekTrips = 0;

        final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

        for (int i = 0; i < 7; i++) {
          final dayDate = monday.add(Duration(days: i));
          final dayStart = PhilippineTime.startOfDay(dayDate);
          final dayEnd = dayStart.add(const Duration(days: 1));

          final count = driverTrips.where((t) {
            final date = t.completedAt ?? t.createdAt;
            return (t.status == RideStatus.completed) &&
                !PhilippineTime.toPhilippine(date).isBefore(dayStart) &&
                PhilippineTime.toPhilippine(date).isBefore(dayEnd);
          }).length;

          final earningsOnDay = driverTrips.where((t) {
            final date = t.completedAt ?? t.createdAt;
            final localDate = PhilippineTime.toPhilippine(date);
            return t.status == RideStatus.completed &&
                !localDate.isBefore(dayStart) &&
                localDate.isBefore(dayEnd);
          }).fold<double>(0.0, (sum, t) => sum + t.fare);

          if (count > maxTrips && count > 0) {
            maxTrips = count;
            peakIndex = i;
          }

          weekEarnings += earningsOnDay;
          weekTrips += count;

          days.add(DailyTripStat(
            dayName: dayNames[i],
            date: dayDate,
            tripCount: count,
            earnings: earningsOnDay,
          ));
        }

        final finalDays = days.asMap().entries.map((e) {
          final isPeak = e.key == peakIndex && e.value.tripCount > 0;
          return DailyTripStat(
            dayName: e.value.dayName,
            date: e.value.date,
            tripCount: e.value.tripCount,
            earnings: e.value.earnings,
            isPeak: isPeak,
          );
        }).toList();

        return WeeklyPerformanceStats(
          totalEarningsThisWeek: weekEarnings,
          totalTripsThisWeek: weekTrips,
          dailyBreakdown: finalDays,
          peakDayIndex: peakIndex,
          periodLabel: periodLabel,
        );
      });
    }

    return _localNotifyingStream(() async {
      final db = await DatabaseService.instance.database;
      final tripRows = await db.query(
        'trip',
        where: 'driver_id = ?',
        whereArgs: [driverId],
      );
      final driverTrips = tripRows.map(Trip.fromMap).toList();

      final txRows = await db.query(
        'transactions',
        where: 'driver_id = ?',
        whereArgs: [driverId],
      );
      final driverTx = txRows.map(WalletTransaction.fromMap).toList();

      final now = DateTime.now();
      final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
      final sunday = monday.add(const Duration(days: 6));
      final periodLabel =
          'This week: ${DateFormat('MMM d').format(monday)}-${DateFormat('MMM d').format(sunday)}';

      final days = <DailyTripStat>[];
      int maxTrips = 0;
      int peakIndex = -1;
      double weekEarnings = 0.0;
      int weekTrips = 0;

      final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

      for (int i = 0; i < 7; i++) {
        final dayDate = monday.add(Duration(days: i));
        final dayStart = DateTime.utc(dayDate.year, dayDate.month, dayDate.day);
        final dayEnd = dayStart.add(const Duration(days: 1));

        final count = driverTrips.where((t) {
          final date = t.completedAt ?? t.createdAt;
          return (t.status == RideStatus.completed || t.driverId != null) &&
              !date.isBefore(dayStart) &&
              date.isBefore(dayEnd);
        }).length;

        final earningsOnDay = driverTx.where((tx) {
          return tx.type == 'income' &&
              !tx.createdAt.isBefore(dayStart) &&
              tx.createdAt.isBefore(dayEnd);
        }).fold<double>(0.0, (sum, tx) => sum + tx.amount);

        if (count > maxTrips && count > 0) {
          maxTrips = count;
          peakIndex = i;
        }

        weekEarnings += earningsOnDay;
        weekTrips += count;

        days.add(DailyTripStat(
          dayName: dayNames[i],
          date: dayDate,
          tripCount: count,
          earnings: earningsOnDay,
        ));
      }

      final finalDays = days.asMap().entries.map((e) {
        final isPeak = e.key == peakIndex && e.value.tripCount > 0;
        return DailyTripStat(
          dayName: e.value.dayName,
          date: e.value.date,
          tripCount: e.value.tripCount,
          earnings: e.value.earnings,
          isPeak: isPeak,
        );
      }).toList();

      return WeeklyPerformanceStats(
        totalEarningsThisWeek: weekEarnings,
        totalTripsThisWeek: weekTrips,
        dailyBreakdown: finalDays,
        peakDayIndex: peakIndex,
        periodLabel: periodLabel,
      );
    });
  }

  /// Stream of real-time passenger feedback reviews.
  Stream<List<Review>> streamDriverReviews(String driverId) {
    if (SupabaseService.isConfigured) {
      return SupabaseService.instance.streamRatingsFor(driverId).map((ratings) {
        return ratings
            .map((r) => Review(
                  id: r.id,
                  tripId: r.rideId,
                  driverId: r.toUserId,
                  passengerId: r.fromUserId,
                  passengerName: 'Passenger',
                  rating: r.stars,
                  comment: r.comment,
                  createdAt: r.createdAt,
                ))
            .toList();
      });
    }

    return _localNotifyingStream(() async {
      final db = await DatabaseService.instance.database;
      final rows = await db.query(
        'ratings',
        where: 'to_user_id = ?',
        whereArgs: [driverId],
        orderBy: 'created_at DESC',
      );
      return rows
          .map((r) => Review(
                id: (r['id'] as String?) ?? '',
                tripId: (r['trip_id'] as String?) ?? '',
                driverId: (r['to_user_id'] as String?) ?? driverId,
                passengerId: (r['from_user_id'] as String?) ?? '',
                passengerName: 'Passenger',
                rating: (r['rating'] as num?)?.toInt() ?? 5,
                comment: (r['review'] as String?) ?? '',
                createdAt: DateTime.fromMillisecondsSinceEpoch(
                    (r['created_at'] as int?) ?? 0),
              ))
          .toList();
    });
  }

  /// Stream of passenger users (admin dashboard).
  Stream<List<AppUser>> passengersStream() {
    if (SupabaseService.isConfigured) {
      return Stream.fromFuture(
          SupabaseAdminService.instance.getAdminPassengersPaginated());
    }
    return _localNotifyingStream(auth.listPassengers);
  }

  /// Cloud accounts are authoritative in Admin Web. Never merge cached staff
  /// with a failed or empty server response: doing so hides authorization and
  /// schema failures and can display deleted administrators as current.
  Stream<List<AdminAccount>> adminAccountsStream() {
    if (SupabaseService.isConfigured) {
      return SupabaseService.instance.streamAdminAccounts();
    }
    return Stream<List<AdminAccount>>.multi((controller) {
      controller.add(List.unmodifiable(_inMemoryAdmins));
      void onStateChanged() {
        if (!controller.isClosed) {
          controller.add(List.unmodifiable(_inMemoryAdmins));
        }
      }

      addListener(onStateChanged);
      controller.onCancel = () {
        removeListener(onStateChanged);
      };
    });
  }

  /// Checks whether an email address is already in use by another account.
  Future<bool> isEmailAlreadyUsed(String email) async {
    final clean = email.trim().toLowerCase();
    if (_inMemoryAdmins.any((a) => a.email.toLowerCase() == clean)) {
      return true;
    }
    return await auth.isEmailRegistered(email);
  }

  /// Creates a new administrator account with instant in-memory feedback
  /// and resilient background persistence in Firebase Auth, Firestore, and SQLite.
  Future<void> createAdminAccount({
    required String fullName,
    required String email,
    String mobile = '',
    required String password,
    String role = UserRole.admin,
    String status = AccountStatus.active,
    String permissions = AdminPermissions.standardAdmin,
    String department = 'Operations',
  }) async {
    // 1. Role-based access control guard: only Super Administrators can manage accounts
    if (currentUser == null ||
        !currentUser!.isSuperAdmin ||
        !currentUser!.isActive) {
      throw StateError(
          'Access Denied: Only authorized Super Administrators can create administrator accounts.');
    }

    final cleanEmail = email.trim().toLowerCase();
    if (fullName.trim().length < 2) {
      throw const FormatException('Admin name must be at least 2 characters.');
    }
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(cleanEmail)) {
      throw const FormatException('A valid email address is required.');
    }
    if (password.length < 6) {
      throw const FormatException('Password must be at least 6 characters.');
    }
    if (!['admin', 'super_admin'].contains(role)) {
      throw const FormatException('Invalid administrator role.');
    }
    if (role == 'super_admin') {
      throw const FormatException(
          'New accounts must receive the regular Admin role only.');
    }
    if (!['active', 'disabled', 'deactivated'].contains(status)) {
      throw const FormatException('Invalid administrator status.');
    }

    // The server must create Auth, profile, and role together. A browser-side
    // Auth signUp would replace the current administrator session; an
    // optimistic local row could remain even when the cloud operation failed.
    if (SupabaseService.isConfigured) {
      final now = DateTime.now();
      final request = AdminAccount(
        id: '',
        fullName: fullName.trim(),
        email: cleanEmail,
        mobile: mobile.trim(),
        passwordHash: '',
        role: role,
        status: AccountStatus.active,
        permissions: role == 'super_admin' ? AdminPermissions.all : permissions,
        department: department.trim(),
        createdAt: now,
        updatedAt: now,
      );
      final userId = await SupabaseService.instance
          .createAdminAccountSecure(request, password);
      if (mobile.trim().isNotEmpty) {
        await SupabaseService.instance
            .updateUser(userId, {'mobile': mobile.trim()});
      }
      if (status != AccountStatus.active) {
        await SupabaseService.instance
            .updateAdminStatus(userId, AccountStatus.deactivated);
      }
      final created = await SupabaseService.instance.getAdminAccount(userId);
      if (created == null) {
        throw StateError(
            'Created administrator is not readable from Supabase.');
      }
      _inMemoryAdmins.removeWhere((a) => a.id == userId);
      _inMemoryAdmins.insert(0, created);
      try {
        await DatabaseService.instance.createAdminAccount(created);
      } catch (error) {
        debugPrint('[ADMIN CACHE] create skipped: $error');
      }
      notifyListeners();
      return;
    }

    if (_inMemoryAdmins.any((a) => a.email.toLowerCase() == cleanEmail) ||
        await auth.isEmailRegistered(cleanEmail)) {
      throw Exception('An account with email "$cleanEmail" already exists.');
    }

    final generatedId = 'admin_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();
    final passwordHash = DatabaseService.hashPassword(password);
    final admin = AdminAccount(
      id: generatedId,
      fullName: fullName.trim(),
      email: cleanEmail,
      mobile: mobile.trim(),
      passwordHash: passwordHash,
      role: role,
      status: status == 'disabled' ? AccountStatus.deactivated : status,
      permissions: role == 'super_admin' ? AdminPermissions.all : permissions,
      department: department.trim(),
      createdAt: now,
      updatedAt: now,
    );

    await DatabaseService.instance.createAdminAccount(admin);
    _inMemoryAdmins.removeWhere((a) => a.email.toLowerCase() == cleanEmail);
    _inMemoryAdmins.insert(0, admin);
    notifyListeners();
  }

  /// Updates an existing administrator's details.
  Future<void> updateAdminAccount(AdminAccount admin) async {
    if (currentUser == null ||
        !currentUser!.isSuperAdmin ||
        !currentUser!.isActive) {
      throw StateError(
          'Access Denied: Only authorized Super Administrators can update administrator accounts.');
    }

    if (admin.fullName.trim().length < 2 ||
        !['admin', 'super_admin'].contains(admin.role)) {
      throw const FormatException('Enter a valid name and administrator role.');
    }
    if (currentUser!.id == admin.id &&
        (admin.role != 'super_admin' || !admin.isActive)) {
      throw StateError('You cannot remove your own administrator access.');
    }
    final updated = admin.copyWith(
        fullName: admin.fullName.trim(), updatedAt: DateTime.now());

    if (SupabaseService.isConfigured) {
      await SupabaseService.instance.updateAdminAccount(updated);
      final saved = await SupabaseService.instance.getAdminAccount(updated.id);
      if (saved == null) {
        throw StateError(
            'Updated administrator is not readable from Supabase.');
      }
      final cloudIndex = _inMemoryAdmins.indexWhere((a) => a.id == saved.id);
      if (cloudIndex != -1) _inMemoryAdmins[cloudIndex] = saved;
      if (currentUser!.id == saved.id) currentUser = saved.toUser();
      try {
        await DatabaseService.instance.createAdminAccount(saved);
      } catch (error) {
        debugPrint('[ADMIN CACHE] update skipped: $error');
      }
      notifyListeners();
      return;
    }

    // Optimistic in-memory update
    final idx = _inMemoryAdmins.indexWhere((a) => a.id == updated.id);
    if (idx != -1) {
      _inMemoryAdmins[idx] = updated;
    }
    if (currentUser!.id == updated.id) {
      currentUser = updated.toUser();
    }
    notifyListeners();

    try {
      await DatabaseService.instance.createAdminAccount(updated);
    } catch (e) {
      debugPrint('DatabaseService updateAdminAccount error: $e');
    }
  }

  /// Toggles an admin account between active and deactivated.
  /// Protects against self-deactivation.
  Future<void> toggleAdminAccountStatus(String id, String currentStatus) async {
    if (currentUser == null ||
        !currentUser!.isSuperAdmin ||
        !currentUser!.isActive) {
      throw StateError(
          'Access Denied: Only authorized Super Administrators can change administrator account status.');
    }

    if (currentUser?.id == id) {
      throw StateError('You cannot deactivate your own administrator account.');
    }

    final nextStatus = currentStatus == AccountStatus.active ||
            currentStatus == AccountStatus.approved
        ? AccountStatus.deactivated
        : AccountStatus.active;

    if (SupabaseService.isConfigured) {
      await SupabaseService.instance.updateAdminStatus(id, nextStatus);
      final saved = await SupabaseService.instance.getAdminAccount(id);
      if (saved == null) {
        throw StateError('Administrator status is not readable from Supabase.');
      }
      final cloudIndex = _inMemoryAdmins.indexWhere((a) => a.id == id);
      if (cloudIndex != -1) _inMemoryAdmins[cloudIndex] = saved;
      try {
        await DatabaseService.instance.updateAdminStatus(id, nextStatus);
      } catch (error) {
        debugPrint('[ADMIN CACHE] status update skipped: $error');
      }
      notifyListeners();
      return;
    }

    // Optimistic in-memory update
    final idx = _inMemoryAdmins.indexWhere((a) => a.id == id);
    if (idx != -1) {
      _inMemoryAdmins[idx] = _inMemoryAdmins[idx].copyWith(
        status: nextStatus,
        updatedAt: DateTime.now(),
      );
    }
    notifyListeners();

    try {
      await DatabaseService.instance.updateAdminStatus(id, nextStatus);
    } catch (e) {
      debugPrint('DatabaseService updateAdminStatus error: $e');
    }
  }

  /// Deletes an admin account from Firestore and the local database.
  /// Protects against self-deletion.
  Future<void> deleteAdminAccount(String id) async {
    if (currentUser == null ||
        !currentUser!.isSuperAdmin ||
        !currentUser!.isActive) {
      throw StateError(
          'Access Denied: Only authorized Super Administrators can remove administrator accounts.');
    }

    if (currentUser?.id == id) {
      throw StateError('You cannot delete your own administrator account.');
    }

    if (SupabaseService.isConfigured) {
      await SupabaseService.instance.deleteAdminAccount(id);
      _inMemoryAdmins.removeWhere((a) => a.id == id);
      try {
        await DatabaseService.instance.deleteAdminAccount(id);
      } catch (error) {
        debugPrint('[ADMIN CACHE] delete skipped: $error');
      }
      notifyListeners();
      return;
    }

    // Optimistic in-memory deletion
    _inMemoryAdmins.removeWhere((a) => a.id == id);
    notifyListeners();

    try {
      await DatabaseService.instance.deleteAdminAccount(id);
    } catch (e) {
      debugPrint('DatabaseService deleteAdminAccount error: $e');
    }
  }

  /// Suspends a driver account with reason.
  Future<void> suspendDriver(String driverId, String reason) async {
    if (SupabaseService.isConfigured) {
      await SupabaseService.instance.suspendDriver(driverId, reason);
    } else {
      await auth.setDriverStatus(driverId, AccountStatus.suspended,
          reason: reason);
    }
    notifyListeners();
  }

  /// Reactivates a suspended driver.
  Future<void> reactivateDriver(String driverId) async {
    if (SupabaseService.isConfigured) {
      await SupabaseService.instance.reactivateDriver(driverId);
    } else {
      await auth.setDriverStatus(driverId, AccountStatus.approved);
    }
    notifyListeners();
  }

  /// Updates a passenger's account status (active / restricted / suspended).
  Future<void> setPassengerAccountStatus(String userId, String status,
      {String? reason}) async {
    if (SupabaseService.isConfigured) {
      await SupabaseService.instance
          .setPassengerAccountStatus(userId, status, reason: reason);
    }
    // Keep the device cache in sync only after the server-side, admin-only
    // status RPC succeeds. AuthService never sends the local `status` field
    // to Supabase, so reopening the passenger app cannot undo this action.
    final user = await auth.getUser(userId);
    if (user != null) {
      await auth.updateUser(user.copyWith(status: status));
    }
    notifyListeners();
  }

  /// Streams platform incident and customer support reports.
  Stream<List<FireReport>> reportsStream({
    String? status,
    String? type,
    String? searchQuery,
  }) {
    if (SupabaseService.isConfigured) {
      return SupabaseService.instance.streamAllReports(
        status: status,
        type: type,
        searchQuery: searchQuery,
      );
    }
    return _localNotifyingStream(() async {
      return DatabaseService.instance.getReports(
        status: status,
        type: type,
        searchQuery: searchQuery,
      );
    });
  }

  /// Appends an investigation note to a report.
  Future<void> addReportNote(String reportId, String note) async {
    if (SupabaseService.isConfigured) {
      await SupabaseService.instance.addReportNote(reportId, note);
    }
    try {
      await DatabaseService.instance.addReportNote(reportId, note);
    } catch (e) {
      debugPrint('[Reports] local cache addReportNote skipped: $e');
    }
    notifyListeners();
  }

  /// Updates report status and optional resolution summary.
  Future<void> updateReportStatus(
    String reportId,
    String status, {
    String? resolution,
    String? adminName,
    String? adminId,
  }) async {
    final effectiveAdminId = adminId ?? currentUser?.id;
    final effectiveAdminName =
        adminName ?? currentUser?.fullName ?? 'Admin Staff';
    if (SupabaseService.isConfigured) {
      await SupabaseService.instance.updateReportStatus(
        reportId,
        status,
        resolution: resolution,
        adminId: effectiveAdminId,
        adminName: effectiveAdminName,
      );
    }
    try {
      await DatabaseService.instance.updateReportStatus(
        reportId,
        status,
        resolution: resolution,
        adminName: effectiveAdminName,
      );
    } catch (e) {
      debugPrint('[Reports] local cache updateReportStatus skipped: $e');
    }
    notifyListeners();
  }

  /// Creates a new incident / customer support report.
  ///
  /// Supabase errors (RLS, constraint, network) are rethrown so the calling
  /// form can show a real failure instead of a false success.
  Future<void> createReport(FireReport report) async {
    if (SupabaseService.isConfigured) {
      await SupabaseService.instance.createReport(report);
      try {
        await DatabaseService.instance.createReport(report);
      } catch (e) {
        debugPrint('[Reports] local cache write skipped: $e');
      }
    } else {
      await DatabaseService.instance.createReport(report);
    }
    notifyListeners();
  }

  /// Checks whether a ride exists in Supabase public.rides (or local SQLite).
  Future<bool> rideExists(String rideId) async {
    if (SupabaseService.isConfigured) {
      return SupabaseService.instance.rideExists(rideId);
    }
    final trip = await trips.getById(rideId);
    return trip != null;
  }

  /// Checks whether a user profile exists in Supabase public.profiles.
  Future<bool> profileExists(String userId) async {
    if (SupabaseService.isConfigured) {
      return SupabaseService.instance.profileExists(userId);
    }
    final user = await auth.getUser(userId);
    return user != null;
  }

  /// Admin action to force-cancel an active trip.
  Future<void> adminCancelTrip(String tripId, String reason) async {
    // SQLite not needed for admin action
    if (SupabaseService.isConfigured) {
      await SupabaseService.instance.adminCancelTrip(tripId, reason);
    }
    notifyListeners();
  }

  /// Admin action to record a refund or payment adjustment.
  Future<void> adminRefundPayment(
      String paymentId, double amount, String reason) async {
    if (currentUser?.isAdmin != true || currentUser?.isActive != true) {
      throw StateError('An active administrator account is required.');
    }
    if (!amount.isFinite || amount <= 0 || reason.trim().isEmpty) {
      throw ArgumentError('Enter a positive refund amount and a reason.');
    }
    if (SupabaseService.isConfigured) {
      await SupabaseService.instance
          .adminRefundPayment(paymentId, amount, reason);
    } else {
      await databaseService.recordAdminRefund(paymentId, amount, reason);
    }
    notifyListeners();
  }

  /// Streams TODA associations registry (with local SQLite fallback).
  Stream<List<Map<String, dynamic>>> streamTodas() {
    if (SupabaseService.isConfigured) {
      return SupabaseService.instance
          .streamTodas()
          .map((list) => list.map((e) => e.toMap()).toList());
    }
    return _localNotifyingStream(() async {
      return DatabaseService.instance.getTodas();
    });
  }

  /// Saves or updates a TODA association in Supabase, then refreshes the
  /// local cache only after the server confirms the returned row.
  Future<Map<String, dynamic>> saveToda(Map<String, dynamic> todaData) async {
    if (SupabaseService.isConfigured) {
      await SupabaseService.instance
          .ensureCurrentAdminAuthorized(currentUser?.id);
      final saved = await SupabaseService.instance.saveToda(todaData);
      try {
        await DatabaseService.instance.saveToda(saved);
      } catch (error, stackTrace) {
        // The cloud row is authoritative. A local cache failure must not turn
        // a committed admin operation into an apparent save failure.
        debugPrint('[AdminTODA][LOCAL_CACHE_ERROR] type=${error.runtimeType} '
            'message=$error');
        debugPrintStack(stackTrace: stackTrace);
      }
      notifyListeners();
      return saved;
    }

    await DatabaseService.instance.saveToda(todaData);
    notifyListeners();
    return Map<String, dynamic>.from(todaData);
  }

  /// Deletes a TODA association.
  Future<void> deleteToda(String todaId) async {
    await DatabaseService.instance.deleteToda(todaId);
    if (SupabaseService.isConfigured) {
      await SupabaseService.instance.deleteToda(todaId);
    }
    notifyListeners();
  }

  /// Gets current fare matrix records.
  Future<List<Map<String, dynamic>>> getFareMatrix() async {
    return DatabaseService.instance.getFareMatrix();
  }

  /// Updates fare pricing for a vehicle type.
  Future<void> updateFareMatrix(
      String vehicleType, double baseFare, double perKmRate) async {
    final cleanType = vehicleType.trim().toLowerCase();
    final type =
        cleanType.contains('habal') ? VehicleType.habal : VehicleType.tricycle;

    final existing = getFareMatrixFor(type);
    final updated = FareMatrix(
      id: existing.id,
      vehicleType: existing.vehicleType,
      baseFare: baseFare,
      includedBaseDistance: existing.includedBaseDistance,
      perKmRate: perKmRate,
      perMinuteRate: existing.perMinuteRate,
      minimumFare: existing.minimumFare,
      bookingFee: existing.bookingFee,
      surgeMultiplier: existing.surgeMultiplier,
      commissionPercent: existing.commissionPercent,
      isActive: existing.isActive,
      updatedAt: DateTime.now(),
    );

    await fareMatrixRepo.updateMatrix(updated);
    notifyListeners();
  }

  /// Streams rides for monitoring.
  Stream<List<Trip>> allRidesStream({
    String? status,
    String? searchQuery,
    int limit = 150,
  }) {
    if (SupabaseService.isConfigured) {
      return SupabaseService.instance.streamAllRides(
        status: status,
        searchQuery: searchQuery,
        limit: limit,
      );
    }
    return _localNotifyingStream(() async {
      final db = await DatabaseService.instance.database;
      final rows =
          await db.query('trip', orderBy: 'created_at DESC', limit: limit);
      var list = rows.map((r) => Trip.fromMap(r)).toList();
      if (status != null && status != 'all') {
        list = list.where((t) => t.status == status).toList();
      }
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.toLowerCase().trim();
        list = list
            .where((t) =>
                t.id.toLowerCase().contains(q) ||
                t.pickupAddress.toLowerCase().contains(q) ||
                t.dropoffAddress.toLowerCase().contains(q))
            .toList();
      }
      return list;
    });
  }

  /// Streams payments across the platform.
  Stream<List<FirePayment>> allPaymentsStream({
    String? status,
    String? method,
    String? searchQuery,
    int limit = 150,
  }) {
    if (SupabaseService.isConfigured) {
      return SupabaseService.instance.streamAllPayments(
        status: status,
        method: method,
        searchQuery: searchQuery,
        limit: limit,
      );
    }
    return _localNotifyingStream(() async {
      return DatabaseService.instance.getLocalPayments(
        status: status,
        method: method,
        searchQuery: searchQuery,
        limit: limit,
      );
    });
  }

  Stream<int> adminTotalRidesStream() {
    if (SupabaseService.isConfigured) {
      return SupabaseService.instance.streamAdminTotalRides();
    }
    return _localNotifyingStream(() async {
      final rides = await allRidesStream(limit: 100000).first;
      return rides.length;
    });
  }

  Stream<int> adminActiveRidesStream() {
    if (SupabaseService.isConfigured) {
      return SupabaseService.instance.streamAdminActiveRides();
    }
    return _localNotifyingStream(() async {
      final rides = await allRidesStream(limit: 100000).first;
      return rides
          .where((ride) => kActiveRideStatuses.contains(ride.status))
          .length;
    });
  }

  Stream<int> adminCompletedRidesStream() {
    if (SupabaseService.isConfigured) {
      return SupabaseService.instance.streamAdminCompletedRides();
    }
    return _localNotifyingStream(() async {
      final rides = await allRidesStream(limit: 100000).first;
      return rides.where((ride) => ride.status == RideStatus.completed).length;
    });
  }

  Stream<int> adminCancelledRidesStream() {
    if (SupabaseService.isConfigured) {
      return SupabaseService.instance.streamAdminCancelledRides();
    }
    return _localNotifyingStream(() async {
      final rides = await allRidesStream(limit: 100000).first;
      return rides.where((ride) => ride.status == RideStatus.cancelled).length;
    });
  }

  Stream<bool> adminHealthStream() {
    if (SupabaseService.isConfigured) {
      return Stream.fromFuture(SupabaseService.instance.adminHealthOnce());
    }
    return Stream.value(false);
  }

  Stream<int> adminTotalDriversStream() {
    if (SupabaseService.isConfigured) {
      return Stream.fromFuture(
          SupabaseService.instance.adminTotalDriversOnce());
    }
    return _localNotifyingStream(() async {
      final drivers = await auth.listDrivers();
      return drivers.length;
    });
  }

  Stream<int> adminTotalPassengersStream() {
    if (SupabaseService.isConfigured) {
      return Stream.fromFuture(
          SupabaseService.instance.adminTotalPassengersOnce());
    }
    return _localNotifyingStream(() async {
      final passengers = await auth.listPassengers();
      return passengers.length;
    });
  }

  Stream<int> adminActiveDriversStream() {
    if (SupabaseService.isConfigured) {
      return Stream.fromFuture(
          SupabaseService.instance.adminActiveDriversOnce());
    }
    return _localNotifyingStream(() async {
      final drivers = await auth.listDrivers();
      return drivers.where((d) => d.isOnline).length;
    });
  }

  Stream<double> adminRevenueTodayStream() {
    if (SupabaseService.isConfigured) {
      return Stream.fromFuture(
          SupabaseService.instance.adminRevenueTodayOnce());
    }
    return _localNotifyingStream(() async {
      final all = await earnings.allTransactions();
      return all
          .where((t) => t.type == 'income')
          .fold<double>(0.0, (sum, t) => sum + t.amount);
    });
  }

  /// Gross completed fares per day for the last [days] days (oldest first) -
  /// the real data behind the admin revenue chart.
  Stream<List<double>> weeklyRevenueStream({int days = 7}) {
    if (SupabaseService.isConfigured) {
      return allRidesStream(status: RideStatus.completed, limit: 10000)
          .map((rides) => _dailyRevenueSeries(
                rides
                    .where((ride) => ride.status == RideStatus.completed)
                    .map((ride) =>
                        (ride.completedAt ?? ride.createdAt, ride.fare))
                    .toList(),
                days,
              ));
    }
    return _localNotifyingStream(() async {
      final all = await earnings.allTransactions();
      return _dailyRevenueSeries(
        all
            .where((t) => t.type == 'income')
            .map((t) => (t.createdAt, t.amount))
            .toList(),
        days,
      );
    });
  }

  /// Updates the current user's profile locally + in Firestore.
  Future<void> updateProfile({required String fullName}) async {
    final user = currentUser;
    if (user == null || fullName.trim().isEmpty) return;
    final updated = user.copyWith(fullName: fullName.trim());
    if (user.isAdmin) {
      final admin = await databaseService.getAdminById((user as dynamic).id) ??
          await SupabaseService.instance.getAdminAccount((user as dynamic).id);
      if (admin == null) {
        throw StateError('Administrator profile was not found.');
      }
      final profile =
          admin.copyWith(fullName: fullName.trim(), updatedAt: DateTime.now());
      if (SupabaseService.isConfigured) {
        await SupabaseService.instance
            .updateAdminProfile((user as dynamic).id, fullName.trim());
      }
      await databaseService.createAdminAccount(profile);
    } else {
      await auth.updateUser(updated);
    }
    currentUser = updated;
    notifyListeners();
  }

  Future<void> changeAdminPassword(
    String password, {
    String? currentPassword,
  }) async {
    final user = currentUser;
    if (user == null || !user.isAdmin || !user.isActive) {
      throw StateError('Sign in to an active administrator account first.');
    }
    if (password.length < 6) {
      throw const FormatException('Password must be at least 6 characters.');
    }
    if (currentPassword != null && currentPassword.isNotEmpty) {
      if (currentPassword == password) {
        throw const FormatException(
            'New password must be different from your current password.');
      }
      if (user.passwordHash.isNotEmpty) {
        if (!DatabaseService.verifyPassword(
            currentPassword, user.passwordHash)) {
          throw const FormatException(
              'The current password you entered is incorrect.');
        }
      }
    }
    final injectedClient = PasswordChangeService.activeClientOrNull;
    if (SupabaseAuthService.isConfigured || injectedClient != null) {
      final client = injectedClient ?? Supabase.instance.client;
      final authUser = client.auth.currentUser;
      if (authUser == null || authUser.id != user.id) {
        throw StateError('Sign in again before changing your password.');
      }
      final email = (user.email ?? authUser.email ?? '').trim().toLowerCase();
      if (currentPassword != null &&
          currentPassword.isNotEmpty &&
          email.isNotEmpty) {
        try {
          final verifyRes = await client.auth.signInWithPassword(
            email: email,
            password: currentPassword,
          );
          if (verifyRes.user == null || verifyRes.user!.id != user.id) {
            throw const FormatException(
                'The current password you entered is incorrect.');
          }
        } on AuthException catch (e) {
          final lower = e.message.toLowerCase();
          if (e.code == 'invalid_credentials' ||
              e.code == 'invalid-credentials' ||
              e.code == 'invalid-credential' ||
              lower.contains('invalid login credentials')) {
            throw const FormatException(
                'The current password you entered is incorrect.');
          }
          throw PasswordAuthException(
            PasswordChangeService.formatErrorMessage(e),
            code: e.code,
            statusCode: e.statusCode,
            cause: e,
          );
        }
      }
      try {
        await client.auth.updateUser(
          UserAttributes(
            password: password,
            currentPassword: currentPassword,
          ),
        );
      } on AuthException catch (e) {
        throw PasswordAuthException(
          PasswordChangeService.formatErrorMessage(e),
          code: e.code,
          statusCode: e.statusCode,
          cause: e,
        );
      }
      final token = client.auth.currentSession?.accessToken;
      if (token != null) {
        SupabaseAdminService.instance.cacheAuthorizedAdmin(user.id, token);
      }
    }
    final hash = DatabaseService.hashPassword(password);
    try {
      await databaseService.updateAdminPassword((user as dynamic).id, hash);
    } catch (e, s) {
      AppLogger.debug('AppState non-fatal note: $e', error: e, stackTrace: s);
    }
    final idx = _inMemoryAdmins.indexWhere((a) => a.id == (user as dynamic).id);
    if (idx != -1) {
      _inMemoryAdmins[idx] = _inMemoryAdmins[idx].copyWith(passwordHash: hash);
    }
    currentUser = user.copyWith(passwordHash: hash);
    notifyListeners();
  }

  // --- Driver earnings helpers (computed from real transaction records) ---

  double get totalEarnings => transactions
      .where((t) => t.type == 'income')
      .fold(0.0, (sum, t) => sum + t.amount);

  double get totalWithdrawn => transactions
      .where((t) => t.type == 'withdrawal')
      .fold(0.0, (sum, t) => sum + t.amount);

  double get walletBalance => totalEarnings - totalWithdrawn;

  double get todayEarnings {
    final now = PhilippineTime.now();
    return transactions
        .where((t) =>
            t.type == 'income' && PhilippineTime.isSameDay(t.createdAt, now))
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  int get tripsTodayCount => transactions
      .where((t) =>
          t.type == 'income' &&
          PhilippineTime.isSameDay(t.createdAt, PhilippineTime.now()))
      .length;

  Future<void> refreshTodayDrivingHours() async {
    final user = currentUser;
    if (user == null || !user.isDriver || !SupabaseService.isConfigured) return;
    try {
      _todayOnlineHours =
          await SupabaseService.instance.driverOnlineHoursToday(user.id);
      _hasServerTodayOnlineHours = true;
      notifyListeners();
    } catch (error) {
      debugPrint('SakayTa: online hours refresh note: $error');
    }
  }

  /// Driving hours from all persisted online sessions for the current
  /// Philippine day, including the active session while its heartbeat is
  /// healthy.
  double get todayDrivingHours {
    var total = _todayOnlineHours;
    if (!_hasServerTodayOnlineHours && _onlineStartedAt != null) {
      total += DateTime.now().difference(_onlineStartedAt!).inMinutes / 60.0;
    }
    return double.parse(total.toStringAsFixed(1));
  }

  /// Reverse geocodes the driver's current location with local caching and Nominatim
  Future<String> getAddressForLocation(Geo geo) async {
    final key = '${geo.lat.toStringAsFixed(3)},${geo.lng.toStringAsFixed(3)}';
    if (_locationAddressCache.containsKey(key)) {
      return _locationAddressCache[key]!;
    }
    try {
      final address = await OsmMapService.instance.reverseGeocode(geo);
      if (address != null && address.isNotEmpty) {
        final firstParts = address.split(',').take(2).join(', ').trim();
        _locationAddressCache[key] = firstParts;
        return firstParts;
      }
    } catch (e, s) {
      AppLogger.debug('AppState non-fatal note: $e', error: e, stackTrace: s);
    }
    return '${geo.lat.toStringAsFixed(5)}, ${geo.lng.toStringAsFixed(5)}';
  }

  /// Real-time stream of incoming passenger ride requests matching this driver
  Stream<List<IncomingRideRequest>> streamIncomingRequestsForDriver(
    AppUser driver, {
    Geo? driverLocation,
    double radiusKm = 10.0,
    Trip? assignedTrip,
  }) {
    final vType = driverProfile?.vehicleType ?? VehicleType.tricycle;
    final lat = driverLocation?.lat ?? driver.latitude;
    final lng = driverLocation?.lng ?? driver.longitude;

    final rawStream = SupabaseService.isConfigured
        ? SupabaseService.instance.streamIncomingRequestsForDriver(
            driverId: driver.id,
            vehicleType: vType,
            lat: lat,
            lng: lng,
            radiusKm: radiusKm,
          )
        : _localNotifyingStream(() => trips.listIncomingTripsForDriver(
              driver.id,
              vType,
              driverLocation: lat != null && lng != null ? Geo(lat, lng) : null,
              radiusKm: radiusKm,
            ));

    var firstEmission = true;
    return rawStream.asyncExpand((rawTrips) async* {
      _traceDriverRequest(
        event: firstEmission ? 'INITIAL_FETCH' : 'REALTIME_UPDATE',
        source: SupabaseService.isConfigured ? 'Realtime' : 'LocalDatabase',
        driverId: driver.id,
        trips: rawTrips,
        isOnline: driver.isOnline,
        uiBefore: firstEmission ? 'loading' : 'requestAvailable',
        uiAfter: rawTrips.isEmpty ? 'verifyingEmpty' : 'requestAvailable',
      );
      firstEmission = false;
      final mergedTrips = mergeAssignedSearchingRide(
        rawTrips,
        assignedTrip,
        driver.id,
      );
      final stableTrips = await _stabilizeIncomingTrips(
        driver: driver,
        vehicleType: vType,
        latitude: lat,
        longitude: lng,
        radiusKm: radiusKm,
        candidates: mergedTrips,
      );
      final validTrips =
          stableTrips.where((t) => !_declinedTripIds.contains(t.id)).toList();
      final immediateRequests = validTrips
          .map((trip) => _incomingRequestFromTrip(
                trip,
                latitude: lat,
                longitude: lng,
              ))
          .toList();

      // The ride row already contains the passenger name and route. Emit it
      // immediately; profile photos and ratings are presentational enrichment
      // and must never delay the incoming request card.
      yield immediateRequests;
      if (validTrips.isEmpty) return;

      final passengers = await Future.wait(
        validTrips.map((trip) => _loadIncomingPassenger(trip.passengerId)),
      );
      if (!passengers.any((passenger) => passenger != null)) return;

      yield [
        for (var index = 0; index < validTrips.length; index++)
          _incomingRequestFromTrip(
            validTrips[index],
            latitude: lat,
            longitude: lng,
            passenger: passengers[index],
          ),
      ];
    });
  }

  Future<List<Trip>> _stabilizeIncomingTrips({
    required AppUser driver,
    required VehicleType vehicleType,
    required double? latitude,
    required double? longitude,
    required double radiusKm,
    required List<Trip> candidates,
  }) async {
    final byId = <String, Trip>{
      for (final trip in candidates)
        if (!_declinedTripIds.contains(trip.id)) trip.id: trip,
    };
    final previous = _stableIncomingTripsByDriver[driver.id] ?? const <Trip>[];

    for (final prior in previous) {
      if (byId.containsKey(prior.id) || _declinedTripIds.contains(prior.id)) {
        continue;
      }
      if (!SupabaseService.isConfigured) {
        byId[prior.id] = prior;
        continue;
      }

      try {
        final refreshed = await SupabaseService.instance.getTrip(prior.id);
        _traceDriverRequest(
          event: 'AUTHORITATIVE_REFRESH',
          source: 'Database',
          driverId: driver.id,
          trips: refreshed == null ? const [] : [refreshed],
          requestId: prior.id,
          isOnline: driver.isOnline,
          uiBefore: 'requestAvailable',
          uiAfter: refreshed == null ? 'empty' : refreshed.status,
        );
        if (refreshed != null &&
            _isIncomingTripEligible(
              refreshed,
              driverId: driver.id,
              vehicleType: vehicleType,
              latitude: latitude,
              longitude: longitude,
              radiusKm: radiusKm,
            )) {
          byId[refreshed.id] = refreshed;
        }
      } catch (error) {
        // A transport/channel interruption is not evidence that the request
        // was cancelled or accepted elsewhere. Keep the exact previous row.
        byId[prior.id] = prior;
        _traceDriverRequest(
          event: 'REFRESH_RETAINED',
          source: 'InMemoryCache',
          driverId: driver.id,
          trips: [prior],
          requestId: prior.id,
          note: error.runtimeType.toString(),
          isOnline: driver.isOnline,
          uiBefore: 'requestAvailable',
          uiAfter: 'requestAvailable',
        );
      }
    }

    final stable = byId.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _stableIncomingTripsByDriver[driver.id] = stable;
    return stable;
  }

  bool _isIncomingTripEligible(
    Trip trip, {
    required String driverId,
    required VehicleType vehicleType,
    required double? latitude,
    required double? longitude,
    required double radiusKm,
  }) {
    if (trip.status != RideStatus.searching) return false;
    if (trip.driverId != null && trip.driverId!.isNotEmpty) {
      return trip.driverId == driverId;
    }
    if (trip.vehicleType != vehicleType) return false;
    if (latitude != null &&
        longitude != null &&
        Geo.distanceKm(Geo(latitude, longitude), trip.pickup) > radiusKm) {
      return false;
    }
    return true;
  }

  void _traceDriverRequest({
    required String event,
    required String source,
    required String driverId,
    required List<Trip> trips,
    String? requestId,
    String? note,
    bool? isOnline,
    String? uiBefore,
    String? uiAfter,
  }) {
    final ids = trips.map((trip) => trip.id).join(',');
    final statuses = trips.map((trip) => trip.status).join(',');
    final assignedDrivers =
        trips.map((trip) => trip.driverId ?? 'null').join(',');
    debugPrint('[SakayTa][DriverRequest][$event] source=$source '
        'driverId=$driverId requestId=${requestId ?? ids} '
        'status=$statuses assignedDriver=$assignedDrivers '
        'isOnline=${isOnline ?? currentUser?.isOnline} '
        'currentDriverRide=${activeTrip?.id ?? 'null'} '
        'uiBefore=${uiBefore ?? 'unchanged'} '
        'uiAfter=${uiAfter ?? 'unchanged'} count=${trips.length} '
        'timestamp=${DateTime.now().toUtc().toIso8601String()}'
        '${note == null ? '' : ' note=$note'}');
  }

  Future<AppUser?> _loadIncomingPassenger(String passengerId) async {
    if (SupabaseService.isConfigured) {
      try {
        final passenger = await SupabaseService.instance.getUser(passengerId);
        if (passenger != null) return passenger;
      } catch (error) {
        debugPrint('[SakayTa][DriverIncoming] passenger profile note: '
            '${error.runtimeType}');
      }
    }
    try {
      return await auth.getUser(passengerId);
    } catch (_) {
      return null;
    }
  }

  IncomingRideRequest _incomingRequestFromTrip(
    Trip trip, {
    double? latitude,
    double? longitude,
    AppUser? passenger,
  }) {
    final passengerName = passenger?.fullName.trim().isNotEmpty == true
        ? passenger!.fullName
        : trip.passengerName;
    final rating = passenger?.rating ?? 0;
    final driverLocation = latitude != null && longitude != null
        ? Geo(latitude, longitude)
        : trip.pickup;
    final distanceKm = Geo.distanceKm(driverLocation, trip.pickup);
    return IncomingRideRequest(
      trip: trip,
      passengerName: passengerName.trim().isNotEmpty
          ? _formatShortName(passengerName)
          : 'Passenger',
      passengerPhoto: passenger?.profilePhotoUrl,
      passengerRating: rating,
      passengerTag: passenger != null && passenger.ratingCount > 0
          ? '${rating.toStringAsFixed(1)} Passenger'
          : 'Passenger',
      distanceKm: distanceKm,
      durationMins: (distanceKm / 25 * 60).ceil().clamp(1, 60),
      requestTime: trip.createdAt,
    );
  }

  /// Immediate display model while the broader Realtime request stream is
  /// attaching. The assigned ride remains authoritative; profile enrichment
  /// can arrive on the next stream event.
  IncomingRideRequest incomingRequestFallback(Trip trip, AppUser driver) {
    return _incomingRequestFromTrip(
      trip,
      latitude: driver.latitude,
      longitude: driver.longitude,
    );
  }

  static String _formatShortName(String full) {
    final parts = full.trim().split(RegExp(r'\s+'));
    if (parts.length <= 1) return full;
    return '${parts.first} ${parts.last[0].toUpperCase()}.';
  }

  /// Maps the coded exceptions raised by the `accept_ride` RPC to a specific
  /// driver-facing message. Unknown backend errors keep their real text.
  static String _acceptErrorMessage(Object error) {
    final raw = error is PostgrestException ? error.message : error.toString();
    final code = error is PostgrestException ? error.code : null;
    if (raw.contains('DRIVER_OFFLINE')) {
      return 'You are offline on the server. Go Online again, then accept.';
    }
    if (raw.contains('DRIVER_HAS_ACTIVE_RIDE')) {
      return 'You already have another active ride. Finish it first.';
    }
    if (raw.contains('DRIVER_NOT_APPROVED')) {
      return 'Your driver account is not approved for rides yet.';
    }
    if (raw.contains('DRIVER_VEHICLE_MISMATCH')) {
      return 'This request is for a different vehicle type.';
    }
    if (raw.contains('DRIVER_PROFILE_MISSING')) {
      return 'No driver record was found for this account.';
    }
    if (raw.contains('DRIVER_NOT_AUTHENTICATED') ||
        raw.contains('authentication required')) {
      return 'Your session expired. Sign in again.';
    }
    if (code == '42501' || raw.contains('permission denied')) {
      return 'The server denied this action (permission). Please contact support.';
    }
    if (error is AuthException) {
      return 'Your session expired. Sign in again.';
    }
    if (raw.contains('SocketException') ||
        raw.contains('Failed host lookup') ||
        raw.contains('ClientException') ||
        raw.contains('TimeoutException')) {
      return 'Network error while accepting. Check your connection and retry.';
    }
    return 'Unable to accept ride: $raw';
  }

  /// Atomically accepts an incoming trip via backend transaction
  Future<bool> acceptTripAtomic(Trip trip) async {
    final user = currentUser;
    if (user == null) return false;
    _traceDriverRequest(
      event: 'ACCEPT_START',
      source: SupabaseService.isConfigured ? 'RPC' : 'LocalDatabase',
      driverId: user.id,
      trips: [trip],
      requestId: trip.id,
      isOnline: user.isOnline,
      uiBefore: 'requestAvailable',
      uiAfter: 'accepting',
    );
    var success = false;
    if (SupabaseService.isConfigured) {
      Object? acceptError;
      try {
        success = await SupabaseService.instance.atomicAcceptBooking(
          rideId: trip.id,
          driver: user,
        );
      } catch (error) {
        acceptError = error;
      }
      if (!success) {
        if (acceptError != null && kDebugMode) {
          debugPrint('[SakayTa][DriverRequest][ACCEPT_RPC_ERROR] '
              'rideId=${trip.id} driverUid=${user.id} '
              'type=${acceptError.runtimeType} '
              'code=${acceptError is PostgrestException ? acceptError.code : '-'} '
              'message=${acceptError is PostgrestException ? acceptError.message : acceptError}');
        }
        Trip? authoritative;
        try {
          authoritative = await SupabaseService.instance.getTrip(trip.id);
        } catch (e, s) {
      AppLogger.debug('AppState non-fatal note: $e', error: e, stackTrace: s);
    }
        _traceDriverRequest(
          event: 'ACCEPT_REFRESH',
          source: 'Database',
          driverId: user.id,
          trips: authoritative == null ? const [] : [authoritative],
          requestId: trip.id,
          isOnline: user.isOnline,
          uiBefore: 'accepting',
          uiAfter: authoritative?.status ?? 'deletedOrHidden',
        );
        if (authoritative?.status == RideStatus.accepted &&
            authoritative?.driverId == user.id) {
          success = true;
        } else if (acceptError != null) {
          // Surface the real backend reason. Never replace an RPC/database
          // error with a generic eligibility message.
          throw StateError(_acceptErrorMessage(acceptError));
        } else if (authoritative?.status == RideStatus.searching) {
          throw StateError(
            'The ride is still open but the server declined this accept. '
            'Pull to refresh and try again.',
          );
        }
      }
    } else {
      success = await trips.atomicAccept(trip.id, user);
    }
    if (success) {
      final acceptedTrip = trip.copyWith(
        driverId: (user as dynamic).id,
        status: RideStatus.accepted,
        acceptedAt: DateTime.now(),
      );
      activeTrips = [
        ...activeTrips.where((t) => t.id != acceptedTrip.id),
        acceptedTrip,
      ];
      activeTrip = activeTrips.firstOrNull ?? acceptedTrip;
      _stableIncomingTripsByDriver[user.id]
          ?.removeWhere((candidate) => candidate.id == trip.id);
      _traceDriverRequest(
        event: 'ACCEPT_SUCCESS',
        source: SupabaseService.isConfigured ? 'RPC' : 'LocalDatabase',
        driverId: user.id,
        trips: [acceptedTrip],
        requestId: trip.id,
        isOnline: user.isOnline,
        uiBefore: 'accepting',
        uiAfter: 'accepted',
      );
      notifyListeners();
      await refreshTrips();
      try {
        await refreshUser();
      } catch (error) {
        debugPrint('[SakayTa][DriverRequest][PROFILE_REFRESH_NOTE] '
            '${error.runtimeType}');
      }
      return true;
    }
    _traceDriverRequest(
      event: 'ACCEPT_REJECTED',
      source: SupabaseService.isConfigured ? 'RPC' : 'LocalDatabase',
      driverId: user.id,
      trips: [trip],
      requestId: trip.id,
      isOnline: user.isOnline,
      uiBefore: 'accepting',
      uiAfter: 'unavailable',
    );
    return false;
  }

  /// Declines an incoming trip request for this driver
  Future<void> declineTrip(Trip trip) async {
    final user = currentUser;
    _declinedTripIds.add(trip.id);
    if (user != null) {
      _stableIncomingTripsByDriver[user.id]
          ?.removeWhere((candidate) => candidate.id == trip.id);
    }
    if (user != null) {
      if (SupabaseService.isConfigured) {
        await SupabaseService.instance.declineBooking(
          rideId: trip.id,
          driverId: (user as dynamic).id,
        );
      }
      await trips.declineIncoming(trip.id, (user as dynamic).id);
      await refreshUser();
    }
    notifyListeners();
  }

  /// Stream of driver users for the admin dashboard. Uses the Firestore
  /// `users` collection when Firebase is configured; falls back to the local
  /// SQLite database in demo/offline mode.
  Stream<List<AppUser>> driversStream({String? status}) {
    if (SupabaseService.isConfigured) {
      return SupabaseService.instance.streamDrivers(status: status);
    }
    return _localNotifyingStream(() => auth.listDrivers(status: status));
  }

  /// Stream of drivers waiting for admin verification.
  Stream<List<AppUser>> pendingDriversStream() {
    if (SupabaseService.isConfigured) {
      return SupabaseService.instance.streamPendingDrivers();
    }
    return _localNotifyingStream(
        () => auth.listDrivers(status: AccountStatus.pending));
  }

  /// Stream of driver applications (user + profile + verification status) for admin review.
  Stream<List<DriverApplication>> pendingDriverApplicationsStream(
      {int? limit}) {
    if (SupabaseService.isConfigured) {
      return SupabaseService.instance
          .streamPendingDriverApplications(limit: limit);
    }
    return _localNotifyingStream(() async {
      final pendingUsers =
          await auth.listDrivers(status: AccountStatus.pending);
      final list = <DriverApplication>[];
      for (final user in pendingUsers) {
        if (limit != null && list.length >= limit) break;
        final profile = await auth.getDriverProfile((user as dynamic).id);
        list.add(DriverApplication(
          user: user,
          profile: profile ??
              DriverProfile(
                userId: (user as dynamic).id,
                vehicleType: VehicleType.tricycle,
                submittedAt: user.createdAt,
              ),
          verificationStatus: user.status,
        ));
      }
      return list;
    });
  }

  /// Creates a real ride. [driverId] optionally assigns the specific driver
  /// the passenger picked from the nearby-drivers list (otherwise the trip
  /// enters the matching pool). Returns the created trip, or null on failure.
  Future<Trip?> requestTrip({
    required String pickupAddress,
    required String dropoffAddress,
    required Geo pickup,
    required Geo dropoff,
    required VehicleType vehicleType,
    required String paymentMethod,
    required double estimatedFare,
    double? distanceKm,
    int? durationMin,
    String? driverId,
    int passengerCount = 1,
  }) async {
    final user = currentUser;
    if (user == null) return null;
    if (_requestingRide) return activeTrip;

    if (SupabaseService.isConfigured) {
      final authUid = Supabase.instance.client.auth.currentUser?.id;
      if (authUid == null || authUid != (user as dynamic).id) {
        throw StateError('Your session could not be verified. Sign in again.');
      }
      // Do not silently return an existing trip when explicitly requesting a new one.
      // This prevents the bug where a new destination is replaced by an old stuck trip.
    }

    _requestingRide = true;
    try {
      if (driverId != null && SupabaseService.isConfigured) {
        final requestable =
            await SupabaseService.instance.isDriverRequestable(driverId);
        if (!requestable) {
          throw StateError(
              'This driver is no longer available. Please choose another driver.');
        }
      }

      // A selected-driver booking is only real after the secured Supabase RPC
      // returns the created ride. Do not silently queue it as a successful
      // local booking based on a stale connectivity flag.
      if (SupabaseService.isConfigured) {
        activeTrip = await trips.requestTrip(
          passengerId: (user as dynamic).id,
          vehicleType: vehicleType,
          pickupAddress: pickupAddress,
          dropoffAddress: dropoffAddress,
          pickup: pickup,
          dropoff: dropoff,
          paymentMethod: paymentMethod,
          driverId: driverId,
          estimatedFare: estimatedFare,
          distanceKm: distanceKm,
          durationMin: durationMin,
          passengerCount: passengerCount,
        );
        if (activeTrip != null) {
          debugPrint('[SakayTa][Booking] rideId=${activeTrip!.id} '
              'driverId=${activeTrip!.driverId} '
              'status=${activeTrip!.status} persisted=1');
          try {
            await SupabaseService.instance
                .incrementPassengerRideCount((user as dynamic).id);
          } catch (error) {
            debugPrint('[SakayTa][Booking] rideId=${activeTrip!.id} '
                'rideCountError=${error.runtimeType}');
          }
        }
      } else {
        if (driverId != null) {
          throw StateError(
              'Internet connection is required to book a selected driver.');
        }
        // Create local active ride in SQLite first so ride tracking works offline
        activeTrip = await trips.requestTrip(
          passengerId: (user as dynamic).id,
          vehicleType: vehicleType,
          pickupAddress: pickupAddress,
          dropoffAddress: dropoffAddress,
          pickup: pickup,
          dropoff: dropoff,
          paymentMethod: paymentMethod,
          driverId: driverId,
          estimatedFare: estimatedFare,
          distanceKm: distanceKm,
          durationMin: durationMin,
          queued: true,
          passengerCount: passengerCount,
        );

        // Record in sync queue for automatic cloud synchronization
        await sync.queueBooking(
          passengerId: (user as dynamic).id,
          vehicleType: vehicleType,
          pickupAddress: pickupAddress,
          dropoffAddress: dropoffAddress,
          pickup: pickup,
          dropoff: dropoff,
          paymentMethod: paymentMethod,
          driverId: driverId,
          tripId: activeTrip?.id,
        );
        pendingSyncCount = await sync.pendingCount();
      }
      notifyListeners();
      return activeTrip;
    } finally {
      _requestingRide = false;
    }
  }

  Future<SyncResult?> flushSyncQueue() async {
    if (syncing) return null;
    syncing = true;
    notifyListeners();
    try {
      final result = await sync.syncAll();
      pendingSyncCount = result.remaining;
      await refreshTrips();
      await refreshTransactions();
      await refreshUser();
      return result;
    } catch (e) {
      debugPrint('AppState flushSyncQueue error: $e');
      return null;
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  Future<void> setTripStatus(String tripId, String status) async {
    await trips.setStatus(tripId, status);
    if (isOnline && SupabaseService.isConfigured) {
      try {
        await SupabaseService.instance.updateTrip(tripId, {'status': status});
      } catch (e) {
        debugPrint('AppState setTripStatus cloud fallback to queue: $e');
        await sync.queueTripStatus(tripId: tripId, status: status);
        pendingSyncCount = await sync.pendingCount();
      }
    } else {
      await sync.queueTripStatus(tripId: tripId, status: status);
      pendingSyncCount = await sync.pendingCount();
    }
    await refreshTrips();
  }

  Future<void> autoAcceptActiveTrip() async {
    final trip = activeTrip;
    if (trip == null || trip.driverId == null) return;
    if (trip.status == RideStatus.searching) {
      await trips.acceptIncoming(trip.id, trip.driverId!);
      if (!isOnline) {
        await sync.queueTripStatus(
          tripId: trip.id,
          status: RideStatus.accepted,
        );
        pendingSyncCount = await sync.pendingCount();
      }
      await refreshTrips();
    }
  }

  /// Driver confirms arrival at the pickup point.
  Future<bool> arriveAtPickup({String? tripId}) async {
    final trip = (tripId != null
            ? activeTrips
                .cast<Trip?>()
                .firstWhere((t) => t?.id == tripId, orElse: () => null)
            : null) ??
        activeTrip;
    final driver = currentUser;
    if (trip == null || driver == null || !driver.isDriver) return false;
    if (trip.driverId != driver.id) return false;
    if (trip.status == RideStatus.arrived) return true;
    if (trip.status != RideStatus.accepted) return false;
    if (isOnline && SupabaseService.isConfigured) {
      try {
        var changed = await SupabaseService.instance.transitionDriverRide(
          rideId: trip.id,
          driverId: driver.id,
          fromStatuses: const {RideStatus.accepted},
          toStatus: RideStatus.arrived,
        );
        if (!changed) {
          final remote = await SupabaseService.instance.getTrip(trip.id);
          if (remote != null &&
              remote.driverId == driver.id &&
              const {
                RideStatus.arrived,
                RideStatus.started,
                RideStatus.completed,
              }.contains(remote.status)) {
            changed = true;
          }
        }
        if (!changed) return false;
      } catch (error) {
        if (!isTransientNetworkError(error)) rethrow;
        debugPrint('[SakayTa][DriverTrip] rideId=${trip.id} '
            'arriveAtPickup network fallback to queue: $error');
        await sync.queueTripStatus(
          tripId: trip.id,
          status: RideStatus.arrived,
          latitude: _lastLatitude,
          longitude: _lastLongitude,
        );
        pendingSyncCount = await sync.pendingCount();
      }
    } else {
      await sync.queueTripStatus(
        tripId: trip.id,
        status: RideStatus.arrived,
        latitude: _lastLatitude,
        longitude: _lastLongitude,
      );
      pendingSyncCount = await sync.pendingCount();
    }
    await trips.setStatusLocally(trip.id, RideStatus.arrived);
    final updatedTrip = trip.copyWith(
      status: RideStatus.arrived,
      arrivedAt: DateTime.now(),
    );
    activeTrips = [
      ...activeTrips.where((t) => t.id != trip.id),
      updatedTrip,
    ];
    activeTrip = activeTrips.firstOrNull ?? updatedTrip;
    notifyListeners();
    await refreshTrips();
    return true;
  }

  /// Starts an arrived ride once, after validating role and ownership.
  Future<bool> startActiveTrip({String? tripId}) async {
    if (_startingActiveTrip) return false;
    final trip = (tripId != null
            ? activeTrips
                .cast<Trip?>()
                .firstWhere((t) => t?.id == tripId, orElse: () => null)
            : null) ??
        activeTrip;
    final driver = currentUser;
    if (trip == null ||
        driver == null ||
        !driver.isDriver ||
        trip.driverId != driver.id ||
        trip.status != RideStatus.arrived) {
      return false;
    }
    _startingActiveTrip = true;
    try {
      debugPrint('[SakayTa][DriverTrip] rideId=${trip.id} '
          'authUid=${driver.id} role=${driver.role} route=driverHome '
          'rendered=DriverHome oldStatus=${trip.status} '
          'requestedStatus=${RideStatus.started}');
      if (isOnline && SupabaseService.isConfigured) {
        try {
          var changed = await SupabaseService.instance.transitionDriverRide(
            rideId: trip.id,
            driverId: driver.id,
            fromStatuses: const {RideStatus.arrived},
            toStatus: RideStatus.started,
          );
          if (!changed) {
            final remote = await SupabaseService.instance.getTrip(trip.id);
            if (remote != null &&
                remote.driverId == driver.id &&
                const {
                  RideStatus.started,
                  RideStatus.completed,
                }.contains(remote.status)) {
              changed = true;
            }
          }
          debugPrint('[SakayTa][DriverTrip] rideId=${trip.id} '
              'updated=${changed ? 1 : 0} returnedStatus='
              '${changed ? RideStatus.started : trip.status}');
          if (!changed) return false;
        } catch (error) {
          if (!isTransientNetworkError(error)) rethrow;
          debugPrint('[SakayTa][DriverTrip] rideId=${trip.id} '
              'startActiveTrip network fallback to queue: $error');
          await sync.queueTripStatus(
            tripId: trip.id,
            status: RideStatus.started,
            latitude: _lastLatitude,
            longitude: _lastLongitude,
          );
          pendingSyncCount = await sync.pendingCount();
        }
      } else {
        await sync.queueTripStatus(
          tripId: trip.id,
          status: RideStatus.started,
          latitude: _lastLatitude,
          longitude: _lastLongitude,
        );
        pendingSyncCount = await sync.pendingCount();
      }
      await trips.setStatusLocally(trip.id, RideStatus.started);
      final updatedTrip = trip.copyWith(
        status: RideStatus.started,
        startedAt: DateTime.now(),
      );
      activeTrips = [
        ...activeTrips.where((t) => t.id != trip.id),
        updatedTrip,
      ];
      activeTrip = activeTrips.firstOrNull ?? updatedTrip;
      notifyListeners();
      await refreshTrips();
      return true;
    } catch (error, stackTrace) {
      debugPrint('[SakayTa][DriverTrip] rideId=${trip.id} '
          'startError=${error.runtimeType}: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    } finally {
      _startingActiveTrip = false;
    }
  }

  /// Result of the driver completion boundary.
  ///
  /// `confirmed` means Supabase returned the completed, owned ride. The
  /// offline result is deliberately separate so the UI never claims that
  /// server earnings were recorded before the sync queue reaches Supabase.
  Future<TripCompletionResult> completeTrip(
      {required bool onTime, String? tripId}) async {
    if (_completingActiveTrip) {
      throw StateError('Trip completion is already in progress.');
    }

    final trip = (tripId != null
            ? activeTrips
                .cast<Trip?>()
                .firstWhere((t) => t?.id == tripId, orElse: () => null)
            : null) ??
        activeTrip;
    final driver = currentUser;
    if (trip == null ||
        driver == null ||
        !driver.isDriver ||
        trip.driverId != driver.id ||
        trip.status != RideStatus.started) {
      throw StateError(
        'The active trip is no longer in progress. Refresh and try again.',
      );
    }

    _completingActiveTrip = true;
    try {
      final usingSupabase = isOnline && SupabaseService.isConfigured;
      var confirmedOnServer = false;
      debugPrint('[SakayTa][DriverTrip] rideId=${trip.id} '
          'authUid=${driver.id} role=${driver.role} '
          'route=completeTrip oldStatus=${trip.status} '
          'backend=${usingSupabase ? 'supabase' : 'offline_queue'}');

      if (usingSupabase) {
        try {
          await SupabaseService.instance.completeTrip(
            rideId: trip.id,
            actualFare: trip.fare,
          );
          confirmedOnServer = true;
        } catch (error) {
          if (!isTransientNetworkError(error)) rethrow;
          debugPrint('[SakayTa][DriverTrip] rideId=${trip.id} '
              'completeTrip network fallback to queue: $error');
          await sync.queueTripStatus(
            tripId: trip.id,
            status: RideStatus.completed,
            fare: trip.fare,
          );
          pendingSyncCount = await sync.pendingCount();
        }
      } else {
        await sync.queueTripStatus(
          tripId: trip.id,
          status: RideStatus.completed,
          fare: trip.fare,
        );
        pendingSyncCount = await sync.pendingCount();
      }

      await trips.setStatusLocally(trip.id, RideStatus.completed);
      activeTrips = activeTrips.where((t) => t.id != trip.id).toList();
      activeTrip = activeTrips.firstOrNull;
      notifyListeners();

      if (confirmedOnServer) {
        try {
          await SupabaseService.instance.pushNotification(
            userId: trip.passengerId,
            title: 'Trip Completed',
            body: 'Your trip has been completed. Receipt: '
                '${_paymentReference(trip)}. Thanks for riding with Sakay Ta!',
            senderId: trip.driverId,
            tripId: trip.id,
          );
        } catch (error) {
          debugPrint('[SakayTa][DriverTrip] rideId=${trip.id} '
              'completionNotificationError=${error.runtimeType}');
        }
      }
      await trips.markOnTime(trip.id);

      // In Supabase mode the completion RPC owns the payment and earning
      // rows. Keep a local ledger only for the legacy/local fallback.
      if (trip.paymentMethod.toLowerCase() == PaymentMethod.cash &&
          !SupabaseService.isConfigured) {
        await earnings.recordTripIncome(
          driverId: trip.driverId!,
          tripId: trip.id,
          fare: trip.fare,
          method: trip.paymentMethod,
        );
      }

      // These refreshes are best-effort after the server confirmation. The
      // realtime streams are the source of truth and will also refresh them.
      await refreshTrips();
      await refreshTransactions();
      await refreshUser();
      return confirmedOnServer
          ? TripCompletionResult.confirmed
          : TripCompletionResult.queuedOffline;
    } catch (error, stackTrace) {
      debugPrint('[SakayTa][DriverTrip] rideId=${trip.id} '
          'completionError=${error.runtimeType}: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    } finally {
      _completingActiveTrip = false;
    }
  }

  Future<bool> cancelRide(String tripId) async {
    final cleanId = tripId.trim();
    if (cleanId.isEmpty) return false;
    var success = true;
    if (isOnline && SupabaseService.isConfigured) {
      try {
        success = await SupabaseService.instance.cancelRide(rideId: cleanId);
      } catch (e) {
        debugPrint('AppState cancelRide cloud note: $e');
      }
    }
    await trips.cancelTrip(cleanId);
    if (!isOnline) {
      await sync.queueTripStatus(
        tripId: cleanId,
        status: RideStatus.cancelled,
      );
      pendingSyncCount = await sync.pendingCount();
    }
    if (activeTrip?.id == cleanId) {
      activeTrip = activeTrip!.copyWith(status: RideStatus.cancelled);
    }
    await refreshTrips();
    notifyListeners();
    return success;
  }

  Future<void> cancelActiveTrip() async {
    final trip = activeTrip;
    if (trip == null) return;
    if (isOnline && SupabaseService.isConfigured) {
      final cancelled =
          await SupabaseService.instance.cancelRide(rideId: trip.id);
      if (!cancelled) return;
    }
    await trips.cancelTrip(trip.id);
    if (!isOnline) {
      await sync.queueTripStatus(
        tripId: trip.id,
        status: RideStatus.cancelled,
      );
      pendingSyncCount = await sync.pendingCount();
    }
    await refreshTrips();
  }

  String _paymentReference(Trip trip) {
    final now = DateTime.now();
    final stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    final tripTail = trip.id.length > 4
        ? trip.id.substring(trip.id.length - 4).toUpperCase()
        : trip.id.toUpperCase();
    return 'ST-$stamp-$tripTail';
  }

  /// Initiates an online checkout session via GCash / Maya
  Future<GatewayPaymentResult> initiateTripOnlinePayment({
    required Trip trip,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
  }) async {
    final user = currentUser;
    final passengerId = user?.id ?? trip.passengerId;
    return PaymentService.instance.initiateOnlinePaymentSession(
      tripId: trip.id,
      passengerId: passengerId,
      amount: trip.fare,
      paymentMethodType: trip.paymentMethod,
      driverId: trip.driverId,
      customerName: customerName ?? user?.fullName,
      customerPhone: customerPhone ?? user?.mobile,
      customerEmail: customerEmail ?? user?.email,
      pickupAddress: trip.pickupAddress,
      dropoffAddress: trip.dropoffAddress,
    );
  }

  /// Verifies transaction status and settles the trip online atomically
  Future<GatewayPaymentResult> verifyAndSettleTripOnlinePayment({
    required String sessionId,
    required Trip trip,
  }) async {
    final result = await PaymentService.instance.verifyAndSettlePayment(
      sessionId: sessionId,
      tripId: trip.id,
      passengerId: trip.passengerId,
      driverId: trip.driverId ?? '',
      fare: trip.fare,
      commission: 0,
      net: trip.fare,
      method: trip.paymentMethod,
    );

    if (result.isPaid) {
      if (!SupabaseService.isConfigured) {
        await _markPaid(trip.id);
        if (trip.driverId != null && trip.driverId!.isNotEmpty) {
          await earnings.recordTripIncome(
            driverId: trip.driverId!,
            tripId: trip.id,
            fare: trip.fare,
            method: trip.paymentMethod,
            description: 'Trip earnings (${result.referenceNumber})',
          );
        }
      }
      await refreshTrips();
      await refreshTransactions();
      await refreshUser();
    }
    return result;
  }

  Future<void> payActiveTrip() async {
    final trip = activeTrip;
    if (trip == null || trip.queued) return;
    await trips.setStatus(trip.id, RideStatus.completed);
    if (trip.paymentMethod == PaymentMethod.cash &&
        !SupabaseService.isConfigured) {
      await _markPaid(trip.id);
      if (trip.driverId != null) {
        await earnings.recordTripIncome(
          driverId: trip.driverId!,
          tripId: trip.id,
          fare: trip.fare,
          method: trip.paymentMethod,
        );
      }
      await refreshTransactions();
    }
    await refreshTrips();
    await refreshUser();
  }

  Future<void> _markPaid(String tripId) async {
    final database = await databaseService.database;
    await database.update(
      'trip',
      {'payment_status': PaymentStatus.paid},
      where: 'id = ?',
      whereArgs: [tripId],
    );
  }

  Future<void> rateActiveTrip(int rating, String comment) async {
    final trip = activeTrip;
    final user = currentUser;
    if (trip == null ||
        user == null ||
        user.isDriver ||
        trip.status != RideStatus.completed ||
        trip.rating != null) {
      return;
    }
    await _rateTrip(trip.id, user, rating, comment);
  }

  /// Rates any completed ride (used from the ride history screen, where the
  /// trip is no longer the active one). Writes the `ratings` document and
  /// recalculates the driver's average rating in Firestore.
  Future<void> rateTrip({
    required String tripId,
    required int rating,
    required String comment,
  }) async {
    final user = currentUser;
    if (user == null || user.isDriver) return;
    await _rateTrip(tripId, user, rating, comment);
  }

  Future<void> _rateTrip(
      String tripId, AppUser user, int rating, String comment) async {
    markRatingPrompted(tripId);
    final trip = await trips.getById(tripId);
    if (user.isDriver ||
        trip == null ||
        trip.driverId == null ||
        trip.status != RideStatus.completed ||
        RideStatus.normalize(trip.status) != RideStatus.completed ||
        trip.rating != null) {
      return;
    }
    final revieweeId = trip.driverId!;

    if (isOnline && SupabaseService.isConfigured && !user.isDriver) {
      await SupabaseService.instance.rateDriver(
        rideId: tripId,
        passengerId: user.id,
        driverId: revieweeId,
        rating: rating.toDouble(),
        comment: comment,
      );
    } else if (!user.isDriver) {
      await sync.queueRating(
        tripId: tripId,
        fromUserId: user.id,
        toUserId: revieweeId,
        rating: rating,
        comment: comment,
      );
      pendingSyncCount = await sync.pendingCount();
    }
    // Keep the local history responsive. The server-side rating RPC is the
    // authoritative write and the ride-history query joins the ratings row
    // again after restart.
    await trips.rateTrip(tripId: tripId, rating: rating, comment: comment);
    await refreshTrips();
  }

  Future<void> sendChat(String text) async {
    final trip = activeTrip;
    final user = currentUser;
    if (trip == null || user == null || text.trim().isEmpty) return;
    await trips.sendMessage(
      tripId: trip.id,
      senderId: (user as dynamic).id,
      senderName: user.fullName,
      isDriver: user.isDriver,
      text: text.trim(),
    );
    if (!isOnline) {
      await sync.queueChat(
        tripId: trip.id,
        senderId: (user as dynamic).id,
        senderRole: user.isDriver ? 'driver' : 'passenger',
        text: text.trim(),
      );
      pendingSyncCount = await sync.pendingCount();
    }
    await refreshChat();
  }

  Future<void> refreshChat() async {
    final trip = activeTrip;
    if (trip == null) {
      chatMessages = [];
      return;
    }
    chatMessages = await trips.messagesForTrip(trip.id);
    notifyListeners();
  }

  Future<void> withdraw({
    required double amount,
    required String method,
    String? accountDetails,
  }) async {
    final user = currentUser;
    if (user == null) return;
    if (amount <= 0) {
      throw Exception('Withdrawal amount must be greater than 0.');
    }
    final currentBal = walletBalance;
    if (amount > currentBal) {
      throw Exception('Requested amount exceeds available balance.');
    }

    final id = 'wd_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();

    // 1. Record withdrawal locally in SQLite
    await earnings.withdraw(
      driverId: (user as dynamic).id,
      amount: amount,
      method: method,
    );

    // 2. Record withdrawal in Firestore
    await SupabaseService.instance.saveWithdrawal(Withdrawal(
      id: id,
      driverId: (user as dynamic).id,
      amount: amount,
      method: method,
      status: 'pending',
      note: accountDetails,
      createdAt: now,
    ));

    // 3. Save a transaction record in Firestore
    await SupabaseService.instance.saveTransaction(WalletTransaction(
      id: id,
      driverId: (user as dynamic).id,
      amount: amount,
      type: 'withdrawal',
      description:
          'Withdrawal to ${method.toUpperCase()}${accountDetails != null && accountDetails.isNotEmpty ? " ($accountDetails)" : ""}',
      method: method,
      createdAt: now,
    ));

    // 4. Notify admin
    final adminId = await SupabaseService.instance.getAdminUserId();
    if (adminId != null) {
      await SupabaseService.instance.pushNotification(
        userId: adminId,
        title: 'Withdrawal Request',
        body:
            '${user.fullName} requested a ₱${amount.toStringAsFixed(2)} withdrawal ($method).',
        senderId: (user as dynamic).id,
      );
    }
    await refreshTransactions();
    await refreshUser();
    notifyListeners();
  }

  Future<void> addNotification(
      {required String title, required String body}) async {
    final user = currentUser;
    if (user == null) return;
    final notification = AppNotification(
      id: 'notif_${DateTime.now().millisecondsSinceEpoch}_${(user as dynamic).id}',
      userId: (user as dynamic).id,
      title: title,
      body: body,
      createdAt: DateTime.now(),
    );
    await notifications.addFrom(notification);
    // Cloud notification handled by RPC
    await refreshNotifications();
  }

  Future<void> markNotificationsRead() async {
    final user = currentUser;
    if (user == null) return;
    await notifications.markAllRead((user as dynamic).id);
    await refreshNotifications();
  }

  Future<void> approveDriver(String userId) async {
    await auth.setDriverStatus(userId, AccountStatus.approved);
    if (!SupabaseService.isConfigured) {
      final notification = AppNotification(
        id: 'notif_${DateTime.now().millisecondsSinceEpoch}_$userId',
        userId: userId,
        title: 'Account Approved',
        body: 'Congratulations! You can now go online and start earning.',
        createdAt: DateTime.now(),
      );
      await notifications.addFrom(notification);
    }
    if (currentUser?.isAdmin == true) {
      try {
        await refreshUser();
      } catch (e, s) {
      AppLogger.debug('AppState non-fatal note: $e', error: e, stackTrace: s);
    }
    }
    notifyListeners();
  }

  Future<void> setDriverApplicationReceipt({
    required String applicationId,
    required String statusToken,
    required String email,
    required String status,
  }) async {
    pendingDriverApplicationId = applicationId;
    pendingDriverApplicationStatusToken = statusToken;
    pendingDriverApplicationEmail = email;
    pendingDriverApplicationStatus = status;
    pendingDriverApplicationRejectionReason = null;
    pendingDriverApplicationStatusError = null;
    await prefs.saveDriverApplicationReceipt(
      applicationId: applicationId,
      statusToken: statusToken,
      email: email,
    );
    notifyListeners();
  }

  Future<void> clearDriverApplicationReceipt() async {
    pendingDriverApplicationId = null;
    pendingDriverApplicationStatusToken = null;
    pendingDriverApplicationEmail = null;
    pendingDriverApplicationStatus = 'pending';
    pendingDriverApplicationRejectionReason = null;
    pendingDriverApplicationStatusError = null;
    await prefs.clearDriverApplicationReceipt();
    notifyListeners();
  }

  /// Activates and fully initializes an approved driver's session and state,
  /// matching the exact flow and dependencies of a successful driver login.
  Future<bool> initializeApprovedDriverSession() async {
    // 1. Resolve authenticated user ID from active Supabase session or prefs
    var userId = SupabaseService.isConfigured
        ? Supabase.instance.client.auth.currentUser?.id
        : null;
    userId ??= await prefs.sessionUserId;

    if (userId == null) {
      final restored = await auth.restoreSession();
      userId = restored?.id;
    }
    if (userId == null) {
      return false;
    }

    // 2. Fetch fresh user and driver profile
    AppUser? freshUser;
    DriverProfile? freshDriverProfile;
    try {
      final fetchResults = await Future.wait([
        auth.getUser(userId),
        auth.getDriverProfile(userId),
      ]);
      freshUser = fetchResults[0] as AppUser?;
      freshDriverProfile = fetchResults[1] as DriverProfile?;
    } catch (e) {
      debugPrint('[initializeApprovedDriverSession] fetch error: $e');
    }

    freshUser ??= await auth.restoreSession();
    if (freshUser == null) {
      return false;
    }

    // 3. Ensure role and status are set to approved driver
    var resolvedUser = freshUser;
    if (!resolvedUser.isDriver) {
      resolvedUser = resolvedUser.copyWith(role: UserRole.driver);
    }
    if (resolvedUser.status != AccountStatus.approved &&
        resolvedUser.status != AccountStatus.active) {
      resolvedUser = resolvedUser.copyWith(status: AccountStatus.approved);
    }
    if ((resolvedUser.profilePhotoUrl == null ||
            resolvedUser.profilePhotoUrl!.isEmpty) &&
        freshDriverProfile?.docProfile != null &&
        freshDriverProfile!.docProfile!.isNotEmpty) {
      resolvedUser = resolvedUser.copyWith(
          profilePhotoUrl: freshDriverProfile.docProfile);
    }

    // 4. Update state and persist session
    currentUser = resolvedUser;
    driverProfile = freshDriverProfile;
    await prefs.saveSession(resolvedUser.id, resolvedUser.role);
    await clearDriverApplicationReceipt();

    // 5. Load fare matrix and admins
    unawaited(_loadFareMatrix());
    unawaited(_loadAdminsFromStorage());

    // 6. Complete full user data & feed initialization (trips, notifications, transactions, realtime listeners)
    await _loadUserData(resolvedUser.id);
    notifyListeners();
    return true;
  }

  Future<void> refreshDriverApplicationStatus() async {
    final applicationId = pendingDriverApplicationId;
    final statusToken = pendingDriverApplicationStatusToken;
    if (applicationId == null || statusToken == null) return;
    try {
      final result = await SupabaseService.instance
          .getUnlinkedDriverApplicationStatus(
        applicationId: applicationId,
        statusToken: statusToken,
      );
      pendingDriverApplicationStatus =
          result['status']?.toString() ?? pendingDriverApplicationStatus;
      pendingDriverApplicationRejectionReason =
          result['rejectionReason']?.toString();
      pendingDriverApplicationStatusError = null;
    } catch (error) {
      pendingDriverApplicationStatusError = error.toString();
    }
    notifyListeners();
  }

  Future<Map<String, dynamic>> reviewUnlinkedDriverApplication({
    required String applicationId,
    required String decision,
    String? reason,
  }) async {
    final result = await SupabaseService.instance
        .reviewUnlinkedDriverApplication(
      applicationId: applicationId,
      decision: decision,
      reason: reason,
    );
    notifyListeners();
    return result;
  }

  Future<List<DriverApplication>> rejectedDriverApplications() =>
      SupabaseService.instance.fetchRejectedDriverApplications();

  Future<bool> clearRejectedDriverApplication(String applicationId) async {
    final result = await SupabaseService.instance
        .clearRejectedDriverApplication(applicationId);
    notifyListeners();
    return result;
  }

  Future<int> clearAllRejectedDriverApplications() async {
    final result = await SupabaseService.instance
        .clearAllRejectedDriverApplications();
    notifyListeners();
    return result;
  }

  Future<void> rejectDriver(String userId, String reason) async {
    await auth.setDriverStatus(userId, AccountStatus.rejected, reason: reason);
    if (!SupabaseService.isConfigured) {
      final notification = AppNotification(
        id: 'notif_${DateTime.now().millisecondsSinceEpoch}_$userId',
        userId: userId,
        title: 'Account Rejected',
        body: 'Your application was rejected. Reason: $reason',
        createdAt: DateTime.now(),
      );
      await notifications.addFrom(notification);
    }
    if (currentUser?.isAdmin == true) {
      try {
        await refreshUser();
      } catch (e, s) {
      AppLogger.debug('AppState non-fatal note: $e', error: e, stackTrace: s);
    }
    }
    notifyListeners();
  }
}

/// A ride-history row: the trip plus the driver display info (name + plate)
/// resolved from the drivers collection / local database.
class RideEntry {
  final Trip trip;
  final String driverName;
  final String plateNumber;
  final String? driverPhotoUrl;
  final int driverAvatarColor;

  const RideEntry({
    required this.trip,
    required this.driverName,
    required this.plateNumber,
    this.driverPhotoUrl,
    this.driverAvatarColor = 0,
  });
}

/// A wallet row shown on the driver wallet page (income or withdrawal).
class WalletEntry {
  final String id;
  final String type; // income | withdrawal
  final double amount;
  final String description;
  final String method;
  final DateTime createdAt;
  final String? status;
  final String? rideId;
  final double? grossFare;
  final double? commission;
  final String? reference;

  const WalletEntry({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.method,
    required this.createdAt,
    this.status,
    this.rideId,
    this.grossFare,
    this.commission,
    this.reference,
  });

  factory WalletEntry.fromTransaction(WalletTransaction t) => WalletEntry(
        id: t.id,
        type: t.type,
        amount: t.type == 'income' ? t.amount : -t.amount,
        description: t.description.isNotEmpty
            ? t.description
            : (t.type == 'income' ? 'Ride Income' : 'Withdrawal'),
        method: t.method,
        createdAt: t.createdAt,
        status: 'Completed',
        rideId: t.tripId,
        grossFare: t.type == 'income' ? t.amount : null,
      );

  factory WalletEntry.fromEarning(DriverEarning e) {
    final isCash = e.paymentMethod.toLowerCase().trim() == 'cash';
    final isRefunded = e.settlementStatus.toLowerCase().trim() == 'refunded';
    // Cash earnings are measured by the ride's gross fare. Use the canonical
    // gross amount so legacy commission deductions in net_amount do not
    // understate qualifying cash totals. Digital settlement continues to use
    // its recorded net amount.
    final amount = isCash ? e.fare : e.net;

    return WalletEntry(
      id: e.id,
      type: 'income',
      amount: isRefunded ? -amount : amount,
      description: 'Ride #${e.rideId}',
      method: e.paymentMethod,
      createdAt: e.createdAt,
      status: e.settlementStatus,
      rideId: e.rideId.trim().isNotEmpty ? e.rideId.trim() : null,
      grossFare: e.fare,
      commission: e.commission,
    );
  }

  factory WalletEntry.fromWithdrawal(Withdrawal w) => WalletEntry(
        id: w.id,
        type: 'withdrawal',
        amount: -w.amount,
        description: 'Withdrawal to ${w.method.toUpperCase()}',
        method: w.method,
        createdAt: w.createdAt,
        status: w.status,
        reference: w.reference,
      );
}

/// Platform-wide counts for the admin overview (real data).
class PlatformStats {
  final int totalDrivers;
  final int totalPassengers;
  final int activeToday;
  final double revenueToday;

  const PlatformStats({
    required this.totalDrivers,
    required this.totalPassengers,
    required this.activeToday,
    required this.revenueToday,
  });
}

class AdminRideStats {
  final int total;
  final int active;
  final int completed;
  final int cancelled;

  const AdminRideStats({
    required this.total,
    required this.active,
    required this.completed,
    required this.cancelled,
  });
}

/// Sums [entries] (createdAt, amount) into one bucket per day for the last
/// [days] days, oldest first - zero for days with no activity.
List<double> _dailyRevenueSeries(List<(DateTime, double)> entries, int days) {
  final today = PhilippineTime.startOfDay(PhilippineTime.now());
  final out = <double>[];
  for (var i = days - 1; i >= 0; i--) {
    final localDay = today.subtract(Duration(days: i));
    final day = PhilippineTime.startOfDay(localDay);
    final next = day.add(const Duration(days: 1));
    out.add(entries.where((e) {
      final localDate = PhilippineTime.toPhilippine(e.$1);
      return !localDate.isBefore(day) && localDate.isBefore(next);
    }).fold(0.0, (sum, e) => sum + e.$2));
  }
  return out;
}

class IncomingRideRequest {
  final Trip trip;
  final String passengerName;
  final String? passengerPhoto;
  final double passengerRating;
  final String passengerTag;
  final double distanceKm;
  final int durationMins;
  final DateTime requestTime;

  const IncomingRideRequest({
    required this.trip,
    required this.passengerName,
    this.passengerPhoto,
    this.passengerRating = 4.9,
    this.passengerTag = '4.9 Passenger',
    required this.distanceKm,
    required this.durationMins,
    required this.requestTime,
  });
}

class DailyTripStat {
  final String dayName;
  final DateTime date;
  final int tripCount;
  final double earnings;
  final bool isPeak;

  const DailyTripStat({
    required this.dayName,
    required this.date,
    this.tripCount = 0,
    this.earnings = 0.0,
    this.isPeak = false,
  });
}

class WeeklyPerformanceStats {
  final double totalEarningsThisWeek;
  final int totalTripsThisWeek;
  final List<DailyTripStat> dailyBreakdown;
  final int peakDayIndex;
  final String periodLabel;

  const WeeklyPerformanceStats({
    required this.totalEarningsThisWeek,
    required this.totalTripsThisWeek,
    required this.dailyBreakdown,
    required this.peakDayIndex,
    required this.periodLabel,
  });
}
