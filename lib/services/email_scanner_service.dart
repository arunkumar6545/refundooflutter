import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/refund_item.dart';
import 'auth_service.dart';
import 'refund_detection_service.dart';

/// Scans Gmail inbox for refund-related emails (last 30 days only).
/// Uses the Gmail REST API with the access token from Google Sign-In.
class EmailScannerService {
  // Non-sensitive toggle in regular prefs
  static const _keyEmailEnabled = 'email_sync_enabled';
  // Approved account email is PII — store encrypted
  static const _secKeyApprovedEmail = 'email_sync_account_sec';
  static const _gmailBase = 'https://gmail.googleapis.com/gmail/v1/users/me';

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

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
      await _secureStorage.write(key: _secKeyApprovedEmail, value: accountEmail);
    } else if (!value) {
      await _secureStorage.delete(key: _secKeyApprovedEmail);
    }
  }

  Future<String?> get approvedAccount async {
    return await _secureStorage.read(key: _secKeyApprovedEmail);
  }

  /// Scan Gmail inbox for refund emails from the last 30 days.
  /// Returns parsed [RefundItem]s.
  Future<List<RefundItem>> scanInbox() async {
    final account = _auth.currentUser;
    if (account == null) return [];

    try {
      final auth = await account.authentication;
      final token = auth.accessToken;
      if (token == null || token.isEmpty) return [];

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
      if (listResp.statusCode == 401) {
        // Token expired — silently skip, user must re-auth
        return [];
      }
      if (listResp.statusCode != 200) return [];

      final listData = jsonDecode(listResp.body) as Map<String, dynamic>;
      final messages = (listData['messages'] as List<dynamic>?) ?? [];

      final items = <RefundItem>[];
      for (final msg in messages) {
        // Only accept well-formed alphanumeric message IDs from the API
        final rawId = msg['id'];
        if (rawId is! String) continue;
        final id = rawId.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '');
        if (id.isEmpty || id.length > 64) continue;

        final detailUri =
            Uri.parse('$_gmailBase/messages/$id?format=full');
        final detailResp = await http.get(
          detailUri,
          headers: {'Authorization': 'Bearer $token'},
        );
        if (detailResp.statusCode != 200) continue;

        Map<String, dynamic> detail;
        try {
          detail = jsonDecode(detailResp.body) as Map<String, dynamic>;
        } on FormatException {
          continue;
        }

        // Cap body at 5 KB before passing to the parser
        var body = _extractPlainText(detail);
        if (body.length > 5000) body = body.substring(0, 5000);
        if (body.isEmpty) continue;

        final dateMs =
            int.tryParse((detail['internalDate'] as String?) ?? '') ?? 0;
        final date = dateMs > 0
            ? DateTime.fromMillisecondsSinceEpoch(dateMs)
            : DateTime.now();

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
    } on http.ClientException {
      return [];
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
      final directData =
          (payload['body'] as Map<String, dynamic>?)?['data'] as String?;
      if (directData != null && directData.isNotEmpty) {
        return _decodeBase64(directData);
      }

      // Walk parts with depth limit to prevent stack-overflow via crafted payloads
      final parts = payload['parts'] as List<dynamic>? ?? [];
      return _walkParts(parts, depth: 0);
    } catch (_) {
      return '';
    }
  }

  String _walkParts(List<dynamic> parts, {required int depth}) {
    // Guard against deeply nested MIME structures (malicious or malformed emails)
    if (depth > 6) return '';
    for (final part in parts) {
      if (part is! Map<String, dynamic>) continue;
      final mime = part['mimeType'] as String? ?? '';
      if (mime == 'text/plain') {
        final data =
            (part['body'] as Map<String, dynamic>?)?['data'] as String?;
        if (data != null && data.isNotEmpty) return _decodeBase64(data);
      }
      // Recurse into multipart
      final subParts = part['parts'] as List<dynamic>?;
      if (subParts != null) {
        final result = _walkParts(subParts, depth: depth + 1);
        if (result.isNotEmpty) return result;
      }
    }
    return '';
  }

  String _decodeBase64(String data) {
    try {
      return utf8.decode(base64Url.decode(data));
    } on FormatException {
      return '';
    } catch (_) {
      return '';
    }
  }

  String _extractSender(Map<String, dynamic> message) {
    try {
      final headers =
          (message['payload']?['headers'] as List<dynamic>?) ?? [];
      for (final h in headers) {
        if (h is! Map<String, dynamic>) continue;
        if ((h['name'] as String?)?.toLowerCase() == 'from') {
          final raw = h['value'] as String? ?? '';
          // Strip display-name portion, keep only the email address part
          final emailMatch =
              RegExp(r'<([^>]+)>').firstMatch(raw);
          if (emailMatch != null) return emailMatch.group(1)!.trim();
          return raw.trim();
        }
      }
    } catch (_) {}
    return 'Email';
  }
}
