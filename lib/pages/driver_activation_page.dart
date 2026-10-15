import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../main.dart' hide Brand, Avatar;
import '../services/password_recovery_service.dart';

class DriverActivationPage extends StatefulWidget {
  const DriverActivationPage({super.key, required this.onNavigate});

  final Function(AppScreen) onNavigate;

  @override
  State<DriverActivationPage> createState() => _DriverActivationPageState();
}

class _DriverActivationPageState extends State<DriverActivationPage> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    if (_saving) return;
    final password = _passwordController.text;
    if (password.length < 6) {
      setState(() => _error = 'Use a password with at least 6 characters.');
      return;
    }
    if (password != _confirmController.text) {
      setState(() => _error = 'The passwords do not match.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await PasswordRecoveryService.updatePassword(password);
      if (mounted) widget.onNavigate(AppScreen.login);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.toString().replaceFirst('Bad state: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final hasSession = PasswordRecoveryService.hasRecoverySession;
    return Scaffold(
      backgroundColor: AppColors.canvasColor(dark),
      appBar: AppBar(
        backgroundColor: AppColors.canvasColor(dark),
        title: const Text('Activate Driver Account'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.verified_user_outlined,
                      size: 60, color: AppColors.primary),
                  const SizedBox(height: 16),
                  Text(
                    hasSession
                        ? 'Set your password'
                        : 'Open the activation link again',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textColor(dark),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    hasSession
                        ? 'Your application has been approved. Create a password to activate your Driver account. You will start Offline.'
                        : 'This secure activation session is missing or expired. Open the latest invitation email on this device, or ask an administrator to resend it.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textColor(dark).withValues(alpha: 0.72),
                    ),
                  ),
                  if (hasSession) ...[
                    const SizedBox(height: 24),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: const InputDecoration(
                        labelText: 'New password',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirmController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirm password',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _activate(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: const TextStyle(color: Colors.redAccent)),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _saving ? null : _activate,
                      child: _saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Activate account'),
                    ),
                  ] else ...[
                    const SizedBox(height: 24),
                    OutlinedButton(
                      onPressed: () => widget.onNavigate(AppScreen.login),
                      child: const Text('Back to login'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
