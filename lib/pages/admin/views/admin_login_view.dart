import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants.dart';

import '../../../state/app_state.dart';
import '../../password_recovery_page.dart';
import '../admin_theme.dart';

/// Dedicated Flutter Web Admin Login Page.
class AdminLoginView extends StatefulWidget {
  const AdminLoginView({super.key, required this.onLoginSuccess});
  final VoidCallback onLoginSuccess;

  @override
  State<AdminLoginView> createState() => _AdminLoginViewState();
}

class _AdminLoginViewState extends State<AdminLoginView> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _isLoading = false;
  String? _errorMsg;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_isLoading) return;
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();

    if (email.isEmpty || pass.isEmpty) {
      setState(() => _errorMsg = 'Please enter both email and password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final app = context.read<AppState>();
      await app.login(
        mobile: email,
        password: pass,
        role: UserRole.admin,
      );

      if (mounted) {
        if (app.lastError != null) {
          setState(() {
            _isLoading = false;
            _errorMsg = _friendlyError(app.lastError!);
          });
        } else if (app.currentUser != null) {
          if (!app.currentUser!.isAdmin) {
            // Role guard: prevent passenger and driver accounts from logging into Admin Web Dashboard
            final accountRole = app.currentUser!.role.toUpperCase();
            await app.logout();
            if (!mounted) return;
            setState(() {
              _isLoading = false;
              _errorMsg =
                  'Access Denied: This account is registered as a $accountRole. Only authorized administrators can access the Web Admin Portal.';
            });
          } else {
            // Role was already verified against admin_roles inside app.login().
            // The router will independently re-verify the session via RPC before granting access.
            widget.onLoginSuccess();
          }
        } else {
          setState(() {
            _isLoading = false;
            _errorMsg =
                'Unable to sign in. Please verify your admin credentials.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMsg = 'Sign in error: $e';
        });
      }
    }
  }

  Future<void> _forgotPassword() => showPasswordRecoveryDialog(
        context,
        initialEmail: _emailCtrl.text,
      );

  String _friendlyError(String code) {
    if (code == 'wrong_password') {
      return 'Incorrect email or password. Please try again.';
    }
    if (code == 'wrong_role') {
      return 'Access Denied: This account does not have administrator privileges.';
    }
    if (code == 'no_user') {
      return 'No administrator account found with these credentials.';
    }
    if (code == 'account_deactivated') {
      return 'This administrator account has been deactivated.';
    }
    return code;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminTheme.bgPrimary,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Container(
              padding: const EdgeInsets.all(36),
              decoration: AdminTheme.cardDecoration(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Brand Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: AdminTheme.navy,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.electric_rickshaw_rounded,
                            color: AdminTheme.gold, size: 26),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sakay Ta',
                            style: TextStyle(
                              color: AdminTheme.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            'ADMIN WEB PORTAL',
                            style: TextStyle(
                              color: AdminTheme.terracotta,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  const Text(
                    'Administrator Sign In',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AdminTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Sign in with your authorized Supabase administrator account to access platform controls.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AdminTheme.textMuted, fontSize: 12, height: 1.4),
                  ),

                  const SizedBox(height: 24),

                  // Error Banner
                  if (_errorMsg != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AdminTheme.danger.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AdminTheme.danger.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: AdminTheme.dangerText, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_errorMsg!,
                                style: const TextStyle(
                                    color: AdminTheme.dangerText,
                                    fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Email
                  const Text('EMAIL ADDRESS',
                      style: TextStyle(
                          color: AdminTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(
                        color: AdminTheme.textPrimary, fontSize: 13),
                    decoration: AdminTheme.inputDecoration(
                      hintText: 'admin@sakayta.app',
                      prefixIcon: const Icon(Icons.email_outlined,
                          color: AdminTheme.slate, size: 18),
                    ),
                    onSubmitted: (_) => _handleLogin(),
                  ),

                  const SizedBox(height: 16),

                  // Password
                  const Text('PASSWORD',
                      style: TextStyle(
                          color: AdminTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _passCtrl,
                    obscureText: _obscurePass,
                    style: const TextStyle(
                        color: AdminTheme.textPrimary, fontSize: 13),
                    decoration: AdminTheme.inputDecoration(
                      hintText: '••••••••',
                      prefixIcon: const Icon(Icons.lock_outline_rounded,
                          color: AdminTheme.slate, size: 18),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePass
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AdminTheme.slate,
                          size: 18,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePass = !_obscurePass),
                      ),
                    ),
                    onSubmitted: (_) => _handleLogin(),
                  ),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isLoading ? null : _forgotPassword,
                      child: const Text('Forgot password?'),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Sign In Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminTheme.terracotta,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Sign In to Admin Dashboard',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.bold)),
                  ),

                  const SizedBox(height: 20),

                  const Center(
                    child: Text(
                      'Secured by Supabase Authentication and Row Level Security',
                      style:
                          TextStyle(color: AdminTheme.textMuted, fontSize: 11),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AdminTheme.bgInput,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AdminTheme.borderLight),
                    ),
                    child: const Text(
                      '🔒 Developer-Provisioned Portal: Public self-registration is disabled. Admin accounts are provisioned directly by the platform developer/owner.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AdminTheme.textMuted,
                          fontSize: 10,
                          height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
