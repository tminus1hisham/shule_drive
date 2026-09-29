import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_spacing.dart';

/// One side of a [SwipeAction].
class SwipeSpec {
  const SwipeSpec({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTrigger,
  });

  final String label;
  final IconData icon;
  final Color color;

  /// Runs when the swipe passes the threshold. Return true to let the row
  /// slide away (delete), false to spring it back (mark picked/absent).
  final Future<bool> Function() onTrigger;
}

/// Swipe a row right for [start] or left for [end], revealing a coloured
/// action surface behind it. Fires a haptic on trigger.
class SwipeAction extends StatelessWidget {
  const SwipeAction({
    required super.key,
    required this.child,
    this.start,
    this.end,
    this.borderRadius = AppRadius.brLg,
  });

  final Widget child;
  final SwipeSpec? start;
  final SwipeSpec? end;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    if (start == null && end == null) return child;

    final direction = start != null && end != null
        ? DismissDirection.horizontal
        : start != null
        ? DismissDirection.startToEnd
        : DismissDirection.endToStart;

    return Dismissible(
      key: key!,
      direction: direction,
      dismissThresholds: const {
        DismissDirection.startToEnd: 0.3,
        DismissDirection.endToStart: 0.3,
      },
      confirmDismiss: (dir) {
        HapticFeedback.mediumImpact();
        final spec = dir == DismissDirection.startToEnd ? start! : end!;
        return spec.onTrigger();
      },
      background: start == null
          ? const SizedBox.shrink()
          : _Surface(spec: start!, alignStart: true, radius: borderRadius),
      secondaryBackground: end == null
          ? null
          : _Surface(spec: end!, alignStart: false, radius: borderRadius),
      child: child,
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({
    required this.spec,
    required this.alignStart,
    required this.radius,
  });

  final SwipeSpec spec;
  final bool alignStart;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    final content = [
      Icon(spec.icon, color: Colors.white, size: AppIconSize.xl),
      const SizedBox(width: AppSpacing.xs),
      Text(
        spec.label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
    ];
    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: alignStart ? Alignment.centerLeft : Alignment.centerRight,
          end: alignStart ? Alignment.centerRight : Alignment.centerLeft,
          colors: [spec.color, spec.color.withValues(alpha: 0.75)],
        ),
      ),
      alignment: alignStart ? Alignment.centerLeft : Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: alignStart ? content : content.reversed.toList(),
      ),
    );
  }
}
