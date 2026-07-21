import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qistiraha/core/services/hive_service.dart';
import 'package:qistiraha/features/consumer/models/installment.dart';
import 'package:qistiraha/features/consumer/models/enums.dart';

const _kBrand = Color(0xFF99AFD7);
const _kBg = Color(0xFFF8F9FA);

/// Read-only view of a single consumer's installment plan, as seen by the
/// merchant. Merchants can review the contract terms and nudge overdue
/// buyers via WhatsApp, but cannot edit anything here — the contract
/// belongs to the consumer, who manages payments from their own app.
class MerchantInstallmentDetailsScreen extends StatelessWidget {
  final Installment installment;

  const MerchantInstallmentDetailsScreen({
    super.key,
    required this.installment,
  });

  /// Builds one row per completed payment, newest first. Amounts come from
  /// [Installment.pastPayments] when available (falling back to the plan's
  /// standard [Installment.monthlyPayment] for older records that predate
  /// that field); dates are approximated backward from [Installment.dueDate]
  /// in payment-period increments, since the model only stores an exact
  /// timestamp for the most recent payment.
  List<_PaymentHistoryEntry> _paymentHistory() {
    final int paid = installment.paidPayments;
    if (paid <= 0) return [];

    final entries = <_PaymentHistoryEntry>[];
    for (int i = paid - 1; i >= 0; i--) {
      final double amount = i < installment.pastPayments.length
          ? installment.pastPayments[i]
          : installment.monthlyPayment;
      final DateTime approxDate = installment.dueDateForPeriodsBack(paid - i);
      entries.add(
        _PaymentHistoryEntry(
          title: 'Payment ${i + 1} of ${installment.totalPayments}',
          date: approxDate,
          amount: amount,
        ),
      );
    }
    return entries;
  }

  Future<void> _sendWhatsAppReminder(BuildContext context) async {
    final phone = installment.customerPhone ?? '';
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No phone number on file for this customer.'),
        ),
      );
      return;
    }

    final currency = NumberFormat.currency(symbol: 'EGP ', decimalDigits: 0);
    final buyerName = installment.customerName ?? 'there';
    final message =
        'Hello $buyerName, this is a friendly reminder from '
        '${installment.merchantName} that your installment of '
        '${currency.format(installment.monthlyPayment)} for the '
        '${installment.itemDescription} is currently due.';

    final whatsappUri = Uri.parse(
      'https://wa.me/$digits?text=${Uri.encodeComponent(message)}',
    );

    final launched = await launchUrl(
      whatsappUri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open WhatsApp. Is it installed?'),
        ),
      );
    }
  }

  /// Voids the contract entirely — for when the customer returned the item
  /// or settled the remaining balance in cash outside the app. Unlike the
  /// consumer side (which can never delete a merchant-linked plan), the
  /// merchant has the final say here since it's their sale record.
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

    final businessBox = HiveService.getBusinessBox();
    for (final business in businessBox.values) {
      if (business.id == installment.merchantId) {
        business.sentQists?.remove(installment);
        await business.save();
        break;
      }
    }
    await installment.delete();

    if (context.mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: 'EGP ', decimalDigits: 0);
    final bool isOverdue = installment.statusEnum == InstallmentStatus.overdue;
    final history = _paymentHistory();

    Color statusColor;
    String statusLabel;
    switch (installment.statusEnum) {
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

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Installment Details',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: 'Cancel Contract',
            onPressed: () => _cancelContract(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
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
                                  installment.itemDescription,
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
                                  value: currency.format(installment.amount),
                                ),
                              ),
                              Expanded(
                                child: _StatBlock(
                                  label: installment.paymentFrequencyLabel,
                                  value: currency.format(
                                    installment.monthlyPayment,
                                  ),
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
                                '${installment.paidPayments} of ${installment.totalPayments} paid',
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
                              value: installment.totalPayments > 0
                                  ? installment.paidPayments /
                                        installment.totalPayments
                                  : 0.0,
                              backgroundColor: Colors.grey[200],
                              color: statusColor,
                              minHeight: 8,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isOverdue
                                ? 'Overdue since ${DateFormat('dd MMM yyyy').format(installment.dueDate)}'
                                : 'Next due ${DateFormat('dd MMM yyyy').format(installment.dueDate)}',
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
                                  installment.customerName ?? 'Customer',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                if (installment.customerPhone?.isNotEmpty ==
                                    true) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    installment.customerPhone!,
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
                            _EmptyPaymentHistory()
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
                  ],
                ),
              ),
            ),

            // ── WhatsApp reminder (overdue only) ──────────────────────
            if (isOverdue)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _sendWhatsAppReminder(context),
                      icon: const Icon(Icons.chat),
                      label: const Text(
                        'Send WhatsApp Reminder',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kBrand,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
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

/// A single completed-payment row — mirrors the consumer-side history
/// timeline (light grey pill, green checkmark, "PAID" badge) so a merchant
/// reviewing a contract sees the same visual language as the buyer does.
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
