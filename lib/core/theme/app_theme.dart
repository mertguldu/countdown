import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

// TODO: Revisit every value here once designs are shared.
// The goal is that no screen ever calls Theme.of(context) and gets a surprise.

abstract final class AppTheme {
  static ThemeData light() => _build(
        brightness: Brightness.light,
        primary: AppColors.primary,
        background: AppColors.backgroundLight,
        surface: AppColors.surfaceLight,
        textPrimary: AppColors.textPrimaryLight,
        textSecondary: AppColors.textSecondaryLight,
      );

  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        primary: AppColors.primary,
        background: AppColors.backgroundDark,
        surface: AppColors.surfaceDark,
        textPrimary: AppColors.textPrimaryDark,
        textSecondary: AppColors.textSecondaryDark,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color primary,
    required Color background,
    required Color surface,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
      surface: surface,
      error: AppColors.error,
    ).copyWith(
      // Override generated colours with our explicit palette where needed.
      primary: primary,
      onSurface: textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,

      // ── Typography ────────────────────────────────────────────────────────
      textTheme: TextTheme(
        displayLarge:   AppTextStyles.displayLarge.copyWith(color: textPrimary),
        headlineLarge:  AppTextStyles.headlineLarge.copyWith(color: textPrimary),
        headlineMedium: AppTextStyles.headlineMedium.copyWith(color: textPrimary),
        titleLarge:     AppTextStyles.titleLarge.copyWith(color: textPrimary),
        titleMedium:    AppTextStyles.titleMedium.copyWith(color: textPrimary),
        bodyLarge:      AppTextStyles.bodyLarge.copyWith(color: textPrimary),
        bodyMedium:     AppTextStyles.bodyMedium.copyWith(color: textSecondary),
        labelLarge:     AppTextStyles.labelLarge.copyWith(color: textPrimary),
        labelSmall:     AppTextStyles.labelSmall.copyWith(color: textSecondary),
      ),

      // ── AppBar ────────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTextStyles.titleLarge.copyWith(color: textPrimary),
      ),

      // ── Cards ─────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: EdgeInsets.zero,
      ),

      // ── Bottom sheet ──────────────────────────────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: true,
      ),

      // ── Input fields ──────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      // ── Buttons ───────────────────────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: AppTextStyles.labelLarge,
        ),
      ),

      // ── Divider ───────────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: textSecondary.withValues(alpha: 0.12),
        thickness: 1,
        space: 1,
      ),
    );
  }
}