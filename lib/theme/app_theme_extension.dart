import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Semantic colors, gradients and shadows that don't fit into Material's
/// [ColorScheme]. Lives on the theme as a [ThemeExtension] so it adapts to
/// light/dark automatically — read it via `context.colors`.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.brand,
    required this.brandSoft,
    required this.onBrandSoft,
    required this.accent,
    required this.accentSoft,
    required this.onAccent,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.surfaceSubtle,
    required this.outline,
    required this.textSecondary,
    required this.textMuted,
    required this.brandGradient,
    required this.accentGradient,
    required this.shadowSm,
    required this.shadowMd,
    required this.shadowLg,
  });

  final Color brand;
  final Color brandSoft;
  final Color onBrandSoft;
  final Color accent;
  final Color accentSoft;
  final Color onAccent;
  final Color success;
  final Color warning;
  final Color error;
  final Color info;
  final Color surfaceSubtle;
  final Color outline;
  final Color textSecondary;
  final Color textMuted;
  final Gradient brandGradient;

  /// School-bus amber, for bus / ETA / live moments. Put dark text on it:
  /// white on amber fails contrast.
  final Gradient accentGradient;
  final List<BoxShadow> shadowSm;
  final List<BoxShadow> shadowMd;
  final List<BoxShadow> shadowLg;

  static const AppColors light = AppColors(
    brand: AppPalette.emerald,
    brandSoft: AppPalette.emeraldSoftLight,
    onBrandSoft: AppPalette.emeraldPressed,
    accent: AppPalette.amber,
    accentSoft: AppPalette.amberSoftLight,
    onAccent: AppPalette.onAmber,
    success: AppPalette.success,
    warning: AppPalette.warning,
    error: AppPalette.error,
    info: AppPalette.info,
    surfaceSubtle: AppPalette.surfaceSubtleLight,
    outline: AppPalette.outlineLight,
    textSecondary: AppPalette.textSecondaryLight,
    textMuted: AppPalette.textMutedLight,
    brandGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [AppPalette.emerald, AppPalette.emeraldDeep],
    ),
    accentGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [AppPalette.amberBright, AppPalette.amber],
    ),
    // Two layers each: a tight contact shadow plus a soft ambient one, both
    // tinted with brand ink rather than pure black.
    shadowSm: [
      BoxShadow(color: Color(0x0F06140E), blurRadius: 2, offset: Offset(0, 1)),
      BoxShadow(color: Color(0x0A06140E), blurRadius: 8, offset: Offset(0, 2)),
    ],
    shadowMd: [
      BoxShadow(color: Color(0x1206140E), blurRadius: 3, offset: Offset(0, 1)),
      BoxShadow(color: Color(0x1406140E), blurRadius: 20, offset: Offset(0, 8)),
    ],
    shadowLg: [
      BoxShadow(color: Color(0x1406140E), blurRadius: 4, offset: Offset(0, 2)),
      BoxShadow(
        color: Color(0x2006140E),
        blurRadius: 36,
        offset: Offset(0, 16),
      ),
    ],
  );

  static const AppColors dark = AppColors(
    brand: AppPalette.emeraldBright,
    brandSoft: AppPalette.emeraldSoftDark,
    onBrandSoft: AppPalette.emeraldBright,
    accent: AppPalette.amberBright,
    accentSoft: AppPalette.amberSoftDark,
    onAccent: AppPalette.amberBright,
    success: AppPalette.successBright,
    warning: AppPalette.warning,
    error: AppPalette.errorBright,
    info: AppPalette.infoBright,
    surfaceSubtle: AppPalette.surfaceSubtleDark,
    outline: AppPalette.outlineDark,
    textSecondary: AppPalette.textSecondaryDark,
    textMuted: AppPalette.textMutedDark,
    brandGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [AppPalette.emerald, AppPalette.emeraldDeep],
    ),
    accentGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [AppPalette.amberBright, AppPalette.amber],
    ),
    shadowSm: [
      BoxShadow(color: Color(0x40000000), blurRadius: 2, offset: Offset(0, 1)),
      BoxShadow(color: Color(0x26000000), blurRadius: 8, offset: Offset(0, 2)),
    ],
    shadowMd: [
      BoxShadow(color: Color(0x4D000000), blurRadius: 3, offset: Offset(0, 1)),
      BoxShadow(color: Color(0x40000000), blurRadius: 20, offset: Offset(0, 8)),
    ],
    shadowLg: [
      BoxShadow(color: Color(0x59000000), blurRadius: 4, offset: Offset(0, 2)),
      BoxShadow(
        color: Color(0x52000000),
        blurRadius: 36,
        offset: Offset(0, 16),
      ),
    ],
  );

  @override
  AppColors copyWith({
    Color? brand,
    Color? brandSoft,
    Color? onBrandSoft,
    Color? accent,
    Color? accentSoft,
    Color? onAccent,
    Color? success,
    Color? warning,
    Color? error,
    Color? info,
    Color? surfaceSubtle,
    Color? outline,
    Color? textSecondary,
    Color? textMuted,
    Gradient? brandGradient,
    Gradient? accentGradient,
    List<BoxShadow>? shadowSm,
    List<BoxShadow>? shadowMd,
    List<BoxShadow>? shadowLg,
  }) {
    return AppColors(
      brand: brand ?? this.brand,
      brandSoft: brandSoft ?? this.brandSoft,
      onBrandSoft: onBrandSoft ?? this.onBrandSoft,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      onAccent: onAccent ?? this.onAccent,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      info: info ?? this.info,
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
      outline: outline ?? this.outline,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      brandGradient: brandGradient ?? this.brandGradient,
      accentGradient: accentGradient ?? this.accentGradient,
      shadowSm: shadowSm ?? this.shadowSm,
      shadowMd: shadowMd ?? this.shadowMd,
      shadowLg: shadowLg ?? this.shadowLg,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      brand: Color.lerp(brand, other.brand, t)!,
      brandSoft: Color.lerp(brandSoft, other.brandSoft, t)!,
      onBrandSoft: Color.lerp(onBrandSoft, other.onBrandSoft, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      info: Color.lerp(info, other.info, t)!,
      surfaceSubtle: Color.lerp(surfaceSubtle, other.surfaceSubtle, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      brandGradient: Gradient.lerp(brandGradient, other.brandGradient, t)!,
      accentGradient: Gradient.lerp(accentGradient, other.accentGradient, t)!,
      shadowSm: BoxShadow.lerpList(shadowSm, other.shadowSm, t)!,
      shadowMd: BoxShadow.lerpList(shadowMd, other.shadowMd, t)!,
      shadowLg: BoxShadow.lerpList(shadowLg, other.shadowLg, t)!,
    );
  }
}

/// Ergonomic theme accessors. Prefer these over `Theme.of(context)` chains.
extension AppThemeContext on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get scheme => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;

  /// Semantic colors / gradients / shadows (see [AppColors]).
  AppColors get colors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.light;

  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
