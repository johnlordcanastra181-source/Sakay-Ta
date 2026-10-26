import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Predefined avatar accent colors for user profile personalization.
const List<Color> kAvatarColors = [
  Color(0xFF059669), // Emerald
  Color(0xFFD97706), // Amber
  Color(0xFF3B82F6), // Blue
  Color(0xFF8B5CF6), // Purple
  Color(0xFFEC4899), // Pink
  Color(0xFF1E2B45), // Navy
];

/// Returns an [ImageProvider] for a profile photo URL.
/// Supports data URIs (`data:image/...;base64,...`), HTTP/HTTPS URLs, and local files.
/// Downscales decoded bitmaps via [ResizeImage.resizeIfNeeded] so high-MP camera
/// photos do not consume 40MB+ of uncompressed RAM on low-end devices.
ImageProvider<Object>? getUserAvatarImageProvider(
  String? photoUrl, {
  int targetDecodeSize = 128,
}) {
  if (photoUrl == null || photoUrl.trim().isEmpty) return null;
  final clean = photoUrl.trim();
  ImageProvider<Object>? baseProvider;

  // 1. Base64 Data URI
  if (clean.startsWith('data:image/')) {
    try {
      final commaIdx = clean.indexOf(',');
      if (commaIdx != -1) {
        final b64 = clean.substring(commaIdx + 1);
        final bytes = base64Decode(b64);
        baseProvider = MemoryImage(bytes);
      }
    } catch (e) {
      debugPrint('UserAvatar non-fatal note: $e');
    }
  } else if (clean.startsWith('http://') || clean.startsWith('https://')) {
    // 2. Network URL
    baseProvider = NetworkImage(clean);
  } else if (!kIsWeb) {
    // 3. Local File Path (non-web)
    try {
      final file = File(clean.replaceFirst('file://', ''));
      if (file.existsSync()) {
        baseProvider = FileImage(file);
      }
    } catch (e) {
      debugPrint('UserAvatar non-fatal note: $e');
    }
  }

  if (baseProvider == null) return null;
  final clampedSize = targetDecodeSize.clamp(64, 256);
  return ResizeImage.resizeIfNeeded(clampedSize, clampedSize, baseProvider);
}

/// A versatile, unified avatar component for passengers, drivers, and admins.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    this.photoUrl,
    required this.name,
    this.radius = 24,
    this.avatarColorIndex = 0,
    this.showCameraBadge = false,
    this.onTap,
    this.border,
    this.boxShadow,
    this.elevation = 0,
  });

  final String? photoUrl;
  final String name;
  final double radius;
  final int avatarColorIndex;
  final bool showCameraBadge;
  final VoidCallback? onTap;
  final BoxBorder? border;
  final List<BoxShadow>? boxShadow;
  final double elevation;

  Color get _accentColor {
    final idx = avatarColorIndex.clamp(0, kAvatarColors.length - 1);
    return kAvatarColors[idx];
  }

  String get _initials {
    final clean = name.trim();
    if (clean.isEmpty) return 'U';
    final parts =
        clean.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return clean[0].toUpperCase();
  }

  Widget _buildImageOrFallback() {
    final provider = getUserAvatarImageProvider(
      photoUrl,
      targetDecodeSize: (radius * 3).toInt(),
    );

    if (provider != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: _accentColor.withValues(alpha: 0.18),
        foregroundImage: provider,
        onForegroundImageError: (_, __) {},
        child: _buildInitials(),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: _accentColor.withValues(alpha: 0.18),
      child: _buildInitials(),
    );
  }

  Widget _buildInitials() {
    return Text(
      _initials,
      style: TextStyle(
        fontSize: radius * 0.85,
        fontWeight: FontWeight.w900,
        color: _accentColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget avatar = Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: border,
        boxShadow: boxShadow ??
            (elevation > 0
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: elevation * 2,
                      offset: Offset(0, elevation),
                    ),
                  ]
                : null),
      ),
      child: _buildImageOrFallback(),
    );

    if (showCameraBadge) {
      final badgeSize = (radius * 0.55).clamp(20.0, 32.0);
      final iconSize = (badgeSize * 0.55).clamp(12.0, 18.0);

      avatar = Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: badgeSize,
              height: badgeSize,
              decoration: BoxDecoration(
                color: AppColors.terracotta,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  Icons.camera_alt_rounded,
                  size: iconSize,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (onTap != null) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: avatar,
        ),
      );
    }

    return avatar;
  }
}
