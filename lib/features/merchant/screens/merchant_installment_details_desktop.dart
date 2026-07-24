import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qistiraha/core/services/database_service.dart';
import 'package:qistiraha/core/utils/responsive_layout.dart';
import 'package:qistiraha/features/consumer/models/enums.dart';
import 'package:qistiraha/features/merchant/widgets/installment_row_compat.dart';

const _kBrand = Color(0xFF99AFD7);

/// Desktop-native rendition of the merchant's read-only installment detail
/// pane. Ported from `merchant_installment_details_screen.dart` (same data
/// and actions — WhatsApp reminder, cancel contract, payment history) but
/// laid out for a wide, persistent detail pane instead of a pushed mobile
/// route: no AppBar/back button (this replaces the pane's content directly,
/// it isn't navigated to), a lightweight header row with a proper desktop
/// `TextButton.icon` for Cancel instead of an AppBar icon, and a
/// width-constrained WhatsApp button instead of a full-width mobile one.
///
/// [onCancelled] is called after the contract is successfully cancelled so
/// the parent master-detail view can clear its selection — there's no route
/// to pop here, this widget lives directly in the detail pane.
class MerchantInstallmentDetailsDesktop extends StatefulWidget {
  final InstallmentRow installment;
  final VoidCallback onCancelled;

  const MerchantInstallmentDetailsDesktop({
    super.key,
    required this.installment,
    required this.onCancelled,
  });

  @override
  State<MerchantInstallmentDetailsDesktop> createState() =>
      _MerchantInstallmentDetailsDesktopState();
}

