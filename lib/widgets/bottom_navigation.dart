import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme_extension.dart';
import 'ui/ui.dart';

/// Floating glass-style bottom navigation. Colors come entirely from the theme
/// so it adapts to light/dark automatically.
class BottomNavigation extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const BottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isDriver = context.watch<AuthProvider>().isDriver;
    final scheme = context.scheme;
    final colors = context.colors;

    // Tab routes fade through each other; flying the bar as a shared hero
    // keeps it planted instead of fading out and back in with the page.
    return Hero(
      tag: 'app-bottom-nav',
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.96),
            borderRadius: AppRadius.brPill,
            border: Border.all(color: colors.outline, width: 1),
            boxShadow: colors.shadowMd,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(context, Icons.home_rounded, 'Home', 0),
              _buildNavItem(
                context,
                Icons.chat_bubble_outline_rounded,
                'Chat',
                1,
                badgeCount: provider.unreadChatCount,
              ),
              // Only show center '+' button for drivers (taps index 4)
              if (isDriver) _buildCenterActionButton(context),
              _buildNavItem(
                context,
                Icons.notifications_none_rounded,
                'Alerts',
                2,
                badgeCount: provider.unreadAlertCount,
              ),
              _buildNavItem(context, Icons.settings_outlined, 'Settings', 3),
            ],
          ),
        ),
      ),
    );
  }

  static const double _iconSizeUnselected = 24;
  static const double _iconSizeSelected = 26;

  Widget _buildNavItem(
    BuildContext context,
    IconData icon,
    String label,
    int index, {
    int badgeCount = 0,
  }) {
    final isSelected = currentIndex == index;
    final activeColor = context.scheme.primary;
    final inactiveColor = context.colors.textMuted;

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (!isSelected) HapticFeedback.selectionClick();
            onTap(index);
          },
          borderRadius: AppRadius.brLg,
          splashColor: activeColor.withValues(alpha: 0.1),
          highlightColor: activeColor.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CountBadge(
                  count: badgeCount,
                  child: AnimatedContainer(
                    duration: AppDuration.fast,
                    padding: EdgeInsets.all(isSelected ? 8 : 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? activeColor.withValues(alpha: 0.15)
                          : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    // Each tab is its own route, so the bar remounts on every
                    // tab change and the newly selected icon springs in.
                    child: isSelected
                        ? Icon(
                            icon,
                            color: activeColor,
                            size: _iconSizeSelected,
                          ).pop()
                        : Icon(
                            icon,
                            color: inactiveColor,
                            size: _iconSizeUnselected,
                          ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  label,
                  style: context.text.labelSmall?.copyWith(
                    color: isSelected ? activeColor : inactiveColor,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static const double _centerButtonSize = 56;

  Widget _buildCenterActionButton(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Start trip',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onTap(4),
          customBorder: const CircleBorder(),
          child: Container(
            width: _centerButtonSize,
            height: _centerButtonSize,
            decoration: BoxDecoration(
              gradient: context.colors.brandGradient,
              borderRadius: AppRadius.brLg,
              boxShadow: [
                BoxShadow(
                  color: context.colors.brand.withValues(alpha: 0.5),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
          ),
        ),
      ),
    );
  }
}
