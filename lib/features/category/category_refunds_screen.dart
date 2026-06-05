import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/category_theme.dart';
import '../../models/refund_item.dart';
import '../../services/refund_storage_service.dart';

class CategoryRefundsScreen extends StatefulWidget {
  const CategoryRefundsScreen({super.key, required this.category});

  final RefundCategory category;

  @override
  State<CategoryRefundsScreen> createState() => _CategoryRefundsScreenState();
}

class _CategoryRefundsScreenState extends State<CategoryRefundsScreen>
    with SingleTickerProviderStateMixin {
  final _storage = RefundStorageService();

  List<RefundItem> _all = [];
  bool _loading = true;

  String? _chipFilter;

  late final AnimationController _entranceCtrl;

  // Must match RefundItem.statusLabel values exactly.
  static const _chips = [
    'Processing',
    'Awaiting Confirmation',
    'Bank Processing',
    'Completed',
  ];

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _load();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final all = await _storage.loadRefunds();
    if (!mounted) return;
    setState(() {
      _all = all.where((r) => r.category == widget.category).toList()
        ..sort((a, b) =>
            (b.detectedAt ?? b.refundIssuedAt ?? DateTime(0))
                .compareTo(a.detectedAt ?? a.refundIssuedAt ?? DateTime(0)));
      _loading = false;
    });
    _entranceCtrl.forward(from: 0);
  }

  List<RefundItem> get _filtered {
    if (_chipFilter == null) return _all;
    return _all.where((r) => r.statusLabel == _chipFilter).toList();
  }

  Future<void> _delete(RefundItem item) async {
    final saved   = await _storage.loadRefunds();
    final updated = saved.where((r) => r.id != item.id).toList();
    await _storage.saveRefunds(updated);
    if (!mounted) return;
    setState(() {
      _all = _all.where((r) => r.id != item.id).toList();
      _entranceCtrl.forward(from: 0);
    });
  }

  Future<bool> _confirmDelete(RefundItem item) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete refund?'),
        content: Text(
          'Remove "${item.merchantName}" (${item.formattedAmount})?\nThis cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final gradient = gradientForCategory(widget.category);
    final icon     = iconForCategory(widget.category);
    final items    = _filtered;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Pinned AppBar — category name appears exactly ONCE ──────────
          SliverAppBar(
            pinned: true,
            surfaceTintColor: Colors.transparent,
            backgroundColor: gradient.colors.first,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white),
              onPressed: () => context.pop(),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  widget.category.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),

          // ── Summary card — scrolls with content ────────────────────────
          if (!_loading)
            SliverToBoxAdapter(child: _buildSummary(gradient)),

          // ── Status filter chips ──────────────────────────────────────────
          SliverToBoxAdapter(child: _buildChips(gradient)),

          // ── Refund list ─────────────────────────────────────────────────
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (items.isEmpty)
            SliverFillRemaining(child: _empty())
          else
            SliverPadding(
              padding: const EdgeInsets.only(top: 8, bottom: 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _buildDismissible(items[i], i),
                  childCount: items.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Summary card ──────────────────────────────────────────────────────────

  Widget _buildSummary(LinearGradient gradient) {
    // Aggregate per status — only statuses with at least one item are shown.
    final statuses = RefundStatus.values;
    final rows = statuses.map((s) {
      final matched = _all.where((r) => r.status == s).toList();
      return (
        status: s,
        count:  matched.length,
        amount: matched.fold(0.0, (sum, r) => sum + r.amount),
      );
    }).where((r) => r.count > 0).toList();

    final grandTotal   = _all.fold(0.0, (s, r) => s + r.amount);
    final totalPending = _all
        .where((r) => r.status != RefundStatus.completed)
        .fold(0.0, (s, r) => s + r.amount);

    final fmt = NumberFormat('#,##0.00', 'en_IN');
    const sym = '₹';

    return Container(
      decoration: BoxDecoration(gradient: gradient),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      child: Column(
        children: [
          // Top strip: count + pending badge
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Text(
                  '${_all.length} refund${_all.length == 1 ? '' : 's'} in this category',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                if (totalPending > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$sym${fmt.format(totalPending)} pending',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Status breakdown card
          if (rows.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18), width: 1),
              ),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                children: [
                  // Column headers
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('Status',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.55),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5)),
                        ),
                        SizedBox(
                          width: 56,
                          child: Text('Items',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.55),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5)),
                        ),
                        SizedBox(
                          width: 90,
                          child: Text('Amount',
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.55),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5)),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white24, height: 1),
                  const SizedBox(height: 8),

                  // Per-status rows
                  ...rows.map((r) {
                    final color = _statusColour(r.status);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          // Status dot + label
                          Container(
                            width: 8, height: 8,
                            decoration: BoxDecoration(
                                color: color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _statusLabel(r.status),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                height: 1.0,
                              ),
                            ),
                          ),
                          // Count
                          SizedBox(
                            width: 56,
                            child: Text(
                              '${r.count}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                height: 1.0,
                              ),
                            ),
                          ),
                          // Amount
                          SizedBox(
                            width: 90,
                            child: Text(
                              '$sym${fmt.format(r.amount)}',
                              textAlign: TextAlign.end,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 8),
                  Divider(
                      color: Colors.white.withValues(alpha: 0.35), height: 1),
                  const SizedBox(height: 10),

                  // Grand total row
                  Row(
                    children: [
                      const Text('Grand Total',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            height: 1.0,
                          )),
                      const Spacer(),
                      Text(
                        '${_all.length} item${_all.length == 1 ? '' : 's'}',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 12,
                            height: 1.0),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 90,
                        child: Text(
                          '$sym${fmt.format(grandTotal)}',
                          textAlign: TextAlign.end,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _statusLabel(RefundStatus s) {
    switch (s) {
      case RefundStatus.processing:          return 'Processing';
      case RefundStatus.awaitingConfirmation: return 'Awaiting Confirmation';
      case RefundStatus.bankProcessing:      return 'Bank Processing';
      case RefundStatus.completed:           return 'Completed';
    }
  }

  Color _statusColour(RefundStatus s) {
    switch (s) {
      case RefundStatus.processing:          return const Color(0xFFD97706);
      case RefundStatus.awaitingConfirmation:
      case RefundStatus.bankProcessing:      return const Color(0xFFDC2626);
      case RefundStatus.completed:           return const Color(0xFF059669);
    }
  }

  // ── Filter chips ──────────────────────────────────────────────────────────

  Widget _buildChips(LinearGradient gradient) {
    return Container(
      // Chips sit on the gradient background, blending with the summary card.
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            gradient.colors.last.withValues(alpha: 0.25),
            Colors.transparent,
          ],
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(
          children: [
            _Chip(
              label: 'All',
              selected: _chipFilter == null,
              onTap: () => setState(() => _chipFilter = null),
            ),
            ..._chips.map((label) => Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: _Chip(
                    label: label,
                    selected: _chipFilter == label,
                    onTap: () => setState(() =>
                        _chipFilter = _chipFilter == label ? null : label),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  // ── Dismissible wrapper ───────────────────────────────────────────────────

  Widget _buildDismissible(RefundItem item, int index) {
    return Dismissible(
      key: Key('cat_${item.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(item),
      onDismissed:   (_) => _delete(item),
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.error,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline, color: Colors.white, size: 22),
            SizedBox(height: 4),
            Text('Delete',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
      child: _TileWithEntrance(
        index: index,
        controller: _entranceCtrl,
        child: _RefundTile(
          item: item,
          onTap: () async {
            await context.push('/refund/${item.id}');
            if (mounted) _load();
          },
        ),
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconForCategory(widget.category),
              size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            _chipFilter == null
                ? 'No ${widget.category.label} refunds yet'
                : 'No "$_chipFilter" refunds in this category',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

// ── Staggered entrance ────────────────────────────────────────────────────────

class _TileWithEntrance extends StatelessWidget {
  const _TileWithEntrance({
    required this.index,
    required this.controller,
    required this.child,
  });

  final int index;
  final AnimationController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final start = (index * 0.07).clamp(0.0, 0.85);
    final end   = (start + 0.4).clamp(0.0, 1.0);
    final anim  = CurvedAnimation(
      parent: controller,
      curve: Interval(start, end, curve: Curves.easeOut),
    );
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.12),
          end: Offset.zero,
        ).animate(anim),
        child: child,
      ),
    );
  }
}

// ── Status chip ───────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : (isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(20),
          border: selected
              ? null
              : Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? Colors.white
                : (isDark ? Colors.white70 : Colors.grey.shade700),
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}

// ── Refund tile ───────────────────────────────────────────────────────────────

class _RefundTile extends StatefulWidget {
  const _RefundTile({required this.item, required this.onTap});

  final RefundItem item;
  final VoidCallback onTap;

  @override
  State<_RefundTile> createState() => _RefundTileState();
}

class _RefundTileState extends State<_RefundTile> {
  bool _pressed = false;

  String _fmtDate(DateTime? dt) {
    if (dt == null) return '';
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d     = DateTime(dt.year, dt.month, dt.day);
    if (d == today) return 'Today';
    if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('d MMM yyyy').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final item      = widget.item;
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final date      = _fmtDate(item.detectedAt ?? item.refundIssuedAt);
    final meta      = [
      if (date.isNotEmpty) date,
      if (item.orderId?.isNotEmpty == true) '#${item.orderId}',
    ].join('  ·  ');
    final statusClr = item.statusColor;

    return GestureDetector(
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) => setState(() => _pressed = false),
      onTapCancel: ()  => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          child: Material(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            elevation: isDark ? 0 : 1,
            shadowColor: Colors.black.withValues(alpha: 0.06),
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: item.isOverdue
                    ? BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFB91C1C).withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                      )
                    : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: item.isOverdue
                              ? const Color(0xFFB91C1C).withValues(alpha: 0.10)
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : AppColors.primary.withValues(alpha: 0.10)),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          iconForCategory(item.category),
                          color: item.isOverdue
                              ? const Color(0xFFB91C1C)
                              : AppColors.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.merchantName,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            if (meta.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(meta,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                          color: Colors.grey.shade500,
                                          fontSize: 11)),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            item.formattedAmount,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusClr.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              item.statusLabel,
                              style: TextStyle(
                                color: statusClr,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
