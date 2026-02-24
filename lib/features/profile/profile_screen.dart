import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 24),
            onPressed: () {},
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
              'Alex Rivera',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(
              'alex.rivera@icloud.com',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    letterSpacing: 2,
                    color: AppColors.textMuted,
                  ),
            ),
            const SizedBox(height: 32),
            _buildPersonaBadge(context),
            const SizedBox(height: 24),
            _buildSecurityGrid(context),
            const SizedBox(height: 24),
            _buildIntegrations(context),
            const SizedBox(height: 48),
            TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.logout, color: AppColors.textMuted, size: 20),
              label: const Text(
                'Sign Out',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w700,
                ),
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
          child: const Icon(Icons.person, size: 48, color: Colors.white70),
        ),
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            border: Border.all(
              color: Theme.of(context).scaffoldBackgroundColor,
              width: 2,
            ),
          ),
          child: const Icon(Icons.edit, size: 14, color: AppColors.textPrimary),
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
          Container(
            width: 48,
            height: 2,
            color: AppColors.primary,
          ),
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

  Widget _buildSecurityGrid(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Security & Access',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: _ProfileCard(
                icon: Icons.verified_user_outlined,
                iconColor: Colors.blue,
                title: 'Security Audit',
                subtitle: '2FA & Bio-auth enabled',
                badge: 'ACTIVE',
                color: AppColors.pastelBlue,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _ProfileCard(
                icon: Icons.notifications_active_outlined,
                iconColor: Colors.purple,
                title: '12',
                subtitle: 'Alerts',
                color: AppColors.pastelPurple,
                compact: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _ProfileCard(
          icon: Icons.account_balance_wallet_outlined,
          iconColor: Colors.green,
          title: 'Vault Access',
          subtitle: '3 Linked Institutions',
          color: AppColors.pastelGreen,
        ),
      ],
    );
  }

  Widget _buildIntegrations(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Integrations',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.05)
                : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.1)
                  : const Color(0xFFF3F4F6),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF1A2E2E)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.alternate_email,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.primary
                      : AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Smart Receipt Parser',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      'Email Sync Enabled',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
      ],
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

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.iconColor,
    this.badge,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color? iconColor;
  final String? badge;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: (iconColor ?? AppColors.primary).withValues(alpha: 0.2),
        ),
      ),
      child: compact
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 40, color: iconColor ?? AppColors.primary),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(icon, color: iconColor ?? AppColors.primary, size: 24),
                    ),
                    if (badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (iconColor ?? Colors.blue).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          badge!,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: iconColor ?? Colors.blue,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.labelSmall,
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
