import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_logo.dart';
import '../../services/auth_service.dart';
import '../../services/refund_storage_service.dart';
import '../../services/sms_scanner_service.dart';

// ─── Phase state machine ───────────────────────────────────────────────────
enum _Phase { loading, syncing, done }

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  _Phase _phase = _Phase.loading;
  int _newCount = 0;

  // Radar pulse (repeats during sync)
  late final AnimationController _radarCtrl;
  // Check-mark pop (plays once on done)
  late final AnimationController _checkCtrl;
  // Fade for the status text
  late final AnimationController _textCtrl;

  @override
  void initState() {
    super.initState();
    _radarCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _checkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _textCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..value = 1;

    _navigate();
  }

  @override
  void dispose() {
    _radarCtrl.dispose();
    _checkCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _navigate() async {
    // ── Phase 1 : restore session ──────────────────────────────────────────
    final results = await Future.wait([
      AuthService().restoreSession(),
      SharedPreferences.getInstance(),
      Future.delayed(const Duration(milliseconds: 900)),
    ]);
    if (!mounted) return;

    final isSignedIn = results[0] as bool;
    final prefs      = results[1] as SharedPreferences;

    if (!isSignedIn) {
      context.go('/login');
      return;
    }

    final hasSetup = prefs.getBool('has_completed_setup') ?? false;
    if (!hasSetup) {
      context.go('/permissions');
      return;
    }

    // ── Phase 2 : optional SMS scan ───────────────────────────────────────
    final smsExplicitlyDisabled =
        prefs.containsKey('sms_enabled') && !(prefs.getBool('sms_enabled')!);

    if (!smsExplicitlyDisabled && Platform.isAndroid) {
      // Request permission before showing the animation so the OS dialog
      // doesn't pop up mid-radar.
      final scanner = SmsScannerService();
      final granted = await scanner.requestPermission();

      if (granted) {
        // Transition text out, then switch phase
        await _textCtrl.reverse();
        if (!mounted) return;
        setState(() => _phase = _Phase.syncing);
        await _textCtrl.forward();

        try {
          final items = await scanner.scanInbox();
          await Future.delayed(const Duration(milliseconds: 400)); // min visual time
          final count = items.length;
          if (items.isNotEmpty) {
            await RefundStorageService().mergeAndSave(items);
          }
          await prefs.setBool('sms_enabled', true);

          if (!mounted) return;

          // ── Phase 3 : done ─────────────────────────────────────────────
          await _textCtrl.reverse();
          setState(() {
            _phase    = _Phase.done;
            _newCount = count;
          });
          _radarCtrl.stop();
          await _textCtrl.forward();
          await _checkCtrl.forward();
          await Future.delayed(const Duration(milliseconds: 1600));
        } catch (_) {
          // Scan failed — skip to dashboard silently
        }
      }
    }

    if (!mounted) return;
    context.go('/dashboard');
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;

    return Scaffold(
      backgroundColor: bg,
      body: PopScope(
        canPop: false, // lock back button during sync
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),

              // ── Logo ──────────────────────────────────────────────────────
              const AppLogo(size: 96, borderRadius: 26),
              const SizedBox(height: 20),
              Text(
                'Refundoo',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
              ),

              const Spacer(flex: 1),

              // ── Central animation area ─────────────────────────────────────
              SizedBox(
                width: 200,
                height: 200,
                child: _phase == _Phase.done
                    ? _DoneWidget(controller: _checkCtrl, count: _newCount)
                    : _phase == _Phase.syncing
                        ? _RadarWidget(controller: _radarCtrl)
                        : _LoadingSpinner(),
              ),

              const SizedBox(height: 28),

              // ── Status text ───────────────────────────────────────────────
              FadeTransition(
                opacity: _textCtrl,
                child: _StatusText(phase: _phase, count: _newCount),
              ),

              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Loading spinner (phase: loading) ─────────────────────────────────────
class _LoadingSpinner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 40,
        height: 40,
        child: CircularProgressIndicator(
          strokeWidth: 3,
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      ),
    );
  }
}

// ─── Radar rings (phase: syncing) ─────────────────────────────────────────
class _RadarWidget extends StatelessWidget {
  const _RadarWidget({required this.controller});
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) => CustomPaint(
        painter: _RadarPainter(controller.value, AppColors.primary),
        child: Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.12),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.5),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.wifi_tethering_rounded,
              color: AppColors.primary,
              size: 30,
            ),
          ),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter(this.t, this.color);
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    const rings = 3;

    for (var i = 0; i < rings; i++) {
      final phase   = (t + i / rings) % 1.0;
      final radius  = 38 + phase * 62; // expands from 38 to 100
      final opacity = (1 - phase) * 0.55;
      final paint   = Paint()
        ..color      = color.withValues(alpha: opacity)
        ..style      = PaintingStyle.stroke
        ..strokeWidth = 1.8;
      canvas.drawCircle(Offset(cx, cy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.t != t;
}

// ─── Done checkmark (phase: done) ─────────────────────────────────────────
class _DoneWidget extends StatelessWidget {
  const _DoneWidget({required this.controller, required this.count});
  final AnimationController controller;
  final int count;

  @override
  Widget build(BuildContext context) {
    final scale = CurvedAnimation(
      parent: controller,
      curve: Curves.elasticOut,
    );

    return Center(
      child: ScaleTransition(
        scale: scale,
        child: Container(
          width: 96,
          height: 96,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.success,
          ),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 52),
        ),
      ),
    );
  }
}

// ─── Status text ──────────────────────────────────────────────────────────
class _StatusText extends StatelessWidget {
  const _StatusText({required this.phase, required this.count});
  final _Phase phase;
  final int count;

  @override
  Widget build(BuildContext context) {
    final (title, subtitle) = switch (phase) {
      _Phase.loading => ('Loading…', ''),
      _Phase.syncing => ('Scanning messages', 'Looking for new refunds…'),
      _Phase.done    => count > 0
          ? ('Found $count refund${count == 1 ? '' : 's'}!',
             'All data saved on your device')
          : ('All caught up!', 'No new refunds found'),
    };

    return Column(
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: phase == _Phase.done && count > 0
                    ? AppColors.success
                    : Theme.of(context).colorScheme.onSurface,
              ),
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                ),
          ),
        ],
        // Animated dots during syncing
        if (phase == _Phase.syncing) ...[
          const SizedBox(height: 12),
          const _BouncingDots(),
        ],
      ],
    );
  }
}

// ─── Three bouncing dots ───────────────────────────────────────────────────
class _BouncingDots extends StatefulWidget {
  const _BouncingDots();

  @override
  State<_BouncingDots> createState() => _BouncingDotsState();
}

class _BouncingDotsState extends State<_BouncingDots>
    with TickerProviderStateMixin {
  late final List<AnimationController> _ctrls;

  @override
  void initState() {
    super.initState();
    _ctrls = List.generate(3, (i) {
      final c = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500),
      );
      Future.delayed(Duration(milliseconds: i * 130), () {
        if (mounted) c.repeat(reverse: true);
      });
      return c;
    });
  }

  @override
  void dispose() {
    for (final c in _ctrls) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _ctrls[i],
          builder: (_, __) {
            final dy = -6.0 * math.sin(_ctrls[i].value * math.pi);
            return Transform.translate(
              offset: Offset(0, dy),
              child: Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.7),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
