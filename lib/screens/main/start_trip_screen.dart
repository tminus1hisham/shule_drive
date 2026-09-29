import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../theme/app_spacing.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/master_trip.dart';
import '../../models/preloaded_trip_data.dart';
import '../../api/services/bus_service.dart';
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/trip_provider.dart';
import '../../api/api.dart' as api;
import '../../services/trip_history_service.dart';
import '../../widgets/main_scaffold.dart';

import '../../theme/app_colors.dart';
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
///
/// Arguments:
/// - masterTrip: Pre-selected MasterTrip from trip selection (optional)
/// - vehicle: Pre-selected Bus from vehicle selection (optional)
/// - preSelectedRoute: Route name to pre-select (optional)
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

  // Driver specific buses
  List<api.Bus> _driverBuses = [];

  // Pre-populated data from navigation arguments
  MasterTrip? _preSelectedMasterTrip;
  Bus? _preSelectedVehicle;
  String? _preSelectedRouteName;
  PreloadedTripData? _preloadedData;

  bool _isLoading = false;
  int _currentStep = 0;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: AppDuration.medium,
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: AppCurves.easeOut,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: AppCurves.easeOut,
          ),
        );

    _animationController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _processArguments();
      _loadData();
    });
  }

  /// Process navigation arguments to pre-populate selections
  void _processArguments() {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    if (args != null) {
      _preSelectedMasterTrip = args['masterTrip'] as MasterTrip?;
      _preSelectedVehicle = args['vehicle'] as Bus?;
      _preSelectedRouteName = args['preSelectedRoute'] as String?;
      // Parse preloaded data from Map
      final preloadedDataMap = args['preloadedData'] as Map<String, dynamic>?;
      if (preloadedDataMap != null) {
        _preloadedData = PreloadedTripData.fromJson(preloadedDataMap);
      }

      if (kDebugMode) {
        print('🎯 StartTripScreen received arguments:');
        print('   MasterTrip: ${_preSelectedMasterTrip?.tripName}');
        print('   Vehicle: ${_preSelectedVehicle?.registrationNumber}');
        print('   Route: $_preSelectedRouteName');
        print('   Preloaded Students: ${_preloadedData?.students.length ?? 0}');
      }
    }
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

    // Fetch active trip - role-specific
    if (authProvider.isGuardian) {
      // Guardians: Check if their children are on active trips
      final hasPhone =
          authProvider.userPhone != null && authProvider.userPhone!.isNotEmpty;
      if (hasPhone) {
        await tripProvider.fetchActiveTrip(
          guardianPhone: authProvider.userPhone,
        );
      }
    } else if (authProvider.isDriver) {
      // Drivers: Skip guardian endpoint - they just selected a trip to start
      // The active trip check happens via preloaded data or will be created when they start
      if (kDebugMode) {
        print('🚀 Driver starting trip - skipping guardian active trip check');
      }
    }

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
            print(
              '🔄 StartTripScreen: School ID missing, refreshing user data...',
            );
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
          await Future.wait([provider.fetchRoutes(), provider.fetchBuses()]);
        } else {
          if (kDebugMode) {
            print('🏫 StartTripScreen: Loading data for school $schoolId');
          }
          // Fetch school-scoped data (pass school name for route filtering fallback)
          await provider.fetchAllSchoolData(
            schoolId,
            schoolName: user?.schoolName,
          );
        }

        if (kDebugMode) {
          print('✅ StartTripScreen: Data loaded successfully');
          print('📍 Routes: ${provider.routes.length}');
          print('🚌 Buses: ${provider.buses.length}');
          for (final route in provider.routes) {
            print(
              '  - Route: ${route.name} (ID: ${route.id}, School: ${route.schoolId})',
            );
          }
        }

        // Also load driver's specific buses
        try {
          final busService = BusService();
          final userBuses = await busService.getBusesByUser();
          if (mounted) {
            setState(() {
              _driverBuses = userBuses;
            });
          }
          if (kDebugMode) {
            print('🚌 Driver specific buses loaded: ${_driverBuses.length}');
          }
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ Error loading driver buses: $e');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ StartTripScreen: Error loading data: $e');
        }
      }
    }

    // Apply pre-selected values after data is loaded
    _applyPreSelectedValues(provider);

    // Auto-start trip if everything is pre-selected
    await _tryAutoStartTrip();

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  /// Route and bus are chosen: start straight away.
  Future<void> _tryAutoStartTrip() async {
    if (_preSelectedMasterTrip != null && _selectedVehicle != null) {
      await _startTrip();
    }
  }

  bool _isStartingTrip = false;

  String get _selectedNumberPlate {
    for (final bus in _driverBuses) {
      if (bus.id == _selectedVehicle) return bus.registrationNumber;
    }
    return _preSelectedMasterTrip?.numberPlate ?? _selectedVehicle ?? '';
  }

  /// Start the trip on the server and open the live map. Students are added
  /// from the map (its Add button is always there), not beforehand.
  Future<void> _startTrip() async {
    if (_isStartingTrip || !_canStartTrip) return;
    setState(() => _isStartingTrip = true);

    final tripProvider = context.read<TripProvider>();
    final authProvider = context.read<AuthProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Refuse a second trip while one is still running, possibly left
      // active from an earlier session or another device.
      await tripProvider.fetchActiveTrip(driverId: authProvider.userId);
      final existing = tripProvider.activeTrip;
      if (existing != null && existing.isActive) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'A trip is already in progress. End it before starting a new one.',
            ),
            backgroundColor: AppPalette.warning,
          ),
        );
        navigator.pushReplacementNamed(
          '/osm-tracking',
          arguments: {'tripId': existing.id, 'preloadedData': null},
        );
        return;
      }

      final masterTrip = _preSelectedMasterTrip;
      final roster = _preloadedData?.students ?? const <TripStudent>[];
      final plate = _selectedNumberPlate;
      final routeName = _preSelectedRouteName ?? masterTrip?.route ?? '';
      final trip = await tripProvider.startTrip(
        routeId: _selectedRoute!,
        vehicleId: _selectedVehicle!,
        studentIds: [for (final s in roster) s.studentId.toString()],
        masterTripId: masterTrip?.id,
        route: routeName,
        tripName: masterTrip?.tripName ?? 'Trip',
        driverName: authProvider.userName ?? 'Unknown Driver',
        driverPhoneNumber: authProvider.userPhone ?? '',
        numberPlate: plate,
      );
      if (trip == null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(tripProvider.errorMessage ?? 'Failed to start trip'),
            backgroundColor: AppPalette.error,
          ),
        );
        return;
      }

      // The start API returns no students; seed them (with their saved
      // coordinates) so status changes and guardian alerts have a roster.
      tripProvider.hydrateActiveTrip(
        roster: [
          for (final s in roster) api.StudentPickup.fromJson(s.toJson()),
        ],
        vehicleNumber: plate,
        routeName: routeName,
      );
      if (authProvider.isDriver) {
        await TripHistoryService().saveTripToHistory(
          trip: tripProvider.activeTrip ?? trip,
          driverId: authProvider.userId ?? '',
          driverName: authProvider.userName ?? '',
        );
      }
      // MQTT up before the first pick so the guardian alert goes out live.
      unawaited(tripProvider.initialize());

      navigator.pushReplacementNamed(
        '/osm-tracking',
        arguments: {
          'tripId': trip.id,
          'preloadedData': _preloadedData?.toJson(),
        },
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error starting trip: $e'),
          backgroundColor: AppPalette.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isStartingTrip = false);
    }
  }

  /// Apply pre-selected values from navigation arguments
  void _applyPreSelectedValues(AppProvider provider) {
    if (_preSelectedVehicle != null) {
      // Find matching vehicle in loaded buses
      try {
        final busesToSearch = _driverBuses.isNotEmpty
            ? _driverBuses
            : provider.buses;
        final matchingBus = busesToSearch.firstWhere(
          (bus) =>
              bus.id == _preSelectedVehicle!.id ||
              bus.registrationNumber == _preSelectedVehicle!.registrationNumber,
        );
        _selectedVehicle = matchingBus.id;
        if (kDebugMode) {
          print(
            '✅ Pre-selected vehicle applied: ${matchingBus.registrationNumber}',
          );
        }
      } catch (e) {
        // No matching bus found
        if (kDebugMode) {
          print('⚠️ Pre-selected vehicle not found in loaded buses');
        }
      }
    }

    if (_preSelectedRouteName != null) {
      // Find matching route by name
      try {
        final matchingRoute = provider.routes.firstWhere(
          (route) => route.name == _preSelectedRouteName,
        );
        _selectedRoute = matchingRoute.id;
        if (kDebugMode) {
          print('✅ Pre-selected route applied: ${matchingRoute.name}');
        }
      } catch (e) {
        // No matching route found
        if (kDebugMode) {
          print('⚠️ Pre-selected route not found in loaded routes');
        }
      }
    }

    // If master trip has a numberPlate, try to match it
    if (_preSelectedMasterTrip?.numberPlate != null &&
        _selectedVehicle == null) {
      try {
        final busesToSearch = _driverBuses.isNotEmpty
            ? _driverBuses
            : provider.buses;
        final matchingBus = busesToSearch.firstWhere(
          (bus) =>
              bus.registrationNumber == _preSelectedMasterTrip!.numberPlate,
        );
        _selectedVehicle = matchingBus.id;
        if (kDebugMode) {
          print(
            '✅ Vehicle matched from master trip numberPlate: ${matchingBus.registrationNumber}',
          );
        }
      } catch (e) {
        // No matching bus found
        if (kDebugMode) {
          print('⚠️ Vehicle from master trip numberPlate not found');
        }
      }
    }

    // Update current step based on selections
    if (_selectedRoute != null) {
      _currentStep = _selectedVehicle != null ? 2 : 1;
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
                ? [AppPalette.surfaceDark, AppPalette.bgDark]
                : [AppPalette.bgLight, Colors.white],
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
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppPalette.emerald,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Loading trip...',
                          style: TextStyle(
                            color: isDarkMode
                                ? AppPalette.textSecondaryDark
                                : AppPalette.textSecondaryLight,
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
                          ? _buildGuardianActiveTripView(
                              tripProvider.activeTrip!,
                              isDarkMode,
                            )
                          : _buildDriverActiveTripView(
                              tripProvider.activeTrip!,
                              isDarkMode,
                            ),
                    ),
                  ),
                ),
                // Bottom action buttons based on role
                isGuardian
                    ? _buildGuardianBottomActions(
                        isDarkMode,
                        tripProvider.activeTrip!,
                      )
                    : _buildDriverBottomActions(
                        isDarkMode,
                        tripProvider.activeTrip!,
                      ),
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

  Widget _buildHeader(
    bool isDarkMode,
    AuthProvider authProvider,
    bool hasActiveTrip,
    bool isGuardian,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Animated Bus Icon
          TweenAnimationBuilder(
            tween: Tween<double>(begin: 0, end: 1),
            duration: AppDuration.slow,
            curve: AppCurves.easeOut,
            builder: (context, value, child) {
              return Transform.scale(
                scale: 0.9 + (0.1 * value),
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: hasActiveTrip
                        ? const LinearGradient(
                            colors: [AppPalette.info, AppPalette.info],
                          )
                        : const LinearGradient(
                            colors: [AppPalette.emerald, AppPalette.emeraldPressed],
                          ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: hasActiveTrip
                            ? AppPalette.info.withAlpha(100)
                            : AppPalette.emerald.withAlpha(100),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Icon(
                    hasActiveTrip
                        ? Icons.location_on
                        : (isGuardian
                              ? Icons.family_restroom
                              : Icons.directions_bus),
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
              color: isDarkMode ? AppPalette.textPrimaryDark : AppPalette.textPrimaryLight,
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
              color: isDarkMode ? AppPalette.textSecondaryDark : AppPalette.textSecondaryLight,
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
                colors: [AppPalette.emerald, AppPalette.emeraldPressed],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppPalette.emerald.withAlpha(100),
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
                        color: AppPalette.error,
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
                color: isDarkMode ? AppPalette.textPrimaryDark : AppPalette.textPrimaryLight,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Child status cards
          ...guardianChildren.map(
            (student) => _buildGuardianChildCard(student, isDarkMode),
          ),

          if (guardianChildren.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? AppPalette.surfaceDark
                    : AppPalette.surfaceSubtleLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: isDarkMode ? Colors.white60 : AppPalette.textMutedLight,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your child is not assigned to this trip',
                      style: TextStyle(
                        color: isDarkMode
                            ? AppPalette.textSecondaryDark
                            : AppPalette.textSecondaryLight,
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
              color: isDarkMode
                  ? const Color(0xFF1E3A5F)
                  : const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDarkMode
                    ? AppPalette.info
                    : const Color(0xFF90CAF9),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.security,
                  color: isDarkMode
                      ? AppPalette.info
                      : AppPalette.info,
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
                          color: isDarkMode
                              ? AppPalette.textPrimaryDark
                              : AppPalette.textPrimaryLight,
                        ),
                      ),
                      Text(
                        'Your child\'s location is updated in real-time. You\'ll be notified when they\'re picked up and dropped off.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode
                              ? AppPalette.textSecondaryDark
                              : AppPalette.textSecondaryLight,
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

  Widget _buildGuardianChildCard(api.StudentPickup student, bool isDarkMode) {
    final isPicked = student.status == 'picked';
    final isDropped = student.status == 'dropped';

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (isDropped) {
      statusColor = AppPalette.info;
      statusText = 'Dropped Off';
      statusIcon = Icons.home;
    } else if (isPicked) {
      statusColor = AppPalette.success;
      statusText = 'Picked Up';
      statusIcon = Icons.check_circle;
    } else {
      statusColor = AppPalette.warning;
      statusText = 'Waiting for Pickup';
      statusIcon = Icons.schedule;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? AppPalette.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withAlpha(50), width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
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
              color: isDarkMode ? Colors.white30 : AppPalette.outlineLight,
            ),
            const SizedBox(height: 24),
            Text(
              'No Active Trip',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? AppPalette.textPrimaryDark : AppPalette.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your child is not currently on any trip. When a trip starts, you\'ll be able to track their journey here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: isDarkMode ? AppPalette.textSecondaryDark : AppPalette.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 32),
            // Upcoming trips placeholder
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? AppPalette.surfaceDark
                    : AppPalette.surfaceSubtleLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.schedule,
                    color: isDarkMode
                        ? Colors.white.withAlpha(100)
                        : AppPalette.textMutedLight,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Upcoming trips will appear here',
                    style: TextStyle(
                      color: isDarkMode ? AppPalette.textSecondaryDark : AppPalette.textSecondaryLight,
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
                ? AppPalette.bgDark.withAlpha(0)
                : Colors.white.withAlpha(0),
            isDarkMode ? AppPalette.bgDark : Colors.white,
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
                      backgroundColor: AppPalette.emerald,
                      foregroundColor: Colors.white,
                      elevation: 8,
                      shadowColor: AppPalette.emerald.withAlpha(100),
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
                      foregroundColor: AppPalette.emerald,
                      side: const BorderSide(color: AppPalette.emerald),
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
                colors: [AppPalette.info, AppPalette.info],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppPalette.info.withAlpha(100),
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
              color: isDarkMode
                  ? AppPalette.surfaceDark
                  : AppPalette.surfaceSubtleLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  // Map placeholder
                  Container(
                    color: isDarkMode
                        ? AppPalette.surfaceSubtleDark
                        : AppPalette.emeraldSoftLight,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.map,
                            size: 48,
                            color: isDarkMode
                                ? Colors.white38
                                : AppPalette.emerald,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Route Map',
                            style: TextStyle(
                              color: isDarkMode
                                  ? AppPalette.textSecondaryDark
                                  : AppPalette.textSecondaryLight,
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
                ? AppPalette.bgDark.withAlpha(0)
                : Colors.white.withAlpha(0),
            isDarkMode ? AppPalette.bgDark : Colors.white,
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
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.info,
                  foregroundColor: Colors.white,
                  elevation: 8,
                  shadowColor: AppPalette.info.withAlpha(100),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => _confirmEndTrip(trip),
              icon: const Icon(Icons.stop_circle, color: AppPalette.error),
              label: const Text(
                'End Trip',
                style: TextStyle(color: AppPalette.error),
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
            color: isDarkMode ? AppPalette.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDarkMode ? Colors.white12 : AppPalette.outlineLight,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: AppPalette.emerald, size: 24),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? AppPalette.textSecondaryDark : AppPalette.textSecondaryLight,
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
    // Navigate to native Mapbox driver map with vector tiles
    // Pass preloaded students which include location data
    Navigator.pushNamed(
      context,
      '/osm-tracking',
      arguments: {'tripId': trip.id, 'preloadedData': _preloadedData?.toJson()},
    );
  }

  void _openTripChat(api.Trip trip) {
    Navigator.pushNamed(
      context,
      '/chat-detail',
      arguments: {
        'tripId': trip.id,
        'receiverName': trip.routeName,
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
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.schedule, color: AppPalette.emerald),
              title: const Text('Running Late'),
              onTap: () {
                Navigator.pop(context);
                _showSuccessSnackbar('Notification sent to guardians');
              },
            ),
            ListTile(
              leading: const Icon(Icons.traffic, color: AppPalette.emerald),
              title: const Text('Traffic Delay'),
              onTap: () {
                Navigator.pop(context);
                _showSuccessSnackbar('Notification sent to guardians');
              },
            ),
            ListTile(
              leading: const Icon(Icons.check_circle, color: AppPalette.emerald),
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
                _showErrorSnackbar(
                  tripProvider.errorMessage ?? 'Failed to end trip',
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppPalette.error),
            child: const Text(
              'End Trip',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppPalette.error,
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
        backgroundColor: AppPalette.emerald,
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
            duration: AppDuration.medium,
            curve: Curves.ease,
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: isCompleted
                  ? const LinearGradient(
                      colors: [AppPalette.emerald, AppPalette.emeraldPressed],
                    )
                  : null,
              color: isCompleted
                  ? null
                  : isActive
                  ? AppPalette.emerald.withAlpha(30)
                  : isDarkMode
                  ? AppPalette.surfaceSubtleDark
                  : AppPalette.outlineLight,
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive ? AppPalette.emerald : Colors.transparent,
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
                            ? AppPalette.emerald
                            : isDarkMode
                            ? AppPalette.textMutedDark
                            : AppPalette.textMutedLight,
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
                  ? AppPalette.emerald
                  : isDarkMode
                  ? AppPalette.textMutedDark
                  : AppPalette.textMutedLight,
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
        duration: AppDuration.medium,
        curve: Curves.ease,
        height: 3,
        margin: const EdgeInsets.only(bottom: 25),
        decoration: BoxDecoration(
          gradient: isCompleted
              ? const LinearGradient(
                  colors: [AppPalette.emerald, AppPalette.emeraldPressed],
                )
              : null,
          color: isCompleted
              ? null
              : isDarkMode
              ? AppPalette.surfaceSubtleDark
              : AppPalette.outlineLight,
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
            valueColor: AlwaysStoppedAnimation<Color>(AppPalette.emerald),
          ),
          const SizedBox(height: 20),
          Text(
            'Loading your trips...',
            style: TextStyle(
              color: isDarkMode ? Colors.white60 : AppPalette.textMutedLight,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionContent(AppProvider provider, bool isDarkMode) {
    final routes = provider.routes;
    // Use driver specific buses if available, otherwise fallback to provider.buses
    final buses = _driverBuses.isNotEmpty ? _driverBuses : provider.buses;

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
            color: AppPalette.emerald,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? AppPalette.textPrimaryDark : AppPalette.textPrimaryLight,
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
            duration: AppDuration.fast,
            curve: Curves.ease,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(
                      colors: [AppPalette.emerald, AppPalette.emeraldPressed],
                    )
                  : null,
              color: isSelected
                  ? null
                  : isDarkMode
                  ? AppPalette.surfaceDark
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? Colors.transparent
                    : isDarkMode
                    ? Colors.white12
                    : AppPalette.outlineLight,
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
                        : AppPalette.emerald.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected ? Colors.white : AppPalette.emerald,
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
                              ? AppPalette.textPrimaryDark
                              : AppPalette.textPrimaryLight,
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
                              ? AppPalette.textSecondaryDark
                              : AppPalette.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle, color: Colors.white, size: 28),
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
          backgroundColor: isDarkMode ? AppPalette.surfaceDark : Colors.white,
          selectedColor: AppPalette.emerald,
          labelStyle: TextStyle(
            color: isSelected
                ? Colors.white
                : isDarkMode
                ? AppPalette.textSecondaryDark
                : AppPalette.textSecondaryLight,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSelected
                  ? Colors.transparent
                  : isDarkMode
                  ? Colors.white12
                  : AppPalette.outlineLight,
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
        color: isDarkMode ? AppPalette.surfaceDark : AppPalette.surfaceSubtleLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: isDarkMode ? Colors.white.withAlpha(100) : AppPalette.textMutedLight,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: isDarkMode ? AppPalette.textSecondaryDark : AppPalette.textSecondaryLight,
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
                ? AppPalette.bgDark.withAlpha(0)
                : Colors.white.withAlpha(0),
            isDarkMode ? AppPalette.bgDark : Colors.white,
          ],
        ),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton(
            onPressed: _canStartTrip && !_isStartingTrip ? _startTrip : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppPalette.emerald,
              foregroundColor: Colors.white,
              disabledBackgroundColor: isDarkMode
                  ? AppPalette.surfaceSubtleDark
                  : AppPalette.outlineLight,
              disabledForegroundColor: isDarkMode
                  ? Colors.white30
                  : AppPalette.textMutedLight,
              elevation: _canStartTrip ? 8 : 0,
              shadowColor: AppPalette.emerald.withAlpha(100),
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
                    : AppPalette.textMutedLight,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
