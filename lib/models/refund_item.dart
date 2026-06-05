import 'package:flutter/material.dart' show Color;

// ─────────────────────────────────────────────────────────────────────────────
// Per-refund user note (text + optional local image path)
// ─────────────────────────────────────────────────────────────────────────────

class RefundNote {
  const RefundNote({
    required this.id,
    required this.text,
    required this.createdAt,
    this.imagePath,
  });

  /// Unique id — uses createdAt epoch millis as a simple unique string.
  final String id;
  final String text;
  final DateTime createdAt;
  /// Absolute path to a locally stored image, or null if text-only.
  final String? imagePath;

  Map<String, dynamic> toJson() => {
    'id':        id,
    'text':      text,
    'createdAt': createdAt.toIso8601String(),
    'imagePath': imagePath,
  };

  factory RefundNote.fromJson(Map<String, dynamic> j) => RefundNote(
    id:         j['id'] as String,
    text:       j['text'] as String,
    createdAt:  DateTime.parse(j['createdAt'] as String),
    imagePath:  j['imagePath'] as String?,
  );
}

enum RefundStatus {
  processing,
  awaitingConfirmation,
  bankProcessing,
  completed,
}

enum RefundSource {
  sms,
  email,
}

enum RefundDestination {
  bankAccount,
  creditCard,
  debitCard,
  wallet,
  upi,
  unknown,
}

extension RefundDestinationX on RefundDestination {
  String get label {
    switch (this) {
      case RefundDestination.bankAccount: return 'Bank Account';
      case RefundDestination.creditCard:  return 'Credit Card';
      case RefundDestination.debitCard:   return 'Debit Card';
      case RefundDestination.wallet:      return 'Wallet';
      case RefundDestination.upi:         return 'UPI';
      case RefundDestination.unknown:     return 'Account';
    }
  }

  String get icon {
    switch (this) {
      case RefundDestination.bankAccount: return '🏦';
      case RefundDestination.creditCard:  return '💳';
      case RefundDestination.debitCard:   return '💳';
      case RefundDestination.wallet:      return '👝';
      case RefundDestination.upi:         return '📲';
      case RefundDestination.unknown:     return '🏦';
    }
  }
}

class RefundItem {
  const RefundItem({
    required this.id,
    required this.merchantName,
    required this.amount,
    required this.status,
    required this.source,
    this.currency = '₹',
    this.orderId,
    this.category,
    this.categoryLabel,
    this.estimatedDays,
    this.rawSnippet,
    this.detectedAt,
    this.refundIssuedAt,
    this.description,
    this.manuallyCompleted = false,
    this.bankName,
    this.refundDestination = RefundDestination.unknown,
    this.refundIssuer,
    this.senderAddress,
    this.notes = const [],
  });

  final String id;
  final String merchantName;
  final double amount;
  final RefundStatus status;
  final RefundSource source;
  /// Currency symbol, e.g. ₹, $, €, £, ¥
  final String currency;
  final String? orderId;
  final RefundCategory? category;
  /// Custom category name when preset categories don't fit (e.g. "Other").
  final String? categoryLabel;
  final int? estimatedDays;
  final String? rawSnippet;
  final DateTime? detectedAt;
  /// Date when the refund was issued.
  final DateTime? refundIssuedAt;
  final String? description;
  /// True when the user has manually marked this refund as completed.
  /// Sync will never downgrade the status back to processing.
  final bool manuallyCompleted;
  /// Bank name where the refund will be credited (e.g. "HDFC", "SBI").
  final String? bankName;
  /// Where the refund is going (bank account, credit card, UPI, etc.).
  final RefundDestination refundDestination;
  /// Company that issued the refund (e.g. "Amazon", "Zomato").
  final String? refundIssuer;
  /// Raw sender address: phone number / short code for SMS, email for email.
  /// Used to deep-link back to the original message thread.
  final String? senderAddress;
  /// User-authored follow-up notes (text + optional photo).
  final List<RefundNote> notes;

