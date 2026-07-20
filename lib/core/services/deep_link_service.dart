import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:qistiraha/features/merchant/models/qist_link_payload.dart';
import 'package:qistiraha/features/consumer/screens/incoming_qist_screen.dart';

/// Listens for `qistiraha://pay?...` links — opened either by tapping a
/// merchant's WhatsApp message or by the OS camera recognizing the QR code —
/// and pushes [IncomingQistScreen] on top of whatever the consumer is
/// currently looking at.
class DeepLinkService {
  static final AppLinks _appLinks = AppLinks();
  static StreamSubscription<Uri>? _subscription;

  /// [uriLinkStream] emits both the cold-start initial link and every link
  /// received while the app is already running, so a single subscription
  /// covers all cases.
  static Future<void> init(GlobalKey<NavigatorState> navigatorKey) async {
    _subscription?.cancel();
    _subscription = _appLinks.uriLinkStream.listen(
      (uri) => _handle(uri, navigatorKey),
      onError: (_) {},
    );
  }

  static void _handle(Uri uri, GlobalKey<NavigatorState> navigatorKey) {
    final payload = QistLinkPayload.fromUri(uri);
    if (payload == null) return;

    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => IncomingQistScreen(payload: payload)),
    );
  }

  static void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
