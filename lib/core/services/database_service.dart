import 'dart:async';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Production origin used to build shareable web claim links when the merchant
/// is NOT running the web app (native has no browser origin to read). On web
/// the live origin (`Uri.base.origin`) is used instead, so this only matters
/// for links generated from the mobile app. Set it to your deployed web host.
const String kWebAppOrigin = 'https://qistiraha.app';

/// Live, Supabase-backed access to `public.installments`.
///
/// The two `*Stream` getters use `.stream(primaryKey: ['id'])`, which opens a
/// realtime channel: any INSERT/UPDATE/DELETE that RLS lets the current user
/// see is pushed to the stream immediately. That is the whole point of the
/// merchant↔consumer handshake — when a consumer claims a pending row, the
/// merchant's [merchantInstallments] stream and the consumer's
/// [consumerInstallments] stream both re-emit with no manual refresh.
///
/// Rows are plain `Map<String, dynamic>` (Postgres row JSON), not the legacy
/// Hive `Installment` model. See [Installment.fromRow] below for a typed view.
class DatabaseService {
  static SupabaseClient get _client => Supabase.instance.client;
  static String? get _uid => _client.auth.currentUser?.id;

  /// The current authenticated user's id (or null). Used e.g. to decide
  /// whether a plan is self-owned (deletable) vs. merchant-issued.
  static String? get currentUserId => _uid;

  static const String _table = 'installments';

  // ---------------------------------------------------------------------------
  // Realtime streams
  // ---------------------------------------------------------------------------

  /// Every installment this merchant has generated, newest activity last.
  /// Emits `[]` (rather than erroring) when signed out.
  ///
  /// Each emission is enriched with the real buyer name — but only for claimed
  /// (`active`) rows, and sourced from the [`merchant_customer_names`] RPC that
  /// returns nothing but the name (never income or any other profile field).
  /// `asyncMap` keeps the name merge in step with every realtime update.
  // --- Session-cached merchant stream ------------------------------------
  // One realtime subscription per session, fanned out via a broadcast
  // controller, with the last snapshot retained. New subscribers (e.g. a
  // desktop widget that gets REMOUNTED when ResponsiveLayout swaps layouts on
  // web) re-attach to this SAME live subscription and are replayed the last
  // known list immediately — so a remount can never reset the dashboard to an
  // empty array or race a fresh realtime channel teardown. Acts like a small
  // hand-rolled BehaviorSubject.
  static StreamController<List<InstallmentRow>>? _merchantCtrl;
  static StreamSubscription<List<InstallmentRow>>? _merchantSub;
  static List<InstallmentRow> _merchantLast = const [];
  static String? _merchantCachedUid;

  static Stream<List<InstallmentRow>> merchantInstallments() {
    final uid = _uid;
    if (uid == null) {
      _disposeMerchantStream();
      return Stream.value(const []);
    }
    // (Re)build the shared pipeline only when it doesn't exist yet or the
    // signed-in merchant changed — NOT on every call/rebuild.
    if (_merchantCtrl == null || _merchantCachedUid != uid) {
      _disposeMerchantStream();
      _merchantCachedUid = uid;
      final ctrl = StreamController<List<InstallmentRow>>.broadcast();
      _merchantCtrl = ctrl;
      // Build the installment list from the realtime stream FIRST and
      // unconditionally (identical mapping to the consumer stream); the
      // buyer-name lookup is a separate, fully-guarded decoration step.
      final source = _client
          .from(_table)
          .stream(primaryKey: ['id'])
          .eq('merchant_id', uid)
          .order('created_at')
          .map(_mapRows)
          .asyncMap(_decorateWithCustomerNames);
      _merchantSub = source.listen(
        (rows) {
          _merchantLast = rows;
          if (!ctrl.isClosed) ctrl.add(rows);
        },
        onError: (Object e, StackTrace s) {
          if (!ctrl.isClosed) ctrl.addError(e, s);
        },
      );
    }
    return _replayThenFollow(_merchantCtrl!);
  }

  /// Replays the last known list to a new subscriber, then follows live
  /// updates from the shared broadcast controller.
  static Stream<List<InstallmentRow>> _replayThenFollow(
    StreamController<List<InstallmentRow>> ctrl,
  ) async* {
    yield _merchantLast;
    yield* ctrl.stream;
  }

