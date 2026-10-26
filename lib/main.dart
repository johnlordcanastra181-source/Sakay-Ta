import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/supabase_config.dart';
import 'core/constants.dart';
import 'core/logger.dart';
import 'core/philippine_time.dart';

import 'models/app_user.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';

import 'services/supabase_service.dart';
import 'services/prefs_service.dart';
import 'state/app_state.dart';
import 'pages/login_page.dart' as login;
import 'pages/passenger_home.dart' as passenger_home;
import 'pages/passenger_profile.dart' as passenger_profile;
import 'pages/ride_tracking.dart' as ride_tracking;
import 'pages/my_rides.dart' as my_rides;
import 'pages/driver_registration.dart' as driver_reg;
import 'pages/driver_pending_approval.dart' as driver_pending;
import 'pages/driver_activation_page.dart' as driver_activation;
import 'pages/driver_home.dart' as driver_home;
import 'pages/wallet_page.dart' as wallet;
import 'pages/performance_page.dart' as performance;
import 'pages/heading_home.dart' as heading;
import 'pages/admin_dashboard.dart' as admin_dashboard;
import 'pages/passenger_signup.dart' as passenger_signup;
import 'services/deep_link_service.dart';
import 'services/password_change_service.dart';
import 'services/password_recovery_service.dart';
import 'l10n/app_localizations.dart';
import 'core/theme.dart';
import 'widgets/sakay_ta_splash_screen.dart';
import 'admin_main.dart' as admin;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PhilippineTime.initialize();
  debugPrint('[SakayTa][Platform] kIsWeb=$kIsWeb');

  // Silence all verbose logging in release mode to eliminate Android logcat IPC stalls.
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  // Cap decoded bitmap image cache to 30 MB / 100 images so low-RAM (1-2 GB)
  // devices never suffer GC thrashing or Android LMK background kills.
  PaintingBinding.instance.imageCache.maximumSize = 100;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 30 * 1024 * 1024;

  // Top-level error safety to log uncaught errors and prevent raw crash screens
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('[SakayTa][FlutterError] ${details.exceptionAsString()}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[SakayTa][PlatformDispatcher] unhandled async error: $error');
    return true;
  };
  ErrorWidget.builder = (FlutterErrorDetails details) {
    debugPrint('[SakayTa][ErrorWidget] ${details.exceptionAsString()}');
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Unable to display this section right now.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  };

  try {
    await PrefsService.initialize().timeout(const Duration(milliseconds: 600));
  } catch (e) {
    debugPrint('SharedPreferences initialization warning: $e');
  }

  if (kIsWeb) {
    debugPrint('[SakayTa][Router] Initial route=/admin/login');
    await admin.runAdminApp();
    return;
  }

  debugPrint('[SakayTa][Router] Initial route=/login');

  try {
    await SupabaseConfig.initialize().timeout(const Duration(milliseconds: 800));
    await SupabaseService.instance.init().timeout(const Duration(milliseconds: 800));
  } catch (e) {
    debugPrint('[SakayTa][Supabase] initialization disabled: $e');
  }

  unawaited(
      DeepLinkService.instance.init().catchError((Object e, StackTrace s) {
    AppLogger.warn('DeepLinkService.init error: $e', error: e, stackTrace: s);
  }));

  runApp(
    MultiProvider(
      providers: [
        Provider<DatabaseService>(create: (_) => DatabaseService.instance),
        Provider<SupabaseService>(create: (_) => SupabaseService.instance),
        Provider<PrefsService>(create: (_) => PrefsService.instance),
        ChangeNotifierProvider<AppState>(
          create: (_) => AppState.instance..init(),
        ),
        ChangeNotifierProvider<LocaleProvider>(
          create: (context) => LocaleProvider(context.read<PrefsService>()),
        ),
        ProxyProvider<LocaleProvider, AuthService>(
          update: (context, localeProvider, auth) => AuthService(
            DatabaseService.instance,
            context.read<PrefsService>(),
          ),
        ),
      ],
      child: const SakayTaApp(),
    ),
  );
}

class LocaleProvider extends ChangeNotifier {
  final PrefsService prefs;
  Locale _locale = const Locale('en');

  Locale get locale => _locale;

  LocaleProvider(this.prefs) {
    _init();
  }

  static String _normalize(String? code) {
    if (code == null || code.isEmpty) return 'en';
    final lower = code.toLowerCase().trim();
    if (lower.startsWith('ceb') || lower.startsWith('bis')) return 'ceb';
    if (lower.startsWith('tl') || lower.startsWith('fil')) return 'tl';
    return 'en';
  }

