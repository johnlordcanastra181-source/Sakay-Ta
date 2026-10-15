import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/app_user.dart';

class SupabaseAuthHelpers {
  SupabaseAuthHelpers._();
  static final SupabaseAuthHelpers instance = SupabaseAuthHelpers._();
  SupabaseClient get _db => Supabase.instance.client;

  Future<void> saveMagicLink(Map<String, dynamic> link) async {
    // Supabase has built-in magic links, this might be custom logic for driver approval.
    // If table doesn't exist, this will fail at runtime but compile fine.
    await _db.from('magic_links').insert(link);
  }

  Future<dynamic> verifyMagicLinkToken(String token) async {
    final res = await _db
        .from('magic_links')
        .select()
        .eq('token', token)
        .eq('used', false)
        .maybeSingle();
    if (res != null) {
      final expiresAt = DateTime.parse(res['expiresAt']);
      if (expiresAt.isAfter(DateTime.now())) {
        await _db
            .from('magic_links')
            .update({'used': true}).eq('id', res['id']);
        return (isValid: true, mobile: res['mobile'], status: res['status']);
      }
    }
    return (isValid: false, mobile: null, status: null);
  }

  Future<AppUser?> getUserByEmail(String email) async {
    final res =
        await _db.from('profiles').select().eq('email', email).maybeSingle();
    return res == null ? null : AppUser.fromMap(res);
  }

  Future<bool> isEmailInUse(String email) async {
    final user = await getUserByEmail(email);
    return user != null;
  }
}
