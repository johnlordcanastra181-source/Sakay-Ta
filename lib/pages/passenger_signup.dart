import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/logger.dart';
import '../core/neumorphic_theme.dart';
import '../core/phone_utils.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../main.dart' hide Brand, Avatar;
import '../models/philippine_address.dart';
import '../services/auth_service.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/neumorphic_widgets.dart';
import '../widgets/philippine_address_selector.dart';

class PassengerSignupPage extends StatefulWidget {
  const PassengerSignupPage({
    super.key,
    required this.onNavigate,
    this.onNavigateWithArgs,
  });

  final Function(AppScreen) onNavigate;
  final Function(AppScreen, Map<String, dynamic>)? onNavigateWithArgs;

  @override
  State<PassengerSignupPage> createState() => _PassengerSignupPageState();
}

class _PassengerSignupPageState extends State<PassengerSignupPage> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();

  PhilippineAddress? _selectedAddress;
  bool _addressError = false;

  bool _showPassword = false;
  bool _termsAccepted = false;
  bool _termsError = false;
  bool _isLoading = false;

  String _selectedLanguage = 'en';

  @override
  void initState() {
    super.initState();
    _loadLanguagePreference();
  }

  Future<void> _loadLanguagePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLang = prefs.getString('locale') ?? 'en';
    if (mounted) {
      setState(() {
        _selectedLanguage = savedLang;
      });
    }
  }

  Future<void> _changeLanguage(String langCode) async {
    setState(() {
      _selectedLanguage = langCode;
    });

    final localeProvider = context.read<LocaleProvider>();
    await localeProvider.setLocale(langCode);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale', langCode);
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateFullName(String? value, AppLocalizations? l10n) {
    if (value == null || value.trim().length < 2) {
      return l10n?.signUpFullNameError ?? 'Please enter your full name';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email address';
    }
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9.!#$%&`*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$',
    );
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validateMobile(String? value, AppLocalizations? l10n) {
    final error = PhoneUtils.validateNationalNumber(value);
    if (error != null) return error;
    return null;
  }

  String? _validatePassword(String? value, AppLocalizations? l10n) {
    if (value == null || value.length < 6) {
      return l10n?.signUpPasswordError ??
          'Password must be at least 6 characters';
    }
    return null;
  }

  Future<void> _submitForm(AppLocalizations? l10n) async {
    if (_isLoading) return;
    FocusScope.of(context).unfocus();

    // If a province is selected, require full cascade (City & Barangay)
    final hasPartialAddress = _selectedAddress != null &&
        _selectedAddress!.provinceName.isNotEmpty &&
        !_selectedAddress!.isComplete;

    setState(() {
      _addressError = hasPartialAddress;
      _termsError = !_termsAccepted;
    });

    final isFormValid = _formKey.currentState?.validate() ?? false;

    if (!isFormValid || !_termsAccepted || hasPartialAddress) {
      if (hasPartialAddress) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                  'Please complete your City/Municipality and Barangay selection.'),
              backgroundColor: AppColors.danger,
              behavior: SnackBarBehavior.floating,
            ),
          );
      } else if (!_termsAccepted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(l10n?.signUpTermsRequired ??
                  'You must agree to the Terms of Service and Privacy Policy.'),
              backgroundColor: AppColors.danger,
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final fullName = _fullNameController.text.trim();
      final email = _emailController.text.trim().toLowerCase();
      final rawMobile = _mobileController.text.trim();
      final password = _passwordController.text;

      AppLog.i('SignupPage',
          'Creating passenger account for $email with PSGC address: ${_selectedAddress?.formattedAddress}');

      final authService = context.read<AuthService>();
      // Run both duplicate checks concurrently to halve pre-registration time.
      final checks = await Future.wait<bool>([
        authService.isEmailRegistered(email),
        if (rawMobile.isNotEmpty) authService.isMobileRegistered(rawMobile),
      ]);
      final emailRegistered = checks[0];
      final mobileRegistered =
          rawMobile.isNotEmpty && checks.length > 1 ? checks[1] : false;

      if (emailRegistered) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'An account with this email address already exists. Please log in instead.',
              ),
              backgroundColor: AppColors.danger,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      if (mobileRegistered) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'An account with this mobile number already exists. Please log in instead.',
              ),
              backgroundColor: AppColors.danger,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final user = await authService.registerPassenger(
        fullName: fullName,
        mobile: rawMobile,
        password: password,
        email: email,
        address: _selectedAddress,
      );
      if (user == null) {
        throw StateError('Passenger profile setup did not complete.');
      }

      // AuthService only returns after Supabase Auth and the passenger
      // capability row are both acknowledged. Set app state once, then use
      // the single router transition to avoid an OTP route or duplicate home.
      AppState.instance.currentUser = user;
      if (mounted) widget.onNavigate(AppScreen.passengerHome);
    } catch (e, st) {
      AppLog.e('SignupPage', 'Error during signup submit', e, st);
      if (mounted) {
        setState(() => _isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_signupErrorMessage(e)),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _signupErrorMessage(Object error) {
    if (error is AuthException && error.message.isNotEmpty) {
      final msg = error.message;
      final lower = msg.toLowerCase();
      if (lower.contains('confirm email') ||
          lower.contains('no authenticated session')) {
        return 'Registration is not ready on the server. An administrator must disable Supabase Email Confirm before accounts can open immediately.';
      }
      if (lower.contains('already registered') ||
          lower.contains('already exists') ||
          lower.contains('user_already_exists') ||
          lower.contains('email_exists')) {
        return 'This email address is already registered. Please log in instead.';
      }
      return msg;
    }

    final raw = error.toString();
    final lower = raw.toLowerCase();
    if (lower.contains('confirm email') ||
        lower.contains('no authenticated session')) {
      return 'Registration is not ready on the server. An administrator must disable Supabase Email Confirm before accounts can open immediately.';
    }
    if (lower.contains('already registered') ||
        lower.contains('already exists') ||
        lower.contains('user_already_exists') ||
        lower.contains('email_exists')) {
      return 'This email address is already registered. Please log in instead.';
    }
    if (lower.contains('permission denied') ||
        lower.contains('row-level security') ||
        lower.contains('42501')) {
      return 'Your account was created, but the passenger profile could not be saved. Please retry while signed in.';
    }
    if (lower.contains('socketexception') ||
        lower.contains('clientexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('network')) {
      return 'Unable to reach the Sakay Ta server. Please check your internet connection and try again.';
    }
    if (error is StateError && error.message.isNotEmpty) {
      return error.message;
    }
    return 'Unable to complete signup. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final app = context.watch<AppState>();
    final isDark =
        app.darkMode || Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.canvasColor(isDark),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Navigation Bar: Brand on left, Avatar on right
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          NeumorphicIconButton(
                            icon: Icons.arrow_back_ios_new_rounded,
                            size: 40,
                            iconSize: 18,
                            onTap: () => widget.onNavigate(AppScreen.login),
                          ),
                          const SizedBox(width: 8),
                          Brand(dark: isDark),
                        ],
                      ),
                      const Avatar(),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Headline & Subtitle
                  Text(
                    'Create an Account',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textColor(isDark),
                      fontFamily: 'Serif',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Sign up to start booking your rides easily and safely.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.subtextColor(isDark),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Full Name Field
                  _buildOutlineField(
                    label: 'Full Name',
                    controller: _fullNameController,
                    hint: 'e.g. Juan Dela Cruz',
                    prefixIcon: Icons.badge_outlined,
                    validator: (val) => _validateFullName(val, l10n),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 18),

                  // Email Address Field (Primary Identifier)
                  _buildOutlineField(
                    label: 'Email Address',
                    controller: _emailController,
                    hint: 'e.g. juan@gmail.com',
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (val) => _validateEmail(val),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 18),

                  // Mobile Number Field (Optional for passengers)
                  _buildOutlineField(
                    label: 'Mobile Number (Optional)',
                    controller: _mobileController,
                    hint: '912 345 6789 (Optional)',
                    isPhone: true,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    validator: (val) => val == null || val.isEmpty
                        ? null
                        : _validateMobile(val, l10n),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 18),

                  // Address Cascade Dropdown (Province -> City -> Barangay)
                  NeumorphicCard(
                    padding: const EdgeInsets.all(16),
                    radius: 16,
                    border: _addressError
                        ? Border.all(color: AppColors.danger, width: 1.8)
                        : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: NeumorphicColors.brandPrimary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.location_on_rounded,
                                  color: NeumorphicColors.brandPrimary,
                                  size: 18),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Address',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textColor(isDark),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Select your Province, City/Municipality, and Barangay.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.subtextColor(isDark),
                          ),
                        ),
                        const SizedBox(height: 12),
                        PhilippineAddressSelector(
                          initialAddress: _selectedAddress,
                          onAddressChanged: (address) {
                            setState(() {
                              _selectedAddress = address;
                              if (address.isComplete) {
                                _addressError = false;
                              }
                            });
                          },
                          showStreetField: true,
                          streetLabel:
                              'Street Name / House / Unit Details (Optional)',
                          streetHint: 'e.g. Block 4 Lot 12, Acacia Street',
                        ),
                      ],
                    ),
                  ),
                  if (_addressError)
                    const Padding(
                      padding: EdgeInsets.only(left: 14, top: 4),
                      child: Text(
                        'Please select your Province, City/Municipality, and Barangay.',
                        style: TextStyle(color: AppColors.danger, fontSize: 12),
                      ),
                    ),
                  const SizedBox(height: 18),

                  // Password Field with eye toggle
                  _buildOutlineField(
                    label: 'Password',
                    controller: _passwordController,
                    hint: 'At least 6 characters',
                    prefixIcon: Icons.lock_outline_rounded,
                    obscure: !_showPassword,
                    suffix: IconButton(
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 40, minHeight: 40),
                      splashRadius: 20,
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
                    validator: (val) => _validatePassword(val, l10n),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 18),

                  // Preferred Language Field Dropdown
                  _buildLanguageDropdown(isDark),
                  const SizedBox(height: 28),

                  // Terms & Privacy Policy Card Container
                  NeumorphicCard(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    radius: 14,
                    border: _termsError
                        ? Border.all(color: AppColors.danger, width: 1.5)
                        : null,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _termsAccepted = !_termsAccepted;
                          _termsError = !_termsAccepted;
                        });
                      },
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 22,
                            height: 22,
                            child: Checkbox(
                              value: _termsAccepted,
                              activeColor: NeumorphicColors.brandPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              side: BorderSide(
                                color: _termsError
                                    ? AppColors.danger
                                    : (isDark
                                        ? AppColors.darkBorder
                                        : const Color(0xFF808080)),
                                width: 1.6,
                              ),
                              onChanged: (val) {
                                setState(() {
                                  _termsAccepted = val ?? false;
                                  _termsError = !_termsAccepted;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                text: "I agree to Sakay Ta's ",
                                style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textColor(isDark),
                                    height: 1.3),
                                children: [
                                  TextSpan(
                                    text: 'Terms of Service',
                                    style: TextStyle(
                                      color: isDark
                                          ? AppColors.goldVibrant
                                          : const Color(0xFF6E5600),
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                  const TextSpan(text: ' and '),
                                  TextSpan(
                                    text: 'Privacy Policy',
                                    style: TextStyle(
                                      color: isDark
                                          ? AppColors.goldVibrant
                                          : const Color(0xFF6E5600),
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                  const TextSpan(text: '.'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_termsError)
                    const Padding(
                      padding: EdgeInsets.only(left: 14, top: 4),
                      child: Text(
                        'You must agree to the Terms of Service and Privacy Policy.',
                        style: TextStyle(color: AppColors.danger, fontSize: 12),
                      ),
                    ),

                  const SizedBox(height: 28),

                  // Register Now Button
                  NeumorphicButton(
                    text: 'Create Account',
                    icon: Icons.email_outlined,
                    isLoading: _isLoading,
                    onPressed: () => _submitForm(l10n),
                    accentColor: isDark
                        ? AppColors.terracottaVibrant
                        : const Color(0xFFE65100),
                    height: 52,
                  ),

                  const SizedBox(height: 24),

                  // Bottom Link: Already have an account? Log in here
                  Center(
                    child: GestureDetector(
                      onTap: () => widget.onNavigate(AppScreen.login),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: RichText(
                          text: TextSpan(
                            text: 'Already have an account? ',
                            style: TextStyle(
                                color: AppColors.subtextColor(isDark),
                                fontSize: 14),
                            children: [
                              TextSpan(
                                text: 'Log in here',
                                style: TextStyle(
                                  color: isDark
                                      ? AppColors.goldVibrant
                                      : const Color(0xFF6E5600),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOutlineField({
    required String label,
    required TextEditingController controller,
    required String hint,
    IconData? prefixIcon,
    bool isPhone = false,
    bool obscure = false,
    Widget? suffix,
    TextInputType? keyboardType,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: NeumorphicColors.textPrimary(isDark),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: NeumorphicDecorations.inset(
            isDark: isDark,
            radius: 14,
          ),
          child: TextFormField(
            controller: controller,
            obscureText: obscure,
            keyboardType: keyboardType,
            maxLength: maxLength,
            inputFormatters: inputFormatters,
            validator: validator,
            style: TextStyle(
              fontSize: 14,
              color: NeumorphicColors.textPrimary(isDark),
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              isDense: true,
              filled: false,
              fillColor: Colors.transparent,
              hintText: hint,
              hintStyle: TextStyle(
                color: NeumorphicColors.textSecondary(isDark),
                fontSize: 14,
              ),
              helperText: isPhone ? 'Enter the last 10 digits after +63' : null,
              helperStyle: TextStyle(
                color: isDark ? AppColors.goldVibrant : const Color(0xFF8A7B4F),
                fontSize: 11,
              ),
              counterText: '',
              prefixIcon: isPhone
                  ? Padding(
                      padding: const EdgeInsets.only(left: 14, right: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '+63',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: NeumorphicColors.textPrimary(isDark),
                            ),
                          ),
                        ],
                      ),
                    )
                  : (prefixIcon != null
                      ? Icon(prefixIcon,
                          color: NeumorphicColors.textSecondary(isDark),
                          size: 20)
                      : null),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 44, minHeight: 44),
              suffixIcon: suffix,
              suffixIconConstraints:
                  const BoxConstraints(minWidth: 44, minHeight: 44),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageDropdown(bool isDark) {
    return NeumorphicCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      radius: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Preferred Language',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.subtextColor(isDark),
              fontWeight: FontWeight.w700,
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedLanguage,
              isExpanded: true,
              dropdownColor:
                  isDark ? AppColors.darkCardElevated : Colors.white,
              icon: Icon(Icons.arrow_drop_down,
                  color: AppColors.subtextColor(isDark)),
              items: [
                DropdownMenuItem(
                  value: 'en',
                  child: Row(
                    children: [
                      Icon(Icons.language_rounded,
                          size: 18, color: AppColors.subtextColor(isDark)),
                      const SizedBox(width: 8),
                      Text('English',
                          style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textColor(isDark),
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'ceb',
                  child: Row(
                    children: [
                      const Text('🇵🇭', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Text('Cebuano',
                          style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textColor(isDark),
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'tl',
                  child: Row(
                    children: [
                      const Text('🇵🇭', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Text('Tagalog',
                          style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textColor(isDark),
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
              onChanged: (val) {
                if (val != null) _changeLanguage(val);
              },
            ),
          ),
        ],
      ),
    );
  }
}
