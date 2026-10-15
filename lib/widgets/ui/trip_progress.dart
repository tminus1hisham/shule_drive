import 'package:flutter/material.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme_extension.dart';

/// Trip completion ("3 of 12 students done") as an animated bar or ring. The
/// fill eases from its previous value whenever [done] changes, instead of
/// jumping, and fills up from empty the first time it appears.
///
/// Set [onBrand] when placing it on a gradient/brand surface.
class TripProgress extends StatelessWidget {
  const TripProgress.bar({
    super.key,
    required this.done,
    required this.total,
    this.color,
    this.onBrand = false,
    this.thickness = 8,
  }) : size = 0,
       center = null,
       _ring = false;

  const TripProgress.ring({
    super.key,
    required this.done,
    required this.total,
    this.color,
    this.onBrand = false,
    this.size = 64,
    this.thickness = 6,
    this.center,
  }) : _ring = true;

  final int done;
  final int total;
  final Color? color;
  final bool onBrand;
  final double thickness;

  /// Ring diameter.
  final double size;

  /// Ring centre. Defaults to the percentage.
  final Widget? center;

  final bool _ring;

  double get fraction => total <= 0 ? 0 : (done / total).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final fill = onBrand ? Colors.white : (color ?? context.colors.brand);
    final track = onBrand
        ? Colors.white.withValues(alpha: 0.22)
        : fill.withValues(alpha: 0.14);

    return Semantics(
      label: '$done of $total done',
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: fraction),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : AppDuration.count,
        curve: AppCurves.easeOut,
        builder: (context, v, _) => _ring
            ? _buildRing(context, v, fill, track)
            : _buildBar(v, fill, track),
      ),
    );
  }

  Widget _buildBar(double v, Color fill, Color track) => ClipRRect(
    borderRadius: AppRadius.brPill,
    child: LinearProgressIndicator(
      value: v,
      minHeight: thickness,
      color: fill,
      backgroundColor: track,
    ),
  );

  Widget _buildRing(BuildContext context, double v, Color fill, Color track) {
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: v,
              strokeWidth: thickness,
              strokeCap: StrokeCap.round,
              color: fill,
              backgroundColor: track,
            ),
          ),
          center ??
              Text(
                '${(v * 100).round()}%',
                style: context.text.titleSmall?.copyWith(
                  color: onBrand ? Colors.white : context.scheme.onSurface,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
        ],
      ),
    );
  }
}
