import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:qistiraha/features/auth/models/business_account.dart';
import '../models/qist_link_payload.dart';
import 'qist_link_screen.dart';

/// "Generate Payment Link" screen — the merchant enters the sale details
/// here and gets a scannable QR / WhatsApp link back on [QistLinkScreen].
class MerchantPortalScreen extends StatefulWidget {
  final BusinessAccount business;
  const MerchantPortalScreen({super.key, required this.business});

  @override
  State<MerchantPortalScreen> createState() => _MerchantPortalScreenState();
}

class _MerchantPortalScreenState extends State<MerchantPortalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _assetNameController = TextEditingController();
  final _priceController = TextEditingController();
  final _termsController = TextEditingController();

  void _generateQR() {
    if (_formKey.currentState!.validate()) {
      final payload = QistLinkPayload(
        planId: const Uuid().v4(),
        merchantId: widget.business.id,
        merchantName: widget.business.businessName,
        item: _assetNameController.text,
        price: double.tryParse(_priceController.text) ?? 0.0,
        months: int.tryParse(_termsController.text) ?? 1,
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QistLinkScreen(payload: payload),
        ),
      );
    }
  }

  @override
  void dispose() {
    _assetNameController.dispose();
    _priceController.dispose();
    _termsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Generate Payment Link',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Log New Transaction',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter the details to generate a Qist-Link QR for the buyer.',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 32),
              _buildTextField(
                'Item Description',
                _assetNameController,
                Icons.shopping_bag,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                'Total Price (EGP)',
                _priceController,
                Icons.attach_money,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                'Installment Terms (Months)',
                _termsController,
                Icons.calendar_month,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      size: 18,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Buyer details are captured automatically from the '
                        "customer's account when they scan the link.",
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _generateQR,
                  icon: const Icon(Icons.qr_code),
                  label: const Text(
                    'Generate Qist-Link QR',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E2337),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.grey),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
          ),
          validator: (value) =>
              value == null || value.isEmpty ? 'Required' : null,
        ),
      ],
    );
  }
}
