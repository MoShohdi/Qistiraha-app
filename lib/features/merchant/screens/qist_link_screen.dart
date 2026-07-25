import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

const _kBrand = Color(0xFF99AFD7);

/// Success screen shown after a merchant generates a Qist-Link. [link] is the
/// real Supabase deep link (`qistiraha://installment/<id>`) for the freshly
/// created `pending_scan` row — scanning/tapping it opens the consumer's claim
/// flow, which reads that row and attaches the consumer's account to it.
class QistLinkScreen extends StatelessWidget {
  /// Native deep link (`qistiraha://installment/<id>`) — encoded in the QR for
  /// in-app scanning.
  final String link;

  /// Web link (`https://<host>/?claim_id=<id>`) — the pasteable/shareable URL
  /// used for copy + WhatsApp, so a buyer on any device (desktop browser too)
  /// can open it.
  final String webLink;
  final String item;
  final double price;
  final int months;

  const QistLinkScreen({
    super.key,
    required this.link,
    required this.webLink,
    required this.item,
    required this.price,
    required this.months,
  });

  /// The QR MUST encode the native custom scheme (`qistiraha://installment/…`)
  /// so scanning it opens the app directly. It deliberately does NOT use the
  /// https web link — that would trap a phone in the mobile browser on
  /// `http(s)://…` (no Universal Links in local dev). The web link is used only
  /// for the Copy and WhatsApp-share buttons below.
  String get _nativeQrLink => link;

  Future<void> _shareViaWhatsApp(BuildContext context) async {
    final currency = NumberFormat.currency(symbol: 'EGP ', decimalDigits: 0);
    final message =
        'Here is your Qistiraha installment plan for $item '
        '(${currency.format(price)} over $months months). '
        'Click here to add it to your app: $webLink';

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open WhatsApp. Is it installed?'),
        ),
      );
    }
  }

  void _copyLink(BuildContext context) {
    Clipboard.setData(ClipboardData(text: webLink));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Link copied to clipboard')));
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
          'Qist-Link QR',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text(
              item,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Show this to the buyer to add the installment',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: QrImageView(
                data: _nativeQrLink,
                version: QrVersions.auto,
                size: 240.0,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => _copyLink(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        webLink,
                        style: TextStyle(color: Colors.grey[700], fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.copy, size: 16, color: _kBrand),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _shareViaWhatsApp(context),
                icon: const Icon(Icons.chat),
                label: const Text(
                  'Share via WhatsApp',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.done),
                label: const Text('Done'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black,
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
    );
  }
}
