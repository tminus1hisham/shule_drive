import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../main.dart';
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/trip_provider.dart';
import '../../api/services/trip_service.dart';
import '../../models/master_trip.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme_extension.dart';
import '../../utils/next_trip_selector.dart';
import '../../widgets/main_scaffold.dart';
import '../../widgets/bus_illustration.dart';
import '../../widgets/ui/ui.dart';

/// Unified Dashboard - Single home screen that adapts based on role and trip status
///
/// Driver View:
/// - No active trip: Shows "Start Trip" CTA
/// - Active trip: Shows live trip progress, students list, end trip button
///
/// Guardian View:
/// - No active trip: Shows upcoming trips, children status
/// - Active trip: Shows child's pickup status, bus location, ETA
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with RouteAware, WidgetsBindingObserver {
  // Timer for periodic refresh
  Timer? _refreshTimer;

  // Trip duration timer
  Timer? _durationTimer;
  Duration _tripDuration = Duration.zero;

  // Next scheduled master trip (for idle dashboard)
  ScheduledMasterTrip? _nextScheduledTrip;

  // Refresh interval (30 seconds)
  static const Duration _refreshInterval = Duration(seconds: 30);

  // Flag to prevent multiple master trip checks
  bool _hasCheckedMasterTrips = false;
  bool _isCheckingMasterTrips = false;

  // Flag: came from trip end (skip auto-redirect to trip selection)
  bool _fromTripEnd = false;

  // Upcoming trip prompt
  Timer? _upcomingTripTimer;
  final Set<int> _promptedTripIds = {};
  bool _isShowingUpcomingPrompt = false;

  @override
  void initState() {
    super.initState();

    _startPeriodicRefresh();
    // Subscribe to app lifecycle
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Check if we arrived from trip end
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map && args['fromTripEnd'] == true) {
        _fromTripEnd = true;
        debugPrint(
          '📍 Dashboard: Arrived from trip end, skipping auto-redirect',
        );
      }
      _initDashboard();
    });
  }

  /// Initial dashboard flow: fetch the active trip first, and if the driver
  /// has one running, resume it immediately on the live trip screen.
  /// Only when there is no active trip do we check for scheduled master trips.
  Future<void> _initDashboard() async {
    // Make sure the autoload preference is read before we decide whether to
    // jump the driver straight into their scheduled trips.
    await context.read<AppProvider>().ensurePreferencesLoaded();
    await _loadData();
    if (!mounted) return;

    final authProvider = context.read<AuthProvider>();
    final tripProvider = context.read<TripProvider>();
    final activeTrip = tripProvider.activeTrip;

    if (authProvider.isDriver && activeTrip != null && !_fromTripEnd) {
      debugPrint('🚌 Active trip found on open, resuming: ${activeTrip.id}');
      Navigator.pushNamed(
        context,
        '/osm-tracking',
        arguments: {'tripId': activeTrip.id, 'preloadedData': null},
      );
      return;
    }

    _checkMasterTripsForDriver();
    _startUpcomingTripChecker();
  }

  /// Check if driver has master trips and redirect accordingly
  Future<void> _checkMasterTripsForDriver() async {
    if (_hasCheckedMasterTrips || _isCheckingMasterTrips) {
      debugPrint(
        '🔍 Master trip check already performed or in progress, skipping',
      );
      return;
    }

    setState(() => _isCheckingMasterTrips = true);

    final authProvider = context.read<AuthProvider>();

    debugPrint('🔍 =========================================');
    debugPrint('🔍 CHECKING MASTER TRIPS FOR DRIVER');
    debugPrint('🔍 =========================================');
    debugPrint('🔍 isDriver: ${authProvider.isDriver}');
    debugPrint('🔍 User role: ${authProvider.userRole}');
    debugPrint('🔍 User role from data: ${authProvider.userData['role']}');
    debugPrint('🔍 Current user ID: ${authProvider.currentUser?.id}');
    debugPrint('🔍 Current user name: ${authProvider.currentUser?.name}');

    // Only check for drivers
    if (!authProvider.isDriver) {
      debugPrint(
        '🔍 User is NOT a driver (role: ${authProvider.userRole}), skipping check',
      );
      setState(() {
        _hasCheckedMasterTrips = true;
        _isCheckingMasterTrips = false;
      });
      return;
    }

    // Driver opted out of autoload - they open scheduled trips themselves
    if (!context.read<AppProvider>().autoloadTrips) {
      debugPrint('🔍 Autoload is off, skipping master trip check');
      setState(() {
        _hasCheckedMasterTrips = true;
        _isCheckingMasterTrips = false;
      });
      return;
    }

    // Check if there's an active trip - if so, skip master trip check
    final tripProvider = context.read<TripProvider>();
    if (tripProvider.activeTrip != null) {
      debugPrint('🔍 Active trip exists, skipping master trip check');
      setState(() {
        _hasCheckedMasterTrips = true;
        _isCheckingMasterTrips = false;
      });
      return;
    }

    try {
      final tripService = TripService();
      final driverId = authProvider.currentUser?.id;

      debugPrint('🔍 Driver ID: $driverId');

      if (driverId == null || driverId.isEmpty) {
        debugPrint('❌ Driver ID is null or empty');
        setState(() {
          _hasCheckedMasterTrips = true;
          _isCheckingMasterTrips = false;
        });
        return;
      }

      debugPrint('🔍 Calling API: getMasterTripsByDriverCached($driverId)');

      // Use cache-first pattern - shows cached trips immediately while fetching fresh data
      MasterTrip? firstTrip;
      final masterTrips = await tripService.getMasterTripsByDriverCached(
        driverId,
        onRefresh: (freshTrips) {
          debugPrint('🔄 Background refresh: ${freshTrips.length} trips');
          // Only redirect on background refresh if NOT coming from trip end
          if (freshTrips.isNotEmpty && mounted && !_fromTripEnd) {
            if (firstTrip == null) {
              debugPrint(
                '✅ Fresh data available, redirecting to trip selection',
              );
              Navigator.pushReplacementNamed(context, '/trip-selection');
            }
          }
        },
      );

      // Save first trip for comparison
      if (masterTrips.isNotEmpty) {
        firstTrip = masterTrips.first;
      }

      debugPrint(
        '🔍 Loaded ${masterTrips.length} master trips (from cache or API)',
      );
      for (final trip in masterTrips) {
        debugPrint(
          '  - ${trip.tripName} (ID: ${trip.id}, Route: ${trip.route})',
        );
      }

      if (!mounted) {
        debugPrint('🔍 Widget not mounted');
        return;
      }

      if (masterTrips.isNotEmpty && !_fromTripEnd) {
        debugPrint('✅ Redirecting to trip selection screen');

        // Redirect to trip selection screen
        Navigator.pushReplacementNamed(context, '/trip-selection');
      } else {
        if (_fromTripEnd) {
          debugPrint('📍 Skipping auto-redirect (came from trip end)');
        } else {
          debugPrint('ℹ️ No master trips found');
        }
        setState(() {
          _hasCheckedMasterTrips = true;
          _isCheckingMasterTrips = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error: $e');
      debugPrint('❌ Stack: $stackTrace');
      setState(() {
        _hasCheckedMasterTrips = true;
        _isCheckingMasterTrips = false;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to route observer
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  // ==================== UPCOMING TRIP PROMPT ====================

  /// Start periodic check for upcoming trips (every 30 seconds)
  void _startUpcomingTripChecker() {
    final authProvider = context.read<AuthProvider>();
    if (!authProvider.isDriver) return;

    // Check immediately
    _checkUpcomingTrips();

    // Then check every 30 seconds
    _upcomingTripTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _checkUpcomingTrips(),
    );
  }

  /// Check if any master trip is starting within the next 5 minutes
  Future<void> _checkUpcomingTrips() async {
    if (!mounted || _isShowingUpcomingPrompt) return;

    final authProvider = context.read<AuthProvider>();
    if (!authProvider.isDriver) return;

    final driverId = authProvider.currentUser?.id;
    if (driverId == null || driverId.isEmpty) return;

    try {
      final tripService = TripService();
      final masterTrips = await tripService.getMasterTripsByDriverCached(
        driverId,
        onRefresh: (_) {},
      );

      final now = DateTime.now();

      // Keep the idle dashboard's "next trip" card in step with the clock.
      _updateNextScheduledTrip(masterTrips, now);

      for (final trip in masterTrips) {
        // Skip already-prompted trips
        if (_promptedTripIds.contains(trip.id)) continue;

        final tripDateTime = parseTripTimeOfDay(trip.tripTime, now: now);
        if (tripDateTime == null) continue;

        final diff = tripDateTime.difference(now);

        // Trip starts within 5 minutes (but not in the past by more than 2 min)
        if (diff.inMinutes <= 5 && diff.inMinutes >= -2) {
          _promptedTripIds.add(trip.id);
          if (mounted) {
            _showUpcomingTripPrompt(trip, tripDateTime);
          }
          break; // Only show one prompt at a time
        }
      }
    } catch (e) {
      debugPrint('⚠️ Upcoming trip check error: $e');
    }
  }

  /// Store the trip that is next up for the driver right now, so the idle
  /// dashboard shows the trip the clock has reached rather than whichever one
  /// the API happened to list first.
  void _updateNextScheduledTrip(List<MasterTrip> trips, DateTime now) {
    if (!mounted) return;

    final next = selectNextMasterTrip(trips, now: now);

    // Rebuild whenever there is something to show: the countdown label ages
    // with the clock even when the selected trip is unchanged.
    if (next == null && _nextScheduledTrip == null) return;

    setState(() => _nextScheduledTrip = next);
  }

  /// Show a bottom sheet prompting the driver to start an upcoming trip
  void _showUpcomingTripPrompt(MasterTrip trip, DateTime scheduledTime) {
    if (!mounted) return;
    _isShowingUpcomingPrompt = true;

    final minutesAway = scheduledTime.difference(DateTime.now()).inMinutes;

    showAppBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pulsing icon
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.85, end: 1.0),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeInOut,
            builder: (context, value, child) =>
                Transform.scale(scale: value, child: child),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                gradient: ctx.colors.brandGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: ctx.colors.brand.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.access_time_filled,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            minutesAway > 0
                ? 'Trip starting in $minutesAway min'
                : 'Trip starting now!',
            textAlign: TextAlign.center,
            style: ctx.text.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            color: ctx.colors.surfaceSubtle,
            shadow: const [],
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: ctx.colors.brandSoft,
                    borderRadius: AppRadius.brSm,
                  ),
                  child: Icon(
                    Icons.directions_bus_rounded,
                    color: ctx.colors.brand,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(trip.tripName, style: ctx.text.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        '${trip.route} • ${trip.tripTime}',
                        style: ctx.text.bodySmall?.copyWith(
                          color: ctx.colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Start Now',
            icon: Icons.play_arrow_rounded,
            onPressed: () {
              Navigator.pop(ctx);
              _isShowingUpcomingPrompt = false;
              Navigator.pushNamed(
                context,
                '/trip-selection',
                arguments: {'autoSelectTripId': trip.id},
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'View All Trips',
            icon: Icons.list_alt_rounded,
            variant: AppButtonVariant.outline,
            onPressed: () {
              Navigator.pop(ctx);
              _isShowingUpcomingPrompt = false;
              Navigator.pushNamed(context, '/trip-selection');
            },
          ),
          const SizedBox(height: AppSpacing.xs),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _isShowingUpcomingPrompt = false;
            },
            child: const Text('Dismiss'),
          ),
        ],
      ),
    ).whenComplete(() => _isShowingUpcomingPrompt = false);
  }

  @override
  void dispose() {
    // Stop timers and unsubscribe
    _refreshTimer?.cancel();
    _durationTimer?.cancel();
    _upcomingTripTimer?.cancel();
    routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh when app comes to foreground
    if (state == AppLifecycleState.resumed) {
      _refresh();
      _startPeriodicRefresh();
    } else if (state == AppLifecycleState.paused) {
      // Stop timer when app is in background
      _refreshTimer?.cancel();
    }
  }

  /// Called when the route is popped and this screen becomes visible again
  @override
  void didPopNext() {
    // Reload data when coming back from another screen
    _refresh();
  }

  /// Start periodic refresh timer
  void _startPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      if (mounted) {
        _refresh();
      }
    });
  }

  Future<void> _loadData() async {
    final tripProvider = context.read<TripProvider>();
    final authProvider = context.read<AuthProvider>();

    if (kDebugMode) {
      print('📱 Dashboard _loadData:');
      print('  isGuardian: ${authProvider.isGuardian}');
      print('  isDriver: ${authProvider.isDriver}');
      print('  userPhone: ${authProvider.userPhone}');
    }

    // Both guardians and drivers can fetch active trips
    if (authProvider.isGuardian) {
      final hasPhone =
          authProvider.userPhone != null && authProvider.userPhone!.isNotEmpty;
      if (hasPhone) {
        await tripProvider.fetchActiveTrip(
          guardianPhone: authProvider.userPhone,
        );
      }
    } else if (authProvider.isDriver) {
      await tripProvider.fetchActiveTrip(
        driverId: authProvider.currentUser?.id,
      );
    }

    // For drivers: start duration timer if active trip, load next scheduled trip
    if (authProvider.isDriver) {
      if (tripProvider.activeTrip != null) {
        _startDurationTimer(tripProvider);
      }
      _loadNextScheduledTrip(authProvider);
    }
  }

  /// Start a timer that ticks every second to update trip duration
  void _startDurationTimer(TripProvider tripProvider) {
    _durationTimer?.cancel();
    final activeTrip = tripProvider.activeTrip;
    if (activeTrip == null) return;

    // Calculate initial duration from trip start
    _tripDuration = DateTime.now().difference(activeTrip.startTime);

    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _tripDuration += const Duration(seconds: 1);
        });
      }
    });
  }

  /// Load next scheduled master trip for the idle dashboard
  Future<void> _loadNextScheduledTrip(AuthProvider authProvider) async {
    try {
      final driverId = authProvider.currentUser?.id;
      if (driverId == null || driverId.isEmpty) return;

      final tripService = TripService();
      final trips = await tripService.getMasterTripsByDriverCached(
        driverId,
        onRefresh: (_) {},
      );

      _updateNextScheduledTrip(trips, DateTime.now());
    } catch (e) {
      if (kDebugMode) print('Failed to load next trip: $e');
    }
  }

  /// Format duration as HH:MM or MM:SS
  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _refresh() async {
    final tripProvider = context.read<TripProvider>();
    final authProvider = context.read<AuthProvider>();

    if (kDebugMode) {
      print('📱 Dashboard _refresh:');
      print('  isGuardian: ${authProvider.isGuardian}');
      print('  isDriver: ${authProvider.isDriver}');
      print('  userPhone: ${authProvider.userPhone}');
    }

    // Fetch active trips for both
    if (authProvider.isGuardian) {
      final hasPhone =
          authProvider.userPhone != null && authProvider.userPhone!.isNotEmpty;
      if (hasPhone) {
        await tripProvider.fetchActiveTrip(
          guardianPhone: authProvider.userPhone,
        );
      }
    } else if (authProvider.isDriver) {
      await tripProvider.fetchActiveTrip(
        driverId: authProvider.currentUser?.id,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final authProvider = context.watch<AuthProvider>();
    final tripProvider = context.watch<TripProvider>();
    final userData = authProvider.userData;
    final isDriver = authProvider.isDriver;
    final isGuardian = authProvider.isGuardian;
    final hasActiveTrip = tripProvider.activeTrip != null;

    return MainScaffold(
      showBottomNav: true,
      bottomNavIndex: 0,
      onBottomNavTap: (index) => _handleNavigation(index, isDriver),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _refresh,
            color: context.colors.brand,
            child: SafeArea(
              bottom: false,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildTopBar(userData, appProvider)),
                  SliverToBoxAdapter(
                    child: _buildGreeting(userData, isDriver, hasActiveTrip),
                  ),

                  // Primary content — adapts to role and live trip status.
                  if (isDriver)
                    ..._driverSlivers(tripProvider, hasActiveTrip)
                  else if (isGuardian)
                    ..._guardianSlivers(tripProvider, hasActiveTrip),

                  SliverToBoxAdapter(child: _buildQuickActions(isDriver)),

                  const SliverPadding(
                    padding: EdgeInsets.only(bottom: AppSpacing.xxl),
                  ),
                ],
              ),
            ),
          ),
          if (_isCheckingMasterTrips) _buildCheckingOverlay(),
        ],
      ),
    );
  }

  /// Horizontal screen gutter shared by every dashboard block, so the whole
  /// page lines up on one vertical rhythm.
  Widget _block({required Widget child, double top = 0}) => Padding(
    padding: EdgeInsets.fromLTRB(AppSpacing.lg, top, AppSpacing.lg, 0),
    child: child,
  );

  List<Widget> _driverSlivers(TripProvider tripProvider, bool hasActiveTrip) {
    if (hasActiveTrip) {
      return [
        SliverToBoxAdapter(child: _block(child: _buildDriverActiveTrip(tripProvider))),
      ];
    }
    return [
      SliverToBoxAdapter(child: _block(child: _buildDriverStartTrip())),
      if (_nextScheduledTrip != null)
        SliverToBoxAdapter(
          child: _block(top: AppSpacing.sm, child: _buildNextTripCard()),
        ),
    ];
  }

  List<Widget> _guardianSlivers(TripProvider tripProvider, bool hasActiveTrip) {
    if (!hasActiveTrip) {
      return [SliverToBoxAdapter(child: _block(child: _buildGuardianIdle()))];
    }
    return [
      SliverToBoxAdapter(child: _block(child: _buildGuardianActiveTrip(tripProvider))),
    ];
  }

  Widget _buildCheckingOverlay() {
    return Positioned.fill(
      child: ColoredBox(
        color: context.scheme.surface.withValues(alpha: 0.82),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: context.colors.brand),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Checking for scheduled trips...',
                style: context.text.labelLarge?.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Navigate to the start-trip flow, but never while a trip is running.
  /// If a trip is active, redirect to the live trip screen instead.
  void _goToStartTrip() {
    final activeTrip = context.read<TripProvider>().activeTrip;
    if (activeTrip != null) {
      AppSnackbar.info(
        context,
        'A trip is already in progress. End it before starting a new one.',
      );
      Navigator.pushNamed(
        context,
        '/osm-tracking',
        arguments: {'tripId': activeTrip.id, 'preloadedData': null},
      );
      return;
    }
    Navigator.pushNamed(context, '/start-trip');
  }

  void _handleNavigation(int index, bool isDriver) {
    switch (index) {
      case 0:
        // Already on home - refresh data instead
        _refresh();
        break;
      case 1:
        Navigator.pushNamed(context, '/chat');
        break;
      case 2:
        Navigator.pushNamed(context, '/notifications');
        break;
      case 3:
        Navigator.pushNamed(context, '/profile');
        break;
      case 4:
        if (isDriver) {
          _goToStartTrip();
        }
        break;
    }
  }

  // ==================== TOP BAR & GREETING ====================

  /// Slim app bar: drawer, wordmark, notifications and profile. Kept to a
  /// single 44pt row so the greeting below is the first thing that reads.
  Widget _buildTopBar(Map<String, dynamic> userData, AppProvider appProvider) {
    final unread = appProvider.unreadAlertCount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.lg,
        0,
      ),
      child: Row(
        children: [
          Builder(
            builder: (context) => _CircleIconButton(
              icon: Icons.menu_rounded,
              tooltip: 'Menu',
              onTap: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: context.colors.brandGradient,
              borderRadius: AppRadius.brSm,
            ),
            child: const Icon(
              Icons.directions_bus_rounded,
              color: Colors.white,
              size: AppIconSize.md,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              'ShuleDrive',
              style: context.text.titleLarge?.copyWith(fontSize: 18),
            ),
          ),
          _CircleIconButton(
            icon: Icons.notifications_none_rounded,
            tooltip: 'Notifications',
            badgeCount: unread,
            onTap: () => Navigator.pushNamed(context, '/notifications'),
          ),
          const SizedBox(width: AppSpacing.xs),
          AppAvatar(
            imageUrl: userData['avatar'] as String?,
            name: userData['name'] as String?,
            size: 40,
            heroTag: 'profile_avatar',
            borderColor: context.scheme.surface,
            onTap: () => Navigator.pushNamed(context, '/profile'),
          ),
        ],
      ),
    );
  }

  Widget _buildGreeting(
    Map<String, dynamic> userData,
    bool isDriver,
    bool hasActiveTrip,
  ) {
    final now = DateTime.now();
    final hour = now.hour;
    final String greeting;
    if (hour < 12) {
      greeting = 'Good morning';
    } else if (hour < 17) {
      greeting = 'Good afternoon';
    } else {
      greeting = 'Good evening';
    }

    final String subtitle;
    if (isDriver) {
      subtitle = hasActiveTrip
          ? 'Trip in progress — drive safe.'
          : 'Ready to start your next trip?';
    } else {
      subtitle = hasActiveTrip
          ? 'Your child\'s bus is on the way.'
          : 'Track your child\'s journey safely.';
    }

    final firstName = (userData['name'] as String?)?.split(' ').first ?? 'there';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _MetaChip(
                icon: Icons.calendar_today_rounded,
                label: DateFormat('EEE, d MMM').format(now),
              ),
              const SizedBox(width: AppSpacing.xs),
              _MetaChip(
                icon: isDriver
                    ? Icons.local_shipping_rounded
                    : Icons.family_restroom_rounded,
                label: isDriver ? 'Driver' : 'Guardian',
                tint: context.colors.brand,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '$greeting,',
            style: context.text.bodyLarge?.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
          Text(firstName, style: context.text.displaySmall),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            subtitle,
            style: context.text.bodyMedium?.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== DRIVER VIEWS ====================

  /// Idle driver hero. The scheduled-trip details moved out to their own
  /// "Up next" card so this stays a single, unambiguous call to action.
  Widget _buildDriverStartTrip() {
    return GradientHeroCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.directions_bus_rounded,
                  color: Colors.white,
                  size: AppIconSize.xl,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ready to roll',
                      style: context.text.headlineSmall?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Begin your route and get every student there safely.',
                      style: context.text.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Start Trip',
            icon: Icons.play_arrow_rounded,
            variant: AppButtonVariant.onBrand,
            onPressed: _goToStartTrip,
          ),
        ],
      ),
    );
  }

  /// The driver's next scheduled master trip, promoted to its own tappable row
  /// so the countdown is scannable at a glance.
  Widget _buildNextTripCard() {
    final next = _nextScheduledTrip!;
    return AppCard(
      onTap: () => Navigator.pushNamed(
        context,
        '/trip-selection',
        arguments: {'autoSelectTripId': next.trip.id},
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              color: context.colors.accentSoft,
              borderRadius: AppRadius.brSm,
            ),
            child: Icon(
              Icons.schedule_rounded,
              color: context.colors.accent,
              size: AppIconSize.lg,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'UP NEXT',
                  style: context.text.labelSmall?.copyWith(
                    color: context.colors.textMuted,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  next.trip.tripName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  '${next.trip.route} • ${next.trip.tripTime}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall?.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          StatusPill(
            label: formatNextTripCountdown(next),
            color: context.colors.accent,
            showDot: false,
            dense: true,
          ),
        ],
      ),
    );
  }

  Widget _buildDriverActiveTrip(TripProvider tripProvider) {
    final trip = tripProvider.activeTrip!;
    final pickedCount = trip.students.where((s) => s.status == 'picked').length;
    final totalCount = trip.students.length;
    final progress = totalCount > 0 ? pickedCount / totalCount : 0.0;

    // Ensure duration timer is running
    if (_durationTimer == null || !_durationTimer!.isActive) {
      _startDurationTimer(tripProvider);
    }

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      shadow: context.colors.shadowMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: context.colors.brandSoft,
                  borderRadius: AppRadius.brSm,
                ),
                child: Icon(
                  Icons.directions_bus_rounded,
                  color: context.colors.brand,
                  size: AppIconSize.lg,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.routeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: AppIconSize.xs,
                          color: context.colors.textSecondary,
                        ),
                        const SizedBox(width: AppSpacing.xxs),
                        Text(
                          _formatDuration(_tripDuration),
                          style: context.text.labelMedium?.copyWith(
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              StatusPill(
                label: 'LIVE',
                color: context.colors.success,
                pulse: true,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Pickup progress
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$pickedCount of $totalCount picked up',
                style: context.text.bodyMedium?.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: context.text.titleMedium?.copyWith(
                  color: context.colors.brand,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: AppRadius.brPill,
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: context.colors.surfaceSubtle,
              valueColor: AlwaysStoppedAnimation(context.colors.brand),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // PRIMARY: Resume live map button
          AppButton(
            label: 'View Live Map',
            icon: Icons.map_outlined,
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.pushNamed(
                context,
                '/osm-tracking',
                arguments: {
                  'tripId': tripProvider.activeTrip?.id ?? '',
                  'preloadedData': null,
                },
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),

          // SECONDARY: Students + End trip row
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Students',
                  icon: Icons.people_outline,
                  variant: AppButtonVariant.outline,
                  onPressed: () => Navigator.pushNamed(
                    context,
                    '/students-list',
                    arguments: {'tripId': tripProvider.activeTrip?.id},
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  label: 'End Trip',
                  icon: Icons.stop_circle_outlined,
                  variant: AppButtonVariant.danger,
                  onPressed: () => _showEndTripDialog(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== GUARDIAN VIEWS ====================

  Widget _buildGuardianIdle() {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      shadow: context.colors.shadowMd,
      child: Column(
        children: [
          const BusIllustration(height: 120),
          const SizedBox(height: AppSpacing.lg),
          Text('No active trips', style: context.text.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'When the school bus starts its route, live updates will appear right here.',
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(
              color: context.colors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Manage Children',
            icon: Icons.child_care_rounded,
            variant: AppButtonVariant.outline,
            onPressed: () => Navigator.pushNamed(context, '/manage-children'),
          ),
        ],
      ),
    );
  }

  Widget _buildGuardianActiveTrip(TripProvider tripProvider) {
    final trip = tripProvider.activeTrip!;
    final guardianChildren = trip.students.toList();
    final total = trip.students.length;
    final picked = trip.students.where((s) => s.status == 'picked').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Live tracking hero — tappable to open the unified trip view
        GradientHeroCard(
          onTap: () => Navigator.pushNamed(context, '/start-trip'),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.directions_bus_rounded,
                      color: Colors.white,
                      size: AppIconSize.lg,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trip.routeName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.titleMedium?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Bus ${trip.vehicleNumber ?? '...'}',
                          style: context.text.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const StatusPill(
                    label: 'LIVE',
                    color: Colors.white,
                    pulse: true,
                    dense: true,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              // Divider keeps the metrics visually separate from the header.
              Divider(
                color: Colors.white.withValues(alpha: 0.18),
                height: 1,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  StatTile(
                    icon: Icons.groups_outlined,
                    value: '$total',
                    label: 'Students',
                    onLight: true,
                  ),
                  StatTile(
                    icon: Icons.check_circle_outline,
                    value: '$picked',
                    label: 'Picked up',
                    onLight: true,
                  ),
                  StatTile(
                    icon: Icons.timelapse_outlined,
                    value: '${total - picked}',
                    label: 'Remaining',
                    onLight: true,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Track',
                      icon: Icons.map_outlined,
                      variant: AppButtonVariant.onBrand,
                      onPressed: () => Navigator.pushNamed(
                        context,
                        '/osm-tracking',
                        arguments: {
                          'tripId': trip.id,
                          'busId': trip.vehicleId,
                          'routeId': trip.routeId,
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: () => _openTripChat(context, trip),
                        icon: const Icon(Icons.chat_bubble_outline, size: 20),
                        label: const Text('Chat'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          foregroundColor: Colors.white,
                          shape: const RoundedRectangleBorder(
                            borderRadius: AppRadius.brMd,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xl),

        SectionHeader(
          title: guardianChildren.length == 1 ? 'Your child' : 'Your children',
          subtitle: 'Live pickup status on this trip',
        ),
        const SizedBox(height: AppSpacing.sm),

        ...guardianChildren.map(_buildChildStatusCard),

        if (guardianChildren.isEmpty)
          AppCard(
            color: context.colors.surfaceSubtle,
            shadow: const [],
            child: Row(
              children: [
                Icon(Icons.info_outline, color: context.colors.textSecondary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Your child is not assigned to this trip',
                    style: context.text.bodyMedium?.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildChildStatusCard(StudentPickup student) {
    final isPicked = student.status == 'picked';
    final isDropped = student.status == 'dropped';
    final isAbsent = student.status == 'absent';

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (isPicked) {
      statusColor = context.colors.success;
      statusText = 'Picked up';
      statusIcon = Icons.check_circle_rounded;
    } else if (isDropped) {
      statusColor = context.colors.info;
      statusText = 'Dropped off';
      statusIcon = Icons.home_rounded;
    } else if (isAbsent) {
      statusColor = context.colors.error;
      statusText = 'Absent';
      statusIcon = Icons.person_off_rounded;
    } else {
      statusColor = context.colors.warning;
      statusText = 'Waiting';
      statusIcon = Icons.schedule_rounded;
    }

    final time = student.pickupTime;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            // Child avatar with a status ring, so state reads before the text.
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: statusColor.withValues(alpha: 0.45),
                  width: 2,
                ),
              ),
              child: AppAvatar(name: student.name, size: 40),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleMedium,
                  ),
                  if (time != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'at ${DateFormat('h:mm a').format(time)}',
                      style: context.text.bodySmall?.copyWith(
                        color: context.colors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            StatusPill(
              label: statusText,
              color: statusColor,
              icon: statusIcon,
              dense: true,
            ),
          ],
        ),
      ),
    );
  }

  // ==================== QUICK ACTIONS ====================

  /// Balanced 2×2 grid. Tints come from the theme tokens only, so the set reads
  /// as one family in both light and dark rather than a bag of stock colors.
  Widget _buildQuickActions(bool isDriver) {
    final colors = context.colors;

    final actions = isDriver
        ? <_QuickAction>[
            _QuickAction(
              icon: Icons.play_circle_outline_rounded,
              label: 'Start Trip',
              subtitle: 'Begin a new journey',
              tint: colors.brand,
              onTap: _goToStartTrip,
            ),
            _QuickAction(
              icon: Icons.event_note_rounded,
              label: 'Manage Trips',
              subtitle: 'View schedules',
              tint: colors.info,
              onTap: () => Navigator.pushNamed(context, '/manage-master-trips'),
            ),
            _QuickAction(
              icon: Icons.history_rounded,
              label: 'Trip History',
              subtitle: 'Past journeys',
              tint: colors.accent,
              onTap: () => Navigator.pushNamed(context, '/trips'),
            ),
            _QuickAction(
              icon: Icons.chat_bubble_outline_rounded,
              label: 'Messages',
              subtitle: 'Chat with guardians',
              tint: colors.brand,
              onTap: () => Navigator.pushNamed(context, '/chat'),
            ),
          ]
        : <_QuickAction>[
            _QuickAction(
              icon: Icons.child_care_rounded,
              label: 'My Children',
              subtitle: 'Manage profiles',
              tint: colors.brand,
              onTap: () => Navigator.pushNamed(context, '/manage-children'),
            ),
            _QuickAction(
              icon: Icons.route_rounded,
              label: 'My Trips',
              subtitle: 'Track journeys',
              tint: colors.info,
              onTap: () => Navigator.pushNamed(context, '/trips'),
            ),
            _QuickAction(
              icon: Icons.chat_bubble_outline_rounded,
              label: 'Messages',
              subtitle: 'Chat with driver',
              tint: colors.accent,
              onTap: () => Navigator.pushNamed(context, '/chat'),
            ),
            _QuickAction(
              icon: Icons.notifications_none_rounded,
              label: 'Alerts',
              subtitle: 'Trip notifications',
              tint: colors.brand,
              onTap: () => Navigator.pushNamed(context, '/notifications'),
            ),
          ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Quick actions'),
          const SizedBox(height: AppSpacing.md),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 1.35,
            children: [
              for (final action in actions) _ActionTile(action: action),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== DIALOGS ====================

  void _showEndTripDialog(BuildContext context) {
    final tripProvider = context.read<TripProvider>();
    if (tripProvider.activeTrip == null) return;

    confirmDialog(
      context,
      title: 'End Trip?',
      message:
          'Are you sure you want to end this trip? This action cannot be undone.',
      confirmLabel: 'End Trip',
      icon: Icons.stop_circle_outlined,
      destructive: true,
    ).then((confirmed) {
      if (confirmed) _endTrip();
    });
  }

  Future<void> _endTrip() async {
    final tripProvider = context.read<TripProvider>();
    final authProvider = context.read<AuthProvider>();
    final trip = tripProvider.activeTrip;
    if (trip == null) return;

    // Show loading overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) =>
          Center(child: CircularProgressIndicator(color: ctx.colors.brand)),
    );

    try {
      final userData = authProvider.userData;
      final driverId = userData['id']?.toString();
      final driverName = userData['name']?.toString();

      final success = await tripProvider.endTrip(
        trip.id,
        driverId: driverId,
        driverName: driverName,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // Remove loading overlay

      if (success) {
        HapticFeedback.heavyImpact();
        AppSnackbar.success(context, 'Trip ended successfully');
        // Refresh dashboard
        _loadData();
      } else {
        AppSnackbar.error(
          context,
          'Failed to end trip: ${tripProvider.errorMessage ?? "Unknown error"}',
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Remove loading overlay
        AppSnackbar.error(context, 'Error ending trip: $e');
      }
    }
  }

  void _openTripChat(BuildContext context, Trip trip) {
    Navigator.pushNamed(
      context,
      '/chat-detail',
      arguments: {
        'tripId': trip.id,
        'receiverId': trip.vehicleId, // Use vehicleId as receiver identifier
        'receiverName': 'Driver - ${trip.routeName}',
        'receiverRole': 'Driver',
        'isTripChat': true,
      },
    );
  }
}

// ==================== DASHBOARD PIECES ====================

/// Soft circular icon button used in the dashboard top bar, with an optional
/// unread badge.
class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.badgeCount = 0,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    Widget button = Material(
      color: context.colors.surfaceSubtle,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: AppIconSize.md, color: context.scheme.onSurface),
        ),
      ),
    );

    if (tooltip != null) {
      button = Tooltip(message: tooltip!, child: button);
    }

    if (badgeCount <= 0) return button;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        button,
        Positioned(
          top: -1,
          right: -1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            constraints: const BoxConstraints(minWidth: 18),
            decoration: BoxDecoration(
              color: context.colors.error,
              borderRadius: AppRadius.brPill,
              border: Border.all(color: context.scheme.surface, width: 1.5),
            ),
            child: Text(
              badgeCount > 9 ? '9+' : '$badgeCount',
              textAlign: TextAlign.center,
              style: context.text.labelSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Small pill showing a piece of context (date, role) above the greeting.
class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label, this.tint});

  final IconData icon;
  final String label;

  /// Defaults to a neutral tint; pass a token color to emphasise the chip.
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final fg = tint ?? context.colors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: tint == null
            ? context.colors.surfaceSubtle
            : tint!.withValues(alpha: 0.12),
        borderRadius: AppRadius.brPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppIconSize.xs, color: fg),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            label,
            style: context.text.labelMedium?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// One entry in the quick-actions grid.
class _QuickAction {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.tint,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color tint;
  final VoidCallback onTap;
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.action});

  final _QuickAction action;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: action.onTap,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              color: action.tint.withValues(alpha: 0.12),
              borderRadius: AppRadius.brSm,
            ),
            child: Icon(
              action.icon,
              color: action.tint,
              size: AppIconSize.lg,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                action.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.titleSmall,
              ),
              const SizedBox(height: 2),
              Text(
                action.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelSmall?.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