  /// Formatted amount string, e.g. "₹499.00" or "$34.99"
  String get formattedAmount => '$currency${amount.toStringAsFixed(2)}';

  /// How many days this refund has been waiting (since detectedAt).
  int get waitingDays {
    final since = detectedAt ?? refundIssuedAt;
    if (since == null) return 0;
    return DateTime.now().difference(since).inDays;
  }

  /// Category-based SLA defaults (days until refund should arrive).
  static const _categorySla = {
    RefundCategory.travel:        14,
    RefundCategory.retail:        7,
    RefundCategory.services:      10,
    RefundCategory.foodDining:    5,
    RefundCategory.electronics:   10,
    RefundCategory.entertainment: 7,
  };

  /// Threshold: parsed from message → category SLA → generic 7-day fallback.
  int get expectedDays => estimatedDays ?? _categorySla[category] ?? 7;

  /// The date by which the refund should have arrived.
  DateTime? get expectedByDate {
    final since = detectedAt ?? refundIssuedAt;
    if (since == null) return null;
    return since.add(Duration(days: expectedDays));
  }

  /// True when a non-completed refund has been waiting longer than expected.
  bool get isOverdue =>
      status != RefundStatus.completed && waitingDays > expectedDays;

  /// Days past the promised deadline (positive = overdue, negative = still within window).
  int get overdueDays => waitingDays - expectedDays;

  RefundItem copyWith({
    String? id,
    String? merchantName,
    double? amount,
    RefundStatus? status,
    RefundSource? source,
    String? currency,
    String? orderId,
    RefundCategory? category,
    String? categoryLabel,
    int? estimatedDays,
    String? rawSnippet,
    DateTime? detectedAt,
    DateTime? refundIssuedAt,
    String? description,
    bool? manuallyCompleted,
    String? bankName,
    RefundDestination? refundDestination,
    String? refundIssuer,
    String? senderAddress,
    List<RefundNote>? notes,
  }) {
    return RefundItem(
      id: id ?? this.id,
      merchantName: merchantName ?? this.merchantName,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      source: source ?? this.source,
      currency: currency ?? this.currency,
      orderId: orderId ?? this.orderId,
      category: category ?? this.category,
      categoryLabel: categoryLabel ?? this.categoryLabel,
      estimatedDays: estimatedDays ?? this.estimatedDays,
      rawSnippet: rawSnippet ?? this.rawSnippet,
      detectedAt: detectedAt ?? this.detectedAt,
      refundIssuedAt: refundIssuedAt ?? this.refundIssuedAt,
      description: description ?? this.description,
      manuallyCompleted: manuallyCompleted ?? this.manuallyCompleted,
      bankName: bankName ?? this.bankName,
      refundDestination: refundDestination ?? this.refundDestination,
      refundIssuer: refundIssuer ?? this.refundIssuer,
      senderAddress: senderAddress ?? this.senderAddress,
      notes: notes ?? this.notes,
    );
  }

  /// Display category: custom label if set, otherwise enum label.
  String? get displayCategory => categoryLabel?.isNotEmpty == true ? categoryLabel : category?.label;

  String get statusLabel {
    switch (status) {
      case RefundStatus.processing:
        return 'Processing';
      case RefundStatus.awaitingConfirmation:
        return 'Awaiting Confirmation';
      case RefundStatus.bankProcessing:
        return 'Bank Processing';
      case RefundStatus.completed:
        return 'Completed';
    }
  }

  /// Short group label shown as a coloured badge.
  String get statusBadgeLabel {
    switch (status) {
      case RefundStatus.processing:
        return 'Processing';
      case RefundStatus.awaitingConfirmation:
      case RefundStatus.bankProcessing:
        return 'Action Needed';
      case RefundStatus.completed:
        return 'Completed';
    }
  }

