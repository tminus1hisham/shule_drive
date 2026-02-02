import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/student.dart';

class StudentCard extends StatelessWidget {
  final Student student;
  final VoidCallback? onPick;
  final VoidCallback? onAbsent;
  final VoidCallback? onCall;
  final bool showActions;

  const StudentCard({
    super.key,
    required this.student,
    this.onPick,
    this.onAbsent,
    this.onCall,
    this.showActions = true,
  });

  Color get _statusColor {
    switch (student.status) {
      case StudentStatus.picked:
        return const Color(0xFF6B9B5B);
      case StudentStatus.absent:
        return const Color(0xFFFF9800);
      case StudentStatus.pending:
        return const Color(0xFF9E9E9E);
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
        return Icons.check_circle;
      case StudentStatus.absent:
        return Icons.cancel;
      case StudentStatus.pending:
        return Icons.schedule;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Main Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar with Status Ring
                Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _statusColor.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 28,
                        backgroundImage: NetworkImage(student.avatar),
                        backgroundColor: Colors.grey[200],
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: _statusColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Icon(
                          _statusIcon,
                          color: Colors.white,
                          size: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        student.className,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _statusText,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Call Button
                if (onCall != null)
                  GestureDetector(
                    onTap: onCall,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF6B9B5B).withValues(alpha: 0.15),
                            const Color(0xFF6B9B5B).withValues(alpha: 0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
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
            const Divider(height: 1, indent: 16, endIndent: 16),
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
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.cancel_outlined,
                      label: 'Mark Absent',
                      color: const Color(0xFFFF9800),
                      onTap: onAbsent,
                    ),
                  ),
                ],
              ),
            ),
          ] else if (showActions && student.status == StudentStatus.picked) ...[
            const Divider(height: 1, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Color(0xFF6B9B5B),
                            size: 18,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Successfully Picked',
                            style: TextStyle(
                              color: Color(0xFF6B9B5B),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap?.call();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
