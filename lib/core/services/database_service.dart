import 'package:supabase_flutter/supabase_flutter.dart';

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
  static Stream<List<InstallmentRow>> merchantInstallments() {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _client
        .from(_table)
        .stream(primaryKey: ['id'])
        .eq('merchant_id', uid)
        .order('created_at')
        .map(_mapRows);
  }

  /// Every installment this consumer has claimed.
  static Stream<List<InstallmentRow>> consumerInstallments() {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _client
        .from(_table)
        .stream(primaryKey: ['id'])
        .eq('consumer_id', uid)
        .order('created_at')
        .map(_mapRows);
  }

  static List<InstallmentRow> _mapRows(List<Map<String, dynamic>> rows) =>
      rows.map(InstallmentRow.fromMap).toList();

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
  /// set themselves as the consumer. A row that was already claimed simply
  /// updates nothing.
  static Future<void> claimInstallment(String id) async {
    if (_uid == null) throw StateError('Not authenticated.');
    await _client
        .from(_table)
        .update({'consumer_id': _uid, 'status': 'active'})
        .eq('id', id);
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
  // Deep link
  // ---------------------------------------------------------------------------

  /// The shareable link a merchant hands to a buyer (QR / WhatsApp):
  /// `qistiraha://installment/<id>`. Parsed back out by `DeepLinkService`.
  static String deepLinkFor(String installmentId) =>
      'qistiraha://installment/$installmentId';

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
    );
  }

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
