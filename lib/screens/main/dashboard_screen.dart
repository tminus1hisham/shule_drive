import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../main.dart';
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/trip_provider.dart';
import '../../api/services/trip_service.dart';
import '../../models/master_trip.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme_extension.dart';
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
  MasterTrip? _nextMasterTrip;

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

    // Check if we arrived from trip end
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map && args['fromTripEnd'] == true) {
        _fromTripEnd = true;
        debugPrint(
          '📍 Dashboard: Arrived from trip end, skipping auto-redirect',
        );
      }
    });

    _loadData();
    _startPeriodicRefresh();
    // Subscribe to app lifecycle
    WidgetsBinding.instance.addObserver(this);

    // Check for master trips if driver - with slight delay to ensure auth is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _checkMasterTripsForDriver();
          // Start upcoming trip checker
          _startUpcomingTripChecker();
        }
      });
    });
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

      for (final trip in masterTrips) {
        // Skip already-prompted trips
        if (_promptedTripIds.contains(trip.id)) continue;

        final tripDateTime = _parseTripTime(trip.tripTime);
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

  /// Parse tripTime string (e.g. "07:30 AM") to DateTime for today
  DateTime? _parseTripTime(String tripTime) {
    try {
      final cleaned = tripTime.trim().toUpperCase();
      final isPM = cleaned.contains('PM');
      final isAM = cleaned.contains('AM');
      final timePart = cleaned.replaceAll(RegExp(r'[APM\s]'), '').trim();
      final parts = timePart.split(':');

      if (parts.length < 2) return null;

      var hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      if (isPM && hour != 12) hour += 12;
      if (isAM && hour == 12) hour = 0;

      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day, hour, minute);
    } catch (e) {
      debugPrint('⚠️ Failed to parse trip time "$tripTime": $e');
      return null;
    }
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
      await tripProvider.fetchActiveTrip();
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

      if (mounted && trips.isNotEmpty) {
        setState(() {
          _nextMasterTrip = trips.first;
        });
      }
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
      await tripProvider.fetchActiveTrip();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final authProvider = context.watch<AuthProvider>();
    final tripProvider = context.watch<TripProvider>();
    final isDarkMode = provider.isDarkMode;
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
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader(userData, isDarkMode)),
                  SliverToBoxAdapter(
                    child: _buildGreeting(
                      userData,
                      isDriver,
                      hasActiveTrip,
                      isDarkMode,
                    ),
                  ),

                  // Main content based on role and trip status
                  if (isDriver)
                    SliverToBoxAdapter(
                      child: hasActiveTrip
                          ? _buildDriverActiveTrip(
                              context,
                              tripProvider,
                              isDarkMode,
                            )
                          : _buildDriverStartTrip(context, isDarkMode),
                    )
                  else if (isGuardian)
                    SliverToBoxAdapter(
                      child: hasActiveTrip
                          ? _buildGuardianActiveTrip(
                              context,
                              tripProvider,
                              isDarkMode,
                            )
                          : _buildGuardianIdle(context, isDarkMode),
                    ),

                  // Quick actions section
                  SliverToBoxAdapter(
                    child: _buildQuickActions(
                      context,
                      isDriver,
                      hasActiveTrip,
                      isDarkMode,
                    ),
                  ),

                  const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
                ],
              ),
            ),
          ),
          // Loading overlay when checking master trips
          if (_isCheckingMasterTrips)
            Container(
              color: context.scheme.surface.withValues(alpha: 0.7),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: context.colors.brand),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Checking for scheduled trips...',
                      style: context.text.labelLarge?.copyWith(
                        color: context.colors.brand,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
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
          Navigator.pushNamed(context, '/start-trip');
        }
        break;
    }
  }

  // ==================== HEADER & GREETING ====================

  Widget _buildHeader(Map<String, dynamic> userData, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Builder(
                builder: (context) => IconButton(
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  icon: const Icon(Icons.menu_rounded),
                  color: context.scheme.onSurface,
                  tooltip: 'Menu',
                  style: IconButton.styleFrom(
                    backgroundColor: context.colors.surfaceSubtle,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  gradient: context.colors.brandGradient,
                  borderRadius: AppRadius.brSm,
                  boxShadow: context.colors.shadowSm,
                ),
                child: const Icon(
                  Icons.directions_bus_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ShuleDrive', style: context.text.titleLarge),
                  Text(
                    'Safe School Transport',
                    style: context.text.labelSmall?.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          AppAvatar(
            imageUrl: userData['avatar'] as String?,
            name: userData['name'] as String?,
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
    bool isDarkMode,
  ) {
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'Good Morning';
    } else if (hour < 17) {
      greeting = 'Good Afternoon';
    } else {
      greeting = 'Good Evening';
    }

    String subtitle;
    if (isDriver) {
      subtitle = hasActiveTrip
          ? 'Trip in progress. Drive safe!'
          : 'Ready to start your next trip?';
    } else {
      subtitle = hasActiveTrip
          ? 'Your child\'s bus is on the way'
          : 'Track your child\'s journey safely';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$greeting, ${userData['name']?.split(' ').first ?? 'User'}',
            style: context.text.headlineMedium,
          ),
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

  Widget _buildDriverStartTrip(BuildContext context, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: GradientHeroCard(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.directions_bus_rounded,
                color: Colors.white,
                size: 48,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Ready to Start?',
              style: context.text.headlineSmall?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Begin your route and ensure students arrive safely',
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_nextMasterTrip != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.xs,
                  horizontal: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: AppRadius.brSm,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      color: Colors.white70,
                      size: 18,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Next: ${_nextMasterTrip!.tripName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.labelMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${_nextMasterTrip!.route} • ${_nextMasterTrip!.tripTime}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.labelSmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            AppButton(
              label: 'Start Trip',
              icon: Icons.play_arrow_rounded,
              variant: AppButtonVariant.onBrand,
              onPressed: () => Navigator.pushNamed(context, '/start-trip'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverActiveTrip(
    BuildContext context,
    TripProvider tripProvider,
    bool isDarkMode,
  ) {
    final trip = tripProvider.activeTrip!;
    final pickedCount = trip.students.where((s) => s.status == 'picked').length;
    final totalCount = trip.students.length;
    final progress = totalCount > 0 ? pickedCount / totalCount : 0.0;

    // Ensure duration timer is running
    if (_durationTimer == null || !_durationTimer!.isActive) {
      _startDurationTimer(tripProvider);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: AppCard(
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
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(trip.routeName, style: context.text.titleMedium),
                      Row(
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 14,
                            color: context.colors.textSecondary,
                          ),
                          const SizedBox(width: AppSpacing.xxs),
                          Text(
                            _formatDuration(_tripDuration),
                            style: context.text.labelMedium?.copyWith(
                              color: context.colors.brand,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                StatusPill(label: 'Active', color: context.colors.success),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: context.colors.surfaceSubtle,
                valueColor: AlwaysStoppedAnimation(context.colors.brand),
                minHeight: 10,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$pickedCount of $totalCount students picked up',
                  style: context.text.bodyMedium?.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: context.text.titleSmall?.copyWith(
                    color: context.colors.brand,
                  ),
                ),
              ],
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
      ),
    );
  }

  // ==================== GUARDIAN VIEWS ====================

  Widget _buildGuardianIdle(BuildContext context, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.xl),
        shadow: context.colors.shadowMd,
        child: Column(
          children: [
            const BusIllustration(height: 120),
            const SizedBox(height: AppSpacing.lg),
            Text('No Active Trips', style: context.text.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'When the school bus starts its route, you\'ll see live updates here',
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(
                color: context.colors.textSecondary,
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
      ),
    );
  }

  Widget _buildGuardianActiveTrip(
    BuildContext context,
    TripProvider tripProvider,
    bool isDarkMode,
  ) {
    final trip = tripProvider.activeTrip!;
    final guardianChildren = trip.students.toList();
    final total = trip.students.length;
    final picked = trip.students.where((s) => s.status == 'picked').length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        children: [
          // Live tracking card — tappable to open unified trip view
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
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trip.routeName,
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
                    ),
                  ],
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

          const SizedBox(height: AppSpacing.lg),

          // Child status section
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Your Child\'s Status', style: context.text.headlineSmall),
          ),
          const SizedBox(height: AppSpacing.sm),

          ...guardianChildren.map(
            (student) => _buildChildStatusCard(student, isDarkMode),
          ),

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
      ),
    );
  }

  Widget _buildChildStatusCard(StudentPickup student, bool isDarkMode) {
    final isPicked = student.status == 'picked';
    final isDropped = student.status == 'dropped';
    final isAbsent = student.status == 'absent';

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (isPicked) {
      statusColor = context.colors.success;
      statusText = 'Picked Up';
      statusIcon = Icons.check_circle;
    } else if (isDropped) {
      statusColor = context.colors.info;
      statusText = 'Dropped Off';
      statusIcon = Icons.home_rounded;
    } else if (isAbsent) {
      statusColor = context.colors.warning;
      statusText = 'Absent';
      statusIcon = Icons.person_off_rounded;
    } else {
      statusColor = context.colors.warning;
      statusText = 'Waiting';
      statusIcon = Icons.schedule_rounded;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        border: Border.all(color: statusColor.withValues(alpha: 0.25)),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xs),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(statusIcon, color: statusColor),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(student.name, style: context.text.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    statusText,
                    style: context.text.labelMedium?.copyWith(
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ),
            if (student.pickupTime != null)
              Text(
                '${student.pickupTime!.hour}:${student.pickupTime!.minute.toString().padLeft(2, '0')}',
                style: context.text.bodySmall?.copyWith(
                  color: context.colors.textMuted,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ==================== QUICK ACTIONS ====================

  Widget _buildQuickActions(
    BuildContext context,
    bool isDriver,
    bool hasActiveTrip,
    bool isDarkMode,
  ) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Quick Actions'),
          const SizedBox(height: AppSpacing.md),

          // Modern grid layout for quick actions
          if (isDriver)
            _buildDriverQuickActionsGrid(context, isDarkMode)
          else
            _buildGuardianQuickActionsGrid(context, isDarkMode),
        ],
      ),
    );
  }

  /// Modern grid layout for driver quick actions (2x2 grid, no Live Track)
  Widget _buildDriverQuickActionsGrid(BuildContext context, bool isDarkMode) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildModernQuickActionCard(
                icon: Icons.add_circle_outline,
                label: 'Start Trip',
                subtitle: 'Begin new journey',
                color: context.colors.brand,
                onTap: () => Navigator.pushNamed(context, '/start-trip'),
                isDarkMode: isDarkMode,
                isPrimary: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildModernQuickActionCard(
                icon: Icons.settings,
                label: 'Manage Trips',
                subtitle: 'View schedules',
                color: const Color(0xFF2196F3),
                onTap: () =>
                    Navigator.pushNamed(context, '/manage-master-trips'),
                isDarkMode: isDarkMode,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildModernQuickActionCard(
                icon: Icons.history,
                label: 'Trip History',
                subtitle: 'Past journeys',
                color: const Color(0xFF9C27B0),
                onTap: () => Navigator.pushNamed(context, '/trips'),
                isDarkMode: isDarkMode,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildModernQuickActionCard(
                icon: Icons.chat_bubble_outline,
                label: 'Messages',
                subtitle: 'Chat with guardians',
                color: const Color(0xFFFF9800),
                onTap: () => Navigator.pushNamed(context, '/chat'),
                isDarkMode: isDarkMode,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Modern grid layout for guardian quick actions (2x2 grid)
  Widget _buildGuardianQuickActionsGrid(BuildContext context, bool isDarkMode) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildModernQuickActionCard(
                icon: Icons.child_care,
                label: 'My Children',
                subtitle: 'Manage profiles',
                color: const Color(0xFFE91E63),
                onTap: () => Navigator.pushNamed(context, '/manage-children'),
                isDarkMode: isDarkMode,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildModernQuickActionCard(
                icon: Icons.local_shipping,
                label: 'My Trips',
                subtitle: 'Track journeys',
                color: context.colors.brand,
                onTap: () => Navigator.pushNamed(context, '/trips'),
                isDarkMode: isDarkMode,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildModernQuickActionCard(
                icon: Icons.chat_bubble_outline,
                label: 'Messages',
                subtitle: 'Chat with driver',
                color: const Color(0xFFFF9800),
                onTap: () => Navigator.pushNamed(context, '/chat'),
                isDarkMode: isDarkMode,
              ),
            ),
            const SizedBox(width: 12),
            const Spacer(),
          ],
        ),
      ],
    );
  }

  /// Modern quick action card with subtitle and better styling
  Widget _buildModernQuickActionCard({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    required bool isDarkMode,
    bool isPrimary = false,
  }) {
    return AppCard(
      onTap: onTap,
      border: isPrimary
          ? Border.all(color: color.withValues(alpha: 0.4), width: 1.5)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: AppRadius.brSm,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(label, style: context.text.titleSmall),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: context.text.labelSmall?.copyWith(
              color: context.colors.textSecondary,
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
      builder: (ctx) => Center(
        child: CircularProgressIndicator(color: ctx.colors.brand),
      ),
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
