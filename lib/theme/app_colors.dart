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
  // Deep enough that white labels pass WCAG AA (4.9:1); the old #1FA971 was 3:1.
  static const Color emerald = Color(0xFF138057);
  static const Color emeraldPressed = Color(0xFF0F6B49);
  static const Color emeraldDeep = Color(0xFF0C5A3D); // gradient end
  static const Color emeraldBright = Color(0xFF34C98B); // for dark surfaces
  static const Color emeraldSoftLight = Color(0xFFDDF1E7);
  static const Color emeraldSoftDark = Color(0xFF123427);

  // ---- Accent: school-bus amber ----
  static const Color amber = Color(0xFFF5A623);
  static const Color amberBright = Color(0xFFFBB540); // for dark surfaces
  static const Color amberSoftLight = Color(0xFFFEF1DC);
  static const Color amberSoftDark = Color(0xFF34280F);
  static const Color onAmber = Color(0xFF422C00);

  // ---- Semantic ----
  static const Color success = Color(0xFF16A34A);
  static const Color successBright = Color(0xFF4ADE80);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFDC2626);
  static const Color errorBright = Color(0xFFF87171);
  static const Color info = Color(0xFF2563EB);
  static const Color infoBright = Color(0xFF60A5FA);

  // ---- Neutrals ----
  // One green-tinted neutral family for both modes, so greys never drift
  // between cool slate (light) and warm green (dark).
  static const Color bgLight = Color(0xFFF4F6F5);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceSubtleLight = Color(0xFFEDF1EF);
  static const Color outlineLight = Color(0xFFDFE5E2);
  static const Color textPrimaryLight = Color(0xFF0E1813);
  static const Color textSecondaryLight = Color(0xFF52615A);
  static const Color textMutedLight = Color(0xFF6B7A73);

  static const Color bgDark = Color(0xFF0B110E);
  static const Color surfaceDark = Color(0xFF141C18);
  static const Color surfaceSubtleDark = Color(0xFF1D2722);
  static const Color outlineDark = Color(0xFF28332D);
  static const Color textPrimaryDark = Color(0xFFEEF4F1);
  static const Color textSecondaryDark = Color(0xFFA9B7B0);
  static const Color textMutedDark = Color(0xFF83928B);

  /// Tint for shadows and scrims: brand-hued near-black instead of pure black.
  static const Color ink = Color(0xFF06140E);

  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
}