  Future<void> _init() async {
    final langCode = await prefs.locale;
    final normalized = _normalize(langCode);
    _locale = Locale(normalized);
    AppState.instance.locale = _locale;
    notifyListeners();
  }

  Future<void> setLocale(String langCode) async {
    final normalized = _normalize(langCode);
    await prefs.setLocale(normalized);
    _locale = Locale(normalized);
    AppState.instance.locale = _locale;
    notifyListeners();
  }
}

enum AppScreen {
  login,
  passengerRegistration,
  magicLinkVerification,
  passengerHome,
  profile,
  tracking,
  rides,
  driverRegistration,
  driverPendingApproval,
  driverActivation,
  driverHome,
  wallet,
  performance,
  headingHome,
  adminDashboard,
}

@visibleForTesting
AppScreen homeScreenFor(AppUser user) {
  if (user.isAdmin) return AppScreen.adminDashboard;
  if (user.isDriver && user.status == AccountStatus.pending) {
    return AppScreen.driverPendingApproval;
  }
  if (user.isDriver) return AppScreen.driverHome;
  return AppScreen.passengerHome;
}

/// Keeps role-exclusive screens out of the wrong authenticated shell.
@visibleForTesting
AppScreen guardAppScreen(AppScreen requested, AppUser? user) {
  if (requested == AppScreen.adminDashboard &&
      (user == null || !user.isAdmin)) {
    return user != null ? homeScreenFor(user) : AppScreen.login;
  }
  if (user?.isDriver == true &&
      (requested == AppScreen.passengerHome ||
          requested == AppScreen.rides ||
          requested == AppScreen.tracking)) {
    return AppScreen.driverHome;
  }
  return requested;
}

class FallbackMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const FallbackMaterialLocalizationsDelegate();
  @override
  bool isSupported(Locale locale) => true;
  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      DefaultMaterialLocalizations.load(locale);
  @override
  bool shouldReload(FallbackMaterialLocalizationsDelegate old) => false;
}

class FallbackCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const FallbackCupertinoLocalizationsDelegate();
  @override
  bool isSupported(Locale locale) => true;
  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      DefaultCupertinoLocalizations.load(locale);
  @override
  bool shouldReload(FallbackCupertinoLocalizationsDelegate old) => false;
}

class SakayTaApp extends StatelessWidget {
  const SakayTaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<LocaleProvider, AppState>(
      builder: (context, localeProvider, app, _) {
        final locale = localeProvider.locale;
        final darkMode = app.darkMode;

        return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sakay Ta',
      locale: locale,
      supportedLocales: const [
        Locale('en'),
        Locale('ceb'),
        Locale('tl'),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        FallbackMaterialLocalizationsDelegate(),
        FallbackCupertinoLocalizationsDelegate(),
      ],
      localeListResolutionCallback: (locales, supportedLocales) {
        if (locales != null) {
          for (final locale in locales) {
            for (final supported in supportedLocales) {
              if (locale.languageCode == supported.languageCode) {
                return locale;
              }
            }
          }
        }
        return const Locale('en');
      },
      theme: SakayTheme.light(),
      darkTheme: SakayTheme.dark(),
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
      themeAnimationDuration: const Duration(milliseconds: 250),
      themeAnimationCurve: Curves.easeInOut,
      home: const _HomeNavigator(),
    );
      },
    );
  }
}

class _HomeNavigator extends StatefulWidget {
  const _HomeNavigator();

  @override
  State<_HomeNavigator> createState() => _HomeNavigatorState();
}

class _HomeNavigatorState extends State<_HomeNavigator> {
  AppScreen screen = AppScreen.login;
  bool _showSplash = true;
  StreamSubscription<AuthState>? _authSubscription;
  void go(AppScreen value) => setState(() => screen = value);

  void _ensureAuthSubscription() {
    if (_authSubscription != null || !SupabaseConfig.isInitialized) return;
    final auth = Supabase.instance.client.auth;
    void routeInvite(User? user) {
      if (AppState.instance.currentUser != null ||
          PasswordChangeService.isFlowActive ||
          PasswordRecoveryService.isFlowActive) {
        return;
      }
      final metadata = user?.userMetadata;
      final applicationId = metadata?['driver_application_id'];
      if (applicationId != null &&
          metadata?['driver_account_activated'] != true &&
          mounted) {
        setState(() => screen = AppScreen.driverActivation);
      }
    }

    routeInvite(auth.currentUser);
    _authSubscription = auth.onAuthStateChange.listen((state) {
      routeInvite(state.session?.user);
    });
  }

