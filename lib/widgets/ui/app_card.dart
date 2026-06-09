import 'package:flutter/material.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme_extension.dart';

/// Standard surface card: themed background, soft shadow, large radius and
/// consistent padding. Optionally tappable. Replaces the dozens of inline
/// `Container(decoration: BoxDecoration(...))` cards across the app.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.onTap,
    this.color,
    this.borderRadius = AppRadius.brLg,
    this.border,
    this.shadow,
    this.clip = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final BorderRadius borderRadius;
  final Border? border;

  /// Override the default soft shadow; pass `[]` for a flat card.
  final List<BoxShadow>? shadow;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: color ?? context.scheme.surface,
      borderRadius: borderRadius,
      border: border,
      boxShadow: shadow ?? context.colors.shadowSm,
    );

    final content = Padding(padding: padding, child: child);

    if (onTap == null) {
      return Container(
        decoration: decoration,
        clipBehavior: clip ? Clip.antiAlias : Clip.none,
        child: content,
      );
    }

    return Material(
      color: color ?? context.scheme.surface,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          border: border,
          boxShadow: shadow ?? context.colors.shadowSm,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: content,
        ),
      ),
    );
  }
}
