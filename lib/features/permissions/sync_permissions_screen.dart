import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/email_scanner_service.dart';

class SyncPermissionsScreen extends StatefulWidget {
  const SyncPermissionsScreen({super.key});

  @override
  State<SyncPermissionsScreen> createState() => _SyncPermissionsScreenState();
}

class _SyncPermissionsScreenState extends State<SyncPermissionsScreen> {
  bool _smsEnabled = true;
  bool _loadingPrefs = true;
  List<String> _approvedEmailAccounts = [];

  final AuthService _auth = AuthService();
  final EmailScannerService _emailScanner = EmailScannerService();

  @override
  void initState() {
    super.initState();
    _loadSavedPrefs();
  }

  Future<void> _loadSavedPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = await _emailScanner.approvedAccounts;
    setState(() {
      _smsEnabled = prefs.getBool('sms_enabled') ?? true;
      _approvedEmailAccounts = accounts;
      _loadingPrefs = false;
    });
  }

  Future<void> _onSmsToggleChanged(bool value) async {
    if (!value) {
      setState(() => _smsEnabled = false);
      return;
    }
    if (!Platform.isAndroid) {
      setState(() => _smsEnabled = true);
      return;
    }
    final status = await Permission.sms.request();
    if (status.isGranted) {
      setState(() => _smsEnabled = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SMS access granted. Refund tracking will use your messages locally.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      setState(() => _smsEnabled = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'SMS permission is required to scan for refunds. You can enable it in Settings.',
            ),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () => openAppSettings(),
            ),
          ),
        );
      }
    }
  }

  /// Called when user taps an email provider icon.
  Future<void> _onProviderTap(String provider) async {
    if (provider != 'gmail') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$provider sync is coming soon!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Gmail: sign in if needed, then request scope
    var account = _auth.currentUser;
    if (account == null) {
      setState(() => _loadingPrefs = true);
      try { account = await _auth.signInSilently(); } catch (_) {}
      if (account == null) {
        try { account = await _auth.signIn(); } catch (_) {}
      }
      if (mounted) setState(() => _loadingPrefs = false);
      if (account == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google sign-in failed. Please try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    // Already approved — nothing to do
    if (_approvedEmailAccounts.contains(account.email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${account.email} is already added.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final granted = await _auth.requestGmailScope();
    if (!mounted) return;
    if (granted) {
      await _emailScanner.addApprovedAccount(account.email);
      setState(() => _approvedEmailAccounts = [..._approvedEmailAccounts, account!.email]);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gmail sync enabled for ${account.email}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gmail permission was not granted.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _removeEmailAccount(String email) async {
    await _emailScanner.removeApprovedAccount(email);
    setState(() => _approvedEmailAccounts = _approvedEmailAccounts.where((e) => e != email).toList());
  }

  Future<void> _finishSetup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sms_enabled', _smsEnabled);
    await prefs.setBool('has_completed_setup', true);
    if (!mounted) return;
    context.go('/dashboard');
  }

  // ── unused field removed: _emailEnabled now derived from _approvedEmailAccounts

  @override
  Widget build(BuildContext context) {
    if (_loadingPrefs) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Sync Permissions'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text(
                'Connect your accounts to start tracking.',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontSize: 32,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                "We'll automatically find your refund confirmations and update your dashboard.",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMuted,
                    ),
              ),
              const SizedBox(height: 32),
              _PermissionCard(
                icon: Icons.sms_outlined,
                title: 'SMS Access',
                description:
                    'To automatically detect refund confirmations sent via text message from retailers and airlines. Permission is required and can be revoked anytime in device Settings.',
                value: _smsEnabled,
                onChanged: _onSmsToggleChanged,
              ),
              const SizedBox(height: 16),
              _EmailSyncSection(
                approvedAccounts: _approvedEmailAccounts,
                onProviderTap: _onProviderTap,
                onRemove: _removeEmailAccount,
                isDark: isDark,
              ),
              const SizedBox(height: 32),
              Text(
                'Coverage Preview',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              _CoverageGrid(isDark: isDark),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1A2C2C)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : const Color(0xFFF3F4F6),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      color: AppColors.primary,
                      size: 32,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Security Guarantee',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your privacy is our priority. All message processing happens locally on your device. We never store the contents of your private conversations or emails on our servers.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: SizedBox(
            height: 64,
            child: FilledButton(
              onPressed: _finishSetup,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Finish Setup'),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Email Sync section — provider icon grid + approved accounts list
// ─────────────────────────────────────────────────────────────────────────────

class _EmailProvider {
  const _EmailProvider(this.id, this.label, this.color, this.icon, {this.available = false});
  final String id;
  final String label;
  final Color color;
  final IconData icon;
  final bool available;
}

const _kEmailProviders = [
  _EmailProvider('gmail',   'Gmail',       Color(0xFFEA4335), Icons.mail_rounded,            available: true),
  _EmailProvider('outlook', 'Outlook',     Color(0xFF0078D4), Icons.mail_outline_rounded),
  _EmailProvider('yahoo',   'Yahoo Mail',  Color(0xFF6001D2), Icons.alternate_email_rounded),
  _EmailProvider('apple',   'Apple Mail',  Color(0xFF1C7CD6), Icons.mark_email_read_rounded),
];

class _EmailSyncSection extends StatelessWidget {
  const _EmailSyncSection({
    required this.approvedAccounts,
    required this.onProviderTap,
    required this.onRemove,
    required this.isDark,
  });

  final List<String> approvedAccounts;
  final void Function(String providerId) onProviderTap;
  final void Function(String email) onRemove;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.mail_outline, color: AppColors.primary, size: 28),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Email Sync',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 20)),
          const SizedBox(height: 4),
          Text(
            'Tap a provider to connect your inbox. We scan the last 30 days for refund confirmations — nothing leaves your device.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),

          // Provider icon grid
          Row(
            children: _kEmailProviders.map((p) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _ProviderIcon(
                    provider: p,
                    isDark: isDark,
                    onTap: () => onProviderTap(p.id),
                  ),
                ),
              );
            }).toList(),
          ),

          // Approved accounts list
          if (approvedAccounts.isNotEmpty) ...[
            const SizedBox(height: 20),
            Divider(color: AppColors.primary.withValues(alpha: 0.12)),
            const SizedBox(height: 12),
            Text(
              'Connected accounts',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textMuted,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),
            ...approvedAccounts.map((email) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ApprovedAccountTile(
                email: email,
                isDark: isDark,
                onRemove: () => onRemove(email),
              ),
            )),
          ],
        ],
      ),
    );
  }
}

