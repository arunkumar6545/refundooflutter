import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

import '../models/refund_item.dart';
import 'refund_detection_service.dart';

/// Scans SMS inbox for refund-related messages.
/// Android only; iOS does not allow reading SMS.
class SmsScannerService {
  final RefundDetectionService _detection = RefundDetectionService();

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

  /// Returns refund items parsed from SMS. Uses telephony on Android when available.
  Future<List<RefundItem>> scanInbox() async {
    if (!Platform.isAndroid) return [];
    final granted = await requestPermission();
    if (!granted) return [];

    // Telephony package would be used here. For a new project we avoid
    // triggering platform code without Flutter run; return mock for now.
    // Example with telephony:
    // final telephony = Telephony.instance;
    // final messages = await telephony.getInboxSms(columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE]);
    // for (final msg in messages) {
    //   final item = _detection.parseRefund(id: msg.id ?? '', sourceText: msg.body ?? '', sender: msg.address, source: RefundSource.sms, date: msg.date != null ? DateTime.fromMillisecondsSinceEpoch(msg.date!) : null);
    //   if (item != null) results.add(item);
    // }
    return [];
  }
}
