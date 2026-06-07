import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_logo.dart';
import '../../services/auth_service.dart';
import '../../services/email_scanner_service.dart';
import 'package:intl/intl.dart';
import '../../main.dart' show premiumNotifier, themeModeNotifier;
import '../../services/notification_service.dart';
import '../../services/premium_service.dart';
import '../../services/swipe_settings_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _auth = AuthService();
  final EmailScannerService _emailScanner = EmailScannerService();
  String _name = '';
  String _email = '';
  String? _photoUrl;
  bool _smsEnabled = false;
  bool _emailSyncEnabled = false;
  String? _approvedEmailAccount;
  bool _isGuest = false;
  bool _notificationsEnabled = true;
  bool _isPremium = false;
  DateTime? _premiumExpiry;
  SwipeAction _swipeLeft  = SwipeAction.delete;
  SwipeAction _swipeRight = SwipeAction.archive;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadSyncStatus();
    _loadPremiumStatus();
    _loadSwipeSettings();
  }

  Future<void> _loadUser() async {
    final name = await _auth.cachedName;
    final email = await _auth.cachedEmail;
    final photo = await _auth.cachedPhotoUrl;
    final guest = await _auth.isGuest;
    if (mounted) {
      setState(() {
        _name = name;
        _email = email;
        _photoUrl = photo;
        _isGuest = guest;
      });
    }
  }

  Future<void> _loadPremiumStatus() async {
    final active = await PremiumService.isPremium;
    final expiry = await PremiumService.expiryDate;
    if (!mounted) return;
    setState(() {
      _isPremium = active;
      _premiumExpiry = expiry;
    });
  }

  Future<void> _loadSwipeSettings() async {
    final swipe = await SwipeSettingsService.load();
    if (!mounted) return;
    setState(() {
      _swipeLeft  = swipe.left;
      _swipeRight = swipe.right;
    });
  }

  Future<void> _loadSyncStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final emailEnabled = await _emailScanner.isEnabled;
    final approvedEmail = await _emailScanner.approvedAccount;
    if (mounted) {
      setState(() {
        _smsEnabled = prefs.getBool('sms_enabled') ?? false;
        _emailSyncEnabled = emailEnabled;
        _approvedEmailAccount = approvedEmail;
        _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      });
    }
  }

  Future<void> _signOut() async {
    await _auth.signOut();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppLogo(size: 30, borderRadius: 8, showGlow: false),
            SizedBox(width: 8),
            Text('Profile'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_outlined, size: 24),
            onPressed: () => context.push('/permissions'),
            tooltip: 'Sync settings',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 16),
            _buildAvatar(context),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _name.isNotEmpty ? _name : 'User',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                if (_isPremium) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFB8860B), Color(0xFFFFD700)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.workspace_premium_rounded,
                            color: Colors.white, size: 12),
                        SizedBox(width: 3),
                        Text('Premium',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            Text(
              _email.isNotEmpty ? _email : (_isGuest ? 'Guest' : ''),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    letterSpacing: 1,
                    color: AppColors.textMuted,
                  ),
            ),
            const SizedBox(height: 8),
            _buildPremiumSection(context),
            const SizedBox(height: 24),
            _buildSyncSection(context),
            const SizedBox(height: 24),
            _buildNotificationsSection(context),
            const SizedBox(height: 24),
            _buildSwipeSection(context),
            const SizedBox(height: 24),
            _buildAppearanceSection(context),
            const SizedBox(height: 24),
            _buildPersonaBadge(context),
            const SizedBox(height: 48),
            TextButton.icon(
              onPressed: _signOut,
              icon: const Icon(Icons.logout, color: Colors.red, size: 20),
              label: const Text(
                'Sign Out',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'VERSION 1.0.0',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 9,
                    letterSpacing: 3,
                    color: AppColors.textMuted,
                  ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.pastelBlue],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: _photoUrl != null
              ? ClipOval(
                  child: Image.network(
                    _photoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.person, size: 48, color: Colors.white70),
                  ),
                )
              : const Icon(Icons.person, size: 48, color: Colors.white70),
        ),
      ],
    );
  }

  // ── Premium section ─────────────────────────────────────────────────────

  Widget _buildPremiumSection(BuildContext context) {
    return _isPremium
        ? _buildPremiumActiveCard(context)
        : _buildPremiumUpgradeCard(context);
  }

  Widget _buildPremiumUpgradeCard(BuildContext context) {
    return GestureDetector(
      onTap: () => _showPurchaseSheet(context),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF7B4F00), Color(0xFFB8860B)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFB8860B).withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.workspace_premium_rounded,
                  color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Go Premium',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          height: 1.0)),
                  const SizedBox(height: 4),
                  const Text('Remove all ads forever · ₹100/year',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          height: 1.0)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Text('Upgrade',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Color(0xFF7B4F00),
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      height: 1.0)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumActiveCard(BuildContext context) {
    final expiryStr = _premiumExpiry != null
        ? DateFormat('d MMM yyyy').format(_premiumExpiry!)
        : '—';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4A3200), Color(0xFF7B5C00)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7B5C00).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.workspace_premium_rounded,
                  color: Color(0xFFFFD700), size: 24),
              const SizedBox(width: 10),
              const Text('Premium Active',
                  style: TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.5)),
                ),
                child: const Text('Ad-free',
                    style: TextStyle(
                        color: Color(0xFFFFD700),
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Valid until $expiryStr',
              style:
                  const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white30),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _showPurchaseSheet(context),
                  child: const Text('Renew'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _confirmRevoke(context),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Purchase bottom-sheet.
  ///
  /// TODO: Replace the "Confirm Purchase" handler with your real payment flow
  ///       (in_app_purchase / Razorpay / etc.) and only call
  ///       [PremiumService.activatePremium] after a verified payment callback.
  Future<void> _showPurchaseSheet(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PremiumPurchaseSheet(
        onPurchase: () async {
          // ── TODO: wire real payment here ──────────────────────────────────
          await PremiumService.activatePremium();
          premiumNotifier.value = true;
          // ─────────────────────────────────────────────────────────────────
          if (!mounted) return;
          Navigator.of(context).pop();
          await _loadPremiumStatus();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉  Welcome to Premium! Ads removed.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmRevoke(BuildContext context) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel Premium?'),
        content: const Text(
            'You will lose your ad-free experience and your Premium badge.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  const Text('Cancel Premium', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (yes != true) return;
    await PremiumService.revokePremium();
    premiumNotifier.value = false;
    await _loadPremiumStatus();
  }

  Widget _buildSyncSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Sync & Permissions',
                style: Theme.of(context).textTheme.titleLarge),
            TextButton(
              onPressed: () async {
                await context.push('/permissions');
                _loadSyncStatus();
              },
              child: const Text('Manage'),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // SMS Sync card
        _SyncStatusCard(
          icon: Icons.sms_outlined,
          iconColor: _smsEnabled
              ? AppColors.success
              : AppColors.textMuted,
          title: 'SMS Sync',
          status: _smsEnabled ? 'Active' : 'Disabled',
          statusColor: _smsEnabled ? AppColors.success : AppColors.textMuted,
          detail: _smsEnabled
              ? 'Scanning all incoming refund SMS'
              : 'Enable in sync settings to scan SMS',
          isDark: isDark,
          onTap: _smsEnabled ? null : () => context.push('/permissions'),
        ),
        const SizedBox(height: 12),

        // Email Sync card
        _SyncStatusCard(
          icon: Icons.mail_outline,
          iconColor: _emailSyncEnabled
              ? AppColors.primary
              : AppColors.textMuted,
          title: 'Gmail Sync',
          status: _emailSyncEnabled ? 'Active' : 'Disabled',
          statusColor: _emailSyncEnabled ? AppColors.primary : AppColors.textMuted,
          detail: _emailSyncEnabled
              ? 'Scanning last 30 days'
              : 'Enable in sync settings',
          isDark: isDark,
          badge: _emailSyncEnabled && _approvedEmailAccount != null
              ? _approvedEmailAccount!
              : null,
          onTap: _emailSyncEnabled ? null : () => context.push('/permissions'),
        ),
      ],
    );
  }

  Widget _buildNotificationsSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: (_notificationsEnabled ? AppColors.primary : AppColors.textMuted)
              .withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: (_notificationsEnabled ? AppColors.primary : AppColors.textMuted)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.notifications_outlined,
              color: _notificationsEnabled ? AppColors.primary : AppColors.textMuted,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Overdue Alerts',
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  _notificationsEnabled
                      ? 'Daily reminder + overdue alerts'
                      : 'Notifications disabled',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Switch(
            value: _notificationsEnabled,
            activeColor: AppColors.primary,
            onChanged: (val) async {
              setState(() => _notificationsEnabled = val);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('notifications_enabled', val);
              if (val) {
                await NotificationService.scheduleDailyReminder();
              } else {
                await NotificationService.cancelAll();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSwipeSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget swipeRow({
      required String label,
      required IconData icon,
      required SwipeAction value,
      required ValueChanged<SwipeAction?> onChanged,
    }) {
      return Row(
        children: [
          Icon(icon, size: 18,
              color: isDark ? Colors.white70 : Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: Theme.of(context).textTheme.bodyMedium),
          ),
          DropdownButton<SwipeAction>(
            value: value,
            underline: const SizedBox.shrink(),
            borderRadius: BorderRadius.circular(12),
            items: SwipeAction.values.map((a) => DropdownMenuItem(
              value: a,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    a == SwipeAction.archive
                        ? Icons.archive_outlined
                        : Icons.delete_outline,
                    size: 16,
                    color: a == SwipeAction.archive
                        ? const Color(0xFF0D9488)
                        : const Color(0xFFDC2626),
                  ),
                  const SizedBox(width: 6),
                  Text(a.label),
                ],
              ),
            )).toList(),
            onChanged: onChanged,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Swipe Gestures', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text('Configure what left and right swipe do on refund tiles.',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              swipeRow(
                label: 'Swipe right',
                icon: Icons.swipe_right_outlined,
                value: _swipeRight,
                onChanged: (a) async {
                  if (a == null) return;
                  await SwipeSettingsService.setRightAction(a);
                  setState(() => _swipeRight = a);
                },
              ),
              const Divider(height: 20),
              swipeRow(
                label: 'Swipe left',
                icon: Icons.swipe_left_outlined,
                value: _swipeLeft,
                onChanged: (a) async {
                  if (a == null) return;
                  await SwipeSettingsService.setLeftAction(a);
                  setState(() => _swipeLeft = a);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAppearanceSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Appearance', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        ValueListenableBuilder<ThemeMode>(
          valueListenable: themeModeNotifier,
          builder: (_, current, __) => SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode_outlined, size: 18),
                label: Text('Light'),
              ),
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.brightness_auto_outlined, size: 18),
                label: Text('System'),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode_outlined, size: 18),
                label: Text('Dark'),
              ),
            ],
            selected: {current},
            onSelectionChanged: (Set<ThemeMode> val) async {
              final mode = val.first;
              themeModeNotifier.value = mode;
              final prefs = await SharedPreferences.getInstance();
              final key = mode == ThemeMode.light ? 'light'
                        : mode == ThemeMode.dark  ? 'dark'
                        : 'system';
              await prefs.setString('theme_mode', key);
            },
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: AppColors.primary.withValues(alpha: 0.15),
              selectedForegroundColor: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPersonaBadge(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF112121), Color(0xFF2A4A4A)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'AI Shopper Profile',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.primary,
                      letterSpacing: 2,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'MINDFUL PLANNER',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                ),
          ),
          const SizedBox(height: 12),
          Container(width: 48, height: 2, color: AppColors.primary),
          const SizedBox(height: 12),
          Text(
            'You tend to request refunds for apparel most frequently, showing a preference for high-end fit precision and quality testing.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                  height: 1.4,
                ),
          ),
        ],
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
          _NavItem(icon: Icons.grid_view_outlined, onTap: () => context.go('/dashboard')),
          _NavItem(icon: Icons.receipt_long_outlined, onTap: () => context.go('/dashboard')),
          _NavItem(icon: Icons.person, active: true, onTap: () {}),
        ],
      ),
    );
  }
}

