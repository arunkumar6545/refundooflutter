import '../models/refund_item.dart';
import 'refund_detection_service.dart';

/// Placeholder for email sync (Gmail API / Microsoft Graph).
/// User must register and grant OAuth scope to read mail.
/// Actual implementation would use:
/// - google_sign_in + Gmail API, or
/// - msal_flutter + Microsoft Graph
class EmailSyncService {
  final RefundDetectionService _detection = RefundDetectionService();

  /// Whether the user has connected an email account.
  bool get isConnected => false;

  /// Initiate OAuth flow for Gmail/Outlook. User grants read-only mail access.
  Future<bool> connectAccount() async {
    // TODO: Launch OAuth (e.g. Google Sign-In with scope email + https://www.googleapis.com/auth/gmail.readonly)
    return false;
  }

  /// Disconnect and revoke token.
  Future<void> disconnect() async {}

  /// Fetch recent messages, parse for refunds. Would call Gmail API list + get.
  Future<List<RefundItem>> scanInbox() async {
    if (!isConnected) return [];
    // TODO: Gmail API list messages, get body, run _detection.parseRefund(..., source: RefundSource.email)
    return [];
  }
}
