import 'package:flutter/material.dart';

import '../utils/student_trip_logic.dart';

typedef NextStudentTripTargetCallback = void Function(
  NextStudentTripTarget student,
);
typedef NextStudentTripModeResolver = StudentTripActionMode Function(
  NextStudentTripTarget student,
);
typedef NextStudentTripDistanceResolver = double? Function(
  NextStudentTripTarget student,
);

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
  final List<NextStudentTripTarget> students;
  final StudentTripActionMode mode;
  final double? distanceMeters;
  final NextStudentTripModeResolver? modeForStudent;
  final NextStudentTripDistanceResolver? distanceForStudent;
  final bool isSubmitting;
  final String? errorMessage;
  final VoidCallback? onPickedUp;
  final VoidCallback? onDroppedOff;
  final VoidCallback? onAbsent;
  final NextStudentTripTargetCallback? onPickedUpStudent;
  final NextStudentTripTargetCallback? onDroppedOffStudent;
  final NextStudentTripTargetCallback? onAbsentStudent;
  final VoidCallback? onChat;
  final VoidCallback? onStudents;
  final VoidCallback? onNotify;
  final EdgeInsetsGeometry padding;
  final double maxRosterHeight;

  const NextStudentTripActionCard({
    super.key,
    required this.student,
    this.students = const [],
    required this.mode,
    this.distanceMeters,
    this.modeForStudent,
    this.distanceForStudent,
    this.isSubmitting = false,
    this.errorMessage,
    this.onPickedUp,
    this.onDroppedOff,
    this.onAbsent,
    this.onPickedUpStudent,
    this.onDroppedOffStudent,
    this.onAbsentStudent,
    this.onChat,
    this.onStudents,
    this.onNotify,
    this.padding = const EdgeInsets.all(16),
    this.maxRosterHeight = 260,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final target = student;
    final roster = _buildRoster();

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
      child: roster.isEmpty
          ? _buildEmptyState(context)
          : _buildStudentState(context, target, roster),
    );
  }

  List<NextStudentTripTarget> _buildRoster() {
    final byId = <String, NextStudentTripTarget>{};

    for (final item in students) {
      if (item.id.isNotEmpty) byId[item.id] = item;
    }

    final highlighted = student;
    if (highlighted != null && highlighted.id.isNotEmpty) {
      byId.putIfAbsent(highlighted.id, () => highlighted);
    }

    return byId.values.toList();
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(Icons.check_circle_outline, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'No students in this trip',
            style: theme.textTheme.titleSmall,
          ),
        ),
      ],
    );
  }

  Widget _buildStudentState(
    BuildContext context,
    NextStudentTripTarget? target,
    List<NextStudentTripTarget> roster,
  ) {
    final theme = Theme.of(context);
    final pendingCount = roster.where((s) => s.status == 'pending').length;
    final pickedCount = roster.where((s) => s.status == 'picked').length;
    final droppedCount = roster.where((s) => s.status == 'dropped').length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRosterHeader(
          context,
          roster.length,
          pendingCount,
          pickedCount,
          droppedCount,
        ),
        if (_hasTripActions) ...[
          const SizedBox(height: 12),
          _buildTripActions(),
        ],
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
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxRosterHeight),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: roster.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = roster[index];
              return _StudentTripActionRow(
                student: item,
                isHighlighted: target?.id == item.id,
                mode: _modeForTarget(item),
                distanceMeters: _distanceForTarget(item),
                isSubmitting: isSubmitting,
                onPickedUp: _pickActionFor(item),
                onDroppedOff: _dropActionFor(item),
                onAbsent: _absentActionFor(item),
                statusLabel: _statusLabel(item.status),
                formatDistance: _formatDistance,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRosterHeader(
    BuildContext context,
    int total,
    int pending,
    int picked,
    int dropped,
  ) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.groups_outlined, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Trip students',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$total total - $pending waiting - $picked picked - '
                '$dropped dropped',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool get _hasTripActions =>
      onChat != null || onStudents != null || onNotify != null;

  Widget _buildTripActions() {
    return Row(
      children: [
        Expanded(
          child: _TripActionButton(
            icon: Icons.chat_bubble_outline,
            label: 'Chat',
            onPressed: onChat,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _TripActionButton(
            icon: Icons.people_outline,
            label: 'Students',
            onPressed: onStudents,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _TripActionButton(
            icon: Icons.notifications_none,
            label: 'Notify',
            onPressed: onNotify,
          ),
        ),
      ],
    );
  }

  StudentTripActionMode _modeForTarget(NextStudentTripTarget target) {
    final resolver = modeForStudent;
    if (resolver != null) return resolver(target);

    if (student?.id == target.id) return mode;
    return target.status == 'picked'
        ? StudentTripActionMode.dropoff
        : StudentTripActionMode.pickup;
  }

  double? _distanceForTarget(NextStudentTripTarget target) {
    final resolver = distanceForStudent;
    if (resolver != null) return resolver(target);

    return student?.id == target.id ? distanceMeters : null;
  }

  VoidCallback? _pickActionFor(NextStudentTripTarget target) {
    if (onPickedUpStudent != null) {
      return () => onPickedUpStudent!(target);
    }

    return student?.id == target.id ? onPickedUp : null;
  }

  VoidCallback? _dropActionFor(NextStudentTripTarget target) {
    if (onDroppedOffStudent != null) {
      return () => onDroppedOffStudent!(target);
    }

    return student?.id == target.id ? onDroppedOff : null;
  }

  VoidCallback? _absentActionFor(NextStudentTripTarget target) {
    if (onAbsentStudent != null) {
      return () => onAbsentStudent!(target);
    }

    return student?.id == target.id ? onAbsent : null;
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

class _TripActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _TripActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 46,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: theme.colorScheme.primary,
          side: BorderSide(
            color: theme.colorScheme.primary.withValues(alpha: 0.28),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

class _StudentTripActionRow extends StatelessWidget {
  final NextStudentTripTarget student;
  final bool isHighlighted;
  final StudentTripActionMode mode;
  final double? distanceMeters;
  final bool isSubmitting;
  final VoidCallback? onPickedUp;
  final VoidCallback? onDroppedOff;
  final VoidCallback? onAbsent;
  final String statusLabel;
  final String Function(double? meters) formatDistance;

  const _StudentTripActionRow({
    required this.student,
    required this.isHighlighted,
    required this.mode,
    required this.distanceMeters,
    required this.isSubmitting,
    required this.onPickedUp,
    required this.onDroppedOff,
    required this.onAbsent,
    required this.statusLabel,
    required this.formatDistance,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPickup = mode == StudentTripActionMode.pickup;
    final status = student.status;
    final canPick = isPickup && status == 'pending' && !isSubmitting;
    final canDrop =
        mode == StudentTripActionMode.dropoff && status == 'picked' &&
        !isSubmitting;
    final canMarkAbsent = isPickup && status == 'pending' && !isSubmitting;
    final destination = student.destinationLabel?.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isHighlighted
            ? theme.colorScheme.primary.withValues(alpha: 0.08)
            : theme.colorScheme.surfaceVariant.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlighted
              ? theme.colorScheme.primary.withValues(alpha: 0.35)
              : theme.dividerColor.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: theme.colorScheme.primary.withValues(
                  alpha: 0.1,
                ),
                backgroundImage:
                    student.photoUrl != null && student.photoUrl!.isNotEmpty
                    ? NetworkImage(student.photoUrl!)
                    : null,
                child: student.photoUrl == null || student.photoUrl!.isEmpty
                    ? Icon(Icons.person, color: theme.colorScheme.primary)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isHighlighted) ...[
                      Text(
                        isPickup ? 'Next pickup' : 'Next drop-off',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                    Text(
                      student.name,
                      style: theme.textTheme.titleSmall?.copyWith(
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
              _StatusChip(label: statusLabel, status: status),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.near_me_outlined,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                formatDistance(distanceMeters),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
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
          ),
        ],
      ),
    );
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