class _ProviderIcon extends StatelessWidget {
  const _ProviderIcon({
    required this.provider,
    required this.isDark,
    required this.onTap,
  });

  final _EmailProvider provider;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: isDark
                      ? provider.color.withValues(alpha: 0.2)
                      : provider.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: provider.color.withValues(alpha: provider.available ? 0.5 : 0.25),
                    width: 1.5,
                  ),
                ),
                child: Icon(provider.icon, color: provider.color, size: 26),
              ),
              if (!provider.available)
                Positioned(
                  right: 0, top: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.textMuted,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Soon',
                        style: TextStyle(fontSize: 7, color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            provider.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: provider.available
                  ? (isDark ? Colors.white : const Color(0xFF1E293B))
                  : AppColors.textMuted,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}

class _ApprovedAccountTile extends StatelessWidget {
  const _ApprovedAccountTile({
    required this.email,
    required this.isDark,
    required this.onRemove,
  });

  final String email;
  final bool isDark;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: isDark ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.success, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              email,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.success,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close, size: 16,
                color: AppColors.success.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.05)
            : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: AppColors.primary, size: 28),
              ),
              const Spacer(),
              Switch.adaptive(
                value: value,
                onChanged: onChanged,
                activeColor: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 20,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _CoverageGrid extends StatelessWidget {
  const _CoverageGrid({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: _CoverageTile(
                label: 'Travel',
                sublabel: 'Airlines & Hotels',
                icon: Icons.flight_takeoff,
                color: AppColors.pastelBlue,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _CoverageTile(
                label: 'Retail',
                sublabel: 'Top Brands',
                icon: Icons.shopping_bag_outlined,
                color: AppColors.pastelOrange,
                tall: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _CoverageTile(
          label: 'Services',
          sublabel: 'Subscriptions',
          icon: Icons.description_outlined,
          color: AppColors.pastelPurple,
        ),
      ],
    );
  }
}

class _CoverageTile extends StatelessWidget {
  const _CoverageTile({
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.color,
    this.tall = false,
  });

  final String label;
  final String sublabel;
  final IconData icon;
  final Color color;
  final bool tall;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: tall ? 120 : 80),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: color.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF0369A1), size: 20),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0C4A6E),
                    ),
              ),
              Text(
                sublabel,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: const Color(0xFF0369A1),
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
