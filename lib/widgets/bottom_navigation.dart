import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

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
    final isDarkMode = provider.isDarkMode;

    // Background color: green tint in dark mode, white in light mode
    final backgroundColor = isDarkMode 
        ? const Color(0xFF2D4A2A)  // Dark green for dark mode
        : Colors.white;
    
    // Shadow color adjustment for dark mode
    final shadowColor = isDarkMode 
        ? Colors.black.withAlpha(50)
        : Colors.black.withAlpha(13);

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home_rounded, 'Home', 0, isDarkMode),
              _buildNavItem(Icons.chat_bubble_outline_rounded, 'Chat', 1, isDarkMode),
              _buildNavItem(Icons.notifications_none_rounded, 'Alerts', 2, isDarkMode),
              _buildNavItem(Icons.settings_outlined, 'Settings', 3, isDarkMode),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, bool isDarkMode) {
    final isSelected = currentIndex == index;
    
    // Active color: lighter green in dark mode for better contrast
    final activeColor = isDarkMode 
        ? const Color(0xFF90C695)  // Lighter green for dark mode
        : const Color(0xFF6B9B5B); // Base green for light mode
    
    // Inactive color: lighter in dark mode for visibility
    final inactiveColor = isDarkMode 
        ? const Color(0xFF8BA88B)  // Muted light green
        : const Color(0xFF999999); // Grey for light mode

    return GestureDetector(
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected 
              ? activeColor.withValues(alpha: isDarkMode ? 0.15 : 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? activeColor : inactiveColor,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? activeColor : inactiveColor,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
