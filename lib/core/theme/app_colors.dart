import 'package:flutter/material.dart';

// TODO: Replace every value here once designs are shared.
// This file is the single source of truth for all colours in the app.
// Nothing in the codebase should use a raw Color() literal — use these instead.

abstract final class AppColors {
  // ── Brand ──────────────────────────────────────────────────────────────────
  static const primary = Color(0xFF5C6BC0);       // TODO: brand primary
  static const primaryVariant = Color(0xFF3949AB); // TODO: brand primary dark

  // ── Backgrounds ────────────────────────────────────────────────────────────
  static const backgroundLight = Color(0xFFF8F8F8);
  static const backgroundDark  = Color(0xFF121212);

  // ── Surface (cards, sheets, modals) ────────────────────────────────────────
  static const surfaceLight = Color(0xFFFFFFFF);
  static const surfaceDark  = Color(0xFF1E1E1E);

  // ── Text ───────────────────────────────────────────────────────────────────
  static const textPrimaryLight   = Color(0xFF111111);
  static const textSecondaryLight = Color(0xFF666666);
  static const textPrimaryDark    = Color(0xFFF1F1F1);
  static const textSecondaryDark  = Color(0xFF9E9E9E);

  // ── Semantic ───────────────────────────────────────────────────────────────
  static const error   = Color(0xFFE53935);
  static const success = Color(0xFF43A047);
  static const warning = Color(0xFFFFB300);

  // ── Category pill colours ──────────────────────────────────────────────────
  // TODO: update once category system is designed
  static const List<Color> categoryColors = [
    Color(0xFF5C6BC0),
    Color(0xFF26A69A),
    Color(0xFFEF5350),
    Color(0xFFFF7043),
    Color(0xFF8D6E63),
    Color(0xFF78909C),
  ];
}