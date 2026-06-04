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

  // ── Bank name extraction ───────────────────────────────────────────────────
  static final _bankPatterns = <String, RegExp>{
    'HDFC Bank':    RegExp(r'\bhdfc\b',       caseSensitive: false),
    'SBI':          RegExp(r'\bsbi\b|\bstate bank\b', caseSensitive: false),
    'ICICI Bank':   RegExp(r'\bicici\b',       caseSensitive: false),
    'Axis Bank':    RegExp(r'\baxis\b',        caseSensitive: false),
    'Kotak Bank':   RegExp(r'\bkotak\b',       caseSensitive: false),
    'Yes Bank':     RegExp(r'\byes bank\b',    caseSensitive: false),
    'PNB':          RegExp(r'\bpnb\b|\bpunjab national\b', caseSensitive: false),
    'Canara Bank':  RegExp(r'\bcanara\b',      caseSensitive: false),
    'Union Bank':   RegExp(r'\bunion bank\b',  caseSensitive: false),
    'IDFC Bank':    RegExp(r'\bidfc\b',        caseSensitive: false),
    'Federal Bank': RegExp(r'\bfederal bank\b', caseSensitive: false),
    'RBL Bank':     RegExp(r'\brbl\b',         caseSensitive: false),
    'IndusInd Bank':RegExp(r'\bindusind\b',    caseSensitive: false),
    'Bank of Baroda':RegExp(r'\bbaroda\b|\bbob\b', caseSensitive: false),
    'Paytm Payments Bank': RegExp(r'\bpaytm payments bank\b', caseSensitive: false),
    'HSBC':         RegExp(r'\bhsbc\b',        caseSensitive: false),
    'Citi Bank':    RegExp(r'\bciti\b',        caseSensitive: false),
    'Chase':        RegExp(r'\bchase\b',       caseSensitive: false),
    'Bank of America': RegExp(r'\bbank of america\b|\bboa\b', caseSensitive: false),
    'Wells Fargo':  RegExp(r'\bwells fargo\b', caseSensitive: false),
    'Barclays':     RegExp(r'\bbarclays\b',    caseSensitive: false),
  };

  // ── Destination type extraction ────────────────────────────────────────────
  static final _destPatterns = <RefundDestination, RegExp>{
    RefundDestination.upi:         RegExp(r'\bupi\b|\bvpa\b|\bupi id\b', caseSensitive: false),
    RefundDestination.wallet:      RegExp(r'\bwallet\b|\bpaytm\b|\bphonepe\b|\bgpay\b|\bgoogle pay\b|\bamazon pay\b|\bmobikwik\b', caseSensitive: false),
    RefundDestination.creditCard:  RegExp(r'\bcredit card\b|\bcc\b', caseSensitive: false),
    RefundDestination.debitCard:   RegExp(r'\bdebit card\b|\bdc\b', caseSensitive: false),
    RefundDestination.bankAccount: RegExp(r'\bbank account\b|\bsavings account\b|\bcurrent account\b|\bneft\b|\bimps\b|\brtgs\b|\baccount ending\b|\baccount no\b', caseSensitive: false),
  };

  // ── Issuer / company extraction ────────────────────────────────────────────
  static const _issuers = [
    'Amazon', 'Flipkart', 'Myntra', 'Meesho', 'Nykaa', 'Ajio',
    'Zomato', 'Swiggy', 'Blinkit', 'BigBasket',
    'Ola', 'Uber', 'Rapido',
    'MakeMyTrip', 'GoIbibo', 'IRCTC', 'IndiGo', 'Air India',
    'BookMyShow', 'Netflix', 'Hotstar', 'Zee5', 'SonyLIV',
    'Jio', 'Airtel', 'Vi', 'BSNL',
    'Croma', 'Reliance Digital',
    'Paytm', 'PhonePe', 'Google Pay',
    'Apple', 'Google', 'Microsoft',
  ];

  String? extractBankName(String text) {
    for (final entry in _bankPatterns.entries) {
      if (entry.value.hasMatch(text)) return entry.key;
    }
    return null;
  }

  RefundDestination extractDestination(String text) {
    for (final entry in _destPatterns.entries) {
      if (entry.value.hasMatch(text)) return entry.key;
    }
    return RefundDestination.unknown;
  }

  String? extractIssuer(String sender, String body) {
    final combined = '$sender $body';
    for (final issuer in _issuers) {
      if (combined.toLowerCase().contains(issuer.toLowerCase())) return issuer;
    }
    // Fall back to sender cleaned up (remove country codes, digits, dashes)
    final cleaned = sender.replaceAll(RegExp(r'[^a-zA-Z\s]'), '').trim();
    if (cleaned.length >= 3) return cleaned;
    return null;
  }

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

  /// Sanitizes a raw snippet before storage:
  /// - Removes OTP/CVV patterns (3–8 digit standalone numbers preceded by keywords)
  /// - Masks anything that looks like a full card/account number (12+ consecutive digits)
  /// - Truncates to 200 characters
  static String sanitizeSnippet(String raw) {
    var s = raw;
    // Mask long digit runs (card numbers, account numbers: 12–19 digits)
    s = s.replaceAllMapped(
      RegExp(r'\b(\d{12,19})\b'),
      (m) {
        final digits = m.group(1)!;
        return '${digits.substring(0, 4)}****${digits.substring(digits.length - 4)}';
      },
    );
    // Mask OTP context: "OTP is 123456" → "OTP is ****"
    s = s.replaceAll(
      RegExp(r'(?:otp|pin|password|passcode)\s*(?:is|:)?\s*\d{4,8}',
          caseSensitive: false),
      'OTP ****',
    );
    // Truncate
    if (s.length > 200) s = '${s.substring(0, 200)}...';
    return s;
  }

  /// Builds a RefundItem from raw message content (SMS or email body).
  /// [sender] is the display name / cleaned address.
  /// [senderAddress] is the raw address (phone number, short code, or email)
  /// used to deep-link back to the original message thread.
  RefundItem? parseRefund({
    required String id,
    required String sourceText,
    String? sender,
    String? senderAddress,
    required RefundSource source,
    DateTime? date,
  }) {
    if (!looksLikeRefund(sourceText)) return null;
    final amount = extractAmount(sourceText);
    if (amount == null || amount <= 0 || amount > 9999999) return null;
    final currency = extractCurrency(sourceText);
    final orderId = extractOrderId(sourceText);
    final merchant = sender ?? 'Unknown';
    final category = inferCategory(merchant, sourceText);
    final bankName = extractBankName(sourceText);
    final destination = extractDestination(sourceText);
    final issuer = extractIssuer(merchant, sourceText);
    return RefundItem(
      id: id,
      merchantName: merchant,
      amount: amount,
      status: RefundStatus.processing,
      source: source,
      currency: currency,
      orderId: orderId,
      category: category,
      rawSnippet: sanitizeSnippet(sourceText),
      detectedAt: date ?? DateTime.now(),
      bankName: bankName,
      refundDestination: destination,
      refundIssuer: issuer,
      senderAddress: senderAddress ?? sender,
    );
  }
}
