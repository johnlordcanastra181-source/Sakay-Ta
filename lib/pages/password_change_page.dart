import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/password_change_service.dart';

Future<void> showPasswordChangeDialog(BuildContext context) async {
  await Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const PasswordChangePage()),
  );
}

class PasswordChangePage extends StatefulWidget {
  const PasswordChangePage({super.key});

  @override
  State<PasswordChangePage> createState() => _PasswordChangePageState();
}

class _PasswordChangePageState extends State<PasswordChangePage> {
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  Timer? _cooldownTimer;
  int _cooldown = 0;
  bool _requested = false;
  bool _busy = false;
  String? _error;
  String? _info;

  String get _email => PasswordChangeService.currentUserEmail;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    if (_busy || _cooldown > 0) return;
    final previousCode = _codeController.text;
    _codeController.clear();
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await PasswordChangeService.requestOtp(previousCode: previousCode);
      if (!mounted) return;
      setState(() {
        _requested = true;
        _info = 'A verification code was sent to $_email.';
      });
      _startCooldown();
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldown = 30);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldown <= 1) {
        timer.cancel();
        setState(() => _cooldown = 0);
      } else {
        setState(() => _cooldown--);
      }
    });
  }

  Future<void> _update() async {
    if (_busy) return;
    final code = _codeController.text.trim();
    final password = _passwordController.text;
    final confirmation = _confirmController.text;
    if (!_requested) {
      setState(() => _error = 'Request a verification code first.');
      return;
    }
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _error = 'Enter the 6-digit verification code.');
      return;
    }
    if (password.length < 6) {
      setState(
          () => _error = 'Use at least 6 characters for your new password.');
      return;
    }
    if (password != confirmation) {
      setState(() => _error = 'New passwords do not match.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await PasswordChangeService.verifyAndUpdate(
        email: _email,
        code: code,
        newPassword: password,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      Navigator.of(context).pop(true);
      messenger?.showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF059669),
          content: Text('Password updated successfully.'),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _message(Object error) =>
      PasswordChangeService.formatErrorMessage(error);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change Password')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Verify your account before changing the password.',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text('A 6-digit code will be sent to $_email.'),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Text(_error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                      ],
                      if (_info != null) ...[
                        const SizedBox(height: 16),
                        Text(_info!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.primary)),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _busy || _cooldown > 0 ? null : _requestCode,
                        child: _busy && !_requested
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(_cooldown > 0
                                ? 'Resend in ${_cooldown}s'
                                : _requested
                                    ? 'Resend Verification Code'
                                    : 'Send Verification Code'),
                      ),
                      if (_requested) ...[
                        const SizedBox(height: 20),
                        TextField(
                          controller: _codeController,
                          enabled: !_busy,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          maxLength: 6,
                          decoration: const InputDecoration(
                            labelText: 'Verification Code',
                            prefixIcon: Icon(Icons.numbers),
                            counterText: '',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passwordController,
                          enabled: !_busy,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'New Password',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _confirmController,
                          enabled: !_busy,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Confirm New Password',
                            prefixIcon: Icon(Icons.check_circle_outline),
                          ),
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _busy ? null : _update,
                          child: _busy
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Update Password'),
                        ),
                      ],
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _busy ? null : () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
