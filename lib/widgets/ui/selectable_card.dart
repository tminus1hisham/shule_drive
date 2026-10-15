import 'package:flutter/material.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme_extension.dart';
import 'press_scale.dart';

/// A card the user picks one of (a trip, a vehicle, a route). Selecting it
/// animates the brand border, lifts the shadow and pops a check into the radio.
class SelectableCard extends StatelessWidget {
  const SelectableCard({
    super.key,
    required this.selected,
    required this.onTap,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.showRadio = true,
  });

  final bool selected;
  final VoidCallback? onTap;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool showRadio;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : AppDuration.medium;

    return Semantics(
      selected: selected,
      button: true,
      child: PressScale(
        enabled: onTap != null,
        scale: 0.985,
        child: AnimatedContainer(
          duration: duration,
          curve: AppCurves.easeOut,
          decoration: BoxDecoration(
            color: selected
                ? Color.alphaBlend(
                    c.brand.withValues(alpha: 0.06),
                    context.scheme.surface,
                  )
                : context.scheme.surface,
            borderRadius: AppRadius.brLg,
            border: Border.all(
              color: selected ? c.brand : c.outline,
              width: selected ? 2 : 1,
            ),
            boxShadow: selected ? c.shadowMd : c.shadowSm,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: AppRadius.brLg,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: padding,
                child: Row(
                  children: [
                    Expanded(child: child),
                    if (showRadio) ...[
                      const SizedBox(width: AppSpacing.sm),
                      _Radio(selected: selected, duration: duration),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.selected, required this.duration});

  final bool selected;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedContainer(
      duration: duration,
      curve: AppCurves.easeOut,
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? c.brand : Colors.transparent,
        border: Border.all(color: selected ? c.brand : c.outline, width: 2),
      ),
      child: AnimatedScale(
        scale: selected ? 1 : 0,
        duration: duration,
        curve: Curves.easeOutBack,
        child: Icon(
          Icons.check_rounded,
          size: 16,
          color: context.scheme.onPrimary,
        ),
      ),
    );
  }
}
