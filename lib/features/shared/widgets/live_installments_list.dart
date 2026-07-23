import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qistiraha/core/services/database_service.dart';

/// A self-contained real-time list of installment rows, driven by one of the
/// [DatabaseService] streams. Drop this into either dashboard and it stays
/// live: when a consumer claims a pending link, the merchant's copy of this
/// widget re-renders that row from `pending_scan` → `active` with no refresh,
/// and the consumer's copy gains the row the instant they claim it.
///
/// This is the migration seam — a `StreamBuilder<List<InstallmentRow>>` — that
/// the feature-rich Hive dashboards can adopt incrementally, one section at a
/// time, without a big-bang rewrite.
///
/// Usage:
/// ```dart
/// // Merchant dashboard:
/// LiveInstallmentsList(
///   stream: DatabaseService.merchantInstallments(),
///   emptyLabel: 'No payment links yet',
///   perspective: InstallmentPerspective.merchant,
/// )
/// // Consumer dashboard:
/// LiveInstallmentsList(
///   stream: DatabaseService.consumerInstallments(),
///   emptyLabel: 'No installments yet',
///   perspective: InstallmentPerspective.consumer,
/// )
/// ```
enum InstallmentPerspective { merchant, consumer }

class LiveInstallmentsList extends StatelessWidget {
  final Stream<List<InstallmentRow>> stream;
  final String emptyLabel;
  final InstallmentPerspective perspective;
  final ValueChanged<InstallmentRow>? onTap;

  const LiveInstallmentsList({
    super.key,
    required this.stream,
    required this.emptyLabel,
    required this.perspective,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: 'EGP ', decimalDigits: 0);
    return StreamBuilder<List<InstallmentRow>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _centered('Could not load installments.');
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final rows = snapshot.data!;
        if (rows.isEmpty) return _centered(emptyLabel);

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: rows.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) =>
              _InstallmentTile(row: rows[i], currency: currency, onTap: onTap),
        );
      },
    );
  }

  Widget _centered(String text) => Center(
    child: Text(text, style: TextStyle(color: Colors.grey[500], fontSize: 14)),
  );
}

class _InstallmentTile extends StatelessWidget {
  final InstallmentRow row;
  final NumberFormat currency;
  final ValueChanged<InstallmentRow>? onTap;

  const _InstallmentTile({
    required this.row,
    required this.currency,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final meta = _statusMeta(row.status);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap == null ? null : () => onTap!(row),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.itemDescription.isEmpty
                          ? 'Installment'
                          : row.itemDescription,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${currency.format(row.totalAmount)} · ${row.months} mo',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: meta.$2.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  meta.$1,
                  style: TextStyle(
                    color: meta.$2,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// (label, color) for a status string.
  (String, Color) _statusMeta(String status) {
    switch (status) {
      case 'pending_scan':
        return ('Awaiting scan', Colors.orange);
      case 'active':
        return ('Active', const Color(0xFF99AFD7));
      case 'completed':
        return ('Completed', Colors.green);
      case 'cancelled':
        return ('Cancelled', Colors.red);
      default:
        return (status, Colors.grey);
    }
  }
}
