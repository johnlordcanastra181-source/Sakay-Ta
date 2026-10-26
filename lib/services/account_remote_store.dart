import '../models/admin_account.dart';
import '../models/app_user.dart';
import '../models/driver_profile.dart';
import '../models/philippine_address.dart';
import 'supabase_auth_service.dart';
import 'supabase_service.dart';

abstract class AccountRemoteStore {
  bool get isConfigured;
  Future<String> signIn(String identifier, String password,
      {List<String>? alternateIdentifiers});
  Future<String> createAccount(String mobile, String password, String? email);
  Future<AppUser?> getUser(String uid);
  Future<AdminAccount?> getAdmin(String uid);
  Future<void> saveUser(AppUser user);
  Future<void> saveDriverProfile(DriverProfile profile);
  Future<DriverProfile?> getDriverProfile(String uid);
  Future<void> savePassengerProfile(String uid, PhilippineAddress? address,
      {bool initialize = true});
}

class SupabaseAccountRemoteStore implements AccountRemoteStore {
  const SupabaseAccountRemoteStore();

  @override
  bool get isConfigured => SupabaseAuthService.isConfigured;

  @override
  Future<String> signIn(String identifier, String password,
      {List<String>? alternateIdentifiers}) async {
    final uid = await SupabaseAuthService.signIn(
      mobile: identifier,
      password: password,
      alternateIdentifiers: alternateIdentifiers,
    );
    if (uid == null)
      throw StateError(
          'Failed to sign in. User not found or invalid password.');
    return uid;
  }

  @override
  Future<String> createAccount(String mobile, String password, String? email) {
    return SupabaseAuthService.createDurableAccount(
        mobile: mobile, password: password, email: email);
  }

  @override
  Future<AppUser?> getUser(String uid) {
    return SupabaseService.instance.getUser(uid);
  }

  @override
  Future<AdminAccount?> getAdmin(String uid) {
    return SupabaseService.instance.getAdminAccount(uid);
  }

  @override
  Future<void> saveUser(AppUser user) {
    return SupabaseService.instance.saveUser(user);
  }

  @override
  Future<void> saveDriverProfile(DriverProfile profile) {
    return SupabaseService.instance.saveDriverProfile(profile);
  }

  @override
  Future<DriverProfile?> getDriverProfile(String uid) {
    return SupabaseService.instance.getDriverProfile(uid);
  }

  @override
  Future<void> savePassengerProfile(String uid, PhilippineAddress? address,
      {bool initialize = true}) {
    return SupabaseService.instance
        .savePassengerProfile(uid, address: address, initialize: initialize);
  }
}
