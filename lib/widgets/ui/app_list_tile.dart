import 'package:flutter/material.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme_extension.dart';
import 'press_scale.dart';

/// A settings/menu row: tinted icon tile, title, optional subtitle and a
/// trailing chevron (or custom [trailing]). Presses give a physical push.
/// Place several inside an [AppCard] with `padding: EdgeInsets.zero`.
class AppListTile extends StatelessWidget {
  const AppListTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.iconColor,
    this.trailing,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Color? iconColor;

  /// Replaces the default chevron. Pass `SizedBox.shrink()` for none.
  final Widget? trailing;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tint = destructive ? c.error : (iconColor ?? c.brand);

    return PressScale(
      enabled: onTap != null,
      scale: 0.98,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.brMd,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          tint.withValues(alpha: 0.20),
                          tint.withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: AppRadius.brSm,
                    ),
                    child: Icon(icon, color: tint, size: AppIconSize.md),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: context.text.titleSmall?.copyWith(
                            color: destructive ? c.error : null,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: context.text.bodySmall?.copyWith(
                              color: c.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  trailing ??
                      Icon(
                        Icons.chevron_right_rounded,
                        color: c.textMuted,
                        size: AppIconSize.lg,
                      ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
