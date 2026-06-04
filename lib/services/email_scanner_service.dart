import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/refund_item.dart';
import 'auth_service.dart';
import 'refund_detection_service.dart';

/// Scans Gmail inbox for refund-related emails (last 30 days only).
/// Uses the Gmail REST API with the access token from Google Sign-In.
class EmailScannerService {
  static const _keyEmailEnabled = 'email_sync_enabled';
  static const _keyApprovedEmail = 'email_sync_account';
  static const _gmailBase = 'https://gmail.googleapis.com/gmail/v1/users/me';

  final RefundDetectionService _detector = RefundDetectionService();
  final AuthService _auth = AuthService();

  Future<bool> get isEnabled async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyEmailEnabled) ?? false;
  }

  Future<void> setEnabled(bool value, {String? accountEmail}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEmailEnabled, value);
    if (accountEmail != null) {
      await prefs.setString(_keyApprovedEmail, accountEmail);
    } else if (!value) {
      await prefs.remove(_keyApprovedEmail);
    }
  }

  Future<String?> get approvedAccount async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyApprovedEmail);
  }

  /// Scan Gmail inbox for refund emails from the last 30 days.
  /// Returns parsed [RefundItem]s.
  Future<List<RefundItem>> scanInbox() async {
    final account = _auth.currentUser;
    if (account == null) return [];

    try {
      final auth = await account.authentication;
      final token = auth.accessToken;
      if (token == null) return [];

      // Build Gmail query: refund-related keywords, last 30 days
      final since = DateTime.now().subtract(const Duration(days: 30));
      final afterStr =
          '${since.year}/${since.month.toString().padLeft(2, '0')}/${since.day.toString().padLeft(2, '0')}';
      const keywords =
          '(refund OR "amount credited" OR "money returned" OR "refund initiated" OR "refund processed" OR "cashback")';
      final query = Uri.encodeComponent('$keywords after:$afterStr');

      final listUri =
          Uri.parse('$_gmailBase/messages?q=$query&maxResults=50');
      final listResp = await http.get(
        listUri,
        headers: {'Authorization': 'Bearer $token'},
      );
      if (listResp.statusCode != 200) return [];

      final listData = jsonDecode(listResp.body) as Map<String, dynamic>;
      final messages =
          (listData['messages'] as List<dynamic>?) ?? [];

      final items = <RefundItem>[];
      for (final msg in messages) {
        final id = msg['id'] as String;
        final detailUri =
            Uri.parse('$_gmailBase/messages/$id?format=full');
        final detailResp = await http.get(
          detailUri,
          headers: {'Authorization': 'Bearer $token'},
        );
        if (detailResp.statusCode != 200) continue;

        final detail =
            jsonDecode(detailResp.body) as Map<String, dynamic>;
        final body = _extractPlainText(detail);
        final dateMs = int.tryParse(
                (detail['internalDate'] as String?) ?? '') ??
            0;
        final date = dateMs > 0
            ? DateTime.fromMillisecondsSinceEpoch(dateMs)
            : DateTime.now();

        if (body.isEmpty) continue;

        final item = _detector.parseRefund(
          id: 'email_$id',
          sourceText: body,
          sender: _extractSender(detail),
          source: RefundSource.email,
          date: date,
        );
        if (item != null) items.add(item);
      }
      return items;
    } catch (_) {
      return [];
    }
  }

  /// Extract plain-text body from a Gmail message payload.
  String _extractPlainText(Map<String, dynamic> message) {
    try {
      final payload = message['payload'] as Map<String, dynamic>?;
      if (payload == null) return '';

      // Check direct body
      final directData = (payload['body'] as Map<String, dynamic>?)?['data'] as String?;
      if (directData != null && directData.isNotEmpty) {
        return _decodeBase64(directData);
      }

      // Walk parts
      final parts = payload['parts'] as List<dynamic>? ?? [];
      return _walkParts(parts);
    } catch (_) {
      return '';
    }
  }

  String _walkParts(List<dynamic> parts) {
    for (final part in parts) {
      final mime = part['mimeType'] as String? ?? '';
      if (mime == 'text/plain') {
        final data = (part['body'] as Map<String, dynamic>?)?['data'] as String?;
        if (data != null && data.isNotEmpty) return _decodeBase64(data);
      }
      // Recurse into multipart
      final subParts = part['parts'] as List<dynamic>?;
      if (subParts != null) {
        final result = _walkParts(subParts);
        if (result.isNotEmpty) return result;
      }
    }
    return '';
  }

  String _decodeBase64(String data) {
    try {
      return utf8.decode(base64Url.decode(data));
    } catch (_) {
      return '';
    }
  }

  String _extractSender(Map<String, dynamic> message) {
    try {
      final headers =
          (message['payload']?['headers'] as List<dynamic>?) ?? [];
      for (final h in headers) {
        if ((h['name'] as String?)?.toLowerCase() == 'from') {
          return h['value'] as String? ?? 'Email';
        }
      }
    } catch (_) {}
    return 'Email';
  }
}
