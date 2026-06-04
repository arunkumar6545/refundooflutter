import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/responsive.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/app_drawer.dart';
import '../../models/refund_item.dart';
import '../../services/refund_storage_service.dart';
import '../../services/sms_scanner_service.dart';
import '../../services/email_scanner_service.dart';
import '../../services/auth_service.dart';
import '../profile/profile_screen.dart';

/// Gradient backgrounds per category — no network dependency.
const _categoryGradients = {
  RefundCategory.travel: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
  ),
  RefundCategory.retail: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6A1B9A), Color(0xFF4A148C)],
  ),
  RefundCategory.services: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
  ),
  RefundCategory.foodDining: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE65100), Color(0xFFBF360C)],
  ),
  RefundCategory.electronics: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF263238), Color(0xFF37474F)],
  ),
  RefundCategory.entertainment: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFAD1457), Color(0xFF880E4F)],
  ),
};

const _genericGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF004D40), Color(0xFF00695C)],
);

IconData _activityIconFor(RefundCategory? category) {
  switch (category) {
    case RefundCategory.travel:
      return Icons.confirmation_number_outlined;
    case RefundCategory.retail:
      return Icons.shopping_cart_outlined;
    case RefundCategory.services:
      return Icons.description_outlined;
    case RefundCategory.foodDining:
      return Icons.restaurant_outlined;
    case RefundCategory.electronics:
      return Icons.devices_outlined;
    case RefundCategory.entertainment:
      return Icons.movie_outlined;
    default:
      return Icons.receipt_long_outlined;
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

/// Active dashboard filter: from Pending card, Wait Time card, or a category bento.
enum _DashboardFilterKind { all, pending, waitTime, category }

class _DashboardScreenState extends State<DashboardScreen> {
  final RefundStorageService _storage = RefundStorageService();
  final SmsScannerService _smsScanner = SmsScannerService();
  final EmailScannerService _emailScanner = EmailScannerService();
  final AuthService _auth = AuthService();
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  List<RefundItem> _refunds = [];
  bool _loading = true;
  bool _syncing = false;
  _DashboardFilterKind _filterKind = _DashboardFilterKind.all;
  RefundCategory? _filterCategory;
  String _chipFilter = 'All'; // for the existing status chips: All, Processing, Completed, Action Needed
  Offset? _fabOffset; // null until first layout; then user can drag it

  double get _pendingAmount {
    final pending = _refunds.where((r) => r.status != RefundStatus.completed);
    return pending.fold(0.0, (sum, r) => sum + r.amount);
  }

  /// The most common currency among pending refunds, or '₹' if none.
  String get _pendingCurrency {
    final pending = _refunds
        .where((r) => r.status != RefundStatus.completed)
        .map((r) => r.currency)
        .toList();
    if (pending.isEmpty) return '₹';
    final freq = <String, int>{};
    for (final c in pending) freq[c] = (freq[c] ?? 0) + 1;
    return freq.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  /// Average number of days pending refunds have been waiting since detection.
  /// Returns 0 when there are no pending items.
  int get _waitDays {
    final pending = _refunds
        .where((r) => r.status != RefundStatus.completed)
        .toList();
    if (pending.isEmpty) return 0;
    final now = DateTime.now();
    final totalDays = pending.fold<int>(0, (sum, r) {
      final since = r.detectedAt ?? r.refundIssuedAt;
      if (since == null) return sum;
      return sum + now.difference(since).inDays;
    });
    final withDate = pending.where(
        (r) => r.detectedAt != null || r.refundIssuedAt != null).length;
    if (withDate == 0) return 0;
    return (totalDays / withDate).round();
  }

  /// Label describing what _waitDays means.
  String get _waitLabel {
    final days = _waitDays;
    if (days == 0) return '0 days';
    if (days == 1) return '1 day avg wait';
    return '$days days avg wait';
  }

  bool get _hasActiveFilter =>
      _filterKind != _DashboardFilterKind.all ||
      _chipFilter != 'All';

  void _clearFilters() {
    setState(() {
      _filterKind = _DashboardFilterKind.all;
      _filterCategory = null;
      _chipFilter = 'All';
    });
  }

  List<RefundItem> get _filteredRefunds {
    List<RefundItem> list = _refunds;

    // Apply card/category filter first (from Pending, Wait Time, or category bento)
    switch (_filterKind) {
      case _DashboardFilterKind.pending:
        list = list.where((r) => r.status != RefundStatus.completed).toList();
        break;
      case _DashboardFilterKind.waitTime:
        list = list.where((r) => r.status != RefundStatus.completed).toList();
        break;
      case _DashboardFilterKind.category:
        if (_filterCategory != null) {
          list = list.where((r) => r.category == _filterCategory).toList();
        }
        break;
      case _DashboardFilterKind.all:
        break;
    }

    // Then apply status chip filter (All, Processing, Completed, Action Needed, Overdue)
    switch (_chipFilter) {
      case 'Processing':
        list = list.where((r) => r.status == RefundStatus.processing).toList();
        break;
      case 'Completed':
        list = list.where((r) => r.status == RefundStatus.completed).toList();
        break;
      case 'Action Needed':
        list = list
            .where((r) =>
                r.status == RefundStatus.awaitingConfirmation ||
                r.status == RefundStatus.bankProcessing)
            .toList();
        break;
      case 'Overdue':
        list = list.where((r) => r.isOverdue).toList();
        break;
      default:
        break;
    }

    return list;
  }

  List<({RefundCategory category, double amount, bool pending, String currency, int count})> get _categories {
    final byCategory = <RefundCategory, ({double total, bool hasPending, Map<String, int> currencies, int count})>{
      for (final c in RefundCategory.values)
        c: (total: 0, hasPending: false, currencies: {}, count: 0),
    };
    for (final r in _refunds) {
      final cat = r.category ?? RefundCategory.retail;
      final cur = byCategory[cat]!;
      final cmap = Map<String, int>.from(cur.currencies);
      cmap[r.currency] = (cmap[r.currency] ?? 0) + 1;
      byCategory[cat] = (
        total: cur.total + (r.status != RefundStatus.completed ? r.amount : 0),
        hasPending: cur.hasPending || r.status != RefundStatus.completed,
        currencies: cmap,
        count: cur.count + 1,
      );
    }
    return byCategory.entries.map((e) {
      final cmap = e.value.currencies;
      final dominant = cmap.isEmpty
          ? '₹'
          : cmap.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
      return (
        category: e.key,
        amount: e.value.total,
        pending: e.value.hasPending,
        currency: dominant,
        count: e.value.count,
      );
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadRefunds();
  }

  Future<void> _loadRefunds({bool showLoader = true}) async {
    if (showLoader) setState(() => _loading = true);
    // One-time migration: clear old seeded demo data (ids '1' and '2')
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('_seeded_data_cleared') ?? false)) {
      var list = await _storage.loadRefunds();
      final cleaned = list.where((r) => r.id != '1' && r.id != '2').toList();
      await _storage.saveRefunds(cleaned);
      await prefs.setBool('_seeded_data_cleared', true);
    }
    final list = await _storage.loadRefunds();
    if (!mounted) return;
    setState(() {
      _refunds = list;
      _loading = false;
    });
  }

  Future<void> _quickSync() async {
    setState(() => _syncing = true);
    final prefs = await SharedPreferences.getInstance();
    var newCount = 0;

    // ── SMS scan (all messages) ──────────────────────────────────────────
    final smsEnabled = prefs.getBool('sms_enabled') ?? false;
    if (smsEnabled && Platform.isAndroid) {
      final fromSms = await _smsScanner.scanInbox();
      newCount += fromSms.length;
      if (fromSms.isNotEmpty) await _storage.mergeAndSave(fromSms);
    }

    // ── Email scan (last 30 days) ────────────────────────────────────────
    final emailEnabled = await _emailScanner.isEnabled;
    if (emailEnabled && _auth.currentUser != null) {
      final fromEmail = await _emailScanner.scanInbox();
      newCount += fromEmail.length;
      if (fromEmail.isNotEmpty) await _storage.mergeAndSave(fromEmail);
    }

    final merged = await _storage.loadRefunds();
    if (!mounted) return;
    setState(() {
      _refunds = merged;
      _syncing = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          newCount > 0
              ? 'Found $newCount refund(s). All data saved locally.'
              : 'No new refunds found this time.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tablet = context.isTablet;
    return Scaffold(
      key: _scaffoldKey,
      // Drawer only shown on phone (tablet uses permanent NavigationRail)
      drawer: tablet ? null : const AppDrawer(currentRoute: '/dashboard'),
      body: SafeArea(
        child: Row(
          children: [
            // ── Tablet: permanent left navigation rail ──────────────────
            if (tablet) _buildNavRail(context),
            if (tablet)
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
              ),

            // ── Main scroll area ────────────────────────────────────────
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Pin FAB to bottom-right on first layout
                  _fabOffset ??= Offset(
                    constraints.maxWidth - 72,
                    constraints.maxHeight - 80,
                  );
                  return Stack(
                    children: [
                      CustomScrollView(
                        slivers: [
                          SliverToBoxAdapter(child: _buildAppBar(context, tablet)),
                          SliverToBoxAdapter(child: _buildHeadline(context)),
                          SliverToBoxAdapter(child: _buildStatsRow(context)),
                          SliverToBoxAdapter(
                              child: _buildSectionHeader(context, 'Refund Categories', 'View all')),
                          SliverToBoxAdapter(child: _buildCategoriesGrid(context, constraints.maxWidth)),
                          SliverToBoxAdapter(
                              child: _buildSectionHeader(context, 'Recent Activity', '')),
                          if (_hasActiveFilter)
                            SliverToBoxAdapter(child: _buildClearFilterBar(context)),
                          SliverPersistentHeader(
                            pinned: true,
                            delegate: _FilterChipsDelegate(
                              child: _buildFilterChips(context),
                            ),
                          ),
                          if (_loading)
                            const SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Center(
                                    child: CircularProgressIndicator(color: AppColors.primary)),
                              ),
                            )
                          else if (_filteredRefunds.isEmpty)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 48),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.receipt_long_outlined,
                                      size: 64,
                                      color: AppColors.textMuted.withValues(alpha: 0.4),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _refunds.isEmpty
                                          ? 'No refunds tracked yet'
                                          : 'No results',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(color: AppColors.textMuted),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _refunds.isEmpty
                                          ? 'Tap + to add one manually or use sync to scan SMS'
                                          : 'Try a different filter',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                              color: AppColors.textMuted
                                                  .withValues(alpha: 0.7)),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            _filteredRefunds.length >= 4 && context.isTablet
                                ? SliverPadding(
                                    padding: EdgeInsets.symmetric(horizontal: context.hPad),
                                    sliver: SliverGrid(
                                      gridDelegate:
                                          const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        childAspectRatio: 3.5,
                                        mainAxisSpacing: 0,
                                        crossAxisSpacing: 12,
                                      ),
                                      delegate: SliverChildBuilderDelegate(
                                        (_, i) {
                                          final item = _filteredRefunds[i];
                                          return _ActivityTile(
                                            item: item,
                                            onTap: () async {
                                              await context.push('/refund/${item.id}');
                                              if (mounted) _loadRefunds(showLoader: false);
                                            },
                                          );
                                        },
                                        childCount: _filteredRefunds.length,
                                      ),
                                    ),
                                  )
                                : SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                      (_, i) {
                                        final item = _filteredRefunds[i];
                                        return _ActivityTile(
                                          item: item,
                                          onTap: () async {
                                            await context.push('/refund/${item.id}');
                                            if (mounted) _loadRefunds(showLoader: false);
                                          },
                                        );
                                      },
                                      childCount: _filteredRefunds.length,
                                    ),
                                  ),
                          const SliverToBoxAdapter(child: SizedBox(height: 100)),
                        ],
                      ),

                      // ── Draggable sync FAB ────────────────────────────
                      Positioned(
                        left: _fabOffset!.dx,
                        top: _fabOffset!.dy,
                        child: GestureDetector(
                          onPanUpdate: (details) {
                            setState(() {
                              _fabOffset = Offset(
                                (_fabOffset!.dx + details.delta.dx)
                                    .clamp(0.0, constraints.maxWidth - 56),
                                (_fabOffset!.dy + details.delta.dy)
                                    .clamp(0.0, constraints.maxHeight - 56),
                              );
                            });
                          },
                          child: _SyncFab(
                            onPressed: _syncing ? null : _quickSync,
                            syncing: _syncing,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      // Bottom nav only shown on phone
      bottomNavigationBar: tablet ? null : _buildBottomBar(context),
    );
  }

  Widget _buildNavRail(BuildContext context) {
    final overdueCount = _refunds.where((r) => r.isOverdue).length;
    return NavigationRail(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      selectedIndex: 0,
      extended: context.isExpanded,
      labelType: context.isExpanded ? NavigationRailLabelType.none : NavigationRailLabelType.selected,
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            const AppLogo(size: 28, borderRadius: 9, showGlow: false),
            const SizedBox(height: 4),
            if (context.isExpanded)
              Text(
                'Refundoo',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
              ),
          ],
        ),
      ),
      trailing: Expanded(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 26),
                  tooltip: 'Add refund',
                  onPressed: () => context.push('/add-refund'),
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined, size: 24),
                  tooltip: 'Settings',
                  onPressed: () => context.push('/profile'),
                ),
              ],
            ),
          ),
        ),
      ),
      destinations: [
        const NavigationRailDestination(
          icon: Icon(Icons.grid_view_outlined),
          selectedIcon: Icon(Icons.grid_view_rounded),
          label: Text('Home'),
        ),
        const NavigationRailDestination(
          icon: Icon(Icons.receipt_long_outlined),
          selectedIcon: Icon(Icons.receipt_long_rounded),
          label: Text('Refunds'),
        ),
        NavigationRailDestination(
          icon: overdueCount > 0
              ? Badge(
                  label: Text('$overdueCount'),
                  child: const Icon(Icons.bar_chart_outlined),
                )
              : const Icon(Icons.bar_chart_outlined),
          selectedIcon: const Icon(Icons.bar_chart_rounded),
          label: const Text('Reports'),
        ),
      ],
      onDestinationSelected: (i) {
        if (i == 2) context.push('/reports');
      },
    );
  }

  Widget _buildAppBar(BuildContext context, bool tablet) {
    return Padding(
      padding: EdgeInsets.fromLTRB(tablet ? 24 : 16, 16, 16, 8),
      child: Row(
        children: [
          // Hamburger — phone only (tablet uses persistent NavigationRail)
          if (!tablet)
            IconButton(
              icon: const Icon(Icons.menu_rounded, size: 28),
              tooltip: 'Menu',
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
          // App logo + name (centred on phone, left-aligned on tablet)
          Expanded(
            child: Row(
              mainAxisAlignment:
                  tablet ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                if (!tablet) ...[
                  const AppLogo(size: 26, borderRadius: 8, showGlow: false),
                  const SizedBox(width: 8),
                  Text(
                    'Refundoo',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                  ),
                ] else
                  Text(
                    'Dashboard',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                  ),
              ],
            ),
          ),
          // Add refund — phone only (tablet shows it in rail trailing)
          if (!tablet)
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 28),
              tooltip: 'Add refund',
              onPressed: () => context.push('/add-refund'),
            ),
        ],
      ),
    );
  }

  Widget _buildHeadline(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.hPad, vertical: 24),
      child: Column(
        children: [
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontSize: 36,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
              children: _pendingAmount > 0
                  ? [
                      const TextSpan(text: 'You have '),
                      TextSpan(
                        text: '$_pendingCurrency${_pendingAmount.toStringAsFixed(0)}',
                        style: const TextStyle(color: AppColors.primary),
                      ),
                      const TextSpan(text: ' on the way.'),
                    ]
                  : [
                      const TextSpan(text: 'No pending\nrefunds '),
                      TextSpan(
                        text: '🎉',
                        style: TextStyle(
                          fontSize: 32,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _pendingAmount > 0
                ? 'Estimated arrival in 3-5 business days'
                : 'Sync to scan for new refunds',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.hPad),
      child: Row(
        children: [
              Expanded(
            child: _BentoCard(
              icon: Icons.pending_actions_outlined,
              iconColor: AppColors.primary,
              label: 'Pending',
              value: '$_pendingCurrency${_pendingAmount.toStringAsFixed(2)}',
              primary: true,
              onTap: () => setState(() {
                _filterKind = _DashboardFilterKind.pending;
                _filterCategory = null;
              }),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _BentoCard(
              icon: Icons.schedule_outlined,
              label: 'Avg Wait Time',
              value: _waitLabel,
              onTap: () => setState(() {
                _filterKind = _DashboardFilterKind.waitTime;
                _filterCategory = null;
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, String action) {
    return Padding(
      padding: EdgeInsets.fromLTRB(context.hPad, 24, context.hPad, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          if (action.isNotEmpty)
            GestureDetector(
              onTap: () {},
              child: Text(
                action,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoriesGrid(BuildContext context, double contentWidth) {
    final cats = _categories;
    double amountFor(RefundCategory c) =>
        cats.where((x) => x.category == c).firstOrNull?.amount ?? 0;
    bool pendingFor(RefundCategory c) =>
        cats.where((x) => x.category == c).firstOrNull?.pending ?? false;
    String currencyFor(RefundCategory c) =>
        cats.where((x) => x.category == c).firstOrNull?.currency ?? '₹';
    int countFor(RefundCategory c) =>
        cats.where((x) => x.category == c).firstOrNull?.count ?? 0;
    void onCategoryTap(RefundCategory c) => setState(() {
          _filterKind = _DashboardFilterKind.category;
          _filterCategory = c;
        });

    final categories = [
      RefundCategory.travel,
      RefundCategory.retail,
      RefundCategory.services,
      RefundCategory.foodDining,
      RefundCategory.electronics,
      RefundCategory.entertainment,
    ];

    // Adaptive column count based on available width
    final cols = contentWidth >= kExpandedBreak ? 4
               : contentWidth >= kCompactBreak  ? 3
               : 2;
    final hPad = context.hPad;

    final rows = <Widget>[];
    for (var i = 0; i < categories.length; i += cols) {
      final rowCats = categories.skip(i).take(cols).toList();
      // Pad row to full cols so widths are even
      while (rowCats.length < cols) rowCats.add(rowCats.last); // placeholder fill handled below

      rows.add(
        Row(
          children: [
            for (var j = 0; j < cols; j++) ...[
              if (j > 0) const SizedBox(width: 12),
              Expanded(
                child: j < rowCats.length && i + j < categories.length
                    ? _CategoryBento(
                        category: rowCats[j],
                        amount: amountFor(rowCats[j]),
                        count: countFor(rowCats[j]),
                        pending: pendingFor(rowCats[j]),
                        currencySymbol: currencyFor(rowCats[j]),
                        onTap: () => onCategoryTap(rowCats[j]),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      );
      if (i + cols < categories.length) rows.add(const SizedBox(height: 12));
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hPad),
      child: Column(children: rows),
    );
  }

  Widget _buildClearFilterBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Row(
        children: [
          Text(
            _filterLabel,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _clearFilters,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.close, size: 18, color: Theme.of(context).colorScheme.error),
                    const SizedBox(width: 4),
                    Text(
                      'Clear filters',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.error,
                      ),
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

  String get _filterLabel {
    if (_filterKind == _DashboardFilterKind.pending) return 'Showing pending only.';
    if (_filterKind == _DashboardFilterKind.waitTime) return 'Showing items in wait.';
    if (_filterKind == _DashboardFilterKind.category && _filterCategory != null) {
      return 'Showing ${_filterCategory!.label} only.';
    }
    if (_chipFilter != 'All') return 'Showing $_chipFilter only.';
    return 'Filter active.';
  }

  Widget _buildFilterChips(BuildContext context) {
    final overdueCount = _refunds.where((r) => r.isOverdue).length;
    final chips = <({String label, Color? color, Color? bg})>[
      (label: 'All', color: null, bg: null),
      (label: 'Processing', color: const Color(0xFFD97706), bg: const Color(0xFFFEF3C7)),
      (label: 'Completed', color: const Color(0xFF059669), bg: const Color(0xFFD1FAE5)),
      (label: 'Action Needed', color: const Color(0xFFDC2626), bg: const Color(0xFFFEE2E2)),
      (label: 'Overdue', color: const Color(0xFFB91C1C), bg: const Color(0xFFFEE2E2)),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: chips.map((c) {
          final selected = c.label == _chipFilter;
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final isOverdueChip = c.label == 'Overdue';
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _chipFilter = c.label),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? (c.bg ?? AppColors.primary.withValues(alpha: 0.15))
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : AppColors.surfaceLight),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected
                        ? (c.color ?? AppColors.primary).withValues(alpha: 0.4)
                        : (isOverdueChip && overdueCount > 0
                            ? const Color(0xFFB91C1C).withValues(alpha: 0.35)
                            : Colors.transparent),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (c.color != null && selected) ...[
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: c.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      c.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? (c.color ?? AppColors.primary)
                            : (isOverdueChip && overdueCount > 0
                                ? const Color(0xFFB91C1C)
                                : AppColors.textMuted),
                      ),
                    ),
                    // Count badge on Overdue chip
                    if (isOverdueChip && overdueCount > 0) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFB91C1C),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$overdueCount',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return BottomAppBar(
      height: 72,
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            icon: Icons.grid_view_outlined,
            label: 'Home',
            active: true,
            onTap: () {},
          ),
          _NavItem(
            icon: Icons.receipt_long_outlined,
            label: 'Refunds',
            onTap: () {},
          ),
          _NavItem(
            icon: Icons.bar_chart_rounded,
            label: 'Reports',
            onTap: () => context.push('/reports'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sticky header delegate for the filter chips row
// ─────────────────────────────────────────────────────────────────────────────

class _FilterChipsDelegate extends SliverPersistentHeaderDelegate {
  const _FilterChipsDelegate({required this.child});

  final Widget child;

  // Chip height (≈32px) + 12px top + 12px bottom
  static const double _height = 56.0;

  @override
  double get minExtent => _height;
  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      elevation: shrinkOffset > 0 ? 1 : 0,
      shadowColor: Colors.black12,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: child,
      ),
    );
  }

  @override
  bool shouldRebuild(_FilterChipsDelegate old) => child != old.child;
}

// ─────────────────────────────────────────────────────────────────────────────

class _BentoCard extends StatelessWidget {
  const _BentoCard({
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
    this.primary = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;
  final bool primary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 28, color: iconColor ?? AppColors.textMuted),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: primary
                ? AppColors.primary.withValues(alpha: 0.1)
                : (Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.05)
                    : AppColors.surfaceLight),
            borderRadius: BorderRadius.circular(16),
            border: primary ? Border.all(color: AppColors.primary.withValues(alpha: 0.2)) : null,
            boxShadow: [
              BoxShadow(
                color: const Color(0x0D000000),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _CategoryBento extends StatelessWidget {
  const _CategoryBento({
    required this.category,
    required this.amount,
    required this.count,
    required this.pending,
    this.currencySymbol = '₹',
    this.onTap,
  });

  final RefundCategory category;
  final double amount;
  final int count;
  final bool pending;
  final String currencySymbol;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final gradient = _categoryGradients[category] ?? _genericGradient;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: gradient,
            boxShadow: [
              BoxShadow(
                color: const Color(0x1A000000),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: _CategoryPatternPainter()),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(
                          _iconForCategory(category),
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              category.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (count > 0)
                            Container(
                              margin: const EdgeInsets.only(left: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '$count',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        amount > 0
                            ? (pending
                                ? '$currencySymbol${amount.toStringAsFixed(2)} pending'
                                : '$currencySymbol${amount.toStringAsFixed(2)}')
                            : 'No refunds',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
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
    );
  }

  IconData _iconForCategory(RefundCategory c) {
    switch (c) {
      case RefundCategory.travel:
        return Icons.flight_takeoff;
      case RefundCategory.retail:
        return Icons.shopping_bag_outlined;
      case RefundCategory.services:
        return Icons.account_tree_outlined;
      case RefundCategory.foodDining:
        return Icons.restaurant_outlined;
      case RefundCategory.electronics:
        return Icons.devices_outlined;
      case RefundCategory.entertainment:
        return Icons.movie_outlined;
    }
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.item, required this.onTap});

  final RefundItem item;
  final VoidCallback onTap;

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    if (d == today) return 'Today';
    if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('d MMM yyyy').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final date = _formatDate(item.detectedAt ?? item.refundIssuedAt);
    final hasOrderId = item.orderId?.isNotEmpty == true;
    final metaText = [
      if (date.isNotEmpty) date,
      if (hasOrderId) '#${item.orderId}',
    ].join('  ·  ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Material(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: isDark ? 0 : 1,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        child: InkWell(
          onTap: onTap,
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Category icon
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: item.isOverdue
                          ? const Color(0xFFB91C1C).withValues(alpha: 0.1)
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : AppColors.primary.withValues(alpha: 0.1)),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _activityIconFor(item.category),
                      color: item.isOverdue
                          ? const Color(0xFFB91C1C)
                          : AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Middle: merchant + meta
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.merchantName,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (metaText.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            metaText,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                              letterSpacing: 0.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (item.isOverdue) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.warning_amber_rounded,
                                  size: 12, color: Color(0xFFB91C1C)),
                              const SizedBox(width: 3),
                              Text(
                                '${item.overdueDays} day${item.overdueDays == 1 ? '' : 's'} overdue',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFB91C1C),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Right: amount + status badge (+ M tag if manually completed)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        item.formattedAmount,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (item.manuallyCompleted) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppColors.success.withValues(alpha: 0.4),
                                ),
                              ),
                              child: const Text(
                                'M',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.success,
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                          ],
                          _StatusBadge(item: item),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.item});
  final RefundItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: item.statusBgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: item.statusColor.withValues(alpha: 0.45),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: item.statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            item.statusBadgeLabel,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: item.statusColor,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.onTap,
    this.label = '',
    this.active = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : AppColors.textMuted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 26, color: color),
            if (label.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SyncFab extends StatelessWidget {
  const _SyncFab({required this.onPressed, this.syncing = false});

  final VoidCallback? onPressed;
  final bool syncing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: syncing
          ? AppColors.primary.withValues(alpha: 0.75)
          : AppColors.primary,
      shape: const CircleBorder(),
      elevation: 6,
      shadowColor: AppColors.primary.withValues(alpha: 0.45),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 52,
          height: 52,
          child: Center(
            child: syncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white),
                  )
                : const Icon(Icons.sync, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

/// Draws subtle decorative circles in the top-right of category cards.
class _CategoryPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x18FFFFFF)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width + 10, -10), 60, paint);
    canvas.drawCircle(Offset(size.width - 20, size.height * 0.3), 30, paint);
  }

  @override
  bool shouldRepaint(_CategoryPatternPainter oldDelegate) => false;
}
