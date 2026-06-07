import 'package:flutter/material.dart';

// Fraunces is declared in pubspec.yaml and used exclusively for large
// countdown number displays (FrauncesNumber widget).
// Body, label and UI text uses the platform default (SF Pro / Roboto).

abstract final class AppTextStyles {
  // ── Fraunces — countdown number display ────────────────────────────────────
  // Usage: FrauncesNumber widget only.

  static const frauncesHero = TextStyle(
    fontFamily: 'Fraunces',
    fontSize: 80,
    fontWeight: FontWeight.w300, // Light — feels elegant at large sizes
    height: 1.0,
    letterSpacing: -2.0,
  );

  static const frauncesLarge = TextStyle(
    fontFamily: 'Fraunces',
    fontSize: 56,
    fontWeight: FontWeight.w300,
    height: 1.0,
    letterSpacing: -1.5,
  );

  static const frauncesMedium = TextStyle(
    fontFamily: 'Fraunces',
    fontSize: 36,
    fontWeight: FontWeight.w400,
    height: 1.1,
    letterSpacing: -0.5,
  );

  // ── System font — UI & content ─────────────────────────────────────────────
  // These mirror Material 3 type roles. ThemeData maps them automatically;
  // use Theme.of(context).textTheme in widgets rather than these directly
  // unless you need to override a specific style.

  static const displayLarge = TextStyle(
    fontSize: 57,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.25,
  );

  static const headlineLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );

  static const headlineMedium = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );

  static const titleLarge = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
  );

  static const titleMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.15,
  );

  static const bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.5,
  );

  static const bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.25,
  );

  static const labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
  );

  static const labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
  );
}