import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppColors {
  static const primary = Color(0xFF0F766E);
  static const background = Color(0xFFF3F6F5);
  static const surface = Color(0xFFFFFFFF);
  static const text = Color(0xFF14211F);
  static const muted = Color(0xFF4B5F5A);
  static const divider = Color(0xFFDCE5E2);
}

abstract final class AppTheme {
  static final light = _buildLightTheme();

  static ThemeData _buildLightTheme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      primary: AppColors.primary,
      surface: AppColors.surface,
      error: const Color(0xFFB91C1C),
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      textTheme: _withBengaliFallback(
        GoogleFonts.plusJakartaSansTextTheme(
          base.textTheme,
        ).apply(bodyColor: AppColors.text, displayColor: AppColors.text),
      ),
      dividerColor: AppColors.divider,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDC2626)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.65),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ).copyWith(fontFamilyFallback: const ['Noto Sans Bengali']),
        ),
      ),
    );
  }

  static TextTheme _withBengaliFallback(TextTheme theme) => TextTheme(
    displayLarge: _fallback(theme.displayLarge),
    displayMedium: _fallback(theme.displayMedium),
    displaySmall: _fallback(theme.displaySmall),
    headlineLarge: _fallback(theme.headlineLarge),
    headlineMedium: _fallback(theme.headlineMedium),
    headlineSmall: _fallback(theme.headlineSmall),
    titleLarge: _fallback(theme.titleLarge),
    titleMedium: _fallback(theme.titleMedium),
    titleSmall: _fallback(theme.titleSmall),
    bodyLarge: _fallback(theme.bodyLarge),
    bodyMedium: _fallback(theme.bodyMedium),
    bodySmall: _fallback(theme.bodySmall),
    labelLarge: _fallback(theme.labelLarge),
    labelMedium: _fallback(theme.labelMedium),
    labelSmall: _fallback(theme.labelSmall),
  );

  static TextStyle? _fallback(TextStyle? style) =>
      style?.copyWith(fontFamilyFallback: const ['Noto Sans Bengali']);
}
