import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../models/refund_item.dart';
import '../../models/refund_timeline_step.dart';
import '../../services/refund_storage_service.dart';

class RefundDetailScreen extends StatefulWidget {
  const RefundDetailScreen({super.key, required this.refundId});

  final String refundId;

  @override
  State<RefundDetailScreen> createState() => _RefundDetailScreenState();
}

const _kCurrencies = ['₹', '\$', '€', '£', '¥'];

class _RefundDetailScreenState extends State<RefundDetailScreen> {
  final RefundStorageService _storage = RefundStorageService();
  RefundItem? _refund;
  bool _loading = true;

  static List<RefundTimelineStep> _timelineFor(RefundItem? refund) {
    if (refund == null) return [];
    final isManual = refund.manuallyCompleted;
    final closedAt = refund.refundIssuedAt ?? refund.detectedAt ?? DateTime.now();
    final issuer = refund.refundIssuer ?? refund.merchantName;

    return [
      // Step 1 — always complete (we scanned it)
      RefundTimelineStep(
        title: 'Message Parsed',
        timestamp: refund.detectedAt != null
            ? _formatDate(refund.detectedAt!)
            : 'Unknown',
        isCompleted: true,
        source: refund.source,
        snippet: refund.rawSnippet?.isNotEmpty == true
            ? refund.rawSnippet!
            : 'Refund of ${refund.formattedAmount} detected from $issuer.',
      ),

      // Step 2 — merchant confirmed (complete when we have the data)
      RefundTimelineStep(
        title: 'Merchant Confirmed',
        timestamp: refund.detectedAt != null
            ? _formatDate(refund.detectedAt!)
            : 'Unknown',
        isCompleted: true,
        source: refund.source,
        snippet: '${refund.formattedAmount} refund from $issuer'
            '${refund.orderId != null ? ' (Order #${refund.orderId})' : ''}'
            ' has been confirmed.',
      ),

      // Step 3 — bank processing: current if still processing, skipped if manual
      RefundTimelineStep(
        title: 'Bank Processing',
        timestamp: isManual ? '— Skipped' : 'Awaiting',
        isCompleted: false,
        isCurrent: !isManual,
        isSkipped: isManual,
        source: refund.source,
      ),

      // Step 4 — funds released: awaiting normally, skipped if manual
      RefundTimelineStep(
        title: 'Funds Released',
        timestamp: isManual ? '— Skipped' : 'Awaiting',
        isCompleted: false,
        isSkipped: isManual,
        source: refund.source,
      ),

      // Step 5 — only for manually closed refunds
      if (isManual)
        RefundTimelineStep(
          title: 'Manually Closed',
          timestamp: _formatDate(closedAt),
          isCompleted: true,
          isManualClose: true,
          source: refund.source,
          snippet: refund.description?.isNotEmpty == true
              ? refund.description!
              : 'Marked as completed by you.',
        ),
    ];
  }

  static String _formatDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final h = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    final am = d.hour < 12;
    return '${months[d.month - 1]} ${d.day}, ${d.year}  ${h}:${d.minute.toString().padLeft(2, '0')} ${am ? 'AM' : 'PM'}';
  }

  @override
  void initState() {
    super.initState();
    _loadRefund();
  }

  Future<void> _loadRefund() async {
    final refund = await _storage.getRefundById(widget.refundId);
    setState(() {
      _refund = refund;
      _loading = false;
    });
  }

