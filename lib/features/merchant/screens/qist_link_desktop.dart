import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qistiraha/core/utils/responsive_layout.dart';
import '../models/qist_link_payload.dart';

const _kBrand = Color(0xFF99AFD7);
const _kInk = Color(0xFF1E2337);
const _kBg = Color(0xFFF8F9FA);
const _kWhatsApp = Color(0xFF25D366);

/// Desktop/web rendition of the Qist-Link success screen — same
/// [QistLinkPayload], link URI, copy and WhatsApp-share actions as the
/// mobile [QistLinkScreen], laid out as a centered split card: the QR on
/// the left, the plan summary and share actions on the right. Uses the
/// floating desktop toast instead of full-width mobile snackbars.
class QistLinkDesktopScreen extends StatelessWidget {
  final QistLinkPayload payload;

  const QistLinkDesktopScreen({super.key, required this.payload});

  String get _link => payload.toUri().toString();

  Future<void> _shareViaWhatsApp(BuildContext context) async {
    final currency = NumberFormat.currency(symbol: 'EGP ', decimalDigits: 0);
    final message =
        'Here is your Qistiraha installment plan for ${payload.item} '
        '(${currency.format(payload.price)} over ${payload.months} months). '
        'Click here to add it to your app: $_link';

    // No recipient prefill — the merchant picks the chat; buyer identity
    // is supplied by the consumer's own account when they open the link.
    final whatsappUri = Uri.parse(
      'https://wa.me/?text=${Uri.encodeComponent(message)}',
    );

    final launched = await launchUrl(
      whatsappUri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      showDesktopSnackBar(
        context,
        message: 'Could not open WhatsApp. Is it installed?',
      );
    }
  }

  void _copyLink(BuildContext context) {
    Clipboard.setData(ClipboardData(text: _link));
    showDesktopSnackBar(context, message: 'Link copied to clipboard');
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: 'EGP ', decimalDigits: 0);
    final monthly = payload.months > 0
        ? payload.price / payload.months
        : payload.price;

    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          const _QistLinkDesktopHeader(title: 'Qist-Link QR'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 880),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey[200]!),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 4, child: _buildQrPane()),
                          VerticalDivider(width: 1, color: Colors.grey[200]),
                          Expanded(
                            flex: 5,
                            child: _buildDetailsPane(
                              context,
                              currency,
                              monthly,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrPane() {
    return Container(
      padding: const EdgeInsets.all(36),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            // Tight SizedBox so the enclosing IntrinsicHeight never asks
            // QrImageView (which uses a LayoutBuilder internally, and
            // LayoutBuilder cannot report intrinsics) to measure itself.
            child: SizedBox(
              width: 240,
              height: 240,
              child: QrImageView(
                data: _link,
                version: QrVersions.auto,
                size: 240.0,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.qr_code_scanner, size: 15, color: Colors.grey[500]),
              const SizedBox(width: 6),
              Text(
                'Buyer scans this to add the plan',
                style: TextStyle(color: Colors.grey[500], fontSize: 12.5),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsPane(
    BuildContext context,
    NumberFormat currency,
    double monthly,
  ) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Qist-Link ready',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 40),
            child: Text(
              'Share it however the buyer prefers.',
              style: TextStyle(color: Colors.grey[500], fontSize: 12.5),
            ),
          ),
          const SizedBox(height: 22),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _kBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                _SummaryRow(label: 'Item', value: payload.item),
                const SizedBox(height: 10),
                _SummaryRow(
                  label: 'Total Price',
                  value: currency.format(payload.price),
                ),
                const SizedBox(height: 10),
                _SummaryRow(
                  label: 'Terms',
                  value:
                      '${payload.months} month${payload.months == 1 ? '' : 's'}',
                ),
                const SizedBox(height: 10),
                _SummaryRow(
                  label: 'Monthly Payment',
                  value: currency.format(monthly),
                  emphasized: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => _copyLink(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _link,
                        style: TextStyle(color: Colors.grey[700], fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.copy, size: 15, color: _kBrand),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: ElevatedButton.icon(
                    onPressed: () => _shareViaWhatsApp(context),
                    icon: const Icon(Icons.chat, size: 18),
                    label: const Text(
                      'Share via WhatsApp',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kWhatsApp,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: OutlinedButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kInk,
                    side: BorderSide(color: Colors.grey[300]!),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(fontWeight: FontWeight.bold),
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

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasized;
  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12.5)),
        Text(
          value,
          style: TextStyle(
            fontWeight: emphasized ? FontWeight.bold : FontWeight.w600,
            fontSize: emphasized ? 14.5 : 13,
          ),
        ),
      ],
    );
  }
}

class _QistLinkDesktopHeader extends StatelessWidget {
  final String title;
  const _QistLinkDesktopHeader({required this.title});

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
