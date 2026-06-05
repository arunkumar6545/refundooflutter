import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/category_theme.dart';
import '../../models/refund_item.dart';
import '../../services/refund_storage_service.dart';

/// Shows all refunds for a single [category], with the same status-chip
/// filters that appear on the main dashboard.
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

  // Status chip filter — null means "show all statuses"
  String? _chipFilter;

  // Entrance animation for list tiles
  late final AnimationController _entranceCtrl;

  static const _chips = [
    'Processing',
    'Awaiting Response',
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
    final saved = await _storage.loadRefunds();
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
          // ── Gradient header ─────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(gradient: gradient),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.20),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(icon, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.category.label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  height: 1.1,
                                ),
                              ),
                              Text(
                                '${_all.length} refund${_all.length == 1 ? '' : 's'}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.80),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Keep title in collapsed state
              title: Text(
                widget.category.label,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700),
              ),
              titlePadding: const EdgeInsets.only(left: 56, bottom: 14),
            ),
            backgroundColor: gradient.colors.first,
          ),

          // ── Status filter chips ──────────────────────────────────────────
          SliverToBoxAdapter(child: _buildChips()),

          // ── List ────────────────────────────────────────────────────────
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (items.isEmpty)
            SliverFillRemaining(child: _empty())
          else
            SliverPadding(
              padding: const EdgeInsets.only(top: 8, bottom: 24),
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

  Widget _buildChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        children: [
          // "All" chip to clear the filter
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
    );
  }

  Widget _buildDismissible(RefundItem item, int index) {
    return Dismissible(
      key: Key('cat_refund_${item.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(item),
      onDismissed: (_) => _delete(item),
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
                : 'No "${_chipFilter}" refunds',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

// ── Staggered entrance animation ──────────────────────────────────────────────

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
            fontWeight:
                selected ? FontWeight.w700 : FontWeight.w500,
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
    final item   = widget.item;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final date   = _fmtDate(item.detectedAt ?? item.refundIssuedAt);
    final meta   = [
      if (date.isNotEmpty) date,
      if (item.orderId?.isNotEmpty == true) '#${item.orderId}',
    ].join('  ·  ');

    // Status badge colour
    final statusColor = item.status == RefundStatus.completed
        ? const Color(0xFF16A34A)
        : AppColors.primary;

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
                      // Category icon circle
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
                      // Merchant + meta
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
                              Text(
                                meta,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Colors.grey.shade500,
                                      fontSize: 11,
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Amount + status badge
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            item.formattedAmount,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              item.statusLabel,
                              style: TextStyle(
                                color: statusColor,
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
