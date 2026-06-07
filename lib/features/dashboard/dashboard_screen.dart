import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/category_theme.dart';
import '../../core/theme/responsive.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/app_drawer.dart';
import '../../models/refund_item.dart';
import '../../services/refund_storage_service.dart';
import '../../services/sms_scanner_service.dart';
import '../../services/email_scanner_service.dart';
import '../../services/auth_service.dart';
import '../../core/widgets/banner_ad_widget.dart';
import '../../services/ad_service.dart';
import '../../services/notification_service.dart';
import '../../services/widget_service.dart';
import '../../services/swipe_settings_service.dart';

// Icon + gradient helpers are in lib/core/theme/category_theme.dart

String _fmtDate(DateTime d) {
  const months = ['Jan','Feb','Mar','Apr','May','Jun',
                  'Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${months[d.month - 1]} ${d.day}';
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

/// Active dashboard filter: from Pending card, Wait Time card, or a category bento.
enum _DashboardFilterKind { all, pending, waitTime, category }

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  final RefundStorageService _storage = RefundStorageService();
  final SmsScannerService _smsScanner = SmsScannerService();
  final EmailScannerService _emailScanner = EmailScannerService();
  final AuthService _auth = AuthService();
  final _scaffoldKey       = GlobalKey<ScaffoldState>();
  final _recentActivityKey = GlobalKey();
  late final ScrollController _scrollCtrl;

  // Entrance animation — drives the staggered section/list fade+slide.
  late final AnimationController _entranceCtrl;
  // Separate controller for the headline amount count-up.
  late final AnimationController _countCtrl;
  double _countFrom = 0;
  double _countTo   = 0;

  List<RefundItem> _refunds = [];
  SwipeAction _swipeLeft  = SwipeAction.delete;
  SwipeAction _swipeRight = SwipeAction.archive;
  // Pre-computed views — updated only when source data or filters change,
  // not on every animation/setState call.
  List<RefundItem> _displayRefunds = [];
  List<({RefundCategory category, double amount, bool pending, String currency, int count})>
      _displayCategories = [];

  bool _loading = true;
  bool _syncing = false;
  _DashboardFilterKind _filterKind = _DashboardFilterKind.all;
  RefundCategory? _filterCategory;
  String _chipFilter = 'Processing'; // default to Processing tab on launch
  Offset? _fabOffset; // null until first layout; then user can drag it
  bool _searching = false;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // Search debounce — avoids filtering on every keystroke
  Timer? _searchDebounce;

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
      _chipFilter.isNotEmpty;

  void _clearFilters() {
    setState(() {
      _filterKind = _DashboardFilterKind.all;
      _filterCategory = null;
      _chipFilter = '';
      _rebuildDerived();
    });
  }

  /// Recomputes [_displayRefunds] and [_displayCategories] from current state.
  /// Call whenever _refunds, filter fields, or _searchQuery changes.
  void _rebuildDerived() {
    // ── filtered list ────────────────────────────────────────────────────────
    // Always exclude archived items from all dashboard views.
    List<RefundItem> list = _refunds.where((r) => !r.archived).toList();

    switch (_filterKind) {
      case _DashboardFilterKind.pending:
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

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((r) =>
        r.merchantName.toLowerCase().contains(q) ||
        (r.orderId?.toLowerCase().contains(q) ?? false) ||
        (r.description?.toLowerCase().contains(q) ?? false)
      ).toList();
    }

    _displayRefunds = list;

    // ── categories ───────────────────────────────────────────────────────────
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
    _displayCategories = byCategory.entries.map((e) {
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
    _scrollCtrl = ScrollController();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _countCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _loadRefunds();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _entranceCtrl.dispose();
    _countCtrl.dispose();
    _searchCtrl.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Widget _buildDismissible(BuildContext context, RefundItem item, int index) {
    final leftAction  = _swipeLeft;
    final rightAction = _swipeRight;

    Future<bool?> confirm(SwipeAction action) => showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(action == SwipeAction.delete ? 'Delete refund?' : 'Archive refund?'),
        content: Text(
          action == SwipeAction.delete
              ? 'Remove "${item.merchantName}" (${item.formattedAmount})?\nThis cannot be undone.'
              : 'Move "${item.merchantName}" to Archive?\nYou can still view it there.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          FilledButton(
            style: action == SwipeAction.delete
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error)
                : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    Widget _bg(SwipeAction action, Alignment align, EdgeInsets pad) {
      final isDelete = action == SwipeAction.delete;
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: BoxDecoration(
          color: isDelete ? const Color(0xFFDC2626) : const Color(0xFF0D9488),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: align,
        padding: pad,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isDelete ? Icons.delete_outline : Icons.archive_outlined,
              color: Colors.white, size: 22,
            ),
            const SizedBox(height: 4),
            Text(action.label,
                style: const TextStyle(color: Colors.white, fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      );
    }

    return Dismissible(
      key: Key('refund_${item.id}'),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) {
        final action = direction == DismissDirection.startToEnd
            ? rightAction : leftAction;
        return confirm(action);
      },
      onDismissed: (direction) {
        final action = direction == DismissDirection.startToEnd
            ? rightAction : leftAction;
        if (action == SwipeAction.delete) {
          _deleteRefund(item);
        } else {
          _archiveRefund(item);
        }
      },
      background:          _bg(rightAction, Alignment.centerLeft,  const EdgeInsets.only(left: 20)),
      secondaryBackground: _bg(leftAction,  Alignment.centerRight, const EdgeInsets.only(right: 20)),
      child: _AnimatedListItem(
        index: index,
        controller: _entranceCtrl,
        child: _ActivityTile(
          item: item,
          onTap: () async {
            await context.push('/refund/${item.id}');
            if (mounted) _loadRefunds(showLoader: false);
          },
        ),
      ),
    );
  }

  Future<void> _deleteRefund(RefundItem item) async {
    // Tombstone first so this ID is never re-imported by SMS/email scans.
    await _storage.dismissRefund(item.id);
    final all = await _storage.loadRefunds();
    final updated = all.where((r) => r.id != item.id).toList();
    await _storage.saveRefunds(updated);
    if (!mounted) return;
    setState(() {
      _refunds = updated;
      _rebuildDerived();
      _entranceCtrl.forward(from: 0);
    });
  }

  Future<void> _archiveRefund(RefundItem item) async {
    await _storage.archiveRefund(item.id);
    final all = await _storage.loadRefunds();
    if (!mounted) return;
    setState(() {
      _refunds = all;
      _rebuildDerived();
      _entranceCtrl.forward(from: 0);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Moved to Archive'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'View',
          onPressed: () => context.push('/archive'),
        ),
      ),
    );
  }

  void _scrollToRecentActivity() {
    final ctx = _recentActivityKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.0,          // top of the viewport
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
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
    final list = await _storage.autoArchiveCompleted(); // auto-archives completed items ≥ 1 day old
    final swipe = await SwipeSettingsService.load();
    if (!mounted) return;
    final newAmount = list
        .where((r) => r.status != RefundStatus.completed && !r.archived)
        .fold(0.0, (sum, r) => sum + r.amount);
    setState(() {
      _countFrom = showLoader ? 0 : _countTo;
      _countTo   = newAmount;
      _refunds   = list;
      _loading   = false;
      _swipeLeft  = swipe.left;
      _swipeRight = swipe.right;
      _rebuildDerived();
    });
    _entranceCtrl.forward(from: 0);
    _countCtrl.forward(from: 0);
    unawaited(NotificationService.scheduleOverdueReminder(_refunds));
    unawaited(WidgetService.update(_refunds));
    // Show the launch interstitial once per session after first data load.
    AdService.instance.showSessionInterstitial();
  }

  Future<void> _quickSync() async {
    if (_syncing) return; // guard against rapid double-tap
    setState(() => _syncing = true);
    final prefs = await SharedPreferences.getInstance();
    var newCount = 0;

    // ── SMS scan (all messages) ──────────────────────────────────────────
    // Treat "never configured" the same as "enabled" so a fresh install /
    // reinstall (which wipes SharedPreferences) still works on first sync.
    final smsExplicitlyDisabled =
        prefs.containsKey('sms_enabled') && !(prefs.getBool('sms_enabled')!);
    if (!smsExplicitlyDisabled && Platform.isAndroid) {
      final fromSms = await _smsScanner.scanInbox(); // requests permission internally
      newCount += fromSms.length;
      if (fromSms.isNotEmpty) await _storage.mergeAndSave(fromSms);
      // Persist the flag so the settings screen reflects the granted state
      if (await _smsScanner.hasPermission) {
        await prefs.setBool('sms_enabled', true);
      }
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
      _rebuildDerived();
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
                  return Column(
                    children: [
                      Expanded(
                        child: Stack(
                    children: [
                      CustomScrollView(
                        controller: _scrollCtrl,
                        slivers: [
                          SliverToBoxAdapter(child: _buildAppBar(context, tablet)),
                          SliverToBoxAdapter(child: _buildHeadline(context)),
                          SliverToBoxAdapter(child: _buildStatsRow(context)),
                          SliverToBoxAdapter(
                              child: _buildSectionHeader(context, 'Refund Categories', 'View all')),
                          SliverToBoxAdapter(child: _buildCategoriesTreemap(context, constraints.maxWidth)),
                          SliverToBoxAdapter(
                              child: KeyedSubtree(
                                key: _recentActivityKey,
                                child: _buildSectionHeader(context, 'Recent Activity', ''),
                              )),
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
                          else if (_displayRefunds.isEmpty)
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
                            _displayRefunds.length >= 4 && context.isTablet
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
                                          final item = _displayRefunds[i];
                                          return _buildDismissible(context, item, i);
                                        },
                                        childCount: _displayRefunds.length,
                                      ),
                                    ),
                                  )
                                : SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                      (_, i) {
                                        final item = _displayRefunds[i];
                                        return _buildDismissible(context, item, i);

                                      },
                                      childCount: _displayRefunds.length,
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
                        ),
                      ),
                      // ── Banner ad (bottom of screen) ─────────────────────
                      const BannerAdWidget(),
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
          if (!tablet && !_searching)
            IconButton(
              icon: const Icon(Icons.menu_rounded, size: 28),
              tooltip: 'Menu',
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
          // Title or search field
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _searching
                  ? TextField(
                      key: const ValueKey('search_field'),
                      controller: _searchCtrl,
                      autofocus: true,
                      onChanged: (v) {
                        _searchDebounce?.cancel();
                        _searchDebounce = Timer(
                          const Duration(milliseconds: 250),
                          () => setState(() {
                            _searchQuery = v;
                            _rebuildDerived();
                          }),
                        );
                      },
                      decoration: InputDecoration(
                        hintText: 'Search merchant or order ID…',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                    )
                  : Row(
                      key: const ValueKey('title_row'),
                      mainAxisAlignment: tablet
                          ? MainAxisAlignment.start
                          : MainAxisAlignment.center,
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
          ),
          // Search / close toggle
          IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _searching
                  ? const Icon(Icons.close, key: ValueKey('close'), size: 26)
                  : const Icon(Icons.search_outlined, key: ValueKey('search'), size: 26),
            ),
            tooltip: _searching ? 'Close search' : 'Search',
            onPressed: () {
              setState(() {
                _searching = !_searching;
                if (!_searching) {
                  _searchDebounce?.cancel();
                  _searchCtrl.clear();
                  _searchQuery = '';
                  _rebuildDerived();
                }
              });
            },
          ),
          if (!tablet && !_searching)
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
    final slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic),
    ));
    final fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
      ),
    );

    return FadeTransition(
      opacity: fadeAnim,
      child: SlideTransition(
        position: slideAnim,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: context.hPad, vertical: 24),
          child: Column(
            children: [
              // Count-up animation on the amount
              AnimatedBuilder(
                animation: _countCtrl,
                builder: (context, _) {
                  final displayed = Tween<double>(begin: _countFrom, end: _countTo)
                      .animate(CurvedAnimation(
                        parent: _countCtrl,
                        curve: Curves.easeOut,
                      ))
                      .value;
                  return RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            fontSize: 36,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                      children: _countTo > 0
                          ? [
                              const TextSpan(text: 'You have '),
                              TextSpan(
                                text: '$_pendingCurrency${displayed.toStringAsFixed(0)}',
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
                  );
                },
              ),
              const SizedBox(height: 8),
              Text(
                _countTo > 0
                    ? 'Estimated arrival in 3-5 business days'
                    : 'Sync to scan for new refunds',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context) {
    final slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.35),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.1, 0.6, curve: Curves.easeOutCubic),
    ));
    final fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.1, 0.5, curve: Curves.easeOut),
      ),
    );

    return FadeTransition(
      opacity: fadeAnim,
      child: SlideTransition(
        position: slideAnim,
        child: Padding(
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
                    _rebuildDerived();
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
                    _rebuildDerived();
                  }),
                ),
              ),
            ],
          ),
        ),
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

  /// Squarified treemap: all 6 categories fill a square, area ∝ pending amount.
  /// Zero-amount categories get a minimum 10 % of the largest amount so they
  /// are still legible.
  Widget _buildCategoriesTreemap(BuildContext context, double contentWidth) {
    final cats = _displayCategories;
    double amountFor(RefundCategory c) =>
        cats.where((x) => x.category == c).firstOrNull?.amount ?? 0;
    bool pendingFor(RefundCategory c) =>
        cats.where((x) => x.category == c).firstOrNull?.pending ?? false;
    String currencyFor(RefundCategory c) =>
        cats.where((x) => x.category == c).firstOrNull?.currency ?? '₹';
    int countFor(RefundCategory c) =>
        cats.where((x) => x.category == c).firstOrNull?.count ?? 0;

    const categories = [
      RefundCategory.travel,
      RefundCategory.retail,
      RefundCategory.services,
      RefundCategory.foodDining,
      RefundCategory.electronics,
      RefundCategory.entertainment,
    ];

    // Log compression: math.log(1+amount)+1 for non-zero categories,
    // 1.0 for zero-item categories.
    // This guarantees every category with actual refunds is always larger
    // than an empty category, while dampening extreme skews so even a
    // ₹1 category is comfortably tappable.
    final items = categories.asMap().entries.map((e) {
      final amt = amountFor(e.value);
      final weight = amt > 0 ? (math.log(1 + amt) + 1.0) : 1.0;
      return _TMapItem(
        category:       e.value,
        value:          weight,
        amount:         amt,
        count:          countFor(e.value),
        pending:        pendingFor(e.value),
        currencySymbol: currencyFor(e.value),
      );
    }).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final hPad     = context.hPad;
    final side     = contentWidth - 2 * hPad;
    final totalVal = items.fold(0.0, (s, e) => s + e.value);
    _squarify(items, Rect.fromLTWH(0, 0, side, side), totalVal);

    const gap = 5.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hPad),
      child: SizedBox(
        width:  side,
        height: side,
        child: Stack(
          children: items.asMap().entries.map((entry) {
            final idx  = entry.key;
            final item = entry.value;
            final r = Rect.fromLTRB(
              item.rect.left   + gap / 2,
              item.rect.top    + gap / 2,
              item.rect.right  - gap / 2,
              item.rect.bottom - gap / 2,
            );
            return Positioned(
              left:   r.left,
              top:    r.top,
              width:  r.width,
              height: r.height,
              child: _CategoryBento(
                category:       item.category,
                amount:         item.amount,
                count:          item.count,
                pending:        item.pending,
                currencySymbol: item.currencySymbol,
                index:          idx,
                onTap: () => context.push('/category/${item.category.name}'),
              ),
            );
          }).toList(),
        ),
      ),
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
    if (_chipFilter.isNotEmpty) return 'Showing $_chipFilter only.';
    return 'Filter active.';
  }

  Widget _buildFilterChips(BuildContext context) {
    final overdueCount = _refunds.where((r) => r.isOverdue).length;
    // No "All" chip — empty selection means show everything.
    // Tapping the active chip again deselects it (toggle).
    final chips = <({String label, Color color, Color bg})>[
      (label: 'Processing',   color: const Color(0xFFD97706), bg: const Color(0xFFFEF3C7)),
      (label: 'Completed',    color: const Color(0xFF059669), bg: const Color(0xFFD1FAE5)),
      (label: 'Action Needed',color: const Color(0xFFDC2626), bg: const Color(0xFFFEE2E2)),
      (label: 'Overdue',      color: const Color(0xFFB91C1C), bg: const Color(0xFFFEE2E2)),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: chips.map((c) {
          final selected      = c.label == _chipFilter;
          final isDark        = Theme.of(context).brightness == Brightness.dark;
          final isOverdueChip = c.label == 'Overdue';
          // Always show a faint border so chips look tappable
          final idleBorderColor = isOverdueChip && overdueCount > 0
              ? const Color(0xFFB91C1C).withValues(alpha: 0.30)
              : c.color.withValues(alpha: 0.18);

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              // Toggle: tap active chip to deselect; tap inactive chip to select
              onTap: () => setState(() {
                _chipFilter = selected ? '' : c.label;
                _rebuildDerived();
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: selected
                      ? c.bg
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : AppColors.surfaceLight),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected
                        ? c.color.withValues(alpha: 0.5)
                        : idleBorderColor,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Coloured dot — always shown (not just when selected)
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: selected
                            ? c.color
                            : c.color.withValues(alpha: 0.45),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      c.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                        color: selected
                            ? c.color
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
            onTap: _scrollToRecentActivity,
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

  // Chip height (≈34px) + 12px top + 12px bottom
  static const double _height = 58.0;

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

// Three large background icons give each card a "photo-like" illustrated feel.
// ── Treemap layout ────────────────────────────────────────────────────────────

class _TMapItem {
  _TMapItem({
    required this.category,
    required this.value,
    required this.amount,
    required this.count,
    required this.pending,
    required this.currencySymbol,
  });

  final RefundCategory category;
  final double value;          // layout weight (>= minValue)
  final double amount;         // raw display amount (may be 0)
  final int count;
  final bool pending;
  final String currencySymbol;
  Rect rect = Rect.zero;       // filled by _squarify
}

/// Squarified treemap: places [items] (sorted desc by value) into [bounds],
/// minimising worst cell aspect-ratio. Fills [_TMapItem.rect] in-place.
void _squarify(List<_TMapItem> items, Rect bounds, double remaining) {
  if (items.isEmpty) return;
  if (items.length == 1) { items[0].rect = bounds; return; }

  final w    = bounds.width;
  final h    = bounds.height;
  final wide = w >= h;

  var rowSum   = 0.0;
  var rowCount = 0;
  var prevWorst = double.infinity;

  for (var i = 0; i < items.length; i++) {
    final cand     = rowSum + items[i].value;
    final frac     = cand / remaining;
    final stripDim = (wide ? w : h) * frac;
    final crossDim = wide ? h : w;

    var worst = 0.0;
    for (var j = 0; j <= i; j++) {
      final itemFrac = items[j].value / cand;
      final itemDim  = crossDim * itemFrac;
      final r        = stripDim > itemDim ? stripDim / itemDim : itemDim / stripDim;
      if (r > worst) worst = r;
    }

    if (i == 0 || worst <= prevWorst) {
      rowSum    = cand;
      rowCount  = i + 1;
      prevWorst = worst;
    } else {
      break;
    }
  }

  // Place committed row.
  final frac     = rowSum / remaining;
  final stripDim = (wide ? w : h) * frac;
  final crossDim = wide ? h : w;

  var offset = 0.0;
  for (var i = 0; i < rowCount; i++) {
    final itemFrac = items[i].value / rowSum;
    final itemDim  = crossDim * itemFrac;
    items[i].rect  = wide
        ? Rect.fromLTWH(bounds.left, bounds.top + offset, stripDim, itemDim)
        : Rect.fromLTWH(bounds.left + offset, bounds.top, itemDim, stripDim);
    offset += itemDim;
  }

  // Recurse for the rest.
  final rest = items.skip(rowCount).toList();
  if (rest.isNotEmpty) {
    final nb = wide
        ? Rect.fromLTWH(bounds.left + stripDim, bounds.top, w - stripDim, h)
        : Rect.fromLTWH(bounds.left, bounds.top + stripDim, w, h - stripDim);
    _squarify(rest, nb, remaining - rowSum);
  }
}

// ── Decorative background icons per category ──────────────────────────────────

const _categoryBgIcons = <RefundCategory, List<IconData>>{
  RefundCategory.travel:        [Icons.flight_takeoff, Icons.luggage, Icons.travel_explore],
  RefundCategory.retail:        [Icons.local_mall, Icons.shopping_bag, Icons.storefront],
  RefundCategory.services:      [Icons.build_circle, Icons.support_agent, Icons.settings],
  RefundCategory.foodDining:    [Icons.restaurant, Icons.fastfood, Icons.local_cafe],
  RefundCategory.electronics:   [Icons.phone_android, Icons.laptop_mac, Icons.memory],
  RefundCategory.entertainment: [Icons.movie, Icons.music_note, Icons.sports_esports],
};

// iconForCategory is imported from category_theme.dart

class _CategoryBento extends StatefulWidget {
  const _CategoryBento({
    required this.category,
    required this.amount,
    required this.count,
    required this.pending,
    required this.index,
    this.currencySymbol = '₹',
    this.onTap,
  });

  final RefundCategory category;
  final double amount;
  final int count;
  final bool pending;
  final int index;
  final String currencySymbol;
  final VoidCallback? onTap;

  @override
  State<_CategoryBento> createState() => _CategoryBentoState();
}

class _CategoryBentoState extends State<_CategoryBento>
    with SingleTickerProviderStateMixin {
  // One-time entrance: fade + scale-up on first appearance.
  late final AnimationController _entranceCtrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _scaleAnim = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut),
    );
    // Stagger each card by 80 ms so they cascade in on load.
    Future.delayed(Duration(milliseconds: widget.index * 80), () {
      if (!mounted) return;
      _entranceCtrl.forward();
    });
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gradient = gradientForCategory(widget.category);
    final bgIcons  = _categoryBgIcons[widget.category] ?? [];

    return FadeTransition(
      opacity: _fadeAnim,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: GestureDetector(
          onTapDown:   (_) => setState(() => _pressed = true),
          onTapUp:     (_) { setState(() => _pressed = false); widget.onTap?.call(); },
          onTapCancel: ()  => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _pressed ? 0.94 : 1.0,
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOut,
            child: LayoutBuilder(builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;
              // Tighter breakpoints to prevent content overflow on small cells.
              final tiny  = w < 85  || h < 85;   // icon badge only
              final small = w < 130 || h < 130;  // icon + name, no amount/badge
              final pad      = tiny ? 7.0  : 11.0;
              final br       = tiny ? 10.0 : 14.0;
              final iconSz   = tiny ? 14.0 : 18.0;
              final badgePad = tiny ? 5.0  : 7.0;
              final bgIconSz = small ? 48.0 : 72.0;

              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(br),
                  gradient: gradient,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: _pressed ? 0.06 : 0.16),
                      blurRadius: _pressed ? 4 : 12,
                      offset: Offset(0, _pressed ? 1 : 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(br),
                  child: Stack(
                    children: [
                      // Decorative background icons (hidden in tiny cells).
                      if (!tiny && bgIcons.isNotEmpty)
                        Positioned(
                          right: -10, top: -10,
                          child: Icon(bgIcons[0], size: bgIconSz,
                              color: Colors.white.withValues(alpha: 0.13)),
                        ),
                      if (!tiny && bgIcons.length > 1)
                        Positioned(
                          left: -8, bottom: -6,
                          child: Icon(bgIcons[1], size: bgIconSz * 0.65,
                              color: Colors.white.withValues(alpha: 0.09)),
                        ),
                      // Bottom scrim for text legibility.
                      if (!tiny)
                        Positioned(
                          left: 0, right: 0, bottom: 0, height: 44,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.0),
                                  Colors.black.withValues(alpha: 0.26),
                                ],
                              ),
                            ),
                          ),
                        ),
                      // Foreground: OverflowBox lets the Column size to its
                      // content; ClipRRect above clips any excess silently.
                      Positioned.fill(
                        child: OverflowBox(
                          alignment: Alignment.topLeft,
                          maxHeight: double.infinity,
                          child: Padding(
                            padding: EdgeInsets.all(pad),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Icon badge — always shown.
                                Container(
                                  padding: EdgeInsets.all(badgePad),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.22),
                                    borderRadius:
                                        BorderRadius.circular(br * 0.65),
                                  ),
                                  child: Icon(iconForCategory(widget.category),
                                      color: Colors.white, size: iconSz),
                                ),
                                // Category name — hidden in tiny cells.
                                if (!tiny) ...[
                                  SizedBox(height: small ? 5 : 8),
                                  Text(
                                    widget.category.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: small ? 10 : 12,
                                      fontWeight: FontWeight.w700,
                                      height: 1.0,
                                    ),
                                  ),
                                  if (!small && widget.amount > 0) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      widget.pending
                                          ? '${widget.currencySymbol}'
                                            '${widget.amount.toStringAsFixed(0)} pending'
                                          : '${widget.currencySymbol}'
                                            '${widget.amount.toStringAsFixed(0)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                            alpha: 0.80),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        height: 1.0,
                                      ),
                                    ),
                                  ],
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// Staggered entrance wrapper used for each list item.
class _AnimatedListItem extends StatelessWidget {
  const _AnimatedListItem({
    required this.index,
    required this.controller,
    required this.child,
  });

  final int index;
  final AnimationController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final start = (0.3 + index * 0.06).clamp(0.0, 0.85);
    final end   = (start + 0.35).clamp(0.0, 1.0);

    final fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: controller, curve: Interval(start, end, curve: Curves.easeOut)),
    );
    final slide = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(
      CurvedAnimation(parent: controller, curve: Interval(start, end, curve: Curves.easeOutCubic)),
    );

    return FadeTransition(
      opacity: fade,
      child: SlideTransition(position: slide, child: child),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ActivityTile extends StatefulWidget {
  const _ActivityTile({required this.item, required this.onTap});

  final RefundItem item;
  final VoidCallback onTap;

  @override
  State<_ActivityTile> createState() => _ActivityTileState();
}

class _ActivityTileState extends State<_ActivityTile> {
  bool _pressed = false;

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
    final item   = widget.item;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final date = _formatDate(item.detectedAt ?? item.refundIssuedAt);
    final hasOrderId = item.orderId?.isNotEmpty == true;
    final metaText = [
      if (date.isNotEmpty) date,
      if (hasOrderId) '#${item.orderId}',
    ].join('  ·  ');

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
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
                      iconForCategory(item.category),
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
                        ] else if (item.status != RefundStatus.completed &&
                            item.expectedByDate != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.schedule_outlined,
                                  size: 11, color: AppColors.textMuted),
                              const SizedBox(width: 3),
                              Text(
                                'Expected by ${_fmtDate(item.expectedByDate!)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
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

class _SyncFab extends StatefulWidget {
  const _SyncFab({required this.onPressed, this.syncing = false});

  final VoidCallback? onPressed;
  final bool syncing;

  @override
  State<_SyncFab> createState() => _SyncFabState();
}

class _SyncFabState extends State<_SyncFab> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulsing ring — only shown when idle (not syncing)
          if (!widget.syncing)
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, __) {
                final t = _pulseCtrl.value;
                return CustomPaint(
                  size: const Size(72, 72),
                  painter: _PulseRingPainter(
                    progress: t,
                    color: AppColors.primary,
                  ),
                );
              },
            ),
          Material(
            color: widget.syncing
                ? AppColors.primary.withValues(alpha: 0.75)
                : AppColors.primary,
            shape: const CircleBorder(),
            elevation: 6,
            shadowColor: AppColors.primary.withValues(alpha: 0.45),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: widget.onPressed,
              child: SizedBox(
                width: 52,
                height: 52,
                child: Center(
                  child: widget.syncing
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
          ),
        ],
      ),
    );
  }
}

class _PulseRingPainter extends CustomPainter {
  const _PulseRingPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width * 0.36; // matches fab radius (52/2 / 72*36%)
    final maxRadius  = size.width * 0.50;
    final radius = baseRadius + (maxRadius - baseRadius) * progress;
    final opacity = (1.0 - progress) * 0.45;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(_PulseRingPainter old) => old.progress != progress;
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
