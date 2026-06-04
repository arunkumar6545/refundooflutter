import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/refund_item.dart';

/// Persists all refund tracking data using encrypted storage (Android Keystore).
/// Nothing is sent to any server. All data stays on this device.
class RefundStorageService {
  static const String _keyRefunds = 'refundoo_refund_items_v2';

  // Use EncryptedSharedPreferences on Android (backed by Android Keystore).
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  Future<List<RefundItem>> loadRefunds() async {
    final jsonStr = await _storage.read(key: _keyRefunds);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list
          .map((e) => RefundItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveRefunds(List<RefundItem> items) async {
    final list = items.map((e) => e.toJson()).toList();
    await _storage.write(key: _keyRefunds, value: jsonEncode(list));
  }

  /// Merges new items with existing (by id), then saves. Returns updated list.
  /// If an existing item was manually completed, its status + reason are preserved.
  Future<List<RefundItem>> mergeAndSave(List<RefundItem> newItems) async {
    final existing = await loadRefunds();
    final byId = {for (final r in existing) r.id: r};
    for (final r in newItems) {
      final prev = byId[r.id];
      if (prev != null && prev.manuallyCompleted) {
        // Keep completed status + user's reason — sync must not revert either
        byId[r.id] = r.copyWith(
          status: RefundStatus.completed,
          manuallyCompleted: true,
          description: prev.description,
        );
      } else {
        byId[r.id] = r;
      }
    }
    final merged = byId.values.toList()
      ..sort((a, b) => (b.detectedAt ?? DateTime(0))
          .compareTo(a.detectedAt ?? DateTime(0)));
    await saveRefunds(merged);
    return merged;
  }

  Future<RefundItem?> getRefundById(String id) async {
    final list = await loadRefunds();
    try {
      return list.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }
}
