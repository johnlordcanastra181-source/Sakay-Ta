import 'package:sakay_ta/models/fare_matrix.dart';
import 'package:sakay_ta/services/fare_calculator.dart';
import 'package:sakay_ta/state/app_state.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

enum VehicleType {
  tricycle,
  habal,
}

extension VehicleTypeX on VehicleType {
  String get key => switch (this) {
        VehicleType.tricycle => 'tricycle',
        VehicleType.habal => 'habal',
      };

  static VehicleType fromKey(String key) {
    final k = key.toLowerCase().trim();
    if (k.contains('motor') || k.contains('habal')) {
      return VehicleType.habal;
    }
    return VehicleType.tricycle;
  }

  IconData get icon => switch (this) {
        VehicleType.tricycle => Icons.electric_rickshaw_rounded,
        VehicleType.habal => Icons.two_wheeler_rounded,
      };

  double get baseFare => RideConfig.baseFareFor(this);

  double get perKm => RideConfig.perKmFor(this);

  String get capacity => switch (this) {
        VehicleType.tricycle => '3-4',
        VehicleType.habal => '1-2',
      };
}

class RideConfig {
  static const minWithdraw = 100.0;
  static const maxWithdraw = 50000.0;

  static FareMatrix _matrix(VehicleType type) =>
      AppState.instance.getFareMatrixFor(type);

  static double baseFareFor(VehicleType type) => _matrix(type).baseFare;
  static double perKmFor(VehicleType type) => _matrix(type).perKmRate;
  static double fareFor(VehicleType type, double km) =>
      FareCalculator.calculateFare(
        matrix: _matrix(type),
        distanceKm: km,
        durationMinutes: 0,
      );
}

class Geo {
  final double lat;
  final double lng;

  const Geo(this.lat, this.lng);

  bool get isValid =>
      (lat != 0.0 || lng != 0.0) && lat.abs() <= 90.0 && lng.abs() <= 180.0;

  static double distanceKm(Geo a, Geo b) {
    const r = 6371.0;
    final dLat = _rad(b.lat - a.lat);
    final dLng = _rad(b.lng - a.lng);
    final sLat = math.sin(dLat / 2);
    final sLng = math.sin(dLng / 2);
    final h = sLat * sLat +
        math.cos(_rad(a.lat)) * math.cos(_rad(b.lat)) * sLng * sLng;
    return 2 * r * math.asin(math.sqrt(h));
  }

  static double _rad(double deg) => deg * math.pi / 180;
}

class RideStatus {
  // Existing Sakay Ta canonical lifecycle. `searching` is the requested state
  // and `started` is the in-progress state retained for schema compatibility.
  static const searching = 'searching';
  static const accepted = 'accepted';
  static const arrived = 'arrived';
  static const started = 'started';
  static const completed = 'completed';
  static const cancelled = 'cancelled';

  static const active = <String>{searching, accepted, arrived, started};
  static const terminal = <String>{completed, cancelled};

  static String normalize(String? value) => switch (value?.toLowerCase()) {
        'pending' || 'requested' => searching,
        'assigned' || 'confirmed' => accepted,
        'on_the_way' || 'driver_arriving' || 'arriving' => accepted,
        'ongoing' || 'in_progress' => started,
        'canceled' => cancelled,
        final String value when value.isNotEmpty => value,
        _ => searching,
      };

  static bool isActive(String value) => active.contains(normalize(value));

  static int step(String status) => switch (status) {
        RideStatus.searching => 0,
        RideStatus.accepted => 1,
        RideStatus.arrived => 2,
        RideStatus.started => 3,
        RideStatus.completed => 4,
        _ => 0,
      };
}

class UserRole {
  static const passenger = 'passenger';
  static const driver = 'driver';
  static const admin = 'admin';
}

class AccountStatus {
  static const pending = 'pending';
  static const approved = 'approved';
  static const rejected = 'rejected';
  static const suspended = 'suspended';
  static const active = 'active';
  static const deactivated = 'deactivated';
}

class NearbyDriverConfig {
  /// An online driver must have published a recent GPS fix before a passenger
  /// can reserve them.
  static const bookableLocationMaxAge = Duration(hours: 24);

  /// Older locations can still be displayed as a last-known location, but are
  /// never bookable.
  static const offlineLocationMaxAge = Duration(days: 7);
}

class AdminPermissions {
  static const all = 'all';
  static const manageDrivers = 'manage_drivers';
  static const managePassengers = 'manage_passengers';
  static const manageFares = 'manage_fares';
  static const manageTodas = 'manage_todas';
  static const manageAdmins = 'manage_admins';
  static const deleteAccounts = 'delete_accounts';
  static const viewReports = 'view_reports';
  static const standardAdmin =
      'manage_drivers,manage_passengers,manage_todas,view_reports';
}

class PaymentMethod {
  static const cash = 'cash';
  static const gcash = 'gcash';
  static const maya = 'maya';
  static const card = 'card';
}

class PaymentStatus {
  static const unpaid = 'unpaid';
  static const paid = 'paid';
  static const failed = 'failed';
}

class Place {
  final String name;
  final Geo geo;
  final String address;
  final String? placeId;

  /// The administrative province this place belongs to, populated during
  /// province validation after destination selection. Empty if unknown.
  final String province;

  const Place(
    this.name,
    this.geo, [
    this.address = '',
    this.placeId,
    this.province = '',
  ]);

  /// Returns a copy with the given province set.
  Place withProvince(String p) => Place(name, geo, address, placeId, p.trim());
}

class EnvironmentConfig {
  /// Replace this with your Mapbox Public Token (starts with 'pk.')
  static const String mapboxAccessToken = 'YOUR_MAPBOX_TOKEN_HERE';
}