class _MerchantInstallmentDetailsDesktopState
    extends State<MerchantInstallmentDetailsDesktop> {
  final _scrollController = ScrollController();

  InstallmentRow get _inst => widget.installment;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Builds one row per completed payment, newest first. Amounts come from
  /// [InstallmentRow.pastPayments] when available (falling back to the plan's
  /// standard [InstallmentRow.monthlyPayment] for older records that predate
  /// that field); dates are approximated backward from [InstallmentRow.dueDate]
  /// in payment-period increments, since the model only stores an exact
  /// timestamp for the most recent payment.
  List<_PaymentHistoryEntry> _paymentHistory() {
    final int paid = _inst.paidPayments;
    if (paid <= 0) return [];

    final entries = <_PaymentHistoryEntry>[];
    for (int i = paid - 1; i >= 0; i--) {
      final double amount = i < _inst.pastPayments.length
          ? _inst.pastPayments[i]
          : _inst.monthlyPayment;
      final DateTime approxDate = _inst.dueDateForPeriodsBack(paid - i);
      entries.add(
        _PaymentHistoryEntry(
          title: 'Payment ${i + 1} of ${_inst.totalPayments}',
          date: approxDate,
          amount: amount,
        ),
      );
    }
    return entries;
  }

  /// Opens WhatsApp with a pre-filled reminder for the merchant to send.
  /// No recipient prefill — the account-based handshake carries no phone
  /// number, so the merchant picks the chat (same as the portal's share link).
  Future<void> _sendWhatsAppReminder(BuildContext context) async {
    final currency = NumberFormat.currency(symbol: 'EGP ', decimalDigits: 0);
    final buyerName = _inst.customerName ?? 'there';
    final message =
        'Hello $buyerName, this is a friendly reminder from '
        '${_inst.merchantName} that your installment of '
        '${currency.format(_inst.monthlyPayment)} for the '
        '${_inst.itemDescription} is currently due.';

    final whatsappUri = Uri.parse(
      'https://wa.me/?text=${Uri.encodeComponent(message)}',
    );

    final launched = await launchUrl(
      whatsappUri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      showDesktopSnackBar(
        context,
        message: 'Could not open WhatsApp. Is it installed?',
      );
    }
  }

  /// Voids the contract entirely — for when the customer returned the item
  /// or settled the remaining balance in cash outside the app.
  Future<void> _cancelContract(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Contract?'),
        content: const Text(
          'Use this if the customer returned the item or paid the '
          'remaining balance in full immediately. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Back', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // RLS lets the issuing merchant delete their own row. Once gone, both the
    // merchant's and the consumer's realtime streams re-emit without it.
    await DatabaseService.deleteInstallment(_inst.id);

    if (context.mounted) {
      showDesktopSnackBar(context, message: 'Contract cancelled');
      widget.onCancelled();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: 'EGP ', decimalDigits: 0);
    final bool isOverdue = _inst.statusEnum == InstallmentStatus.overdue;
    final history = _paymentHistory();

    Color statusColor;
    String statusLabel;
    switch (_inst.statusEnum) {
      case InstallmentStatus.overdue:
        statusColor = Colors.red;
        statusLabel = 'Overdue';
        break;
      case InstallmentStatus.paid:
        statusColor = Colors.green;
        statusLabel = 'Paid';
        break;
      case InstallmentStatus.defaulted:
        statusColor = Colors.red[900]!;
        statusLabel = 'Defaulted';
        break;
      case InstallmentStatus.active:
        statusColor = _kBrand;
        statusLabel = 'Pending';
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 20, 16),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Installment Details',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: TextButton.icon(
                  onPressed: () => _cancelContract(context),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text(
                    'Cancel Contract',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.visibility_outlined, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'READ ONLY',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Item + status ──────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isOverdue ? Colors.red : Colors.grey[200]!,
                        width: isOverdue ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                _inst.itemDescription,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                statusLabel,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: _StatBlock(
                                label: 'Total Amount',
                                value: currency.format(_inst.amount),
                              ),
                            ),
                            Expanded(
                              child: _StatBlock(
                                label: _inst.paymentFrequencyLabel,
                                value: currency.format(_inst.monthlyPayment),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Progress',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '${_inst.paidPayments} of ${_inst.totalPayments} paid',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _inst.totalPayments > 0
                                ? _inst.paidPayments / _inst.totalPayments
                                : 0.0,
                            backgroundColor: Colors.grey[200],
                            color: statusColor,
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isOverdue
                              ? 'Overdue since ${DateFormat('dd MMM yyyy').format(_inst.dueDate)}'
                              : 'Next due ${DateFormat('dd MMM yyyy').format(_inst.dueDate)}',
                          style: TextStyle(
                            color: isOverdue
                                ? Colors.red[700]
                                : Colors.grey[600],
                            fontSize: 12,
                            fontWeight: isOverdue
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Customer info ──────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: _kBrand.withValues(alpha: 0.15),
                          child: const Icon(Icons.person, color: _kBrand),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _inst.customerName ?? 'Customer',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              if (_inst.customerPhone?.isNotEmpty == true) ...[
                                const SizedBox(height: 2),
                                Text(
                                  _inst.customerPhone!,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Payment history ────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Payment History',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (history.isEmpty)
                          const _EmptyPaymentHistory()
                        else
                          for (int i = 0; i < history.length; i++) ...[
                            _PaymentHistoryRow(
                              entry: history[i],
                              currency: currency,
                            ),
                            if (i != history.length - 1)
                              const SizedBox(height: 12),
                          ],
                      ],
                    ),
                  ),

                  // ── WhatsApp reminder (overdue only) ───────────────
                  if (isOverdue) ...[
                    const SizedBox(height: 24),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 380),
                        child: SizedBox(
                          width: double.infinity,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: ElevatedButton.icon(
                              onPressed: () => _sendWhatsAppReminder(context),
                              icon: const Icon(Icons.chat, size: 18),
                              label: const Text(
                                'Send WhatsApp Reminder',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _kBrand,
                                foregroundColor: Colors.black,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatBlock extends StatelessWidget {
  final String label;
  final String value;
  const _StatBlock({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _PaymentHistoryEntry {
  final String title;
  final DateTime date;
  final double amount;
  const _PaymentHistoryEntry({
    required this.title,
    required this.date,
    required this.amount,
  });
}

class _PaymentHistoryRow extends StatelessWidget {
  final _PaymentHistoryEntry entry;
  final NumberFormat currency;
  const _PaymentHistoryRow({required this.entry, required this.currency});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  size: 20,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('dd/MM/yyyy').format(entry.date),
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                currency.format(entry.amount),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'PAID',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyPaymentHistory extends StatelessWidget {
  const _EmptyPaymentHistory();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined, size: 28, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(
            'No payments recorded yet.',
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
        ],
      ),
    );
  }
}
