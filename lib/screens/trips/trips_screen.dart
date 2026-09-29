import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/trip_history_service.dart';
import '../../widgets/main_scaffold.dart';
import 'guardian_trips_screen.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme_extension.dart';
import '../../widgets/ui/ui.dart';

/// Trips Screen - Shows trip history for DRIVERS
/// Shows ACTIVE trips for GUARDIANS (involving their students)
class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  final TripHistoryService _historyService = TripHistoryService();

  List<TripHistory> _trips = [];
  DriverStats _stats = DriverStats.empty();
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final driverId = authProvider.userData['id'] ?? '';

      if (driverId.isEmpty) {
        setState(() {
          _errorMessage = 'Driver ID not found';
          _isLoading = false;
        });
        return;
      }

      // Load from local storage
      final trips = await _historyService.getTripHistory(driverId);
      final stats = await _historyService.getDriverStats(driverId);

      if (mounted) {
        setState(() {
          _trips = trips;
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load trips';
          _isLoading = false;
        });
      }
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

    // For guardians, show the GuardianTripsScreen (active trips view)
    if (!authProvider.isDriver) {
      return const GuardianTripsScreen();
    }

    return MainScaffold(
      title: 'Trip History',
      showBackButton: true,
      showBottomNav: true,
      bottomNavIndex: 3,
      body: Stack(
        children: [
          const Positioned.fill(child: AppBackdrop()),
          AsyncBody(
            loading: _isLoading && _trips.isEmpty,
            error: _trips.isEmpty ? _errorMessage : null,
            onRetry: _loadTrips,
            onRefresh: _loadTrips,
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final c = context.colors;
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _buildStatsCard().enter()),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xl,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                const Expanded(child: SectionHeader(title: 'Recent Trips')),
                if (_trips.isNotEmpty)
                  StatusPill(
                    label: '${_trips.length} trips',
                    color: c.textSecondary,
                    showDot: false,
                    dense: true,
                  ),
              ],
            ).enterList(1),
          ),
        ),
        if (_trips.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.local_shipping_outlined,
              title: 'No trips yet',
              message: 'Start a new trip to see it here',
              actionLabel: 'Start New Trip',
              onAction: () => Navigator.pushNamed(context, '/start-trip'),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            sliver: SliverList.separated(
              itemCount: _trips.length,
              separatorBuilder: (_, _) => AppSpacing.vSm,
              itemBuilder: (context, index) =>
                  _buildTripCard(_trips[index]).enterList(index + 2),
            ),
          ),
        const SliverPadding(padding: EdgeInsets.only(bottom: AppSpacing.xl)),
      ],
    );
  }

  Widget _buildStatsCard() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: GradientHeroCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Your Stats',
                    style: context.text.titleMedium?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
                const StatusPill(
                  label: 'Driver',
                  color: Colors.white,
                  icon: Icons.badge_outlined,
                  dense: true,
                ),
              ],
            ),
            AppSpacing.vLg,
            IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: _heroStat(
                      Icons.route_rounded,
                      _stats.totalTrips,
                      'Trips',
                    ),
                  ),
                  const VerticalDivider(color: Colors.white24, width: 1),
                  Expanded(
                    child: _heroStat(
                      Icons.people_rounded,
                      _stats.totalStudents,
                      'Students',
                    ),
                  ),
                  const VerticalDivider(color: Colors.white24, width: 1),
                  Expanded(
                    child: _heroStat(
                      Icons.check_circle_rounded,
                      _stats.completionRate.round(),
                      'Picked',
                      suffix: '%',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Hero number that counts up from zero when the screen opens.
  Widget _heroStat(
    IconData icon,
    int value,
    String label, {
    String suffix = '',
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        AppSpacing.vXs,
        AnimatedCount(
          value,
          suffix: suffix,
          countUp: true,
          style: context.text.headlineSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: context.text.labelMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.75),
          ),
        ),
      ],
    );
  }

  Widget _buildTripCard(TripHistory history) {
    final c = context.colors;
    final trip = history.trip;
    final isCompleted = trip.isCompleted;

    // Calculate trip duration
    final duration = trip.endTime?.difference(trip.startTime);
    final durationText = duration != null
        ? duration.inHours > 0
              ? '${duration.inHours}h ${duration.inMinutes.remainder(60)}m'
              : '${duration.inMinutes}m'
        : '--';

    Widget meta(IconData icon, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: c.textMuted),
        const SizedBox(width: 6),
        Text(
          text,
          style: context.text.bodySmall?.copyWith(color: c.textSecondary),
        ),
      ],
    );

    return AppCard(
      onTap: () => Navigator.pushNamed(
        context,
        '/trip-details',
        arguments: {'tripId': trip.id, 'history': history},
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Flies into the trip details header.
              Hero(
                tag: 'trip-badge-${trip.id}',
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: isCompleted ? c.brandGradient : c.accentGradient,
                    borderRadius: AppRadius.brSm,
                  ),
                  child: const Icon(
                    Icons.directions_bus_rounded,
                    color: Colors.white,
                  ),
                ),
              ),
              AppSpacing.hSm,
              Expanded(
                child: Text(
                  trip.routeName,
                  style: context.text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              StatusPill(
                label: isCompleted ? 'Completed' : 'Active',
                color: isCompleted ? c.brand : c.warning,
                pulse: !isCompleted,
                dense: true,
              ),
            ],
          ),
          AppSpacing.vSm,
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            children: [
              meta(Icons.calendar_today_rounded, _formatDate(trip.startTime)),
              meta(Icons.access_time_rounded, _formatTime(trip.startTime)),
              meta(Icons.timer_outlined, durationText),
              if (trip.vehicleNumber != null)
                meta(Icons.directions_bus_outlined, trip.vehicleNumber!),
            ],
          ),
          AppSpacing.vSm,
          Divider(height: 1, color: c.outline),
          AppSpacing.vSm,
          Row(
            children: [
              Expanded(
                child: TripProgress.bar(
                  done: trip.pickedCount,
                  total: trip.students.length,
                  thickness: 6,
                ),
              ),
              AppSpacing.hSm,
              Text(
                '${trip.pickedCount}/${trip.students.length} students',
                style: context.text.labelMedium?.copyWith(
                  color: c.brand,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (history.attendantName != null) ...[
            AppSpacing.vXs,
            meta(Icons.person_outline_rounded, 'Att: ${history.attendantName}'),
          ],
        ],
      ),
    );
  }
}
