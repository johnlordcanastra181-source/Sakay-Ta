import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb, Uint8List;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/neumorphic_theme.dart';
import '../core/theme.dart';
import '../models/app_user.dart';
import '../services/supabase_storage_service.dart';
import '../services/supabase_service.dart';
import '../state/app_state.dart';
import 'neumorphic_widgets.dart';
import 'user_avatar.dart';

class EditProfileModal extends StatefulWidget {
  const EditProfileModal({super.key, required this.user});
  final AppUser user;

  static Future<void> show(BuildContext context, {required AppUser user}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EditProfileModal(user: user),
    );
  }

  @override
  State<EditProfileModal> createState() => _EditProfileModalState();
}

class _EditProfileModalState extends State<EditProfileModal> {
  late final TextEditingController _nameCtrl =
      TextEditingController(text: widget.user.fullName);
  late final TextEditingController _mobileCtrl =
      TextEditingController(text: widget.user.mobile);
  late final TextEditingController _emailCtrl =
      TextEditingController(text: widget.user.email ?? '');

  final ImagePicker _picker = ImagePicker();

  var _isSaving = false;
  late int _selectedAvatarIndex =
      widget.user.avatarColor.clamp(0, _avatarColors.length - 1);

  /// Newly picked profile picture bytes (used on mobile + web upload).
  Uint8List? _photoBytes;

  /// Local path of the picked image (used for preview on native platforms).
  String? _photoPath;

  /// Whether the user explicitly removed the stored profile picture.
  bool _removePhoto = false;

  static const List<Color> _avatarColors = [
    Color(0xFF059669),
    Color(0xFFD97706),
    Color(0xFF3B82F6),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
  ];

