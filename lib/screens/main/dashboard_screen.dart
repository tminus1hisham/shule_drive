import 'dart:async';
import 'dart:ui' as ui;
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

  // Timer callbacks must not look up inherited widgets while this element is
  // deactivated. Keep stable provider references and explicit lifecycle state.
  AuthProvider? _scheduledAuthProvider;
  TripProvider? _scheduledTripProvider;
  bool _isElementActive = true;
  bool _isRouteVisible = true;
  bool _isAppActive = true;

  bool get _canUseContext => mounted && _isElementActive;
  bool get _canRunScheduledWork =>
      _canUseContext && _isRouteVisible && _isAppActive;

  @override
  void initState() {
    super.initState();

    _startPeriodicRefresh();
    // Subscribe to app lifecycle
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_canUseContext) return;
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
    if (!_canRunScheduledWork) return;

    final appProvider = context.read<AppProvider>();
    final authProvider = context.read<AuthProvider>();
    final tripProvider = context.read<TripProvider>();
    final navigator = Navigator.of(context);

    // Make sure the autoload preference is read before we decide whether to
    // jump the driver straight into their scheduled trips.
    await appProvider.ensurePreferencesLoaded();
    if (!_canRunScheduledWork) return;

    await _loadData();
    if (!mounted || !_canRunScheduledWork || !navigator.mounted) return;

    final activeTrip = tripProvider.activeTrip;

    if (authProvider.isDriver && activeTrip != null && !_fromTripEnd) {
      debugPrint('🚌 Active trip found on open, resuming: ${activeTrip.id}');
      navigator.pushNamed(
        '/osm-tracking',
        arguments: {'tripId': activeTrip.id, 'preloadedData': null},
      );
      return;
    }

    unawaited(_checkMasterTripsForDriver());
    _startUpcomingTripChecker();
  }

  /// Check if driver has master trips and redirect accordingly
  Future<void> _checkMasterTripsForDriver() async {
    if (!_canRunScheduledWork) return;

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
    final navigator = Navigator.of(context);
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
          if (freshTrips.isNotEmpty &&
              _canRunScheduledWork &&
              navigator.mounted &&
              !_fromTripEnd) {
            if (firstTrip == null) {
              debugPrint(
                '✅ Fresh data available, redirecting to trip selection',
              );
              navigator.pushReplacementNamed('/trip-selection');
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

      if (!mounted || !_canRunScheduledWork || !navigator.mounted) {
        _isCheckingMasterTrips = false;
        debugPrint('🔍 Dashboard is no longer active');
        return;
      }

      if (masterTrips.isNotEmpty && !_fromTripEnd) {
        debugPrint('✅ Redirecting to trip selection screen');

        // Redirect to trip selection screen
        navigator.pushReplacementNamed('/trip-selection');
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
      void finishCheck() {
        _hasCheckedMasterTrips = true;
        _isCheckingMasterTrips = false;
      }

      if (_canUseContext) {
        setState(finishCheck);
      } else {
        finishCheck();
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduledAuthProvider = context.read<AuthProvider>();
    _scheduledTripProvider = context.read<TripProvider>();
    // Subscribe to route observer
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  // ==================== UPCOMING TRIP PROMPT ====================

  /// Start periodic check for upcoming trips (every 30 seconds)
  void _startUpcomingTripChecker() {
    if (!_canRunScheduledWork) return;
    final authProvider = _scheduledAuthProvider;
    if (authProvider == null) return;
    if (!authProvider.isDriver) return;

    _upcomingTripTimer?.cancel();

    // Check immediately
    unawaited(_checkUpcomingTrips());

    // Then check every 30 seconds
    _upcomingTripTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_canRunScheduledWork) {
        unawaited(_checkUpcomingTrips());
      }
    });
  }

  /// Check if any master trip is starting within the next 5 minutes
  Future<void> _checkUpcomingTrips() async {
    if (!_canRunScheduledWork || _isShowingUpcomingPrompt) return;

    final authProvider = _scheduledAuthProvider;
    if (authProvider == null) return;
    if (!authProvider.isDriver) return;

    final driverId = authProvider.currentUser?.id;
    if (driverId == null || driverId.isEmpty) return;

    try {
      final tripService = TripService();
      final masterTrips = await tripService.getMasterTripsByDriverCached(
        driverId,
        onRefresh: (_) {},
      );
      if (!_canRunScheduledWork) return;

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
          if (_canRunScheduledWork) {
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
    if (!_canRunScheduledWork) return;

    final next = selectNextMasterTrip(trips, now: now);

    // Rebuild whenever there is something to show: the countdown label ages
    // with the clock even when the selected trip is unchanged.
    if (next == null && _nextScheduledTrip == null) return;

    setState(() => _nextScheduledTrip = next);
  }

  /// Show a frosted prompt inviting the driver to start an upcoming trip.
  void _showUpcomingTripPrompt(MasterTrip trip, DateTime scheduledTime) {
    if (!_canRunScheduledWork) return;
    _isShowingUpcomingPrompt = true;

    final minutesAway = scheduledTime.difference(DateTime.now()).inMinutes;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(
        alpha: context.isDark ? 0.52 : 0.28,
      ),
      elevation: 0,
      showDragHandle: false,
      builder: (ctx) => SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: _UpcomingTripGlassPrompt(
              trip: trip,
              minutesAway: minutesAway,
              onDismiss: () => Navigator.pop(ctx),
              onStart: () {
                Navigator.pop(ctx);
                _isShowingUpcomingPrompt = false;
                Navigator.pushNamed(
                  context,
                  '/trip-selection',
                  arguments: {'autoSelectTripId': trip.id},
                );
              },
              onViewAll: () {
                Navigator.pop(ctx);
                _isShowingUpcomingPrompt = false;
                Navigator.pushNamed(context, '/trip-selection');
              },
            ),
          ),
        ),
      ),
    ).whenComplete(() => _isShowingUpcomingPrompt = false);
  }

  @override
  void dispose() {
    _isElementActive = false;
    _isRouteVisible = false;
    _isAppActive = false;
    _cancelScheduledWork();
    routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void deactivate() {
    _isElementActive = false;
    _cancelScheduledWork();
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _isElementActive = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resumeScheduledWork();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _isAppActive = true;
      _resumeScheduledWork();
    } else {
      _isAppActive = false;
      _cancelScheduledWork();
    }
  }

  /// Pause polling while another route covers the dashboard.
  @override
  void didPushNext() {
    _isRouteVisible = false;
    _cancelScheduledWork();
  }

  /// Called when the route is popped and this screen becomes visible again
  @override
  void didPopNext() {
    _isRouteVisible = true;
    _resumeScheduledWork();
  }

  void _cancelScheduledWork() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _durationTimer?.cancel();
    _durationTimer = null;
    _upcomingTripTimer?.cancel();
    _upcomingTripTimer = null;
  }

  void _resumeScheduledWork() {
    if (!_canRunScheduledWork) return;

    _startPeriodicRefresh();
    _startUpcomingTripChecker();
    final tripProvider = _scheduledTripProvider;
    if (tripProvider?.activeTrip != null) {
      _startDurationTimer(tripProvider!);
    }
    unawaited(_refresh());
  }

  /// Start periodic refresh timer
  void _startPeriodicRefresh() {
    if (!_canRunScheduledWork) return;
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      if (_canRunScheduledWork) {
        unawaited(_refresh());
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
      if (_canRunScheduledWork) {
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
    if (!_canRunScheduledWork) return;
    final tripProvider = _scheduledTripProvider;
    final authProvider = _scheduledAuthProvider;
    if (tripProvider == null || authProvider == null) return;

    if (kDebugMode) {
      print('📱 Dashboard _refresh:');
      print('  isGuardian: ${authProvider.isGuardian}');
      print('  isDriver: ${authProvider.isDriver}');
      print('  userPhone: ${authProvider.userPhone}');
    }

    try {
      // Fetch active trips for both roles without looking up an ancestor from
      // this timer-driven method.
      if (authProvider.isGuardian) {
        final hasPhone =
            authProvider.userPhone != null &&
            authProvider.userPhone!.isNotEmpty;
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
    } catch (error, stackTrace) {
      if (kDebugMode && _canUseContext) {
        debugPrint('Dashboard refresh failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
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
          const Positioned.fill(child: _DashboardBackdrop()),
          RefreshIndicator(
            onRefresh: _refresh,
            color: context.colors.brand,
            child: SafeArea(
              bottom: false,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: _buildTopBar(userData, appProvider),
                  ),
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
        SliverToBoxAdapter(
          child: _block(child: _buildDriverActiveTrip(tripProvider)),
        ),
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
      SliverToBoxAdapter(
        child: _block(child: _buildGuardianActiveTrip(tripProvider)),
      ),
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

    final firstName =
        (userData['name'] as String?)?.split(' ').first ?? 'there';

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
    return _DashboardGlassPanel(
      onTap: () => Navigator.pushNamed(
        context,
        '/trip-selection',
        arguments: {'autoSelectTripId': next.trip.id},
      ),
      padding: const EdgeInsets.all(AppSpacing.sm),
      tint: context.colors.accent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -52,
            right: -44,
            child: _GlassGlow(
              color: context.colors.accent,
              diameter: 140,
              opacity: context.isDark ? 0.13 : 0.10,
            ),
          ),
          Row(
            children: [
              Container(
                width: 4,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [context.colors.accent, context.colors.brand],
                  ),
                  borderRadius: AppRadius.brPill,
                  boxShadow: [
                    BoxShadow(
                      color: context.colors.accent.withValues(alpha: 0.28),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      context.colors.brand.withValues(alpha: 0.22),
                      context.colors.accent.withValues(alpha: 0.12),
                    ],
                  ),
                  borderRadius: AppRadius.brMd,
                  border: Border.all(
                    color: context.colors.brand.withValues(alpha: 0.18),
                  ),
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
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: context.colors.accent.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: AppRadius.brPill,
                            border: Border.all(
                              color: context.colors.accent.withValues(
                                alpha: 0.20,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.near_me_rounded,
                                size: 11,
                                color: context.colors.accent,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'UP NEXT',
                                style: context.text.labelSmall?.copyWith(
                                  color: context.colors.accent,
                                  letterSpacing: 0.7,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xxs),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: context.scheme.surface.withValues(
                                alpha: context.isDark ? 0.28 : 0.64,
                              ),
                              borderRadius: AppRadius.brPill,
                              border: Border.all(
                                color: context.colors.outline.withValues(
                                  alpha: 0.72,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.schedule_rounded,
                                  size: 11,
                                  color: context.colors.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    formatNextTripCountdown(next),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.text.labelSmall?.copyWith(
                                      color: context.colors.textSecondary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 9,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      next.trip.tripName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.route_rounded,
                          size: 12,
                          color: context.colors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            next.trip.route,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.labelSmall?.copyWith(
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: Container(
                            width: 3,
                            height: 3,
                            decoration: BoxDecoration(
                              color: context.colors.textMuted,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Text(
                          next.trip.tripTime,
                          maxLines: 1,
                          style: context.text.labelSmall?.copyWith(
                            color: context.colors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: context.scheme.surface.withValues(
                    alpha: context.isDark ? 0.24 : 0.62,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: context.colors.outline.withValues(alpha: 0.72),
                  ),
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: AppIconSize.xs,
                  color: context.colors.brand,
                ),
              ),
            ],
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
              Divider(color: Colors.white.withValues(alpha: 0.18), height: 1),
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

  /// Compact action dock. One glass surface keeps all four destinations
  /// visible without letting shortcuts dominate the page.
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
              label: 'Schedules',
              subtitle: 'View schedules',
              tint: colors.info,
              onTap: () => Navigator.pushNamed(context, '/manage-master-trips'),
            ),
            _QuickAction(
              icon: Icons.history_rounded,
              label: 'History',
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
              label: 'Children',
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
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Quick actions'),
          const SizedBox(height: AppSpacing.xs),
          _DashboardGlassPanel(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xxs,
              vertical: AppSpacing.xs,
            ),
            tint: colors.brand,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < actions.length; index++) ...[
                  Expanded(child: _ActionTile(action: actions[index])),
                  if (index < actions.length - 1)
                    Container(
                      width: 1,
                      height: 48,
                      margin: const EdgeInsets.only(top: AppSpacing.xxs),
                      color: colors.outline.withValues(alpha: 0.72),
                    ),
                ],
              ],
            ),
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

/// A focused, low-opacity glass prompt for imminent departures. The backdrop
/// remains visible through the sheet while the borders and type retain enough
/// contrast to stay legible in dark mode.
class _UpcomingTripGlassPrompt extends StatelessWidget {
  const _UpcomingTripGlassPrompt({
    required this.trip,
    required this.minutesAway,
    required this.onDismiss,
    required this.onStart,
    required this.onViewAll,
  });

  final MasterTrip trip;
  final int minutesAway;
  final VoidCallback onDismiss;
  final VoidCallback onStart;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final glassColors = isDark
        ? [
            Colors.white.withValues(alpha: 0.11),
            context.scheme.surface.withValues(alpha: 0.36),
          ]
        : [
            Colors.white.withValues(alpha: 0.72),
            Colors.white.withValues(alpha: 0.44),
          ];
    final edgeColor = Colors.white.withValues(alpha: isDark ? 0.17 : 0.72);
    final countdown = minutesAway > 0 ? '$minutesAway min' : 'Now';

    return Semantics(
      namesRoute: true,
      label: minutesAway > 0
          ? 'Trip starts in $minutesAway minutes'
          : 'Trip starts now',
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppRadius.brXl,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.42 : 0.16),
              blurRadius: 40,
              offset: const Offset(0, 18),
            ),
            BoxShadow(
              color: context.colors.brand.withValues(alpha: 0.10),
              blurRadius: 34,
              spreadRadius: -6,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: AppRadius.brXl,
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 26, sigmaY: 26),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: glassColors,
                ),
                borderRadius: AppRadius.brXl,
                border: Border.all(color: edgeColor),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -72,
                    right: -50,
                    child: _GlassGlow(
                      color: context.colors.accent,
                      diameter: 190,
                    ),
                  ),
                  Positioned(
                    bottom: -86,
                    left: -68,
                    child: _GlassGlow(
                      color: context.colors.brand,
                      diameter: 220,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: context.colors.accent.withValues(
                                  alpha: isDark ? 0.13 : 0.11,
                                ),
                                borderRadius: AppRadius.brPill,
                                border: Border.all(
                                  color: context.colors.accent.withValues(
                                    alpha: 0.24,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.notifications_active_rounded,
                                    size: AppIconSize.xs,
                                    color: context.colors.accent,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'DEPARTURE REMINDER',
                                    style: context.text.labelSmall?.copyWith(
                                      color: context.colors.accent,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.7,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: onDismiss,
                              tooltip: 'Dismiss',
                              visualDensity: VisualDensity.compact,
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white.withValues(
                                  alpha: isDark ? 0.08 : 0.36,
                                ),
                                side: BorderSide(
                                  color: Colors.white.withValues(
                                    alpha: isDark ? 0.11 : 0.52,
                                  ),
                                ),
                              ),
                              icon: Icon(
                                Icons.close_rounded,
                                size: AppIconSize.md,
                                color: context.colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.88, end: 1),
                          duration: const Duration(milliseconds: 650),
                          curve: Curves.easeOutBack,
                          builder: (context, value, child) =>
                              Transform.scale(scale: value, child: child),
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  context.colors.brand.withValues(alpha: 0.28),
                                  context.colors.accent.withValues(alpha: 0.16),
                                ],
                              ),
                              border: Border.all(
                                color: context.colors.brand.withValues(
                                  alpha: 0.34,
                                ),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: context.colors.brand.withValues(
                                    alpha: 0.22,
                                  ),
                                  blurRadius: 28,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.access_time_filled_rounded,
                              color: context.colors.brand,
                              size: AppIconSize.xxl,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          minutesAway > 0
                              ? 'Your next trip starts in'
                              : 'Your next trip starts',
                          textAlign: TextAlign.center,
                          style: context.text.titleMedium?.copyWith(
                            color: context.colors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          countdown,
                          textAlign: TextAlign.center,
                          style: context.text.displaySmall?.copyWith(
                            color: context.scheme.onSurface,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.2,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(
                              alpha: isDark ? 0.065 : 0.34,
                            ),
                            borderRadius: AppRadius.brMd,
                            border: Border.all(
                              color: Colors.white.withValues(
                                alpha: isDark ? 0.11 : 0.52,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: context.colors.brand.withValues(
                                    alpha: 0.14,
                                  ),
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
                                      trip.tripName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: context.text.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${trip.route} • ${trip.tripTime}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: context.text.bodySmall?.copyWith(
                                        color: context.colors.textSecondary,
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
                          label: 'Start trip now',
                          icon: Icons.play_arrow_rounded,
                          onPressed: onStart,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        AppButton(
                          label: 'View all trips',
                          icon: Icons.list_alt_rounded,
                          variant: AppButtonVariant.outline,
                          onPressed: onViewAll,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassGlow extends StatelessWidget {
  const _GlassGlow({
    required this.color,
    required this.diameter,
    this.opacity = 0.17,
  });

  final Color color;
  final double diameter;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

/// A quiet tinted canvas gives translucent cards something to refract on light
/// themes while remaining subtle enough to keep the dashboard content primary.
class _DashboardBackdrop extends StatelessWidget {
  const _DashboardBackdrop();

  @override
  Widget build(BuildContext context) {
    final base = context.theme.scaffoldBackgroundColor;

    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.alphaBlend(
                    context.colors.brand.withValues(
                      alpha: context.isDark ? 0.08 : 0.055,
                    ),
                    base,
                  ),
                  base,
                  Color.alphaBlend(
                    context.colors.accent.withValues(
                      alpha: context.isDark ? 0.06 : 0.04,
                    ),
                    base,
                  ),
                ],
                stops: const [0, 0.52, 1],
              ),
            ),
          ),
          Positioned(
            top: 220,
            right: -110,
            child: _GlassGlow(
              color: context.colors.brand,
              diameter: 300,
              opacity: context.isDark ? 0.08 : 0.065,
            ),
          ),
          Positioned(
            bottom: 40,
            left: -120,
            child: _GlassGlow(
              color: context.colors.accent,
              diameter: 290,
              opacity: context.isDark ? 0.07 : 0.05,
            ),
          ),
        ],
      ),
    );
  }
}

/// A theme-aware frosted surface used by the dashboard's compact utility
/// panels. The blur, translucent gradient and hairline edge provide the glass
/// effect without sacrificing contrast in either brightness mode.
class _DashboardGlassPanel extends StatelessWidget {
  const _DashboardGlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.tint,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? tint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const borderRadius = AppRadius.brLg;
    final glassTint = tint ?? context.colors.brand;
    final glassBase = context.isDark
        ? context.scheme.surface.withValues(alpha: 0.70)
        : Colors.white.withValues(alpha: 0.88);
    final glassEnd = Color.alphaBlend(
      glassTint.withValues(alpha: context.isDark ? 0.13 : 0.10),
      context.scheme.surface,
    ).withValues(alpha: context.isDark ? 0.70 : 0.84);
    final edgeColor = context.isDark
        ? Colors.white.withValues(alpha: 0.14)
        : Color.alphaBlend(
            glassTint.withValues(alpha: 0.16),
            context.colors.outline,
          );

    Widget content = Padding(padding: padding, child: child);
    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: content,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.24 : 0.07),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: glassTint.withValues(alpha: context.isDark ? 0.08 : 0.06),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [glassBase, glassEnd],
              ),
              borderRadius: borderRadius,
              border: Border.all(color: edgeColor),
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

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
          child: Icon(
            icon,
            size: AppIconSize.md,
            color: context.scheme.onSurface,
          ),
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
    return Tooltip(
      message: action.subtitle,
      child: Semantics(
        button: true,
        label: '${action.label}. ${action.subtitle}',
        child: Material(
          color: Colors.transparent,
          borderRadius: AppRadius.brSm,
          child: InkWell(
            onTap: action.onTap,
            borderRadius: AppRadius.brSm,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xxs,
                vertical: AppSpacing.xxs,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          action.tint.withValues(alpha: 0.24),
                          action.tint.withValues(alpha: 0.10),
                        ],
                      ),
                      borderRadius: AppRadius.brMd,
                      border: Border.all(
                        color: action.tint.withValues(alpha: 0.20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: action.tint.withValues(alpha: 0.12),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      action.icon,
                      color: action.tint,
                      size: AppIconSize.md,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    action.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: context.text.labelSmall?.copyWith(
                      color: context.scheme.onSurface,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
