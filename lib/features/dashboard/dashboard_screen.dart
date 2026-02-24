import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../models/refund_item.dart';
import '../../services/refund_storage_service.dart';
import '../../services/sms_scanner_service.dart';
import '../profile/profile_screen.dart';

/// Background image URLs from stitch (Travel, Retail, Services) + generic images for extra categories.
const _categoryBackgroundImages = {
  RefundCategory.travel:
      'https://lh3.googleusercontent.com/aida-public/AB6AXuBK4Z_XzClXNaVWowlc_xjCH4vYF93mVlx8P-nPIILHILvj0zQuNuEkqzMFa0X32NAVJX5EIkbVeI-YYeuCazdm7VbMZJekcnEWQmtggv4EgWL-jfZB7F5aU-PAYnuDTQEWbXBbtvbftvx92iWrRAcdTdaXwhn_8e_JRXWJatg4p1bTgWLrBR7rMEt7C-3c7N1a4uBlS0pGTxbwmIHwb0CzSPAswjkcwj3Ve-MwAOI6riIGKW0irh1K_QPgewjw0YysxoTwvk_CjDy1',
  RefundCategory.retail:
      'https://lh3.googleusercontent.com/aida-public/AB6AXuAk3WOQ35_cBDU5n36uEH3neFRK7a11ya5r2l1_PmoJ81WF-tIJsFBffOGhw5iYn92RzYS7FnRoFfOC5JNcAOomM3x2fMI9BMye4CwatVe7hS2Q2b7XR9VWWdxYFlPPhgkg_I62aCrNX0Dp6dG6b7OaPJci3C3FDmVOlv4YRbiZqFp6ZVR-ouUyoHQdT6aJFE589ziJ9YM2FzGesjYPNUcBq_4JMmdOfrB7_eE3OWoWex2DGRJhRsfTU7D_fwr8Oa3aYt5e0j-_4WUz',
  RefundCategory.services:
      'https://lh3.googleusercontent.com/aida-public/AB6AXuDe_lBbQqqGmdRQ_aA7V_ASfkbST_Pz5yeOh1Ro2hrg5cvtnEE_OUIClFG-NldguSw-4YDPyKKIISbb2ar0xG1YzDDWUzA9EywybJgOi5BoYV_a5MHMQeY4cOJSoX6tLCodGJ89aJc4ZUmWl_FxAKa7ao6rFswrwj8ZTTqcp_-8XtYU-LfdZMZMoceRtOMnY1YkT5t9yI0WdllNtLfQXrRyjiws_sV48jDQJ5HThzji_Gpj5G3jAXjdz4DoFy28-Ks8GfmwQEWAN_f-',
  RefundCategory.foodDining:
      'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=800',
  RefundCategory.electronics:
      'https://images.unsplash.com/photo-1518770660439-4636190af475?w=800',
  RefundCategory.entertainment:
      'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=800',
};