  /// Foreground colour for the status badge text.
  Color get statusColor {
    switch (status) {
      case RefundStatus.processing:
        return const Color(0xFFD97706); // amber-600
      case RefundStatus.awaitingConfirmation:
      case RefundStatus.bankProcessing:
        return const Color(0xFFDC2626); // red-600
      case RefundStatus.completed:
        return const Color(0xFF059669); // emerald-600
    }
  }

  /// Light background tint for the badge.
  Color get statusBgColor {
    switch (status) {
      case RefundStatus.processing:
        return const Color(0xFFFEF3C7); // amber-100
      case RefundStatus.awaitingConfirmation:
      case RefundStatus.bankProcessing:
        return const Color(0xFFFEE2E2); // red-100
      case RefundStatus.completed:
        return const Color(0xFFD1FAE5); // emerald-100
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'merchantName': merchantName,
      'amount': amount,
      'status': status.name,
      'source': source.name,
      'currency': currency,
      'orderId': orderId,
      'category': category?.name,
      'categoryLabel': categoryLabel,
      'estimatedDays': estimatedDays,
      'rawSnippet': rawSnippet,
      'detectedAt': detectedAt?.toIso8601String(),
      'refundIssuedAt': refundIssuedAt?.toIso8601String(),
      'description': description,
      'manuallyCompleted': manuallyCompleted,
      'bankName': bankName,
      'refundDestination': refundDestination.name,
      'refundIssuer': refundIssuer,
      'senderAddress': senderAddress,
      'notes': notes.map((n) => n.toJson()).toList(),
    };
  }

  factory RefundItem.fromJson(Map<String, dynamic> json) {
    return RefundItem(
      id: json['id'] as String,
      merchantName: json['merchantName'] as String,
      amount: (json['amount'] as num).toDouble(),
      status: RefundStatus.values.byName(json['status'] as String),
      source: RefundSource.values.byName(json['source'] as String),
      currency: json['currency'] as String? ?? '₹',
      orderId: json['orderId'] as String?,
      category: json['category'] != null
          ? RefundCategory.values.byName(json['category'] as String)
          : null,
      categoryLabel: json['categoryLabel'] as String?,
      estimatedDays: json['estimatedDays'] as int?,
      rawSnippet: json['rawSnippet'] as String?,
      detectedAt: json['detectedAt'] != null
          ? DateTime.tryParse(json['detectedAt'] as String)
          : null,
      refundIssuedAt: json['refundIssuedAt'] != null
          ? DateTime.tryParse(json['refundIssuedAt'] as String)
          : null,
      description: json['description'] as String?,
      manuallyCompleted: json['manuallyCompleted'] as bool? ?? false,
      bankName: json['bankName'] as String?,
      refundDestination: json['refundDestination'] != null
          ? RefundDestination.values.byName(json['refundDestination'] as String)
          : RefundDestination.unknown,
      refundIssuer: json['refundIssuer'] as String?,
      senderAddress: json['senderAddress'] as String?,
      notes: (json['notes'] as List<dynamic>?)
              ?.map((e) => RefundNote.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

enum RefundCategory {
  travel,
  retail,
  services,
  foodDining,
  electronics,
  entertainment,
}

extension RefundCategoryX on RefundCategory {
  String get label {
    switch (this) {
      case RefundCategory.travel:
        return 'Travel';
      case RefundCategory.retail:
        return 'Retail';
      case RefundCategory.services:
        return 'Services';
      case RefundCategory.foodDining:
        return 'Food & Dining';
      case RefundCategory.electronics:
        return 'Electronics';
      case RefundCategory.entertainment:
        return 'Entertainment';
    }
  }

  String get iconName {
    switch (this) {
      case RefundCategory.travel:
        return 'flight_takeoff';
      case RefundCategory.retail:
        return 'shopping_bag';
      case RefundCategory.services:
        return 'account_tree';
      case RefundCategory.foodDining:
        return 'restaurant';
      case RefundCategory.electronics:
        return 'devices';
      case RefundCategory.entertainment:
        return 'movie';
    }
  }
}
