import 'package:flutter/material.dart';
import 'package:qistiraha/features/consumer/models/installment.dart';

class LenderSelectionScreen extends StatelessWidget {
  final Installment installment;

  const LenderSelectionScreen({super.key, required this.installment});

  void _selectLender(BuildContext context, String lenderName) async {
    installment.provider = lenderName;
    installment.lender = lenderName; // keep for backward compatibility
    await installment.save();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Provider $lenderName applied to installment!')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<String> supportedLenders = [
      'Valu',
      'AMAN Holding',
      'Contact Financial Holding',
      'MNT-Halan',
      'Souhoola',
      'Premium Card',
      'Shahry',
      'Forsa',
      'Sympl',
      'Blnk',
      'Fawry',
      'one bank',
      'National Bank of Egypt (NBE)',
      'Banque Misr',
      'Commercial International Bank (CIB)',
      'QNB Alahli',
      'Banque du Caire',
      'Arab African International Bank (AAIB)',
      'HSBC Egypt',
      'AlexBank',
      'Credit Agricole Egypt',
      'Abu Dhabi Islamic Bank (ADIB) Egypt',
      'Emirates NBD Egypt',
      'EG Bank',
      'Mashreq Bank Egypt',
      'saib Bank',
      'Housing and Development Bank (HDB)',
      'Other'
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text('Select Lender', style: TextStyle(color: Colors.black)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: supportedLenders.length,
        itemBuilder: (context, index) {
          var lender = supportedLenders[index];
          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey[300]!),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              title: Text(lender, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text('Please contact your lender for late fees details.', style: TextStyle(color: Colors.grey[700])),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _selectLender(context, lender),
            ),
          );
        },
      ),
    );
  }
}
