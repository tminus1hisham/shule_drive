import 'package:flutter/material.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme_extension.dart';
import 'press_scale.dart';

/// The branded gradient "hero" surface used for primary calls-to-action and the
/// live-trip card. Renders the brand gradient with soft decorative circles and
/// an elevated colored shadow. Optionally tappable.
class GradientHeroCard extends StatelessWidget {
  const GradientHeroCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
    this.onTap,
    this.borderRadius = AppRadius.brXl,
    this.decorate = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;

  /// Show the decorative translucent circles.
  final bool decorate;

  @override
  Widget build(BuildContext context) {
    final gradient = context.colors.brandGradient;

    Widget content = DecoratedBox(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: borderRadius,
        // A 1px light top edge reads as a physical surface; the brand-tinted
        // shadow stays soft rather than glowing.
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
        ),
        boxShadow: [
          BoxShadow(
            color: context.colors.brand.withValues(alpha: 0.18),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: context.colors.brand.withValues(alpha: 0.22),
            blurRadius: 32,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          children: [
            if (decorate) ...[
              Positioned(
                right: -40,
                top: -40,
                child: _circle(150, Colors.white.withValues(alpha: 0.08)),
              ),
              Positioned(
                left: -20,
                bottom: -20,
                child: _circle(100, Colors.white.withValues(alpha: 0.06)),
              ),
            ],
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );

    if (onTap != null) {
      content = PressScale(
        scale: 0.985,
        child: Material(
          color: Colors.transparent,
          borderRadius: borderRadius,
          child: InkWell(
            onTap: onTap,
            borderRadius: borderRadius,
            child: content,
          ),
        ),
      );
    }
    return content;
  }

  Widget _circle(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}
