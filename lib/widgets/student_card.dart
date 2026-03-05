import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/student.dart';

/// Modern Student Card with enhanced styling and status indications
/// 
/// Features:
/// - Premium avatar with status ring
/// - Animated status badge
/// - Action buttons with haptic feedback
/// - Modern shadows and gradients
class StudentCard extends StatelessWidget {
  final Student student;
  final VoidCallback? onPick;
  final VoidCallback? onAbsent;
  final VoidCallback? onCall;
  final VoidCallback? onTap;
  final bool showActions;
  final bool isDarkMode;

  const StudentCard({
    super.key,
    required this.student,
    this.onPick,
    this.onAbsent,
    this.onCall,
    this.onTap,
    this.showActions = true,
    this.isDarkMode = false,
  });

  Color get _statusColor {
    switch (student.status) {
      case StudentStatus.picked:
        return const Color(0xFF6B9B5B);
      case StudentStatus.absent:
        return const Color(0xFFFF9800);
      case StudentStatus.pending:
        return const Color(0xFF607D8B);
    }
  }

  Color get _statusLightColor {
    switch (student.status) {
      case StudentStatus.picked:
        return const Color(0xFFE8F5E9);
      case StudentStatus.absent:
        return const Color(0xFFFFF3E0);
      case StudentStatus.pending:
        return const Color(0xFFECEFF1);
    }
  }

  String get _statusText {
    switch (student.status) {
      case StudentStatus.picked:
        return 'Picked Up';
      case StudentStatus.absent:
        return 'Absent';
      case StudentStatus.pending:
        return 'Pending';
    }
  }

  IconData get _statusIcon {
    switch (student.status) {
      case StudentStatus.picked:
        return Icons.check_circle_rounded;
      case StudentStatus.absent:
        return Icons.cancel_rounded;
      case StudentStatus.pending:
        return Icons.schedule_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.08 * 255)
                : _statusColor.withValues(alpha: 0.1 * 255),
            width: 1.5,
          ),
          boxShadow: isDarkMode
              ? null
              : [
                  BoxShadow(
                    color: _statusColor.withValues(alpha: 0.04 * 255),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02 * 255),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              // Main Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Avatar with Status Ring
                    _buildAvatar(),
                    const SizedBox(width: 16),

                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(height: 6),
                          
                          // Status Badge
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: _statusColor.withValues(
                                alpha: isDarkMode ? 0.15 * 255 : 0.1 * 255,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _statusColor.withValues(alpha: 0.2 * 255),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _statusIcon,
                                  size: 12,
                                  color: _statusColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _statusText,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _statusColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Call Button
                    if (onCall != null)
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          onCall?.call();
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFF6B9B5B).withValues(alpha: 0.15 * 255),
                                const Color(0xFF6B9B5B).withValues(alpha: 0.05 * 255),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFF6B9B5B).withValues(alpha: 0.2 * 255),
                            ),
                          ),
                          child: const Icon(
                            Icons.phone_outlined,
                            color: Color(0xFF6B9B5B),
                            size: 20,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Action Buttons
              if (showActions && student.status != StudentStatus.picked) ...[
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.08 * 255)
                      : Colors.grey.shade200,
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.check_circle_outline,
                          label: 'Pick Up',
                          color: const Color(0xFF6B9B5B),
                          onTap: onPick,
                          isPrimary: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.cancel_outlined,
                          label: 'Mark Absent',
                          color: const Color(0xFFFF9800),
                          onTap: onAbsent,
                          isPrimary: false,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (showActions && student.status == StudentStatus.picked) ...[
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.08 * 255)
                      : Colors.grey.shade200,
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF6B9B5B).withValues(alpha: 0.1 * 255),
                          const Color(0xFF6B9B5B).withValues(alpha: 0.05 * 255),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFF6B9B5B).withValues(alpha: 0.2 * 255),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6B9B5B).withValues(alpha: 0.2 * 255),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_circle,
                            color: Color(0xFF6B9B5B),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Successfully Picked',
                          style: TextStyle(
                            color: Color(0xFF6B9B5B),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _statusColor.withValues(alpha: 0.3 * 255),
                _statusColor.withValues(alpha: 0.1 * 255),
              ],
            ),
          ),
          child: _buildAvatarContent(),
        ),
        // Status indicator
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: _statusColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: _statusColor.withValues(alpha: 0.4 * 255),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarContent() {
    final avatarUrl = student.avatar;
    
    // Check if it's a valid network URL
    if (avatarUrl.isNotEmpty &&
        (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://'))) {
      return CircleAvatar(
        radius: 26,
        backgroundImage: NetworkImage(avatarUrl),
        backgroundColor: _statusColor.withValues(alpha: 0.1 * 255),
        onBackgroundImageError: (e, s) {
          if (kDebugMode) print('⚠️ Failed to load avatar: $e');
        },
      );
    }

    // Fallback to default avatar with initials
    return CircleAvatar(
      radius: 26,
      backgroundColor: _statusColor.withValues(alpha: 0.1 * 255),
      child: Text(
        _getInitials(student.name),
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: _statusColor,
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
    required bool isPrimary,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap?.call();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: isPrimary
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: 0.15 * 255),
                    color.withValues(alpha: 0.05 * 255),
                  ],
                )
              : null,
          color: isPrimary ? null : color.withValues(alpha: 0.08 * 255),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color.withValues(alpha: 0.25 * 255),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}
