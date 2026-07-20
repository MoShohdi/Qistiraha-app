import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qistiraha/core/utils/card_entrance_animation.dart';
import 'package:qistiraha/features/consumer/models/installment.dart';
import 'package:qistiraha/features/consumer/models/enums.dart';

const _kBrand = Color(0xFF99AFD7);

/// The installment card used on the merchant's Active Installments tab —
/// also reused verbatim on [MerchantCustomerProfileScreen] so a customer's
/// plan list looks identical to the main Active tab.
class MerchantPlanRow extends StatelessWidget {
  final Installment installment;
  final NumberFormat currency;
  final VoidCallback? onTap;

  const MerchantPlanRow({
    super.key,
    required this.installment,
    required this.currency,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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

    return GestureDetector(
      onTap: onTap,
      child: CardPopIn(
        id: installment.id,
        builder: (context, animate) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey[200]!),
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
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
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
              ).popInIf(animate, 0),
              const SizedBox(height: 4),
              Text(
                installment.customerName ?? 'Customer',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ).popInIf(animate, 1),
              const SizedBox(height: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${installment.paidPayments} of ${installment.totalPayments} paid',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      Text(
                        currency.format(installment.monthlyPayment),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: installment.totalPayments > 0
                          ? installment.paidPayments / installment.totalPayments
                          : 0.0,
                      backgroundColor: Colors.grey[200],
                      color: statusColor,
                      minHeight: 6,
                    ),
                  ),
                ],
              ).popInIf(animate, 2),
            ],
          ),
        ),
      ),
    );
  }
}
