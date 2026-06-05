import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import 'app_logo.dart';
import '../../services/auth_service.dart';
import '../../services/email_scanner_service.dart';

/// Full-height side navigation drawer.
/// Shows the user profile header, primary navigation, and account actions.
class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key, required this.currentRoute});

  /// Pass the active route path so the drawer can highlight the current item.
  final String currentRoute;

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  final _auth = AuthService();
  final _emailScanner = EmailScannerService();

  String _name = '';
  String _email = '';
  String? _photoUrl;
  bool _isGuest = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final name = await _auth.cachedName;
    final email = await _auth.cachedEmail;
    final photo = await _auth.cachedPhotoUrl;
    final guest = await _auth.isGuest;
    if (!mounted) return;
    setState(() {
      _name = name;
      _email = email;
      _photoUrl = photo;
      _isGuest = guest;
    });
  }

  void _go(BuildContext context, String route) {
    Navigator.of(context).pop(); // close drawer
    if (widget.currentRoute != route) {
      context.push(route);
    }
  }

  Future<void> _signOut(BuildContext context) async {
    Navigator.of(context).pop();
    await _auth.signOut();
    if (context.mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    return Drawer(
      width: screenWidth * 0.78,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
      ),
      backgroundColor:
          isDark ? const Color(0xFF121828) : const Color(0xFFFAFAFC),
      child: Column(
        children: [
          // ── Gradient header ───────────────────────────────────────────────
          _DrawerHeader(
            name: _name,
            email: _email,
            photoUrl: _photoUrl,
            isGuest: _isGuest,
            isDark: isDark,
            onProfileTap: () => _go(context, '/profile'),
          ),

          // ── Scrollable nav items ──────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                // MAIN
                _SectionLabel('Main'),
                _DrawerItem(
                  icon: Icons.grid_view_rounded,
                  label: 'Dashboard',
                  active: widget.currentRoute == '/dashboard',
                  onTap: () => _go(context, '/dashboard'),
                ),
                _DrawerItem(
                  icon: Icons.bar_chart_rounded,
                  label: 'Reports',
                  active: widget.currentRoute == '/reports',
                  badge: 'New',
                  onTap: () => _go(context, '/reports'),
                  sublabel: 'Charts & insights',
                ),

                const SizedBox(height: 6),
                const Divider(height: 1, indent: 8, endIndent: 8),
                const SizedBox(height: 6),

                // REFUNDS
                _SectionLabel('Refunds'),
                _DrawerItem(
                  icon: Icons.receipt_long_outlined,
                  label: 'All Refunds',
                  active: false,
                  onTap: () => _go(context, '/dashboard'),
                ),
                _DrawerItem(
                  icon: Icons.add_circle_outline_rounded,
                  label: 'Add Refund',
                  active: widget.currentRoute == '/add-refund',
                  onTap: () => _go(context, '/add-refund'),
                ),
                _DrawerItem(
                  icon: Icons.archive_outlined,
                  label: 'Archive',
                  active: widget.currentRoute == '/archive',
                  sublabel: 'Completed refunds',
                  onTap: () => _go(context, '/archive'),
                ),

                const SizedBox(height: 6),
                const Divider(height: 1, indent: 8, endIndent: 8),
                const SizedBox(height: 6),

                // ACCOUNT
                _SectionLabel('Account'),
                _DrawerItem(
                  icon: Icons.person_outline_rounded,
                  label: 'My Profile',
                  active: widget.currentRoute == '/profile',
                  onTap: () => _go(context, '/profile'),
                ),
                _DrawerItem(
                  icon: Icons.tune_outlined,
                  label: 'Sync Settings',
                  active: widget.currentRoute == '/permissions',
                  sublabel: 'SMS & Email sync',
                  onTap: () => _go(context, '/permissions'),
                ),
              ],
            ),
          ),

          // ── Footer (sign out + version) ───────────────────────────────────
          _DrawerFooter(isDark: isDark, onSignOut: () => _signOut(context)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({
    required this.name,
    required this.email,
    required this.photoUrl,
    required this.isGuest,
    required this.isDark,
    required this.onProfileTap,
  });

  final String name;
  final String email;
  final String? photoUrl;
  final bool isGuest;
  final bool isDark;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onProfileTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 24,
          left: 20,
          right: 20,
          bottom: 24,
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
          ),
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(28),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1A237E).withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo row
            Row(
              children: [
                const AppLogo(size: 28, borderRadius: 8, showGlow: false),
                const SizedBox(width: 8),
                const Text(
                  'Refundoo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.chevron_right,
                  color: Colors.white.withValues(alpha: 0.6),
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Avatar + name
            Row(
              children: [
                _Avatar(photoUrl: photoUrl, name: name, isGuest: isGuest),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isEmpty ? 'Loading…' : name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isGuest
                            ? 'Using without account'
                            : (email.isEmpty ? '' : email),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Tag pill
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25)),
              ),
              child: Text(
                isGuest ? 'Guest mode' : 'Google Account',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar(
      {required this.photoUrl, required this.name, required this.isGuest});

  final String? photoUrl;
  final String name;
  final bool isGuest;

  @override
  Widget build(BuildContext context) {
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 28,
        backgroundColor: Colors.white.withValues(alpha: 0.2),
        child: ClipOval(
          child: Image.network(
            photoUrl!,
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _initials(),
          ),
        ),
      );
    }
    return CircleAvatar(
      radius: 28,
      backgroundColor: Colors.white.withValues(alpha: 0.2),
      child: _initials(),
    );
  }

  Widget _initials() {
    final letter =
        isGuest ? 'G' : (name.isNotEmpty ? name[0].toUpperCase() : '?');
    return Text(
      letter,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 22,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section label
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: AppColors.textMuted,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Nav item
// ─────────────────────────────────────────────────────────────────────────────

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.sublabel,
    this.badge,
  });

  final IconData icon;
  final String label;
  final String? sublabel;
  final String? badge;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = AppColors.primary;
    final inactiveColor = isDark ? Colors.white70 : AppColors.textMuted;
    final activeBg = AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.1);

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: active ? activeBg : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                // Icon
                Icon(
                  icon,
                  size: 22,
                  color: active ? activeColor : inactiveColor,
                ),
                const SizedBox(width: 14),
                // Labels
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              active ? FontWeight.w700 : FontWeight.w500,
                          color: active
                              ? activeColor
                              : (isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                      if (sublabel != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          sublabel!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Badge pill (e.g. "New")
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                // Active indicator dot
                if (active) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: activeColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Footer
// ─────────────────────────────────────────────────────────────────────────────

class _DrawerFooter extends StatelessWidget {
  const _DrawerFooter({required this.isDark, required this.onSignOut});

  final bool isDark;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFE5E7EB),
          ),
        ),
      ),
      child: Row(
        children: [
          // Sign out
          Expanded(
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: onSignOut,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 10, horizontal: 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.logout_rounded,
                        size: 20,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Sign out',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Version label
          Text(
            'v1.0.0',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
