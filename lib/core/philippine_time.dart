/// Clock and calendar helpers for the application's fixed Philippine timezone.
///
/// Supabase stores timestamps as UTC.  The product's reporting day is always
/// Asia/Manila (UTC+8), independent of the device/browser timezone.
class PhilippineTime {
  PhilippineTime._();

  static const Duration offset = Duration(hours: 8);

  /// Returns the current instant. Project it with [toPhilippine] when reading
  /// Philippine calendar fields; this avoids applying UTC+8 twice in callers.
  static DateTime now() => DateTime.now();

  static DateTime toPhilippine(DateTime value) => value.toUtc().add(offset);

  /// Returns the half-open UTC interval that represents the Philippine local
  /// calendar day containing [value]. Database filters should use these UTC
  /// instants against timestamptz columns such as rides.completed_at.
  static ({DateTime startUtc, DateTime endUtc}) utcBoundsForPhilippineDay({
    DateTime? value,
  }) {
    final local = toPhilippine(value ?? now());
    final midnightAsUtc = DateTime.utc(local.year, local.month, local.day);
    return (
      startUtc: midnightAsUtc.subtract(offset),
      endUtc: midnightAsUtc.add(const Duration(days: 1)).subtract(offset),
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
    return DateTime(local.year, local.month, local.day);
  }

  static DateTime startOfCurrentWeek() {
    final today = startOfDay(now());
    return today.subtract(Duration(days: today.weekday - DateTime.monday));
  }
}
