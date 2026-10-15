import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/logger.dart';
import '../core/theme.dart';
import '../main.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/deep_link_service.dart';
import '../services/magic_link_service.dart';
import '../widgets/common.dart';

/// "Check your WhatsApp" screen shown after a Magic Link is generated.
///
/// The page launches WhatsApp (via a free `wa.me` URL with the Magic Link
/// pre-filled) so the user can tap the link. When the app is re-opened by the
/// deep link, [DeepLinkService] forwards the token here and verification is
/// automatic. Users can also paste a link received through delivery.
class MagicLinkVerificationPage extends StatefulWidget {
  const MagicLinkVerificationPage({
    super.key,
    required this.onNavigate,
    required this.fullName,
    required this.mobile,
    required this.password,
    required this.deepLink,
    required this.waMeUrl,
    required this.token,
  });

  final Function(AppScreen) onNavigate;
  final String fullName;
  final String mobile;
  final String password;
  final String deepLink;
  final String waMeUrl;
  final String token;

  @override
  State<MagicLinkVerificationPage> createState() =>
      _MagicLinkVerificationPageState();
}

class _MagicLinkVerificationPageState extends State<MagicLinkVerificationPage> {
  bool _isVerifying = false;
  bool _isResending = false;
  bool _isLaunching = false;
  bool _showManualEntry = false;

  String? _errorMessage;
  String? _infoMessage;

  int _resendTimer = 30;
  Timer? _timer;
  StreamSubscription<Uri>? _linkSub;

  final _manualTokenController = TextEditingController();

