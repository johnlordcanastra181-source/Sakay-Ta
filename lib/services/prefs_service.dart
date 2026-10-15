import 'package:shared_preferences/shared_preferences.dart';

class PrefsService {
  static final PrefsService instance = PrefsService._();
  PrefsService._();

  // The singleton SharedPreferences instance. Initialized once at startup via
  // [PrefsService.initialize()] before runApp() is called, so the Pigeon-based
  // Android platform channel is already registered when the first read fires.
  SharedPreferences? _prefs;

  /// Must be called in main() after WidgetsFlutterBinding.ensureInitialized()
  /// and before runApp(). This guarantees the platform channel is ready.
  static Future<void> initialize() async {
    instance._prefs = await SharedPreferences.getInstance();
  }

  SharedPreferences get _p {
    // Fallback safety: if prefs are not yet initialized (e.g. in tests),
    // throw a clear error instead of a confusing PlatformException.
    if (_prefs == null) {
      throw StateError(
        'PrefsService.initialize() must be called before using PrefsService.',
      );
    }
    return _prefs!;
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

  Future<String> get locale async => _p.getString(kLocale) ?? 'en';

  Future<void> setLocale(String value) async =>
      await _p.setString(kLocale, value);

  Future<bool> get darkMode async => _p.getBool(kDarkMode) ?? false;

  Future<void> setDarkMode(bool value) async =>
      await _p.setBool(kDarkMode, value);

  Future<bool> get notificationsEnabled async =>
      _p.getBool(kNotificationsEnabled) ?? true;

  Future<void> setNotificationsEnabled(bool value) async =>
      await _p.setBool(kNotificationsEnabled, value);

  Future<bool> get soundAlertsEnabled async =>
      _p.getBool(kSoundAlertsEnabled) ?? true;

  Future<void> setSoundAlertsEnabled(bool value) async =>
      await _p.setBool(kSoundAlertsEnabled, value);

  Future<bool> get autoAcceptRides async =>
      _p.getBool(kAutoAcceptRides) ?? false;

  Future<void> setAutoAcceptRides(bool value) async =>
      await _p.setBool(kAutoAcceptRides, value);

  Future<double> get pickupRadiusKm async =>
      _p.getDouble(kPickupRadiusKm) ?? 5.0;

  Future<void> setPickupRadiusKm(double value) async =>
      await _p.setDouble(kPickupRadiusKm, value);

  Future<String?> get sessionUserId async => _p.getString(kSessionUserId);

  Future<String?> get sessionRole async => _p.getString(kSessionRole);

  Future<void> saveSession(String userId, String role) async {
    await _p.setString(kSessionUserId, userId);
    await _p.setString(kSessionRole, role);
  }

  Future<void> clearSession() async {
    await _p.remove(kSessionUserId);
    await _p.remove(kSessionRole);
  }

  Future<void> saveDriverApplicationReceipt({
    required String applicationId,
    required String statusToken,
    required String email,
  }) async {
    await _p.setString(kDriverApplicationId, applicationId);
    await _p.setString(kDriverApplicationStatusToken, statusToken);
    await _p.setString(kDriverApplicationEmail, email);
  }

  Future<({String applicationId, String statusToken, String email})?>
      get driverApplicationReceipt async {
    final applicationId = _p.getString(kDriverApplicationId);
    final statusToken = _p.getString(kDriverApplicationStatusToken);
    final email = _p.getString(kDriverApplicationEmail);
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
    await _p.remove(kDriverApplicationId);
    await _p.remove(kDriverApplicationStatusToken);
    await _p.remove(kDriverApplicationEmail);
  }
}
