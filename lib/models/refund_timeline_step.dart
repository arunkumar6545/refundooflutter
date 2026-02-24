import 'refund_item.dart';

class RefundTimelineStep {
  const RefundTimelineStep({
    required this.title,
    required this.timestamp,
    required this.isCompleted,
    required this.source,
    this.snippet,
    this.isCurrent = false,
  });

  final String title;
  final String timestamp;
  final bool isCompleted;
  final RefundSource source;
  final String? snippet;
  final bool isCurrent;
}