  /// Holds the latest Magic Link values (updated on resend).
  late String _deepLink = widget.deepLink;
  late String _waMeUrl = widget.waMeUrl;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    _listenForDeepLinks();
    _handlePendingLink();
    _openWhatsApp();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _linkSub?.cancel();
    _manualTokenController.dispose();
    super.dispose();
  }

  void _listenForDeepLinks() {
    _linkSub = DeepLinkService.instance.links.listen((uri) {
      final token = MagicLinkService.tokenFromLink(uri);
      if (token == null) {
        AppLog.w('MagicLinkPage', 'Ignored non-auth link: $uri');
        return;
      }
      AppLog.i('MagicLinkPage', 'Auth deep link intercepted: $uri');
      _verifyToken(token);
    });
  }

  void _handlePendingLink() {
    final initial = DeepLinkService.instance.takeInitialAuthLink();
    if (initial != null) {
      final token = MagicLinkService.tokenFromLink(initial);
      if (token != null) _verifyToken(token);
    }
  }

  void _startResendTimer() {
    _resendTimer = 30;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendTimer > 0) {
        setState(() => _resendTimer--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _openWhatsApp() async {
    if (_isLaunching) return;
    setState(() {
      _isLaunching = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    final uri = Uri.parse(_waMeUrl);
    AppLog.i('MagicLinkPage', 'Opening WhatsApp with wa.me URL: $uri');

    try {
      // Safety timeout: if the platform never answers canLaunch/launch (e.g.
      // an unresponsive intent resolver), never leave the user stuck on a
      // spinner - fall back to the copyable link dialog instead.
      final canOpen =
          await canLaunchUrl(uri).timeout(const Duration(seconds: 8));
      if (!canOpen) {
        AppLog.w('MagicLinkPage', 'No app can open $uri');
        if (mounted) _showCopyLinkDialog();
        return;
      }
      await launchUrl(uri, mode: LaunchMode.externalApplication)
          .timeout(const Duration(seconds: 8));
    } on TimeoutException {
      AppLog.w('MagicLinkPage',
          'Timed out launching WhatsApp - offering copy fallback');
      if (mounted) _showCopyLinkDialog();
    } catch (e) {
      AppLog.e('MagicLinkPage', 'Failed to launch WhatsApp', e);
      if (mounted) _showCopyLinkDialog();
    } finally {
      if (mounted) setState(() => _isLaunching = false);
    }
  }

  void _showCopyLinkDialog() {
    AppLog.w('MagicLinkPage', 'WhatsApp unavailable - offering copy fallback');
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('WhatsApp not found'),
        content: const Text(
            'We could not open WhatsApp automatically. Copy the Magic Link '
            'below and paste it into WhatsApp, Viber, or any messaging app, '
            'then tap the link.'),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _deepLink));
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Magic Link copied. Paste it into WhatsApp!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Copy Link'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _verifyToken(String token) async {
    if (_isVerifying) return;
    setState(() {
      _isVerifying = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    AppLog.i('MagicLinkPage', 'Verifying token (length=${token.length})');
    try {
      final service = MagicLinkService.database(DatabaseService.instance);
      final result = await service.verifyToken(token);
      if (!mounted) return;

      if (result.status == MagicLinkVerificationStatus.verified) {
        final user = await context.read<AuthService>().registerPassenger(
              fullName: widget.fullName,
              mobile: widget.mobile,
              password: widget.password,
            );
        if (!mounted) return;
        if (user != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Account created successfully! Welcome to Sakay Ta.'),
              backgroundColor: AppColors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.of(context).popUntil((route) => route.isFirst);
          widget.onNavigate(AppScreen.passengerHome);
        } else {
          setState(() => _errorMessage = 'Failed to create user account.');
        }
      } else if (result.status == MagicLinkVerificationStatus.expired) {
        setState(() {
          _errorMessage =
              'This Magic Link has expired. Tap Request New Link to send a fresh one.';
        });
      } else if (result.status == MagicLinkVerificationStatus.alreadyUsed) {
        setState(
            () => _errorMessage = 'This Magic Link has already been used.');
      } else {
        setState(() => _errorMessage =
            'Invalid verification link. Please request a new link.');
      }
    } catch (e) {
      AppLog.e('MagicLinkPage', 'Verification failed: $e');
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  /// Extracts the verification token from whatever the user pasted: the raw
  /// `sakayta://` deep link, a `wa.me` URL carrying the link in `?text=`, or
  /// a bare token. Returns null when nothing usable was found.
  String? _extractTokenFromPastedText(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    Uri uri;
    try {
      uri = Uri.parse(trimmed);
    } catch (_) {
      // Not parseable as a URI at all - treat it as a bare token.
      return trimmed;
    }

    // Direct deep link: sakayta://auth/verify?token=...
    final direct = MagicLinkService.tokenFromLink(uri);
    if (direct != null) return direct;

    // wa.me URL with the link URL-encoded inside ?text=...
    final text = uri.queryParameters['text'];
    if (text != null) {
      final inner = Uri.tryParse(text);
      if (inner != null) {
        final fromInner = MagicLinkService.tokenFromLink(inner);
        if (fromInner != null) return fromInner;
        final innerToken = inner.queryParameters['token'];
        if (innerToken != null) return innerToken;
      }
    }

    // Bare token (no scheme/host and no whitespace), e.g. a JWT or the
    // on-device base64 token pasted straight from the chat.
    if (uri.scheme.isEmpty && uri.host.isEmpty && !trimmed.contains(' ')) {
      return trimmed;
    }

    return null;
  }

  void _submitManualToken() {
    final token = _extractTokenFromPastedText(_manualTokenController.text);
    if (token == null) {
      AppLog.w('MagicLinkPage', 'Manual entry contained no usable token');
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text('Could not find a Magic Link token in that text. '
                'Copy the link or token from the message and try again.'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }
    AppLog.i('MagicLinkPage',
        'Manual token entry submitted (length=${token.length})');
    _verifyToken(token);
  }

  Future<void> _resendMagicLink() async {
    if (_isResending || _resendTimer > 0) return;
    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    AppLog.i('MagicLinkPage', 'Resend Magic Link pressed for ${widget.mobile}');
    try {
      final service = MagicLinkService.database(DatabaseService.instance);
      final nextResult = await service.requestMagicLink(
          mobile: widget.mobile, purpose: 'signup');
      if (!mounted) return;

      setState(() {
        _deepLink = nextResult.deepLink;
        _waMeUrl = nextResult.waMeUrl;
        _infoMessage =
            'A fresh Magic Link is ready. Tap the button below to open it in WhatsApp.';
      });
      _startResendTimer();
      await _openWhatsApp();
    } catch (e) {
      AppLog.e('MagicLinkPage', 'Resend error', e);
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF8F0),
      appBar: AppBar(
        backgroundColor: AppColors.terracotta,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => widget.onNavigate(AppScreen.login),
        ),
        title: const Text(
          'Verify Your Number',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: AppColors.terracotta.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chat_rounded,
                  size: 36,
                  color: AppColors.terracotta,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Check your WhatsApp',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'We sent a secure Magic Link to\n${widget.mobile}\n'
                'Open WhatsApp and tap the link to verify. No code needed.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),

              CustomButton(
                text: 'Open WhatsApp',
                isLoading: _isLaunching,
                onPressed: _openWhatsApp,
              ),

              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () =>
                    Clipboard.setData(ClipboardData(text: _deepLink)),
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copy Magic Link',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.terracotta,
                  minimumSize: const Size.fromHeight(48),
                  side: const BorderSide(color: AppColors.terracotta),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),
              ],
              if (_infoMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Text(
                    _infoMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.green, fontSize: 13),
                  ),
                ),
              ],

              if (_isVerifying) ...[
                const SizedBox(height: 24),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                      SizedBox(width: 12),
                      Text('Verifying link...'),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Manual entry fallback for users who cannot tap the link.
              TextButton.icon(
                onPressed: () =>
                    setState(() => _showManualEntry = !_showManualEntry),
                icon: Icon(Icons.keyboard_alt_outlined,
                    size: 18,
                    color: _showManualEntry
                        ? AppColors.terracotta
                        : Colors.black54),
                label: Text(
                  _showManualEntry
                      ? 'Hide manual entry'
                      : 'Paste/token manual entry',
                  style: const TextStyle(fontSize: 14),
                ),
              ),

              if (_showManualEntry) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _manualTokenController,
                  keyboardType: TextInputType.text,
                  decoration: InputDecoration(
                    labelText: 'Paste the Magic Link token',
                    hintText: 'Paste the full link and this app will '
                        'read the token',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.send_rounded, size: 20),
                      onPressed: _submitManualToken,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Didn't receive it? ",
                    style: TextStyle(color: Colors.black54, fontSize: 14),
                  ),
                  GestureDetector(
                    onTap: _resendTimer == 0 ? _resendMagicLink : null,
                    child: Text(
                      _isResending
                          ? 'Sending...'
                          : _resendTimer > 0
                              ? 'New link in ${_resendTimer}s'
                              : 'Request New Link',
                      style: TextStyle(
                        color: _resendTimer == 0
                            ? AppColors.terracotta
                            : Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        decoration: _resendTimer == 0
                            ? TextDecoration.underline
                            : TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
