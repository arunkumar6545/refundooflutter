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
  bool _emailEnabled = false;
  bool _loadingPrefs = true;
  String? _approvedEmailAccount;

  final AuthService _auth = AuthService();
  final EmailScannerService _emailScanner = EmailScannerService();

  @override
  void initState() {
    super.initState();
    _loadSavedPrefs();
  }

  Future<void> _loadSavedPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final approved = await _emailScanner.approvedAccount;
    setState(() {
      _smsEnabled = prefs.getBool('sms_enabled') ?? true;
      _emailEnabled = prefs.getBool('email_sync_enabled') ?? false;
      _approvedEmailAccount = approved;
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

  Future<void> _onEmailToggleChanged(bool value) async {
    if (!value) {
      await _emailScanner.setEnabled(false);
      setState(() { _emailEnabled = false; _approvedEmailAccount = null; });
      return;
    }

    // Must be signed in with Google to use Gmail
    final account = _auth.currentUser;
    if (account == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sign in with Google first to enable email sync.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Request Gmail readonly scope
    final granted = await _auth.requestGmailScope();
    if (!mounted) return;
    if (granted) {
      await _emailScanner.setEnabled(true, accountEmail: account.email);
      setState(() {
        _emailEnabled = true;
        _approvedEmailAccount = account.email;
      });
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

  Future<void> _finishSetup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sms_enabled', _smsEnabled);
    await prefs.setBool('has_completed_setup', true);
    if (!mounted) return;
    context.go('/dashboard');
  }

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
              _PermissionCard(
                icon: Icons.mail_outline,
                title: 'Email Sync',
                description: _approvedEmailAccount != null
                    ? 'Syncing Gmail for $_approvedEmailAccount (last 30 days). Tap to disable.'
                    : 'Scan your Gmail inbox for refund confirmations from the last 30 days. Requires Google sign-in and Gmail read access.',
                value: _emailEnabled,
                onChanged: _onEmailToggleChanged,
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
