import 'package:flutter/widgets.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'app_spacing.dart';

/// Shared entrance effects so every screen moves the same way. Built on
/// flutter_animate, tuned with [AppCurves]/[AppDuration], and skipped entirely
/// when the platform asks for reduced motion (flutter_animate doesn't check).
///
/// ```dart
/// SectionCard().enter();
/// ListView.builder(itemBuilder: (_, i) => Row(...).enterList(i));
/// Icon(Icons.check).pop();
/// ```
extension AppMotion on Widget {
  /// Fade in while rising 8px. For sections and cards appearing.
  Widget enter({Duration delay = Duration.zero}) => _MotionGate(
    plain: this,
    animated: animate(delay: delay)
        .fadeIn(duration: AppDuration.medium, curve: AppCurves.easeOut)
        .moveY(
          begin: 8,
          end: 0,
          duration: AppDuration.slow,
          curve: AppCurves.easeOut,
        ),
  );

  /// [enter] staggered by list position. The delay stops growing after
  /// [AppMotion.maxStaggered] rows so long lists never leave late rows waiting.
  Widget enterList(int index, {Duration baseDelay = Duration.zero}) =>
      enter(delay: baseDelay + staggerStep * index.clamp(0, maxStaggered));

  /// Springy scale-in for icons, badges and success moments.
  Widget pop({Duration delay = Duration.zero}) => _MotionGate(
    plain: this,
    animated: animate(delay: delay)
        .fadeIn(duration: AppDuration.fast)
        .scaleXY(
          begin: 0.8,
          end: 1,
          duration: AppDuration.slow,
          curve: Curves.easeOutBack,
        ),
  );

  /// A single light sweep across the widget, for "done!" moments.
  Widget celebrate({Duration delay = const Duration(milliseconds: 300)}) =>
      _MotionGate(
        plain: this,
        animated: animate(delay: delay).shimmer(
          duration: const Duration(milliseconds: 900),
          color: const Color(0x66FFFFFF),
        ),
      );

  static const Duration staggerStep = Duration(milliseconds: 50);
  static const int maxStaggered = 8;
}

class _MotionGate extends StatelessWidget {
  const _MotionGate({required this.plain, required this.animated});

  final Widget plain;
  final Widget animated;

  @override
  Widget build(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context) ? plain : animated;
}
