import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../main.dart';
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/trip_provider.dart';
import '../../api/services/trip_service.dart';
import '../../widgets/main_scaffold.dart';
import '../../widgets/bus_illustration.dart';

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

  // Refresh interval (30 seconds)
  static const Duration _refreshInterval = Duration(seconds: 30);

  // Flag to prevent multiple master trip checks
  bool _hasCheckedMasterTrips = false;
  bool _isCheckingMasterTrips = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _startPeriodicRefresh();
    // Subscribe to app lifecycle
    WidgetsBinding.instance.addObserver(this);
    
    // Check for master trips if driver - with slight delay to ensure auth is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _checkMasterTripsForDriver();
        }
      });
    });
  }

  /// Check if driver has master trips and redirect accordingly
  Future<void> _checkMasterTripsForDriver() async {
    if (_hasCheckedMasterTrips || _isCheckingMasterTrips) {
      debugPrint('🔍 Master trip check already performed or in progress, skipping');
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
      debugPrint('🔍 User is NOT a driver (role: ${authProvider.userRole}), skipping check');
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
      
      debugPrint('🔍 Calling API: getMasterTripsByDriver($driverId)');
      
      final masterTrips = await tripService.getMasterTripsByDriver(driverId);
      
      debugPrint('🔍 API returned ${masterTrips.length} master trips');
      for (final trip in masterTrips) {
        debugPrint('  - ${trip.tripName} (ID: ${trip.id}, Route: ${trip.route})');
      }
      
      if (!mounted) {
        debugPrint('🔍 Widget not mounted');
        return;
      }
      
      if (masterTrips.isNotEmpty) {
        debugPrint('✅ Redirecting to trip selection screen');
        
        // Redirect to trip selection screen
        Navigator.pushReplacementNamed(context, '/trip-selection');
      } else {
        debugPrint('ℹ️ No master trips found');
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

  @override
  void dispose() {
    // Stop timer and unsubscribe
    _refreshTimer?.cancel();
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

    // Only guardians use the active trip API
    // Drivers manage trips through StartTripScreen, not dashboard
    if (authProvider.isGuardian) {
      final hasPhone =
          authProvider.userPhone != null && authProvider.userPhone!.isNotEmpty;
      if (hasPhone) {
        await tripProvider.fetchActiveTrip(guardianPhone: authProvider.userPhone);
      }
    }
    // For drivers, we don't fetch active trip on dashboard
    // They use the StartTripScreen to see/manage their active trip
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

    // Only guardians use the active trip API
    if (authProvider.isGuardian) {
      final hasPhone =
          authProvider.userPhone != null && authProvider.userPhone!.isNotEmpty;
      if (hasPhone) {
        await tripProvider.fetchActiveTrip(guardianPhone: authProvider.userPhone);
      }
    }
    // For drivers, skip active trip fetch
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
            color: const Color(0xFF6B9B5B),
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
          color: (isDarkMode ? Colors.black : Colors.white).withOpacity(0.7),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6B9B5B)),
                ),
                SizedBox(height: 16),
                Text(
                  'Checking for scheduled trips...',
                  style: TextStyle(
                    color: Color(0xFF6B9B5B),
                    fontWeight: FontWeight.w500,
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
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Menu button + Logo
          Row(
            children: [
              // Menu button to open side drawer
              Builder(
                builder: (context) => GestureDetector(
                  onTap: () => Scaffold.of(context).openDrawer(),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.white10 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.menu,
                      color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
                      size: 24,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6B9B5B), Color(0xFF5A8A4A)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6B9B5B).withAlpha(80),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.directions_bus,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ShuleDrive',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Safe School Transport',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? Colors.white60 : Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/profile'),
            child: Hero(
              tag: 'profile_avatar',
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6B9B5B), Color(0xFF5A8A4A)],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 8),
                  ],
                ),
                child: userData['avatar'] != null
                    ? ClipOval(
                        child: Image.network(
                          userData['avatar'],
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, stack) =>
                              _buildAvatarFallback(userData),
                        ),
                      )
                    : _buildAvatarFallback(userData),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarFallback(Map<String, dynamic> userData) {
    final name = userData['name'] ?? 'User';
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'U',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$greeting, ${userData['name']?.split(' ').first ?? 'User'}',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? Colors.white70 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ==================== DRIVER VIEWS ====================

  Widget _buildDriverStartTrip(BuildContext context, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6B9B5B), Color(0xFF5A8A4A)],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6B9B5B).withAlpha(100),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_circle_outline,
                color: Colors.white,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Start New Trip',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Begin your route and ensure students get to school safely',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withAlpha(230),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/start-trip'),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Start Trip'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF6B9B5B),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
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

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Active Trip Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isDarkMode ? 50 : 20),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6B9B5B).withAlpha(30),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.directions_bus,
                        color: Color(0xFF6B9B5B),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trip.routeName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                          ),
                          Text(
                            'Trip #${trip.id}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDarkMode ? Colors.white60 : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withAlpha(30),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, color: Colors.green, size: 8),
                          SizedBox(width: 6),
                          Text(
                            'Active',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF6B9B5B)),
                    minHeight: 10,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$pickedCount of $totalCount students picked up',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode
                            ? Colors.white70
                            : Colors.grey.shade700,
                      ),
                    ),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6B9B5B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            Navigator.pushNamed(context, '/students-list'),
                        icon: const Icon(Icons.people_outline),
                        label: const Text('View Students'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6B9B5B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showEndTripDialog(context),
                        icon: const Icon(
                          Icons.stop_circle_outlined,
                          color: Colors.red,
                        ),
                        label: const Text(
                          'End Trip',
                          style: TextStyle(color: Colors.red),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== GUARDIAN VIEWS ====================

  Widget _buildGuardianIdle(BuildContext context, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDarkMode ? 50 : 20),
              blurRadius: 20,
            ),
          ],
        ),
        child: Column(
          children: [
            const BusIllustration(height: 120),
            const SizedBox(height: 20),
            Text(
              'No Active Trips',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'When the school bus starts its route, you\'ll see live updates here',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.white60 : Colors.grey,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () =>
                    Navigator.pushNamed(context, '/manage-children'),
                icon: const Icon(Icons.child_care),
                label: const Text('Manage Children'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Color(0xFF6B9B5B)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
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

    // Get the guardian's children from the trip
    final guardianChildren = trip.students
        .where(
          (s) =>
              // In real app, filter by guardian's child IDs
              true,
        )
        .toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Live tracking mini card - now tappable to open unified trip view
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/start-trip'),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6B9B5B), Color(0xFF5A8A4A)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6B9B5B).withAlpha(100),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(30),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.directions_bus,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trip.routeName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'Bus ${trip.vehicleNumber ?? '...'}',
                              style: TextStyle(
                                color: Colors.white.withAlpha(230),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(30),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'LIVE',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildLiveStat(
                      icon: Icons.access_time,
                      value: '15 min', // TODO: Calculate from trip data
                      label: 'ETA',
                    ),
                    _buildLiveStat(
                      icon: Icons.speed,
                      value: '32 km/h',
                      label: 'Speed',
                    ),
                    _buildLiveStat(
                      icon: Icons.location_on,
                      value: '2.4 km',
                      label: 'Distance',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pushNamed(
                          context,
                          '/osm-tracking',
                          arguments: {
                            'tripId': trip.id,
                            'busId': trip.vehicleId,
                            'routeId': trip.routeId,
                          },
                        ),
                        icon: const Icon(Icons.map),
                        label: const Text('Track'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF6B9B5B),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _openTripChat(context, trip),
                        icon: const Icon(Icons.chat),
                        label: const Text('Chat'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withAlpha(30),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ),

          const SizedBox(height: 20),

          // Child status section
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Your Child\'s Status',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Child status cards
          ...guardianChildren.map(
            (student) => _buildChildStatusCard(student, isDarkMode),
          ),

          if (guardianChildren.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? const Color(0xFF1E1E1E)
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: isDarkMode ? Colors.white60 : Colors.grey,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your child is not assigned to this trip',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white70 : Colors.grey,
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

  Widget _buildLiveStat({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildChildStatusCard(StudentPickup student, bool isDarkMode) {
    final isPicked = student.status == 'picked';
    final isDropped = student.status == 'dropped';

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (isPicked) {
      statusColor = Colors.green;
      statusText = 'Picked Up';
      statusIcon = Icons.check_circle;
    } else if (isDropped) {
      statusColor = Colors.blue;
      statusText = 'Dropped Off';
      statusIcon = Icons.home;
    } else {
      statusColor = Colors.orange;
      statusText = 'Waiting';
      statusIcon = Icons.schedule;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withAlpha(50), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: Icon(statusIcon, color: statusColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (student.pickupTime != null)
            Text(
              '${student.pickupTime!.hour}:${student.pickupTime!.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                color: isDarkMode ? Colors.white60 : Colors.grey,
                fontSize: 12,
              ),
            ),
        ],
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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (isDriver)
                Expanded(
                  child: _buildQuickActionCard(
                    icon: Icons.settings,
                    label: 'Manage Trips',
                    color: const Color(0xFF6B9B5B),
                    onTap: () => Navigator.pushNamed(context, '/manage-master-trips'),
                    isDarkMode: isDarkMode,
                  ),
                )
              else
                Expanded(
                  child: _buildQuickActionCard(
                    icon: Icons.child_care,
                    label: 'My Children',
                    color: const Color(0xFFE91E63),
                    onTap: () =>
                        Navigator.pushNamed(context, '/manage-children'),
                    isDarkMode: isDarkMode,
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionCard(
                  icon: Icons.map,
                  label: 'Live Track',
                  color: const Color(0xFFFF9800),
                  onTap: () => Navigator.pushNamed(
                    context,
                    '/osm-tracking',
                    arguments: {
                      'tripId': 'TRIP_001',
                      'busId': 'BUS001',
                      'routeId': 'ROUTE_001',
                    },
                  ),
                  isDarkMode: isDarkMode,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionCard(
                  icon: isDriver ? Icons.history : Icons.local_shipping,
                  label: isDriver ? 'History' : 'My Trips',
                  color: const Color(0xFF9C27B0),
                  onTap: () => Navigator.pushNamed(context, '/trips'),
                  isDarkMode: isDarkMode,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required bool isDarkMode,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDarkMode ? 30 : 10),
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== DIALOGS ====================

  void _showEndTripDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Trip?'),
        content: const Text(
          'Are you sure you want to end this trip? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement end trip logic
              _endTrip();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('End Trip'),
          ),
        ],
      ),
    );
  }

  Future<void> _endTrip() async {
    final tripProvider = context.read<TripProvider>();
    // TODO: Implement actual end trip API call
    await tripProvider.fetchActiveTrip(); // Refresh to update status
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
