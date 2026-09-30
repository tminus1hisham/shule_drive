import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api/services/trip_service.dart';
import '../../providers/auth_provider.dart';
import '../../services/trip_history_service.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme_extension.dart';
import '../../widgets/main_scaffold.dart';
import '../../widgets/ui/ui.dart';

/// Trip Details Screen - Shows detailed trip information for DRIVERS ONLY
/// Includes: trip info, students picked/dropped, timeline, stats
class TripDetailsScreen extends StatefulWidget {
  const TripDetailsScreen({super.key});

  @override
  State<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends State<TripDetailsScreen> {
  TripHistory? _tripHistory;
  bool _isLoading = true;
  bool _didLoadData = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load data here instead of initState to access ModalRoute
    if (!_didLoadData) {
      _didLoadData = true;
      _loadTripDetails();
    }
  }

  Future<void> _loadTripDetails() async {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    if (args != null && args['history'] != null) {
      setState(() {
        _tripHistory = args['history'] as TripHistory;
        _isLoading = false;
      });
    } else if (args != null && args['tripId'] != null) {
      // Load from history service
      final authProvider = context.read<AuthProvider>();
      final driverId = authProvider.userData['id'] ?? '';
      final history = await TripHistoryService().getCachedDriverTripHistory(
        driverId,
      );

      // Not in saved history -> show the empty state, don't spin forever.
      final tripHistory = history
          .where((h) => h.trip.id == args['tripId'])
          .firstOrNull;

      if (mounted) {
        setState(() {
          _tripHistory = tripHistory;
          _isLoading = false;
        });
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour > 12
        ? date.hour - 12
        : (date.hour == 0 ? 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    // GUARDIAN CHECK: Only drivers should see this screen
    if (!authProvider.isDriver) {
      return MainScaffold(
        title: 'Trip Details',
        showBackButton: true,
        body: EmptyState(
          icon: Icons.lock_outline_rounded,
          iconColor: context.colors.warning,
          title: 'Driver Feature Only',
          message: 'Trip details are only available for drivers.',
        ),
      );
    }

    final history = _tripHistory;
    return MainScaffold(
      title: 'Trip Details',
      showBackButton: true,
      body: Stack(
        children: [
          const Positioned.fill(child: AppBackdrop()),
          AsyncBody(
            loading: _isLoading,
            isEmpty: history == null,
            empty: const EmptyState(
              icon: Icons.search_off_rounded,
              title: 'Trip not found',
              message: 'This trip isn\'t in your history on this device.',
            ),
            skeleton: ListView(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.md),
              children: const [
                AppSkeleton(height: 200, borderRadius: AppRadius.brXl),
                AppSpacing.vMd,
                AppSkeleton(height: 130, borderRadius: AppRadius.brLg),
                AppSpacing.vMd,
                SkeletonListTile(),
                SkeletonListTile(),
                SkeletonListTile(),
              ],
            ),
            child: history == null
                ? const SizedBox.shrink()
                : ListView(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    children: [
                      _buildTripHeaderCard(history.trip).enter(),
                      AppSpacing.vLg,
                      _buildTripStats(history.trip).enterList(1),
                      AppSpacing.vXl,
                      _buildStudentsSection(history.trip),
                      AppSpacing.vXl,
                      if (history.trip.stops.isNotEmpty) ...[
                        _buildTimelineSection(history.trip),
                        AppSpacing.vXl,
                      ],
                      _buildDriverInfoCard(history).enterList(4),
                      AppSpacing.vXxl,
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripHeaderCard(Trip trip) {
    final c = context.colors;
    final isCompleted = trip.isCompleted;
    final meta = context.text.bodyMedium?.copyWith(
      color: Colors.white.withValues(alpha: 0.9),
    );

    Widget line(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          AppSpacing.hXs,
          Text(text, style: meta),
        ],
      ),
    );

    return GradientHeroCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Hero(
                tag: 'trip-badge-${trip.id}',
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: isCompleted ? null : c.accentGradient,
                    color: isCompleted
                        ? Colors.white.withValues(alpha: 0.2)
                        : null,
                    borderRadius: AppRadius.brSm,
                  ),
                  child: const Icon(
                    Icons.directions_bus_rounded,
                    color: Colors.white,
                  ),
                ),
              ),
              AppSpacing.hSm,
              StatusPill(
                label: isCompleted ? 'COMPLETED' : 'ACTIVE',
                color: Colors.white,
                pulse: !isCompleted,
                icon: isCompleted ? Icons.check_circle_rounded : null,
                dense: true,
              ),
              const Spacer(),
              Text(_formatDate(trip.startTime), style: meta),
            ],
          ),
          AppSpacing.vMd,
          Text(
            trip.routeName,
            style: context.text.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          line(
            Icons.directions_bus_outlined,
            trip.vehicleNumber ?? 'Unknown Vehicle',
          ),
          line(
            Icons.access_time_rounded,
            'Started: ${_formatTime(trip.startTime)}',
          ),
          if (trip.endTime != null)
            line(
              Icons.check_circle_outline_rounded,
              'Ended: ${_formatTime(trip.endTime!)}',
            ),
        ],
      ),
    );
  }

  Widget _buildTripStats(Trip trip) {
    final c = context.colors;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: SectionHeader(title: 'Trip Statistics')),
              TripProgress.ring(
                done: trip.pickedUpCount,
                total: trip.students.length,
                size: 48,
                thickness: 5,
              ),
            ],
          ),
          AppSpacing.vMd,
          Row(
            children: [
              _buildStatBox(
                trip.students.length.toString(),
                'Total Students',
                Icons.people_rounded,
                c.brand,
              ),
              AppSpacing.hSm,
              _buildStatBox(
                trip.pickedUpCount.toString(),
                'Picked Up',
                Icons.check_circle_rounded,
                c.success,
              ),
              AppSpacing.hSm,
              _buildStatBox(
                trip.absentCount.toString(),
                'Absent',
                Icons.cancel_rounded,
                c.warning,
              ),
            ],
          ),
          if (trip.distance != null) ...[
            AppSpacing.vSm,
            Row(
              children: [
                _buildStatBox(
                  '${trip.distance!.toStringAsFixed(1)} km',
                  'Distance',
                  Icons.route_rounded,
                  c.info,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatBox(String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: AppRadius.brSm,
          border: Border.all(color: color.withValues(alpha: 0.16)),
        ),
        child: StatTile(icon: icon, value: value, label: label, color: color),
      ),
    );
  }

  Widget _buildStudentsSection(Trip trip) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: SectionHeader(title: 'Students (${trip.students.length})'),
            ),
            StatusPill(
              label: '${trip.pickedUpCount}/${trip.students.length}',
              color: c.brand,
              icon: Icons.check_circle_rounded,
              dense: true,
            ),
          ],
        ).enterList(2),
        AppSpacing.vSm,
        if (trip.students.isEmpty)
          const EmptyState(
            icon: Icons.people_outline_rounded,
            title: 'No students in this trip',
            compact: true,
          )
        else
          for (final (i, student) in trip.students.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: _buildStudentItem(student).enterList(i + 3),
            ),
      ],
    );
  }

  Widget _buildStudentItem(StudentPickup student) {
    // Handle corrupted data
    final studentName = student.name.isNotEmpty && student.name != 'string'
        ? student.name
        : 'Unknown Student';
    final parentPhone =
        student.parentPhone != null && student.parentPhone != 'string'
        ? student.parentPhone
        : null;
    final photo = student.photo != null && student.photo != 'string'
        ? student.photo
        : null;

    return StudentStatusRow(
      name: studentName,
      status: student.status,
      photoUrl: photo,
      subtitle: parentPhone == null ? null : 'Parent: $parentPhone',
    );
  }

  Widget _buildTimelineSection(Trip trip) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Trip Timeline'),
        AppSpacing.vSm,
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: [
              for (final (index, stop) in trip.stops.indexed)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 16,
                        child: Column(
                          children: [
                            Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                gradient: c.brandGradient,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: context.scheme.surface,
                                  width: 2,
                                ),
                              ),
                            ).pop(delay: AppMotion.staggerStep * index * 2),
                            if (index < trip.stops.length - 1)
                              // The connector grows downward after its stop
                              // appears, drawing the route stop by stop.
                              Expanded(
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0, end: 1),
                                  duration: Duration(
                                    milliseconds: 300 + 100 * index,
                                  ),
                                  curve: AppCurves.easeOut,
                                  builder: (context, v, child) => Align(
                                    alignment: Alignment.topCenter,
                                    heightFactor: 1,
                                    child: FractionallySizedBox(
                                      heightFactor: v,
                                      child: child,
                                    ),
                                  ),
                                  child: Container(
                                    width: 2,
                                    color: c.brand.withValues(alpha: 0.35),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      AppSpacing.hSm,
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            bottom: index < trip.stops.length - 1
                                ? AppSpacing.lg
                                : 0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                stop.name,
                                style: context.text.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (stop.address.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  stop.address,
                                  style: context.text.bodySmall?.copyWith(
                                    color: c.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ).enterList(index),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDriverInfoCard(TripHistory history) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Trip Information'),
          AppSpacing.vSm,
          _buildInfoRow(Icons.person_rounded, 'Driver', history.driverName),
          if (history.attendantName != null)
            _buildInfoRow(
              Icons.assistant_rounded,
              'Attendant',
              history.attendantName!,
            ),
          _buildInfoRow(
            Icons.access_time_rounded,
            'Logged At',
            '${_formatDate(history.loggedAt)} ${_formatTime(history.loggedAt)}',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 18, color: c.textMuted),
          AppSpacing.hSm,
          Text(
            '$label: ',
            style: context.text.bodyMedium?.copyWith(color: c.textSecondary),
          ),
          Expanded(
            child: Text(
              value,
              style: context.text.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
