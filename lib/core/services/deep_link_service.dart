import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:qistiraha/core/services/database_service.dart';
import 'package:qistiraha/features/consumer/screens/claim_installment_screen.dart';

/// Routes inbound `qistiraha://…` deep links.
///
/// The live handshake link is `qistiraha://installment/<id>` — a merchant
/// shares it (QR / WhatsApp), and opening it drops the consumer onto
/// [ClaimInstallmentScreen] to claim that specific Supabase row.
///
/// `supabase_flutter` also listens to `app_links` for its OAuth
/// `qistiraha://login-callback` redirect and completes that itself, so this
/// handler must ignore anything that isn't an installment link (an explicit
/// host guard, so an auth callback can never be misrouted here).
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
    final installmentId = DatabaseService.installmentIdFromUri(uri);
    if (installmentId == null) return; // not an installment link — ignore

    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => ClaimInstallmentScreen(installmentId: installmentId),
      ),
    );
  }

  static void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