  Future<void> _showCurrencyPicker(BuildContext context) async {
    final refund = _refund;
    if (refund == null) return;
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        String selected = refund.currency;
        return StatefulBuilder(
          builder: (ctx, setInner) => Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Select Currency',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  'Choose the correct currency for this refund',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _kCurrencies.map((c) {
                    final isSelected = c == selected;
                    return GestureDetector(
                      onTap: () => setInner(() => selected = c),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.primary.withValues(alpha: 0.2),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              c,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: isSelected ? Colors.white : AppColors.primary,
                              ),
                            ),
                            Text(
                              _currencyName(c),
                              style: TextStyle(
                                fontSize: 9,
                                color: isSelected
                                    ? Colors.white.withValues(alpha: 0.8)
                                    : AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final updated = refund.copyWith(currency: selected);
                      await _storage.mergeAndSave([updated]);
                      setState(() => _refund = updated);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Currency updated to $selected'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _markCompleted(BuildContext context) async {
    final refund = _refund;
    if (refund == null) return;

    // Ask for a reason first
    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _MarkCompleteSheet(),
    );
    if (reason == null || !mounted) return; // user cancelled

    final updated = refund.copyWith(
      status: RefundStatus.completed,
      manuallyCompleted: true,
      description: reason.isNotEmpty ? reason : 'Manually marked as completed',
      refundIssuedAt: refund.refundIssuedAt ?? DateTime.now(),
    );
    await _storage.mergeAndSave([updated]);
    setState(() => _refund = updated);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Expanded(child: Text('Marked as completed — sync won\'t change this')),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showEditMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.currency_exchange, color: AppColors.primary),
              title: const Text('Change currency'),
              onTap: () {
                Navigator.pop(ctx);
                _showCurrencyPicker(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _currencyName(String symbol) {
    switch (symbol) {
      case '₹': return 'INR';
      case '\$': return 'USD';
      case '€': return 'EUR';
      case '£': return 'GBP';
      case '¥': return 'JPY';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => context.pop(),
          ),
          title: const Text('Refund Progress'),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }
    if (_refund == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => context.pop(),
          ),
          title: const Text('Refund Progress'),
        ),
        body: const Center(
          child: Text('Refund not found in local storage.'),
        ),
      );
    }
    final refund = _refund!;
    final steps = _timelineFor(refund);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Refund Progress'),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz),
            onPressed: () => _showEditMenu(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            // ── Overdue warning banner ───────────────────────────────────
            if (refund.isOverdue) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFB91C1C).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFB91C1C).withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Color(0xFFB91C1C), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Refund Overdue',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFB91C1C),
                            ),
                          ),
                          Text(
                            'Expected within ${refund.expectedDays} days · '
                            '${refund.overdueDays} day${refund.overdueDays == 1 ? '' : 's'} past deadline',
                            style: TextStyle(
                              fontSize: 11,
                              color: const Color(0xFFB91C1C).withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            // ── Refund source info card ──────────────────────────────────
            _RefundInfoCard(refund: refund, onEditCurrency: () => _showCurrencyPicker(context)),
            const SizedBox(height: 20),
            _Timeline(steps: steps),
            const SizedBox(height: 32),
            _MerchantContactCard(refund: refund),
            const SizedBox(height: 120),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
          child: refund.status == RefundStatus.completed
              ? Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: AppColors.success, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Refund Completed',
                        style: TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                )
              : FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.success,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => _markCompleted(context),
                  icon: const Icon(Icons.check_circle_outline, size: 20),
                  label: const Text(
                    'Mark as Completed',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
        ),
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.steps});

  final List<RefundTimelineStep> steps;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 19,
          top: 24,
          bottom: 24,
          child: CustomPaint(
            size: const Size(2, double.infinity),
            painter: _DashedLinePainter(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF334155)
                  : const Color(0xFFCBD5E1),
            ),
          ),
        ),
        Column(
          children: steps.asMap().entries.map((entry) {
            final i = entry.key;
            final step = entry.value;
            return _TimelineStepRow(
              step: step,
              isLast: i == steps.length - 1,
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  _DashedLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    const dashHeight = 4.0;
    const gap = 4.0;
    var y = 0.0;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(0, y + dashHeight), paint);
      y += dashHeight + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TimelineStepRow extends StatelessWidget {
  const _TimelineStepRow({required this.step, required this.isLast});

  final RefundTimelineStep step;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPending = !step.isCompleted && !step.isCurrent && !step.isSkipped;

    // Circle color
    final circleColor = step.isManualClose
        ? AppColors.success
        : step.isSkipped
            ? (isDark ? const Color(0xFF374151) : const Color(0xFFD1D5DB))
            : step.isCompleted
                ? AppColors.success
                : step.isCurrent
                    ? AppColors.pending
                    : (isDark ? const Color(0xFF4B5563) : const Color(0xFFD1D5DB));

    // Circle icon
    final IconData circleIcon = step.isManualClose
        ? Icons.pan_tool_outlined
        : step.isSkipped
            ? Icons.close
            : step.isCompleted
                ? (step.title == 'Merchant Confirmed'
                    ? Icons.verified_outlined
                    : step.title == 'Message Parsed'
                        ? Icons.psychology_outlined
                        : Icons.check)
                : step.isCurrent
                    ? Icons.account_balance_outlined
                    : Icons.payments_outlined;

    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Opacity(
        opacity: isPending ? 0.45 : (step.isSkipped ? 0.55 : 1.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Circle ──────────────────────────────────────────────────
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: circleColor,
                shape: BoxShape.circle,
                boxShadow: step.isSkipped
                    ? []
                    : [
                        BoxShadow(
                          color: circleColor.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                border: step.isCurrent
                    ? Border.all(
                        color: AppColors.pending.withValues(alpha: 0.3),
                        width: 4)
                    : step.isManualClose
                        ? Border.all(
                            color: AppColors.success.withValues(alpha: 0.3),
                            width: 3)
                        : null,
              ),
              child: Icon(circleIcon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 16),

            // ── Content card ─────────────────────────────────────────────
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: step.isManualClose
                      ? AppColors.success.withValues(alpha: isDark ? 0.12 : 0.07)
                      : step.isSkipped
                          ? (isDark
                              ? Colors.white.withValues(alpha: 0.03)
                              : const Color(0xFFF3F4F6))
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : AppColors.surfaceLight),
                  borderRadius: BorderRadius.circular(16),
                  border: step.isManualClose
                      ? Border.all(
                          color: AppColors.success.withValues(alpha: 0.35))
                      : step.isCurrent
                          ? Border.all(
                              color: AppColors.pending.withValues(alpha: 0.2))
                          : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title — strikethrough when skipped
                        Flexible(
                          child: Text(
                            step.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  color: step.isManualClose
                                      ? AppColors.success
                                      : step.isSkipped
                                          ? AppColors.textMuted
                                          : step.isCurrent
                                              ? AppColors.pending
                                              : null,
                                  decoration: step.isSkipped
                                      ? TextDecoration.lineThrough
                                      : null,
                                  decorationColor: AppColors.textMuted,
                                ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          step.timestamp,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                decoration: step.isSkipped
                                    ? TextDecoration.lineThrough
                                    : null,
                                decorationColor: AppColors.textMuted,
                              ),
                        ),
                      ],
                    ),

                    // Snippet
                    if (step.snippet != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: step.isManualClose
                              ? AppColors.success.withValues(alpha: 0.06)
                              : (isDark
                                  ? Colors.black.withValues(alpha: 0.2)
                                  : Colors.white.withValues(alpha: 0.5)),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: step.isManualClose
                                ? AppColors.success.withValues(alpha: 0.2)
                                : (isDark
                                    ? const Color(0xFF4B5563)
                                    : const Color(0xFFD1D5DB)),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              step.snippet!,
                              style:
                                  Theme.of(context).textTheme.bodySmall?.copyWith(
                                        fontStyle: step.isManualClose
                                            ? FontStyle.normal
                                            : FontStyle.italic,
                                        color: step.isManualClose
                                            ? AppColors.success
                                            : null,
                                      ),
                            ),
                            if (!step.isManualClose) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    step.source == RefundSource.email
                                        ? Icons.mail_outline
                                        : Icons.sms_outlined,
                                    size: 12,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Source: ${step.source.name.toUpperCase()}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],

                    if (step.snippet == null &&
                        !step.isCompleted &&
                        !step.isSkipped &&
                        step.title == 'Bank Processing') ...[
                      const SizedBox(height: 8),
                      Text(
                        'Verifying transaction with your financial institution. Usually takes 2–3 business days.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (step.snippet == null &&
                        !step.isCompleted &&
                        !step.isSkipped &&
                        step.title == 'Funds Released')
                      Text(
                        'Available in your balance once released.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Top card on the detail screen showing issuer, bank and destination.
class _RefundInfoCard extends StatelessWidget {
  const _RefundInfoCard({required this.refund, required this.onEditCurrency});
  final RefundItem refund;
  final VoidCallback onEditCurrency;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : AppColors.surfaceLight;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        children: [
          // ── Top: issuer + amount ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                // Company icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.storefront_outlined,
                      color: AppColors.primary, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        refund.refundIssuer ?? refund.merchantName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Refunded by',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textMuted,
                            ),
                      ),
                    ],
                  ),
                ),
                // Amount + edit currency
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      refund.formattedAmount,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                    ),
                    InkWell(
                      onTap: onEditCurrency,
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.edit_outlined,
                                size: 11, color: AppColors.primary),
                            const SizedBox(width: 3),
                            Text(
                              'Edit currency',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Divider(
            height: 1,
            color: AppColors.primary.withValues(alpha: 0.12),
          ),

          // ── Bottom: bank + destination ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: _InfoChip(
                    emoji: '🏦',
                    label: 'Bank',
                    value: refund.bankName ?? 'Unknown',
                    color: const Color(0xFF1565C0),
                    bgColor: const Color(0xFFE3F2FD),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _InfoChip(
                    emoji: refund.refundDestination.icon,
                    label: 'Credited to',
                    value: refund.refundDestination.label,
                    color: const Color(0xFF2E7D32),
                    bgColor: const Color(0xFFE8F5E9),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _InfoChip(
                    emoji: '📋',
                    label: 'Order',
                    value: refund.orderId != null
                        ? '#${refund.orderId}'
                        : '#${refund.id.substring(0, 6)}',
                    color: const Color(0xFF6A1B9A),
                    bgColor: const Color(0xFFF3E5F5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.emoji,
    required this.label,
    required this.value,
    required this.color,
    required this.bgColor,
  });

  final String emoji;
  final String label;
  final String value;
  final Color color;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? color.withValues(alpha: 0.15) : bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color.withValues(alpha: 0.8),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet that asks the user why they're manually completing the refund.
/// Returns the typed reason string, or null if cancelled.
class _MarkCompleteSheet extends StatefulWidget {
  @override
  State<_MarkCompleteSheet> createState() => _MarkCompleteSheetState();
}

class _MarkCompleteSheetState extends State<_MarkCompleteSheet> {
  final _ctrl = TextEditingController();

  static const _quickReasons = [
    'Received in bank account',
    'Confirmed via message',
    'Amount reflected in wallet',
    'Resolved by merchant',
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.check_circle_outline,
                    color: AppColors.success, size: 20),
              ),
              const SizedBox(width: 12),
              Text('Mark as Completed',
                  style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Let us know why you\'re marking this as done. '
            'This note is stored locally and sync will never revert it.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          // Quick-pick chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _quickReasons.map((r) {
              return ActionChip(
                label: Text(r, style: const TextStyle(fontSize: 12)),
                onPressed: () => setState(() => _ctrl.text = r),
                backgroundColor:
                    _ctrl.text == r
                        ? AppColors.success.withValues(alpha: 0.12)
                        : null,
                side: BorderSide(
                  color: _ctrl.text == r
                      ? AppColors.success.withValues(alpha: 0.5)
                      : Colors.grey.withValues(alpha: 0.3),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          // Free-text field
          TextField(
            controller: _ctrl,
            maxLines: 2,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Or type your own reason…',
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, null),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.success,
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () =>
                      Navigator.pop(context, _ctrl.text.trim()),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Confirm',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MerchantContactCard extends StatelessWidget {
  const _MerchantContactCard({required this.refund});
  final RefundItem refund;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final issuer = refund.refundIssuer ?? refund.merchantName;
    final bank = refund.bankName;
    final dest = refund.refundDestination;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Refund Details',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.textMuted,
                      letterSpacing: 1,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _DetailRow(
            icon: Icons.storefront_outlined,
            label: 'Issued by',
            value: issuer,
          ),
          const SizedBox(height: 10),
          _DetailRow(
            icon: Icons.account_balance_outlined,
            label: 'Credited to bank',
            value: bank ?? 'Not detected',
            dimmed: bank == null,
          ),
          const SizedBox(height: 10),
          _DetailRow(
            icon: Icons.credit_card_outlined,
            label: 'Payment method',
            value: dest == RefundDestination.unknown
                ? 'Not detected'
                : dest.label,
            dimmed: dest == RefundDestination.unknown,
          ),
          if (refund.description?.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            _DetailRow(
              icon: Icons.note_outlined,
              label: 'Note',
              value: refund.description!,
            ),
          ],
          const SizedBox(height: 14),
          Center(
            child: Text(
              'Data extracted from your SMS. '
              'Contact the merchant directly for disputes.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textMuted.withValues(alpha: 0.7),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.dimmed = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: Theme.of(context).textTheme.labelSmall),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: dimmed ? AppColors.textMuted : null,
                        fontStyle:
                            dimmed ? FontStyle.italic : FontStyle.normal,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

