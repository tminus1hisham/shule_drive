import 'package:flutter/material.dart';
import '../../theme/app_spacing.dart';

/// An integer that rolls to its new value instead of jumping, with tabular
/// digits so the width doesn't jitter. Set [countUp] to also roll up from 0
/// the first time it appears (hero stats); leave it off for rows that rebuild
/// often, so they don't re-count on every scroll.
class AnimatedCount extends StatelessWidget {
  const AnimatedCount(
    this.value, {
    super.key,
    this.style,
    this.suffix = '',
    this.countUp = false,
  });

  final int value;
  final TextStyle? style;
  final String suffix;
  final bool countUp;

  @override
  Widget build(BuildContext context) {
    final target = value.toDouble();
    return TweenAnimationBuilder<double>(
      // `begin` only applies on first build; later changes roll from wherever
      // the number currently is.
      tween: Tween(begin: countUp ? 0 : target, end: target),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : AppDuration.count,
      curve: AppCurves.easeOut,
      builder: (context, v, _) => Text(
        '${v.round()}$suffix',
        style: (style ?? const TextStyle()).copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
