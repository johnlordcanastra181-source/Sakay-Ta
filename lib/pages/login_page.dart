import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/time_utils.dart';
import '../l10n/app_localizations.dart';
import '../main.dart' hide Brand, Avatar;
import '../state/app_state.dart';
import 'password_recovery_page.dart';
import '../widgets/common.dart';

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
      backgroundColor: AppColors.canvasColor(isDark),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Navigation Bar: Brand on left, Theme Toggle on right
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Brand(dark: isDark),
                  _buildThemeToggle(context, isDark, app),
                ],
              ),
              const SizedBox(height: 32),

              // Role & Language Selector Row matching screenshot
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Segmented Role Toggle (Passenger | Driver)
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkCardElevated
                          : const Color(0xFFEFEFEF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () =>
                              setState(() => _selectedRole = 'passenger'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: _selectedRole == 'passenger'
                                  ? (isDark
                                      ? AppColors.goldVibrant
                                      : Colors.white)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(18),
                              border: _selectedRole == 'passenger'
                                  ? (isDark
                                      ? Border.all(color: AppColors.goldVibrant)
                                      : Border.all(
                                          color: const Color(0xFFD0D0D0)))
                                  : null,
                              boxShadow: _selectedRole == 'passenger'
                                  ? [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.05),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Text(
                              l10n.rolePassenger,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: _selectedRole == 'passenger'
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: _selectedRole == 'passenger'
                                    ? (isDark
                                        ? const Color(0xFF0F172A)
                                        : const Color(0xFF1A1A1A))
                                    : (isDark
                                        ? AppColors.darkTextSecondary
                                        : const Color(0xFF707070)),
                              ),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _selectedRole = 'driver'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: _selectedRole == 'driver'
                                  ? (isDark
                                      ? AppColors.goldVibrant
                                      : Colors.white)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(18),
                              border: _selectedRole == 'driver'
                                  ? (isDark
                                      ? Border.all(color: AppColors.goldVibrant)
                                      : Border.all(
                                          color: const Color(0xFFD0D0D0)))
                                  : null,
                              boxShadow: _selectedRole == 'driver'
                                  ? [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.05),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Text(
                              l10n.roleDriver,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: _selectedRole == 'driver'
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: _selectedRole == 'driver'
                                    ? (isDark
                                        ? const Color(0xFF0F172A)
                                        : const Color(0xFF1A1A1A))
                                    : (isDark
                                        ? AppColors.darkTextSecondary
                                        : const Color(0xFF707070)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Language Selector Pill
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkCardElevated
                          : const Color(0xFFEFEFEF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: localeCode,
                        isDense: true,
                        dropdownColor:
                            isDark ? AppColors.darkCardElevated : Colors.white,
                        icon: Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Icon(Icons.arrow_drop_down,
                              size: 18,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : const Color(0xFF404040)),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'en',
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.language_rounded,
                                    size: 16,
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : const Color(0xFF404040)),
                                const SizedBox(width: 6),
                                Text('English',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textColor(isDark),
                                        fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'ceb',
                            child: Text('🇵🇭 Cebuano',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textColor(isDark),
                                    fontWeight: FontWeight.w500)),
                          ),
                          DropdownMenuItem(
                            value: 'tl',
                            child: Text('🇵🇭 Tagalog',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textColor(isDark),
                                    fontWeight: FontWeight.w500)),
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
              const SizedBox(height: 36),

              // Greeting Header matching current local time
              Text(
                '${TimeGreeting.getLocalizedGreeting(localeCode: localeCode)}!',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textColor(isDark),
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
                  color: AppColors.subtextColor(isDark),
                ),
              ),
              const SizedBox(height: 32),

              // Email Address Label & Input Field
              Text(
                l10n.profileEmail,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textColor(isDark),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textColor(isDark),
                    fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  prefixIcon: Icon(
                    Icons.email_outlined,
                    color: AppColors.subtextColor(isDark),
                    size: 22,
                  ),
                  hintText: 'name@example.com',
                  hintStyle: TextStyle(
                      color: AppColors.subtextColor(isDark), fontSize: 14),
                  filled: true,
                  fillColor: AppColors.inputBgColor(isDark),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: isDark
                            ? AppColors.darkBorder
                            : const Color(0xFF998000),
                        width: 1.2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: isDark
                            ? AppColors.darkBorder
                            : const Color(0xFF998000),
                        width: 1.2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: isDark
                            ? AppColors.goldVibrant
                            : const Color(0xFF6E5600),
                        width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Password Label & Forgot Password Link row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.loginPassword,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textColor(isDark),
                    ),
                  ),
                  GestureDetector(
                    onTap: _forgotPassword,
                    child: Text(
                      l10n.loginForgotPassword,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.goldVibrant
                            : const Color(0xFF735A00),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Password Input Field matching screenshot
              TextFormField(
                controller: _passwordCtrl,
                obscureText: !_showPassword,
                style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textColor(isDark),
                    fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  prefixIcon: Icon(
                    Icons.lock_outline_rounded,
                    color: AppColors.subtextColor(isDark),
                    size: 20,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showPassword
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_outlined,
                      color: AppColors.subtextColor(isDark),
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _showPassword = !_showPassword),
                  ),
                  hintText: '••••••••',
                  hintStyle: TextStyle(
                      color: AppColors.subtextColor(isDark), fontSize: 15),
                  filled: true,
                  fillColor: AppColors.inputBgColor(isDark),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: isDark
                            ? AppColors.darkBorder
                            : const Color(0xFF998000),
                        width: 1.2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: isDark
                            ? AppColors.darkBorder
                            : const Color(0xFF998000),
                        width: 1.2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: isDark
                            ? AppColors.goldVibrant
                            : const Color(0xFF6E5600),
                        width: 2),
                  ),
                ),
              ),

              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.red.shade900.withValues(alpha: 0.3)
                          : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: isDark
                              ? Colors.red.shade700
                              : Colors.red.shade200),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ),
                ),

              const SizedBox(height: 32),

              // Large Log In Button
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark
                        ? AppColors.terracottaVibrant
                        : const Color(0xFF6E5600),
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shadowColor: (isDark
                            ? AppColors.terracottaVibrant
                            : const Color(0xFF6E5600))
                        .withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          l10n.loginLoginButton,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 24),

              // Bottom Link: Don't have an account? Create one now
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
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      l10n.loginNoAccount,
                      style: TextStyle(
                        color: isDark
                            ? AppColors.goldVibrant
                            : const Color(0xFF6E5600),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeToggle(BuildContext context, bool isDark, AppState app) {
    return Tooltip(
      message: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => app.setDarkMode(!isDark),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkCardElevated
                  : const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark
                    ? AppColors.darkBorder
                    : const Color(0xFFCBD5E1),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                size: 20,
                color: isDark ? AppColors.goldVibrant : const Color(0xFF1E2B45),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

