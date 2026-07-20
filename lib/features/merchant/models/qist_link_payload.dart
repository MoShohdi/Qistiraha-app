/// The data encoded into a merchant's Qist-Link — both the QR code and the
/// WhatsApp share link carry the exact same `qistiraha://pay?...` URI, so
/// scanning the QR or tapping the WhatsApp link trigger identical behavior
/// on the consumer's device.
class QistLinkPayload {
  final String planId;
  final String merchantId;
  final String merchantName;
  final String item;
  final double price;
  final int months;
  final String? buyerName;
  final String? buyerPhone;

  const QistLinkPayload({
    required this.planId,
    required this.merchantId,
    required this.merchantName,
    required this.item,
    required this.price,
    required this.months,
    this.buyerName,
    this.buyerPhone,
  });

  Uri toUri() {
    return Uri(
      scheme: 'qistiraha',
      host: 'pay',
      queryParameters: {
        'planId': planId,
        'merchantId': merchantId,
        'merchantName': merchantName,
        'item': item,
        'price': price.toString(),
        'months': months.toString(),
        if (buyerName != null && buyerName!.isNotEmpty) 'buyerName': buyerName!,
        if (buyerPhone != null && buyerPhone!.isNotEmpty)
          'buyerPhone': buyerPhone!,
      },
    );
  }

  static QistLinkPayload? fromUri(Uri uri) {
    if (uri.scheme != 'qistiraha' || uri.host != 'pay') return null;
    final q = uri.queryParameters;
    final merchantId = q['merchantId'];
    final item = q['item'];
    final price = double.tryParse(q['price'] ?? '');
    final months = int.tryParse(q['months'] ?? '');
    if (merchantId == null || item == null || price == null || months == null) {
      return null;
    }
    return QistLinkPayload(
      planId: q['planId'] ?? '',
      merchantId: merchantId,
      merchantName: q['merchantName'] ?? 'Merchant',
      item: item,
      price: price,
      months: months,
      buyerName: q['buyerName'],
      buyerPhone: q['buyerPhone'],
    );
  }
}
