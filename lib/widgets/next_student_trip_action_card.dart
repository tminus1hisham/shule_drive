import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_theme_extension.dart';
import '../utils/student_trip_logic.dart';
import 'ui/ui.dart';

typedef NextStudentTripTargetCallback =
    void Function(NextStudentTripTarget student);
typedef NextStudentTripModeResolver =
    StudentTripActionMode Function(NextStudentTripTarget student);
typedef NextStudentTripDistanceResolver =
    double? Function(NextStudentTripTarget student);

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
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.maxRosterHeight = 260,
    this.compact = false,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context) {
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

    return AppCard(
      padding: padding,
      borderRadius: compact ? AppRadius.brMd : AppRadius.brSm,
      border: Border.all(color: context.colors.outline),
      shadow: context.colors.shadowMd,
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
    return Row(
      children: [
        Icon(Icons.check_circle_outline, color: context.colors.brand).pop(),
        AppSpacing.hSm,
        Expanded(
          child: Text(
            'No students in this trip',
            style: context.text.titleSmall,
          ),
        ),
      ],
    );
  }

  Widget _buildError(BuildContext context) {
    final show = errorMessage != null && errorMessage!.isNotEmpty;
    // Errors slide open under the header instead of shoving the roster down.
    return AnimatedSize(
      duration: AppDuration.medium,
      curve: AppCurves.easeOut,
      alignment: Alignment.topCenter,
      child: show
          ? Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: AppIconSize.sm,
                    color: context.colors.error,
                  ),
                  AppSpacing.hXs,
                  Expanded(
                    child: Text(
                      errorMessage!,
                      style: context.text.bodySmall?.copyWith(
                        color: context.colors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox(width: double.infinity),
    );
  }

  Widget _buildStudentState(
    BuildContext context,
    NextStudentTripTarget? target,
    List<NextStudentTripTarget> roster,
  ) {
    final pendingCount = roster.where((s) => s.status == 'pending').length;
    final pickedCount = roster.where((s) => s.status == 'picked').length;
    final droppedCount = roster.where((s) => s.status == 'dropped').length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RosterHeader(
          total: roster.length,
          pending: pendingCount,
          picked: pickedCount,
          dropped: droppedCount,
          compact: false,
        ),
        if (_hasTripActions) ...[AppSpacing.vSm, _buildTripActions()],
        _buildError(context),
        AppSpacing.vSm,
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxRosterHeight),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: roster.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = roster[index];
              return _StudentTripActionRow(
                key: ValueKey(item.id),
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
              ).enterList(index);
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
    final pendingCount = roster.where((s) => s.status == 'pending').length;
    final pickedCount = roster.where((s) => s.status == 'picked').length;
    final droppedCount = roster.where((s) => s.status == 'dropped').length;
    final absentCount = roster.where((s) => s.status == 'absent').length;
    final handledCount = pickedCount + droppedCount + absentCount;
    final primaryTarget = target ?? roster.first;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RosterHeader(
          total: roster.length,
          pending: pendingCount,
          picked: pickedCount,
          dropped: droppedCount,
          compact: true,
        ),
        const SizedBox(height: 10),
        TripProgress.bar(
          done: handledCount,
          total: roster.length,
          thickness: 6,
        ),
        if (_hasTripActions) ...[
          const SizedBox(height: 10),
          _buildTripActions(compact: true),
        ],
        _buildError(context),
        const SizedBox(height: 10),
        // When the next student changes, the old card slides out left and the
        // new one slides in from the right, like turning to the next stop.
        AnimatedSwitcher(
          duration: AppDuration.slow,
          switchInCurve: AppCurves.easeOut,
          switchOutCurve: Curves.easeIn,
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topCenter,
            children: [...previous, ?current],
          ),
          transitionBuilder: (child, anim) {
            final incoming = child.key == ValueKey(primaryTarget.id);
            return FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: Offset(incoming ? 0.15 : -0.15, 0),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            );
          },
          child: _StudentTripActionRow(
            key: ValueKey(primaryTarget.id),
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
        AppSpacing.hXs,
        Expanded(
          child: _TripActionButton(
            icon: Icons.people_outline,
            label: 'Students',
            onPressed: onStudents,
            compact: compact,
          ),
        ),
        AppSpacing.hXs,
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

class _RosterHeader extends StatelessWidget {
  const _RosterHeader({
    required this.total,
    required this.pending,
    required this.picked,
    required this.dropped,
    required this.compact,
  });

  final int total;
  final int pending;
  final int picked;
  final int dropped;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final size = compact ? 34.0 : 42.0;
    return Row(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                c.brand.withValues(alpha: 0.22),
                c.brand.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: compact ? AppRadius.brSm : AppRadius.brSm,
          ),
          child: Icon(
            Icons.groups_rounded,
            color: c.brand,
            size: compact ? AppIconSize.md : AppIconSize.lg,
          ),
        ),
        SizedBox(width: compact ? 10 : AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Trip students',
                style:
                    (compact
                            ? context.text.titleSmall
                            : context.text.titleMedium)
                        ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                '$total total - $pending waiting - $picked picked - '
                '$dropped dropped',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodySmall?.copyWith(
                  color: c.textSecondary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
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
    final brand = context.colors.brand;

    return PressScale(
      enabled: onPressed != null,
      child: SizedBox(
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
            foregroundColor: brand,
            backgroundColor: brand.withValues(alpha: 0.06),
            side: BorderSide(color: brand.withValues(alpha: 0.28)),
            padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8),
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.brSm),
          ),
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
    super.key,
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
    final isPickup = mode == StudentTripActionMode.pickup;
    final status = student.status;
    final canPick = isPickup && status == 'pending' && !isSubmitting;
    final canDrop =
        mode == StudentTripActionMode.dropoff &&
        status == 'picked' &&
        !isSubmitting;
    final canMarkAbsent = isPickup && status == 'pending' && !isSubmitting;
    final destination = student.destinationLabel?.trim();
    final c = context.colors;
    final statusStyle = StudentStatusStyle.of(context, status);

    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StatusAvatar(
          name: student.name,
          photoUrl: student.photoUrl,
          color: statusStyle.color,
          size: compact ? 38 : 46,
        ),
        SizedBox(width: compact ? 10 : AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isHighlighted) ...[
                Text(
                  isPickup ? 'Next pickup' : 'Next drop-off',
                  style:
                      (compact
                              ? context.text.labelSmall
                              : context.text.labelMedium)
                          ?.copyWith(
                            color: c.brand,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                ),
                const SizedBox(height: 2),
              ],
              Text(
                student.name,
                maxLines: compact ? 1 : null,
                overflow: compact ? TextOverflow.ellipsis : null,
                style: context.text.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: compact ? 2 : AppSpacing.xxs),
              Text(
                destination == null || destination.isEmpty
                    ? 'Location unavailable'
                    : destination,
                maxLines: compact ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodySmall?.copyWith(color: c.textSecondary),
              ),
            ],
          ),
        ),
        AppSpacing.hXs,
        StatusPill(label: statusLabel, color: statusStyle.color, dense: true),
      ],
    );

    final distance = Row(
      children: [
        Icon(
          Icons.near_me_rounded,
          size: compact ? 15 : AppIconSize.sm,
          color: c.accent,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            formatDistance(distanceMeters),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodySmall?.copyWith(
              color: c.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );

    final actions = compact
        ? _compactActions(isPickup, canPick, canDrop, canMarkAbsent)
        : Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
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

    // The highlight (tint + brand edge) eases between rows as the "next"
    // student moves down the roster.
    return AnimatedContainer(
      duration: AppDuration.slow,
      curve: AppCurves.easeOut,
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 10 : AppSpacing.sm),
      decoration: BoxDecoration(
        color: isHighlighted
            ? c.brand.withValues(alpha: 0.08)
            : c.surfaceSubtle.withValues(alpha: 0.6),
        borderRadius: AppRadius.brSm,
        border: Border.all(
          color: isHighlighted ? c.brand.withValues(alpha: 0.4) : c.outline,
          width: isHighlighted ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          SizedBox(height: compact ? AppSpacing.xs : 10),
          distance,
          SizedBox(height: compact ? 10 : AppSpacing.sm),
          actions,
        ],
      ),
    );
  }

  Widget _compactActions(
    bool isPickup,
    bool canPick,
    bool canDrop,
    bool canMarkAbsent,
  ) {
    final primaryLabel = isPickup ? 'Picked up' : 'Dropped off';
    final primaryIcon = isPickup
        ? Icons.check_circle_outline
        : Icons.home_outlined;
    final primaryAction = isPickup
        ? (canPick ? onPickedUp : null)
        : (canDrop ? onDroppedOff : null);
    const shape = RoundedRectangleBorder(borderRadius: AppRadius.brSm);

    return Row(
      children: [
        Expanded(
          child: PressScale(
            enabled: primaryAction != null,
            child: SizedBox(
              height: 44,
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
                  shape: shape,
                ),
              ),
            ),
          ),
        ),
        if (isPickup) ...[
          AppSpacing.hXs,
          Expanded(
            child: PressScale(
              enabled: canMarkAbsent,
              child: SizedBox(
                height: 44,
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
                    shape: shape,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
