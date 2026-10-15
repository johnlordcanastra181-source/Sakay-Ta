import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/supabase_config.dart';

import 'pages/admin/admin_shell.dart';
import 'pages/admin/admin_theme.dart';
import 'pages/admin/views/admin_login_view.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';

import 'services/supabase_service.dart';
import 'services/prefs_service.dart';
import 'state/app_state.dart';

/// Standalone Dedicated Flutter Web Entry Point for the Sakay Ta Admin Portal.
/// Run on web: `flutter run -t lib/admin_main.dart -d chrome`
/// Build for web: `flutter build web -t lib/admin_main.dart --release`
Future<void> main() => runAdminApp();

/// Starts the existing admin bootstrap. The default entry point delegates to
/// this function on web so both web launch modes use the same auth guard.
Future<void> runAdminApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('[SakayTa][Platform] kIsWeb=true');

  // Initialize SharedPreferences BEFORE anything else so the platform channel
  // is registered when AppState.init() fires its prefs reads.
  try {
    await PrefsService.initialize();
  } catch (e) {
    debugPrint('Admin Web: SharedPreferences initialization: $e');
  }

  // Initialize Supabase first so cloud access is enabled only after the SDK is
  // ready. If client configuration is absent, the app stays in local mode.
  var supabaseReady = false;
  Object? supabaseInitializationError;
  try {
    await SupabaseConfig.initialize();
    await SupabaseService.instance.init();
    supabaseReady = SupabaseConfig.isInitialized;
  } catch (e) {
    supabaseInitializationError = e;
    debugPrint('[SakayTa][Supabase] admin initialization failed: $e');
  }

  final appState = AppState.instance;
  await appState.init();

  runApp(
    MultiProvider(
      providers: [
        Provider<DatabaseService>(create: (_) => DatabaseService.instance),
        Provider<SupabaseService>(create: (_) => SupabaseService.instance),
        Provider<PrefsService>(create: (_) => PrefsService.instance),
        // AppState is already initialised – just expose it.
        ChangeNotifierProvider<AppState>.value(value: appState),
        ProxyProvider<PrefsService, AuthService>(
          update: (_, prefs, __) =>
              AuthService(DatabaseService.instance, prefs),
        ),
      ],
      child: SakayTaAdminWebApp(
        supabaseReady: supabaseReady,
        initializationError: supabaseInitializationError,
      ),
    ),
  );
}

class SakayTaAdminWebApp extends StatelessWidget {
  const SakayTaAdminWebApp({
    super.key,
    required this.supabaseReady,
    this.initializationError,
  });

  final bool supabaseReady;
  final Object? initializationError;

  @override
  Widget build(BuildContext context) {
    if (!supabaseReady) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: const Scaffold(
          backgroundColor: AdminTheme.bgPrimary,
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'The Admin Portal could not connect to Supabase. '
                'Check the deployed configuration and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sakay Ta - Admin Portal',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AdminTheme.bgPrimary,
        fontFamily: 'Inter',
        colorScheme: const ColorScheme.dark(
          primary: AdminTheme.terracotta,
          secondary: AdminTheme.gold,
          surface: AdminTheme.bgSecondary,
        ),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: const _AdminWebAuthRouter(),
    );
  }
}

class _AdminWebAuthRouter extends StatefulWidget {
  const _AdminWebAuthRouter();

  @override
  State<_AdminWebAuthRouter> createState() => _AdminWebAuthRouterState();
}

class _AdminWebAuthRouterState extends State<_AdminWebAuthRouter> {
  String? _authorizationUserId;
  String? _authorizationToken;
  Future<bool>? _authorization;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<bool> _authorizationFor(String userId, String accessToken) {
    if (_authorizationUserId != userId ||
        _authorizationToken != accessToken ||
        _authorization == null) {
      _authorizationUserId = userId;
      _authorizationToken = accessToken;
      _authorization =
          SupabaseService.instance.isCurrentAdminAuthorized(userId);
    }
    return _authorization!;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    debugPrint('[SakayTa][Auth] User authenticated=${app.currentUser != null}');

    // Wait for the bounded session-restoration steps to finish before routing.
    if (app.initializing) {
      return const Scaffold(
        backgroundColor: AdminTheme.bgPrimary,
        body: Center(
          child: CircularProgressIndicator(
            color: AdminTheme.terracotta,
            strokeWidth: 2.5,
          ),
        ),
      );
    }

    final user = app.currentUser;

    // Never authorize from an AppState/SQLite cache alone. A valid Supabase
    // Auth session and an active server-side admin_roles row are both required.
    final auth = Supabase.instance.client.auth;
    final authUser = auth.currentUser;
    final session = auth.currentSession;
    if (user != null && user.isAdmin && !user.isDeactivated) {
      if (session == null || authUser == null || authUser.id != user.id) {
        unawaited(app.logout());
        return AdminLoginView(onLoginSuccess: () => setState(() {}));
      }
      return FutureBuilder<bool>(
        future: _authorizationFor(user.id, session.accessToken),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              backgroundColor: AdminTheme.bgPrimary,
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.data == true) {
            debugPrint('[SakayTa][Admin] Supabase authorization=true');
            return AdminShell(onLogout: app.logout);
          }
          unawaited(app.logout());
          return AdminLoginView(onLoginSuccess: () => setState(() {}));
        },
      );
    }

    debugPrint('[SakayTa][Admin] Admin authorization=false');
    return AdminLoginView(
      onLoginSuccess: () {
        setState(() {});
      },
    );
  }
}