  /// Preview provider for the profile picture: a newly picked image wins over
  /// the previously stored photo URL / initial fallback.
  ImageProvider<Object>? _photoPreview() {
    if (_removePhoto) return null;
    if (_photoBytes != null) return MemoryImage(_photoBytes!);
    return getUserAvatarImageProvider(widget.user.profilePhotoUrl);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  /// Picks a new profile picture from the gallery or camera and previews it.
  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 80,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _photoBytes = bytes;
        _photoPath = kIsWeb ? null : picked.path;
        _removePhoto = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not pick image: ${e.toString()}')),
        );
      }
    }
  }

  /// Shows the Gallery / Camera chooser for the profile picture.
  Future<void> _choosePhotoSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_rounded,
                    color: Color(0xFF059669)),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded,
                    color: Color(0xFFD97706)),
                title: const Text('Take a Photo'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (source != null) await _pickPhoto(source);
  }

  Future<void> _saveProfile() async {
    final name = _nameCtrl.text.trim();
    final mobile = _mobileCtrl.text.trim();
    final email = _emailCtrl.text.trim().toLowerCase();
    final registeredEmail = widget.user.email?.trim().toLowerCase() ?? '';

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Full name cannot be empty.')),
      );
      return;
    }

    // `profiles.email` is an admin-searchable mirror of the Supabase Auth
    // email. Updating only this client-side field would make Admin display an
    // address that cannot sign in, so email changes need the verified Auth
    // email-change flow rather than the ordinary profile editor.
    if (SupabaseService.isConfigured && email != registeredEmail) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Email changes require the verified account-email flow and cannot be saved here.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final app = context.read<AppState>();

    try {
      String? photoUrl = _removePhoto ? '' : widget.user.profilePhotoUrl;
      if (!_removePhoto && _photoBytes != null) {
        String? uploaded;
        try {
          uploaded = await SupabaseStorageService.uploadProfilePhoto(
            userId: widget.user.id,
            bytes: _photoBytes,
            file: _photoPath != null ? File(_photoPath!) : null,
          );
        } catch (e) {
          throw StateError('Supabase Storage profile-photo upload failed: $e');
        }

        if (uploaded != null && uploaded.isNotEmpty) {
          photoUrl = uploaded;
        } else {
          throw StateError('Failed to retrieve photo download URL.');
        }
      }

      final updated = widget.user.copyWith(
        fullName: name,
        mobile: mobile,
        email: widget.user.email,
        avatarColor: _selectedAvatarIndex,
        profilePhotoUrl: photoUrl,
      );

      await app.auth.updateUser(updated);
      if (SupabaseService.isConfigured) {
        final fields = <String, Object?>{
          'full_name': name,
          'fullName': name,
          'mobile': mobile,
          'avatar_color': _selectedAvatarIndex,
          'avatarColor': _selectedAvatarIndex,
          'profile_photo_url': photoUrl,
          'profilePhotoUrl': photoUrl,
        };
        await SupabaseService.instance.updateUser(widget.user.id, fields);
      }

      // Keep the driver verification profile's photo in sync safely
      if (updated.isDriver) {
        await app.updateDriverDocProfile(photoUrl);
      }

      await app.refreshUser();
      if (updated.isDriver) await app.refreshDriverProfile();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Color(0xFF059669),
          ),
        );
      }
    } catch (e, stack) {
      debugPrint('[EDIT PROFILE] Unable to update profile: $e');
      debugPrintStack(stackTrace: stack);
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to update profile: $e'),
            backgroundColor: const Color(0xFFDC2626), // red-600
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: NeumorphicColors.surface(isDark),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.5)
                  : const Color(0xFFA6B4C9).withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Edit Profile',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: NeumorphicColors.text(isDark),
                      letterSpacing: -0.3,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: NeumorphicColors.subtext(isDark),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Avatar with Photo / Color Picker
              Center(
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: NeumorphicDecorations.subtleShadows(isDark),
                      ),
                      child: GestureDetector(
                        onTap: _choosePhotoSource,
                        child: CircleAvatar(
                          radius: 48,
                          backgroundColor: _avatarColors[_selectedAvatarIndex]
                              .withValues(alpha: 0.18),
                          foregroundImage: _photoPreview(),
                          onForegroundImageError:
                              _photoPreview() != null ? (_, __) {} : null,
                          child: Text(
                            _nameCtrl.text.isNotEmpty
                                ? _nameCtrl.text[0].toUpperCase()
                                : 'P',
                            style: TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w900,
                              color: _avatarColors[_selectedAvatarIndex],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _choosePhotoSource,
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: NeumorphicColors.brandPrimary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: NeumorphicColors.surface(isDark),
                              width: 2.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Action buttons: change / remove photo
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: _choosePhotoSource,
                    icon: Icon(
                      Icons.photo_library_rounded,
                      size: 18,
                      color: NeumorphicColors.brandPrimary,
                    ),
                    label: Text(
                      'Change Photo',
                      style: TextStyle(
                        color: NeumorphicColors.brandPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (widget.user.profilePhotoUrl != null ||
                      _photoBytes != null) ...[
                    Text('•',
                        style: TextStyle(color: NeumorphicColors.subtext(isDark))),
                    TextButton.icon(
                      onPressed: () => setState(() {
                        _removePhoto = true;
                        _photoBytes = null;
                        _photoPath = null;
                      }),
                      icon: const Icon(Icons.delete_outline_rounded,
                          size: 18, color: Color(0xFFDC2626)),
                      label: const Text(
                        'Remove',
                        style: TextStyle(
                          color: Color(0xFFDC2626),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),

              // Color options
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: List.generate(_avatarColors.length, (i) {
                  final isSelected = i == _selectedAvatarIndex;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedAvatarIndex = i),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: _avatarColors[i],
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                                width: 3,
                              )
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: _avatarColors[i].withValues(alpha: 0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 22),

              // Form fields with Neumorphic Inset
              Container(
                decoration: NeumorphicDecorations.inset(
                  isDark: isDark,
                  radius: 14,
                ),
                child: TextField(
                  controller: _nameCtrl,
                  style: TextStyle(color: NeumorphicColors.text(isDark)),
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    labelStyle: TextStyle(
                      color: NeumorphicColors.subtext(isDark),
                      fontSize: 13,
                    ),
                    prefixIcon: Icon(Icons.person_rounded,
                        color: NeumorphicColors.subtext(isDark)),
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                decoration: NeumorphicDecorations.inset(
                  isDark: isDark,
                  radius: 14,
                ),
                child: TextField(
                  controller: _mobileCtrl,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(color: NeumorphicColors.text(isDark)),
                  decoration: InputDecoration(
                    labelText: 'Mobile Number',
                    labelStyle: TextStyle(
                      color: NeumorphicColors.subtext(isDark),
                      fontSize: 13,
                    ),
                    prefixIcon: Icon(Icons.phone_iphone_rounded,
                        color: NeumorphicColors.subtext(isDark)),
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                decoration: NeumorphicDecorations.inset(
                  isDark: isDark,
                  radius: 14,
                ),
                child: TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(color: NeumorphicColors.text(isDark)),
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    labelStyle: TextStyle(
                      color: NeumorphicColors.subtext(isDark),
                      fontSize: 13,
                    ),
                    prefixIcon: Icon(Icons.email_outlined,
                        color: NeumorphicColors.subtext(isDark)),
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Save Button
              NeumorphicButton(
                text: 'Save Changes',
                accentColor: NeumorphicColors.brandPrimary,
                isLoading: _isSaving,
                height: 50,
                onPressed: _isSaving ? null : _saveProfile,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