/// Fallback generic image when a category has no specific image.
const _genericCategoryImage =
    'https://images.unsplash.com/photo-1556742049-0cfed4f6a45d?w=800';

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

  List<RefundItem> _refunds = [];
  bool _loading = true;
  bool _syncing = false;
  _DashboardFilterKind _filterKind = _DashboardFilterKind.all;
  RefundCategory? _filterCategory;
  String _chipFilter = 'All'; // for the existing status chips: All, Processing, Completed, Action Needed

  double get _pendingAmount {
    final pending = _refunds.where((r) => r.status != RefundStatus.completed);
    return pending.fold(0.0, (sum, r) => sum + r.amount);
  }

  int get _waitDays {
    if (_refunds.isEmpty) return 3;
    final processing = _refunds.where((r) => r.status != RefundStatus.completed);
    if (processing.isEmpty) return 0;
    return 3;
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

    // Then apply status chip filter (All, Processing, Completed, Action Needed)
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
      default:
        break;
    }

    return list;
  }

  List<({RefundCategory category, double amount, bool pending})> get _categories {
    final byCategory = <RefundCategory, ({double total, bool hasPending})>{
      RefundCategory.travel: (total: 0, hasPending: false),
      RefundCategory.retail: (total: 0, hasPending: false),
      RefundCategory.services: (total: 0, hasPending: false),
      RefundCategory.foodDining: (total: 0, hasPending: false),
      RefundCategory.electronics: (total: 0, hasPending: false),
      RefundCategory.entertainment: (total: 0, hasPending: false),
    };
    for (final r in _refunds) {
      final cat = r.category ?? RefundCategory.retail;
      final cur = byCategory[cat];
      if (cur != null) {
        byCategory[cat] = (
          total: cur.total + r.amount,
          hasPending: cur.hasPending || r.status != RefundStatus.completed,
        );
      }
    }
    return byCategory.entries
        .map((e) => (
              category: e.key,
              amount: e.value.total,
              pending: e.value.hasPending,
            ))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _loadRefunds();
  }

  Future<void> _loadRefunds() async {
    setState(() => _loading = true);
    var list = await _storage.loadRefunds();
    if (list.isEmpty) {
      list = _defaultRefunds();
      await _storage.saveRefunds(list);
    }
    setState(() {
      _refunds = list;
      _loading = false;
    });
  }

  List<RefundItem> _defaultRefunds() {
    return [
      const RefundItem(
        id: '1',
        merchantName: 'Amazon.com',
        amount: 34.99,
        status: RefundStatus.processing,
        source: RefundSource.email,
        category: RefundCategory.retail,
      ),
      const RefundItem(
        id: '2',
        merchantName: 'Delta Airlines',
        amount: 245.00,
        status: RefundStatus.awaitingConfirmation,
        source: RefundSource.email,
        category: RefundCategory.travel,
      ),
    ];
  }

  Future<void> _quickSync() async {
    setState(() => _syncing = true);
    final prefs = await SharedPreferences.getInstance();
    final smsEnabled = prefs.getBool('sms_enabled') ?? false;
    var newCount = 0;
    if (smsEnabled && Platform.isAndroid) {
      final fromSms = await _smsScanner.scanInbox();
      newCount = fromSms.length;
      if (fromSms.isNotEmpty) {
        await _storage.mergeAndSave(fromSms);
      }
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
              : 'Refunds loaded from local storage. No new SMS refunds this time.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _buildAppBar(context),
            ),
            SliverToBoxAdapter(
              child: _buildHeadline(context),
            ),
            SliverToBoxAdapter(
              child: _buildStatsRow(context),
            ),
            SliverToBoxAdapter(
              child: _buildSectionHeader(context, 'Refund Categories', 'View all'),
            ),
            SliverToBoxAdapter(
              child: _buildCategoriesGrid(context),
            ),
            SliverToBoxAdapter(
              child: _buildSectionHeader(context, 'Recent Activity', ''),
            ),
            if (_hasActiveFilter)
              SliverToBoxAdapter(
                child: _buildClearFilterBar(context),
              ),
            SliverToBoxAdapter(
              child: _buildFilterChips(context),
            ),
            if (_loading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) {
                    final item = _filteredRefunds[i];
                    return _ActivityTile(
                      item: item,
                      onTap: () => context.push('/refund/${item.id}'),
                    );
                  },
                  childCount: _filteredRefunds.length,
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(context),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: _QuickSyncButton(
          onPressed: _syncing ? null : _quickSync,
          syncing: _syncing,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined, size: 32),
            onPressed: () => context.push('/profile'),
          ),
          Expanded(
            child: Text(
              'Dashboard',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 28),
            onPressed: () => context.push('/add-refund'),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, size: 28),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildHeadline(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        children: [
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontSize: 36,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
              children: [
                const TextSpan(text: 'You have '),
                TextSpan(
                  text: '\$${_pendingAmount.toStringAsFixed(0)}',
                  style: const TextStyle(color: AppColors.primary),
                ),
                const TextSpan(text: ' on the way.'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Estimated arrival in 3-5 business days',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: _BentoCard(
              icon: Icons.pending_actions_outlined,
              iconColor: AppColors.primary,
              label: 'Pending',
              value: '\$${_pendingAmount.toStringAsFixed(2)}',
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
              label: 'Wait Time',
              value: '$_waitDays Days',
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
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
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

  Widget _buildCategoriesGrid(BuildContext context) {
    final cats = _categories;
    double amountFor(RefundCategory c) {
      return cats.where((x) => x.category == c).firstOrNull?.amount ?? 0;
    }
    bool pendingFor(RefundCategory c) {
      return cats.where((x) => x.category == c).firstOrNull?.pending ?? false;
    }
    void onCategoryTap(RefundCategory c) {
      setState(() {
        _filterKind = _DashboardFilterKind.category;
        _filterCategory = c;
      });
    }
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _CategoryBento(
                  category: RefundCategory.travel,
                  amount: amountFor(RefundCategory.travel),
                  pending: pendingFor(RefundCategory.travel),
                  onTap: () => onCategoryTap(RefundCategory.travel),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _CategoryBento(
                  category: RefundCategory.retail,
                  amount: amountFor(RefundCategory.retail),
                  pending: pendingFor(RefundCategory.retail),
                  tall: true,
                  onTap: () => onCategoryTap(RefundCategory.retail),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _CategoryBento(
            category: RefundCategory.services,
            amount: amountFor(RefundCategory.services),
            pending: pendingFor(RefundCategory.services),
            onTap: () => onCategoryTap(RefundCategory.services),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _CategoryBento(
                  category: RefundCategory.foodDining,
                  amount: amountFor(RefundCategory.foodDining),
                  pending: pendingFor(RefundCategory.foodDining),
                  onTap: () => onCategoryTap(RefundCategory.foodDining),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _CategoryBento(
                  category: RefundCategory.electronics,
                  amount: amountFor(RefundCategory.electronics),
                  pending: pendingFor(RefundCategory.electronics),
                  onTap: () => onCategoryTap(RefundCategory.electronics),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _CategoryBento(
                  category: RefundCategory.entertainment,
                  amount: amountFor(RefundCategory.entertainment),
                  pending: pendingFor(RefundCategory.entertainment),
                  onTap: () => onCategoryTap(RefundCategory.entertainment),
                ),
              ),
            ],
          ),
        ],
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
    if (_chipFilter != 'All') return 'Showing $_chipFilter only.';
    return 'Filter active.';
  }

  Widget _buildFilterChips(BuildContext context) {
    final chips = ['All', 'Processing', 'Completed', 'Action Needed'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: chips.map((c) {
          final selected = c == _chipFilter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(c, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              selected: selected,
              onSelected: (_) => setState(() => _chipFilter = c),
              selectedColor: AppColors.primary,
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.05)
                  : AppColors.surfaceLight,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return BottomAppBar(
      height: 80,
      padding: const EdgeInsets.symmetric(vertical: 12),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(icon: Icons.grid_view_outlined, onTap: () {}),
          _NavItem(icon: Icons.receipt_long_outlined, onTap: () {}),
          _NavItem(
            icon: Icons.person_outline,
            active: true,
            onTap: () => context.push('/profile'),
          ),
        ],
      ),
    );
  }
}

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
    required this.pending,
    this.tall = false,
    this.onTap,
  });

  final RefundCategory category;
  final double amount;
  final bool pending;
  final bool tall;
  final VoidCallback? onTap;

  static const _gradientOverlay = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: [
      Color(0x99000000),
      Color(0x00000000),
    ],
    stops: [0.0, 0.6],
  );

  @override
  Widget build(BuildContext context) {
    final imageUrl = _categoryBackgroundImages[category] ?? _genericCategoryImage;
    final height = tall ? 200.0 : 100.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0x0D000000),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
          Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: const Color(0xFF1E3A5F),
            ),
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(color: const Color(0xFF1E3A5F));
            },
          ),
          DecoratedBox(
            decoration: const BoxDecoration(gradient: _gradientOverlay),
            child: const SizedBox.expand(),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _iconForCategory(category),
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      category.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Text(
                  pending ? '\$${amount.toStringAsFixed(2)} pending' : '\$${amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      child: Material(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.05)
            : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _activityIconFor(item.category),
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.merchantName,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        item.statusLabel,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
                Text(
                  '\$${item.amount.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.onTap, this.active = false});

  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 28,
            color: active ? AppColors.primary : AppColors.textMuted,
          ),
          if (active) const SizedBox(height: 4),
          if (active)
            Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}

class _QuickSyncButton extends StatelessWidget {
  const _QuickSyncButton({required this.onPressed, this.syncing = false});

  final VoidCallback? onPressed;
  final bool syncing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: syncing
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.sync, size: 22),
        label: Text(syncing ? 'Syncing...' : 'Quick Sync'),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 32),
        ),
      ),
    );
  }
}
