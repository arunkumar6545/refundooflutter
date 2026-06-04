import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Refundoo app logo — drawn entirely with CustomPainter.
///
/// Design: dark-forest-green → teal gradient rounded square,
/// a bright-teal partial circular arc with a return-arrow tip
/// (symbolising a refund), and a centred white ₹ symbol.
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 88,
    this.showGlow = true,
    this.borderRadius = 22,
  });

  final double size;
  final bool showGlow;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final logo = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _LogoPainter(cornerFraction: borderRadius / size),
      ),
    );

    if (!showGlow) return logo;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.40),
            blurRadius: size * 0.36,
            spreadRadius: size * 0.01,
            offset: Offset(0, size * 0.07),
          ),
        ],
      ),
      child: logo,
    );
  }
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter({required this.cornerFraction});

  final double cornerFraction;

  // Brand colours
  static const _bg1  = Color(0xFF0A3530); // dark forest green
  static const _bg2  = Color(0xFF197A6E); // deep teal
  static const _ring = Color(0xFF4CE6D6); // bright teal arc
  static const _arrowTip = Color(0xFF7AEEE2); // lighter tip highlight

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width  / 2;
    final cy = size.height / 2;
    final r  = math.min(cx, cy);
    final cornerR = r * 2 * cornerFraction;

    // ── Gradient background ──────────────────────────────────────────────────
    final bgRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect  = RRect.fromRectAndRadius(bgRect, Radius.circular(cornerR));

    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
          colors: [_bg1, _bg2],
        ).createShader(bgRect),
    );

    // ── Circular return-arc ──────────────────────────────────────────────────
    //   Arc spans ~285° starting at ~48° (so the gap is at top-right)
    //   leaving an arrowhead to complete the "refund cycle" symbol.
    final ringR  = r * 0.60;
    final ringW  = r * 0.10;
    const startA = 0.27 * math.pi;   // ~48.6°
    const sweepA = 1.59 * math.pi;   // ~286°

    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, cy), width: ringR * 2, height: ringR * 2),
      startA,
      sweepA,
      false,
      Paint()
        ..color      = _ring
        ..style      = PaintingStyle.stroke
        ..strokeWidth = ringW
        ..strokeCap  = StrokeCap.round,
    );

    // ── Arrow-head at the end of the arc ─────────────────────────────────────
    final endAngle = startA + sweepA;
    final ax = cx + ringR * math.cos(endAngle);
    final ay = cy + ringR * math.sin(endAngle);
    // Tangent direction: perpendicular to the radius at end-point
    final tangent   = endAngle + math.pi / 2;
    final headLen   = ringW * 1.7;
    final headWidth = ringW * 0.75;

    final tip = Offset(ax + headLen * math.cos(endAngle),
                       ay + headLen * math.sin(endAngle));
    final left  = Offset(ax + headWidth * math.cos(tangent),
                         ay + headWidth * math.sin(tangent));
    final right = Offset(ax - headWidth * math.cos(tangent),
                         ay - headWidth * math.sin(tangent));

    canvas.drawPath(
      Path()
        ..moveTo(tip.dx,   tip.dy)
        ..lineTo(left.dx,  left.dy)
        ..lineTo(right.dx, right.dy)
        ..close(),
      Paint()..color = _arrowTip..style = PaintingStyle.fill,
    );

    // ── ₹ symbol (Material Icons: currency_rupee) ────────────────────────────
    // Using the icon font ensures the ₹ renders at all sizes on all devices.
    final iconCode = Icons.currency_rupee.codePoint;
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(iconCode),
        style: TextStyle(
          fontFamily: Icons.currency_rupee.fontFamily,
          package:    Icons.currency_rupee.fontPackage,
          fontSize:   r * 0.82,
          color:      Colors.white,
          shadows: [
            Shadow(
              color:      Colors.black.withValues(alpha: 0.28),
              offset:     Offset(r * 0.03, r * 0.045),
              blurRadius: r * 0.07,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Shift slightly upward to visually centre the ₹ within the arc
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2 - r * 0.04));
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.cornerFraction != cornerFraction;
}
