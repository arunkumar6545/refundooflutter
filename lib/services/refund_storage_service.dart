import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/refund_item.dart';

/// Persists all refund tracking data using encrypted storage (Android Keystore).
/// Nothing is sent to any server. All data stays on this device.
class RefundStorageService {
  static const String _keyRefunds    = 'refundoo_refund_items_v2';
  /// Tombstone set: IDs that were explicitly deleted by the user.
  /// mergeAndSave will never re-import items whose ID is in this set,
  /// so SMS/email false-positives do not resurface after deletion.
  static const String _keyDismissed  = 'refundoo_dismissed_ids_v1';

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
  /// • Items whose ID is in the dismissed set are silently skipped — deleted
  ///   false-positives will never resurface from subsequent SMS/email scans.
  /// • If an existing item was manually completed, its status + reason are preserved.
  Future<List<RefundItem>> mergeAndSave(List<RefundItem> newItems) async {
    final existing    = await loadRefunds();
    final dismissed   = await loadDismissedIds();
    final byId = {for (final r in existing) r.id: r};
    for (final r in newItems) {
      if (dismissed.contains(r.id)) continue;   // skip dismissed false-positives
      final prev = byId[r.id];
      if (prev != null && prev.manuallyCompleted) {
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

  // ── Dismissed-ID tombstone ────────────────────────────────────────────────

  Future<Set<String>> loadDismissedIds() async {
    final raw = await _storage.read(key: _keyDismissed);
    if (raw == null || raw.isEmpty) return {};
    try {
      return Set<String>.from(jsonDecode(raw) as List<dynamic>);
    } catch (_) {
      return {};
    }
  }

  /// Marks [id] as permanently dismissed so mergeAndSave will never
  /// re-import it from SMS/email scans.
  Future<void> dismissRefund(String id) async {
    final ids = await loadDismissedIds();
    ids.add(id);
    await _storage.write(key: _keyDismissed, value: jsonEncode(ids.toList()));
  }

  /// Removes [id] from the dismissed set (lets it be re-scanned / re-added).
  Future<void> undismissRefund(String id) async {
    final ids = await loadDismissedIds();
    ids.remove(id);
    await _storage.write(key: _keyDismissed, value: jsonEncode(ids.toList()));
  }
}
