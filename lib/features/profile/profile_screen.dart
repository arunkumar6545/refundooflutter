import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_logo.dart';
import '../../services/auth_service.dart';
import '../../services/email_scanner_service.dart';
import '../../main.dart' show themeModeNotifier;

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

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadSyncStatus();
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

  Future<void> _loadSyncStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final emailEnabled = await _emailScanner.isEnabled;
    final approvedEmail = await _emailScanner.approvedAccount;
    if (mounted) {
      setState(() {
        _smsEnabled = prefs.getBool('sms_enabled') ?? false;
        _emailSyncEnabled = emailEnabled;
        _approvedEmailAccount = approvedEmail;
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
            Text(
              _name.isNotEmpty ? _name : 'User',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(
              _email.isNotEmpty ? _email : (_isGuest ? 'Guest' : ''),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    letterSpacing: 1,
                    color: AppColors.textMuted,
                  ),
            ),
            const SizedBox(height: 32),
            _buildSyncSection(context),
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
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String status;
  final Color statusColor;
  final String detail;
  final bool isDark;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Container(
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
