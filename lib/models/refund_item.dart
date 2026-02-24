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

class RefundItem {
  const RefundItem({
    required this.id,
    required this.merchantName,
    required this.amount,
    required this.status,
    required this.source,
    this.orderId,
    this.category,
    this.categoryLabel,
    this.estimatedDays,
    this.rawSnippet,
    this.detectedAt,
    this.refundIssuedAt,
    this.description,
  });

  final String id;
  final String merchantName;
  final double amount;
  final RefundStatus status;
  final RefundSource source;
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'merchantName': merchantName,
      'amount': amount,
      'status': status.name,
      'source': source.name,
      'orderId': orderId,
      'category': category?.name,
      'categoryLabel': categoryLabel,
      'estimatedDays': estimatedDays,
      'rawSnippet': rawSnippet,
      'detectedAt': detectedAt?.toIso8601String(),
      'refundIssuedAt': refundIssuedAt?.toIso8601String(),
      'description': description,
    };
  }

  factory RefundItem.fromJson(Map<String, dynamic> json) {
    return RefundItem(
      id: json['id'] as String,
      merchantName: json['merchantName'] as String,
      amount: (json['amount'] as num).toDouble(),
      status: RefundStatus.values.byName(json['status'] as String),
      source: RefundSource.values.byName(json['source'] as String),
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
