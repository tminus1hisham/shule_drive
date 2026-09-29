import 'package:flutter/widgets.dart';
import '../../theme/app_spacing.dart';

/// Fades and lifts list item [index] into place as [animation] runs 0 → 1,
/// each item starting a beat after the one above it.
///
/// The per-item delay is capped at [maxStaggered] items, so long lists never
/// leave late rows waiting (or invisible) — everything below the fold simply
/// arrives with the last staggered row.
class StaggeredEntrance extends StatelessWidget {
  const StaggeredEntrance({
    super.key,
    required this.animation,
    required this.index,
    required this.child,
  });

  final Animation<double> animation;
  final int index;
  final Widget child;

  static const double _step = 0.06;
  static const int maxStaggered = 8;

  /// Progress (0–1) of item [index] when the shared animation is at [t].
  static double progress(double t, int index) {
    final delay = index.clamp(0, maxStaggered) * _step;
    return ((t - delay) / (1 - delay)).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = AppCurves.easeOut.transform(progress(animation.value, index));
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - t)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