  static void _disposeMerchantStream() {
    _merchantSub?.cancel();
    _merchantSub = null;
    _merchantCtrl?.close();
    _merchantCtrl = null;
    _merchantLast = const [];
    _merchantCachedUid = null;
  }

  /// Tears down session-scoped caches (the shared merchant realtime
  /// subscription). Call on sign-out so the next user starts clean and no
  /// stale subscription lingers.
  static void resetSession() => _disposeMerchantStream();

  /// Overlays the real buyer name onto each row, best-effort. ANY failure —
  /// the RPC erroring, timing out, or the `merchant_customer_names` function
  /// not existing yet — returns the rows UNCHANGED. The installments are never
  /// lost to the name lookup; worst case the merchant sees the generic label.
  static Future<List<InstallmentRow>> _decorateWithCustomerNames(
    List<InstallmentRow> rows,
  ) async {
    if (rows.isEmpty) return rows;
    Map<String, String> names;
    try {
      names = await _merchantCustomerNames().timeout(
        const Duration(seconds: 6),
        onTimeout: () => const <String, String>{},
      );
    } catch (_) {
      names = const {};
    }
    if (names.isEmpty) return rows;
    return [
      for (final r in rows)
        names.containsKey(r.id) ? r.withCustomerName(names[r.id]) : r,
    ];
  }

  /// Calls the SECURITY DEFINER `merchant_customer_names` RPC and returns a
  /// map of installment id → buyer name for the current merchant's claimed
  /// rows. Fails soft (empty map) so a name-lookup hiccup never breaks the
  /// dashboard stream — rows just fall back to the generic label.
  static Future<Map<String, String>> _merchantCustomerNames() async {
    try {
      final data = await _client.rpc('merchant_customer_names');
      final map = <String, String>{};
      if (data is List) {
        for (final row in data) {
          if (row is Map) {
            final id = row['installment_id'];
            final name = row['customer_name'];
            if (id is String && name is String && name.isNotEmpty) {
              map[id] = name;
            }
          }
        }
      }
      return map;
    } catch (_) {
      return const {};
    }
  }

  /// Every installment this consumer has claimed.
  static Stream<List<InstallmentRow>> consumerInstallments() {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _seeded(
      _client
          .from(_table)
          .stream(primaryKey: ['id'])
          .eq('consumer_id', uid)
          .order('created_at')
          .map(_mapRows),
    );
  }

  /// Prepends an immediate empty snapshot so a `StreamBuilder` has data on its
  /// very first frame. This is the deliberate "fallback state" that keeps a
  /// dropped/slow realtime channel from freezing the UI on an endless spinner:
  /// worst case the user sees the normal empty state until the first real
  /// snapshot (or an error) arrives — never a hung loader. Errors from the
  /// underlying channel still propagate through, so `snapshot.hasError` can
  /// drive a retry affordance.
  static Stream<List<InstallmentRow>> _seeded(
    Stream<List<InstallmentRow>> source,
  ) async* {
    yield const <InstallmentRow>[];
    yield* source;
  }

  static List<InstallmentRow> _mapRows(List<Map<String, dynamic>> rows) =>
      rows.map(InstallmentRow.fromMap).toList();

  // ---------------------------------------------------------------------------
  // Merchant storefront (public.businesses)
  // ---------------------------------------------------------------------------

  /// The current merchant's storefront row, or null if signed out. Auto-creates
  /// a default storefront (named from the profile) the first time a merchant
  /// with no `businesses` row asks for it — this is what turns the old
  /// "No merchant account found" dead-end into a working dashboard for anyone
  /// who onboarded before storefronts were provisioned on sign-up.
  static Future<Business?> merchantBusiness() async {
    final uid = _uid;
    if (uid == null) return null;
    final existing = await _client
        .from('businesses')
        .select()
        .eq('owner_id', uid)
        .order('created_at')
        .limit(1)
        .maybeSingle();
    if (existing != null) return Business.fromMap(existing);
    return _createBusinessForCurrentUser();
  }

  /// Ensures a storefront row exists for the current merchant, creating one
  /// from their profile name if absent. Safe to call on every merchant sign-in
  /// / role selection; returns the (possibly newly created) row.
  static Future<Business?> ensureBusiness({String? businessName}) async {
    final uid = _uid;
    if (uid == null) return null;
    final existing = await _client
        .from('businesses')
        .select()
        .eq('owner_id', uid)
        .order('created_at')
        .limit(1)
        .maybeSingle();
    if (existing != null) return Business.fromMap(existing);
    return _createBusinessForCurrentUser(businessName: businessName);
  }

