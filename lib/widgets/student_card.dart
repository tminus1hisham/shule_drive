import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundImage: NetworkImage(student.avatar),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      student.className,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF666666),
                      ),
                    ),
                  ],
                ),
              ),
              if (onCall != null)
                GestureDetector(
                  onTap: onCall,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.phone,
                      color: Color(0xFF6B9B5B),
                      size: 20,
                    ),
                  ),
                ),
            ],
          ),
          if (showActions) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    student.status == StudentStatus.picked ? 'Picked' : 'Pick',
                    student.status == StudentStatus.picked
                        ? const Color(0xFF6B9B5B)
                        : const Color(0xFF6B9B5B),
                    student.status == StudentStatus.picked
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFF6B9B5B),
                    onPick,
                    isOutlined: student.status != StudentStatus.picked,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    'Absent',
                    student.status == StudentStatus.absent
                        ? Colors.white
                        : const Color(0xFFFF9800),
                    student.status == StudentStatus.absent
                        ? const Color(0xFFFF9800)
                        : const Color(0xFFFFF3E0),
                    onAbsent,
                    isOutlined: student.status == StudentStatus.absent,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String text,
    Color textColor,
    Color bgColor,
    VoidCallback? onTap, {
    bool isOutlined = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isOutlined ? Colors.transparent : bgColor,
          borderRadius: BorderRadius.circular(12),
          border: isOutlined ? Border.all(color: bgColor) : null,
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
