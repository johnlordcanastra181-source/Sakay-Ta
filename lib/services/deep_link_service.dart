import 'dart:async';

import 'package:app_links/app_links.dart';

import '../core/logger.dart';
import 'magic_link_service.dart';

/// Listens for `sakayta://auth/verify?token=...` deep links while the app is
/// running and forwards them to whoever is listening (the Magic Link
/// verification page).
///
/// A link that cold-started the app is captured by [init] and can be picked
/// up via [takeInitialAuthLink] so the verification flow can complete even
/// when the app was launched by tapping the Magic Link.
class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  static const String tag = 'DeepLinkService';

  static const String scheme = 'sakayta';
  static const String host = 'auth';

  final AppLinks _appLinks = AppLinks();
  final StreamController<Uri> _controller = StreamController<Uri>.broadcast();

  /// Stream of raw incoming app links.
  Stream<Uri> get links => _controller.stream;

  Uri? _initialAuthLink;
  bool _initialized = false;

  /// Starts listening for `sakayta://` deep links. Safe to call repeatedly.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        AppLog.i(tag,
            'Initial link received: ${initial.replace(query: '').replace(fragment: '')}');
        if (MagicLinkService.tokenFromLink(initial) != null) {
          _initialAuthLink = initial;
        }
        _controller.add(initial);
      }
    } catch (e) {
      AppLog.e(tag, 'Failed to read initial deep link', e);
    }

    _appLinks.uriLinkStream.listen(
      (uri) {
        AppLog.i(tag,
            'Deep link received: ${uri.replace(query: '').replace(fragment: '')}');
        _controller.add(uri);
      },
      onError: (Object e) => AppLog.e(tag, 'Deep link stream error: $e'),
    );
    AppLog.i(tag, 'Listening for $scheme:// links');
  }

  /// Returns and clears the auth-verification link that cold-started the app,
  /// or null when the app was not opened from a [[scheme]] link.
  Uri? takeInitialAuthLink() {
    final link = _initialAuthLink;
    _initialAuthLink = null;
    return link;
  }
}
