import 'package:shared_preferences/shared_preferences.dart';

class PrefsService {
  static final PrefsService instance = PrefsService._();
  PrefsService._();

  // The singleton SharedPreferences instance. Initialized once at startup via
  // [PrefsService.initialize()] before runApp() is called, so the Pigeon-based
  // Android platform channel is already registered when the first read fires.
  SharedPreferences? _prefs;
  static Future<SharedPreferences>? _initFuture;

  /// Initializes SharedPreferences. Can be awaited or called in background;
  /// all async getters/setters also auto-initialize if needed.
  static Future<void> initialize() async {
    final p = await SharedPreferences.getInstance();
    instance._prefs = p;
    _initFuture = Future.value(p);
  }

  Future<SharedPreferences> _ensurePrefs() async {
    final existing = _prefs;
    if (existing != null) return existing;
    _initFuture ??= SharedPreferences.getInstance();
    final resolved = await _initFuture!;
    _prefs = resolved;
    return resolved;
  }

  static const kLocale = 'locale';
  static const kDarkMode = 'dark_mode';
  static const kSessionUserId = 'session_user_id';
  static const kSessionRole = 'session_role';
  static const kMapCacheVersion = 'map_cache_version';
  static const kNotificationsEnabled = 'notifications_enabled';
  static const kSoundAlertsEnabled = 'sound_alerts_enabled';
  static const kAutoAcceptRides = 'auto_accept_rides';
  static const kPickupRadiusKm = 'pickup_radius_km';
  static const kDriverApplicationId = 'driver_application_id';
  static const kDriverApplicationStatusToken = 'driver_application_status_token';
  static const kDriverApplicationEmail = 'driver_application_email';

  Future<String> get locale async => (await _ensurePrefs()).getString(kLocale) ?? 'en';

  Future<void> setLocale(String value) async =>
      await (await _ensurePrefs()).setString(kLocale, value);

  Future<bool> get darkMode async =>
      (await _ensurePrefs()).getBool(kDarkMode) ?? false;

  Future<void> setDarkMode(bool value) async =>
      await (await _ensurePrefs()).setBool(kDarkMode, value);

  Future<bool> get notificationsEnabled async =>
      (await _ensurePrefs()).getBool(kNotificationsEnabled) ?? true;

  Future<void> setNotificationsEnabled(bool value) async =>
      await (await _ensurePrefs()).setBool(kNotificationsEnabled, value);

  Future<bool> get soundAlertsEnabled async =>
      (await _ensurePrefs()).getBool(kSoundAlertsEnabled) ?? true;

  Future<void> setSoundAlertsEnabled(bool value) async =>
      await (await _ensurePrefs()).setBool(kSoundAlertsEnabled, value);

  Future<bool> get autoAcceptRides async =>
      (await _ensurePrefs()).getBool(kAutoAcceptRides) ?? false;

  Future<void> setAutoAcceptRides(bool value) async =>
      await (await _ensurePrefs()).setBool(kAutoAcceptRides, value);

  Future<double> get pickupRadiusKm async =>
      (await _ensurePrefs()).getDouble(kPickupRadiusKm) ?? 5.0;

  Future<void> setPickupRadiusKm(double value) async =>
      await (await _ensurePrefs()).setDouble(kPickupRadiusKm, value);

  Future<String?> get sessionUserId async =>
      (await _ensurePrefs()).getString(kSessionUserId);

  Future<String?> get sessionRole async =>
      (await _ensurePrefs()).getString(kSessionRole);

  Future<void> saveSession(String userId, String role) async {
    final p = await _ensurePrefs();
    await p.setString(kSessionUserId, userId);
    await p.setString(kSessionRole, role);
  }

  Future<void> clearSession() async {
    final p = await _ensurePrefs();
    await p.remove(kSessionUserId);
    await p.remove(kSessionRole);
  }

  Future<void> saveDriverApplicationReceipt({
    required String applicationId,
    required String statusToken,
    required String email,
  }) async {
    final p = await _ensurePrefs();
    await p.setString(kDriverApplicationId, applicationId);
    await p.setString(kDriverApplicationStatusToken, statusToken);
    await p.setString(kDriverApplicationEmail, email);
  }

  Future<({String applicationId, String statusToken, String email})?>
      get driverApplicationReceipt async {
    final p = await _ensurePrefs();
    final applicationId = p.getString(kDriverApplicationId);
    final statusToken = p.getString(kDriverApplicationStatusToken);
    final email = p.getString(kDriverApplicationEmail);
    if (applicationId == null || statusToken == null || email == null) {
      return null;
    }
    return (
      applicationId: applicationId,
      statusToken: statusToken,
      email: email,
    );
  }

  Future<void> clearDriverApplicationReceipt() async {
    final p = await _ensurePrefs();
    await p.remove(kDriverApplicationId);
    await p.remove(kDriverApplicationStatusToken);
    await p.remove(kDriverApplicationEmail);
  }
}
