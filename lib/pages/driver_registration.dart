import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:uuid/uuid.dart';
import '../core/constants.dart';
import '../core/neumorphic_theme.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../main.dart' hide Brand, Avatar;
import '../widgets/neumorphic_widgets.dart';
import '../models/driver_application_rules.dart';
import '../models/driver_profile.dart';
import '../models/philippine_address.dart';
import '../services/supabase_auth_service.dart';
import '../services/supabase_service.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/philippine_address_selector.dart';

class DriverRegistration extends StatefulWidget {
  const DriverRegistration({super.key, required this.onNavigate});
  final Function(AppScreen) onNavigate;

  @override
  State<DriverRegistration> createState() => _DriverRegistrationState();
}

class _DriverRegistrationState extends State<DriverRegistration> {
  int _currentStep = 0;
  bool _isLoading = false;

  // Step 1: Personal
  final _nameCtrl = TextEditingController(text: '');
  final _mobileCtrl = TextEditingController(text: '');
  final _emailCtrl = TextEditingController(text: '');
  final _passwordCtrl = TextEditingController(text: '');
  final _confirmPasswordCtrl = TextEditingController(text: '');
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  String? _submissionKey;
  String? _statusToken;
  final _dobCtrl = TextEditingController();
  String _selectedSex = 'Select';
  final _addressCtrl = TextEditingController();
  PhilippineAddress? _selectedAddress;

  // Step 2: License
  String? _licenseType;
  final _licenseNumCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final Set<String> _selectedDLCodes = {};
  final Set<String> _selectedConditionCodes = {};

  // Step 3: Vehicle
  VehicleType _vehicleType = VehicleType.tricycle;
  final _plateCtrl = TextEditingController();
  final _makeCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();

  // Step 4: Association & Uploads
  String _selectedToda = '';
  List<Map<String, dynamic>> _todaOptions = [];
  bool _todasLoaded = false;
  bool _todasLoading = false;
  bool _todasLoadFailed = false;
  Future<void>? _todasLoadFuture;
  final _barangayCtrl = TextEditingController();
  final _municipalityCtrl = TextEditingController();
  final _provinceCtrl = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  // Picked document photos (uploaded to private Supabase Storage on submit).
  XFile? _licensePhoto;
  XFile? _orCrPhoto;
  XFile? _profilePhoto;

