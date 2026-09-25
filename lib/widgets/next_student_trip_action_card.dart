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
  final bool compact;
  final bool embedded;

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
    this.compact = false,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final target = student;
    final roster = _buildRoster();
    final child = roster.isEmpty
        ? _buildEmptyState(context)
        : compact
            ? _buildCompactStudentState(context, target, roster)
            : _buildStudentState(context, target, roster);

    if (embedded) {
      return Padding(padding: padding, child: child);
    }

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(compact ? 16 : 12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: compact ? 8 : 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
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
                compact: false,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCompactStudentState(
    BuildContext context,
    NextStudentTripTarget? target,
    List<NextStudentTripTarget> roster,
  ) {
    final theme = Theme.of(context);
    final pendingCount = roster.where((s) => s.status == 'pending').length;
    final pickedCount = roster.where((s) => s.status == 'picked').length;
    final droppedCount = roster.where((s) => s.status == 'dropped').length;
    final absentCount = roster.where((s) => s.status == 'absent').length;
    final handledCount = pickedCount + droppedCount + absentCount;
    final progress = roster.isEmpty ? 0.0 : handledCount / roster.length;
    final primaryTarget = target ?? roster.first;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCompactRosterHeader(
          context,
          roster.length,
          pendingCount,
          pickedCount,
          droppedCount,
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0).toDouble(),
            minHeight: 5,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(
              theme.colorScheme.primary,
            ),
          ),
        ),
        if (_hasTripActions) ...[
          const SizedBox(height: 10),
          _buildTripActions(compact: true),
        ],
        if (errorMessage != null && errorMessage!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            errorMessage!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 10),
        _StudentTripActionRow(
          student: primaryTarget,
          isHighlighted: target?.id == primaryTarget.id,
          mode: _modeForTarget(primaryTarget),
          distanceMeters: _distanceForTarget(primaryTarget),
          isSubmitting: isSubmitting,
          onPickedUp: _pickActionFor(primaryTarget),
          onDroppedOff: _dropActionFor(primaryTarget),
          onAbsent: _absentActionFor(primaryTarget),
          statusLabel: _statusLabel(primaryTarget.status),
          formatDistance: _formatDistance,
          compact: true,
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

  Widget _buildCompactRosterHeader(
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
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.groups_outlined,
            color: theme.colorScheme.primary,
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Trip students',
                style: theme.textTheme.titleSmall?.copyWith(
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

  Widget _buildTripActions({bool compact = false}) {
    return Row(
      children: [
        Expanded(
          child: _TripActionButton(
            icon: Icons.chat_bubble_outline,
            label: 'Chat',
            onPressed: onChat,
            compact: compact,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _TripActionButton(
            icon: Icons.people_outline,
            label: 'Students',
            onPressed: onStudents,
            compact: compact,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _TripActionButton(
            icon: Icons.notifications_none,
            label: 'Notify',
            onPressed: onNotify,
            compact: compact,
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
    return '${formatStudentDistance(meters)} away';
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
  final bool compact;

  const _TripActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: compact ? 38 : 46,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: compact ? 16 : 18),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: compact ? 12 : 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: theme.colorScheme.primary,
          side: BorderSide(
            color: theme.colorScheme.primary.withValues(alpha: 0.28),
          ),
          padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8),
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
  final bool compact;

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
    this.compact = false,
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

    if (compact) {
      return _buildCompact(
        context,
        isPickup: isPickup,
        canPick: canPick,
        canDrop: canDrop,
        canMarkAbsent: canMarkAbsent,
        destination: destination,
      );
    }

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

  Widget _buildCompact(
    BuildContext context, {
    required bool isPickup,
    required bool canPick,
    required bool canDrop,
    required bool canMarkAbsent,
    required String? destination,
  }) {
    final theme = Theme.of(context);
    final primaryLabel = isPickup ? 'Picked up' : 'Dropped off';
    final primaryIcon = isPickup
        ? Icons.check_circle_outline
        : Icons.home_outlined;
    final primaryAction = isPickup
        ? (canPick ? onPickedUp : null)
        : (canDrop ? onDroppedOff : null);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isHighlighted
            ? theme.colorScheme.primary.withValues(alpha: 0.07)
            : theme.colorScheme.surfaceVariant.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlighted
              ? theme.colorScheme.primary.withValues(alpha: 0.28)
              : theme.dividerColor.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: theme.colorScheme.primary.withValues(
                  alpha: 0.1,
                ),
                backgroundImage:
                    student.photoUrl != null && student.photoUrl!.isNotEmpty
                    ? NetworkImage(student.photoUrl!)
                    : null,
                child: student.photoUrl == null || student.photoUrl!.isEmpty
                    ? Icon(
                        Icons.person,
                        color: theme.colorScheme.primary,
                        size: 20,
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isHighlighted) ...[
                      Text(
                        isPickup ? 'Next pickup' : 'Next drop-off',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 1),
                    ],
                    Text(
                      student.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      destination == null || destination.isEmpty
                          ? 'Location unavailable'
                          : destination,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusChip(label: statusLabel, status: student.status),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.near_me_outlined,
                size: 15,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  formatDistance(distanceMeters),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: FilledButton.icon(
                    onPressed: primaryAction,
                    icon: Icon(primaryIcon, size: 18),
                    label: Text(
                      primaryLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
              if (isPickup) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: OutlinedButton.icon(
                      onPressed: canMarkAbsent ? onAbsent : null,
                      icon: const Icon(Icons.person_off_outlined, size: 18),
                      label: const Text(
                        'Absent',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
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
