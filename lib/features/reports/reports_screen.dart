import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_drawer.dart';
import '../../models/refund_item.dart';
import '../../services/export_service.dart';
import '../../services/refund_storage_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Colour palette used across every chart
// ─────────────────────────────────────────────────────────────────────────────
const _catColors = {
  RefundCategory.travel:        Color(0xFF1565C0),
  RefundCategory.retail:        Color(0xFF6A1B9A),
  RefundCategory.services:      Color(0xFF2E7D32),
  RefundCategory.foodDining:    Color(0xFFE65100),
  RefundCategory.electronics:   Color(0xFF37474F),
  RefundCategory.entertainment: Color(0xFFAD1457),
};
const _fallbackCatColor = Color(0xFF00695C);

const _destColors = {
  RefundDestination.bankAccount: Color(0xFF1565C0),
  RefundDestination.creditCard:  Color(0xFF6A1B9A),
  RefundDestination.debitCard:   Color(0xFF0277BD),
  RefundDestination.wallet:      Color(0xFFE65100),
  RefundDestination.upi:         Color(0xFF2E7D32),
  RefundDestination.unknown:     Color(0xFF90A4AE),
};

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _storage = RefundStorageService();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  List<RefundItem> _refunds = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _storage.loadRefunds();
    if (!mounted) return;
    setState(() {
      _refunds = list;
      _loading = false;
    });
  }

  // ── Computed values ────────────────────────────────────────────────────────

  int get _total => _refunds.length;
  int get _completed => _refunds.where((r) => r.status == RefundStatus.completed).length;
  int get _pending => _refunds.where((r) => r.status != RefundStatus.completed).length;
  int get _overdue => _refunds.where((r) => r.isOverdue).length;

  double get _totalAmount => _refunds.fold(0.0, (s, r) => s + r.amount);
  double get _pendingAmount =>
      _refunds.where((r) => r.status != RefundStatus.completed).fold(0.0, (s, r) => s + r.amount);
  double get _completedAmount =>
      _refunds.where((r) => r.status == RefundStatus.completed).fold(0.0, (s, r) => s + r.amount);

  String get _currency {
    if (_refunds.isEmpty) return '₹';
    final freq = <String, int>{};
    for (final r in _refunds) freq[r.currency] = (freq[r.currency] ?? 0) + 1;
    return freq.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  double get _recoveryRate =>
      _total == 0 ? 0 : (_completed / _total).clamp(0.0, 1.0);

  // Category breakdown (amounts)
  List<({RefundCategory cat, double amount, int count, Color color})> get _catData {
    final map = <RefundCategory, ({double amount, int count})>{
      for (final c in RefundCategory.values) c: (amount: 0, count: 0),
    };
    for (final r in _refunds) {
      final c = r.category ?? RefundCategory.retail;
      final prev = map[c]!;
      map[c] = (amount: prev.amount + r.amount, count: prev.count + 1);
    }
    return map.entries
        .where((e) => e.value.count > 0)
        .map((e) => (
              cat: e.key,
              amount: e.value.amount,
              count: e.value.count,
              color: _catColors[e.key] ?? _fallbackCatColor,
            ))
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
  }

  // Monthly activity: last 6 months, count of refunds detected
  List<({String label, int count, double amount})> get _monthlyData {
    final now = DateTime.now();
    final months = List.generate(6, (i) {
      final dt = DateTime(now.year, now.month - (5 - i));
      return dt;
    });
    return months.map((m) {
      final refundsInMonth = _refunds.where((r) {
        final d = r.detectedAt ?? r.refundIssuedAt;
        if (d == null) return false;
        return d.year == m.year && d.month == m.month;
      }).toList();
      return (
        label: DateFormat('MMM').format(m),
        count: refundsInMonth.length,
        amount: refundsInMonth.fold(0.0, (s, r) => s + r.amount),
      );
    }).toList();
  }

  // Source breakdown
  int get _smsCount => _refunds.where((r) => r.source == RefundSource.sms).length;
  int get _emailCount => _refunds.where((r) => r.source == RefundSource.email).length;

  // Destination breakdown
  Map<RefundDestination, int> get _destData {
    final map = <RefundDestination, int>{};
    for (final r in _refunds) {
      map[r.refundDestination] = (map[r.refundDestination] ?? 0) + 1;
    }
    return map;
  }

  // Top 5 merchants by total amount
  List<({String name, double amount, int count})> get _topMerchants {
    final map = <String, ({double amount, int count})>{};
    for (final r in _refunds) {
      final key = r.refundIssuer ?? r.merchantName;
      final prev = map[key] ?? (amount: 0, count: 0);
      map[key] = (amount: prev.amount + r.amount, count: prev.count + 1);
    }
    final list = map.entries
        .map((e) => (name: e.key, amount: e.value.amount, count: e.value.count))
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
    return list.take(5).toList();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: const AppDrawer(currentRoute: '/reports'),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, size: 26),
          tooltip: 'Menu',
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.ios_share_outlined),
            tooltip: 'Export CSV',
            onPressed: _refunds.isEmpty ? null : () async {
              final ok = await ExportService.exportCsv(_refunds);
              if (!ok && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Export cancelled or failed.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _refunds.isEmpty
              ? _buildEmpty(context)
              : _buildContent(context),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bar_chart_rounded,
              size: 72, color: AppColors.textMuted.withValues(alpha: 0.35)),
          const SizedBox(height: 16),
          Text('No data yet',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 8),
          Text('Sync SMS or add refunds manually to see reports.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textMuted),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. Summary KPI tiles ──────────────────────────────────────────
          _SectionTitle('Summary'),
          const SizedBox(height: 12),
          _buildSummaryGrid(context),
          const SizedBox(height: 28),

          // ── 2. Recovery rate ring ─────────────────────────────────────────
          _SectionTitle('Recovery Rate'),
          const SizedBox(height: 12),
          _buildRecoveryCard(context),
          const SizedBox(height: 28),

          // ── 3. Category donut ─────────────────────────────────────────────
          if (_catData.isNotEmpty) ...[
            _SectionTitle('Amount by Category'),
            const SizedBox(height: 12),
            _buildCategoryDonut(context),
            const SizedBox(height: 28),
          ],

          // ── 4. Monthly bar chart ──────────────────────────────────────────
          _SectionTitle('Monthly Activity (last 6 months)'),
          const SizedBox(height: 12),
          _buildMonthlyBars(context),
          const SizedBox(height: 28),

          // ── 5. Source breakdown ───────────────────────────────────────────
          if (_total > 0) ...[
            _SectionTitle('Source Breakdown'),
            const SizedBox(height: 12),
            _buildSourceCard(context),
            const SizedBox(height: 28),
          ],

          // ── 6. Payment destination ────────────────────────────────────────
          if (_destData.isNotEmpty) ...[
            _SectionTitle('Refund Destination'),
            const SizedBox(height: 12),
            _buildDestinationCard(context),
            const SizedBox(height: 28),
          ],

          // ── 7. Top merchants ──────────────────────────────────────────────
          if (_topMerchants.isNotEmpty) ...[
            _SectionTitle('Top Merchants by Amount'),
            const SizedBox(height: 12),
            _buildTopMerchants(context),
          ],
        ],
      ),
    );
  }

  // ── 1. Summary Grid ───────────────────────────────────────────────────────

  Widget _buildSummaryGrid(BuildContext context) {
    final fmt = NumberFormat.compact();
    final tiles = [
      (
        label: 'Total Tracked',
        value: '$_total',
        sub: '$_currency${fmt.format(_totalAmount)}',
        icon: Icons.receipt_long_outlined,
        color: AppColors.primary,
      ),
      (
        label: 'Pending',
        value: '$_pending',
        sub: '$_currency${fmt.format(_pendingAmount)}',
        icon: Icons.pending_actions_outlined,
        color: const Color(0xFFD97706),
      ),
      (
        label: 'Recovered',
        value: '$_completed',
        sub: '$_currency${fmt.format(_completedAmount)}',
        icon: Icons.check_circle_outline,
        color: AppColors.success,
      ),
      (
        label: 'Overdue',
        value: '$_overdue',
        sub: _overdue == 0 ? 'All on track' : '$_overdue need attention',
        icon: Icons.warning_amber_rounded,
        color: const Color(0xFFB91C1C),
      ),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: tiles.map((t) => _KpiTile(t.label, t.value, t.sub, t.icon, t.color)).toList(),
    );
  }

  // ── 2. Recovery Rate Ring ────────────────────────────────────────────────

  Widget _buildRecoveryCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _Card(
      child: Row(
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: CustomPaint(
              painter: _RingChartPainter(
                value: _recoveryRate,
                color: AppColors.success,
                bgColor: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0xFFE5E7EB),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(_recoveryRate * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppColors.success,
                      ),
                    ),
                    Text(
                      'recovered',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LegendRow(
                  color: AppColors.success,
                  label: 'Completed',
                  value: '$_completed refunds',
                ),
                const SizedBox(height: 12),
                _LegendRow(
                  color: const Color(0xFFD97706),
                  label: 'Pending',
                  value: '$_pending refunds',
                ),
                if (_overdue > 0) ...[
                  const SizedBox(height: 12),
                  _LegendRow(
                    color: const Color(0xFFB91C1C),
                    label: 'Overdue',
                    value: '$_overdue refunds',
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 3. Category Donut ────────────────────────────────────────────────────

  Widget _buildCategoryDonut(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalCatAmount = _catData.fold(0.0, (s, d) => s + d.amount);

    final segments = _catData.map((d) => (
          sweep: totalCatAmount > 0 ? (d.amount / totalCatAmount) * 2 * math.pi : 0.0,
          color: d.color,
        )).toList();

    return _Card(
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 130,
                height: 130,
                child: CustomPaint(
                  painter: _DonutChartPainter(
                    segments: segments,
                    bgColor: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : const Color(0xFFF3F4F6),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$_currency${NumberFormat.compact().format(totalCatAmount)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                        Text(
                          'total',
                          style: TextStyle(
                              fontSize: 10, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _catData.take(5).map((d) {
                    final pct = totalCatAmount > 0
                        ? ((d.amount / totalCatAmount) * 100).toStringAsFixed(1)
                        : '0';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _LegendRow(
                        color: d.color,
                        label: d.cat.label,
                        value: '$pct%',
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Full category breakdown table
          ...(_catData.map((d) {
            final pct = totalCatAmount > 0
                ? (d.amount / totalCatAmount).clamp(0.0, 1.0)
                : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: d.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          d.cat.label,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        '$_currency${d.amount.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: d.color,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${d.count}x',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 5,
                      backgroundColor: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : const Color(0xFFE5E7EB),
                      valueColor: AlwaysStoppedAnimation(d.color),
                    ),
                  ),
                ],
              ),
            );
          })),
        ],
      ),
    );
  }

  // ── 4. Monthly Bars ──────────────────────────────────────────────────────

  Widget _buildMonthlyBars(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final data = _monthlyData;
    final maxCount = data.fold(0, (m, d) => d.count > m ? d.count : m);
    final today = DateTime.now();

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: data.map((d) {
              final isCurrentMonth =
                  d.label == DateFormat('MMM').format(today);
              final frac = maxCount > 0 ? d.count / maxCount : 0.0;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (d.count > 0)
                        Text(
                          '${d.count}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isCurrentMonth
                                ? AppColors.primary
                                : AppColors.textMuted,
                          ),
                        ),
                      const SizedBox(height: 3),
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(5)),
                        child: Container(
                          height: (frac * 100).clamp(4.0, 100.0),
                          decoration: BoxDecoration(
                            color: isCurrentMonth
                                ? AppColors.primary
                                : (isDark
                                    ? AppColors.primary.withValues(alpha: 0.35)
                                    : AppColors.primary.withValues(alpha: 0.2)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
          Row(
            children: data.map((d) {
              final isCurrentMonth =
                  d.label == DateFormat('MMM').format(today);
              return Expanded(
                child: Text(
                  d.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isCurrentMonth
                        ? FontWeight.w800
                        : FontWeight.w500,
                    color: isCurrentMonth
                        ? AppColors.primary
                        : AppColors.textMuted,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          // Amounts below bars
          Text(
            'Refunds detected per month.',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  // ── 5. Source Breakdown ──────────────────────────────────────────────────

  Widget _buildSourceCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final smsRatio = _total > 0 ? _smsCount / _total : 0.0;
    final emailRatio = _total > 0 ? _emailCount / _total : 0.0;

    return _Card(
      child: Column(
        children: [
          _SourceBar(
            icon: Icons.sms_outlined,
            label: 'SMS',
            count: _smsCount,
            total: _total,
            ratio: smsRatio,
            color: AppColors.primary,
            isDark: isDark,
          ),
          const SizedBox(height: 14),
          _SourceBar(
            icon: Icons.mail_outline,
            label: 'Email',
            count: _emailCount,
            total: _total,
            ratio: emailRatio,
            color: const Color(0xFF1565C0),
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  // ── 6. Destination Breakdown ─────────────────────────────────────────────

  Widget _buildDestinationCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final entries = _destData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxCount =
        entries.fold(0, (m, e) => e.value > m ? e.value : m);

    return _Card(
      child: Column(
        children: entries.map((e) {
          final dest = e.key;
          if (e.value == 0) return const SizedBox.shrink();
          final color = _destColors[dest] ?? const Color(0xFF90A4AE);
          final ratio = maxCount > 0 ? e.value / maxCount : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Text(dest.icon, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            dest.label,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${e.value} refund${e.value == 1 ? '' : 's'}',
                            style: TextStyle(
                                fontSize: 11,
                                color: color,
                                fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 5,
                          backgroundColor: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : const Color(0xFFE5E7EB),
                          valueColor: AlwaysStoppedAnimation(color),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── 7. Top Merchants ────────────────────────────────────────────────────

  Widget _buildTopMerchants(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final top = _topMerchants;
    final maxAmt = top.fold(0.0, (m, t) => t.amount > m ? t.amount : m);

    return _Card(
      child: Column(
        children: top.asMap().entries.map((entry) {
          final i = entry.key;
          final t = entry.value;
          final ratio = maxAmt > 0 ? t.amount / maxAmt : 0.0;
          const colors = [
            Color(0xFF6A1B9A),
            Color(0xFF1565C0),
            Color(0xFF2E7D32),
            Color(0xFFE65100),
            Color(0xFF37474F),
          ];
          final color = colors[i % colors.length];
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: color),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              t.name,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w700),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '$_currency${t.amount.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 5,
                          backgroundColor: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : const Color(0xFFE5E7EB),
                          valueColor: AlwaysStoppedAnimation(color),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${t.count} refund${t.count == 1 ? '' : 's'}',
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE5E7EB),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0D000000),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile(this.label, this.value, this.sub, this.icon, this.color);

  final String label;
  final String value;
  final String sub;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? color.withValues(alpha: 0.1)
            : color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color.withValues(alpha: 0.85),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : color,
              height: 1.1,
            ),
          ),
          Text(
            sub,
            style: const TextStyle(
                fontSize: 10,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow(
      {required this.color, required this.label, required this.value});

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ),
        Text(value,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color)),
      ],
    );
  }
}

class _SourceBar extends StatelessWidget {
  const _SourceBar({
    required this.icon,
    required this.label,
    required this.count,
    required this.total,
    required this.ratio,
    required this.color,
    required this.isDark,
  });

  final IconData icon;
  final String label;
  final int count;
  final int total;
  final double ratio;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final pct =
        total > 0 ? (ratio * 100).toStringAsFixed(0) : '0';
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                  Text('$count refunds · $pct%',
                      style: TextStyle(
                          fontSize: 11,
                          color: color,
                          fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 7,
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFFE5E7EB),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CustomPainters
// ─────────────────────────────────────────────────────────────────────────────

/// Circular ring chart — shows a single ratio value (e.g. recovery rate).
class _RingChartPainter extends CustomPainter {
  _RingChartPainter({
    required this.value,
    required this.color,
    required this.bgColor,
  });

  final double value;
  final Color color;
  final Color bgColor;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(cx, cy) - 8;
    const strokeW = 12.0;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);

    // Background ring
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi,
      false,
      Paint()
        ..color = bgColor
        ..strokeWidth = strokeW
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Filled arc
    if (value > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * value.clamp(0.0, 1.0),
        false,
        Paint()
          ..color = color
          ..strokeWidth = strokeW
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingChartPainter old) =>
      old.value != value || old.color != color;
}

/// Multi-segment donut chart for category breakdown.
class _DonutChartPainter extends CustomPainter {
  _DonutChartPainter({
    required this.segments,
    required this.bgColor,
  });

  final List<({double sweep, Color color})> segments;
  final Color bgColor;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(cx, cy) - 6;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    const strokeW = 16.0;
    const gap = 0.03; // radians gap between segments

    // Background ring
    canvas.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..color = bgColor
        ..strokeWidth = strokeW
        ..style = PaintingStyle.stroke,
    );

    if (segments.isEmpty) return;

    var startAngle = -math.pi / 2;
    for (final seg in segments) {
      if (seg.sweep <= 0) continue;
      canvas.drawArc(
        rect,
        startAngle + gap / 2,
        seg.sweep - gap,
        false,
        Paint()
          ..color = seg.color
          ..strokeWidth = strokeW
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.butt,
      );
      startAngle += seg.sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutChartPainter old) =>
      old.segments.length != segments.length;
}
