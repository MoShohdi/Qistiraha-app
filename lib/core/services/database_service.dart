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
  /// the caller turns into a shareable [deepLinkFor] / QR code.
  static Future<String> createInstallment({
    required String itemDescription,
    required double totalAmount,
    required int months,
  }) async {
    if (_uid == null) throw StateError('Not authenticated.');
    final row = await _client
        .from(_table)
        .insert({
          'merchant_id': _uid,
          'item_description': itemDescription,
          'total_amount': totalAmount,
          'months': months,
          'paid_amount': 0,
          'status': 'pending_scan',
          // consumer_id intentionally omitted → NULL until claimed
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  // ---------------------------------------------------------------------------
  // Consumer side of the handshake
  // ---------------------------------------------------------------------------

  /// Reads one installment by id — used to preview a scanned link before the
  /// consumer commits to claiming it. Returns null if the row is gone or RLS
  /// hides it (e.g. already claimed by someone else).
  static Future<InstallmentRow?> fetchInstallment(String id) async {
    final row = await _client
        .from(_table)
        .select()
        .eq('id', id)
        .maybeSingle();
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

/// Thin typed view over an `installments` row. Keeps call sites off raw map
/// key strings without reintroducing a Hive model.
class InstallmentRow {
  final String id;
  final String merchantId;
  final String? consumerId;
  final String itemDescription;
  final double totalAmount;
  final double paidAmount;
  final int months;
  final String status;

  const InstallmentRow({
    required this.id,
    required this.merchantId,
    required this.consumerId,
    required this.itemDescription,
    required this.totalAmount,
    required this.paidAmount,
    required this.months,
    required this.status,
  });

  factory InstallmentRow.fromMap(Map<String, dynamic> m) {
    double toDouble(dynamic v) =>
        v == null ? 0.0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0);
    int toInt(dynamic v) =>
        v == null ? 0 : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
    return InstallmentRow(
      id: m['id'] as String,
      merchantId: m['merchant_id'] as String,
      consumerId: m['consumer_id'] as String?,
      itemDescription: (m['item_description'] as String?) ?? '',
      totalAmount: toDouble(m['total_amount']),
      paidAmount: toDouble(m['paid_amount']),
      months: toInt(m['months']),
      status: (m['status'] as String?) ?? 'pending_scan',
    );
  }

  double get remaining => (totalAmount - paidAmount).clamp(0, totalAmount);
  double get monthlyAmount => months > 0 ? totalAmount / months : totalAmount;
  bool get isPending => status == 'pending_scan';
}