  static Future<Business?> _createBusinessForCurrentUser({
    String? businessName,
  }) async {
    final uid = _uid;
    if (uid == null) return null;
    var name = businessName?.trim() ?? '';
    if (name.isEmpty) {
      final me = await profileFinance();
      name = me.name.trim().isEmpty ? 'My Store' : "${me.name}'s Store";
    }
    final row = await _client
        .from('businesses')
        .insert({'owner_id': uid, 'business_name': name})
        .select()
        .single();
    return Business.fromMap(row);
  }

  // ---------------------------------------------------------------------------
  // Merchant side of the handshake
  // ---------------------------------------------------------------------------

  /// Creates a new pending installment attributed to the current merchant
  /// (`consumer_id` NULL, status `pending_scan`) and returns its id, which
  /// the caller turns into a shareable [deepLinkFor] / QR code. Seeds the
  /// full plan shape (frequency, per-period amount, first due date) so the
  /// consumer's dashboard can render it richly the instant they claim it.
  static Future<String> createInstallment({
    required String itemDescription,
    required double totalAmount,
    required int months,
    String paymentFrequency = 'Monthly',
    double downPayment = 0,
    double interestRate = 0,
    String? category,
    String? provider,
    String? merchantName,
    bool isLongTerm = false,
    DateTime? firstDueDate,
  }) async {
    if (_uid == null) throw StateError('Not authenticated.');
    final monthsPerPayment = _monthsPerPaymentFor(paymentFrequency);
    final totalPeriods = monthsPerPayment > 0
        ? months ~/ monthsPerPayment
        : months;
    final principal = totalAmount - downPayment;
    final perPeriod = totalPeriods > 0
        ? (principal * (1 + interestRate / 100)) / totalPeriods
        : principal;
    final due = firstDueDate ?? DateTime.now().add(const Duration(days: 30));

    final row = await _client
        .from(_table)
        .insert({
          'merchant_id': _uid,
          'item_description': itemDescription,
          'total_amount': totalAmount,
          'months': months,
          'total_months': months,
          'paid_months': 0,
          'paid_amount': 0,
          'monthly_payment': perPeriod,
          'payment_frequency': paymentFrequency,
          'down_payment': downPayment,
          'interest_rate': interestRate,
          'category': category,
          'provider': provider,
          'merchant_name': merchantName,
          'is_long_term': isLongTerm,
          'due_date': due.toIso8601String().substring(0, 10), // date-only
          'past_payments': <double>[],
          'status': 'pending_scan',
          // consumer_id intentionally omitted → NULL until claimed
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  /// Creates a self-tracked installment (the consumer manually logging a plan
  /// they already have elsewhere). Unlike [createInstallment], this sets
  /// `merchant_id == consumer_id == auth.uid()` and status `active`, so the
  /// row appears immediately on the caller's own [consumerInstallments]
  /// stream — no scan/claim handshake needed.
  static Future<void> addSelfInstallment({
    required String itemDescription,
    required double totalAmount,
    required int totalMonths,
    required double monthlyPayment,
    required DateTime dueDate,
    required double downPayment,
    required double interestRate,
    required String category,
    required bool isLongTerm,
    required String paymentFrequency,
    required String provider,
    required String merchantName,
    int paidMonths = 0,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('Not authenticated.');

    final monthsPerPayment = _monthsPerPaymentFor(paymentFrequency);
    final paidPeriods = monthsPerPayment > 0
        ? paidMonths ~/ monthsPerPayment
        : paidMonths;
    // Reconstruct a "already paid" history for legacy plans the user says
    // they've partly paid off, so timelines/progress render correctly.
    final past = List<double>.filled(paidPeriods, monthlyPayment);

    await _client.from(_table).insert({
      'merchant_id': uid,
      'consumer_id': uid,
      'item_description': itemDescription,
      'total_amount': totalAmount,
      'months': totalMonths,
      'total_months': totalMonths,
      'paid_months': paidMonths,
      'paid_amount': paidPeriods * monthlyPayment,
      'monthly_payment': monthlyPayment,
      'payment_frequency': paymentFrequency,
      'down_payment': downPayment,
      'interest_rate': interestRate,
      'category': category,
      'provider': provider,
      'merchant_name': merchantName,
      'is_long_term': isLongTerm,
      'due_date': dueDate.toIso8601String().substring(0, 10),
      'past_payments': past,
      'status': 'active',
    });
  }

  // ---------------------------------------------------------------------------
  // Profile finance (income lives on public.profiles now, not Hive)
  // ---------------------------------------------------------------------------

  /// Reads the current user's income, salary day, and display name — the
  /// non-installment inputs the Affordability Engine and sidebar need. Returns
  /// zero-income defaults if the row is missing or unreadable.
  static Future<ProfileFinance> profileFinance() async {
    final user = _client.auth.currentUser;
    if (user == null) return const ProfileFinance();
    try {
      final row = await _client
          .from('profiles')
          .select('monthly_income, salary_day, full_name')
          .eq('id', user.id)
          .maybeSingle();
      if (row == null) {
        return ProfileFinance(
          name: user.userMetadata?['full_name'] as String? ?? '',
        );
      }
      double toDouble(dynamic v) => v == null
          ? 0.0
          : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0);
      return ProfileFinance(
        monthlyIncome: toDouble(row['monthly_income']),
        salaryDay: (row['salary_day'] as num?)?.toInt() ?? 1,
        name:
            (row['full_name'] as String?) ??
            (user.userMetadata?['full_name'] as String? ?? ''),
      );
    } catch (_) {
      return const ProfileFinance();
    }
  }

  /// Updates the user's income (and optionally salary day) on their profile.
  static Future<void> updateIncome(
    double monthlyIncome, {
    int? salaryDay,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('Not authenticated.');
    final patch = <String, dynamic>{'monthly_income': monthlyIncome};
    if (salaryDay != null) patch['salary_day'] = salaryDay;
    await _client.from('profiles').update(patch).eq('id', uid);
  }

  // ---------------------------------------------------------------------------
  // Payment recording (consumer marks a period paid)
  // ---------------------------------------------------------------------------

  /// Records a single on-time period payment against [row]: appends the
  /// per-period amount to `past_payments`, advances `paid_months` and
  /// `due_date` by one frequency step, stamps `last_paid_at`, and flips
  /// `status` to `completed` when the final period is paid. No penalties.
  ///
  /// Because the caller's dashboard subscribes to [consumerInstallments], the
  /// updated row streams straight back and the UI reflects it with no refresh.
  static Future<void> recordPayment(InstallmentRow row) async {
    final uid = _uid;
    if (uid == null) throw StateError('Not authenticated.');
    if (row.paidPayments >= row.totalPayments) return;

    final newPaidMonths = row.paidMonths + row.monthsPerPayment;
    final newDueDate = DateTime(
      row.dueDate.year,
      row.dueDate.month + row.monthsPerPayment,
      row.dueDate.day,
    );
    final newPast = [...row.pastPayments, row.monthlyPayment];
    final completed = newPaidMonths >= row.totalMonths;

    await _client
        .from(_table)
        .update({
          'paid_months': newPaidMonths,
          'paid_amount': row.paidAmount + row.monthlyPayment,
          'past_payments': newPast,
          'due_date': newDueDate.toIso8601String().substring(0, 10),
          'last_paid_at': DateTime.now().toIso8601String(),
          if (completed) 'status': 'completed',
        })
        .eq('id', row.id);
  }

  // ---------------------------------------------------------------------------
  // Consumer side of the handshake
  // ---------------------------------------------------------------------------

  /// Reads one installment by id — used to preview a scanned link before the
  /// consumer commits to claiming it. Returns null if the row is gone or RLS
  /// hides it (e.g. already claimed by someone else).
  static Future<InstallmentRow?> fetchInstallment(String id) async {
    final row = await _client.from(_table).select().eq('id', id).maybeSingle();
    return row == null ? null : InstallmentRow.fromMap(row);
  }

  /// Claims a pending installment for the current consumer: sets
  /// `consumer_id = auth.uid()` and `status = 'active'`. The heavy lifting is
  /// the RLS "consumer claims pending" policy — this update only succeeds if
  /// the row is still `pending_scan` and unclaimed, and only lets the caller
  /// set themselves as the consumer.
  ///
  /// Returns `true` when a row was actually updated, `false` when nothing
  /// matched — the row was already claimed, already gone, or hidden by RLS.
  /// The `.eq('status', 'pending_scan')` guard plus `.select()` make that
  /// outcome observable instead of a silent no-op.
  static Future<bool> claimInstallment(String id) async {
    final uid = _uid;
    if (uid == null) throw StateError('Not authenticated.');
    final updated = await _client
        .from(_table)
        .update({'consumer_id': uid, 'status': 'active'})
        .eq('id', id)
        .eq('status', 'pending_scan')
        .select();
    return updated.isNotEmpty;
  }

  /// Declines a shared installment: deletes the still-unclaimed `pending_scan`
  /// draft so abandoned links don't accumulate. Gated to pending rows (the
  /// `.eq` guard plus the "decline pending" RLS policy), so this can never
  /// remove a live/claimed plan. No-op if the row is already claimed or gone.
  static Future<void> declineInstallment(String id) async {
    if (_uid == null) throw StateError('Not authenticated.');
    await _client
        .from(_table)
        .delete()
        .eq('id', id)
        .eq('status', 'pending_scan');
  }

  /// Deletes an installment row. RLS lets this succeed only for the issuing
  /// merchant — which, for a self-added plan (merchant_id == consumer_id ==
  /// the user), is the user themselves.
  static Future<void> deleteInstallment(String id) async {
    if (_uid == null) throw StateError('Not authenticated.');
    await _client.from(_table).delete().eq('id', id);
  }

  /// Re-plans an installment's terms (early-payoff calculator): sets a new
  /// per-period amount and total month count. Allowed by the "consumer
  /// updates own" RLS policy.
  static Future<void> updatePlanTerms(
    String id, {
    required double monthlyPayment,
    required int totalMonths,
  }) async {
    if (_uid == null) throw StateError('Not authenticated.');
    await _client
        .from(_table)
        .update({
          'monthly_payment': monthlyPayment,
          'total_months': totalMonths,
          'months': totalMonths,
        })
        .eq('id', id);
  }

  // ---------------------------------------------------------------------------
  // Receipt / warranty images (Supabase Storage bucket 'receipts')
  // ---------------------------------------------------------------------------

  static const String _receiptsBucket = 'receipts';

  /// Uploads [bytes] as the receipt image for [installmentId] to
  /// `receipts/<uid>/<installmentId>.jpg`, writes the public URL onto the row,
  /// and returns it. Works on web and mobile (byte upload). Cache-busts the
  /// URL so a re-upload actually re-renders.
  static Future<String> uploadReceipt(
    String installmentId,
    Uint8List bytes, {
    String contentType = 'image/jpeg',
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('Not authenticated.');
    final path = '$uid/$installmentId.jpg';
    await _client.storage
        .from(_receiptsBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(upsert: true, contentType: contentType),
        );
    final base = _client.storage.from(_receiptsBucket).getPublicUrl(path);
    final url = '$base?t=${DateTime.now().millisecondsSinceEpoch}';
    await _client
        .from(_table)
        .update({'receipt_image_url': url})
        .eq('id', installmentId);
    return url;
  }

  /// Removes the stored receipt image and clears the column.
  static Future<void> removeReceipt(String installmentId) async {
    final uid = _uid;
    if (uid == null) throw StateError('Not authenticated.');
    await _client.storage.from(_receiptsBucket).remove(['$uid/$installmentId.jpg']);
    await _client
        .from(_table)
        .update({'receipt_image_url': null})
        .eq('id', installmentId);
  }

  // ---------------------------------------------------------------------------
  // Deep link
  // ---------------------------------------------------------------------------

  /// The shareable link a merchant hands to a buyer (QR / WhatsApp):
  /// `qistiraha://installment/<id>`. Parsed back out by `DeepLinkService`.
  static String deepLinkFor(String installmentId) =>
      'qistiraha://installment/$installmentId';

  /// The web equivalent of [deepLinkFor]: `https://<host>/?claim_id=<id>` —
  /// pasteable straight into a desktop browser (handled at boot in `main.dart`
  /// / `DeepLinkService.claimIdFromUri`). On the web app the live origin is
  /// used; from the native app it falls back to [kWebAppOrigin].
  static String webClaimLinkFor(String installmentId) =>
      '${_webOrigin()}/?claim_id=$installmentId';

  static String _webOrigin() {
    final base = Uri.base;
    if (base.scheme == 'http' || base.scheme == 'https') return base.origin;
    return kWebAppOrigin;
  }

  /// Extracts the installment id from a `qistiraha://installment/<id>` URI,
  /// or null if [uri] is not one of those links.
  static String? installmentIdFromUri(Uri uri) {
    if (uri.scheme != 'qistiraha' || uri.host != 'installment') return null;
    return uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
  }
}

/// The non-installment finance inputs (income, salary day, display name) the
/// dashboard needs, sourced from `public.profiles` now that Hive is gone.
class ProfileFinance {
  final double monthlyIncome;
  final int salaryDay;
  final String name;
  const ProfileFinance({
    this.monthlyIncome = 0,
    this.salaryDay = 1,
    this.name = '',
  });
}

/// A merchant's storefront row from `public.businesses`. Replaces the legacy
/// Hive `BusinessAccount` on the merchant dashboards.
class Business {
  final String id;
  final String ownerId;
  final String name;
  final String? category;

  const Business({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.category,
  });

  factory Business.fromMap(Map<String, dynamic> m) => Business(
    id: m['id'] as String,
    ownerId: m['owner_id'] as String,
    name: (m['business_name'] as String?) ?? 'My Store',
    category: m['category'] as String?,
  );
}

/// Number of calendar months per payment period for a frequency string —
/// the single source of truth reused by [DatabaseService.createInstallment]
/// and [InstallmentRow]. (Kept local so this Supabase-only service never
/// imports the legacy Hive `Installment` model.)
int _monthsPerPaymentFor(String frequency) {
  switch (frequency) {
    case 'Quarterly':
      return 3;
    case 'Semi-Annually':
      return 6;
    case 'Annually':
      return 12;
    default:
      return 1;
  }
}

/// Typed, penalty-free view over an `installments` row. Deliberately mirrors
/// the field names and computed getters of the legacy Hive `Installment`
/// model so the dashboards can swap their data source from Hive to this with
/// minimal churn — but carries NO late-fee/penalty surface, since Qistiraha
/// no longer tracks those.
///
/// Lifecycle `status` here is the marketplace lifecycle
/// (`pending_scan` → `active` → `completed` / `cancelled`), which is distinct
/// from the old paid/overdue enum — overdue is now a *derived* condition
/// ([isOverdue]) computed from [dueDate], not a stored value.
class InstallmentRow {
  final String id;
  final String merchantId;
  final String? consumerId;
  final String itemDescription;
  final double totalAmount;
  final double paidAmount;
  final double monthlyPayment; // per-PERIOD chunk
  final String paymentFrequency;
  final int totalMonths;
  final int paidMonths;
  final DateTime dueDate;
  final double downPayment;
  final double interestRate;
  final String category;
  final String provider;
  final String merchantName;
  final bool isLongTerm;
  final List<double> pastPayments;
  final DateTime? lastPaidAt;
  final String status;
  final String? receiptImageUrl;
  final String? customerName; // buyer's display name (denormalized)

  const InstallmentRow({
    required this.id,
    required this.merchantId,
    required this.consumerId,
    required this.itemDescription,
    required this.totalAmount,
    required this.paidAmount,
    required this.monthlyPayment,
    required this.paymentFrequency,
    required this.totalMonths,
    required this.paidMonths,
    required this.dueDate,
    required this.downPayment,
    required this.interestRate,
    required this.category,
    required this.provider,
    required this.merchantName,
    required this.isLongTerm,
    required this.pastPayments,
    required this.lastPaidAt,
    required this.status,
    required this.receiptImageUrl,
    required this.customerName,
  });

  factory InstallmentRow.fromMap(Map<String, dynamic> m) {
    double toDouble(dynamic v) => v == null
        ? 0.0
        : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0);
    int toInt(dynamic v) =>
        v == null ? 0 : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
    DateTime? toDate(dynamic v) => v == null ? null : DateTime.tryParse('$v');
    List<double> toDoubleList(dynamic v) => v is List
        ? v
              .map(
                (e) => e is num ? e.toDouble() : double.tryParse('$e') ?? 0.0,
              )
              .toList()
        : const [];

    return InstallmentRow(
      id: m['id'] as String,
      merchantId: m['merchant_id'] as String,
      consumerId: m['consumer_id'] as String?,
      itemDescription: (m['item_description'] as String?) ?? '',
      totalAmount: toDouble(m['total_amount']),
      paidAmount: toDouble(m['paid_amount']),
      monthlyPayment: toDouble(m['monthly_payment']),
      paymentFrequency: (m['payment_frequency'] as String?) ?? 'Monthly',
      totalMonths: toInt(m['total_months'] ?? m['months']),
      paidMonths: toInt(m['paid_months']),
      dueDate: toDate(m['due_date']) ?? DateTime.now(),
      downPayment: toDouble(m['down_payment']),
      interestRate: toDouble(m['interest_rate']),
      category: (m['category'] as String?) ?? 'Other',
      provider: (m['provider'] as String?) ?? 'Other / Custom',
      merchantName: (m['merchant_name'] as String?) ?? '',
      isLongTerm: (m['is_long_term'] as bool?) ?? false,
      pastPayments: toDoubleList(m['past_payments']),
      lastPaidAt: toDate(m['last_paid_at']),
      status: (m['status'] as String?) ?? 'pending_scan',
      receiptImageUrl: m['receipt_image_url'] as String?,
      customerName: m['customer_name'] as String?,
    );
  }

  /// Returns a copy with [customerName] overlaid — used to decorate merchant
  /// rows with the buyer's real name (from the `merchant_customer_names` RPC)
  /// without rebuilding from the raw map.
  InstallmentRow withCustomerName(String? name) => InstallmentRow(
    id: id,
    merchantId: merchantId,
    consumerId: consumerId,
    itemDescription: itemDescription,
    totalAmount: totalAmount,
    paidAmount: paidAmount,
    monthlyPayment: monthlyPayment,
    paymentFrequency: paymentFrequency,
    totalMonths: totalMonths,
    paidMonths: paidMonths,
    dueDate: dueDate,
    downPayment: downPayment,
    interestRate: interestRate,
    category: category,
    provider: provider,
    merchantName: merchantName,
    isLongTerm: isLongTerm,
    pastPayments: pastPayments,
    lastPaidAt: lastPaidAt,
    status: status,
    receiptImageUrl: receiptImageUrl,
    customerName: name,
  );

  // ── lifecycle ────────────────────────────────────────────────────────────
  bool get isPending => status == 'pending_scan';
  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';

  /// Overdue is derived, not stored: an active plan whose next due date is in
  /// the past. (No penalty is attached — this is purely for display/sorting.)
  bool get isOverdue {
    if (!isActive) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return due.isBefore(today);
  }

  // ── frequency / period math (mirrors the old Installment getters) ─────────
  int get monthsPerPayment => _monthsPerPaymentFor(paymentFrequency);
  int get totalPayments => totalMonths ~/ monthsPerPayment;
  int get paidPayments => paidMonths ~/ monthsPerPayment;

  double get remaining => (totalAmount - paidAmount).clamp(0, totalAmount);
  double get monthlyAmount =>
      totalMonths > 0 ? totalAmount / totalMonths : totalAmount;

  /// The per-period chunk normalized to a monthly figure — used by the
  /// Affordability Engine so quarterly/annual plans don't over-count against
  /// a single month's income.
  double get monthlyDrain =>
      monthsPerPayment > 0 ? monthlyPayment / monthsPerPayment : monthlyPayment;

  String get periodNoun {
    switch (paymentFrequency) {
      case 'Quarterly':
        return 'Quarter';
      case 'Semi-Annually':
        return 'Half-Year';
      case 'Annually':
        return 'Year';
      default:
        return 'Month';
    }
  }

  String get paymentFrequencyLabel {
    switch (paymentFrequency) {
      case 'Quarterly':
        return 'Quarterly Payment';
      case 'Semi-Annually':
        return 'Semi-Annual Payment';
      case 'Annually':
        return 'Annual Payment';
      default:
        return 'Monthly Payment';
    }
  }

  String get paymentCadencePhrase {
    switch (paymentFrequency) {
      case 'Quarterly':
        return 'every quarter';
      case 'Semi-Annually':
        return 'every 6 months';
      case 'Annually':
        return 'every year';
      default:
        return 'every month';
    }
  }

  /// Calendar date of the payment [periodsBack] periods before [dueDate];
  /// steps by whole frequency chunks so quarterly/annual timeline nodes land
  /// on real dates. Mirrors the old `Installment.dueDateForPeriodsBack`.
  DateTime dueDateForPeriodsBack(int periodsBack) {
    final monthsBack = periodsBack * monthsPerPayment;
    return DateTime(dueDate.year, dueDate.month - monthsBack, dueDate.day);
  }
}
