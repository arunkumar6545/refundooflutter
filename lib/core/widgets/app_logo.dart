import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Displays the Refundoo app logo.
///
/// [size] controls the bounding box – the logo PNG scales to fit.
/// Set [showGlow] to add the ambient teal shadow (nice for dark screens).
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
    final Widget logo = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.asset(
        'assets/images/app_logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
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
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: size * 0.32,
            spreadRadius: size * 0.02,
            offset: Offset(0, size * 0.08),
          ),
        ],
      ),
      child: logo,
    );
  }
}
