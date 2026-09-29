import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api/services/trip_service.dart';
import '../../providers/auth_provider.dart';
import '../../services/guardian_trip_notification_service.dart';
import '../../services/trip_history_service.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme_extension.dart';
import '../../widgets/main_scaffold.dart';
import '../../widgets/ui/ui.dart';

/// Model for guardian trip history entry
/// Groups students by trip so shared trips appear together
class GuardianTripHistoryEntry {
  final String tripId;
  final String routeName;
  final DateTime tripDate;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? vehicleNumber;
  final String status;
  final List<StudentTripInfo> students;

  GuardianTripHistoryEntry({
    required this.tripId,
    required this.routeName,
    required this.tripDate,
    this.startTime,
    this.endTime,
    this.vehicleNumber,
    required this.status,
    required this.students,
  });

  /// Calculate trip duration
  Duration? get duration {
    if (startTime != null && endTime != null) {
      return endTime!.difference(startTime!);
    }
    return null;
  }

  String get formattedDuration {
    final d = duration;
    if (d == null) return '--';
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}

/// Student info within a trip history entry
class StudentTripInfo {
  final String studentId;
  final String name;
  final String? photo;
  final String status;
  final DateTime? pickupTime;
  final DateTime? dropoffTime;

  StudentTripInfo({
    required this.studentId,
    required this.name,
    this.photo,
    required this.status,
    this.pickupTime,
    this.dropoffTime,
  });
}

/// Guardian Trips Screen - Shows ACTIVE trips and TRIP HISTORY for guardian's students
class GuardianTripsScreen extends StatefulWidget {
  const GuardianTripsScreen({super.key});

