import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Clock and calendar helpers for the application's Philippine timezone
/// powered by the canonical IANA `Asia/Manila` timezone database.
///
/// Supabase stores timestamps as UTC. The product's reporting day is always
/// Asia/Manila, independent of the device/browser timezone.
class PhilippineTime {
  PhilippineTime._();

  static bool _isInitialized = false;
  static late final tz.Location _manilaLocation;

  /// Ensures the IANA timezone database is initialized and `Asia/Manila` is loaded.
  static void initialize() {
    if (_isInitialized) return;
    tz_data.initializeTimeZones();
    _manilaLocation = tz.getLocation('Asia/Manila');
    _isInitialized = true;
  }

  /// Returns the canonical IANA `Asia/Manila` location.
  static tz.Location get location {
    if (!_isInitialized) initialize();
    return _manilaLocation;
  }

  /// Standard Philippine offset (UTC+8) for legacy compatibility.
  static Duration get offset =>
      Duration(milliseconds: location.currentTimeZone.offset);

  /// Returns the current instant. Project it with [toPhilippine] when reading
  /// Philippine calendar fields; this avoids applying the offset twice in callers.
  static DateTime now() => DateTime.now();

  /// Projects any [DateTime] into the `Asia/Manila` timezone (`tz.TZDateTime`).
  static DateTime toPhilippine(DateTime value) {
    return tz.TZDateTime.from(value.toUtc(), location);
  }

  /// Returns the half-open UTC interval that represents the Philippine local
  /// calendar day containing [value]. Database filters should use these UTC
  /// instants against timestamptz columns such as rides.completed_at.
  static ({DateTime startUtc, DateTime endUtc}) utcBoundsForPhilippineDay({
    DateTime? value,
  }) {
    final local = tz.TZDateTime.from((value ?? now()).toUtc(), location);
    final startManila =
        tz.TZDateTime(location, local.year, local.month, local.day);
    final endManila =
        tz.TZDateTime(location, local.year, local.month, local.day + 1);
    return (
      startUtc: startManila.toUtc(),
      endUtc: endManila.toUtc(),
    );
  }

  static bool isSameDay(DateTime value, DateTime day) {
    final localValue = toPhilippine(value);
    final localDay = toPhilippine(day);
    return localValue.year == localDay.year &&
        localValue.month == localDay.month &&
        localValue.day == localDay.day;
  }

  static DateTime startOfDay(DateTime value) {
    final local = toPhilippine(value);
    return tz.TZDateTime(location, local.year, local.month, local.day);
  }

  static DateTime startOfCurrentWeek() {
    final today = startOfDay(now());
    return today.subtract(Duration(days: today.weekday - DateTime.monday));
  }
}
