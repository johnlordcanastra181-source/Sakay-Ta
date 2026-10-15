import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_config.dart';

class SupabaseStorageService {
  SupabaseStorageService._();

  static const _driverDocumentsBucket = 'driver-documents';
  static const _avatarsBucket = 'avatars';

  static bool get isConfigured => SupabaseConfig.isInitialized;

  static Future<String> uploadDriverDocument({
    required String userId,
    required String kind,
    Uint8List? bytes,
    File? file,
  }) async {
    if (userId.trim().isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'must not be empty');
    }
    const folders = <String, String>{
      'license': 'license',
      'license_front': 'license',
      'orcr': 'orcr',
      'profile': 'profile',
    };
    final folder = folders[kind];
    if (folder == null) {
      throw ArgumentError.value(kind, 'kind', 'unsupported document type');
    }
    if (bytes != null && bytes.isEmpty) {
      throw ArgumentError.value(bytes, 'bytes', 'must not be empty');
    }
    if (file != null && !await file.exists()) {
      throw ArgumentError.value(file.path, 'file', 'does not exist');
    }
    if (bytes == null && file == null) {
      throw ArgumentError('Either bytes or file must be provided.');
    }
    final authenticatedUserId = Supabase.instance.client.auth.currentUser?.id;
    if (authenticatedUserId != userId) {
      throw const AuthException(
          'A signed-in account may upload only its own driver documents.');
    }

    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final path = '$userId/$folder/${kind}_$timestamp.jpg';
    final storage =
        Supabase.instance.client.storage.from(_driverDocumentsBucket);

    try {
      debugPrint('SupabaseStorage: starting $kind upload for uid=$userId');
      if (bytes != null) {
        await storage.uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
      } else {
        await storage.upload(
          path,
          file!,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
      }
      debugPrint('SupabaseStorage: completed $kind upload for uid=$userId');

      // Store the private object path, never a long-lived signed URL. Readers
      // obtain a short-lived URL only after database RLS authorizes them.
      return path;
    } catch (e) {
      debugPrint('SupabaseStorage: $kind upload failed (${e.runtimeType})');
      rethrow;
    }
  }

  static Future<void> deleteByDownloadUrl(String downloadUrl) async {
    // New uploads supply a canonical object path. The URL parsing branch keeps
    // rollback compatibility with documents uploaded by older app builds.
    try {
      var path = downloadUrl.trim();
      if (path.contains('://')) {
        final segments = Uri.parse(path).pathSegments;
        final bucketIndex = segments.indexOf(_driverDocumentsBucket);
        if (bucketIndex == -1 || bucketIndex + 1 >= segments.length) return;
        path = segments.sublist(bucketIndex + 1).join('/');
      }
      if (path.isEmpty) return;
      await Supabase.instance.client.storage
          .from(_driverDocumentsBucket)
          .remove([path]);
    } catch (e) {
      debugPrint('SupabaseStorage: rollback delete failed (${e.runtimeType})');
    }
  }

  static Future<void> deleteDriverDocument({
    required String userId,
    required String kind,
  }) async {
    // Best effort delete if we knew the exact path. Since we used timestamp,
    // we would need to list and delete. Skipping complex logic for now as it's best-effort.
  }

  static Future<String?> uploadProfilePhoto({
    required String userId,
    Uint8List? bytes,
    File? file,
  }) async {
    if (userId.trim().isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'must not be empty');
    }
    if (bytes != null && bytes.isEmpty) {
      throw ArgumentError.value(bytes, 'bytes', 'must not be empty');
    }
    if (file != null && !await file.exists()) {
      throw ArgumentError.value(file.path, 'file', 'does not exist');
    }
    if (bytes == null && file == null) return null;
    final authenticatedUserId = Supabase.instance.client.auth.currentUser?.id;
    if (authenticatedUserId != userId) {
      throw const AuthException(
          'A signed-in account may upload only its own profile photo.');
    }

    try {
      // The existing avatars RLS policy scopes the first path segment to the
      // authenticated user. A stable path replaces the prior photo instead of
      // accumulating timestamped uploads for every profile edit.
      final path = '$userId/profile.jpg';
      final storage = Supabase.instance.client.storage.from(_avatarsBucket);

      debugPrint(
          '[PROFILE PHOTO] upload starting for uid=$userId target=$path');

      if (bytes != null) {
        await storage.uploadBinary(
          path,
          bytes,
          fileOptions:
              const FileOptions(contentType: 'image/jpeg', upsert: true),
        );
      } else if (file != null) {
        await storage.upload(
          path,
          file,
          fileOptions:
              const FileOptions(contentType: 'image/jpeg', upsert: true),
        );
      } else {
        return null;
      }

      // Store the canonical path. SupabaseDatabaseService resolves it to the
      // public avatars URL when reading the passenger profile.
      debugPrint('[PROFILE PHOTO] upload completed');
      return path;
    } catch (e, stackTrace) {
      debugPrint('[PROFILE PHOTO][ERROR] ${e.runtimeType}: $e');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }
}
