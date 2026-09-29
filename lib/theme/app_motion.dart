import 'package:flutter/widgets.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'app_spacing.dart';

/// Shared entrance effects so every screen moves the same way. Built on
/// flutter_animate, tuned with [AppCurves]/[AppDuration], and skipped entirely
/// when the platform asks for reduced motion (flutter_animate doesn't check).
///
/// Widget tests: flutter_animate starts every effect through a (zero-length)
/// timer, so a test must pump through the entrance (`pumpAndSettle()` or
/// `pump(const Duration(seconds: 1))`) before it ends, or it fails with
/// "A Timer is still pending".
///
/// ```dart
/// SectionCard().enter();
/// ListView.builder(itemBuilder: (_, i) => Row(...).enterList(i));
/// Icon(Icons.check).pop();
/// ```
extension AppMotion on Widget {
  /// Fade in while rising [offsetY] px (default 8). For sections and cards
  /// appearing. Use a larger value for panels docked to a screen edge (e.g.
  /// 80 for a bottom sheet-like panel, -40 for a bar dropping in from the top).
  Widget enter({Duration delay = Duration.zero, double offsetY = 8}) =>
      _MotionGate(
        plain: this,
        animated: animate(delay: delay)
            .fadeIn(duration: AppDuration.medium, curve: AppCurves.easeOut)
            .moveY(
              begin: offsetY,
              end: 0,
              duration: AppDuration.slow,
              curve: AppCurves.easeOut,
            ),
      );

  /// [enter] staggered by list position. The delay stops growing after
  /// [AppMotion.maxStaggered] rows so long lists never leave late rows waiting.
  Widget enterList(int index, {Duration baseDelay = Duration.zero}) =>
      enter(delay: baseDelay + staggerStep * index.clamp(0, maxStaggered));

  /// Springy scale-in for icons, badges and success moments. [origin] is the
  /// point it grows from (e.g. a chat bubble's tail corner).
  Widget pop({
    Duration delay = Duration.zero,
    Alignment origin = Alignment.center,
  }) => _MotionGate(
    plain: this,
    animated: animate(delay: delay)
        .fadeIn(duration: AppDuration.fast)
        .scaleXY(
          alignment: origin,
          begin: 0.8,
          end: 1,
          duration: AppDuration.slow,
          curve: Curves.easeOutBack,
        ),
  );

  /// A short horizontal shake for a rejected form. Pass a new [trigger] value
  /// (e.g. an error counter) each time it should play.
  Widget shake(Object trigger) => _MotionGate(
    plain: this,
    animated: animate(
      key: ValueKey(trigger),
    ).shakeX(hz: 5, amount: 6, duration: AppDuration.slow),
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
