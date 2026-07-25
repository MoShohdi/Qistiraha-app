import 'package:flutter/material.dart';
import 'package:qistiraha/core/services/database_service.dart';
import 'qist_link_screen.dart';

/// "Generate Payment Link" screen — the merchant enters the sale details
/// here, which creates a real `pending_scan` installment in Supabase, and
/// gets a scannable QR / WhatsApp link back on [QistLinkScreen].
class MerchantPortalScreen extends StatefulWidget {
  final Business business;
  const MerchantPortalScreen({super.key, required this.business});

  @override
  State<MerchantPortalScreen> createState() => _MerchantPortalScreenState();
}

class _MerchantPortalScreenState extends State<MerchantPortalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _assetNameController = TextEditingController();
  final _priceController = TextEditingController();
  final _termsController = TextEditingController();
  bool _generating = false;

  Future<void> _generateQR() async {
    if (!_formKey.currentState!.validate()) return;
    final item = _assetNameController.text.trim();
    final price = double.tryParse(_priceController.text) ?? 0.0;
    final months = int.tryParse(_termsController.text) ?? 1;

    setState(() => _generating = true);
    try {
      // Persist a pending_scan row now; the buyer claims it via the deep link.
      final id = await DatabaseService.createInstallment(
        itemDescription: item,
        totalAmount: price,
        months: months,
        merchantName: widget.business.name,
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QistLinkScreen(
            link: DatabaseService.deepLinkFor(id),
            webLink: DatabaseService.webClaimLinkFor(id),
            item: item,
            price: price,
            months: months,
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not create the payment link. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
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
                  onPressed: _generating ? null : _generateQR,
                  icon: _generating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.qr_code),
                  label: Text(
                    _generating ? 'Creating…' : 'Generate Qist-Link QR',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
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
