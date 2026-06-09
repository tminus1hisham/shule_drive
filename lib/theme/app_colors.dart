import 'package:flutter/material.dart';

/// Raw color values for the ShuleDrive design system.
///
/// Do NOT reference these directly inside screens. Instead read colors through
/// the theme so they adapt to light/dark automatically:
///   - `Theme.of(context).colorScheme.*`  (or `context.scheme`)
///   - `context.colors.*`                  (semantic + brand + shadows)
///
/// These constants exist only so the theme builders in [app_theme.dart] and the
/// [AppColors] ThemeExtension have a single source of truth.
class AppPalette {
  AppPalette._();

  // ---- Brand: emerald (modernized from the legacy #6B9B5B) ----
  static const Color emerald = Color(0xFF1FA971);
  static const Color emeraldPressed = Color(0xFF15825A);
  static const Color emeraldBright = Color(0xFF34C98B); // for dark surfaces
  static const Color emeraldSoftLight = Color(0xFFDCF3E8);
  static const Color emeraldSoftDark = Color(0xFF16352A);

  // ---- Accent: school-bus amber ----
  static const Color amber = Color(0xFFF5A623);
  static const Color amberBright = Color(0xFFFBB540); // for dark surfaces
  static const Color amberSoftLight = Color(0xFFFEF1DC);
  static const Color amberSoftDark = Color(0xFF34280F);
  static const Color onAmber = Color(0xFF422C00);

  // ---- Semantic ----
  static const Color success = Color(0xFF22C55E);
  static const Color successBright = Color(0xFF4ADE80);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color errorBright = Color(0xFFF87171);
  static const Color info = Color(0xFF3B82F6);

  // ---- Neutrals: light ----
  static const Color bgLight = Color(0xFFF7F8FA);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceSubtleLight = Color(0xFFF1F3F5);
  static const Color outlineLight = Color(0xFFE5E8EC);
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF64748B);
  static const Color textMutedLight = Color(0xFF94A3B8);

  // ---- Neutrals: dark ----
  static const Color bgDark = Color(0xFF0E1512);
  static const Color surfaceDark = Color(0xFF1A211E);
  static const Color surfaceSubtleDark = Color(0xFF232B27);
  static const Color outlineDark = Color(0xFF2C3530);
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFFB6C2BB);
  static const Color textMutedDark = Color(0xFF7E8C84);

  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
}
