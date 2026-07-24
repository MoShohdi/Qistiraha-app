import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qistiraha/core/services/database_service.dart';
import 'qist_link_desktop.dart';

const _kBrand = Color(0xFF99AFD7);
const _kInk = Color(0xFF1E2337);
const _kBg = Color(0xFFF8F9FA);

/// Desktop/web rendition of the "Generate Payment Link" form — same three
/// data fields and [QistLinkPayload] construction as the mobile
/// [MerchantPortalScreen], laid out Stripe-style for a wide viewport: a
/// constrained, centered split layout with the transaction form on the left
/// and a live link preview on the right that recomputes as the merchant
/// types. Buyer name/phone are deliberately absent — the consumer's account
/// supplies them automatically when the link is scanned.
class MerchantPortalDesktopScreen extends StatefulWidget {
  final Business business;
  const MerchantPortalDesktopScreen({super.key, required this.business});

  @override
  State<MerchantPortalDesktopScreen> createState() =>
      _MerchantPortalDesktopScreenState();
}

class _MerchantPortalDesktopScreenState
    extends State<MerchantPortalDesktopScreen> {
  final _formKey = GlobalKey<FormState>();
  final _assetNameController = TextEditingController();
  final _priceController = TextEditingController();
  final _termsController = TextEditingController();
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    // Live preview: any keystroke in the three fields re-renders the
    // right-hand summary panel.
    _assetNameController.addListener(_onFieldChanged);
    _priceController.addListener(_onFieldChanged);
    _termsController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() => setState(() {});

  @override
  void dispose() {
    _assetNameController.dispose();
    _priceController.dispose();
    _termsController.dispose();
    super.dispose();
  }

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
          builder: (context) => QistLinkDesktopScreen(
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          const _PortalDesktopHeader(title: 'Generate Payment Link'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: _buildFormCard()),
                      const SizedBox(width: 24),
                      Expanded(flex: 2, child: _buildPreviewPanel()),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Transaction Details',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Enter the sale details to generate a Qist-Link for the buyer.',
                    style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 24),
                  _buildLabel('Item Description'),
                  _buildTextField(
                    _assetNameController,
                    'e.g., Winter Abaya Set',
                    suffixIcon: Icons.shopping_bag_outlined,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Total Price'),
                            _buildTextField(
                              _priceController,
                              '0.00',
                              suffixText: 'EGP',
                              keyboardType: TextInputType.number,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Installment Terms'),
                            _buildTextField(
                              _termsController,
                              'e.g., 6',
                              suffixText: 'Months',
                              keyboardType: TextInputType.number,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        size: 17,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Buyer details are captured automatically from the '
                          "customer's account when they scan the link — "
                          'nothing to type here.',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.grey[200]),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              child: Row(
                children: [
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const Spacer(),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: ElevatedButton.icon(
                      onPressed: _generating ? null : _generateQR,
                      icon: _generating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.qr_code, size: 18),
                      label: Text(
                        _generating ? 'Creating…' : 'Generate Qist-Link',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kInk,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Right-hand "what the buyer sees" panel — a receipt-style dark card
  /// that live-updates from the three form fields. Everything shown is
  /// derived from the entered data (no fabricated values): the per-payment
  /// figure is simply price / months.
  Widget _buildPreviewPanel() {
    final currency = NumberFormat.currency(symbol: 'EGP ', decimalDigits: 0);
    final item = _assetNameController.text.trim();
    final price = double.tryParse(_priceController.text);
    final months = int.tryParse(_termsController.text);
    final monthly = (price != null && months != null && months > 0)
        ? price / months
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            'LINK PREVIEW',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
              color: Colors.grey[500],
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_kInk, Color(0xFF2A3150)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: _kInk.withValues(alpha: 0.25),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.storefront,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.business.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                item.isEmpty ? 'Item description' : item,
                style: TextStyle(
                  color: item.isEmpty
                      ? Colors.white.withValues(alpha: 0.35)
                      : Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                price != null ? currency.format(price) : 'EGP —',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                months != null && months > 0
                    ? 'over $months month${months == 1 ? '' : 's'}'
                    : 'over — months',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 18),
              Divider(color: Colors.white.withValues(alpha: 0.12), height: 1),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Monthly Payment',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12.5,
                    ),
                  ),
                  Text(
                    monthly != null ? currency.format(monthly) : 'EGP —',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _kBrand.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _kBrand.withValues(alpha: 0.30)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.qr_code_scanner, size: 17, color: _kInk),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'The buyer scans the QR (or taps the WhatsApp link) and '
                  'confirms the plan in their own app.',
                  style: TextStyle(
                    color: Colors.grey[800],
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12.5,
          color: Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    IconData? suffixIcon,
    String? suffixText,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400]),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _kBrand, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red),
        ),
        suffixIcon: suffixIcon != null
            ? Icon(suffixIcon, color: Colors.grey, size: 20)
            : null,
        suffixText: suffixText,
      ),
      validator: (value) =>
          value == null || value.isEmpty ? 'Required field' : null,
    );
  }
}

/// Slim white top bar shared by the desktop payment-link screens: Back
/// button, hairline divider, page title.
class _PortalDesktopHeader extends StatelessWidget {
  final String title;
  const _PortalDesktopHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text(
                'Back',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              style: TextButton.styleFrom(foregroundColor: Colors.black87),
            ),
          ),
          Container(
            width: 1,
            height: 20,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: Colors.grey[300],
          ),
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