  @override
  void initState() {
    super.initState();
    // Prefill user details if already signed in
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final firebaseUser = Supabase.instance.client.auth.currentUser;
      final appUser = context.read<AppState>().currentUser;
      if (_nameCtrl.text.isEmpty) {
        _nameCtrl.text = (appUser?.fullName.isNotEmpty == true
                ? appUser!.fullName
                : (firebaseUser?.userMetadata?['full_name'] as String?)) ??
            '';
      }
      if (_emailCtrl.text.isEmpty) {
        _emailCtrl.text = (appUser?.email?.isNotEmpty == true
                ? appUser!.email
                : firebaseUser?.email) ??
            '';
      }
      if (_mobileCtrl.text.isEmpty) {
        _mobileCtrl.text = (appUser?.mobile.isNotEmpty == true
                ? appUser!.mobile
                : (firebaseUser?.userMetadata?['phone'] as String?)) ??
            '';
      }
      if (_addressCtrl.text.isEmpty && appUser?.address?.isNotEmpty == true) {
        _addressCtrl.text = appUser!.address!;
      }
      setState(() {});
    });
  }

  bool get _requiresToda => DriverApplicationRules.requiresToda(_vehicleType);

  Future<void> _loadEligibleTodas() {
    final activeRequest = _todasLoadFuture;
    if (activeRequest != null) return activeRequest;
    final request = _fetchEligibleTodas().whenComplete(() {
      _todasLoadFuture = null;
    });
    _todasLoadFuture = request;
    return request;
  }

  Future<void> _fetchEligibleTodas() async {
    if (mounted) {
      setState(() {
        _todasLoading = true;
        _todasLoaded = false;
        _todasLoadFailed = false;
      });
    }
    try {
      // The query is limited to active rows in the Admin-managed public.todas
      // table. Errors are kept distinct from a successfully empty result.
      final rows = await SupabaseService.instance.todasOnce();
      if (!mounted) return;
      final eligible = rows
          .where((row) {
            final id = row['id']?.toString().trim() ?? '';
            final name = row['name']?.toString().trim() ?? '';
            return id.isNotEmpty && name.isNotEmpty;
          })
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      setState(() {
        _todaOptions = eligible;
        _todasLoaded = true;
        _todasLoadFailed = false;
        if (!_todaOptions.any((toda) => toda['id'] == _selectedToda)) {
          _selectedToda = '';
        }
      });
    } catch (error) {
      debugPrint(
          'DriverApplication: TODA loading failed (${error.runtimeType})');
      if (mounted) {
        setState(() {
          _todaOptions = [];
          _selectedToda = '';
          _todasLoaded = true;
          _todasLoadFailed = true;
        });
      }
    } finally {
      if (mounted) setState(() => _todasLoading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _dobCtrl.dispose();
    _addressCtrl.dispose();
    _licenseNumCtrl.dispose();
    _expiryCtrl.dispose();
    _plateCtrl.dispose();
    _makeCtrl.dispose();
    _modelCtrl.dispose();
    _yearCtrl.dispose();
    _colorCtrl.dispose();
    _barangayCtrl.dispose();
    _municipalityCtrl.dispose();
    _provinceCtrl.dispose();
    super.dispose();
  }

  String get _selectedTodaName {
    if (_selectedToda.isEmpty) return '';
    final found = _todaOptions.firstWhere(
      (t) => t['id'] == _selectedToda,
      orElse: () => {},
    );
    return (found['name'] as String?) ?? '';
  }

  /// Converts the existing MM/DD/YYYY form display (and ISO input) to the
  /// date-only format expected by PostgreSQL. Invalid calendar dates are
  /// rejected instead of being normalized by DateTime.
  String? _isoDateOnly(String value) {
    final input = value.trim();
    final match =
        RegExp(r'^(?:(\d{1,2})/(\d{1,2})/(\d{4})|(\d{4})-(\d{2})-(\d{2}))$')
            .firstMatch(input);
    if (match == null) return null;
    final month = int.tryParse(match.group(1) ?? match.group(5) ?? '');
    final day = int.tryParse(match.group(2) ?? match.group(6) ?? '');
    final year = int.tryParse(match.group(3) ?? match.group(4) ?? '');
    if (month == null || day == null || year == null || year < 1) return null;
    final date = DateTime.utc(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return '${year.toString().padLeft(4, '0')}-'
        '${month.toString().padLeft(2, '0')}-'
        '${day.toString().padLeft(2, '0')}';
  }

  /// Validates the required fields across the steps before submitting.
  /// Returns an error message, or null when everything is filled in.
  String? _validateRequiredFields([AppLocalizations? l10n]) {
    final name = _nameCtrl.text.trim();
    final mobile = _mobileCtrl.text.trim();
    final email = _emailCtrl.text.trim();

    if (name.isEmpty) {
      return l10n?.signUpFullNameError ?? 'Please enter your full name.';
    }
    // Accept 7-11 digits (with or without leading zero, excluding the +63 prefix
    // that is shown separately in the UI).
    final cleanMobile = mobile.replaceAll(RegExp(r'\D'), '');
    if (cleanMobile.length < 7) {
      return 'Please enter a valid mobile number.';
    }
    if (email.isEmpty) {
      return 'Please enter your email address.';
    }
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(email)) {
      return 'Please enter a valid email address (e.g. name@example.com).';
    }
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      if (_passwordCtrl.text.length < 6) {
        return l10n?.signUpPasswordError ??
            'Password must be at least 6 characters.';
      }
      if (_passwordCtrl.text != _confirmPasswordCtrl.text) {
        return l10n?.signUpConfirmPasswordError ??
            'Passwords do not match.';
      }
    }
    if (_dobCtrl.text.trim().isEmpty) {
      return 'Please select your date of birth.';
    }
    if (_isoDateOnly(_dobCtrl.text) == null) {
      return 'Please enter a valid date of birth.';
    }
    if (_selectedSex == 'Select') {
      return 'Please select your sex.';
    }
    if (_addressCtrl.text.trim().isEmpty) {
      return 'Please select your address.';
    }
    final vehicleError = _validateVehicleStep();
    if (vehicleError != null) return vehicleError;
    final licenseNumber = _licenseNumCtrl.text.trim();
    final licenseExpiry = _expiryCtrl.text.trim();
    final hasLicenseDetails = _licenseType != null ||
        licenseNumber.isNotEmpty ||
        licenseExpiry.isNotEmpty;
    if (hasLicenseDetails && _licenseType == null) {
      return 'Please select Professional or Non-Professional for the license provided.';
    }
    if (hasLicenseDetails && licenseNumber.isEmpty) {
      return 'Please enter your driver license number, or leave the license fields empty if you do not have one.';
    }
    if (licenseExpiry.isNotEmpty && _isoDateOnly(licenseExpiry) == null) {
      return 'Enter a valid license expiry date in MM/DD/YYYY format.';
    }
    if (_requiresToda) {
      if (_todasLoadFailed) {
        return 'Unable to load active TODAs. Refresh the list and try again.';
      }
      if (!_todasLoaded) {
        return 'TODA list is still loading. Please try again in a moment.';
      }
      if (_todaOptions.isEmpty) {
        return 'No active TODAs are available. Please contact the administrator.';
      }
      final selectedId = DriverApplicationRules.todaIdForVehicle(
        _vehicleType,
        _selectedToda,
      );
      if (selectedId == null) return 'Please select a TODA.';
      if (!_todaOptions.any((toda) => toda['id']?.toString() == selectedId)) {
        return 'The selected TODA is no longer available. Refresh and select another.';
      }
    }
    if (_profilePhoto == null) {
      return 'Please upload a profile photo before submitting.';
    }
    // License number is optional — drivers without a license yet may still apply.
    return null;
  }

  String? _validateVehicleStep() {
    if (_plateCtrl.text.trim().isEmpty) {
      return 'Please enter your vehicle plate or MV file number.';
    }
    if (_makeCtrl.text.trim().isEmpty || _modelCtrl.text.trim().isEmpty) {
      return 'Please enter your vehicle make and model.';
    }
    final color = DriverApplicationRules.normalizeVehicleColor(_colorCtrl.text);
    if (color == null) {
      return _colorCtrl.text.trim().isEmpty
          ? 'Please enter your vehicle color.'
          : 'Vehicle color must be 60 characters or fewer.';
    }
    return null;
  }

  /// Step one validates the applicant's information without creating an
  /// Auth account. Driver accounts are provisioned only after Admin approval.
  String? _validatePersonalStep([AppLocalizations? l10n]) {
    final name = _nameCtrl.text.trim();
    final mobile = _mobileCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    if (name.isEmpty) {
      return l10n?.signUpFullNameError ?? 'Please enter your full name.';
    }
    if (mobile.replaceAll(RegExp(r'\D'), '').length < 7) {
      return 'Please enter a valid mobile number.';
    }
    if (!RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$')
        .hasMatch(email)) {
      return 'Please enter a valid email address (e.g. name@example.com).';
    }
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      final password = _passwordCtrl.text;
      final confirmPassword = _confirmPasswordCtrl.text;
      if (password.length < 6) {
        return l10n?.signUpPasswordError ??
            'Password must be at least 6 characters.';
      }
      if (password != confirmPassword) {
        return l10n?.signUpConfirmPasswordError ??
            'Passwords do not match.';
      }
    }
    if (_dobCtrl.text.trim().isEmpty) {
      return 'Please select your date of birth.';
    }
    if (_isoDateOnly(_dobCtrl.text) == null) {
      return 'Please enter a valid date of birth.';
    }
    if (_selectedSex == 'Select') {
      return 'Please select your sex.';
    }
    if (_addressCtrl.text.trim().isEmpty) {
      return 'Please select your address.';
    }
    return null;
  }

  Future<void> _continueFromPersonalStep() async {
    if (_isLoading) return;
    final error = _validatePersonalStep(AppLocalizations.of(context));
    if (error != null) {
      _showSubmitError(error);
      return;
    }
    if (mounted) setState(() => _currentStep = 1);
  }

  Future<void> _submitRegistration() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      // Recheck immediately before submission so an association deactivated
      // while this form was open cannot be submitted from a stale dropdown.
      if (_requiresToda) await _loadEligibleTodas();
      if (!mounted) return;
      final validationError =
          _validateRequiredFields(AppLocalizations.of(context));
      if (validationError != null) {
        _showSubmitError(validationError);
        return;
      }

      final name = _nameCtrl.text.trim();
      final mobile = _mobileCtrl.text.trim();
      final email = _emailCtrl.text.trim().toLowerCase();
      debugPrint(
        '[DriverApplication] SUBMIT START '
        'vehicle=${_vehicleType.key} '
        'todaRequired=${_vehicleType == VehicleType.tricycle} '
        'profilePhoto=${_profilePhoto != null} '
        'licensePhoto=${_licensePhoto != null} '
        'orCrPhoto=${_orCrPhoto != null}',
      );

      if (!_requiresToda) _selectedToda = '';
      _submissionKey ??= Uuid().v4();
      _statusToken ??= _newStatusToken();

      final profile = DriverProfile(
        // This is an application-scoped placeholder, never an Auth UID.
        userId: _submissionKey!,
        dob: _isoDateOnly(_dobCtrl.text)!,
        sex: _selectedSex,
        address: _addressCtrl.text.trim(),
        licenseType: _licenseType,
        licenseNumber: _licenseNumCtrl.text.trim(),
        licenseExpiry: _expiryCtrl.text.trim().isEmpty
            ? ''
            : _isoDateOnly(_expiryCtrl.text)!,
        dlCodes: _selectedDLCodes.toList(),
        conditionCodes: _selectedConditionCodes.toList(),
        vehicleType: _vehicleType,
        plateNumber: _plateCtrl.text.trim(),
        make: _makeCtrl.text.trim(),
        model: _modelCtrl.text.trim(),
        year: int.tryParse(_yearCtrl.text.trim()) ?? DateTime.now().year,
        color: DriverApplicationRules.normalizeVehicleColor(_colorCtrl.text)!,
        // Empty strings are not valid foreign keys. Motorcycle/Habal-Habal
        // applicants correctly have no TODA, so persist null instead.
        todaId: DriverApplicationRules.todaIdForVehicle(
          _vehicleType,
          _selectedToda,
        ),
        todaName: _selectedTodaName,
        barangay: _barangayCtrl.text.trim(),
        municipality: _municipalityCtrl.text.trim(),
        province: _provinceCtrl.text.trim(),
        submittedAt: DateTime.now(),
      );

      final files = <String, XFile>{
        if (_profilePhoto != null) 'profile': _profilePhoto!,
        if (_licensePhoto != null) 'license_front': _licensePhoto!,
        if (_orCrPhoto != null) 'or_cr': _orCrPhoto!,
      };
      final documentBytes = <String, Uint8List>{};
      final documentTypes = <String, String>{};
      for (final entry in files.entries) {
        final bytes = await entry.value.readAsBytes();
        if (bytes.isEmpty) {
          throw StateError('The selected ${entry.key} document is empty.');
        }
        documentBytes[entry.key] = bytes;
        documentTypes[entry.key] = _contentTypeFor(entry.value);
      }
      // Ensure applicant has an authenticated Supabase account before submitting
      var authUser = Supabase.instance.client.auth.currentUser;
      authUser ??= await SupabaseAuthService.createAuthenticatedAccount(
        email: email,
        password: _passwordCtrl.text,
        fullName: name,
        mobile: mobile,
      );

      final receipt =
          await SupabaseService.instance.submitUnlinkedDriverApplication(
        fullName: name,
        email: email,
        mobile: mobile,
        profile: profile,
        submissionKey: _submissionKey!,
        statusToken: _statusToken!,
        documentBytes: documentBytes,
        documentContentTypes: documentTypes,
      );
      await AppState.instance.setDriverApplicationReceipt(
        applicationId: receipt.applicationId,
        statusToken: receipt.statusToken,
        email: email,
        status: receipt.status,
      );
      await AppState.instance.prefs.saveSession(authUser.id, UserRole.driver);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Driver application submitted successfully. Please wait for Admin review.',
            ),
            backgroundColor: Color(0xFF2D6A4F),
            behavior: SnackBarBehavior.floating,
          ),
        );
        widget.onNavigate(AppScreen.driverPendingApproval);
      }
    } on AuthException catch (e) {
      debugPrint(
          '[DriverApplication] SUBMIT FAILURE auth code=${e.code} message=${e.message}');
      if (mounted) _showSubmitError(_friendlySubmitError(e));
    } on PostgrestException catch (e) {
      debugPrint(
          '[DriverApplication] SUBMIT FAILURE postgres code=${e.code} message=${e.message} details=${e.details} hint=${e.hint}');
      if (mounted) _showSubmitError(_friendlySubmitError(e));
    } catch (e) {
      debugPrint(
          '[DriverApplication] SUBMIT FAILURE type=${e.runtimeType} error=$e');
      if (mounted) {
        _showSubmitError(_friendlySubmitError(e));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _newStatusToken() {
    final bytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  String _contentTypeFor(XFile file) {
    final declared = file.mimeType?.toLowerCase().split(';').first.trim();
    if (declared == 'image/jpeg' ||
        declared == 'image/png' ||
        declared == 'image/webp') {
      return declared!;
    }
    final name = file.name.toLowerCase();
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    if (name.endsWith('.jpg') || name.endsWith('.jpeg')) return 'image/jpeg';
    throw StateError('Use a JPEG, PNG, or WebP image for driver documents.');
  }

  void _showSubmitError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: _submitRegistration,
        ),
      ),
    );
  }

  String _friendlySubmitError(Object error) {
    final code = error is AuthException ? error.code : '';
    switch (code) {
      case 'invalid-credential':
      case 'invalid-user-token':
      case 'user-token-expired':
        return 'Your session could not be verified. Please sign in again.';
      case 'network-request-failed':
      case 'unavailable':
      case 'deadline-exceeded':
        return 'Unable to connect. Check your internet connection and try again.';
      case 'permission-denied':
      case 'unauthorized':
        return "You don't have permission to perform this action.";
      case 'email-already-in-use':
        return 'This email address is already registered. Please sign in and try again.';
      case 'weak-password':
        return 'Your password is too weak. Please use at least 6 characters.';
      case 'invalid-email':
        return 'The email address you entered is not valid.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'object-not-found':
      case 'bucket-not-found':
      case 'project-not-found':
      case 'quota-exceeded':
      case 'retry-limit-exceeded':
      case 'canceled':
        return 'One of your documents could not be uploaded. Please try again.';
    }

    final raw = error.toString();

    if (error is PostgrestException &&
        (error.code == '23514' || error.code == '23503') &&
        raw.toLowerCase().contains('toda')) {
      return 'The selected TODA is no longer available. Refresh the list and choose an active TODA.';
    }

    if (raw.contains('email-already-in-use') ||
        raw.contains('emailAlreadyInUse')) {
      return 'This email address is already registered. Please log in or use a different email.';
    }
    if (raw.contains('weak-password') || raw.contains('weakPassword')) {
      return 'Your password is too weak. Please use at least 6 characters.';
    }
    if (raw.contains('invalid-email') || raw.contains('invalidEmail')) {
      return 'The email address you entered is not valid.';
    }
    if (raw.contains('network-request-failed') ||
        raw.contains('NetworkException') ||
        raw.contains('SocketException')) {
      return 'No internet connection. Please check your network and try again.';
    }
    if (raw.toLowerCase().contains('confirm email') ||
        raw.toLowerCase().contains('no active authenticated session') ||
        raw.toLowerCase().contains('no authenticated session')) {
      return 'Registration is not ready on the server. An administrator must disable Supabase Email Confirm before driver applications can be submitted without an OTP.';
    }
    if (raw.contains('too-many-requests')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    if (raw.contains('already exists') || raw.contains('already registered')) {
      return 'An account with this information already exists. Please log in instead.';
    }
    if (raw.contains('account has not been created') ||
        raw.contains('Account service is unavailable')) {
      return 'Registration failed. Please check your internet connection and try again.';
    }
    if (raw.contains('SqliteException') || raw.contains('FOREIGN KEY')) {
      return 'We could not save your application because of a local data issue. Please try again.';
    }
    if (raw.contains('already been reviewed')) {
      return 'This application has already been reviewed. Please contact support if you need help.';
    }
    if (raw.contains('StorageException') ||
        raw.contains('upload data') ||
        raw.contains('does not exist') ||
        raw.contains('TimeoutException')) {
      return 'One of your documents could not be uploaded. Please try again.';
    }
    return 'Something went wrong while submitting your application. Please try again.';
  }

  /// Picks a document photo from the gallery with compression for fast uploads.
  Future<void> _pickDocument(int slot) async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 75,
      );
      if (picked == null) return;
      final length = await picked.length();
      if (picked.path.trim().isEmpty || length <= 0) {
        throw StateError('The selected image is empty or unavailable.');
      }
      if (!mounted) return;
      setState(() {
        if (slot == 0) _licensePhoto = picked;
        if (slot == 1) _orCrPhoto = picked;
        if (slot == 2) _profilePhoto = picked;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not open that image. Please choose another.'),
        ));
      }
    }
  }

  Future<void> _handleNext() async {
    if (_currentStep == 0) {
      _continueFromPersonalStep();
      return;
    }
    if (_currentStep == 2) {
      final error = _validateVehicleStep();
      if (error != null) {
        _showSubmitError(error);
        return;
      }
    }
    if (_currentStep == 2 && _requiresToda) {
      await _loadEligibleTodas();
      if (!mounted) return;
    }
    if (_currentStep < 3) {
      setState(() => _currentStep++);
    } else {
      _submitRegistration();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeProvider = context.watch<LocaleProvider>();
    final localeCode = localeProvider.locale.languageCode;
    final app = context.watch<AppState>();
    final isDark =
        app.darkMode || Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.canvasColor(isDark),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar Header: Brand on left, Avatar on right
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      NeumorphicIconButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        size: 40,
                        iconSize: 18,
                        onTap: () {
                          if (_currentStep > 0) {
                            setState(() => _currentStep--);
                          } else {
                            widget.onNavigate(AppScreen.login);
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      Brand(dark: isDark),
                    ],
                  ),
                  const Avatar(),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Sub-header Row: Become a Driver & Language Pill
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            l10n.regTitle,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textColor(isDark),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 2),
                          decoration: NeumorphicDecorations.pill(
                            isDark: isDark,
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: (localeCode == 'ceb' ||
                                      localeCode == 'tl' ||
                                      localeCode == 'en')
                                  ? localeCode
                                  : 'en',
                              isDense: true,
                              dropdownColor: isDark
                                  ? AppColors.darkCardElevated
                                  : const Color(0xFFFFFCF7),
                              borderRadius: BorderRadius.circular(16),
                              icon: Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Icon(Icons.arrow_drop_down,
                                    size: 18,
                                    color: isDark
                                        ? AppColors.goldVibrant
                                        : const Color(0xFF6E5600)),
                              ),
                              selectedItemBuilder: (BuildContext context) {
                                return [
                                  // 'en'
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.language_rounded,
                                          size: 14,
                                          color: isDark
                                              ? AppColors.goldVibrant
                                              : const Color(0xFF6E5600)),
                                      const SizedBox(width: 4),
                                      Text(
                                        'English',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? AppColors.goldVibrant
                                              : const Color(0xFF6E5600),
                                        ),
                                      ),
                                    ],
                                  ),
                                  // 'ceb'
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.language_rounded,
                                          size: 14,
                                          color: isDark
                                              ? AppColors.goldVibrant
                                              : const Color(0xFF6E5600)),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Bisaya',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? AppColors.goldVibrant
                                              : const Color(0xFF6E5600),
                                        ),
                                      ),
                                    ],
                                  ),
                                  // 'tl'
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.language_rounded,
                                          size: 14,
                                          color: isDark
                                              ? AppColors.goldVibrant
                                              : const Color(0xFF6E5600)),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Tagalog',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? AppColors.goldVibrant
                                              : const Color(0xFF6E5600),
                                        ),
                                      ),
                                    ],
                                  ),
                                ];
                              },
                              items: [
                                DropdownMenuItem(
                                  value: 'en',
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.language_rounded,
                                          size: 16,
                                          color: isDark
                                              ? AppColors.goldVibrant
                                              : const Color(0xFF6E5600)),
                                      const SizedBox(width: 8),
                                      Text(
                                        'English',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textColor(isDark),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'ceb',
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('🇵🇭',
                                          style: TextStyle(fontSize: 14)),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Bisaya (Cebuano)',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textColor(isDark),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'tl',
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('🇵🇭',
                                          style: TextStyle(fontSize: 14)),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Tagalog',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textColor(isDark),
                                        ),
                                      ),
                                    ],
                                  ),
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
                    const SizedBox(height: 18),

                    // Stepper Progress Bar (1 - 2 - 3 - 4) matching screenshot
                    _buildStepperProgressBar(l10n, isDark),
                    const SizedBox(height: 24),

                    // Current Step Form
                    if (_currentStep == 0) _buildStep1Personal(l10n, isDark),
                    if (_currentStep == 1) _buildStep2License(l10n, isDark),
                    if (_currentStep == 2) _buildStep3Vehicle(l10n, isDark),
                    if (_currentStep == 3) _buildStep4Upload(l10n, isDark),

                    const SizedBox(height: 28),

                    // Action Button matching screenshot "Next: License Details →"
                    NeumorphicButton(
                      text: _getButtonText(l10n),
                      icon: Icons.arrow_forward_rounded,
                      isLoading: _isLoading,
                      accentColor: isDark
                          ? AppColors.terracottaVibrant
                          : const Color(0xFFE65100),
                      height: 52,
                      onPressed: _isLoading ? null : _handleNext,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getButtonText(AppLocalizations l10n) {
    switch (_currentStep) {
      case 0:
        return l10n.regNextStep(l10n.regStep2);
      case 1:
        return l10n.regNextStep(l10n.regStep3);
      case 2:
        return l10n.regNextStep(l10n.regStep5);
      case 3:
      default:
        return l10n.regSubmitApplication;
    }
  }

  // Stepper Bar matching exact design from screenshot: 1 Personal - 2 License - 3 Vehicle - 4 Upload
  Widget _buildStepperProgressBar(AppLocalizations l10n, bool isDark) {
    final steps = [
      {'num': '1', 'label': l10n.regStep1},
      {'num': '2', 'label': l10n.regStep2},
      {'num': '3', 'label': l10n.regStep3},
      {'num': '4', 'label': l10n.regStep5},
    ];

    return Row(
      children: List.generate(4, (index) {
        final isCompleted = index < _currentStep;
        final isCurrent = index == _currentStep;
        final step = steps[index];

        return Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  if (index > 0)
                    Expanded(
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          color: index <= _currentStep
                              ? (isDark
                                  ? AppColors.goldVibrant
                                  : const Color(0xFFE65100))
                              : (isDark
                                  ? AppColors.darkBorder
                                  : const Color(0xFFDDE3ED)),
                        ),
                      ),
                    ),
                  if (isCompleted)
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF10B981), Color(0xFF059669)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withValues(alpha: 0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.check_rounded, color: Colors.white, size: 18),
                      ),
                    )
                  else if (isCurrent)
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: NeumorphicColors.brandGradient,
                        boxShadow: [
                          BoxShadow(
                            color: NeumorphicColors.brandPrimary.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          step['num']!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 32,
                      height: 32,
                      decoration: NeumorphicDecorations.inset(
                        isDark: isDark,
                        radius: 16,
                      ),
                      child: Center(
                        child: Text(
                          step['num']!,
                          style: TextStyle(
                            color: NeumorphicColors.textSecondary(isDark),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  if (index < 3)
                    Expanded(
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          color: index < _currentStep
                              ? (isDark
                                  ? AppColors.goldVibrant
                                  : const Color(0xFFE65100))
                              : (isDark
                                  ? AppColors.darkBorder
                                  : const Color(0xFFDDE3ED)),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                step['label']!,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                  color: isCurrent
                      ? AppColors.textColor(isDark)
                      : AppColors.subtextColor(isDark),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  // STEP 1: Personal Info
  Widget _buildStep1Personal(AppLocalizations l10n, bool isDark) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner Card "About You"
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardColor(isDark),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderColor(isDark)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.goldVibrant.withValues(alpha: 0.15)
                        : const Color(0xFFFFD600),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person_rounded,
                    color: isDark
                        ? AppColors.goldVibrant
                        : const Color(0xFF1E1E1E),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.regStep1,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textColor(isDark),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.regSubtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.subtextColor(isDark),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Full Name
          Text(
            l10n.regFullName,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.textColor(isDark),
            ),
          ),
          const SizedBox(height: 6),
          _buildGreyTextField(
            controller: _nameCtrl,
            hint: l10n.regFullNameHint,
            isDark: isDark,
          ),
          const SizedBox(height: 16),

          // Mobile Number with split +63 prefix
          Text(
            l10n.regMobileNumber,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.textColor(isDark),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                width: 64,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.inputBgColor(isDark),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.borderColor(isDark)),
                ),
                child: Center(
                  child: Text(
                    '+63',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textColor(isDark),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildGreyTextField(
                  controller: _mobileCtrl,
                  hint: '912 345 6789',
                  keyboardType: TextInputType.phone,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Email Address
          Text(
            l10n.profileEmail,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.textColor(isDark),
            ),
          ),
          const SizedBox(height: 6),
          _buildGreyTextField(
            controller: _emailCtrl,
            hint: 'driver@sakayta.ph',
            keyboardType: TextInputType.emailAddress,
            isDark: isDark,
          ),
          const SizedBox(height: 16),

          // Password
          Text(
            l10n.signUpPassword,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.textColor(isDark),
            ),
          ),
          const SizedBox(height: 6),
          _buildGreyTextField(
            controller: _passwordCtrl,
            hint: l10n.signUpPasswordHint,
            obscureText: !_showPassword,
            isDark: isDark,
            suffixIcon: IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              splashRadius: 20,
              icon: Icon(
                _showPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
                color: AppColors.subtextColor(isDark),
              ),
              onPressed: () => setState(() => _showPassword = !_showPassword),
            ),
          ),
          const SizedBox(height: 16),

          // Confirm Password
          Text(
            l10n.signUpConfirmPassword,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.textColor(isDark),
            ),
          ),
          const SizedBox(height: 6),
          _buildGreyTextField(
            controller: _confirmPasswordCtrl,
            hint: l10n.signUpConfirmPasswordHint,
            obscureText: !_showConfirmPassword,
            isDark: isDark,
            suffixIcon: IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              splashRadius: 20,
              icon: Icon(
                _showConfirmPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
                color: AppColors.subtextColor(isDark),
              ),
              onPressed: () => setState(
                  () => _showConfirmPassword = !_showConfirmPassword),
            ),
          ),
          const SizedBox(height: 16),

          // Date of Birth & Sex (Side-by-side row)
          Row(
            children: [
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.regDateOfBirth,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textColor(isDark),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _dobCtrl,
                      readOnly: true,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textColor(isDark),
                      ),
                      decoration: InputDecoration(
                        hintText: 'mm/dd/yyyy',
                        hintStyle: TextStyle(
                          color: AppColors.subtextColor(isDark),
                          fontSize: 13,
                        ),
                        filled: true,
                        fillColor: AppColors.inputBgColor(isDark),
                        suffixIcon: Icon(
                          Icons.calendar_today_rounded,
                          size: 18,
                          color: AppColors.subtextColor(isDark),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              BorderSide(color: AppColors.borderColor(isDark)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              BorderSide(color: AppColors.borderColor(isDark)),
                        ),
                      ),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime(1995),
                          firstDate: DateTime(1950),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null && mounted) {
                          setState(() {
                            _dobCtrl.text =
                                '${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}/${picked.year}';
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.regSex,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textColor(isDark),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.inputBgColor(isDark),
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: AppColors.borderColor(isDark)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedSex,
                          dropdownColor: AppColors.cardColor(isDark),
                          isExpanded: true,
                          icon: Icon(
                            Icons.arrow_drop_down,
                            color: AppColors.subtextColor(isDark),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'Select',
                              child: Text(
                                l10n.commonSelect,
                                style: TextStyle(
                                  color: AppColors.subtextColor(isDark),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Male',
                              child: Text(
                                l10n.regMale,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textColor(isDark),
                                ),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Female',
                              child: Text(
                                l10n.regFemale,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textColor(isDark),
                                ),
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedSex = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Official PSGC Cascading Philippine Address Selector
          PhilippineAddressSelector(
            initialAddress: _selectedAddress,
            onAddressChanged: (addr) {
              setState(() {
                _selectedAddress = addr;
                _addressCtrl.text = addr.formattedAddress;
                _provinceCtrl.text = addr.provinceName;
                _municipalityCtrl.text = addr.cityName;
                _barangayCtrl.text = addr.barangayName;
              });
            },
          ),
        ],
      );

  // STEP 2: License Details
  Widget _buildStep2License(AppLocalizations l10n, bool isDark) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${l10n.regStep2} Details',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textColor(isDark),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.regLicenseType,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.textColor(isDark),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Optional if you do not have a driver license.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.subtextColor(isDark),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: Text(l10n.regProfessional),
                  selected: _licenseType == 'Professional',
                  selectedColor: isDark
                      ? AppColors.terracottaVibrant
                      : const Color(0xFF6E5600),
                  backgroundColor: AppColors.cardElevatedColor(isDark),
                  side: BorderSide(color: AppColors.borderColor(isDark)),
                  labelStyle: TextStyle(
                    color: _licenseType == 'Professional'
                        ? Colors.white
                        : AppColors.textColor(isDark),
                  ),
                  onSelected: (sel) => setState(
                      () => _licenseType = sel ? 'Professional' : null),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ChoiceChip(
                  label: Text(l10n.regNonProfessional),
                  selected: _licenseType == 'Non-Professional',
                  selectedColor: isDark
                      ? AppColors.terracottaVibrant
                      : const Color(0xFF6E5600),
                  backgroundColor: AppColors.cardElevatedColor(isDark),
                  side: BorderSide(color: AppColors.borderColor(isDark)),
                  labelStyle: TextStyle(
                    color: _licenseType == 'Non-Professional'
                        ? Colors.white
                        : AppColors.textColor(isDark),
                  ),
                  onSelected: (sel) => setState(
                      () => _licenseType = sel ? 'Non-Professional' : null),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            l10n.regLicenseNumber,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.textColor(isDark),
            ),
          ),
          const SizedBox(height: 6),
          _buildGreyTextField(
            controller: _licenseNumCtrl,
            hint: l10n.regLicenseNumberHint,
            isDark: isDark,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.regLicenseExpiry,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.textColor(isDark),
            ),
          ),
          const SizedBox(height: 6),
          _buildGreyTextField(
            controller: _expiryCtrl,
            hint: 'mm/dd/yyyy',
            isDark: isDark,
          ),
        ],
      );

  // STEP 3: Vehicle Details
  Widget _buildStep3Vehicle(AppLocalizations l10n, bool isDark) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${l10n.regStep3} Details',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textColor(isDark),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.regVehicleType,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.textColor(isDark),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _buildVehicleSelectionCard(
                  title: 'Tricycle',
                  subtitle: '3-4 passengers',
                  icon: Icons.electric_rickshaw,
                  isSelected: _vehicleType == VehicleType.tricycle,
                  isDark: isDark,
                  onTap: () {
                    setState(() {
                      _vehicleType = VehicleType.tricycle;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildVehicleSelectionCard(
                  title: 'Habal-Habal',
                  subtitle: 'Motorcycle (1 pax)',
                  icon: Icons.two_wheeler,
                  isSelected: _vehicleType == VehicleType.habal,
                  isDark: isDark,
                  onTap: () {
                    setState(() {
                      _vehicleType = VehicleType.habal;
                      _selectedToda = '';
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            l10n.regPlateNumber,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.textColor(isDark),
            ),
          ),
          const SizedBox(height: 6),
          _buildGreyTextField(
            controller: _plateCtrl,
            hint: 'e.g. 1234, 7788 GB, or 123 ABC',
            isDark: isDark,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.regMake,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textColor(isDark),
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildGreyTextField(
                      controller: _makeCtrl,
                      hint: 'Honda / Kawasaki',
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.regModel,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textColor(isDark),
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildGreyTextField(
                      controller: _modelCtrl,
                      hint: 'TMX / Barako',
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            l10n.regColor,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.textColor(isDark),
            ),
          ),
          const SizedBox(height: 6),
          _buildGreyTextField(
            controller: _colorCtrl,
            hint: 'e.g. Blue, Metallic Blue, Black and Red',
            maxLength: 60,
            isDark: isDark,
          ),
        ],
      );

  // STEP 4: Documents Upload
  Widget _buildStep4Upload(AppLocalizations l10n, bool isDark) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${l10n.regStep4} & ${l10n.regStep5}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textColor(isDark),
            ),
          ),
          const SizedBox(height: 16),
          if (_vehicleType == VehicleType.tricycle)
            // TODA options are loaded from the Admin-managed Supabase table.
            NeumorphicCard(
              padding: const EdgeInsets.all(16),
              radius: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.regToda,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.textColor(isDark),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Refresh TODA list',
                        onPressed: _todasLoading ? null : _loadEligibleTodas,
                        icon: _todasLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _todasLoading
                        ? 'Loading active associations…'
                        : _todasLoadFailed
                            ? 'Unable to load TODAs. Tap refresh to retry.'
                            : !_todasLoaded
                                ? 'Refresh to load available associations.'
                                : _todaOptions.isEmpty
                                    ? 'No active TODAs are available. Contact the administrator.'
                                    : 'Select your association from the list below',
                    style: TextStyle(
                      fontSize: 12,
                      color: _todasLoadFailed ||
                              (_todasLoaded && _todaOptions.isEmpty)
                          ? AppColors.terracottaVibrant
                          : _todasLoaded
                              ? (isDark
                                  ? AppColors.emeraldVibrant
                                  : const Color(0xFF2D6A4F))
                              : AppColors.subtextColor(isDark),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedToda.isEmpty ? null : _selectedToda,
                    isExpanded: true,
                    dropdownColor: isDark
                        ? AppColors.darkCardElevated
                        : Colors.white,
                    style: TextStyle(
                      color: AppColors.textColor(isDark),
                      fontSize: 14,
                    ),
                    hint: Text(
                      _todasLoading
                          ? 'Loading associations…'
                          : _todasLoadFailed
                              ? 'Refresh to retry'
                              : _todasLoaded && _todaOptions.isEmpty
                                  ? 'No active TODAs'
                                  : 'Select your TODA',
                      style: TextStyle(
                        color: AppColors.subtextColor(isDark),
                        fontSize: 13,
                      ),
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.inputBgColor(isDark),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            BorderSide(color: AppColors.borderColor(isDark)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            BorderSide(color: AppColors.borderColor(isDark)),
                      ),
                    ),
                    items: _todaOptions
                        .map((toda) => DropdownMenuItem<String>(
                              value: toda['id'] as String?,
                              child: Text(
                                (toda['name'] as String?) ?? 'TODA',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: AppColors.textColor(isDark)),
                              ),
                            ))
                        .toList(),
                    onChanged: _todasLoading ||
                            _todasLoadFailed ||
                            _todaOptions.isEmpty
                        ? null
                        : (val) {
                            if (val != null) {
                              setState(() => _selectedToda = val);
                            }
                          },
                  ),
                ],
              ),
            ),
          if (_vehicleType == VehicleType.habal) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkCardElevated
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderColor(isDark)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 20,
                    color: isDark
                        ? AppColors.goldVibrant
                        : const Color(0xFF6E5600),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'TODA association is only required for tricycle drivers. Motorcycle (Habal-Habal) drivers do not require a TODA.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textColor(isDark),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Driver license and vehicle OR/CR uploads are optional. '
            'You can submit without these documents. An admin will review '
            'your application and decide whether to approve or reject it.',
            style:
                TextStyle(fontSize: 12, color: AppColors.subtextColor(isDark)),
          ),
          const SizedBox(height: 12),
          _buildDocUploadCard(
            l10n.regDocLicenseFront,
            _licensePhoto != null,
            l10n,
            () => _pickDocument(0),
            isDark,
          ),
          const SizedBox(height: 12),
          _buildDocUploadCard(
            l10n.regDocOrCr,
            _orCrPhoto != null,
            l10n,
            () => _pickDocument(1),
            isDark,
          ),
          const SizedBox(height: 12),
          _buildDocUploadCard(
            '${l10n.regDocProfile} (Required)',
            _profilePhoto != null,
            l10n,
            () => _pickDocument(2),
            isDark,
          ),
        ],
      );

  Widget _buildDocUploadCard(
    String title,
    bool isUploaded,
    AppLocalizations l10n,
    VoidCallback onTap,
    bool isDark,
  ) {
    final uploadColor = isUploaded
        ? (isDark ? AppColors.emeraldVibrant : const Color(0xFF2D6A4F))
        : NeumorphicColors.brandPrimary;
    return NeumorphicCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      radius: 14,
      border: isUploaded
          ? Border.all(
              color: uploadColor.withValues(alpha: 0.4),
              width: 1.5,
            )
          : null,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: uploadColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isUploaded
                  ? Icons.check_circle_rounded
                  : Icons.cloud_upload_outlined,
              color: uploadColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.textColor(isDark),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isUploaded ? l10n.regUploaded : l10n.regUploadTap,
                  style: TextStyle(
                    fontSize: 12,
                    color: isUploaded
                        ? uploadColor
                        : AppColors.subtextColor(isDark),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              foregroundColor:
                  isDark ? AppColors.goldVibrant : const Color(0xFF6E5600),
            ),
            child: Text(isUploaded ? 'Change' : 'Upload'),
          ),
        ],
      ),
    );
  }

  Widget _buildGreyTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    int? maxLength,
    bool obscureText = false,
    Widget? suffixIcon,
    required bool isDark,
  }) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: NeumorphicDecorations.inset(
        isDark: isDark,
        radius: 12,
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        maxLength: maxLength,
        obscureText: obscureText,
        style: TextStyle(fontSize: 14, color: AppColors.textColor(isDark)),
        decoration: InputDecoration(
          isDense: true,
          filled: false,
          fillColor: Colors.transparent,
          hintText: hint,
          counterText: maxLength == null ? null : '',
          suffixIcon: suffixIcon,
          suffixIconConstraints:
              const BoxConstraints(minWidth: 40, minHeight: 40),
          hintStyle: TextStyle(
            color: AppColors.subtextColor(isDark),
            fontSize: 14,
          ),
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
    );
  }

  Widget _buildVehicleSelectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final activeColor =
        isDark ? AppColors.terracottaVibrant : const Color(0xFFE65100);
    return NeumorphicCard(
      onTap: onTap,
      radius: 14,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      border: isSelected
          ? Border.all(color: activeColor, width: 2.0)
          : null,
      color: isSelected
          ? (isDark
              ? activeColor.withValues(alpha: 0.15)
              : activeColor.withValues(alpha: 0.08))
          : null,
      child: Column(
        children: [
          Icon(
            icon,
            size: 28,
            color: isSelected ? activeColor : AppColors.subtextColor(isDark),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: isSelected ? activeColor : AppColors.textColor(isDark),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.subtextColor(isDark),
            ),
          ),
        ],
      ),
    );
  }
}
