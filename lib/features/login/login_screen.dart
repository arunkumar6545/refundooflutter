import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/responsive.dart';
import '../../core/widgets/app_logo.dart';
import '../../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _auth = AuthService();
  bool _loading = false;
  late AnimationController _fadeCtrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    setState(() => _loading = true);
    try {
      final account = await _auth.signIn();
      if (!mounted) return;
      if (account != null) {
        context.go('/dashboard');
      }
    } catch (e) {
      if (!mounted) return;
      final err = e.toString();
      if (err.contains('sign_in_canceled') || err.contains('canceled')) {
        // User dismissed — no message needed
      } else if (err.contains('network_error')) {
        _showError('No internet connection. Please try again.');
      } else if (err.contains(': 10:') || err.contains('DEVELOPER_ERROR')) {
        _showSetupDialog();
      } else {
        // Generic message — never expose raw exception details to the user
        _showError('Sign-in failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  void _showSetupDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.settings_outlined, color: AppColors.primary),
            SizedBox(width: 10),
            Text('OAuth setup needed'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'To enable Google Sign-In, register this app in Google Cloud Console:',
              style: TextStyle(fontSize: 13),
            ),
            SizedBox(height: 12),
            _Step(n: '1', text: 'Go to console.cloud.google.com'),
            _Step(n: '2', text: 'Create project → OAuth consent screen → External'),
            _Step(n: '3', text: 'Credentials → Create → OAuth 2.0 Client → Android'),
            _Step(n: '4', text: 'Package name: com.refundoo.refundoo'),
            _Step(n: '5', text: 'Run: keytool -list -v -keystore debug.keystore\nto obtain your debug SHA-1 fingerprint'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _continueAsGuest();
            },
            child: const Text('Use app without sign-in'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _continueAsGuest() async {
    await _auth.signInAsGuest();
    if (!mounted) return;
    context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: FadeTransition(
        opacity: _fade,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const Spacer(flex: 2),
                // App logo
                const AppLogo(size: 96, borderRadius: 26),
                const SizedBox(height: 20),
                Text(
                  'Refundoo',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Track every refund, effortlessly.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textMuted,
                      ),
                ),
                const Spacer(flex: 2),
                // Feature bullets
                ..._features.map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(f.$2, color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(f.$1,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700)),
                              Text(f.$3,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: AppColors.textMuted)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(flex: 3),
                // Google Sign-In button
                _GoogleSignInButton(
                  loading: _loading,
                  onPressed: _loading ? null : _handleSignIn,
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _continueAsGuest,
                  child: Text(
                    'Skip for now',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your data always stays on this device.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted.withValues(alpha: 0.7),
                        fontSize: 11,
                      ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
            ),
          ),
        ),
      ),
    );
  }

  static const _features = [
    ('Auto-detect refunds', Icons.sms_outlined, 'Scans your SMS for refund notices'),
    ('Multi-currency', Icons.currency_exchange, 'Supports ₹, \$, €, £ and more'),
    ('100% private', Icons.shield_outlined, 'All data stays on your device'),
  ];
}

class _GoogleSignInButton extends StatelessWidget {
  const _GoogleSignInButton({required this.loading, required this.onPressed});

  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Material(
        color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : const Color(0xFFE0E0E0),
              ),
            ),
            child: loading
                ? const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.primary,
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Google G logo
                      _GoogleLogo(),
                      const SizedBox(width: 12),
                      Text(
                        'Continue with Google',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF1F1F1F),
                          letterSpacing: 0.1,
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

class _GoogleLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.text});
  final String n;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(n,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    // Clip to circle
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r)));

    // Draw colored quadrants approximately matching the Google logo
    final colors = [
      const Color(0xFF4285F4), // blue
      const Color(0xFF34A853), // green
      const Color(0xFFFBBC05), // yellow
      const Color(0xFFEA4335), // red
    ];
    for (var i = 0; i < 4; i++) {
      final paint = Paint()..color = colors[i];
      final startAngle = (i * 90 - 90) * (3.14159265 / 180.0);
      final sweepAngle = 90 * (3.14159265 / 180.0);
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        startAngle,
        sweepAngle,
        true,
        paint,
      );
    }

    // White inner circle (donut effect) + white rect for the bar
    final whitePaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(cx, cy), r * 0.55, whitePaint);

    // Blue horizontal bar
    canvas.drawRect(
      Rect.fromLTWH(cx, cy - r * 0.18, r, r * 0.36),
      Paint()..color = const Color(0xFF4285F4),
    );

    // Re-draw white inner ring to clean up
    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.50,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.2,
    );
  }

  @override
  bool shouldRepaint(_GoogleLogoPainter oldDelegate) => false;
}
