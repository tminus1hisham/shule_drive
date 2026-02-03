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

    // Modern glassmorphism background
    final backgroundColor = isDarkMode 
        ? const Color(0xFF1E2D1C).withValues(alpha: 0.95)
        : Colors.white.withValues(alpha: 0.95);
    
    // Border color for glass effect
    final borderColor = isDarkMode 
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.05);

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: borderColor,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isDarkMode 
                  ? Colors.black.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(Icons.home_rounded, 'Home', 0, isDarkMode),
            _buildNavItem(Icons.chat_bubble_outline_rounded, 'Chat', 1, isDarkMode),
            _buildCenterActionButton(isDarkMode),
            _buildNavItem(Icons.notifications_none_rounded, 'Alerts', 2, isDarkMode),
            _buildNavItem(Icons.settings_outlined, 'Settings', 3, isDarkMode),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, bool isDarkMode) {
    final isSelected = currentIndex == index;
    
    // Active color
    final activeColor = isDarkMode 
        ? const Color(0xFF90C695)
        : const Color(0xFF6B9B5B);
    
    // Inactive color
    final inactiveColor = isDarkMode 
        ? const Color(0xFF6B8B6B)
        : const Color(0xFF9CA3AF);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onTap(index),
        borderRadius: BorderRadius.circular(20),
        splashColor: activeColor.withValues(alpha: 0.1),
        highlightColor: activeColor.withValues(alpha: 0.05),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: isSelected 
                      ? const EdgeInsets.all(6)
                      : const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? activeColor.withValues(alpha: isDarkMode ? 0.25 : 0.15)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: isSelected ? activeColor : inactiveColor,
                    size: isSelected ? 22 : 20,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? activeColor : inactiveColor,
                    fontSize: isSelected ? 11 : 10,
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

  Widget _buildCenterActionButton(bool isDarkMode) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onTap(4),
        customBorder: const CircleBorder(),
        splashColor: Colors.white.withValues(alpha: 0.3),
        highlightColor: Colors.white.withValues(alpha: 0.1),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF6B9B5B),
                Color(0xFF5A8A4A),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6B9B5B).withValues(alpha: 0.5),
                blurRadius: 12,
                offset: const Offset(0, 6),
                spreadRadius: 0,
              ),
            ],
          ),
          child: const Icon(
            Icons.add_rounded,
            color: Colors.white,
            size: 32,
          ),
        ),
      ),
    );
  }
}
