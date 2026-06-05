import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/responsive.dart';
import '../../core/widgets/app_drawer.dart';
import '../../core/widgets/banner_ad_widget.dart';
import '../../models/refund_item.dart';
import '../../services/refund_storage_service.dart';

class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  final _storage = RefundStorageService();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  List<RefundItem> _completed = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await _storage.loadRefunds();
    if (!mounted) return;
    setState(() {
      _completed = all
          .where((r) => r.status == RefundStatus.completed)
          .toList()
        ..sort((a, b) {
          final da = a.refundIssuedAt ?? a.detectedAt ?? DateTime(0);
          final db = b.refundIssuedAt ?? b.detectedAt ?? DateTime(0);
          return db.compareTo(da);
        });
      _loading = false;
    });
  }

  // ── Computed stats ────────────────────────────────────────────────────────

  double get _thisYearTotal {
    final year = DateTime.now().year;
    return _completed
        .where((r) => (r.refundIssuedAt ?? r.detectedAt)?.year == year)
        .fold(0.0, (s, r) => s + r.amount);
  }

  int get _thisYearCount {
    final year = DateTime.now().year;
    return _completed
        .where((r) => (r.refundIssuedAt ?? r.detectedAt)?.year == year)
        .length;
  }

  String get _dominantCurrency {
    if (_completed.isEmpty) return '₹';
    final freq = <String, int>{};
    for (final r in _completed) freq[r.currency] = (freq[r.currency] ?? 0) + 1;
    return freq.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  // ── Grouping ──────────────────────────────────────────────────────────────

  /// Groups completed refunds by (year, month), newest first.
  List<({String label, List<RefundItem> items})> get _groups {
    final map = <String, List<RefundItem>>{};
    for (final r in _completed) {
      final dt = r.refundIssuedAt ?? r.detectedAt;
      final key = dt != null
          ? DateFormat('MMMM yyyy').format(dt)
          : 'Unknown date';
      map.putIfAbsent(key, () => []).add(r);
    }
    return map.entries
        .map((e) => (label: e.key, items: e.value))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: const AppDrawer(currentRoute: '/archive'),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, size: 26),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('Archive'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : _completed.isEmpty
                    ? _buildEmpty(context)
                    : _buildContent(context),
          ),
          const BannerAdWidget(),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.archive_outlined,
              size: 64,
              color: AppColors.textMuted.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text('No completed refunds yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textMuted,
                  )),
          const SizedBox(height: 8),
          Text('Completed refunds will appear here.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final groups = _groups;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildSummaryCard(context)),
        for (final group in groups) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(context.hPad, 20, context.hPad, 8),
              child: Text(
                group.label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => _ArchiveTile(
                item: group.items[i],
                onTap: () async {
                  await context.push('/refund/${group.items[i].id}');
                  if (mounted) _load();
                },
              ),
              childCount: group.items.length,
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    final cur = _dominantCurrency;
    return Padding(
      padding: EdgeInsets.fromLTRB(context.hPad, 20, context.hPad, 4),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF004D40), Color(0xFF00695C)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF004D40).withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline,
                color: Colors.white, size: 36),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Received in ${DateTime.now().year}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$cur${_thisYearTotal.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'across $_thisYearCount refund${_thisYearCount == 1 ? '' : 's'}  ·  '
                    '${_completed.length} total completed',
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Archive tile (read-only, no swipe-delete)
// ─────────────────────────────────────────────────────────────────────────────

class _ArchiveTile extends StatelessWidget {
  const _ArchiveTile({required this.item, required this.onTap});

  final RefundItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final date = item.refundIssuedAt ?? item.detectedAt;
    final dateStr = date != null ? DateFormat('d MMM yyyy').format(date) : '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Material(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: isDark ? 0 : 1,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_outline,
                      color: AppColors.success, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.merchantName,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      if (dateStr.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(dateStr,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            )),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(item.formattedAmount,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.success,
                            )),
                    if (item.manuallyCompleted) ...[
                      const SizedBox(height: 3),
                      const Text('Manual',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textMuted,
                          )),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
