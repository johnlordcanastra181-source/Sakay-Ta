import 'dart:async';
import 'package:flutter/material.dart';
import '../services/password_recovery_service.dart';

Future<void> showPasswordRecoveryDialog(
  BuildContext context, {
  String initialEmail = '',
}) async {
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => PasswordRecoveryEmailScreen(initialEmail: initialEmail),
    ),
  );
}

class PasswordRecoveryEmailScreen extends StatefulWidget {
  final String initialEmail;
  const PasswordRecoveryEmailScreen({super.key, this.initialEmail = ''});

  @override
  State<PasswordRecoveryEmailScreen> createState() =>
      _PasswordRecoveryEmailScreenState();
}

class _PasswordRecoveryEmailScreenState
    extends State<PasswordRecoveryEmailScreen> {
  late final TextEditingController _emailController;
  bool _sending = false;
  String? _error;
  bool _sent = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail.trim());
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await PasswordRecoveryService.sendRecoveryEmail(_emailController.text);
      if (mounted) setState(() => _sent = true);
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _message(Object error) {
    final value = error.toString().replaceFirst('Exception: ', '');
    return value.replaceFirst('StateError: ', '');
  }

  void _goToVerification() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PasswordRecoveryVerificationScreen(
          email: _emailController.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset password'),
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: _sent
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Check your email',
                              style: TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'If an account exists for this email, a verification code has been sent.',
                            ),
                            const SizedBox(height: 24),
                            FilledButton(
                              onPressed: _goToVerification,
                              child: const Text('Enter Verification Code'),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Enter the email address registered to your Sakay Ta account.',
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              autofocus: true,
                              autocorrect: false,
                              enabled: !_sending,
                              decoration: const InputDecoration(
                                labelText: 'Email address',
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                              onSubmitted: (_) => _send(),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                _error!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            FilledButton(
                              onPressed: _sending ? null : _send,
                              child: _sending
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Text('Send Verification Code'),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _sending
                                  ? null
                                  : () => Navigator.pop(context),
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

class PasswordRecoveryVerificationScreen extends StatefulWidget {
  final String email;
  const PasswordRecoveryVerificationScreen({super.key, required this.email});

  @override
  State<PasswordRecoveryVerificationScreen> createState() =>
      _PasswordRecoveryVerificationScreenState();
}

class _PasswordRecoveryVerificationScreenState
    extends State<PasswordRecoveryVerificationScreen> {
  final _codeController = TextEditingController();
  bool _verifying = false;
  bool _resending = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_verifying) return;
    setState(() {
      _verifying = true;
      _error = null;
      _info = null;
    });
    try {
      await PasswordRecoveryService.verifyRecoveryOtp(
          widget.email, _codeController.text);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const PasswordRecoveryNewPasswordScreen(),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() =>
            _error = error.toString().replaceFirst('StateError: ', '').replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    if (_resending) return;
    setState(() {
      _resending = true;
      _error = null;
      _info = null;
    });
    try {
      await PasswordRecoveryService.sendRecoveryEmail(widget.email);
      if (mounted) {
        setState(() {
          _info = 'A new code has been sent.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() =>
            _error = error.toString().replaceFirst('StateError: ', '').replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Code'),
        elevation: 0,
      ),
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
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Enter the verification code sent to .',
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        enabled: !_verifying,
                        decoration: const InputDecoration(
                          labelText: 'Verification Code',
                          prefixIcon: Icon(Icons.numbers),
                        ),
                        onSubmitted: (_) => _verify(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      if (_info != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _info!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _verifying ? null : _verify,
                        child: _verifying
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Verify Code'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _resending || _verifying ? null : _resend,
                        child: _resending
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Resend Code'),
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

class PasswordRecoveryNewPasswordScreen extends StatefulWidget {
  const PasswordRecoveryNewPasswordScreen({super.key});

  @override
  State<PasswordRecoveryNewPasswordScreen> createState() =>
      _PasswordRecoveryNewPasswordScreenState();
}

class _PasswordRecoveryNewPasswordScreenState
    extends State<PasswordRecoveryNewPasswordScreen> {
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _saving = false;
  bool _showPassword = false;
  String? _error;
  bool _complete = false;

  @override
  void dispose() {
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_password.text != _confirmPassword.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await PasswordRecoveryService.updatePassword(_password.text);
      if (mounted) setState(() => _complete = true);
    } catch (error) {
      if (mounted) {
        setState(() =>
            _error = error.toString().replaceFirst('StateError: ', '').replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasSession = PasswordRecoveryService.hasRecoverySession;
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Password'),
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: _complete
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Icon(Icons.check_circle_outline,
                                color: Colors.green, size: 48),
                            const SizedBox(height: 16),
                            const Text('Password changed successfully.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 22, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            const Text(
                              'Sign in with your new password.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            FilledButton(
                              onPressed: () {
                                // Pop all the way back to login
                                Navigator.popUntil(context, (route) => route.isFirst);
                              },
                              child: const Text('Return to sign in'),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('Choose a new password',
                                style: TextStyle(
                                    fontSize: 22, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text(
                              hasSession
                                  ? 'Use at least 6 characters.'
                                  : 'This recovery session is invalid or expired. Request a new code.',
                            ),
                            const SizedBox(height: 20),
                            TextField(
                              controller: _password,
                              enabled: hasSession && !_saving,
                              obscureText: !_showPassword,
                              decoration: InputDecoration(
                                labelText: 'New password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(_showPassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined),
                                  onPressed: () => setState(
                                      () => _showPassword = !_showPassword),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _confirmPassword,
                              enabled: hasSession && !_saving,
                              obscureText: !_showPassword,
                              decoration: const InputDecoration(
                                labelText: 'Confirm new password',
                                prefixIcon: Icon(Icons.lock_outline),
                              ),
                              onSubmitted: (_) => _save(),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              Text(_error!,
                                  style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.error)),
                            ],
                            const SizedBox(height: 20),
                            FilledButton(
                              onPressed: hasSession && !_saving ? _save : null,
                              child: _saving
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Text('Update Password'),
                            ),
                            TextButton(
                              onPressed: _saving ? null : () => Navigator.pop(context),
                              child: const Text('Back'),
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
