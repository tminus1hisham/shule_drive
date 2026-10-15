// Flutter 3.47+ no longer re-exports CupertinoPageTransitionsBuilder from
// material.dart; older SDKs flag this as redundant.
// ignore: unnecessary_import
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_theme_extension.dart';
import 'app_typography.dart';

/// Single source of truth for the app's [ThemeData].
///
/// Replaces the inline `_buildLightTheme` / `_buildDarkTheme` that used to live
/// in main.dart. Screens should pull all visual values from this theme rather
/// than hardcoding colors / sizes.
class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = isDark ? _darkScheme : _lightScheme;
    final appColors = isDark ? AppColors.dark : AppColors.light;
    final bg = isDark ? AppPalette.bgDark : AppPalette.bgLight;
    final textTheme = AppTypography.textTheme(
      isDark ? AppPalette.textPrimaryDark : AppPalette.textPrimaryLight,
      isDark ? AppPalette.textSecondaryDark : AppPalette.textSecondaryLight,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      fontFamily: AppTypography.fontFamily,
      textTheme: textTheme,
      splashFactory: InkRipple.splashFactory,
      extensions: [appColors],

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: scheme.onSurface),
        titleTextStyle: textTheme.titleLarge?.copyWith(fontSize: 18),
      ),

      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.brLg),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.primary.withValues(alpha: 0.45),
          disabledForegroundColor: scheme.onPrimary.withValues(alpha: 0.8),
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 16),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.brMd),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size.fromHeight(52),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 16),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.brMd),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          side: BorderSide(color: appColors.outline, width: 1.5),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 16),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.brMd),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: textTheme.labelLarge,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.brSm),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: appColors.surfaceSubtle,
        hintStyle: textTheme.bodyMedium?.copyWith(color: appColors.textMuted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: const OutlineInputBorder(
          borderRadius: AppRadius.brSm,
          borderSide: BorderSide.none,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppRadius.brSm,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.brSm,
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.brSm,
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.brSm,
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: appColors.surfaceSubtle,
        side: BorderSide.none,
        labelStyle: textTheme.labelMedium,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.brPill),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: scheme.surface,
        showDragHandle: true,
        dragHandleColor: appColors.outline,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.brXl),
        titleTextStyle: textTheme.titleLarge?.copyWith(fontSize: 18),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: appColors.textSecondary,
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark
            ? AppPalette.surfaceSubtleDark
            : AppPalette.textPrimaryLight,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        actionTextColor: appColors.brand,
        insetPadding: const EdgeInsets.all(AppSpacing.md),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.brSm),
      ),

      dividerTheme: DividerThemeData(
        color: appColors.outline,
        thickness: 1,
        space: 1,
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: appColors.surfaceSubtle,
        circularTrackColor: Colors.transparent,
      ),

      listTileTheme: ListTileThemeData(
        iconColor: appColors.textSecondary,
        titleTextStyle: textTheme.titleMedium,
        subtitleTextStyle: textTheme.bodySmall,
      ),

      iconTheme: IconThemeData(color: scheme.onSurface),
      splashColor: scheme.primary.withValues(alpha: 0.08),
      highlightColor: scheme.primary.withValues(alpha: 0.04),
    );
  }

  // ---- Color schemes -------------------------------------------------------

  static const ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppPalette.emerald,
    onPrimary: AppPalette.white,
    primaryContainer: AppPalette.emeraldSoftLight,
    onPrimaryContainer: AppPalette.emeraldPressed,
    secondary: AppPalette.amber,
    onSecondary: AppPalette.onAmber,
    secondaryContainer: AppPalette.amberSoftLight,
    onSecondaryContainer: AppPalette.onAmber,
    tertiary: AppPalette.info,
    onTertiary: AppPalette.white,
    error: AppPalette.error,
    onError: AppPalette.white,
    errorContainer: Color(0xFFFFE2E2),
    onErrorContainer: Color(0xFF7F1D1D),
    surface: AppPalette.surfaceLight,
    onSurface: AppPalette.textPrimaryLight,
    surfaceContainerHighest: AppPalette.surfaceSubtleLight,
    onSurfaceVariant: AppPalette.textSecondaryLight,
    outline: AppPalette.outlineLight,
    outlineVariant: AppPalette.surfaceSubtleLight,
    shadow: AppPalette.ink,
    scrim: AppPalette.ink,
    inverseSurface: AppPalette.textPrimaryLight,
    onInverseSurface: AppPalette.white,
    inversePrimary: AppPalette.emeraldBright,
  );

  static const ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppPalette.emeraldBright,
    onPrimary: Color(0xFF052015),
    primaryContainer: AppPalette.emeraldSoftDark,
    onPrimaryContainer: AppPalette.emeraldBright,
    secondary: AppPalette.amberBright,
    onSecondary: AppPalette.onAmber,
    secondaryContainer: AppPalette.amberSoftDark,
    onSecondaryContainer: AppPalette.amberBright,
    tertiary: AppPalette.infoBright,
    onTertiary: AppPalette.ink,
    error: AppPalette.errorBright,
    onError: Color(0xFF450A0A),
    errorContainer: Color(0xFF5B1717),
    onErrorContainer: Color(0xFFFFD9D9),
    surface: AppPalette.surfaceDark,
    onSurface: AppPalette.textPrimaryDark,
    surfaceContainerHighest: AppPalette.surfaceSubtleDark,
    onSurfaceVariant: AppPalette.textSecondaryDark,
    outline: AppPalette.outlineDark,
    outlineVariant: AppPalette.surfaceSubtleDark,
    shadow: AppPalette.ink,
    scrim: AppPalette.ink,
    inverseSurface: AppPalette.surfaceLight,
    onInverseSurface: AppPalette.textPrimaryLight,
    inversePrimary: AppPalette.emerald,
  );
}
