import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qistiraha/core/services/database_service.dart';
import 'package:qistiraha/core/theme/app_theme.dart';
import 'package:qistiraha/core/utils/responsive_layout.dart';
import 'package:qistiraha/widgets/desktop/app_modal.dart';

/// Launches the merchant "Generate Payment Link" flow as a constrained
/// [AppModal] directly over the dashboard. Two phases in one modal: a small
/// details form, then the Qist-Link result (native-scheme QR + web copy/share).
Future<void> showGeneratePaymentLinkModal(
  BuildContext context,
  Business business,
) {
  return showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (_) => _GeneratePaymentLinkModal(business: business),
  );
}

class _GeneratePaymentLinkModal extends StatefulWidget {
  final Business business;
  const _GeneratePaymentLinkModal({required this.business});

  @override
  State<_GeneratePaymentLinkModal> createState() =>
      _GeneratePaymentLinkModalState();
}

class _GeneratePaymentLinkModalState extends State<_GeneratePaymentLinkModal> {
  final _formKey = GlobalKey<FormState>();
  final _itemController = TextEditingController();
  final _priceController = TextEditingController();
  final _termsController = TextEditingController();
  final _currency = NumberFormat.currency(symbol: 'EGP ', decimalDigits: 0);
  static const _kWhatsApp = Color(0xFF25D366);

  bool _generating = false;

  // Result (null until the link is created).
  String? _nativeLink;
  String? _webLink;
  String _item = '';
  double _price = 0;
  int _months = 1;

  bool get _hasResult => _nativeLink != null;

  @override
  void dispose() {
    _itemController.dispose();
    _priceController.dispose();
    _termsController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (!_formKey.currentState!.validate()) return;
    final item = _itemController.text.trim();
    final price = double.tryParse(_priceController.text) ?? 0.0;
    final months = int.tryParse(_termsController.text) ?? 1;

    setState(() => _generating = true);
    try {
      final id = await DatabaseService.createInstallment(
        itemDescription: item,
        totalAmount: price,
        months: months,
        merchantName: widget.business.name,
      );
      if (!mounted) return;
      setState(() {
        _item = item;
        _price = price;
        _months = months;
        _nativeLink = DatabaseService.deepLinkFor(id);
        _webLink = DatabaseService.webClaimLinkFor(id);
        _generating = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _generating = false);
        showDesktopSnackBar(
          context,
          message: 'Could not create the payment link. Try again.',
        );
      }
    }
  }

  void _copyLink() {
    Clipboard.setData(ClipboardData(text: _webLink!));
    showDesktopSnackBar(context, message: 'Link copied to clipboard');
  }

  Future<void> _shareWhatsApp() async {
    final message =
        'Here is your Qistiraha installment plan for $_item '
        '(${_currency.format(_price)} over $_months months). '
        'Click here to add it to your app: $_webLink';
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}');
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      showDesktopSnackBar(context, message: 'Could not open WhatsApp.');
    }
  }

  @override
  Widget build(BuildContext context) => _hasResult ? _result() : _form();

  // ── Phase 1: details form ────────────────────────────────────────────────
  AppModal _form() {
    return AppModal(
      title: 'Generate Payment Link',
      subtitle: 'Enter the sale details to create a Qist-Link for the buyer.',
      maxWidth: 460,
      actions: [
        TextButton(
          onPressed: _generating ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _generating ? null : _generate,
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
          label: Text(_generating ? 'Creating…' : 'Generate Link'),
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _label('Item Description'),
            TextFormField(
              controller: _itemController,
              decoration: const InputDecoration(hintText: 'e.g., 55" Smart TV'),
              validator: _required,
            ),
            const SizedBox(height: AppSpacing.lg),
            _label('Total Price'),
            TextFormField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: '0.00',
                suffixText: 'EGP',
              ),
              validator: _required,
            ),
            const SizedBox(height: AppSpacing.lg),
            _label('Installment Terms'),
            TextFormField(
              controller: _termsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'e.g., 12',
                suffixText: 'months',
              ),
              validator: _required,
            ),
            const SizedBox(height: AppSpacing.lg),
            _infoNote(
              'Buyer name and account are attached automatically when they '
              'scan and confirm — no personal details needed here.',
            ),
          ],
        ),
      ),
    );
  }

  // ── Phase 2: Qist-Link result ────────────────────────────────────────────
  AppModal _result() {
    final monthly = _months > 0 ? _price / _months : _price;
    return AppModal(
      title: 'Qist-Link Ready',
      subtitle: 'Share it however the buyer prefers.',
      maxWidth: 460,
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
        ElevatedButton.icon(
          onPressed: _shareWhatsApp,
          style: ElevatedButton.styleFrom(backgroundColor: _kWhatsApp),
          icon: const Icon(Icons.chat, size: 18),
          label: const Text('Share'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadii.mdAll,
                border: Border.all(color: AppColors.border),
                boxShadow: AppShadows.card,
              ),
              // Fixed box so QrImageView (LayoutBuilder-based) is never asked
              // to self-measure inside the scrolling column.
              child: SizedBox(
                width: 190,
                height: 190,
                child: QrImageView(
                  data: _nativeLink!, // native qistiraha:// scheme
                  version: QrVersions.auto,
                  size: 190,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Center(
            child: Text(
              'Buyer scans this to open the app',
              style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _summaryRow('Item', _item),
          _summaryRow('Total', _currency.format(_price)),
          _summaryRow('Terms', '$_months month${_months == 1 ? '' : 's'}'),
          _summaryRow('Monthly', _currency.format(monthly), emphasized: true),
          const SizedBox(height: AppSpacing.lg),
          _label('Web link'),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: _copyLink,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: AppRadii.smAll,
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _webLink!,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    const Icon(Icons.copy, size: 15, color: AppColors.accent),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── helpers ──────────────────────────────────────────────────────────────
  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 12.5,
        color: AppColors.textSecondary,
      ),
    ),
  );

  Widget _summaryRow(String label, String value, {bool emphasized = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.5,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: emphasized ? FontWeight.w700 : FontWeight.w600,
              fontSize: emphasized ? 14.5 : 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoNote(String text) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: AppRadii.smAll,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.verified_user_outlined,
            size: 16,
            color: AppColors.textTertiary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
