import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';
import '../models/app_user.dart';
import 'password_change_page.dart';
import '../services/payment_service.dart';
import '../services/saved_places_service.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/edit_profile_modal.dart';
import '../widgets/help_center_modal.dart';
import '../widgets/passenger_bottom_nav.dart';
import '../widgets/saved_places_modal.dart';
import '../widgets/user_avatar.dart';

class PassengerProfile extends StatefulWidget {
  const PassengerProfile({super.key, required this.onNavigate});
  final Function(AppScreen) onNavigate;

  @override
  State<PassengerProfile> createState() => _PassengerProfileState();
}

class _PassengerProfileState extends State<PassengerProfile> {
  final PaymentService _paymentService = PaymentService.instance;
  final SavedPlacesService _savedPlacesService = SavedPlacesService.instance;
  Stream<List<RideEntry>>? _completedHistoryStream;
  String? _completedHistoryStreamKey;

  @override
  void initState() {
    super.initState();
    final user = context.read<AppState>().currentUser;
    _paymentService.init(user?.id);
    _savedPlacesService.init(user?.id);
  }

  Stream<List<RideEntry>> _stableCompletedHistoryStream(
      AppState app, String userId) {
    if (_completedHistoryStream == null ||
        _completedHistoryStreamKey != userId) {
      _completedHistoryStreamKey = userId;
      _completedHistoryStream =
          app.rideHistoryStream(status: RideStatus.completed);
    }
    return _completedHistoryStream!;
  }

