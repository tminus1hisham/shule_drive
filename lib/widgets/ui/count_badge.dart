import 'package:flutter/material.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme_extension.dart';

/// Pins an unread-style count to the top-right of [child]. The badge springs
/// in when [count] becomes positive, re-pops whenever the number changes, and
/// shrinks away at zero. [dot] shows a plain dot instead of the number.
class CountBadge extends StatelessWidget {
  const CountBadge({
    super.key,
    required this.count,
    required this.child,
    this.dot = false,
    this.offset = const Offset(-2, -2),
  });

  final int count;
  final Widget child;
  final bool dot;

  /// Distance from the child's top-right corner (negative = outside).
  final Offset offset;

  @override
  Widget build(BuildContext context) {
    final show = count > 0;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final border = Border.all(color: context.scheme.surface, width: 1.5);

    final badge = dot
        ? Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: context.colors.error,
              shape: BoxShape.circle,
              border: border,
            ),
          )
        : Container(
            key: ValueKey(count),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            constraints: const BoxConstraints(minWidth: 18),
            decoration: BoxDecoration(
              color: context.colors.error,
              borderRadius: AppRadius.brPill,
              border: border,
            ),
            child: Text(
              count > 9 ? '9+' : '$count',
              textAlign: TextAlign.center,
              style: context.text.labelSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 10,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: offset.dy,
          right: offset.dx,
          child: Semantics(
            label: show ? '$count unread' : null,
            child: AnimatedScale(
              scale: show ? 1 : 0,
              duration: reduce ? Duration.zero : AppDuration.medium,
              curve: show ? Curves.easeOutBack : AppCurves.easeOut,
              child: AnimatedSwitcher(
                duration: reduce ? Duration.zero : AppDuration.medium,
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: CurvedAnimation(
                    parent: anim,
                    curve: Curves.easeOutBack,
                  ),
                  child: child,
                ),
                child: badge,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
