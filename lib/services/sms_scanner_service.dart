import 'dart:io';

import 'package:permission_handler/permission_handler.dart';
import 'package:telephony/telephony.dart';

import '../models/refund_item.dart';
import 'refund_detection_service.dart';

/// Scans SMS inbox for refund-related messages.
/// Android only; iOS does not allow reading SMS.
class SmsScannerService {
  final RefundDetectionService _detection = RefundDetectionService();
  final Telephony _telephony = Telephony.instance;

  Future<bool> requestPermission() async {
    if (!Platform.isAndroid) return false;
    final status = await Permission.sms.status;
    if (status.isGranted) return true;
    return await Permission.sms.request().isGranted;
  }

  Future<bool> get hasPermission async {
    if (!Platform.isAndroid) return false;
    return await Permission.sms.isGranted;
  }

  /// Returns refund items parsed from the SMS inbox (all messages).
  Future<List<RefundItem>> scanInbox() async {
    if (!Platform.isAndroid) return [];
    final granted = await requestPermission();
    if (!granted) return [];

    final results = <RefundItem>[];
    try {
      final messages = await _telephony.getInboxSms(
        columns: [SmsColumn.ID, SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
      );
      for (final msg in messages) {
        final body = msg.body ?? '';
        final sender = msg.address ?? 'Unknown';
        final id = 'sms_${msg.id ?? DateTime.now().millisecondsSinceEpoch}';
        final date = msg.date != null
            ? DateTime.fromMillisecondsSinceEpoch(msg.date!)
            : DateTime.now();
        final item = _detection.parseRefund(
          id: id,
          sourceText: body,
          sender: sender,
          source: RefundSource.sms,
          date: date,
        );
        if (item != null) results.add(item);
      }
    } catch (_) {
      // SMS read failed silently — user will see 0 new results
    }
    return results;
  }
}
