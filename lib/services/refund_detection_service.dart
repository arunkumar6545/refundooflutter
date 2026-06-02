import '../models/refund_item.dart';

/// Detects refund-related content in raw SMS/email text.
/// Runs locally on device; no server storage.
class RefundDetectionService {
  static const _refundKeywords = [
    'refund',
    'refunded',
    'refunding',
    'reimbursement',
    'return processed',
    'money back',
    'credited back',
    'credit to your',
    'refund of',
    'refund has been',
    'refund initiated',
    'refund processed',
    'refund confirmation',
    'refund request approved',
  ];

  // Group 1 = currency prefix, Group 2 = numeric amount
  // Matches: $34.99 | Rs 499 | Rs.1,299.00 | INR 500 | ₹ 249 | €12 | £8.99 | ¥300
  static final _amountRegex = RegExp(
    r'(\$|Rs\.?\s*|INR\s*|₹\s*|€\s*|£\s*|¥\s*)(\d+(?:,\d{3})*(?:\.\d{2})?)',
    caseSensitive: false,
  );

  /// Mapping from raw detected prefix to a clean symbol.
  static String _normaliseCurrency(String raw) {
    final t = raw.trim().toUpperCase();
    if (t.startsWith('RS') || t == 'INR' || t == '₹') return '₹';
    if (t == '\$') return '\$';
    if (t == '€') return '€';
    if (t == '£') return '£';
    if (t == '¥') return '¥';
    return raw.trim();
  }

  static final _orderIdRegex = RegExp(
    r'(?:order|ref|reference|confirmation)\s*#?\s*(\d{4,})',
    caseSensitive: false,
  );

  /// Returns true if the text likely describes a refund.
  bool looksLikeRefund(String text) {
    final lower = text.toLowerCase();
    return _refundKeywords.any((k) => lower.contains(k));
  }

  /// Tries to extract a refund amount from text. Returns null if none found.
  double? extractAmount(String text) {
    final match = _amountRegex.firstMatch(text);
    if (match == null) return null;
    final amountStr = match.group(2)?.replaceAll(',', '') ?? '';
    return double.tryParse(amountStr);
  }

  /// Detects the currency symbol from text. Returns '₹' as fallback.
  String extractCurrency(String text) {
    final match = _amountRegex.firstMatch(text);
    if (match == null) return '₹';
    return _normaliseCurrency(match.group(1) ?? '₹');
  }

  /// Tries to extract an order/reference ID.
  String? extractOrderId(String text) {
    final match = _orderIdRegex.firstMatch(text);
    return match?.group(1);
  }

  /// Infers category from sender or content (best-effort).
  RefundCategory? inferCategory(String sender, String body) {
    final combined = '${sender.toLowerCase()} ${body.toLowerCase()}';
    if (combined.contains('flight') ||
        combined.contains('airline') ||
        combined.contains('hotel') ||
        combined.contains('travel') ||
        combined.contains('delta') ||
        combined.contains('irctc') ||
        combined.contains('train') ||
        combined.contains('indigo') ||
        combined.contains('makemytrip') ||
        combined.contains('booking')) {
      return RefundCategory.travel;
    }
    if (combined.contains('amazon') ||
        combined.contains('flipkart') ||
        combined.contains('myntra') ||
        combined.contains('meesho') ||
        combined.contains('nykaa') ||
        combined.contains('retail') ||
        combined.contains('store') ||
        combined.contains('shipping') ||
        combined.contains('order')) {
      return RefundCategory.retail;
    }
    if (combined.contains('subscription') ||
        combined.contains('service') ||
        combined.contains('support') ||
        combined.contains('invoice') ||
        combined.contains('jio') ||
        combined.contains('airtel') ||
        combined.contains('recharge')) {
      return RefundCategory.services;
    }
    if (combined.contains('restaurant') ||
        combined.contains('delivery') ||
        combined.contains('food') ||
        combined.contains('zomato') ||
        combined.contains('swiggy') ||
        combined.contains('doordash') ||
        combined.contains('ubereats') ||
        combined.contains('grubhub')) {
      return RefundCategory.foodDining;
    }
    if (combined.contains('electronics') ||
        combined.contains('laptop') ||
        combined.contains('mobile') ||
        combined.contains('croma') ||
        combined.contains('reliance digital') ||
        combined.contains('tech') ||
        combined.contains('best buy')) {
      return RefundCategory.electronics;
    }
    if (combined.contains('ticket') ||
        combined.contains('movie') ||
        combined.contains('bookmyshow') ||
        combined.contains('streaming') ||
        combined.contains('netflix') ||
        combined.contains('hotstar') ||
        combined.contains('prime video') ||
        combined.contains('event') ||
        combined.contains('concert')) {
      return RefundCategory.entertainment;
    }
    return null;
  }

  /// Builds a RefundItem from raw message content (SMS or email body).
  RefundItem? parseRefund({
    required String id,
    required String sourceText,
    String? sender,
    required RefundSource source,
    DateTime? date,
  }) {
    if (!looksLikeRefund(sourceText)) return null;
    final amount = extractAmount(sourceText);
    if (amount == null || amount <= 0) return null;
    final currency = extractCurrency(sourceText);
    final orderId = extractOrderId(sourceText);
    final merchant = sender ?? 'Unknown';
    final category = inferCategory(merchant, sourceText);
    return RefundItem(
      id: id,
      merchantName: merchant,
      amount: amount,
      status: RefundStatus.processing,
      source: source,
      currency: currency,
      orderId: orderId,
      category: category,
      rawSnippet: sourceText.length > 200 ? '${sourceText.substring(0, 200)}...' : sourceText,
      detectedAt: date ?? DateTime.now(),
    );
  }
}
