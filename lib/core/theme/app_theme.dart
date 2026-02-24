import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: AppColors.primary,
        surface: Colors.white,
        onPrimary: AppColors.textPrimary,
        onSurface: AppColors.textPrimary,
        outline: AppColors.textMuted,
      ),
      scaffoldBackgroundColor: AppColors.backgroundLight,
      fontFamily: GoogleFonts.manrope().fontFamily,
      textTheme: _textTheme(Brightness.light),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white.withValues(alpha: 0.8),
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.manrope(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: -0.015 * 18,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceLight,
        elevation: 0,
        shadowColor: const Color(0x0D000000),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.textPrimary,
          foregroundColor: Colors.white,
          elevation: 8,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9999),
          ),
          textStyle: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceLight,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: AppColors.primary,
        surface: const Color(0xFF112121),
        onPrimary: AppColors.textPrimary,
        onSurface: Colors.white,
        outline: AppColors.textMuted,
      ),
      scaffoldBackgroundColor: AppColors.backgroundDark,
      fontFamily: GoogleFonts.manrope().fontFamily,
      textTheme: _textTheme(Brightness.dark),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.backgroundDark.withValues(alpha: 0.8),
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.manrope(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: -0.015 * 18,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white.withValues(alpha: 0.05),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textPrimary,
          elevation: 8,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9999),
          ),
          textStyle: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  static TextTheme _textTheme(Brightness brightness) {
    final base = brightness == Brightness.light
        ? const Color(0xFF111717)
        : Colors.white;
    final muted = brightness == Brightness.light
        ? const Color(0xFF6B7280)
        : const Color(0xFF9CA3AF);
    return TextTheme(
      displayLarge: GoogleFonts.manrope(
        fontSize: 36,
        fontWeight: FontWeight.w800,
        color: base,
        letterSpacing: -0.5,
        height: 1.2,
      ),
      headlineMedium: GoogleFonts.manrope(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: base,
      ),
      titleLarge: GoogleFonts.manrope(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: base,
        letterSpacing: -0.27,
      ),
      titleMedium: GoogleFonts.manrope(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: base,
      ),
      bodyMedium: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: base,
      ),
      bodySmall: GoogleFonts.manrope(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: muted,
      ),
      labelSmall: GoogleFonts.manrope(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: muted,
        letterSpacing: 0.5,
      ),
    );
  }
}
