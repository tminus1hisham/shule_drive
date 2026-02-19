import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/trip_provider.dart';
import '../../api/api.dart' as api;
import '../../widgets/main_scaffold.dart';

/// Start Trip Screen - Unified trip view for both drivers and guardians
/// 
/// Driver Mode:
/// - Can start new trips
/// - Can pick/drop students
/// - Can complete trip
/// - Can message guardians
///
/// Guardian Mode:
/// - View-only access to child's trip
/// - Can track bus location
/// - Can chat with driver
class StartTripScreen extends StatefulWidget {
  const StartTripScreen({super.key});

  @override
  State<StartTripScreen> createState() => _StartTripScreenState();
}

class _StartTripScreenState extends State<StartTripScreen>
    with TickerProviderStateMixin {
  String? _selectedVehicle;
  String? _selectedRoute;
  String? _selectedAttendant;

  bool _isLoading = false;
  int _currentStep = 0;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _animationController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final provider = context.read<AppProvider>();
    final authProvider = context.read<AuthProvider>();
    final tripProvider = context.read<TripProvider>();

    // Fetch active trip for both drivers and guardians
    final hasPhone =
        authProvider.userPhone != null && authProvider.userPhone!.isNotEmpty;
    final guardianPhone = hasPhone ? authProvider.userPhone : null;
    await tripProvider.fetchActiveTrip(guardianPhone: guardianPhone);

    // Only drivers need to load routes and buses
    if (authProvider.isDriver) {
      if (kDebugMode) {
        print('🚀 StartTripScreen: Loading school-scoped data for driver...');
      }

      try {
        // Get driver's school ID from their profile
        var user = authProvider.currentUser;
        var schoolId = user?.schoolId;

        // If schoolId is missing, try to refresh user data from API
        if (schoolId == null || schoolId.isEmpty) {
          if (kDebugMode) {
            print('🔄 StartTripScreen: School ID missing, refreshing user data...');
          }
          await authProvider.refreshUserData();
          user = authProvider.currentUser;
          schoolId = user?.schoolId;
        }

        if (kDebugMode) {
          print('👤 Current user: ${user?.name}, ID: ${user?.id}');
          print('🏫 School ID from user: $schoolId');
          print('🏫 School name from user: ${user?.schoolName}');
        }

        if (schoolId == null || schoolId.isEmpty) {
          if (kDebugMode) {
            print('⚠️ StartTripScreen: No school ID found for driver');
            print('   Falling back to non-scoped data (showing all schools)');
          }
          // Fallback to non-scoped data for backward compatibility
          await Future.wait([
            provider.fetchRoutes(),
            provider.fetchBuses(),
          ]);
        } else {
          if (kDebugMode) {
            print('🏫 StartTripScreen: Loading data for school $schoolId');
          }
          // Fetch school-scoped data (pass school name for route filtering fallback)
          await provider.fetchAllSchoolData(schoolId, schoolName: user?.schoolName);
        }

        if (kDebugMode) {
          print('✅ StartTripScreen: Data loaded successfully');
          print('📍 Routes: ${provider.routes.length}');
          print('🚌 Buses: ${provider.buses.length}');
          for (final route in provider.routes) {
            print('  - Route: ${route.name} (ID: ${route.id}, School: ${route.schoolId})');
          }
          for (final bus in provider.buses) {
            print('  - Bus: ${bus.registrationNumber} (ID: ${bus.id}, School: ${bus.schoolId})');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ StartTripScreen: Error loading data: $e');
        }
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  bool get _canStartTrip => _selectedRoute != null && _selectedVehicle != null;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final authProvider = context.watch<AuthProvider>();
    final tripProvider = context.watch<TripProvider>();
    final isDarkMode = provider.isDarkMode;
    final hasActiveTrip = tripProvider.activeTrip != null;
    final isDriver = authProvider.isDriver;
    final isGuardian = authProvider.isGuardian;

    // Debug logging
    if (kDebugMode) {
      print('🏗️ StartTripScreen build:');
      print('   isDriver: $isDriver, isGuardian: $isGuardian');
      print('   hasActiveTrip: $hasActiveTrip');
      print('   activeTrip: ${tripProvider.activeTrip?.id}');
      print('   isLoading: $_isLoading');
    }

    return MainScaffold(
      title: hasActiveTrip 
          ? (isGuardian ? 'Track Trip' : 'Active Trip')
          : (isGuardian ? 'My Child\'s Trips' : 'New Trip'),
      showBackButton: true,
      showBottomNav: false,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDarkMode
                ? [const Color(0xFF1A1A1A), const Color(0xFF0D0D0D)]
                : [const Color(0xFFF5F5F0), Colors.white],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header Section with Animation
              _buildHeader(isDarkMode, authProvider, hasActiveTrip, isGuardian),

              // Show loading state while fetching data
              if (_isLoading || tripProvider.isLoading) ...[
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6B9B5B)),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Loading trip...',
                          style: TextStyle(
                            color: isDarkMode ? Colors.white60 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else if (hasActiveTrip) ...[
                // Active Trip Card - Different views for driver vs guardian
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: isGuardian
                          ? _buildGuardianActiveTripView(tripProvider.activeTrip!, isDarkMode)
                          : _buildDriverActiveTripView(tripProvider.activeTrip!, isDarkMode),
                    ),
                  ),
                ),
                // Bottom action buttons based on role
                isGuardian
                    ? _buildGuardianBottomActions(isDarkMode, tripProvider.activeTrip!)
                    : _buildDriverBottomActions(isDarkMode, tripProvider.activeTrip!),
              ] else ...[
                // No active trip
                if (isGuardian)
                  Expanded(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: _buildGuardianNoTripView(isDarkMode),
                      ),
                    ),
                  )
                else ...[
                  // Progress Indicator for driver
                  _buildProgressIndicator(isDarkMode),

                  // Main Content for driver to start new trip
                  Expanded(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: _isLoading
                            ? _buildLoadingState(isDarkMode)
                            : _buildSelectionContent(provider, isDarkMode),
                      ),
                    ),
                  ),

                  // Bottom Action Button for driver
                  _buildBottomButton(isDarkMode),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ==================== HEADER ====================

  Widget _buildHeader(bool isDarkMode, AuthProvider authProvider, bool hasActiveTrip, bool isGuardian) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Animated Bus Icon
          TweenAnimationBuilder(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 1000),
            builder: (context, value, child) {
              return Transform.scale(
                scale: 0.8 + (0.2 * value),
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: hasActiveTrip
                        ? const LinearGradient(
                            colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                          )
                        : const LinearGradient(
                            colors: [Color(0xFF6B9B5B), Color(0xFF5A8A4A)],
                          ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: hasActiveTrip
                            ? const Color(0xFF2196F3).withAlpha(100)
                            : const Color(0xFF6B9B5B).withAlpha(100),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Icon(
                    hasActiveTrip ? Icons.location_on : (isGuardian ? Icons.family_restroom : Icons.directions_bus),
                    color: Colors.white,
                    size: 50,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          Text(
            hasActiveTrip 
                ? (isGuardian ? 'Child on Trip' : 'Trip in Progress')
                : (isGuardian ? 'No Active Trip' : 'Ready to Roll?'),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasActiveTrip
                ? (isGuardian 
                    ? 'Track your child\'s journey in real-time'
                    : 'Continue monitoring your active trip')
                : (isGuardian
                    ? 'Your child is not on any active trip'
                    : 'Configure your trip details below'),
            style: TextStyle(
              fontSize: 15,
              color: isDarkMode ? Colors.white60 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== GUARDIAN VIEWS ====================

  Widget _buildGuardianActiveTripView(api.Trip trip, bool isDarkMode) {
    // Get guardian's children from the trip
    final guardianChildren = trip.students.where((s) => true).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Live Trip Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6B9B5B), Color(0xFF5A8A4A)],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6B9B5B).withAlpha(100),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Live indicator
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'LIVE TRACKING',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(30),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        trip.status.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Route name
                Text(
                  trip.routeName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                // Vehicle info
                Row(
                  children: [
                    const Icon(
                      Icons.directions_bus,
                      color: Colors.white70,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Bus ${trip.vehicleNumber ?? 'Unknown'}',
                      style: TextStyle(
                        color: Colors.white.withAlpha(230),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildGuardianStat(
                      Icons.access_time,
                      '${DateTime.now().difference(trip.startTime).inMinutes}m',
                      'Duration',
                    ),
                    _buildGuardianStat(
                      Icons.people,
                      '${trip.pickedCount}/${trip.students.length}',
                      'Picked Up',
                    ),
                    _buildGuardianStat(
                      Icons.pending,
                      '${trip.pendingCount}',
                      'Remaining',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Child Status Section
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Your Child\'s Status',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Child status cards
          ...guardianChildren.map((student) => _buildGuardianChildCard(student, isDarkMode)),

          if (guardianChildren.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey.shade50,
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
                        color: isDarkMode ? Colors.white70 : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),

          // Safety Info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1E3A5F) : const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDarkMode ? const Color(0xFF2196F3) : const Color(0xFF90CAF9),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.security,
                  color: isDarkMode ? const Color(0xFF2196F3) : const Color(0xFF1976D2),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Safety First',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
                        ),
                      ),
                      Text(
                        'Your child\'s location is updated in real-time. You\'ll be notified when they\'re picked up and dropped off.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode ? Colors.white70 : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuardianStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withAlpha(200),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildGuardianChildCard(api.StudentPickup student, bool isDarkMode) {
    final isPicked = student.status == 'picked';
    final isDropped = student.status == 'dropped';

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (isDropped) {
      statusColor = Colors.blue;
      statusText = 'Dropped Off';
      statusIcon = Icons.home;
    } else if (isPicked) {
      statusColor = Colors.green;
      statusText = 'Picked Up';
      statusIcon = Icons.check_circle;
    } else {
      statusColor = Colors.orange;
      statusText = 'Waiting for Pickup';
      statusIcon = Icons.schedule;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withAlpha(50),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: Icon(statusIcon, color: statusColor, size: 24),
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
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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

  Widget _buildGuardianNoTripView(bool isDarkMode) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today,
              size: 80,
              color: isDarkMode ? Colors.white30 : Colors.grey.shade300,
            ),
            const SizedBox(height: 24),
            Text(
              'No Active Trip',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your child is not currently on any trip. When a trip starts, you\'ll be able to track their journey here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: isDarkMode ? Colors.white60 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 32),
            // Upcoming trips placeholder
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.schedule,
                    color: isDarkMode ? Colors.white.withAlpha(100) : Colors.grey.shade400,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Upcoming trips will appear here',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white60 : Colors.grey.shade600,
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

  Widget _buildGuardianBottomActions(bool isDarkMode, api.Trip trip) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            isDarkMode
                ? const Color(0xFF0D0D0D).withAlpha(0)
                : Colors.white.withAlpha(0),
            isDarkMode ? const Color(0xFF0D0D0D) : Colors.white,
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openLiveTracking(trip),
                    icon: const Icon(Icons.map),
                    label: const Text(
                      'Track Location',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6B9B5B),
                      foregroundColor: Colors.white,
                      elevation: 8,
                      shadowColor: const Color(0xFF6B9B5B).withAlpha(100),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openTripChat(trip),
                    icon: const Icon(Icons.chat),
                    label: const Text('Chat with Driver'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6B9B5B),
                      side: const BorderSide(color: Color(0xFF6B9B5B)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==================== DRIVER VIEWS ====================

  Widget _buildDriverActiveTripView(api.Trip trip, bool isDarkMode) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Active Trip Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2196F3).withAlpha(100),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Live indicator
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(30),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        trip.status.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Route name
                Text(
                  trip.routeName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                // Vehicle info
                Row(
                  children: [
                    const Icon(
                      Icons.directions_bus,
                      color: Colors.white70,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      trip.vehicleNumber ?? 'Unknown Vehicle',
                      style: TextStyle(
                        color: Colors.white.withAlpha(230),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Stats
                Row(
                  children: [
                    _buildDriverStat(
                      Icons.people,
                      '${trip.pickedCount}/${trip.students.length}',
                      'Students',
                    ),
                    const SizedBox(width: 24),
                    _buildDriverStat(
                      Icons.access_time,
                      '${DateTime.now().difference(trip.startTime).inMinutes}m',
                      'Duration',
                    ),
                    const SizedBox(width: 24),
                    _buildDriverStat(
                      Icons.check_circle,
                      '${trip.pendingCount}',
                      'Remaining',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Quick Actions
          Row(
            children: [
              Expanded(
                child: _buildQuickActionButton(
                  icon: Icons.chat,
                  label: 'Chat',
                  onTap: () => _openTripChat(trip),
                  isDarkMode: isDarkMode,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionButton(
                  icon: Icons.people_outline,
                  label: 'Students',
                  onTap: () => Navigator.pushNamed(
                    context,
                    '/students-list',
                    arguments: {'tripId': trip.id},
                  ),
                  isDarkMode: isDarkMode,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionButton(
                  icon: Icons.notifications,
                  label: 'Notify',
                  onTap: () => _showNotifyOptions(),
                  isDarkMode: isDarkMode,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Trip Preview Map
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  // Map placeholder
                  Container(
                    color: isDarkMode 
                        ? const Color(0xFF2C2C2C) 
                        : const Color(0xFFE8F5E9),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.map,
                            size: 48,
                            color: isDarkMode 
                                ? Colors.white38 
                                : const Color(0xFF6B9B5B),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Route Map',
                            style: TextStyle(
                              color: isDarkMode 
                                  ? Colors.white60 
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Tap to open full map
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _openLiveTracking(trip),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withAlpha(100),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: const Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.fullscreen,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Open Live Map',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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

  Widget _buildDriverStat(IconData icon, String value, String label) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withAlpha(200),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDriverBottomActions(bool isDarkMode, api.Trip trip) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            isDarkMode
                ? const Color(0xFF0D0D0D).withAlpha(0)
                : Colors.white.withAlpha(0),
            isDarkMode ? const Color(0xFF0D0D0D) : Colors.white,
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: () => _openLiveTracking(trip),
                icon: const Icon(Icons.map),
                label: const Text(
                  'Open Live Map',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                  elevation: 8,
                  shadowColor: const Color(0xFF2196F3).withAlpha(100),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => _confirmEndTrip(trip),
              icon: const Icon(Icons.stop_circle, color: Colors.red),
              label: const Text(
                'End Trip',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== SHARED WIDGETS ====================

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDarkMode,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDarkMode ? Colors.white12 : Colors.grey.shade200,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: const Color(0xFF6B9B5B),
                size: 24,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? Colors.white70 : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== ACTIONS ====================

  void _openLiveTracking(api.Trip trip) {
    Navigator.pushNamed(
      context,
      '/active-trip',
      arguments: {'tripId': trip.id},
    );
  }

  void _openTripChat(api.Trip trip) {
    Navigator.pushNamed(
      context,
      '/chat-detail',
      arguments: {
        'tripId': trip.id,
        'receiverName': trip.routeName ?? 'Trip Chat',
        'receiverRole': 'Group',
        'isGroupChat': true,
      },
    );
  }

  void _showNotifyOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Send Notification',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.schedule, color: Color(0xFF6B9B5B)),
              title: const Text('Running Late'),
              onTap: () {
                Navigator.pop(context);
                _showSuccessSnackbar('Notification sent to guardians');
              },
            ),
            ListTile(
              leading: const Icon(Icons.traffic, color: Color(0xFF6B9B5B)),
              title: const Text('Traffic Delay'),
              onTap: () {
                Navigator.pop(context);
                _showSuccessSnackbar('Notification sent to guardians');
              },
            ),
            ListTile(
              leading: const Icon(Icons.check_circle, color: Color(0xFF6B9B5B)),
              title: const Text('On Schedule'),
              onTap: () {
                Navigator.pop(context);
                _showSuccessSnackbar('Notification sent to guardians');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmEndTrip(api.Trip trip) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Trip'),
        content: const Text(
          'Are you sure you want to end this trip? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final tripProvider = context.read<TripProvider>();
              final authProvider = context.read<AuthProvider>();
              final success = await tripProvider.endTrip(
                trip.id,
                driverId: authProvider.userData['id'],
                driverName: authProvider.userData['name'],
              );
              if (success && mounted) {
                _showSuccessSnackbar('Trip ended successfully');
              } else if (mounted) {
                _showErrorSnackbar(tripProvider.errorMessage ?? 'Failed to end trip');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('End Trip', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF6B9B5B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ==================== DRIVER NEW TRIP UI ====================

  Widget _buildProgressIndicator(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          _buildStepDot(0, 'Route', isDarkMode),
          _buildStepLine(_selectedRoute != null, isDarkMode),
          _buildStepDot(1, 'Vehicle', isDarkMode),
          _buildStepLine(_selectedVehicle != null, isDarkMode),
          _buildStepDot(2, 'Attendant', isDarkMode),
        ],
      ),
    );
  }

  Widget _buildStepDot(int step, String label, bool isDarkMode) {
    final isActive = step <= _currentStep;
    final isCompleted =
        step < _currentStep ||
        (step == 0 && _selectedRoute != null) ||
        (step == 1 && _selectedVehicle != null) ||
        (step == 2 && _selectedAttendant != null);

    return Expanded(
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: isCompleted
                  ? const LinearGradient(
                      colors: [Color(0xFF6B9B5B), Color(0xFF5A8A4A)],
                    )
                  : null,
              color: isCompleted
                  ? null
                  : isActive
                  ? const Color(0xFF6B9B5B).withAlpha(30)
                  : isDarkMode
                  ? const Color(0xFF2C2C2C)
                  : Colors.grey.shade200,
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive ? const Color(0xFF6B9B5B) : Colors.transparent,
                width: 2,
              ),
            ),
            child: Center(
              child: isCompleted
                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                  : Text(
                      '${step + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isActive
                            ? const Color(0xFF6B9B5B)
                            : isDarkMode
                            ? Colors.white38
                            : Colors.grey,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              color: isActive
                  ? const Color(0xFF6B9B5B)
                  : isDarkMode
                  ? Colors.white38
                  : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepLine(bool isCompleted, bool isDarkMode) {
    return Expanded(
      flex: 2,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 3,
        margin: const EdgeInsets.only(bottom: 25),
        decoration: BoxDecoration(
          gradient: isCompleted
              ? const LinearGradient(
                  colors: [Color(0xFF6B9B5B), Color(0xFF5A8A4A)],
                )
              : null,
          color: isCompleted
              ? null
              : isDarkMode
              ? const Color(0xFF2C2C2C)
              : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildLoadingState(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6B9B5B)),
          ),
          const SizedBox(height: 20),
          Text(
            'Loading your trips...',
            style: TextStyle(
              color: isDarkMode ? Colors.white60 : Colors.grey,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionContent(AppProvider provider, bool isDarkMode) {
    final routes = provider.routes;
    final buses = provider.buses;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Route Selection
          _buildSectionTitle('Select Route', isDarkMode),
          const SizedBox(height: 12),
          ...routes.map((route) {
            final title = route.schoolName ?? 'School Route';
            final subtitle = route.name.isNotEmpty
                ? route.name
                : 'Route ${route.id}';
            

            if (kDebugMode) {
              print(
                '🛣️ Route Card: id=${route.id}, title=$title, school=$subtitle',
              );
            }

            return _buildSelectionCard(
              title: title,
              subtitle: subtitle,
              icon: Icons.route,
              isSelected: _selectedRoute == route.id, // Use ID for selection
              onTap: () {
                setState(() {
                  _selectedRoute = route.id; // Store ID instead of name
                  _currentStep = 1;
                });
                HapticFeedback.lightImpact();
              },
              isDarkMode: isDarkMode,
            );
          }),

          if (routes.isEmpty)
            _buildEmptyState('No routes available', isDarkMode),

          const SizedBox(height: 28),

          // Vehicle Selection
          _buildSectionTitle('Select Vehicle', isDarkMode),
          const SizedBox(height: 12),
          ...buses.map((bus) {
            // Try multiple possible field names for the numberplate
            final numberplate = bus.registrationNumber.isNotEmpty
                ? bus.registrationNumber
                : 'Vehicle ${bus.id}';
            final subtitle = bus.capacity != null && bus.capacity!.isNotEmpty
                ? '${bus.capacity} seats'
                : 'School Bus';

            if (kDebugMode) {
              print(
                '🚌 Bus Card: id=${bus.id}, numberplate=$numberplate, capacity=${bus.capacity}',
              );
            }

            return _buildSelectionCard(
              title: numberplate,
              subtitle: subtitle,
              icon: Icons.directions_bus_filled,
              isSelected: _selectedVehicle == bus.id, // Use ID for selection
              onTap: () {
                setState(() {
                  _selectedVehicle = bus.id; // Store ID instead of numberplate
                  _currentStep = 2;
                });
                HapticFeedback.lightImpact();
              },
              isDarkMode: isDarkMode,
            );
          }),

          if (buses.isEmpty)
            _buildEmptyState('No vehicles available', isDarkMode),

          const SizedBox(height: 28),

          // Attendant Selection
          _buildSectionTitle('Select Attendant (Optional)', isDarkMode),
          const SizedBox(height: 12),
          _buildAttendantChips(isDarkMode),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDarkMode) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: const Color(0xFF6B9B5B),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDarkMode,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(
                      colors: [Color(0xFF6B9B5B), Color(0xFF5A8A4A)],
                    )
                  : null,
              color: isSelected
                  ? null
                  : isDarkMode
                  ? const Color(0xFF1E1E1E)
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? Colors.transparent
                    : isDarkMode
                    ? Colors.white12
                    : Colors.grey.shade200,
              ),
              boxShadow: [
                if (!isSelected)
                  BoxShadow(
                    color: Colors.black.withAlpha(isDarkMode ? 30 : 10),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withAlpha(30)
                        : const Color(0xFF6B9B5B).withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected ? Colors.white : const Color(0xFF6B9B5B),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : isDarkMode
                              ? Colors.white
                              : const Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: isSelected
                              ? Colors.white.withAlpha(230)
                              : isDarkMode
                              ? Colors.white60
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 28,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAttendantChips(bool isDarkMode) {
    final attendants = ['None', 'John Doe', 'Jane Smith', 'Mike Johnson'];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: attendants.map((attendant) {
        final isSelected = _selectedAttendant == attendant;
        final _ = attendant == 'None'; // Reserved for future use

        return ChoiceChip(
          label: Text(attendant),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              _selectedAttendant = selected ? attendant : null;
            });
          },
          backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          selectedColor: const Color(0xFF6B9B5B),
          labelStyle: TextStyle(
            color: isSelected
                ? Colors.white
                : isDarkMode
                ? Colors.white70
                : Colors.grey.shade700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSelected
                  ? Colors.transparent
                  : isDarkMode
                  ? Colors.white12
                  : Colors.grey.shade300,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyState(String message, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: isDarkMode ? Colors.white.withAlpha(100) : Colors.grey,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: isDarkMode ? Colors.white60 : Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            isDarkMode
                ? const Color(0xFF0D0D0D).withAlpha(0)
                : Colors.white.withAlpha(0),
            isDarkMode ? const Color(0xFF0D0D0D) : Colors.white,
          ],
        ),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton(
            onPressed: _canStartTrip
                ? () {
                    Navigator.pushNamed(
                      context,
                      '/select-students',
                      arguments: {
                        'routeId': _selectedRoute,
                        'vehicleId': _selectedVehicle,
                      },
                    );
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B9B5B),
              foregroundColor: Colors.white,
              disabledBackgroundColor: isDarkMode
                  ? const Color(0xFF2C2C2C)
                  : Colors.grey.shade200,
              disabledForegroundColor: isDarkMode
                  ? Colors.white30
                  : Colors.grey.shade400,
              elevation: _canStartTrip ? 8 : 0,
              shadowColor: const Color(0xFF6B9B5B).withAlpha(100),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              'Continue to Select Students',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _canStartTrip
                    ? Colors.white
                    : isDarkMode
                    ? Colors.white30
                    : Colors.grey.shade400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
