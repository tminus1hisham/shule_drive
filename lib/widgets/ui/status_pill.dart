import 'package:flutter/material.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme_extension.dart';

/// Small rounded status chip — e.g. "Active", "LIVE", "Picked Up", "Waiting".
/// Tints a soft background from [color] and shows an optional leading dot/icon.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.showDot = true,
    this.pulse = false,
    this.dense = false,
  });

  final String label;
  final Color color;

  /// Optional leading icon. If null and [showDot] is true, a colored dot shows.
  final IconData? icon;
  final bool showDot;

  /// Animate the leading dot (used for "LIVE").
  final bool pulse;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final leading = icon != null
        ? Icon(icon, size: dense ? 12 : 14, color: color)
        : showDot
        ? _Dot(color: color, pulse: pulse)
        : null;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AppSpacing.xs : AppSpacing.sm,
        vertical: dense ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: AppRadius.brPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading, const SizedBox(width: 6)],
          Text(
            label,
            style: context.text.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: dense ? 11 : 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  const _Dot({required this.color, required this.pulse});
  final Color color;
  final bool pulse;

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.pulse) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 900),
      )..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
    );
    if (_controller == null) return dot;
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1).animate(_controller!),
      child: dot,
    );
  }
}