  void _showLanguageSelector(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeProvider = context.read<LocaleProvider>();
    final currentCode = localeProvider.locale.languageCode;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.profileSelectLanguage,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E1E1E),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _languageTile(
              label: l10n.profileBisayaLanguage,
              code: 'ceb',
              selected: currentCode == 'ceb',
              onTap: () {
                localeProvider.setLocale('ceb');
                Navigator.pop(ctx);
                if (mounted) setState(() {});
              },
            ),
            const SizedBox(height: 8),
            _languageTile(
              label: l10n.profileEnglishLanguage,
              code: 'en',
              selected: currentCode == 'en',
              onTap: () {
                localeProvider.setLocale('en');
                Navigator.pop(ctx);
                if (mounted) setState(() {});
              },
            ),
            const SizedBox(height: 8),
            _languageTile(
              label: l10n.profileTagalogLanguage,
              code: 'tl',
              selected: currentCode == 'tl',
              onTap: () {
                localeProvider.setLocale('tl');
                Navigator.pop(ctx);
                if (mounted) setState(() {});
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _languageTile({
    required String label,
    required String code,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFD97706).withValues(alpha: 0.08)
              : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? const Color(0xFFD97706) : const Color(0xFFE5E7EB),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                  color: const Color(0xFF1E1E1E),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded,
                  color: Color(0xFFD97706), size: 20),
          ],
        ),
      ),
    );
  }

  String _getLanguageDisplay(String code) {
    switch (code) {
      case 'ceb':
      case 'bis':
        return 'Bisaya';
      case 'tl':
      case 'fil':
        return 'Tagalog';
      default:
        return 'English';
    }
  }

  Future<void> _handleClearCache(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final sizeFreed = await context.read<AppState>().clearCache();
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.profileClearCacheSuccess(sizeFreed),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    showPasswordChangeDialog(context);
  }

  void _showNotificationSettings(BuildContext context) {
    final app = context.read<AppState>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Notification Settings',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E1E1E)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SwitchListTile(
                title: const Text('Ride Status Alerts',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text(
                    'Real-time alerts when your driver arrives, begins trip, or completes ride.',
                    style: TextStyle(fontSize: 12)),
                value: app.notificationsEnabled,
                activeThumbColor: AppColors.terracotta,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) {
                  setSheetState(() {});
                  app.updateDriverPreferences(notifications: val);
                  setState(() {});
                },
              ),
              const Divider(height: 20),
              SwitchListTile(
                title: const Text('Sound Alerts',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text(
                    'Play sound chime when rides update or new messages arrive.',
                    style: TextStyle(fontSize: 12)),
                value: app.soundAlertsEnabled,
                activeThumbColor: AppColors.terracotta,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) {
                  setSheetState(() {});
                  app.updateDriverPreferences(soundAlerts: val);
                  setState(() {});
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showEmergencyHotlines(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.shield_rounded,
                          color: Color(0xFFDC2626), size: 24),
                      SizedBox(width: 8),
                      Text('Emergency & Safety',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Sakay Ta 24/7 Bohol Emergency Response Hotlines:',
                style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 14),
              _hotlineTile(
                  title: 'Philippine National Emergency',
                  number: '911 / 117',
                  icon: Icons.local_police_rounded),
              _hotlineTile(
                  title: 'Tagbilaran City Police Station',
                  number: '(038) 411-2222 / 0998-598-6362',
                  icon: Icons.security_rounded),
              _hotlineTile(
                  title: 'Bohol Disaster Risk Reduction (TaRSIER 117)',
                  number: '(038) 411-0138 / 0917-814-1188',
                  icon: Icons.medical_services_rounded),
              _hotlineTile(
                  title: 'Tagbilaran City Fire Station',
                  number: '(038) 411-3030 / 160',
                  icon: Icons.fire_truck_rounded),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hotlineTile(
      {required String title, required String number, required IconData icon}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFDC2626).withValues(alpha: 0.1),
            child: Icon(icon, color: const Color(0xFFDC2626), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                Text(number,
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF0284C7),
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l10n.profileLogoutTitle),
        content: Text(l10n.profileLogoutMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.profileLogoutButton),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await context.read<AppState>().logout();
      widget.onNavigate(AppScreen.login);
    }
  }

  Future<void> _handleDeleteAccount(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          l10n.profileDeleteAccountTitle,
          style: const TextStyle(
              color: Color(0xFFDC2626), fontWeight: FontWeight.bold),
        ),
        content: Text(l10n.profileDeleteAccountWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.profileDeleteAccountConfirmButton),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await context.read<AppState>().deleteAccount();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text(l10n.profileDeleteAccountSuccess),
        ),
      );
      widget.onNavigate(AppScreen.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final app = context.watch<AppState>();
    final user = app.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view your profile.')),
      );
    }

    final localeProvider = context.watch<LocaleProvider>();
    final currentLangLabel =
        _getLanguageDisplay(localeProvider.locale.languageCode);

    final isDark =
        app.darkMode || Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.canvasColor(isDark),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: AppColors.cardColor(isDark),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const SakayTaLogoIcon(size: 28),
                      const SizedBox(width: 8),
                      Text(
                        user.isDriver ? 'Driver Settings' : l10n.profileTitle,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textColor(isDark),
                        ),
                      ),
                    ],
                  ),
                  UserAvatar(
                    photoUrl:
                        user.profilePhotoUrl ?? app.driverProfile?.docProfile,
                    name: user.fullName,
                    radius: 17,
                    avatarColorIndex: user.avatarColor,
                    onTap: () => EditProfileModal.show(context, user: user),
                  ),
                ],
              ),
            ),

            // Main Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: user.isDriver
                    ? _buildDriverContent(
                        context, user, app, l10n, currentLangLabel)
                    : _buildPassengerContent(
                        context, user, app, l10n, currentLangLabel),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: user.isDriver
          ? _buildDriverBottomNav()
          : PassengerBottomNav(
              currentIndex: 3,
              onNavigate: widget.onNavigate,
            ),
    );
  }

  // --- Passenger Profile View ---
  Widget _buildPassengerContent(
    BuildContext context,
    AppUser user,
    AppState app,
    AppLocalizations l10n,
    String currentLangLabel,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Hero Avatar & Name
        Center(
          child: Column(
            children: [
              UserAvatar(
                photoUrl: user.profilePhotoUrl,
                name: user.fullName,
                radius: 46,
                avatarColorIndex: user.avatarColor,
                showCameraBadge: true,
                border: Border.all(color: Colors.white, width: 3),
                elevation: 4,
                onTap: () => EditProfileModal.show(context, user: user),
              ),
              const SizedBox(height: 12),
              Text(
                user.fullName.isNotEmpty ? user.fullName : 'Passenger',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textColor(app.darkMode ||
                      Theme.of(context).brightness == Brightness.dark),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified_rounded,
                      size: 16, color: Color(0xFF059669)),
                  const SizedBox(width: 4),
                  Text(
                    l10n.profileTrustedPassenger,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF059669),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        // Statistics Cards
        Row(
          children: [
            Expanded(
              child: StreamBuilder<List<RideEntry>>(
                stream: _stableCompletedHistoryStream(app, user.id),
                builder: (context, snap) {
                  final count =
                      snap.hasData ? snap.data!.length : user.totalTrips;
                  return _buildStatCard(
                    value: '$count',
                    label: l10n.profileTotalRides,
                    watermarkIcon: Icons.directions_bus_rounded,
                  );
                },
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildStatCard(
                value: '${user.createdAt.year}',
                label: l10n.profileJoinedSince,
                watermarkIcon: Icons.calendar_month_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // ACCOUNT SETTINGS
        Text(
          l10n.profileAccountSettings,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.subtextColor(app.darkMode ||
                  Theme.of(context).brightness == Brightness.dark)),
        ),
        const SizedBox(height: 10),
        _buildMenuCard(
          icon: Icons.person_rounded,
          iconColor: const Color(0xFFD97706),
          iconBg: const Color(0xFFFEF3C7),
          title: l10n.profileEdit,
          subtitle: 'Name, phone, email, profile photo',
          onTap: () => EditProfileModal.show(context, user: user),
        ),
        const SizedBox(height: 10),
        ListenableBuilder(
          listenable: _savedPlacesService,
          builder: (context, _) => _buildMenuCard(
            icon: Icons.location_on_rounded,
            iconColor: const Color(0xFF059669),
            iconBg: const Color(0xFFECFDF5),
            title: l10n.profileSavedPlaces,
            subtitle: _savedPlacesService.summary,
            onTap: () => SavedPlacesModal.show(context, userId: user.id),
          ),
        ),
        const SizedBox(height: 10),
        _buildMenuCard(
          icon: Icons.lock_outline_rounded,
          iconColor: const Color(0xFF0284C7),
          iconBg: const Color(0xFFE0F2FE),
          title: 'Change Password',
          subtitle: 'Update your account password',
          onTap: () => _showChangePasswordDialog(context),
        ),
        const SizedBox(height: 24),

        // PREFERENCES & APP SETTINGS
        Text(
          l10n.profilePreferencesSupport,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.subtextColor(app.darkMode ||
                  Theme.of(context).brightness == Brightness.dark)),
        ),
        const SizedBox(height: 10),
        _buildMenuCard(
          icon: Icons.translate_rounded,
          iconColor: const Color(0xFF4B5563),
          iconBg: const Color(0xFFF3F4F6),
          title: l10n.commonLanguage,
          trailingText: currentLangLabel,
          onTap: () => _showLanguageSelector(context),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.cardColor(app.darkMode),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderColor(app.darkMode)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: app.darkMode
                      ? const Color(0xFF334155)
                      : const Color(0xFFFEF3C7),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.dark_mode_rounded,
                    color: app.darkMode
                        ? const Color(0xFFFBBF24)
                        : const Color(0xFFD97706),
                    size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  l10n.profileDarkMode,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textColor(app.darkMode)),
                ),
              ),
              Switch(
                value: app.darkMode,
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.terracotta,
                onChanged: (val) => app.setDarkMode(val),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _buildMenuCard(
          icon: Icons.notifications_active_rounded,
          iconColor: const Color(0xFF8B5CF6),
          iconBg: const Color(0xFFF3E8FF),
          title: 'Push & Ride Alerts',
          subtitle: 'Sounds, ride updates, reminders',
          onTap: () => _showNotificationSettings(context),
        ),
        const SizedBox(height: 10),
        _buildMenuCard(
          icon: Icons.cleaning_services_rounded,
          iconColor: const Color(0xFF0284C7),
          iconBg: const Color(0xFFE0F2FE),
          title: l10n.profileClearCache,
          subtitle: l10n.profileClearCacheSubtitle,
          onTap: () => _handleClearCache(context),
        ),
        const SizedBox(height: 24),

        // SAFETY & SUPPORT
        Text(
          'SAFETY & SUPPORT',
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.subtextColor(app.darkMode ||
                  Theme.of(context).brightness == Brightness.dark)),
        ),
        const SizedBox(height: 10),
        _buildMenuCard(
          icon: Icons.emergency_rounded,
          iconColor: const Color(0xFFDC2626),
          iconBg: const Color(0xFFFEE2E2),
          title: 'Emergency SOS & Hotlines',
          subtitle: 'Bohol PNP, rescue & dispatch contacts',
          onTap: () => _showEmergencyHotlines(context),
        ),
        const SizedBox(height: 10),
        _buildMenuCard(
          icon: Icons.help_outline_rounded,
          iconColor: const Color(0xFF4B5563),
          iconBg: const Color(0xFFF3F4F6),
          title: l10n.profileHelpCenter,
          onTap: () => HelpCenterModal.show(context),
        ),
        const SizedBox(height: 24),

        // LOG OUT
        _buildLogoutButton(l10n),
        const SizedBox(height: 16),

        // DELETE ACCOUNT
        _buildDeleteAccountButton(l10n),
      ],
    );
  }

  // --- Driver Profile & Settings View ---
  Widget _buildDriverContent(
    BuildContext context,
    AppUser user,
    AppState app,
    AppLocalizations l10n,
    String currentLangLabel,
  ) {
    final driverProfile = app.driverProfile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Driver Hero Header Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.cardColor(app.darkMode),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: AppColors.borderColor(app.darkMode)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  UserAvatar(
                    photoUrl: user.profilePhotoUrl ?? driverProfile?.docProfile,
                    name: user.fullName,
                    radius: 36,
                    avatarColorIndex: user.avatarColor,
                    showCameraBadge: true,
                    elevation: 3,
                    onTap: () => EditProfileModal.show(context, user: user),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.fullName.isNotEmpty ? user.fullName : 'Driver',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textColor(app.darkMode),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star_rounded,
                                      color: Color(0xFFF59E0B), size: 14),
                                  const SizedBox(width: 3),
                                  Text(
                                    user.ratingCount > 0
                                        ? '${user.rating.toStringAsFixed(1)} ★'
                                        : 'New',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: Color(0xFF047857)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: app.darkMode
                                    ? const Color(0xFF26334D)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                driverProfile?.vehicleType == VehicleType.habal
                                    ? '🏍️ Habal-Habal'
                                    : '🛺 Tricycle',
                                style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: app.darkMode
                                        ? Colors.white70
                                        : const Color(0xFF475569)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(
                  height: 1,
                  color: app.darkMode
                      ? const Color(0xFF334155)
                      : const Color(0xFFF1F5F9)),
              const SizedBox(height: 12),
              // Live Online/Offline Toggle in Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: user.isOnline
                              ? const Color(0xFF22C55E)
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        user.isOnline ? 'Online & Ready for Rides' : 'Offline',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: user.isOnline
                              ? const Color(0xFF15803D)
                              : AppColors.subtextColor(app.darkMode),
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: user.isOnline,
                    activeThumbColor: Colors.white,
                    activeTrackColor: const Color(0xFF22C55E),
                    onChanged: (online) => app.setDriverOnline(online),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // VEHICLE & TODA INFORMATION
        Text(
          driverProfile?.vehicleType == VehicleType.habal
              ? 'VEHICLE DETAILS'
              : 'VEHICLE & TODA DETAILS',
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.subtextColor(app.darkMode),
              letterSpacing: 0.5),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardColor(app.darkMode),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderColor(app.darkMode)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        driverProfile?.vehicleType == VehicleType.habal
                            ? Icons.two_wheeler_rounded
                            : Icons.electric_rickshaw_rounded,
                        color: AppColors.terracotta,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        driverProfile?.vehicleType == VehicleType.habal
                            ? 'Habal-Habal Motorcycle'
                            : 'Tricycle Unit',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: app.darkMode
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: app.darkMode
                            ? const Color(0xFF334155)
                            : const Color(0xFFCBD5E1),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 12,
                          color: AppColors.subtextColor(app.darkMode),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Registered',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.subtextColor(app.darkMode),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _detailRow(
                  'Plate Number',
                  driverProfile?.plateNumber.isNotEmpty == true
                      ? driverProfile!.plateNumber
                      : 'Not set'),
              const SizedBox(height: 6),
              _detailRow(
                  'Make & Model',
                  '${driverProfile?.make ?? ''} ${driverProfile?.model ?? ''}'
                          .trim()
                          .isNotEmpty
                      ? '${driverProfile?.make ?? ''} ${driverProfile?.model ?? ''}'
                          .trim()
                      : 'Standard Unit'),
              const SizedBox(height: 6),
              _detailRow(
                  'Color',
                  driverProfile?.color.isNotEmpty == true
                      ? driverProfile!.color
                      : 'Standard'),
              if (driverProfile?.vehicleType != VehicleType.habal) ...[
                const SizedBox(height: 6),
                _detailRow(
                    'TODA Affiliation',
                    driverProfile?.todaName?.isNotEmpty == true
                        ? driverProfile!.todaName!
                        : 'Not provided'),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        // RIDE & DISPATCH PREFERENCES
        Text(
          'RIDE & DISPATCH PREFERENCES',
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.subtextColor(app.darkMode),
              letterSpacing: 0.5),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.cardColor(app.darkMode),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderColor(app.darkMode)),
          ),
          child: Material(
            color: Colors.transparent,
            child: Column(
              children: [
                SwitchListTile(
                  title: Text('Auto-Accept Nearby Rides',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                          color: AppColors.textColor(app.darkMode))),
                  subtitle: Text(
                      'Immediately accepts incoming passenger bookings within range.',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.subtextColor(app.darkMode))),
                  value: app.autoAcceptRides,
                  activeThumbColor: Colors.white,
                  activeTrackColor: AppColors.terracotta,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) =>
                      app.updateDriverPreferences(autoAccept: val),
                ),
                Divider(height: 16, color: AppColors.borderColor(app.darkMode)),
                SwitchListTile(
                  title: Text('Audio Chime on Incoming Request',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                          color: AppColors.textColor(app.darkMode))),
                  subtitle: Text(
                      'Plays distinct sound tone when a passenger books near you.',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.subtextColor(app.darkMode))),
                  value: app.soundAlertsEnabled,
                  activeThumbColor: Colors.white,
                  activeTrackColor: AppColors.terracotta,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) =>
                      app.updateDriverPreferences(soundAlerts: val),
                ),
                Divider(height: 16, color: AppColors.borderColor(app.darkMode)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Search Pickup Radius',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                            color: AppColors.textColor(app.darkMode))),
                    Text('${app.pickupRadiusKm.toStringAsFixed(1)} km',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.terracotta)),
                  ],
                ),
                Slider(
                  value: app.pickupRadiusKm,
                  min: 1.0,
                  max: 10.0,
                  divisions: 9,
                  activeColor: AppColors.terracotta,
                  inactiveColor: app.darkMode
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0),
                  label: '${app.pickupRadiusKm.toStringAsFixed(0)} km',
                  onChanged: (val) => app.updateDriverPreferences(radius: val),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // ACCOUNT & SECURITY
        Text(
          'ACCOUNT & SECURITY',
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.subtextColor(app.darkMode),
              letterSpacing: 0.5),
        ),
        const SizedBox(height: 10),
        _buildMenuCard(
          icon: Icons.person_rounded,
          iconColor: const Color(0xFFD97706),
          iconBg: const Color(0xFFFEF3C7),
          title: 'Personal Info & Photo',
          subtitle: 'Name, phone, email, driver profile picture',
          onTap: () => EditProfileModal.show(context, user: user),
        ),
        const SizedBox(height: 10),
        _buildMenuCard(
          icon: Icons.lock_outline_rounded,
          iconColor: const Color(0xFF0284C7),
          iconBg: const Color(0xFFE0F2FE),
          title: 'Change Password',
          subtitle: 'Update your driver login credentials',
          onTap: () => _showChangePasswordDialog(context),
        ),
        const SizedBox(height: 20),

        // PREFERENCES
        Text(
          'APP PREFERENCES',
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.subtextColor(app.darkMode),
              letterSpacing: 0.5),
        ),
        const SizedBox(height: 10),
        _buildMenuCard(
          icon: Icons.translate_rounded,
          iconColor: const Color(0xFF4B5563),
          iconBg: const Color(0xFFF3F4F6),
          title: l10n.commonLanguage,
          trailingText: currentLangLabel,
          onTap: () => _showLanguageSelector(context),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.cardColor(app.darkMode),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderColor(app.darkMode)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: app.darkMode
                      ? const Color(0xFF334155)
                      : const Color(0xFFFEF3C7),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.dark_mode_rounded,
                    color: app.darkMode
                        ? const Color(0xFFFBBF24)
                        : const Color(0xFFD97706),
                    size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  l10n.profileDarkMode,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textColor(app.darkMode)),
                ),
              ),
              Switch(
                value: app.darkMode,
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.terracotta,
                onChanged: (val) => app.setDarkMode(val),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _buildMenuCard(
          icon: Icons.cleaning_services_rounded,
          iconColor: const Color(0xFF0284C7),
          iconBg: const Color(0xFFE0F2FE),
          title: l10n.profileClearCache,
          subtitle: l10n.profileClearCacheSubtitle,
          onTap: () => _handleClearCache(context),
        ),
        const SizedBox(height: 20),

        // SUPPORT & HELPLINE
        Text(
          'DRIVER SUPPORT & HELPLINE',
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.subtextColor(app.darkMode),
              letterSpacing: 0.5),
        ),
        const SizedBox(height: 10),
        _buildMenuCard(
          icon: Icons.support_agent_rounded,
          iconColor: const Color(0xFF059669),
          iconBg: const Color(0xFFECFDF5),
          title: 'TODA & Dispatch Office Helpline',
          subtitle: 'Direct contact with local TODA desk',
          onTap: () => _showEmergencyHotlines(context),
        ),
        const SizedBox(height: 10),
        _buildMenuCard(
          icon: Icons.help_outline_rounded,
          iconColor: const Color(0xFF4B5563),
          iconBg: const Color(0xFFF3F4F6),
          title: l10n.profileHelpCenter,
          onTap: () => HelpCenterModal.show(context),
        ),
        const SizedBox(height: 24),

        // LOG OUT
        _buildLogoutButton(l10n),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    final isDark = context.watch<AppState>().darkMode ||
        Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style:
                TextStyle(color: AppColors.subtextColor(isDark), fontSize: 13)),
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppColors.textColor(isDark))),
      ],
    );
  }

  Widget _buildDriverBottomNav() {
    final isDark = context.watch<AppState>().darkMode ||
        Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.navBgColor(isDark),
        border: Border(
          top: BorderSide(color: AppColors.navBorderColor(isDark), width: 1),
        ),
      ),
      child: NavigationBar(
        selectedIndex: 3,
        backgroundColor: AppColors.navBgColor(isDark),
        indicatorColor: Colors.transparent,
        elevation: 0,
        height: 62,
        onDestinationSelected: (i) {
          if (i == 0) widget.onNavigate(AppScreen.driverHome);
          if (i == 1) widget.onNavigate(AppScreen.wallet);
          if (i == 2) widget.onNavigate(AppScreen.performance);
        },
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.home_outlined,
                color: AppColors.navInactiveColor(isDark)),
            selectedIcon: Icon(Icons.home_rounded,
                color: AppColors.navActiveColor(isDark)),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined,
                color: AppColors.navInactiveColor(isDark)),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded,
                color: AppColors.navActiveColor(isDark)),
            label: 'Wallet',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined,
                color: AppColors.navInactiveColor(isDark)),
            selectedIcon: Icon(Icons.insights_rounded,
                color: AppColors.navActiveColor(isDark)),
            label: 'Stats',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_rounded,
                color: AppColors.navActiveColor(isDark)),
            selectedIcon: Icon(Icons.person_rounded,
                color: AppColors.navActiveColor(isDark)),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(AppLocalizations l10n) {
    final isDark = context.watch<AppState>().darkMode ||
        Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () => _handleLogout(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF450A0A).withValues(alpha: 0.6)
              : const Color(0xFFFFECEC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? const Color(0xFFEF4444).withValues(alpha: 0.4)
                : const Color(0xFFFCA5A5).withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_rounded,
                color:
                    isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
                size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                l10n.profileLogoutButton,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? const Color(0xFFF87171)
                      : const Color(0xFFDC2626),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteAccountButton(AppLocalizations l10n) {
    final isDark = context.watch<AppState>().darkMode ||
        Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () => _handleDeleteAccount(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                const Color(0xFFEF4444).withValues(alpha: isDark ? 0.4 : 0.3),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_forever_rounded,
                color:
                    isDark ? const Color(0xFFF87171) : const Color(0xFF991B1B),
                size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                l10n.profileDeleteAccountTitle,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? const Color(0xFFF87171)
                      : const Color(0xFF991B1B),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String value,
    required String label,
    required IconData watermarkIcon,
  }) {
    final isDark = context.watch<AppState>().darkMode ||
        Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardElevated : const Color(0xFFF5F6F8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor(isDark)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -6,
            bottom: -6,
            child: Icon(
              watermarkIcon,
              size: 48,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.05),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Center(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textColor(isDark),
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.subtextColor(isDark),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    String? subtitle,
    String? trailingText,
    required VoidCallback onTap,
  }) {
    final isDark = context.watch<AppState>().darkMode ||
        Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.cardColor(isDark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderColor(isDark)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isDark ? iconColor.withValues(alpha: 0.2) : iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textColor(isDark),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null && subtitle.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.subtextColor(isDark),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (trailingText != null) ...[
              Text(
                trailingText,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.gold : const Color(0xFF6E5600),
                ),
              ),
              const SizedBox(width: 4),
            ],
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: AppColors.subtextColor(isDark),
            ),
          ],
        ),
      ),
    );
  }
}
