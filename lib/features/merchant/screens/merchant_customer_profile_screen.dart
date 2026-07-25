import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qistiraha/core/services/database_service.dart';
import 'package:qistiraha/features/merchant/widgets/merchant_plan_row.dart';
import 'merchant_installment_details_screen.dart';

const _kBrand = Color(0xFF99AFD7);
const _kBg = Color(0xFFF8F9FA);

/// A single customer's installment history at this store. Intentionally
/// shows nothing beyond name, phone, and their plans here — no credit
/// score, rating, or "standing" badge, for the customer's financial
/// privacy.
class MerchantCustomerProfileScreen extends StatelessWidget {
  final String customerName;
  final String? customerPhone;
  final List<InstallmentRow> plans;
  final NumberFormat currency;

  const MerchantCustomerProfileScreen({
    super.key,
    required this.customerName,
    required this.customerPhone,
    required this.plans,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = plans.toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

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
          'Customer',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: _kBrand.withValues(alpha: 0.15),
                  child: const Icon(Icons.person, color: _kBrand, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      if (customerPhone?.isNotEmpty == true) ...[
                        const SizedBox(height: 2),
                        Text(
                          customerPhone!,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: sorted.isEmpty
                ? Center(
                    child: Text(
                      'No installments for this customer.',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: sorted.length,
                    itemBuilder: (context, index) {
                      final p = sorted[index];
                      return MerchantPlanRow(
                        installment: p,
                        currency: currency,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MerchantInstallmentDetailsScreen(
                                installment: p,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
