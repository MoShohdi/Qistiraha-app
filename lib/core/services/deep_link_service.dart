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
    final installmentId =
        DatabaseService.installmentIdFromUri(uri) ?? claimIdFromUri(uri);
    if (installmentId == null) return; // not an installment link — ignore

    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => ClaimInstallmentScreen(installmentId: installmentId),
      ),
    );
  }

  /// The claim id embedded in the *current page URL* — used on web, where a
  /// merchant's link is opened as an ordinary browser URL (custom `qistiraha://`
  /// schemes don't apply). Called once at boot from `main()`.
  static String? claimIdFromCurrentUrl() => claimIdFromUri(Uri.base);

  /// Extracts a claim/installment id from a web URL, supporting both:
  ///   * a query param — `?claim_id=<id>` (or `?installment=<id>`), and
  ///   * a hash route  — `#/claim?id=<id>` (or `#/claim?claim_id=<id>`).
  /// Returns null if neither is present. Safe on native (Uri.base carries no
  /// such params there), so callers don't need a `kIsWeb` guard.
  static String? claimIdFromUri(Uri uri) {
    final direct =
        uri.queryParameters['claim_id'] ?? uri.queryParameters['installment'];
    if (direct != null && direct.isNotEmpty) return direct;

    final fragment = uri.fragment;
    if (fragment.isNotEmpty) {
      final f = Uri.tryParse(fragment);
      final id = f?.queryParameters['id'] ?? f?.queryParameters['claim_id'];
      if (id != null && id.isNotEmpty) return id;
    }
    return null;
  }

  static void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
