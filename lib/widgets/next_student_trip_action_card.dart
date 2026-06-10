import 'package:flutter/material.dart';

import '../utils/student_trip_logic.dart';

class NextStudentTripTarget {
  final String id;
  final String name;
  final String status;
  final String? photoUrl;
  final String? destinationLabel;
  final double? latitude;
  final double? longitude;

  const NextStudentTripTarget({
    required this.id,
    required this.name,
    required this.status,
    this.photoUrl,
    this.destinationLabel,
    this.latitude,
    this.longitude,
  });

  bool get hasLocation => hasValidStudentCoordinate(latitude, longitude);
}

class NextStudentTripActionCard extends StatelessWidget {
  final NextStudentTripTarget? student;
  final StudentTripActionMode mode;
  final double? distanceMeters;
  final bool isSubmitting;
  final String? errorMessage;
  final VoidCallback? onPickedUp;
  final VoidCallback? onDroppedOff;
  final VoidCallback? onAbsent;
  final EdgeInsetsGeometry padding;

  const NextStudentTripActionCard({
    super.key,
    required this.student,
    required this.mode,
    this.distanceMeters,
    this.isSubmitting = false,
    this.errorMessage,
    this.onPickedUp,
    this.onDroppedOff,
    this.onAbsent,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final target = student;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: target == null
          ? _buildEmptyState(context)
          : _buildStudentState(context, target),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(Icons.check_circle_outline, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'No pending student actions',
            style: theme.textTheme.titleSmall,
          ),
        ),
      ],
    );
  }

  Widget _buildStudentState(BuildContext context, NextStudentTripTarget target) {
    final theme = Theme.of(context);
    final isPickup = mode == StudentTripActionMode.pickup;
    final statusLabel = _statusLabel(target.status);
    final destination = target.destinationLabel?.trim();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
              backgroundImage: target.photoUrl != null &&
                      target.photoUrl!.isNotEmpty
                  ? NetworkImage(target.photoUrl!)
                  : null,
              child: target.photoUrl == null || target.photoUrl!.isEmpty
                  ? Icon(Icons.person, color: theme.colorScheme.primary)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPickup ? 'Next pickup' : 'Next drop-off',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    target.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    destination == null || destination.isEmpty
                        ? 'Location unavailable'
                        : destination,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _StatusChip(label: statusLabel, status: target.status),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(
              Icons.near_me_outlined,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              _formatDistance(distanceMeters),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        if (errorMessage != null && errorMessage!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            errorMessage!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 14),
        if (isSubmitting)
          const Center(child: CircularProgressIndicator())
        else
          _buildActions(target),
      ],
    );
  }

  Widget _buildActions(NextStudentTripTarget target) {
    final status = target.status;
    final canPick = mode == StudentTripActionMode.pickup && status == 'pending';
    final canDrop = mode == StudentTripActionMode.dropoff && status == 'picked';
    final canMarkAbsent =
        mode == StudentTripActionMode.pickup && status == 'pending';

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          onPressed: canPick ? onPickedUp : null,
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('Picked up'),
        ),
        FilledButton.icon(
          onPressed: canDrop ? onDroppedOff : null,
          icon: const Icon(Icons.home_outlined),
          label: const Text('Dropped off'),
        ),
        OutlinedButton.icon(
          onPressed: canMarkAbsent ? onAbsent : null,
          icon: const Icon(Icons.person_off_outlined),
          label: const Text('Absent'),
        ),
      ],
    );
  }

  String _formatDistance(double? meters) {
    if (meters == null) return 'Distance unavailable';
    if (meters < 1000) return '${meters.round()} m away';
    return '${(meters / 1000).toStringAsFixed(1)} km away';
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'picked':
        return 'Picked';
      case 'dropped':
        return 'Dropped';
      case 'absent':
        return 'Absent';
      default:
        return 'Waiting';
    }
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final String status;

  const _StatusChip({required this.label, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'picked' => Colors.green,
      'dropped' => Colors.blue,
      'absent' => Colors.orange,
      _ => Colors.grey,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

