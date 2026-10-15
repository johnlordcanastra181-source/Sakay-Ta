import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/logger.dart';
import '../models/app_user.dart';
import '../models/philippine_address.dart';
import '../services/auth_service.dart';
import 'app_state.dart';

// --- Events ---
abstract class AuthEvent {}

/// Submits the passenger signup form with primary Email address and optional PSGC address.
class SignUpPassengerSubmitted extends AuthEvent {
  final String fullName;
  final String email;
  final String? mobile;
  final String password;
  final String language;
  final PhilippineAddress? address;

  SignUpPassengerSubmitted({
    required this.fullName,
    required this.email,
    this.mobile,
    required this.password,
    required this.language,
    this.address,
  });
}

class ChangeLanguageEvent extends AuthEvent {
  final String languageCode;
  ChangeLanguageEvent(this.languageCode);
}

// --- States ---
abstract class AuthState {}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

/// Emitted after the authenticated passenger account and profile are created.
class AuthPassengerSignedUp extends AuthState {
  final AppUser user;
  AuthPassengerSignedUp(this.user);
}

class AuthSuccess extends AuthState {
  final AppUser user;
  AuthSuccess(this.user);
}

class AuthFailure extends AuthState {
  final String error;
  AuthFailure(this.error);
}

// --- BLoC ---
class AuthBloc extends ChangeNotifier {
  final AuthService authService;

  AuthState _state = AuthInitial();
  AuthState get state => _state;

  final _stateController = StreamController<AuthState>.broadcast();
  Stream<AuthState> get stream => _stateController.stream;

  AuthBloc({required this.authService});

  void _emit(AuthState newState) {
    _state = newState;
    _stateController.add(newState);
    notifyListeners();
  }

  Future<void> add(AuthEvent event) async {
    if (event is SignUpPassengerSubmitted) {
      await _onSignUpPassengerSubmitted(event);
    } else if (event is ChangeLanguageEvent) {
      await _onChangeLanguage(event);
    }
  }

  Future<void> _onSignUpPassengerSubmitted(
      SignUpPassengerSubmitted event) async {
    _emit(AuthLoading());
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('locale', event.language);

      final cleanEmail = event.email.trim().toLowerCase();
      final user = await authService.registerPassenger(
        fullName: event.fullName,
        email: cleanEmail,
        mobile: event.mobile ?? '',
        password: event.password,
        address: event.address,
      );
      if (user == null) {
        throw StateError('Passenger profile setup did not complete.');
      }
      AppState.instance.currentUser = user;
      AppLog.i('AuthBloc', '[SIGNUP] stage=complete uid=${user.id}');
      _emit(AuthPassengerSignedUp(user));
    } catch (e, st) {
      AppLog.e('AuthBloc', 'Passenger signup failed', e, st);
      final lower = e.toString().toLowerCase();
      final message = lower.contains('confirm email') ||
              lower.contains('no authenticated session')
          ? 'Supabase Email Confirm must be disabled for immediate registration.'
          : lower.contains('already registered') ||
                  lower.contains('already exists') ||
                  lower.contains('user_already_exists')
              ? 'This email address is already registered. Please log in instead.'
              : 'Unable to complete signup. Please try again.';
      _emit(AuthFailure(message));
    }
  }

  Future<void> _onChangeLanguage(ChangeLanguageEvent event) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale', event.languageCode);
  }

  @override
  void dispose() {
    _stateController.close();
    super.dispose();
  }
}
