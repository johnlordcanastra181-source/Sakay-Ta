import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/neumorphic_theme.dart';
import '../core/time_utils.dart';
import '../l10n/app_localizations.dart';
import '../main.dart' hide Brand, Avatar;
import '../state/app_state.dart';
import 'password_recovery_page.dart';
import '../widgets/common.dart';
import '../widgets/neumorphic_widgets.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.onNavigate});
  final Function(AppScreen) onNavigate;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLoading = false;
  String? _error;
  bool _showPassword = false;
  String _selectedRole = 'passenger';
  Timer? _timeTicker;

  @override
  void initState() {
    super.initState();
    // Keep greeting up-to-date automatically as time passes
    _timeTicker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timeTicker?.cancel();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please enter your email and password');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final appState = context.read<AppState>();
      await appState.login(
        email: email,
        password: password,
        role: _selectedRole,
      );

      if (mounted) {
        if (appState.lastError == 'pending') {
          widget.onNavigate(AppScreen.driverPendingApproval);
        } else if (appState.lastError != null) {
          setState(() => _error = _friendlyError(appState.lastError!));
        } else if (appState.currentUser != null) {
          if (appState.currentUser!.isAdmin) {
            widget.onNavigate(AppScreen.adminDashboard);
          } else if (appState.currentUser!.isDriver) {
            widget.onNavigate(AppScreen.driverHome);
          } else {
            widget.onNavigate(AppScreen.passengerHome);
          }
        }
      }
    } catch (e) {
      setState(() => _error = _friendlyError(e.toString()));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _forgotPassword() => showPasswordRecoveryDialog(
        context,
        initialEmail: _emailCtrl.text,
      );

  String _friendlyError(String code) {
    if (code.contains('Sqflite') ||
        code.contains('DatabaseException') ||
        code.contains('unsupported result null') ||
        code.contains('Unsupported operation')) {
      return 'Database connection issue. Please refresh the page and try again.';
    }
    return switch (code) {
      'wrong_password' => 'Incorrect email or password. Please try again.',
      'wrong_role' => 'This account is not registered as the selected '
          'role. Choose the right role and try again.',
      'no_user' =>
        'No account found with these credentials. Please check or sign up first.',
      'profile_not_found' =>
        'Unable to load your saved profile. Please check your internet connection and try logging in again.',
      'profile_unavailable' =>
        'Your login was verified, but your saved profile could not be loaded. Please try again. Your account has not been deleted.',
      'network_unavailable' =>
        'Unable to connect. Please check your internet connection and try again.',
      'use_registered_email' =>
        'Try your registered email address and password. Mobile login may be unavailable after clearing app data.',
      'too_many_requests' =>
        'Too many login attempts. Please wait and try again.',
      'account_deactivated' =>
        'This account has been deactivated. Please contact support or your system administrator.',
      'pending' => 'Your driver application is still under review. You will be '
          'notified once approved.',
      'rejected' =>
        'Your driver application was rejected. Contact support for help.',
      _ => code.startsWith('Exception: ') ? code.substring(11) : code,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeCode = context.watch<LocaleProvider>().locale.languageCode;
    final app = context.watch<AppState>();
    final isDark =
        app.darkMode || Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: NeumorphicColors.canvas(isDark),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Navigation Bar: Brand on left, Neumorphic Theme Toggle on right
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Brand(dark: isDark),
                  _buildThemeToggle(context, isDark, app),
                ],
              ),
              const SizedBox(height: 28),

              // Role & Language Selector Row with soft depth
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Segmented Role Toggle (Passenger | Driver)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: NeumorphicDecorations.inset(
                      isDark: isDark,
                      radius: 22,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildRoleOption(
                          label: l10n.rolePassenger,
                          isSelected: _selectedRole == 'passenger',
                          isDark: isDark,
                          onTap: () =>
                              setState(() => _selectedRole = 'passenger'),
                        ),
                        _buildRoleOption(
                          label: l10n.roleDriver,
                          isSelected: _selectedRole == 'driver',
                          isDark: isDark,
                          onTap: () => setState(() => _selectedRole = 'driver'),
                        ),
                      ],
                    ),
                  ),

                  // Language Selector Pill
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: NeumorphicDecorations.raised(
                      isDark: isDark,
                      radius: 20,
                      distance: 2.5,
                      blur: 6.0,
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: localeCode,
                        isDense: true,
                        dropdownColor:
                            isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        icon: Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Icon(Icons.arrow_drop_down,
                              size: 18,
                              color: NeumorphicColors.textSecondary(isDark)),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'en',
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.language_rounded,
                                    size: 16,
                                    color:
                                        NeumorphicColors.textSecondary(isDark)),
                                const SizedBox(width: 6),
                                Text('English',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color:
                                            NeumorphicColors.textPrimary(isDark),
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'ceb',
                            child: Text('🇵🇭 Cebuano',
                                style: TextStyle(
                                    fontSize: 13,
                                    color:
                                        NeumorphicColors.textPrimary(isDark),
                                    fontWeight: FontWeight.w600)),
                          ),
                          DropdownMenuItem(
                            value: 'tl',
                            child: Text('🇵🇭 Tagalog',
                                style: TextStyle(
                                    fontSize: 13,
                                    color:
                                        NeumorphicColors.textPrimary(isDark),
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            context.read<LocaleProvider>().setLocale(val);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Greeting Header matching current local time
              Text(
                '${TimeGreeting.getLocalizedGreeting(localeCode: localeCode)}!',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: NeumorphicColors.textPrimary(isDark),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _selectedRole == 'passenger'
                    ? l10n.loginSubtitlePassenger
                    : l10n.loginSubtitleDriver,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: NeumorphicColors.textSecondary(isDark),
                ),
              ),
              const SizedBox(height: 28),

              // Email Address Inset Field
              NeumorphicTextField(
                label: l10n.profileEmail,
                hintText: 'name@example.com',
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                prefixIcon: Icon(
                  Icons.email_outlined,
                  color: NeumorphicColors.brandPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(height: 18),

              // Password Row: Label & Forgot Password Link
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    l10n.loginPassword,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: NeumorphicColors.textSecondary(isDark),
                    ),
                  ),
                  GestureDetector(
                    onTap: _forgotPassword,
                    child: Text(
                      l10n.loginForgotPassword,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? NeumorphicColors.brandAmber
                            : NeumorphicColors.brandPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Password Inset Field
              NeumorphicTextField(
                hintText: '••••••••',
                controller: _passwordCtrl,
                obscureText: !_showPassword,
                prefixIcon: const Icon(
                  Icons.lock_outline_rounded,
                  color: NeumorphicColors.brandPrimary,
                  size: 20,
                ),
                suffixIcon: IconButton(
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 40, minHeight: 40),
                  splashRadius: 20,
                  icon: Icon(
                    _showPassword
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_outlined,
                    color: NeumorphicColors.textSecondary(isDark),
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _showPassword = !_showPassword),
                ),
              ),

              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF451A1A)
                          : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFFB91C1C)
                            : const Color(0xFFFCA5A5),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            size: 18, color: Color(0xFFEF4444)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: isDark
                                  ? const Color(0xFFFCA5A5)
                                  : const Color(0xFFDC2626),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 28),

              // Neumorphic Primary Login Button
              NeumorphicButton(
                text: l10n.loginLoginButton,
                isLoading: _isLoading,
                height: 52,
                accentColor: NeumorphicColors.brandPrimary,
                onPressed: _isLoading ? null : _login,
              ),

              const SizedBox(height: 24),

              // Bottom Link: Don't have an account? Sign Up
              Center(
                child: GestureDetector(
                  onTap: () {
                    if (_selectedRole == 'driver') {
                      widget.onNavigate(AppScreen.driverRegistration);
                    } else {
                      widget.onNavigate(AppScreen.passengerRegistration);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      l10n.loginNoAccount,
                      style: TextStyle(
                        color: isDark
                            ? NeumorphicColors.brandAmber
                            : NeumorphicColors.brandPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Footer: Copyright
              Text(
                '© 2026 Sakay Ta. All rights reserved.',
                style: TextStyle(
                  fontSize: 12,
                  color: NeumorphicColors.subtext(isDark),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleOption({
    required String label,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: isSelected
            ? NeumorphicDecorations.raised(
                isDark: isDark,
                radius: 18,
                color: isDark ? const Color(0xFF26334D) : Colors.white,
                distance: 2.0,
                blur: 5.0,
              )
            : const BoxDecoration(color: Colors.transparent),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
            color: isSelected
                ? (isDark
                    ? NeumorphicColors.brandAmber
                    : NeumorphicColors.brandPrimary)
                : NeumorphicColors.textSecondary(isDark),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeToggle(BuildContext context, bool isDark, AppState app) {
    return NeumorphicIconButton(
      icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
      iconColor:
          isDark ? NeumorphicColors.brandAmber : NeumorphicColors.brandNavy,
      size: 40,
      iconSize: 20,
      tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
      onTap: () => app.setDarkMode(!isDark),
    );
  }
}

