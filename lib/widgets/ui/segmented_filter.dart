import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme_extension.dart';
import 'animated_count.dart';

/// One option in a [SegmentedFilter].
class FilterSegment {
  const FilterSegment(this.label, {this.count});

  final String label;

  /// Optional count shown after the label; rolls when it changes.
  final int? count;
}

/// A pill-shaped filter bar whose brand-coloured thumb slides to the selected
/// segment. Counts roll as the underlying data changes.
class SegmentedFilter extends StatelessWidget {
  const SegmentedFilter({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final List<FilterSegment> segments;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : AppDuration.medium;
    final n = segments.length;
    // -1 … 1 across the bar, for AnimatedAlign.
    final x = n == 1 ? 0.0 : -1 + 2 * selected / (n - 1);

    return Container(
      height: 48,
      padding: const EdgeInsets.all(AppSpacing.xxs),
      decoration: BoxDecoration(
        color: c.surfaceSubtle,
        borderRadius: AppRadius.brMd,
        border: Border.all(color: c.outline),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            alignment: Alignment(x, 0),
            duration: duration,
            curve: AppCurves.easeOut,
            child: FractionallySizedBox(
              widthFactor: 1 / n,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: c.brandGradient,
                  borderRadius: AppRadius.brSm,
                  boxShadow: [
                    BoxShadow(
                      color: c.brand.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < n; i++)
                Expanded(
                  child: _Segment(
                    segment: segments[i],
                    selected: i == selected,
                    duration: duration,
                    onTap: () {
                      if (i == selected) return;
                      HapticFeedback.selectionClick();
                      onChanged(i);
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.segment,
    required this.selected,
    required this.duration,
    required this.onTap,
  });

  final FilterSegment segment;
  final bool selected;
  final Duration duration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : context.colors.textSecondary;
    final style = context.text.labelLarge?.copyWith(
      color: fg,
      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      fontSize: 13,
    );

    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: duration,
            style: style ?? const TextStyle(),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(segment.label),
                  if (segment.count != null) ...[
                    const SizedBox(width: 6),
                    AnimatedContainer(
                      duration: duration,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.white.withValues(alpha: 0.25)
                            : context.colors.outline,
                        borderRadius: AppRadius.brPill,
                      ),
                      child: AnimatedCount(
                        segment.count!,
                        style: style?.copyWith(fontSize: 11),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