  @override
  void initState() {
    super.initState();

    _ensureAuthSubscription();

    // Restore an existing session: once AppState has finished initializing,
    // jump straight to the role-appropriate home screen instead of the login
    // page (no-op when there is no saved session).
    final app = AppState.instance;
    void maybeRestore() {
      _ensureAuthSubscription();
      if (app.initializing) return;
      if (app.currentUser == null) {
        if (screen != AppScreen.driverActivation &&
            app.pendingDriverApplicationId != null) {
          app.removeListener(maybeRestore);
          if (mounted) go(AppScreen.driverPendingApproval);
        }
        return;
      }
      app.removeListener(maybeRestore);
      if (!mounted) return;
      go(homeScreenFor(app.currentUser!));
    }

    if (app.initializing) {
      app.addListener(maybeRestore);
    } else {
      maybeRestore();
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  /// Strict Route Guard: prevents unauthorized access to protected admin pages
  AppScreen _guardScreen(AppScreen requested, AppUser? user) {
    final guarded = guardAppScreen(requested, user);
    if (guarded != requested) {
      debugPrint('[SakayTa][Router] blocked screen=$requested '
          'for role=${user?.role ?? 'anonymous'}; rendered=$guarded');
    }
    return guarded;
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return SakayTaSplashScreen(
        onFinished: () {
          if (mounted) {
            setState(() => _showSplash = false);
          }
        },
      );
    }

    return Selector<AppState, AppUser?>(
      selector: (_, app) => app.currentUser,
      builder: (context, currentUser, _) {
        final targetScreen = _guardScreen(screen, currentUser);

        return switch (targetScreen) {
      AppScreen.login => login.LoginPage(onNavigate: go),
      AppScreen.passengerRegistration =>
        passenger_signup.PassengerSignupPage(onNavigate: go),
      AppScreen.magicLinkVerification =>
        passenger_signup.PassengerSignupPage(onNavigate: go),
      AppScreen.passengerHome => passenger_home.PassengerHome(onNavigate: go),
      AppScreen.profile => passenger_profile.PassengerProfile(onNavigate: go),
      AppScreen.tracking => ride_tracking.RideTracking(onNavigate: go),
      AppScreen.rides => my_rides.MyRides(onNavigate: go),
      AppScreen.driverRegistration =>
        driver_reg.DriverRegistration(onNavigate: go),
      AppScreen.driverPendingApproval =>
        driver_pending.DriverPendingApproval(onNavigate: go),
      AppScreen.driverActivation =>
          driver_activation.DriverActivationPage(onNavigate: go),
      AppScreen.driverHome => driver_home.DriverHome(onNavigate: go),
      AppScreen.wallet => wallet.WalletPage(onNavigate: go),
      AppScreen.performance => performance.PerformancePage(onNavigate: go),
      AppScreen.headingHome => heading.HeadingHome(onNavigate: go),
      AppScreen.adminDashboard =>
        admin_dashboard.AdminDashboard(onNavigate: go),
    };
      },
    );
  }
}

class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.child,
    this.bottom,
    this.background,
  });
  final Widget child;
  final Widget? bottom;
  final Color? background;
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor:
            background ?? Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(child: child),
        bottomNavigationBar: bottom,
      );
}

class Brand extends StatelessWidget {
  const Brand({super.key, this.dark, this.size = 32});
  final bool? dark;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isDark = dark ?? (Theme.of(context).brightness == Brightness.dark);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF26334D) : const Color(0xFF1E2B45),
            shape: BoxShape.circle,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                bottom: size * 0.08,
                child: Icon(
                  Icons.location_on_rounded,
                  size: size * 0.72,
                  color: isDark
                      ? const Color(0xFF1E2B45)
                      : const Color(0xFF142036),
                ),
              ),
              Icon(
                Icons.electric_rickshaw_rounded,
                size: size * 0.58,
                color: const Color(0xFFFFD600),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Sakay Ta',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: size * 0.55,
            color: isDark ? Colors.white : const Color(0xFF1E1E1E),
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}

class AppTop extends StatelessWidget {
  const AppTop({super.key, required this.title, this.back, this.action});
  final String title;
  final VoidCallback? back;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
      child: Row(
        children: [
          if (back != null)
            IconButton(
              onPressed: back,
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: isDark ? Colors.white : const Color(0xFF1E1E1E)),
            ),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF1E1E1E),
              ),
            ),
          ),
          action ?? const Avatar(),
        ],
      ),
    );
  }
}

class Avatar extends StatelessWidget {
  const Avatar({super.key, this.size = 34});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.green.withValues(alpha: .16),
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Icon(Icons.person_rounded,
            size: size * .65, color: AppColors.green),
      );
}
