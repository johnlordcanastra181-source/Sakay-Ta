import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/neumorphic_theme.dart';
import '../models/app_user.dart';
import '../models/driver_profile.dart';
import '../models/trip.dart';
import '../services/supabase_service.dart';
import '../state/app_state.dart';
import 'neumorphic_widgets.dart';
import 'user_avatar.dart';

/// Responsive, zero-overflow modal bottom sheet that immediately prompts the
/// passenger to rate their driver as soon as a trip is completed.
class RateDriverModal extends StatefulWidget {
  const RateDriverModal({
    super.key,
    required this.trip,
    this.initialDriverName,
    this.initialDriverPhotoUrl,
    this.initialVehicleLabel,
    this.onRated,
  });

  final Trip trip;
  final String? initialDriverName;
  final String? initialDriverPhotoUrl;
  final String? initialVehicleLabel;
  final void Function(int stars, String comment)? onRated;

  static bool _isShowing = false;

  /// Presents the Rate Driver modal bottom sheet if not already visible.
  static Future<bool?> show(
    BuildContext context, {
    required Trip trip,
    String? driverName,
    String? driverPhotoUrl,
    String? vehicleLabel,
    bool force = false,
    void Function(int stars, String comment)? onRated,
  }) async {
    if (_isShowing) return false;
    final app = AppState.instance;
    if (!force && !app.shouldPromptRatingFor(trip.id)) return false;
    app.markRatingPrompted(trip.id);

    _isShowing = true;
    try {
      return await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => RateDriverModal(
          trip: trip,
          initialDriverName: driverName,
          initialDriverPhotoUrl: driverPhotoUrl,
          initialVehicleLabel: vehicleLabel,
          onRated: onRated,
        ),
      );
    } finally {
      _isShowing = false;
    }
  }

  @override
  State<RateDriverModal> createState() => _RateDriverModalState();
}

class _RateDriverModalState extends State<RateDriverModal> {
  int _selectedStars = 5;
  final Set<String> _selectedTags = {};
  final TextEditingController _commentCtrl = TextEditingController();
  bool _isSubmitting = false;

  String? _driverName;
  String? _driverPhotoUrl;
  int _driverAvatarColor = 0;
  String? _vehicleLabel;

  static const List<String> _quickTags = [
    'Safe Driving',
    'Courteous',
    'On Time',
    'Clean Vehicle',
    'Fair Fare',
  ];

  @override
  void initState() {
    super.initState();
    _driverName = widget.initialDriverName;
    _driverPhotoUrl = widget.initialDriverPhotoUrl;
    _vehicleLabel = widget.initialVehicleLabel;
    _loadDriverDetails();
  }