/// A card that shows the live status of a single sync source.
class _SyncStatusCard extends StatelessWidget {
  const _SyncStatusCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.status,
    required this.statusColor,
    required this.detail,
    required this.isDark,
    this.badge,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String status;
  final Color statusColor;
  final String detail;
  final bool isDark;
  final String? badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: statusColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                if (onTap != null)
                  GestureDetector(
                    onTap: onTap,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Tap to enable in Sync Settings',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_ios_rounded,
                            size: 11, color: AppColors.primary),
                      ],
                    ),
                  )
                else
                  Text(
                    detail,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                  ),
                if (badge != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.account_circle_outlined,
                            size: 12, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            badge!,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ), // Container
    ); // InkWell
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Premium purchase bottom-sheet
// ─────────────────────────────────────────────────────────────────────────────

class _PremiumPurchaseSheet extends StatelessWidget {
  const _PremiumPurchaseSheet({required this.onPurchase});
  final VoidCallback onPurchase;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.textMuted.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          // Crown icon
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFB8860B), Color(0xFFFFD700)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 6)),
              ],
            ),
            child: const Icon(Icons.workspace_premium_rounded,
                color: Colors.white, size: 38),
          ),
          const SizedBox(height: 20),
          const Text('Refundoo Premium',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('One-time yearly subscription',
              style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted)),
          const SizedBox(height: 24),
          // Benefits
          _Benefit(
              icon: Icons.block_outlined,
              title: 'No ads, ever',
              subtitle: 'Banners and interstitials are completely removed'),
          const SizedBox(height: 12),
          _Benefit(
              icon: Icons.workspace_premium_rounded,
              title: 'Premium badge',
              subtitle: 'Gold crown badge shown on your profile'),
          const SizedBox(height: 12),
          _Benefit(
              icon: Icons.favorite_outline_rounded,
              title: 'Support the app',
              subtitle: 'Help keep Refundoo free & actively developed'),
          const SizedBox(height: 28),
          // Price + CTA
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB8860B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              onPressed: onPurchase,
              child: const Text('Get Premium — ₹100/year',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      height: 1.0)),
            ),
          ),
          const SizedBox(height: 12),
          // Disclaimer
          Text(
            'Subscription activates for 1 year from purchase date.\n'
            'Payment handled securely via your app store.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit(
      {required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFB8860B).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFFB8860B), size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textMuted)),
            ],
          ),
        ),
      ],
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
          Icon(icon, size: 28,
              color: active ? AppColors.primary : AppColors.textMuted),
          if (active) const SizedBox(height: 4),
          if (active)
            Container(
              width: 4, height: 4,
              decoration: const BoxDecoration(
                  color: AppColors.primary, shape: BoxShape.circle),
            ),
        ],
      ),
    );
  }
}
