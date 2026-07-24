import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/user_role.dart';
import '../../../core/services/database_service.dart';

/// Where the app should land right now: not authenticated, authenticated
/// but yet to pick Consumer/Merchant, or ready for a specific dashboard.
/// Returned by [AuthService.resolveDestination] and consumed by
/// `destinationScreen()` in `main.dart`.
enum AuthDestination { loggedOut, rolePicker, consumerHome, merchantHome }

/// Supabase-backed authentication (email/password + Google OAuth).
///
/// This is now the ONLY source of identity/role — there is no local Hive
/// mirror of the account any more, and no mock-data seeding. Session state
/// lives in `supabase_flutter`'s persisted client; role lives in
/// `public.profiles.role` (see `supabase/schema.sql`). Installment data is
/// read live from Supabase via `DatabaseService`, never from Hive.
class AuthService {
  static SupabaseClient get _client => Supabase.instance.client;

  static User? get currentUser => _client.auth.currentUser;
  static bool get hasActiveSession => _client.auth.currentSession != null;
  static Stream<AuthState> get authStateChanges =>
      _client.auth.onAuthStateChange;

  // ---------------------------------------------------------------------------
  // Email / password
  // ---------------------------------------------------------------------------

  /// Returns `null` on success, or a user-facing error message on failure.
  static Future<String?> signInWithEmail(String email, String password) async {
    try {
      await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'Something went wrong. Please try again.';
    }
  }

  /// Returns `null` on success, or a user-facing error message on failure.
  /// A `null` return does not guarantee an active session — if the Supabase
  /// project requires email confirmation, [hasActiveSession] will still be
  /// false right after this resolves; the caller should check it and prompt
  /// the user to confirm their email before signing in.
  static Future<String?> signUpWithEmail(
    String name,
    String email,
    String password,
  ) async {
    try {
      await _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'full_name': name},
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'Something went wrong. Please try again.';
    }
  }

  // ---------------------------------------------------------------------------
  // Google OAuth
  // ---------------------------------------------------------------------------

  /// Launches Supabase's browser-based Google OAuth flow. On web this
  /// navigates the current tab away (the app reloads on return, and boot
  /// re-resolves the new session); on mobile it opens the system browser
  /// and control returns via the `qistiraha://login-callback` deep link,
  /// which `supabase_flutter` completes internally. Completion is always
  /// reported asynchronously via [authStateChanges], never by this call.
  static Future<bool> signInWithGoogle() {
    return _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? null : 'qistiraha://login-callback',
      authScreenLaunchMode: kIsWeb
          ? LaunchMode.platformDefault
          : LaunchMode.externalApplication,
    );
  }

  // ---------------------------------------------------------------------------
  // Session / role resolution
  // ---------------------------------------------------------------------------

  static Future<void> signOut() => _client.auth.signOut();

  /// Persists the chosen role on `profiles`. Called exactly once per
  /// identity, from the Role Picker. When the user picks Merchant, this also
  /// provisions their `businesses` storefront row so the merchant dashboard
  /// has data to read immediately (no more "No merchant account found").
  static Future<void> completeRole(UserRole role) async {
    final user = currentUser;
    if (user == null) throw StateError('No authenticated user.');
    await _client
        .from('profiles')
        .update({'role': role.raw})
        .eq('id', user.id);
    if (role == UserRole.merchant) {
      await DatabaseService.ensureBusiness();
    }
  }

  /// The single place that decides what the app should show for the current
  /// Supabase session — called once at boot and again by the root
  /// `onAuthStateChange` listener after every live sign-in. Role comes
  /// straight from `public.profiles`; a null role means the identity hasn't
  /// picked Consumer/Merchant yet.
  static Future<AuthDestination> resolveDestination() async {
    final user = currentUser;
    if (user == null) return AuthDestination.loggedOut;

    final role = await _fetchRole(user.id);
    if (role == null) return AuthDestination.rolePicker;
    return role == UserRole.merchant
        ? AuthDestination.merchantHome
        : AuthDestination.consumerHome;
  }

  static Future<UserRole?> _fetchRole(String authUserId) async {
    final row = await _client
        .from('profiles')
        .select('role')
        .eq('id', authUserId)
        .maybeSingle();
    final raw = row?['role'] as String?;
    return raw == null ? null : UserRole.fromRaw(raw);
  }
}
