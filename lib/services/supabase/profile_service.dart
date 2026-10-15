import 'dart:async';

import '../../models/firestore_models.dart';
import '../../models/trip.dart';

import 'package:flutter/foundation.dart' show debugPrint, debugPrintStack;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants.dart';
import '../../models/app_user.dart';
import '../../models/philippine_address.dart';
import '../supabase_database_service.dart';

/// Supabase native implementation for user and passenger profiles.
class SupabaseProfileService {
  SupabaseProfileService._();
  static final SupabaseProfileService instance = SupabaseProfileService._();

  SupabaseQueryBuilder get _profilesRef =>
      Supabase.instance.client.from('profiles');

  // =====================================================================
  // USERS
  // =====================================================================

  Future<void> saveUser(AppUser user) async {
    try {
      // The auth trigger `handle_new_auth_user` automatically creates the base profile row
      // upon auth.users insert. We only need to UPDATE the profile with user-provided fields.
      // We MUST only send columns that `authenticated` has GRANT UPDATE permission for,
      // otherwise PostgreSQL throws 42501 (Permission Denied).
      final payload = {
        'full_name': user.fullName,
        if (user.mobile.isNotEmpty) 'mobile': user.mobile,
        if (user.address != null) 'address': user.address,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _profilesRef.update(payload).eq('id', user.id);
    } catch (e) {
      debugPrint(
          'SupabaseProfileService: saveUser skipped for ${user.id} ($e)');
      rethrow;
    }
  }

  Future<void> updateUser(String userId, Map<String, dynamic> fields) async {
    try {
      const aliases = <String, String>{
        'fullName': 'full_name',
        'phoneNumber': 'mobile',
        'profilePhotoUrl': 'profile_photo_path',
        'avatarColor': 'avatar_color',
        'locationUpdatedAt': 'location_updated_at',
      };
      const allowed = <String>{
        'full_name',
        'mobile',
        'address',
        'latitude',
        'longitude',
        'location_updated_at',
        'profile_photo_path',
        'avatar_color',
      };
      final payload = <String, dynamic>{};
      for (final entry in fields.entries) {
        final key = aliases[entry.key] ?? entry.key;
        if (allowed.contains(key)) payload[key] = entry.value;
      }
      if (payload.isNotEmpty) {
        await _profilesRef.update(payload).eq('id', userId);
      }
    } catch (e) {
      debugPrint('SupabaseProfileService: updateUser error for $userId ($e)');
      rethrow;
    }
  }

  Stream<AppUser?> streamUser(String userId) {
    return SupabaseDatabaseService.instance.streamUser(userId);
  }

  Future<AppUser?> getUser(String userId) async {
    try {
      final snap = await _profilesRef
          .select()
          .eq('id', userId)
          .maybeSingle()
          .timeout(const Duration(seconds: 2));
      if (snap == null) return null;
      return AppUser.fromMap({
        ...snap,
        'status': snap['account_status']?.toString() ?? AccountStatus.active,
      });
    } on PostgrestException catch (e, stackTrace) {
      debugPrint(
          '[SakayTa][ERROR][SupabaseProfileService] getUser uid=$userId code=${e.code} message=${e.message}');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    } catch (e, stackTrace) {
      debugPrint(
          '[SakayTa][ERROR][SupabaseProfileService] getUser uid=$userId error=$e');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  Future<AppUser?> getUserByEmail(String email) async {
    try {
      final snap = await _profilesRef
          .select()
          .eq('email', email.toLowerCase().trim())
          .limit(1)
          .maybeSingle();
      if (snap == null) return null;
      return AppUser.fromMap(snap);
    } catch (e) {
      return null;
    }
  }

  Future<AppUser?> getUserByMobile(String mobile) async {
    final clean = mobile.trim();
    final digits = clean.replaceAll(RegExp(r'\D'), '');
    final variations = <String>{clean};
    if (digits.isNotEmpty) {
      variations.add(digits);
      if (digits.length == 10 && digits.startsWith('9')) {
        variations.add('0$digits');
        variations.add('+63$digits');
        variations.add('63$digits');
      } else if (digits.length == 11 && digits.startsWith('09')) {
        final nat = digits.substring(1);
        variations.add(nat);
        variations.add('+63$nat');
        variations.add('63$nat');
      } else if (digits.length == 12 && digits.startsWith('639')) {
        final nat = digits.substring(2);
        variations.add(nat);
        variations.add('0$nat');
        variations.add('+$digits');
      }
    }

    try {
      final snap = await _profilesRef
          .select()
          .inFilter('mobile', variations.take(10).toList())
          .limit(1)
          .timeout(const Duration(seconds: 4));
      if (snap.isNotEmpty) {
        return AppUser.fromMap(snap.first);
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> deleteUser(String userId) async {
    try {
      await _profilesRef.delete().eq('id', userId);
    } catch (e) {
      debugPrint('SupabaseProfileService: deleteUser error ($e)');
    }
  }

  // =====================================================================
  // PASSENGERS
  // =====================================================================

  Future<void> savePassengerProfile(
    String userId, {
    List<String>? savedAddresses,
    String? defaultAddress,
    List<String>? paymentMethods,
    PhilippineAddress? address,
    bool initialize = false,
  }) async {
    try {
      final payload = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (savedAddresses != null) payload['saved_addresses'] = savedAddresses;
      if (paymentMethods != null) payload['payment_methods'] = paymentMethods;
      if (defaultAddress != null) payload['default_address'] = defaultAddress;

      if (address != null) {
        // Address doesn't map to separate columns in passenger_profiles schema.
        // passenger_profiles only has default_address text.
        payload['default_address'] = address.formattedAddress;
      }

      if (payload.length > 1) {
        // More than just updated_at
        await Supabase.instance.client
            .from('passenger_profiles')
            .update(payload)
            .eq('user_id', userId);
      }
    } catch (e) {
      debugPrint('SupabaseProfileService: savePassengerProfile error: $e');
      rethrow;
    }
  }

  Future<void> incrementPassengerRideCount(String userId) async {
    try {
      final snap = await Supabase.instance.client
          .from('passenger_profiles')
          .select('ride_count')
          .eq('user_id', userId)
          .maybeSingle();

      int currentCount = 0;
      if (snap != null && snap['ride_count'] != null) {
        currentCount = (snap['ride_count'] as num).toInt();
      }

      await Supabase.instance.client.from('passenger_profiles').update({
        'ride_count': currentCount + 1,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('user_id', userId);
    } catch (e) {
      debugPrint(
          'SupabaseProfileService: incrementPassengerRideCount error: $e');
      rethrow;
    }
  }

  /// Kept as a compatibility façade for older callers. The canonical service
  /// reads passenger_profiles.user_id and then profiles.id; `profiles.role`
  /// does not exist in the Supabase schema.
  Stream<List<AppUser>> streamPassengers() =>
      SupabaseDatabaseService.instance.streamPassengers();

  Future<void> createPassengerCloudProfile(String uid) async {
    try {
      await Supabase.instance.client
          .from('passenger_profiles')
          .upsert({'user_id': uid});
    } catch (e) {
      debugPrint(
          'SupabaseProfileService: createPassengerCloudProfile skipped ($e)');
    }
  }

  Future<void> setPassengerAccountStatus(
    String userId,
    String status, {
    String? reason,
  }) async {
    try {
      await Supabase.instance.client.rpc('set_account_status', params: {
        'target_user': userId,
        'new_status': status,
        'reason': reason?.trim().isEmpty ?? true ? null : reason!.trim(),
      });
    } catch (e) {
      debugPrint('SupabaseProfileService: setPassengerAccountStatus error: $e');
    }
  }

  Stream<PassengerCloudProfile?> streamPassengerProfile(String userId) {
    return SupabaseDatabaseService.instance.streamPassengerProfile(userId);
  }

  Stream<Trip?> streamActiveTripForPassenger(String passengerId) {
    return Stream.value(null);
  }
}
