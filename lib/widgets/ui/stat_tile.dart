import 'package:flutter/material.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme_extension.dart';

/// Compact metric display: icon, value and label stacked vertically. Used for
/// the live trip stats (ETA / Speed / Distance) and dashboard counters.
///
/// Set [onLight] to true when placing on a colored/gradient surface so text
/// renders white.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.onLight = false,
    this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final bool onLight;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fg = onLight ? Colors.white : (color ?? context.scheme.onSurface);
    final muted = onLight
        ? Colors.white.withValues(alpha: 0.8)
        : context.colors.textSecondary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: onLight ? Colors.white70 : (color ?? fg), size: 20),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          value,
          style: context.text.titleMedium?.copyWith(
            color: fg,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: context.text.labelSmall?.copyWith(color: muted),
        ),
      ],
    );
  }
}
