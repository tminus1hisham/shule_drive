import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme_extension.dart';
import 'press_scale.dart';

/// A theme-aware frosted surface: blur, translucent [tint]-washed gradient and
/// a hairline edge. Use over maps and the [AppBackdrop] where a solid card
/// would feel heavy. Keeps text contrast in both brightness modes.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.tint,
    this.onTap,
    this.borderRadius = AppRadius.brLg,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? tint;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final glassTint = tint ?? context.colors.brand;
    final glassBase = context.isDark
        ? context.scheme.surface.withValues(alpha: 0.70)
        : Colors.white.withValues(alpha: 0.88);
    final glassEnd = Color.alphaBlend(
      glassTint.withValues(alpha: context.isDark ? 0.13 : 0.10),
      context.scheme.surface,
    ).withValues(alpha: context.isDark ? 0.70 : 0.84);
    final edgeColor = context.isDark
        ? Colors.white.withValues(alpha: 0.14)
        : Color.alphaBlend(
            glassTint.withValues(alpha: 0.16),
            context.colors.outline,
          );

    Widget content = Padding(padding: padding, child: child);
    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: content,
        ),
      );
    }

    final panel = Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.24 : 0.07),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: glassTint.withValues(alpha: context.isDark ? 0.08 : 0.06),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [glassBase, glassEnd],
              ),
              borderRadius: borderRadius,
              border: Border.all(color: edgeColor),
            ),
            child: content,
          ),
        ),
      ),
    );

    return onTap == null ? panel : PressScale(scale: 0.985, child: panel);
  }
}
