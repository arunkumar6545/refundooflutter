import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/refund_item.dart';

/// Persists all refund tracking data in local storage only.
/// Nothing is sent to any server.
class RefundStorageService {
  static const String _keyRefunds = 'refundoo_refund_items';

  Future<List<RefundItem>> loadRefunds() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyRefunds);
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
    final prefs = await SharedPreferences.getInstance();
    final list = items.map((e) => e.toJson()).toList();
    await prefs.setString(_keyRefunds, jsonEncode(list));
  }

  /// Merges new items with existing (by id), then saves. Returns updated list.
  /// If an existing item was manually completed, its status is preserved.
  Future<List<RefundItem>> mergeAndSave(List<RefundItem> newItems) async {
    final existing = await loadRefunds();
    final byId = {for (final r in existing) r.id: r};
    for (final r in newItems) {
      final prev = byId[r.id];
      if (prev != null && prev.manuallyCompleted) {
        // Keep completed status — user explicitly set this, sync must not revert it
        byId[r.id] = r.copyWith(
          status: RefundStatus.completed,
          manuallyCompleted: true,
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
