import 'package:flutter/material.dart';
import '../../theme/app_theme_extension.dart';

/// A quiet brand-tinted canvas: an emerald → amber wash plus two soft glows.
/// Put it behind a screen's content (`Positioned.fill` in a Stack) so cards
/// and glass panels have something to sit on, without competing with content.
class AppBackdrop extends StatelessWidget {
  const AppBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    final base = context.theme.scaffoldBackgroundColor;

    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.alphaBlend(
                    context.colors.brand.withValues(
                      alpha: context.isDark ? 0.08 : 0.055,
                    ),
                    base,
                  ),
                  base,
                  Color.alphaBlend(
                    context.colors.accent.withValues(
                      alpha: context.isDark ? 0.06 : 0.04,
                    ),
                    base,
                  ),
                ],
                stops: const [0, 0.52, 1],
              ),
            ),
          ),
          Positioned(
            top: 220,
            right: -110,
            child: GlassGlow(
              color: context.colors.brand,
              diameter: 300,
              opacity: context.isDark ? 0.08 : 0.065,
            ),
          ),
          Positioned(
            bottom: 40,
            left: -120,
            child: GlassGlow(
              color: context.colors.accent,
              diameter: 290,
              opacity: context.isDark ? 0.07 : 0.05,
            ),
          ),
        ],
      ),
    );
  }
}

/// A soft radial glow of [color], fading to transparent at its edge.
class GlassGlow extends StatelessWidget {
  const GlassGlow({
    super.key,
    required this.color,
    required this.diameter,
    this.opacity = 0.17,
  });

  final Color color;
  final double diameter;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}
