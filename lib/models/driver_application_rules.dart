import '../core/constants.dart';

/// Shared rules for vehicle-dependent driver application fields.
class DriverApplicationRules {
  DriverApplicationRules._();

  static bool requiresToda(VehicleType vehicleType) =>
      vehicleType == VehicleType.tricycle;

  /// Trims and validates a descriptive vehicle color without restricting it
  /// to a fixed list of color names.
  static String? normalizeVehicleColor(String? value) {
    final color = value?.trim() ?? '';
    if (color.isEmpty || color.runes.length > 60) return null;
    return color;
  }

  static String? todaIdForVehicle(VehicleType vehicleType, String? selectedId) {
    if (!requiresToda(vehicleType)) return null;
    final id = selectedId?.trim() ?? '';
    return id.isEmpty ? null : id;
  }
}
