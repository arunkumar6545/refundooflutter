import 'package:flutter_test/flutter_test.dart';
import 'package:refundoo/models/refund_item.dart';

void main() {
  // ── JSON round-trip ──────────────────────────────────────────────────────

  group('RefundItem serialization', () {
    final sample = RefundItem(
      id: 'test_001',
      merchantName: 'Amazon',
      amount: 1299.00,
      currency: '₹',
      status: RefundStatus.processing,
      source: RefundSource.sms,
      category: RefundCategory.retail,
      orderId: '55566677',
      detectedAt: DateTime(2025, 6, 1, 10, 30),
    );

    test('toJson produces expected keys', () {
      final json = sample.toJson();
      expect(json['id'], 'test_001');
      expect(json['merchantName'], 'Amazon');
      expect(json['amount'], 1299.00);
      expect(json['currency'], '₹');
      expect(json['status'], 'processing');
    });

    test('fromJson restores all fields', () {
      final restored = RefundItem.fromJson(sample.toJson());
      expect(restored.id, sample.id);
      expect(restored.merchantName, sample.merchantName);
      expect(restored.amount, sample.amount);
      expect(restored.currency, sample.currency);
      expect(restored.status, sample.status);
      expect(restored.category, sample.category);
      expect(restored.orderId, sample.orderId);
    });

    test('round-trip preserves detectedAt', () {
      final restored = RefundItem.fromJson(sample.toJson());
      expect(restored.detectedAt, sample.detectedAt);
    });
  });

  // ── copyWith ─────────────────────────────────────────────────────────────

  group('RefundItem.copyWith', () {
    final base = RefundItem(
      id: 'a',
      merchantName: 'Flipkart',
      amount: 499.0,
      status: RefundStatus.processing,
      source: RefundSource.sms,
    );

    test('updates only specified fields', () {
      final updated = base.copyWith(
        amount: 599.0,
        status: RefundStatus.completed,
      );
      expect(updated.id, 'a');
      expect(updated.merchantName, 'Flipkart');
      expect(updated.amount, 599.0);
      expect(updated.status, RefundStatus.completed);
    });

    test('original is unchanged after copyWith', () {
      base.copyWith(amount: 999.0);
      expect(base.amount, 499.0);
    });
  });

  // ── notes ─────────────────────────────────────────────────────────────────

  group('RefundNote serialization', () {
    final note = RefundNote(
      id: 'n1',
      text: 'Called support, ticket #ABC',
      createdAt: DateTime(2025, 7, 15),
    );

    test('toJson/fromJson round-trip', () {
      final restored = RefundNote.fromJson(note.toJson());
      expect(restored.id, note.id);
      expect(restored.text, note.text);
      expect(restored.createdAt, note.createdAt);
      expect(restored.imagePath, isNull);
    });
  });

  // ── expectedByDate ────────────────────────────────────────────────────────

  group('expectedByDate', () {
    test('returns a future date for processing refunds with a detectedAt', () {
      final item = RefundItem(
        id: 'e1',
        merchantName: 'Zomato',
        amount: 100,
        status: RefundStatus.processing,
        source: RefundSource.sms,
        category: RefundCategory.foodDining,
        detectedAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(item.expectedByDate, isNotNull);
    });

    test('returns null when no detectedAt or refundIssuedAt', () {
      final item = RefundItem(
        id: 'e2',
        merchantName: 'Zomato',
        amount: 100,
        status: RefundStatus.completed,
        source: RefundSource.sms,
        category: RefundCategory.foodDining,
        // no detectedAt → expectedByDate should be null
      );
      expect(item.expectedByDate, isNull);
    });

    test('isOverdue is false for completed refunds regardless of wait time', () {
      final item = RefundItem(
        id: 'e3',
        merchantName: 'Zomato',
        amount: 100,
        status: RefundStatus.completed,
        source: RefundSource.sms,
        category: RefundCategory.foodDining,
        detectedAt: DateTime.now().subtract(const Duration(days: 30)),
      );
      expect(item.isOverdue, isFalse);
    });
  });
}