  Future<void> _loadDriverDetails() async {
    final driverId = widget.trip.driverId?.trim();
    if (driverId == null || driverId.isEmpty) return;
    final app = AppState.instance;
    try {
      AppUser? user;
      DriverProfile? profile;
      if (SupabaseService.isConfigured) {
        final results = await Future.wait<Object?>([
          SupabaseService.instance.getUser(driverId),
          SupabaseService.instance.getDriverProfile(driverId),
        ]);
        user = results[0] as AppUser?;
        profile = results[1] as DriverProfile?;
      } else {
        user = await app.auth.getUser(driverId);
        profile = await app.auth.getDriverProfile(driverId);
      }
      if (!mounted) return;
      setState(() {
        if (user != null && user.fullName.trim().isNotEmpty) {
          _driverName = user.fullName.trim();
          _driverAvatarColor = user.avatarColor;
          _driverPhotoUrl = user.profilePhotoUrl ?? profile?.docProfile;
        }
        final vType =
            (profile?.vehicleType ?? widget.trip.vehicleType) == VehicleType.habal
                ? 'Habal-Habal'
                : 'Tricycle';
        final plate = profile?.plateNumber.trim() ?? '';
        _vehicleLabel = plate.isNotEmpty ? '$vType • $plate' : vType;
      });
    } catch (_) {
      // Fallback labels are already initialized.
    }
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  String _starLabel(int stars) {
    switch (stars) {
      case 5:
        return 'Excellent! ⭐⭐⭐⭐⭐';
      case 4:
        return 'Very Good! ⭐⭐⭐⭐';
      case 3:
        return 'Good ⭐⭐⭐';
      case 2:
        return 'Fair ⭐⭐';
      case 1:
        return 'Needs Improvement ⭐';
      default:
        return '';
    }
  }

  Future<void> _submitRating() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final typed = _commentCtrl.text.trim();
    final tagsText = _selectedTags.join(', ');
    final fullComment = [
      if (tagsText.isNotEmpty) tagsText,
      if (typed.isNotEmpty) typed,
    ].join(' — ');

    try {
      final app = context.read<AppState>();
      await app.rateTrip(
        tripId: widget.trip.id,
        rating: _selectedStars,
        comment: fullComment,
      );
      widget.onRated?.call(_selectedStars, fullComment);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Salamat! Your driver rating has been saved.'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to submit rating: $e'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppState.instance.darkMode ||
        Theme.of(context).brightness == Brightness.dark;
    final media = MediaQuery.of(context);
    final resolvedName = (_driverName != null && _driverName!.isNotEmpty)
        ? _driverName!
        : 'Your Driver';
    final resolvedVehicle = (_vehicleLabel != null && _vehicleLabel!.isNotEmpty)
        ? _vehicleLabel!
        : (widget.trip.vehicleType == VehicleType.habal
            ? 'Habal-Habal'
            : 'Tricycle');

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: media.size.height * 0.88,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
          decoration: BoxDecoration(
            color: NeumorphicColors.surface(isDark),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.18),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF475569)
                          : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981)
                                  .withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF10B981),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              'Trip Completed! Rate Driver',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: NeumorphicColors.textPrimary(isDark),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    NeumorphicIconButton(
                      icon: Icons.close_rounded,
                      size: 34,
                      iconSize: 18,
                      onTap: () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                NeumorphicCard(
                  padding: const EdgeInsets.all(14),
                  radius: 16,
                  child: Row(
                    children: [
                      UserAvatar(
                        photoUrl: _driverPhotoUrl,
                        name: resolvedName,
                        avatarColorIndex: _driverAvatarColor,
                        radius: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              resolvedName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.bold,
                                color: NeumorphicColors.textPrimary(isDark),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              resolvedVehicle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: NeumorphicColors.textSecondary(isDark),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '₱${widget.trip.fare.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: NeumorphicColors.textPrimary(isDark),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final starValue = index + 1;
                        final isSelected = starValue <= _selectedStars;
                        return IconButton(
                          iconSize: 38,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          icon: Icon(
                            isSelected
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: isSelected
                                ? const Color(0xFFF59E0B)
                                : NeumorphicColors.textSecondary(isDark),
                          ),
                          onPressed: _isSubmitting
                              ? null
                              : () =>
                                  setState(() => _selectedStars = starValue),
                        );
                      }),
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    _starLabel(_selectedStars),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFD97706),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: _quickTags.map((tag) {
                    final selected = _selectedTags.contains(tag);
                    return GestureDetector(
                      onTap: _isSubmitting
                          ? null
                          : () {
                              setState(() {
                                if (selected) {
                                  _selectedTags.remove(tag);
                                } else {
                                  _selectedTags.add(tag);
                                }
                              });
                            },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? NeumorphicColors.brandPrimary
                                  .withValues(alpha: 0.16)
                              : NeumorphicColors.inset(isDark),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected
                                ? NeumorphicColors.brandPrimary
                                : NeumorphicColors.border(isDark),
                          ),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? NeumorphicColors.brandPrimary
                                : NeumorphicColors.textSecondary(isDark),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                Container(
                  decoration:
                      NeumorphicDecorations.inset(isDark: isDark, radius: 14),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: TextField(
                    controller: _commentCtrl,
                    maxLength: 200,
                    maxLines: 2,
                    enabled: !_isSubmitting,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: NeumorphicColors.textPrimary(isDark),
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      counterText: '',
                      hintText: 'Share feedback about your driver (optional)',
                      hintStyle: TextStyle(
                        fontSize: 12.5,
                        color: NeumorphicColors.textSecondary(isDark),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                NeumorphicButton(
                  text: 'Submit Rating',
                  icon: Icons.star_rounded,
                  accentColor: const Color(0xFFD97706),
                  isLoading: _isSubmitting,
                  onPressed: _isSubmitting ? null : _submitRating,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

