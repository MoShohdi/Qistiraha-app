import 'package:flutter/material.dart';
import 'qist_link_screen.dart';

class MerchantPortalScreen extends StatefulWidget {
  const MerchantPortalScreen({super.key});

  @override
  State<MerchantPortalScreen> createState() => _MerchantPortalScreenState();
}

class _MerchantPortalScreenState extends State<MerchantPortalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _assetNameController = TextEditingController();
  final _priceController = TextEditingController();
  final _termsController = TextEditingController();
  final _buyerPhoneController = TextEditingController();

  void _generateQR() {
    if (_formKey.currentState!.validate()) {
      Map<String, dynamic> payload = {
        'assetName': _assetNameController.text,
        'price': double.tryParse(_priceController.text) ?? 0.0,
        'terms': int.tryParse(_termsController.text) ?? 1,
        'buyerPhone': _buyerPhoneController.text,
      };

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QistLinkScreen(transactionData: payload),
        ),
      );
    }
  }

  @override
  void dispose() {
    _assetNameController.dispose();
    _priceController.dispose();
    _termsController.dispose();
    _buyerPhoneController.dispose();
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
          'Merchant Portal',
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
              _buildTextField('Asset Name', _assetNameController, Icons.shopping_bag),
              const SizedBox(height: 16),
              _buildTextField('Price (EGP)', _priceController, Icons.attach_money, keyboardType: TextInputType.number),
              const SizedBox(height: 16),
              _buildTextField('Terms (Months)', _termsController, Icons.calendar_month, keyboardType: TextInputType.number),
              const SizedBox(height: 16),
              _buildTextField('Buyer Phone', _buyerPhoneController, Icons.phone, keyboardType: TextInputType.phone),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _generateQR,
                  icon: const Icon(Icons.qr_code),
                  label: const Text('Generate Qist-Link QR', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
          validator: (value) => value == null || value.isEmpty ? 'Required' : null,
        ),
      ],
    );
  }
}
