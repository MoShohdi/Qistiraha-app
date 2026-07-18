import 'package:flutter/material.dart';
import 'package:qistiraha/features/consumer/models/installment.dart';

class LenderSelectionScreen extends StatelessWidget {
  final Installment installment;

  const LenderSelectionScreen({super.key, required this.installment});

  void _selectLender(BuildContext context, String lenderName) async {
    installment.lender = lenderName;
    await installment.save();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rule for $lenderName applied to installment!')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lenders = [
      {'name': 'Valu', 'desc': '10% Max on unpaid monthly installment if 5 days late.'},
      {'name': 'SYMPL', 'desc': '25 EGP flat per late payment.'},
      {'name': 'Shahry', 'desc': '7-15% on due installment if 5 days late.'},
      {'name': 'MiniCash', 'desc': '6% (Min 60 LE) starts 5 days after due date.'},
      {'name': 'CIB', 'desc': '150 EGP flat + 3.99% monthly interest.'},
      {'name': 'Other', 'desc': 'Custom or currently unsupported lender.'},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text('Select Lender Rule', style: TextStyle(color: Colors.black)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: lenders.length,
        itemBuilder: (context, index) {
          var lender = lenders[index];
          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey[300]!),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              title: Text(lender['name']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(lender['desc']!, style: TextStyle(color: Colors.grey[700])),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _selectLender(context, lender['name']!),
            ),
          );
        },
      ),
    );
  }
}
