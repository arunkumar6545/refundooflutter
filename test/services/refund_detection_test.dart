import 'package:flutter_test/flutter_test.dart';
import 'package:refundoo/models/refund_item.dart';
import 'package:refundoo/services/refund_detection_service.dart';

void main() {
  final det = RefundDetectionService();

  // ── looksLikeRefund ──────────────────────────────────────────────────────

  group('looksLikeRefund', () {
    test('returns true for typical refund SMS', () {
      expect(
        det.looksLikeRefund('Your refund of Rs 499 has been processed.'),
        isTrue,
      );
    });

    test('returns true for "credited back" phrasing', () {
      expect(
        det.looksLikeRefund('Amount of Rs 250 has been credited back to your account.'),
        isTrue,
      );
    });

    test('returns false for a normal purchase SMS', () {
      expect(
        det.looksLikeRefund('Your payment of Rs 199 to BigBasket is successful.'),
        isFalse,
      );
    });

    test('returns false for an OTP message', () {
      expect(
        det.looksLikeRefund('Your OTP is 123456. Do not share with anyone.'),
        isFalse,
      );
    });
  });

  // ── extractAmount ────────────────────────────────────────────────────────

  group('extractAmount', () {
    test('parses plain Rs amount', () {
      expect(det.extractAmount('Refund of Rs 499 initiated.'), 499.0);
    });

    test('parses ₹ symbol with decimals', () {
      expect(det.extractAmount('Refund ₹1,299.00 processed.'), 1299.0);
    });

    test('parses dollar amount', () {
      expect(det.extractAmount('Refund of \$34.99 processed.'), 34.99);
    });

    test('parses INR prefix', () {
      expect(det.extractAmount('INR 500 refund credited.'), 500.0);
    });

    test('returns null when no amount present', () {
      expect(det.extractAmount('Your order has been placed.'), isNull);
    });
  });

  // ── extractCurrency ──────────────────────────────────────────────────────

  group('extractCurrency', () {
    test('returns ₹ for Rs prefix', () {
      expect(det.extractCurrency('Refund of Rs 499.'), '₹');
    });

    test('returns \$ for dollar prefix', () {
      expect(det.extractCurrency('Refund of \$34.99.'), '\$');
    });

    test('returns ₹ as fallback when no currency found', () {
      expect(det.extractCurrency('Refund processed successfully.'), '₹');
    });
  });

  // ── extractOrderId ───────────────────────────────────────────────────────

  group('extractOrderId', () {
    test('extracts numeric order ID', () {
      expect(
        det.extractOrderId('Your refund for order #12345678 is processed.'),
        '12345678',
      );
    });

    test('extracts reference number', () {
      expect(
        det.extractOrderId('Ref 9876543 has been processed.'),
        '9876543',
      );
    });

    test('returns null when no order ID present', () {
      expect(det.extractOrderId('Refund of Rs 100 processed.'), isNull);
    });
  });

  // ── inferCategory ────────────────────────────────────────────────────────

  group('inferCategory', () {
    test('returns travel for flight-related text', () {
      expect(
        det.inferCategory('IndiGo', 'Refund for your flight booking processed.'),
        RefundCategory.travel,
      );
    });

    test('returns retail for Amazon', () {
      expect(
        det.inferCategory('Amazon', 'Refund for order #112233 initiated.'),
        RefundCategory.retail,
      );
    });

    test('returns foodDining for Zomato', () {
      // Note: body must not contain "order" — that word triggers retail first.
      expect(
        det.inferCategory('Zomato', 'Refund for your food delivery has been credited back.'),
        RefundCategory.foodDining,
      );
    });

    test('returns null for unrecognised sender/body', () {
      expect(
        det.inferCategory('UNKNOWN', 'Refund of Rs 100 processed.'),
        isNull,
      );
    });
  });

  // ── extractBankName ──────────────────────────────────────────────────────

  group('extractBankName', () {
    test('detects HDFC', () {
      expect(det.extractBankName('Your HDFC Bank account has been credited.'), 'HDFC Bank');
    });

    test('detects SBI', () {
      expect(det.extractBankName('Refund credited to SBI account.'), 'SBI');
    });

    test('returns null for unknown bank', () {
      expect(det.extractBankName('Your account has been credited.'), isNull);
    });
  });

  // ── sanitizeSnippet ──────────────────────────────────────────────────────

  group('sanitizeSnippet', () {
    test('masks card-number-length digit runs', () {
      final result = RefundDetectionService.sanitizeSnippet(
        'Card 4111111111111111 refund processed.',
      );
      expect(result, contains('4111****1111'));
    });

    test('masks OTP context', () {
      final result = RefundDetectionService.sanitizeSnippet(
        'Your OTP is 482910. Do not share.',
      );
      expect(result, contains('OTP ****'));
      expect(result, isNot(contains('482910')));
    });

    test('truncates snippet longer than 200 chars', () {
      final long = 'Refund initiated. ' * 20;
      final result = RefundDetectionService.sanitizeSnippet(long);
      expect(result.length, lessThanOrEqualTo(203)); // 200 + '...'
    });
  });

  // ── parseRefund (end-to-end) ─────────────────────────────────────────────

  group('parseRefund', () {
    test('returns RefundItem for a valid refund SMS', () {
      final item = det.parseRefund(
        id: 'sms_001',
        sourceText: 'Refund of Rs.499.00 for your Flipkart order ref 11223344 has been initiated.',
        sender: 'Flipkart',
        source: RefundSource.sms,
      );
      expect(item, isNotNull);
      expect(item!.amount, 499.0);
      expect(item.currency, '₹');
      expect(item.merchantName, 'Flipkart');
      expect(item.status, RefundStatus.processing);
    });

    test('returns null for non-refund message', () {
      final item = det.parseRefund(
        id: 'sms_002',
        sourceText: 'Payment of Rs 250 successful. Thank you for shopping.',
        sender: 'BigBasket',
        source: RefundSource.sms,
      );
      expect(item, isNull);
    });

    test('returns null when amount is zero or missing', () {
      final item = det.parseRefund(
        id: 'sms_003',
        sourceText: 'Your refund has been processed.',
        sender: 'UNKNOWN',
        source: RefundSource.sms,
      );
      expect(item, isNull);
    });
  });
}
