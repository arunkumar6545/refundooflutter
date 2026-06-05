import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/refund_item.dart';

class ExportService {
  /// Builds a CSV string from [refunds] and shares it via the native share sheet.
  /// Returns true if the share sheet was opened, false on error.
  static Future<bool> exportCsv(List<RefundItem> refunds) async {
    try {
      final buf = StringBuffer();

      // Header row
      buf.writeln(
        '"#","Merchant","Amount","Currency","Status","Category",'
        '"Date Detected","Order ID","Notes"',
      );

      // Data rows
      for (var i = 0; i < refunds.length; i++) {
        final r = refunds[i];
        final date = r.detectedAt ?? r.refundIssuedAt;
        final dateStr = date != null
            ? '${date.year}-${_p(date.month)}-${_p(date.day)}'
            : '';
        final notesStr = r.notes.map((n) => n.text).join(' | ');

        buf.writeln([
          '"${i + 1}"',
          '"${_esc(r.merchantName)}"',
          '"${r.amount.toStringAsFixed(2)}"',
          '"${r.currency}"',
          '"${r.statusLabel}"',
          '"${r.displayCategory ?? ''}"',
          '"$dateStr"',
          '"${_esc(r.orderId ?? '')}"',
          '"${_esc(notesStr)}"',
        ].join(','));
      }

      // Write to temp file
      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/refundoo_export.csv');
      await file.writeAsString(buf.toString(), flush: true);

      // Share
      final result = await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        subject: 'Refundoo — My Refunds Export',
      );

      return result.status != ShareResultStatus.dismissed;
    } catch (_) {
      return false;
    }
  }

  static String _p(int n) => n.toString().padLeft(2, '0');

  // Escape double-quotes inside CSV fields.
  static String _esc(String s) => s.replaceAll('"', '""');
}
