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

class _RefundDetailScreenState extends State<RefundDetailScreen> {
  final RefundStorageService _storage = RefundStorageService();
  RefundItem? _refund;
  bool _loading = true;

  static List<RefundTimelineStep> _timelineFor(RefundItem? refund) {
    if (refund == null) return [];
    return [
      RefundTimelineStep(
        title: 'Message Parsed',
        timestamp: refund.detectedAt != null
            ? _formatDate(refund.detectedAt!)
            : 'Oct 12, 10:24 AM',
        isCompleted: true,
        source: refund.source,
        snippet: refund.rawSnippet ??
            'Your refund of \$${refund.amount.toStringAsFixed(2)} has been detected.',
      ),
      const RefundTimelineStep(
        title: 'Merchant Confirmed',
        timestamp: 'Oct 12, 02:15 PM',
        isCompleted: true,
        source: RefundSource.sms,
        snippet:
            'Ref: RFND-920. We have processed your refund. Funds should reach your bank shortly.',
      ),
      const RefundTimelineStep(
        title: 'Bank Processing',
        timestamp: 'Oct 13, 09:00 AM',
        isCompleted: false,
        source: RefundSource.sms,
        isCurrent: true,
      ),
      const RefundTimelineStep(
        title: 'Funds Released',
        timestamp: 'Awaiting',
        isCompleted: false,
        source: RefundSource.sms,
      ),
    ];
  }

  static String _formatDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final h = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    final am = d.hour < 12;
    return '${months[d.month - 1]} ${d.day}, $h:${d.minute.toString().padLeft(2, '0')} ${am ? 'AM' : 'PM'}';
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => context.pop(),
          ),
          title: const Text('Refund Progress Tree'),
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
          title: const Text('Refund Progress Tree'),
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
        title: const Text('Refund Progress Tree'),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text(
              'Refund for Order #${refund.orderId ?? refund.id}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Total amount: \$${refund.amount.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textMuted,
                  ),
            ),
            const SizedBox(height: 24),
            _Timeline(steps: steps),
            const SizedBox(height: 32),
            _MerchantContactCard(),
            const SizedBox(height: 120),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: FilledButton.icon(
            onPressed: _loadRefund,
            icon: const Icon(Icons.sync, size: 20),
            label: const Text('Update Tree'),
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
    final isPending = !step.isCompleted && !step.isCurrent;
    final circleColor = step.isCompleted
        ? AppColors.success
        : step.isCurrent
            ? AppColors.pending
            : (Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF4B5563)
                : const Color(0xFFD1D5DB));
    final icon = step.isCompleted
        ? Icons.psychology
        : step.isCurrent
            ? Icons.account_balance_outlined
            : Icons.payments_outlined;
    if (step.isCompleted) {
      if (step.title == 'Merchant Confirmed') {
        // use verified icon for second step
      }
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: circleColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: circleColor.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
              border: step.isCurrent
                  ? Border.all(color: AppColors.pending.withValues(alpha: 0.3), width: 4)
                  : null,
            ),
            child: Icon(
              step.title == 'Merchant Confirmed'
                  ? Icons.verified_outlined
                  : step.title == 'Message Parsed'
                      ? Icons.psychology_outlined
                      : icon,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Opacity(
              opacity: isPending ? 0.5 : 1,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.05)
                      : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(16),
                  border: step.isCurrent
                      ? Border.all(color: AppColors.pending.withValues(alpha: 0.2))
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          step.title,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: step.isCurrent ? AppColors.pending : null,
                              ),
                        ),
                        Text(
                          step.timestamp,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                    if (step.snippet != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.black.withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF4B5563)
                                : const Color(0xFFD1D5DB),
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              step.snippet!,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontStyle: FontStyle.italic,
                                  ),
                            ),
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
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (step.snippet == null && !step.isCompleted && step.title == 'Bank Processing') ...[
                      const SizedBox(height: 8),
                      Text(
                        'Verifying transaction with your financial institution. This usually takes 2-3 business days.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (step.snippet == null && !step.isCompleted && step.title == 'Funds Released')
                      Text(
                        'Available in your balance.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MerchantContactCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.05)
            : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user_outlined, color: AppColors.success, size: 22),
              const SizedBox(width: 8),
              Text(
                'Official Merchant Contact',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.textMuted,
                      letterSpacing: 1,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ContactRow(
            icon: Icons.call_outlined,
            label: 'Support Line',
            value: '+1 (800) 555-0199',
            onCopy: () {},
          ),
          const SizedBox(height: 12),
          _ContactRow(
            icon: Icons.alternate_email,
            label: 'Official Email',
            value: 'support@merchant.com',
            onCopy: () {},
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Response time typically under 24 hours',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onCopy,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
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
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 20, color: AppColors.textMuted),
            onPressed: onCopy,
          ),
        ],
      ),
    );
  }
}
