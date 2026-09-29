import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../api/services/trip_service.dart';
import '../../models/student.dart';
import '../../providers/auth_provider.dart';
import '../../providers/trip_provider.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme_extension.dart';
import '../../widgets/main_scaffold.dart';
import '../../widgets/ui/ui.dart';

/// The driver's roster for the active trip: progress at a glance, search,
/// status filters, bulk pick/drop and per-student actions (tap, swipe or the
/// inline buttons).
class StudentsListScreen extends StatefulWidget {
  const StudentsListScreen({super.key});

  @override
  State<StudentsListScreen> createState() => _StudentsListScreenState();
}

class _StudentsListScreenState extends State<StudentsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  List<Student> students = [];
  Trip? _trip;
  bool _isUpdating = false;

  /// 0 All, 1 Picked, 2 Absent, 3 Dropped.
  int _filter = 0;

  /// Which bulk button is busy ('pick' / 'drop'), to show its spinner.
  String? _bulkBusy;

  // Store provider reference for listener removal
  TripProvider? _tripProvider;

  @override
  void initState() {
    super.initState();

    // Load students from active trip
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStudentsFromTrip();
    });

    // Listen to TripProvider changes to sync status updates
    _tripProvider = context.read<TripProvider>();
    _tripProvider?.addListener(_onTripProviderChanged);
  }

  void _onTripProviderChanged() {
    // Refresh students when provider updates
    if (mounted && _trip != null) {
      _syncStudentsFromProvider();
    }
  }

  void _syncStudentsFromProvider() {
    final tripProvider = context.read<TripProvider>();

    // Find updated trip data
    Trip? updatedTrip;
    try {
      updatedTrip = tripProvider.trips.firstWhere((t) => t.id == _trip!.id);
    } catch (_) {
      // Try active trip
      if (tripProvider.activeTrip?.id == _trip!.id) {
        updatedTrip = tripProvider.activeTrip;
      }
    }

    if (updatedTrip != null) {
      _trip = updatedTrip;
      // Update students list with new status
      setState(() {
        for (var i = 0; i < students.length; i++) {
          final student = students[i];
          try {
            final updatedStudent = updatedTrip!.students.firstWhere(
              (s) => s.id == student.id,
            );
            students[i] = Student(
              id: student.id,
              name: student.name,
              className: student.className,
              avatar: student.avatar,
              status: _mapStatus(updatedStudent.status),
            );
          } catch (_) {
            // Student not found in updated trip, keep existing
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _tripProvider?.removeListener(_onTripProviderChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _loadStudentsFromTrip() {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final tripId = args?['tripId']?.toString();

    final tripProvider = context.read<TripProvider>();

    // Try to get trip from provider
    Trip? trip;
    if (tripId != null) {
      try {
        trip = tripProvider.trips.firstWhere((t) => t.id == tripId);
      } catch (_) {
        trip = null;
      }
    }
    trip ??= tripProvider.activeTrip;

    if (trip != null) {
      _trip = trip;
      students = trip.students
          .map(
            (s) => Student(
              id: s.id,
              name: s.name,
              className: '', // Not available in StudentPickup
              avatar: s.photo ?? '',
              status: _mapStatus(s.status),
            ),
          )
          .toList();
    } else if (kDebugMode) {
      debugPrint(
        '⚠️ StudentsListScreen: no trip (tripId $tripId, '
        'active ${tripProvider.activeTrip?.id})',
      );
    }

    setState(() => _isLoading = false);
  }

  StudentStatus _mapStatus(String status) {
    switch (status) {
      case 'picked':
        return StudentStatus.picked;
      case 'absent':
        return StudentStatus.absent;
      case 'dropped':
        return StudentStatus.dropped;
      default:
        return StudentStatus.pending;
    }
  }

  void _updateStudentStatus(String id, StudentStatus status) async {
    if (_isUpdating) return;

    setState(() => _isUpdating = true);
    HapticFeedback.lightImpact();

    // Update local state immediately for responsive UI
    setState(() {
      final student = students.firstWhere((s) => s.id == id);
      student.status = status;
    });

    // Sync with backend
    try {
      final tripProvider = context.read<TripProvider>();
      final tripId = _trip?.id;
      if (tripId != null) {
        await tripProvider.updateStudentStatus(
          tripId: tripId,
          studentId: id,
          status: status.name,
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Failed to update student status: $e');
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  List<Student> _getFilteredStudents() {
    final query = _searchController.text.toLowerCase();
    var filtered = students;

    if (query.isNotEmpty) {
      filtered = filtered
          .where((s) => s.name.toLowerCase().contains(query))
          .toList();
    }

    return switch (_filter) {
      1 => filtered.where((s) => s.status == StudentStatus.picked).toList(),
      2 => filtered.where((s) => s.status == StudentStatus.absent).toList(),
      3 => filtered.where((s) => s.status == StudentStatus.dropped).toList(),
      _ => filtered,
    };
  }

  int _count(StudentStatus s) => students.where((x) => x.status == s).length;

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    final filteredStudents = _getFilteredStudents();
    final pickedCount = _count(StudentStatus.picked);
    final absentCount = _count(StudentStatus.absent);
    final droppedCount = _count(StudentStatus.dropped);
    final pendingCount = _count(StudentStatus.pending);

    return MainScaffold(
      title: 'Students',
      showBackButton: true,
      body: Stack(
        children: [
          const Positioned.fill(child: AppBackdrop()),
          AsyncBody(
            loading: _isLoading,
            skeleton: const _LoadingSkeleton(),
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.xs,
                    AppSpacing.md,
                    0,
                  ),
                  sliver: SliverList.list(
                    children: [
                      _buildHero(
                        done: pickedCount + droppedCount,
                        picked: pickedCount,
                        pending: pendingCount,
                        absent: absentCount,
                      ).enter(),
                      AppSpacing.vLg,
                      AppTextField(
                        controller: _searchController,
                        hint: 'Search students by name…',
                        prefixIcon: Icons.search_rounded,
                        textInputAction: TextInputAction.search,
                        onChanged: (_) => setState(() {}),
                        suffixIcon: _searchController.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                icon: const Icon(Icons.close_rounded),
                                onPressed: _clearSearch,
                              ),
                      ).enter(delay: const Duration(milliseconds: 60)),
                      AppSpacing.vMd,
                      SegmentedFilter(
                        selected: _filter,
                        onChanged: (i) => setState(() => _filter = i),
                        segments: [
                          FilterSegment('All', count: students.length),
                          FilterSegment('Picked', count: pickedCount),
                          FilterSegment('Absent', count: absentCount),
                          FilterSegment('Dropped', count: droppedCount),
                        ],
                      ).enter(delay: const Duration(milliseconds: 120)),
                      AppSpacing.vMd,
                      _buildBulkActions().enter(
                        delay: const Duration(milliseconds: 180),
                      ),
                      AppSpacing.vMd,
                    ],
                  ),
                ),
                if (filteredStudents.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      120, // clear the floating "Complete Trip" button
                    ),
                    sliver: SliverList.separated(
                      itemCount: filteredStudents.length,
                      separatorBuilder: (_, _) => AppSpacing.vSm,
                      itemBuilder: (context, index) {
                        final student = filteredStudents[index];
                        // Keyed by filter too, so switching filters replays
                        // the staggered entrance for the new list.
                        return KeyedSubtree(
                          key: ValueKey('$_filter-${student.id}'),
                          child: _buildStudentRow(student).enterList(index),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _isLoading
          ? null
          : _buildCompleteButton(
              allDone: students.isNotEmpty && pendingCount == 0,
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  /// Route, headline progress ring and the three live counters.
  Widget _buildHero({
    required int done,
    required int picked,
    required int pending,
    required int absent,
  }) {
    final onBrand = context.text.bodySmall?.copyWith(
      color: Colors.white.withValues(alpha: 0.85),
    );
    return GradientHeroCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Row(
            children: [
              TripProgress.ring(
                done: done,
                total: students.length,
                onBrand: true,
                size: 72,
                thickness: 7,
              ),
              AppSpacing.hMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _trip?.routeName ?? 'Active Trip',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    AppSpacing.vXxs,
                    Row(
                      children: [
                        const StatusPill(
                          label: 'In progress',
                          color: Colors.white,
                          pulse: true,
                          dense: true,
                        ),
                        AppSpacing.hXs,
                        Flexible(
                          child: Text(
                            '$done of ${students.length} done',
                            style: onBrand,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          AppSpacing.vMd,
          Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: AppRadius.brMd,
            ),
            child: Row(
              children: [
                Expanded(
                  child: StatTile(
                    icon: Icons.check_circle_rounded,
                    value: '$picked',
                    label: 'Picked',
                    onLight: true,
                  ),
                ),
                Expanded(
                  child: StatTile(
                    icon: Icons.schedule_rounded,
                    value: '$pending',
                    label: 'Pending',
                    onLight: true,
                  ),
                ),
                Expanded(
                  child: StatTile(
                    icon: Icons.cancel_rounded,
                    value: '$absent',
                    label: 'Absent',
                    onLight: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulkActions() {
    final busy = _bulkBusy != null;
    return Row(
      children: [
        Expanded(
          child: AppButton(
            label: 'Pick All',
            icon: Icons.done_all_rounded,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.medium,
            loading: _bulkBusy == 'pick',
            onPressed: busy ? null : _pickAllStudents,
          ),
        ),
        AppSpacing.hSm,
        Expanded(
          child: AppButton(
            label: 'Drop All',
            icon: Icons.home_rounded,
            variant: AppButtonVariant.outline,
            size: AppButtonSize.medium,
            loading: _bulkBusy == 'drop',
            onPressed: busy ? null : _dropAllStudents,
          ),
        ),
      ],
    );
  }

  Widget _buildStudentRow(Student student) {
    final c = context.colors;
    final isPending = student.status == StudentStatus.pending;
    final style = StudentStatusStyle.of(context, student.status.name);

    final row = StudentStatusRow(
      name: student.name,
      photoUrl: student.avatar,
      status: student.status.name,
      onTap: () => _showStudentActions(student),
      trailing: isPending
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _QuickAction(
                  icon: Icons.check_rounded,
                  color: c.brand,
                  tooltip: 'Pick up ${student.name}',
                  onTap: () =>
                      _updateStudentStatus(student.id, StudentStatus.picked),
                ),
                AppSpacing.hXs,
                _QuickAction(
                  icon: Icons.close_rounded,
                  color: c.warning,
                  tooltip: 'Mark ${student.name} absent',
                  onTap: () =>
                      _updateStudentStatus(student.id, StudentStatus.absent),
                ),
              ],
            )
          : Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: style.color.withValues(alpha: 0.12),
                borderRadius: AppRadius.brSm,
              ),
              child: Icon(style.icon, size: AppIconSize.lg, color: style.color),
            ).pop(),
    );

    if (!isPending) return row;

    // Swipe right to pick up, left to mark absent. The row springs back and
    // updates in place rather than leaving the list.
    return SwipeAction(
      key: ValueKey('swipe_${student.id}'),
      start: SwipeSpec(
        label: 'Pick Up',
        icon: Icons.check_circle_rounded,
        color: c.brand,
        onTrigger: () async {
          _updateStudentStatus(student.id, StudentStatus.picked);
          return false;
        },
      ),
      end: SwipeSpec(
        label: 'Absent',
        icon: Icons.cancel_rounded,
        color: c.warning,
        onTrigger: () async {
          _updateStudentStatus(student.id, StudentStatus.absent);
          return false;
        },
      ),
      child: row,
    );
  }

  Widget _buildCompleteButton({required bool allDone}) {
    final button = FloatingActionButton.extended(
      heroTag: 'complete-trip',
      backgroundColor: context.scheme.primary,
      foregroundColor: context.scheme.onPrimary,
      onPressed: _endTrip,
      icon: const Icon(Icons.flag_rounded),
      label: const Text('Complete Trip'),
    );
    // Once nobody is left pending, a light sweep nudges the driver to finish.
    return KeyedSubtree(
      key: ValueKey(allDone),
      child: allDone ? button.pop().celebrate() : button.pop(),
    );
  }

  Widget _buildEmptyState() {
    final searching = _searchController.text.isNotEmpty;
    return EmptyState(
      icon: searching ? Icons.search_off_rounded : Icons.person_off_outlined,
      title: searching ? 'No matching students' : 'No students here',
      message: searching
          ? 'Try a different name.'
          : 'Nobody in this category yet.',
      actionLabel: searching ? 'Clear search' : null,
      onAction: searching ? _clearSearch : null,
      compact: true,
    );
  }

  void _clearSearch() {
    _searchController.clear();
    FocusScope.of(context).unfocus();
    setState(() {});
  }

  // ==========================================================================
  // ACTIONS
  // ==========================================================================

  /// End the trip and navigate to dashboard
  Future<void> _endTrip() async {
    if (_trip == null) {
      // No trip to end, just go to dashboard
      Navigator.pushReplacementNamed(
        context,
        '/dashboard',
        arguments: {'fromTripEnd': true},
      );
      return;
    }

    final confirmed = await confirmDialog(
      context,
      title: 'Complete Trip',
      message: 'Are you sure you want to end this trip?',
      confirmLabel: 'End Trip',
      icon: Icons.flag_rounded,
    );

    if (!confirmed || !mounted) return;

    try {
      final tripProvider = context.read<TripProvider>();
      final authProvider = context.read<AuthProvider>();

      final success = await tripProvider.endTrip(
        _trip!.id,
        driverId: authProvider.userId,
        driverName: authProvider.userName,
      );

      if (!mounted) return;
      if (success) {
        AppSnackbar.success(context, 'Trip completed successfully');
        Navigator.pushReplacementNamed(
          context,
          '/dashboard',
          arguments: {'fromTripEnd': true},
        );
      } else {
        AppSnackbar.error(
          context,
          'Failed to complete trip: '
          '${tripProvider.errorMessage ?? "Unknown error"}',
        );
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, 'Error: $e');
    }
  }

  /// Pick all students in the trip
  Future<void> _pickAllStudents() async {
    if (_trip == null || _isUpdating) return;

    setState(() {
      _isUpdating = true;
      _bulkBusy = 'pick';
    });

    try {
      final tripProvider = context.read<TripProvider>();
      final ok = await tripProvider.pickAllStudents(_trip!.id);
      if (!ok) throw Exception(tripProvider.errorMessage ?? 'Request failed');

      setState(() {
        for (final s in students) {
          if (s.status == StudentStatus.pending) {
            s.status = StudentStatus.picked;
          }
        }
      });

      if (mounted) AppSnackbar.success(context, 'All students picked up');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Failed to pick all students: $e');
      if (mounted) AppSnackbar.error(context, 'Failed to pick all: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
          _bulkBusy = null;
        });
      }
    }
  }

  /// Drop all students in the trip
  Future<void> _dropAllStudents() async {
    if (_trip == null || _isUpdating) return;

    setState(() {
      _isUpdating = true;
      _bulkBusy = 'drop';
    });

    try {
      final tripProvider = context.read<TripProvider>();
      final ok = await tripProvider.dropAllStudents(_trip!.id);
      if (!ok) throw Exception(tripProvider.errorMessage ?? 'Request failed');

      setState(() {
        for (final s in students) {
          if (s.status == StudentStatus.picked) {
            s.status = StudentStatus.dropped;
          }
        }
      });

      if (mounted) AppSnackbar.info(context, 'All students dropped off');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Failed to drop all students: $e');
      if (mounted) AppSnackbar.error(context, 'Failed to drop all: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
          _bulkBusy = null;
        });
      }
    }
  }

  void _showStudentActions(Student student) {
    void act(BuildContext sheet, StudentStatus status) {
      _updateStudentStatus(student.id, status);
      Navigator.pop(sheet);
    }

    showAppBottomSheet<void>(
      context: context,
      builder: (sheet) {
        final c = sheet.colors;
        final style = StudentStatusStyle.of(sheet, student.status.name);
        final isPending = student.status == StudentStatus.pending;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppSpacing.vXs,
            StatusAvatar(
              name: student.name,
              photoUrl: student.avatar,
              color: style.color,
              size: 84,
            ).pop(),
            AppSpacing.vMd,
            Text(
              student.name,
              textAlign: TextAlign.center,
              style: sheet.text.headlineSmall,
            ),
            AppSpacing.vXs,
            StatusPill(
              label: style.label,
              color: style.color,
              icon: style.icon,
            ),
            AppSpacing.vXl,
            Row(
              children: [
                Expanded(
                  child: _SheetAction(
                    icon: Icons.check_circle_rounded,
                    label: 'Pick Up',
                    color: c.brand,
                    enabled: isPending,
                    onTap: () => act(sheet, StudentStatus.picked),
                  ).enterList(0),
                ),
                AppSpacing.hSm,
                Expanded(
                  child: _SheetAction(
                    icon: Icons.cancel_rounded,
                    label: 'Absent',
                    color: c.warning,
                    enabled: isPending,
                    onTap: () => act(sheet, StudentStatus.absent),
                  ).enterList(1),
                ),
              ],
            ),
            if (student.status == StudentStatus.picked) ...[
              AppSpacing.vSm,
              SizedBox(
                width: double.infinity,
                child: _SheetAction(
                  icon: Icons.home_rounded,
                  label: 'Drop Off',
                  color: c.info,
                  enabled: true,
                  onTap: () => act(sheet, StudentStatus.dropped),
                ),
              ).enterList(2),
            ],
            if (!isPending) ...[
              AppSpacing.vSm,
              AppButton(
                label: 'Reset to Pending',
                icon: Icons.refresh_rounded,
                variant: AppButtonVariant.outline,
                onPressed: () => act(sheet, StudentStatus.pending),
              ).enterList(3),
            ],
          ],
        );
      },
    );
  }
}

// ============================================================================
// PRIVATE WIDGETS
// ============================================================================

/// Compact tinted icon button for the inline pick / absent actions.
class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: PressScale(
        scale: 0.9,
        child: Material(
          color: color.withValues(alpha: 0.12),
          borderRadius: AppRadius.brSm,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.brSm,
            child: SizedBox.square(
              dimension: 44,
              child: Icon(icon, size: AppIconSize.md, color: color),
            ),
          ),
        ),
      ),
    );
  }
}

/// Large tinted action tile in the student sheet.
class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: enabled ? 1 : 0.4,
      duration: AppDuration.medium,
      child: PressScale(
        enabled: enabled,
        child: Material(
          color: Colors.transparent,
          borderRadius: AppRadius.brLg,
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.18),
                  color.withValues(alpha: 0.06),
                ],
              ),
              borderRadius: AppRadius.brLg,
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: InkWell(
              onTap: enabled ? onTap : null,
              borderRadius: AppRadius.brLg,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Column(
                  children: [
                    Icon(icon, size: AppIconSize.xxl, color: color),
                    AppSpacing.vXs,
                    Text(
                      label,
                      style: context.text.titleSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Placeholder shaped like the real screen: hero, search, filter, rows.
class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.md),
      children: const [
        AppSkeleton(height: 168, borderRadius: AppRadius.brXl),
        AppSpacing.vLg,
        AppSkeleton(height: 52, borderRadius: AppRadius.brMd),
        AppSpacing.vMd,
        AppSkeleton(height: 48, borderRadius: AppRadius.brMd),
        AppSpacing.vMd,
        SkeletonListTile(),
        SkeletonListTile(),
        SkeletonListTile(),
        SkeletonListTile(),
      ],
    );
  }
}
