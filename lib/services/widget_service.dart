import 'package:home_widget/home_widget.dart';

import '../models/refund_item.dart';

class WidgetService {
  static const _appGroupId = 'com.refundoo.refundoo';

  static Future<void> update(List<RefundItem> refunds) async {
    try {
      final pending = refunds
          .where((r) => !r.archived && r.status != RefundStatus.completed)
          .toList();
      final amount = pending.fold(0.0, (s, r) => s + r.amount);
      final count = pending.length;

      await HomeWidget.setAppGroupId(_appGroupId);
      await HomeWidget.saveWidgetData<String>(
          'pending_amount', '₹${amount.toStringAsFixed(0)}');
      await HomeWidget.saveWidgetData<String>(
          'pending_count', '$count refund${count == 1 ? '' : 's'} pending');
      await HomeWidget.updateWidget(
        name: 'RefundooWidget',
        iOSName: 'RefundooWidget',
        androidName: 'RefundooWidget',
      );
    } catch (_) {
      // Widget update is best-effort; do not crash the app
    }
  }
}
