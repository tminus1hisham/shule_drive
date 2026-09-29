import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme_extension.dart';
import 'press_scale.dart';

enum AppButtonVariant { primary, secondary, danger, outline, tertiary, onBrand }

enum AppButtonSize { large, medium, small }

/// The single button used across ShuleDrive. Pulls all colors from the theme,
/// supports loading state, leading/trailing icons, and fires light haptics on
/// tap. Replaces the old `CustomButton` and the many inline `ElevatedButton` /
/// `OutlinedButton` styles.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.large,
    this.icon,
    this.iconTrailing = false,
    this.loading = false,
    this.expand = true,
    this.haptic = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? icon;
  final bool iconTrailing;
  final bool loading;

  /// Stretch to the full available width (default true).
  final bool expand;
  final bool haptic;

  double get _height => switch (size) {
    AppButtonSize.large => 52,
    AppButtonSize.medium => 44,
    AppButtonSize.small => 36,
  };

  double get _fontSize => switch (size) {
    AppButtonSize.large => 16,
    AppButtonSize.medium => 15,
    AppButtonSize.small => 13,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final colors = context.colors;
    final enabled = onPressed != null && !loading;

    // Resolve colors per variant.
    final (Color bg, Color fg, BorderSide? side) = switch (variant) {
      AppButtonVariant.primary => (scheme.primary, scheme.onPrimary, null),
      AppButtonVariant.secondary => (
        colors.brandSoft,
        colors.onBrandSoft,
        null,
      ),
      AppButtonVariant.danger => (scheme.error, scheme.onError, null),
      AppButtonVariant.outline => (
        Colors.transparent,
        scheme.onSurface,
        BorderSide(color: colors.outline, width: 1.5),
      ),
      AppButtonVariant.tertiary => (Colors.transparent, scheme.primary, null),
      AppButtonVariant.onBrand => (Colors.white, scheme.primary, null),
    };

    final style = ButtonStyle(
      // Disabled buttons fade instead of looking identical to enabled ones.
      backgroundColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.disabled) && !loading
            ? bg.withValues(alpha: bg.a * 0.4)
            : bg,
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.disabled) && !loading
            ? fg.withValues(alpha: 0.55)
            : fg,
      ),
      overlayColor: WidgetStatePropertyAll(
        (variant == AppButtonVariant.outline ||
                variant == AppButtonVariant.tertiary ||
                variant == AppButtonVariant.onBrand)
            ? scheme.primary.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.12),
      ),
      elevation: const WidgetStatePropertyAll(0),
      shadowColor: const WidgetStatePropertyAll(Colors.transparent),
      side: side == null ? null : WidgetStatePropertyAll(side),
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      ),
      shape: const WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: AppRadius.brMd),
      ),
      minimumSize: WidgetStatePropertyAll(Size(0, _height)),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    final child = loading
        ? SizedBox(
            height: _fontSize + 4,
            width: _fontSize + 4,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(fg),
            ),
          )
        : _Content(
            label: label,
            icon: icon,
            iconTrailing: iconTrailing,
            fontSize: _fontSize,
          );

    final button = TextButton(
      onPressed: enabled
          ? () {
              if (haptic) HapticFeedback.lightImpact();
              onPressed!();
            }
          : null,
      style: style,
      child: child,
    );

    return PressScale(
      enabled: enabled,
      child: SizedBox(
        width: expand ? double.infinity : null,
        height: _height,
        child: button,
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.label,
    required this.icon,
    required this.iconTrailing,
    required this.fontSize,
  });

  final String label;
  final IconData? icon;
  final bool iconTrailing;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final textWidget = Text(
      label,
      style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600),
    );
    if (icon == null) return textWidget;

    final iconWidget = Icon(icon, size: fontSize + 4);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: iconTrailing
          ? [textWidget, const SizedBox(width: AppSpacing.xs), iconWidget]
          : [iconWidget, const SizedBox(width: AppSpacing.xs), textWidget],
    );
  }
}