  @override
  State<GuardianTripsScreen> createState() => _GuardianTripsScreenState();
}

class _GuardianTripsScreenState extends State<GuardianTripsScreen>
    with SingleTickerProviderStateMixin {
  final TripService _tripService = TripService();
  final TripHistoryService _historyService = TripHistoryService();

  // Tab controller for Active vs History tabs
  late TabController _tabController;

  // Active trip state
  Trip? _activeTrip;
  List<StudentPickup> _myStudents = [];
  bool _isLoadingActive = true;
  String? _activeTripError;

  // History state
  List<GuardianTripHistoryEntry> _tripHistory = [];
  bool _isLoadingHistory = true;
  String? _historyError;

  // Live MQTT student-status updates
  StreamSubscription<GuardianStudentStatusEvent>? _statusSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadActiveTrip();
    _loadTripHistory();

    // Reflect live pick/drop/absent updates pushed by the driver over MQTT.
    _statusSub = GuardianTripNotificationService().updates.listen(
      _onStudentStatusEvent,
    );
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  /// Patch the on-screen active trip when a live status update arrives so the
  /// guardian sees the change without a manual refresh.
  void _onStudentStatusEvent(GuardianStudentStatusEvent event) {
    if (!mounted) return;
    final hasStudent = _myStudents.any((s) => s.id == event.studentId);
    if (!hasStudent) return;

    setState(() {
      _myStudents = _myStudents
          .map(
            (s) =>
                s.id == event.studentId ? s.copyWith(status: event.status) : s,
          )
          .toList();

      final trip = _activeTrip;
      if (trip != null) {
        _activeTrip = trip.copyWith(
          students: trip.students
              .map(
                (s) => s.id == event.studentId
                    ? s.copyWith(status: event.status)
                    : s,
              )
              .toList(),
        );
      }
    });
  }

  void _onTabChanged() {
    // Keep the segmented filter in step with swipes between tabs.
    if (mounted) setState(() {});
    if (_tabController.index == 1 &&
        _tripHistory.isEmpty &&
        !_isLoadingHistory) {
      _loadTripHistory();
    }
  }

  Future<void> _loadActiveTrip() async {
    setState(() {
      _isLoadingActive = true;
      _activeTripError = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final guardianPhone = authProvider.userPhone;

      if (guardianPhone == null || guardianPhone.isEmpty) {
        setState(() {
          _activeTripError = 'Phone number not found. Please log in again.';
          _isLoadingActive = false;
        });
        return;
      }

      // Fetch active trip for this guardian
      final trip = await _tripService.getActiveTrip(
        guardianPhone: guardianPhone,
      );

      if (mounted) {
        setState(() {
          _activeTrip = trip;
          _isLoadingActive = false;
        });

        // If there's an active trip, filter students for this guardian
        if (trip != null) {
          _filterMyStudents(trip, guardianPhone);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _activeTripError = 'Failed to load trip information';
          _isLoadingActive = false;
        });
      }
    }
  }

  /// Load trip history for this guardian's students
  /// Groups students by trip so shared trips appear together
  Future<void> _loadTripHistory() async {
    setState(() {
      _isLoadingHistory = true;
      _historyError = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final guardianPhone = authProvider.userPhone;

      if (guardianPhone == null || guardianPhone.isEmpty) {
        setState(() {
          _historyError = 'Phone number not found';
          _isLoadingHistory = false;
        });
        return;
      }

      // Get all trips from history service
      // Note: In a real implementation, you might want to add a specific
      // API endpoint for guardian trip history. For now, we simulate with local data.
      final allTrips = await _historyService.getAllTripsForGuardian(
        guardianPhone,
      );

      // Group trips by trip ID and filter for this guardian's students
      final Map<String, GuardianTripHistoryEntry> tripMap = {};

      for (final tripHistory in allTrips) {
        final trip = tripHistory.trip;

        // Filter students belonging to this guardian
        final myStudentsInTrip = trip.students.where((student) {
          return student.parentPhone == guardianPhone ||
              student.parentPhone?.replaceAll(RegExp(r'[^0-9]'), '') ==
                  guardianPhone.replaceAll(RegExp(r'[^0-9]'), '');
        }).toList();

        // Skip if no students from this guardian are in this trip
        if (myStudentsInTrip.isEmpty) continue;

        // Group by trip ID - if trip already exists, add students to it
        if (tripMap.containsKey(trip.id)) {
          final existingEntry = tripMap[trip.id]!;
          final newStudents = myStudentsInTrip
              .map(
                (s) => StudentTripInfo(
                  studentId: s.id,
                  name: s.name,
                  photo: s.photo,
                  status: s.status,
                  pickupTime: s.pickupTime,
                  dropoffTime: s.dropoffTime,
                ),
              )
              .toList();

          tripMap[trip.id] = GuardianTripHistoryEntry(
            tripId: trip.id,
            routeName: trip.routeName,
            tripDate: trip.startTime,
            startTime: trip.startTime,
            endTime: trip.endTime,
            vehicleNumber: trip.vehicleNumber,
            status: trip.status,
            students: [...existingEntry.students, ...newStudents],
          );
        } else {
          // Create new entry
          tripMap[trip.id] = GuardianTripHistoryEntry(
            tripId: trip.id,
            routeName: trip.routeName,
            tripDate: trip.startTime,
            startTime: trip.startTime,
            endTime: trip.endTime,
            vehicleNumber: trip.vehicleNumber,
            status: trip.status,
            students: myStudentsInTrip
                .map(
                  (s) => StudentTripInfo(
                    studentId: s.id,
                    name: s.name,
                    photo: s.photo,
                    status: s.status,
                    pickupTime: s.pickupTime,
                    dropoffTime: s.dropoffTime,
                  ),
                )
                .toList(),
          );
        }
      }

      if (mounted) {
        setState(() {
          _tripHistory = tripMap.values.toList()
            ..sort((a, b) => b.tripDate.compareTo(a.tripDate));
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _historyError = 'Failed to load trip history';
          _isLoadingHistory = false;
        });
      }
    }
  }

  void _filterMyStudents(Trip trip, String guardianPhone) {
    // Filter students whose parent phone matches the guardian's phone
    setState(() {
      _myStudents = trip.students.where((student) {
        return student.parentPhone == guardianPhone ||
            student.parentPhone?.replaceAll(RegExp(r'[^0-9]'), '') ==
                guardianPhone.replaceAll(RegExp(r'[^0-9]'), '');
      }).toList();
    });
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

  String _getTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      title: 'My Trips',
      showBackButton: true,
      showBottomNav: true,
      bottomNavIndex: 3,
      body: Stack(
        children: [
          const Positioned.fill(child: AppBackdrop()),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.xs,
                ),
                child: SegmentedFilter(
                  selected: _tabController.index,
                  onChanged: _tabController.animateTo,
                  segments: [
                    FilterSegment('Active', count: _activeTrip == null ? 0 : 1),
                    FilterSegment('History', count: _tripHistory.length),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    AsyncBody(
                      loading: _isLoadingActive,
                      error: _activeTripError,
                      onRetry: _loadActiveTrip,
                      isEmpty: _activeTrip == null,
                      empty: EmptyState(
                        icon: Icons.local_shipping_outlined,
                        title: 'No Active Trips',
                        message:
                            'There are no active trips involving your '
                            'children at the moment.',
                        actionLabel: 'Check Again',
                        onAction: _loadActiveTrip,
                      ),
                      onRefresh: _loadActiveTrip,
                      child: _buildActiveTab(),
                    ),
                    AsyncBody(
                      loading: _isLoadingHistory,
                      error: _historyError,
                      onRetry: _loadTripHistory,
                      isEmpty: _tripHistory.isEmpty,
                      empty: const EmptyState(
                        icon: Icons.history_rounded,
                        title: 'No Trip History',
                        message:
                            'Completed trips involving your students will '
                            'appear here.',
                      ),
                      onRefresh: _loadTripHistory,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: _tripHistory.length,
                        separatorBuilder: (_, _) => AppSpacing.vMd,
                        itemBuilder: (context, index) => _buildHistoryCard(
                          _tripHistory[index],
                        ).enterList(index),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTab() {
    if (_activeTrip == null) return const SizedBox.shrink();
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        _buildActiveTripHeader().enter(),
        AppSpacing.vXl,
        _buildMyStudentsSection(),
        AppSpacing.vXl,
        _buildLiveTrackingButton().enterList(3),
        AppSpacing.vXxl,
      ],
    );
  }

  Widget _buildActiveTripHeader() {
    final trip = _activeTrip!;
    final picked = _myStudents.where((s) => s.status == 'picked').length;
    final meta = context.text.bodyMedium?.copyWith(
      color: Colors.white.withValues(alpha: 0.9),
    );

    return GradientHeroCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const StatusPill(
                      label: 'TRIP IN PROGRESS',
                      color: Colors.white,
                      pulse: true,
                      dense: true,
                    ),
                    AppSpacing.hXs,
                    Flexible(
                      child: Text(
                        _getTimeAgo(trip.startTime),
                        overflow: TextOverflow.ellipsis,
                        style: context.text.labelMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
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
                AppSpacing.vSm,
                Row(
                  children: [
                    const Icon(
                      Icons.directions_bus_rounded,
                      color: Colors.white70,
                      size: 18,
                    ),
                    AppSpacing.hXs,
                    Text(trip.vehicleNumber ?? 'School Bus', style: meta),
                  ],
                ),
                AppSpacing.vXxs,
                Row(
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      color: Colors.white70,
                      size: 18,
                    ),
                    AppSpacing.hXs,
                    Text(
                      'Started: ${_formatTime(trip.startTime)}',
                      style: meta,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_myStudents.isNotEmpty) ...[
            AppSpacing.hMd,
            TripProgress.ring(
              done: picked,
              total: _myStudents.length,
              onBrand: true,
              size: 72,
              thickness: 7,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMyStudentsSection() {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: SectionHeader(title: 'My Students')),
            StatusPill(
              label: '${_myStudents.length} on this trip',
              color: c.brand,
              showDot: false,
              dense: true,
            ),
          ],
        ).enterList(1),
        AppSpacing.vSm,
        if (_myStudents.isEmpty)
          AppCard(
            color: c.surfaceSubtle,
            shadow: const [],
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: c.textMuted),
                AppSpacing.hSm,
                Expanded(
                  child: Text(
                    'No students from your account on this trip',
                    style: context.text.bodyMedium?.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          for (final (i, student) in _myStudents.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              // Live MQTT pushes flip the status in place: the ring recolours
              // and the pill cross-fades, so the parent sees it happen.
              child: StudentStatusRow(
                key: ValueKey(student.id),
                name: student.name,
                photoUrl: student.photo,
                status: student.status,
                subtitle: student.pickupTime == null
                    ? null
                    : '${student.status == 'picked' ? 'Picked up at' : 'Status updated'} '
                          '${_formatTime(student.pickupTime!)}',
              ).enterList(i + 2),
            ),
      ],
    );
  }

  Widget _buildLiveTrackingButton() {
    return AppButton(
      label: 'Live Track Bus',
      icon: Icons.location_on_rounded,
      onPressed: () {
        Navigator.pushNamed(
          context,
          '/osm-tracking',
          arguments: {
            'tripId': _activeTrip?.id ?? 'TRIP_001',
            'busId': _activeTrip?.vehicleId ?? 'BUS001',
            'routeId': _activeTrip?.routeId ?? 'ROUTE_001',
          },
        );
      },
    );
  }

  /// A history card that groups this guardian's students by trip, with each
  /// student's pick and drop times.
  Widget _buildHistoryCard(GuardianTripHistoryEntry entry) {
    final c = context.colors;
    final isCompleted = entry.status == 'completed';
    final tone = isCompleted ? c.brand : c.warning;

    return AppCard(
      padding: EdgeInsets.zero,
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  tone,
                  Color.alphaBlend(Colors.black.withValues(alpha: 0.22), tone),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StatusPill(
                      label: isCompleted ? 'Completed' : 'In Progress',
                      color: Colors.white,
                      showDot: !isCompleted,
                      icon: isCompleted ? Icons.check_circle_rounded : null,
                      dense: true,
                    ),
                    const Spacer(),
                    Text(
                      _formatDate(entry.tripDate),
                      style: context.text.labelMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
                AppSpacing.vSm,
                Text(
                  entry.routeName,
                  style: context.text.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                AppSpacing.vXxs,
                Row(
                  children: [
                    const Icon(
                      Icons.directions_bus_rounded,
                      color: Colors.white70,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      entry.vehicleNumber ?? 'School Bus',
                      style: context.text.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: StatTile(
                      icon: Icons.play_circle_outline_rounded,
                      value: entry.startTime != null
                          ? _formatTime(entry.startTime!)
                          : '--:--',
                      label: 'Start',
                      color: c.brand,
                    ),
                  ),
                  VerticalDivider(color: c.outline, width: 1),
                  Expanded(
                    child: StatTile(
                      icon: Icons.stop_circle_outlined,
                      value: entry.endTime != null
                          ? _formatTime(entry.endTime!)
                          : '--:--',
                      label: 'End',
                      color: c.brand,
                    ),
                  ),
                  VerticalDivider(color: c.outline, width: 1),
                  Expanded(
                    child: StatTile(
                      icon: Icons.timer_outlined,
                      value: entry.formattedDuration,
                      label: 'Duration',
                      color: c.accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Students (${entry.students.length})',
                  style: context.text.labelLarge,
                ),
                AppSpacing.vSm,
                for (final student in entry.students)
                  _buildHistoryStudentItem(student),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Student row with pick and drop times for history.
  Widget _buildHistoryStudentItem(StudentTripInfo student) {
    final c = context.colors;
    final settled = student.status == 'picked' || student.status == 'dropped';
    final (Color color, IconData icon, String label) = settled
        ? (c.success, Icons.check_circle_rounded, 'Completed')
        : student.status == 'absent'
        ? (c.warning, Icons.cancel_rounded, 'Absent')
        : (c.textMuted, Icons.schedule_rounded, 'Pending');
    final time = context.text.labelSmall?.copyWith(color: c.textMuted);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: c.surfaceSubtle,
        borderRadius: AppRadius.brSm,
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          StatusAvatar(
            name: student.name,
            photoUrl: student.photo,
            color: color,
            size: 40,
          ),
          AppSpacing.hSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  style: context.text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                AppSpacing.vXxs,
                Row(
                  children: [
                    if (student.pickupTime != null) ...[
                      Icon(Icons.login_rounded, size: 12, color: c.textMuted),
                      const SizedBox(width: 4),
                      Text(_formatTime(student.pickupTime!), style: time),
                    ],
                    if (student.pickupTime != null &&
                        student.dropoffTime != null)
                      Text(' → ', style: time),
                    if (student.dropoffTime != null) ...[
                      Icon(Icons.logout_rounded, size: 12, color: c.textMuted),
                      const SizedBox(width: 4),
                      Text(_formatTime(student.dropoffTime!), style: time),
                    ],
                  ],
                ),
              ],
            ),
          ),
          StatusPill(label: label, color: color, icon: icon, dense: true),
        ],
      ),
    );
  }
}
