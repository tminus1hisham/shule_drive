import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme_extension.dart';

/// Row that lets a driver turn "Autoload" on or off.
///
/// When on, scheduled trips are fetched on login and the driver is taken
/// straight to trip selection. When off, they stay on the dashboard and open
/// their scheduled trips themselves.
class AutoloadTripsToggle extends StatelessWidget {
  const AutoloadTripsToggle({super.key, this.padding});

  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final enabled = provider.autoloadTrips;
    final brand = context.colors.brand;

    return Padding(
      padding:
          padding ??
          const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
      child: Row(
        children: [
          Icon(
            enabled ? Icons.bolt_rounded : Icons.bolt_outlined,
            color: enabled ? brand : context.colors.textSecondary,
            size: 24,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Autoload', style: context.text.titleMedium),
                Text(
                  enabled
                      ? 'Scheduled trips open on login'
                      : 'Open scheduled trips manually',
                  style: context.text.bodySmall?.copyWith(
                    color: context.colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            onChanged: (value) => provider.setAutoloadTrips(value),
          ),
        ],
      ),
    );
  }
}
