import 'refund_item.dart';

class RefundTimelineStep {
  const RefundTimelineStep({
    required this.title,
    required this.timestamp,
    required this.isCompleted,
    required this.source,
    this.snippet,
    this.isCurrent = false,
    this.isSkipped = false,
    this.isManualClose = false,
    this.senderAddress,
  });

  final String title;
  final String timestamp;
  final bool isCompleted;
  final RefundSource source;
  final String? snippet;
  final bool isCurrent;
  /// True when this step was bypassed by a manual completion.
  final bool isSkipped;
  /// True for the "Manually Closed" terminal step.
  final bool isManualClose;
  /// Raw sender address (phone / short-code for SMS, email for email).
  /// Only set on the "Message Parsed" step to allow deep-linking.
  final String? senderAddress;
}
