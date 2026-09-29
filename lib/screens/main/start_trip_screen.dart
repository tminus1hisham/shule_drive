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
import '../../theme/app_theme_extension.dart';
import '../../widgets/main_scaffold.dart';
import '../../widgets/ui/ui.dart';

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

class _StartTripScreenState extends State<StartTripScreen> {
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

  @override
  void initState() {
    super.initState();

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
    final appProvider = context.read<AppProvider>();
    final navigator = Navigator.of(context);
    try {
      // Refuse a second trip while one is still running, possibly left
      // active from an earlier session or another device.
      await tripProvider.fetchActiveTrip(driverId: authProvider.userId);
      final existing = tripProvider.activeTrip;
      if (existing != null && existing.isActive) {
        if (mounted) {
          AppSnackbar.info(
            context,
            'A trip is already in progress. End it before starting a new one.',
          );
        }
        navigator.pushReplacementNamed(
          '/osm-tracking',
          arguments: {'tripId': existing.id, 'preloadedData': null},
        );
        return;
      }

      final masterTrip = _preSelectedMasterTrip;
      final roster = _preloadedData?.students ?? const <TripStudent>[];
      final plate = _selectedNumberPlate;
      final routeName =
          appProvider.routes
              .where((route) => route.id == _selectedRoute)
              .map((route) => route.name)
              .firstOrNull ??
          _preSelectedRouteName ??
          masterTrip?.route;
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
        if (mounted) {
          AppSnackbar.error(
            context,
            tripProvider.errorMessage ?? 'Failed to start trip',
          );
        }
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
      if (mounted) AppSnackbar.error(context, 'Error starting trip: $e');
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
    final tripProvider = context.watch<TripProvider>();
    final activeTrip = tripProvider.activeTrip;
    final hasActiveTrip = activeTrip != null;
    final loading = _isLoading || tripProvider.isLoading;

    // Loading, active-trip and new-trip states cross-fade into each other.
    final Widget body;
    final String bodyKey;
    if (loading) {
      bodyKey = 'loading';
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: context.colors.brand),
            AppSpacing.vMd,
            Text(
              _isStartingTrip ? 'Starting trip…' : 'Loading trip…',
              style: context.text.bodyMedium?.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          ],
        ),
      );
    } else if (hasActiveTrip) {
      bodyKey = 'active';
      body = _buildDriverActiveTripView(activeTrip);
    } else {
      bodyKey = 'select';
      body = Column(
        children: [
          _buildProgressIndicator(),
          Expanded(child: _buildSelectionContent(provider)),
        ],
      );
    }

    return MainScaffold(
      title: hasActiveTrip ? 'Active Trip' : 'New Trip',
      showBackButton: true,
      showBottomNav: false,
      body: Stack(
        children: [
          const Positioned.fill(child: AppBackdrop()),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(hasActiveTrip),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: AppDuration.slow,
                    switchInCurve: AppCurves.easeOut,
                    child: KeyedSubtree(key: ValueKey(bodyKey), child: body),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomBar: loading
          ? null
          : hasActiveTrip
          ? _buildDriverBottomActions(activeTrip)
          : _buildBottomButton(),
    );
  }

  // ==================== HEADER ====================

  Widget _buildHeader(bool hasActiveTrip) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      child: Column(
        children: [
          AnimatedSwitcher(
            duration: AppDuration.slow,
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
              child: child,
            ),
            child: Container(
              key: ValueKey(hasActiveTrip),
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                gradient: hasActiveTrip ? c.accentGradient : c.brandGradient,
                borderRadius: AppRadius.brXl,
                boxShadow: [
                  BoxShadow(
                    color: (hasActiveTrip ? c.accent : c.brand).withValues(
                      alpha: 0.35,
                    ),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(
                hasActiveTrip
                    ? Icons.location_on_rounded
                    : Icons.directions_bus_rounded,
                color: Colors.white,
                size: 44,
              ),
            ),
          ).pop(),
          AppSpacing.vMd,
          Text(
            hasActiveTrip ? 'Trip in Progress' : 'Ready to Roll?',
            style: context.text.headlineMedium,
          ).enter(delay: const Duration(milliseconds: 60)),
          AppSpacing.vXxs,
          Text(
            hasActiveTrip
                ? 'Continue monitoring your active trip'
                : 'Configure your trip details below',
            style: context.text.bodyMedium?.copyWith(color: c.textSecondary),
          ).enter(delay: const Duration(milliseconds: 100)),
        ],
      ),
    );
  }

  // ==================== ACTIVE TRIP ====================

  Widget _buildDriverActiveTripView(api.Trip trip) {
    final c = context.colors;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      children: [
        GradientHeroCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          onTap: () => _openLiveTracking(trip),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const StatusPill(
                    label: 'LIVE',
                    color: Colors.white,
                    pulse: true,
                  ),
                  const Spacer(),
                  StatusPill(
                    label: trip.status.toUpperCase(),
                    color: Colors.white,
                    showDot: false,
                    dense: true,
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
              AppSpacing.vXs,
              Row(
                children: [
                  const Icon(
                    Icons.directions_bus_rounded,
                    color: Colors.white70,
                    size: 18,
                  ),
                  AppSpacing.hXs,
                  Text(
                    trip.vehicleNumber ?? 'Unknown Vehicle',
                    style: context.text.bodyLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
              AppSpacing.vLg,
              Row(
                children: [
                  TripProgress.ring(
                    done: trip.pickedCount,
                    total: trip.students.length,
                    onBrand: true,
                    size: 56,
                    thickness: 5,
                  ),
                  AppSpacing.hMd,
                  Expanded(
                    child: StatTile(
                      icon: Icons.access_time_rounded,
                      value:
                          '${DateTime.now().difference(trip.startTime).inMinutes}m',
                      label: 'Duration',
                      onLight: true,
                    ),
                  ),
                  Expanded(
                    child: StatTile(
                      icon: Icons.pending_actions_rounded,
                      value: '${trip.pendingCount}',
                      label: 'Remaining',
                      onLight: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ).enter(),
        AppSpacing.vLg,
        Row(
          children: [
            Expanded(
              child: _buildQuickActionButton(
                icon: Icons.chat_bubble_outline_rounded,
                label: 'Chat',
                color: c.info,
                onTap: () => _openTripChat(trip),
              ).enterList(1),
            ),
            AppSpacing.hSm,
            Expanded(
              child: _buildQuickActionButton(
                icon: Icons.people_outline_rounded,
                label: 'Students',
                color: c.brand,
                onTap: () => Navigator.pushNamed(
                  context,
                  '/students-list',
                  arguments: {'tripId': trip.id},
                ),
              ).enterList(2),
            ),
            AppSpacing.hSm,
            Expanded(
              child: _buildQuickActionButton(
                icon: Icons.notifications_none_rounded,
                label: 'Notify',
                color: c.accent,
                onTap: _showNotifyOptions,
              ).enterList(3),
            ),
          ],
        ),
        AppSpacing.vLg,
      ],
    );
  }

  Widget _buildDriverBottomActions(api.Trip trip) {
    return BottomActionBar(
      primary: AppButton(
        label: 'Open Live Map',
        icon: Icons.map_rounded,
        onPressed: () => _openLiveTracking(trip),
      ),
      secondary: AppButton(
        label: 'End Trip',
        icon: Icons.stop_circle_outlined,
        variant: AppButtonVariant.tertiary,
        size: AppButtonSize.medium,
        onPressed: () => _confirmEndTrip(trip),
      ),
    ).enter(offsetY: 40);
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: AppRadius.brSm,
            ),
            child: Icon(icon, color: color, size: AppIconSize.lg),
          ),
          AppSpacing.vXs,
          Text(
            label,
            style: context.text.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== ACTIONS ====================

  void _openLiveTracking(api.Trip trip) {
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
    showAppBottomSheet<void>(
      context: context,
      builder: (context) {
        final c = context.colors;
        final options = [
          (Icons.schedule_rounded, 'Running Late', c.warning),
          (Icons.traffic_rounded, 'Traffic Delay', c.accent),
          (Icons.check_circle_rounded, 'On Schedule', c.brand),
        ];
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Send Notification',
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            ),
            AppSpacing.vSm,
            for (final (i, o) in options.indexed)
              AppListTile(
                icon: o.$1,
                title: o.$2,
                iconColor: o.$3,
                onTap: () {
                  Navigator.pop(context);
                  AppSnackbar.success(
                    this.context,
                    'Notification sent to guardians',
                  );
                },
              ).enterList(i),
          ],
        );
      },
    );
  }

  Future<void> _confirmEndTrip(api.Trip trip) async {
    final confirmed = await confirmDialog(
      context,
      title: 'End Trip',
      message:
          'Are you sure you want to end this trip? This action cannot be undone.',
      confirmLabel: 'End Trip',
      icon: Icons.stop_circle_outlined,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final tripProvider = context.read<TripProvider>();
    final authProvider = context.read<AuthProvider>();
    final success = await tripProvider.endTrip(
      trip.id,
      driverId: authProvider.userData['id'],
      driverName: authProvider.userData['name'],
    );
    if (!mounted) return;
    if (success) {
      AppSnackbar.success(context, 'Trip ended successfully');
    } else {
      AppSnackbar.error(
        context,
        tripProvider.errorMessage ?? 'Failed to end trip',
      );
    }
  }

  // ==================== NEW TRIP ====================

  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Row(
        children: [
          _buildStepDot(0, 'Route'),
          _buildStepLine(_selectedRoute != null),
          _buildStepDot(1, 'Vehicle'),
          _buildStepLine(_selectedVehicle != null),
          _buildStepDot(2, 'Attendant'),
        ],
      ),
    );
  }

  Widget _buildStepDot(int step, String label) {
    final c = context.colors;
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
            curve: AppCurves.easeOut,
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: isCompleted ? c.brandGradient : null,
              color: isCompleted
                  ? null
                  : isActive
                  ? c.brandSoft
                  : c.surfaceSubtle,
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive ? c.brand : Colors.transparent,
                width: 2,
              ),
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: AppDuration.medium,
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: CurvedAnimation(
                    parent: anim,
                    curve: Curves.easeOutBack,
                  ),
                  child: child,
                ),
                child: isCompleted
                    ? const Icon(
                        Icons.check_rounded,
                        key: ValueKey('done'),
                        color: Colors.white,
                        size: 20,
                      )
                    : Text(
                        '${step + 1}',
                        key: const ValueKey('n'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isActive ? c.brand : c.textMuted,
                        ),
                      ),
              ),
            ),
          ),
          AppSpacing.vXs,
          Text(
            label,
            style: context.text.labelMedium?.copyWith(
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? c.brand : c.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepLine(bool isCompleted) {
    final c = context.colors;
    // Fills left-to-right when the step before it completes.
    return Expanded(
      flex: 2,
      child: Container(
        height: 3,
        margin: const EdgeInsets.only(bottom: 25),
        decoration: BoxDecoration(
          color: c.surfaceSubtle,
          borderRadius: AppRadius.brPill,
        ),
        alignment: Alignment.centerLeft,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: isCompleted ? 1 : 0),
          duration: AppDuration.slow,
          curve: AppCurves.easeOut,
          builder: (context, v, _) => FractionallySizedBox(
            widthFactor: v,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: c.brandGradient,
                borderRadius: AppRadius.brPill,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionContent(AppProvider provider) {
    final routes = provider.routes;
    // Use driver specific buses if available, otherwise fallback to provider.buses
    final buses = _driverBuses.isNotEmpty ? _driverBuses : provider.buses;
    var i = 0;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const SectionHeader(title: 'Select Route'),
        AppSpacing.vSm,
        for (final route in routes)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _buildSelectionCard(
              title: route.name.isNotEmpty ? route.name : 'Route ${route.id}',
              subtitle: route.schoolName ?? 'School Route',
              icon: Icons.route_rounded,
              isSelected: _selectedRoute == route.id,
              onTap: () {
                setState(() {
                  _selectedRoute = route.id;
                  _currentStep = 1;
                });
                HapticFeedback.lightImpact();
              },
            ).enterList(i++),
          ),
        if (routes.isEmpty) _buildEmptyState('No routes available'),

        AppSpacing.vXl,
        const SectionHeader(title: 'Select Vehicle'),
        AppSpacing.vSm,
        for (final bus in buses)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _buildSelectionCard(
              title: bus.registrationNumber.isNotEmpty
                  ? bus.registrationNumber
                  : 'Vehicle ${bus.id}',
              subtitle: bus.capacity != null && bus.capacity!.isNotEmpty
                  ? '${bus.capacity} seats'
                  : 'School Bus',
              icon: Icons.directions_bus_filled_rounded,
              accent: true,
              isSelected: _selectedVehicle == bus.id,
              onTap: () {
                setState(() {
                  _selectedVehicle = bus.id;
                  _currentStep = 2;
                });
                HapticFeedback.lightImpact();
              },
            ).enterList(i++),
          ),
        if (buses.isEmpty) _buildEmptyState('No vehicles available'),

        AppSpacing.vXl,
        const SectionHeader(title: 'Select Attendant (Optional)'),
        AppSpacing.vSm,
        _buildAttendantChips(),
        AppSpacing.vXl,
      ],
    );
  }

  Widget _buildSelectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    bool accent = false,
  }) {
    final c = context.colors;
    final tint = accent ? c.accent : c.brand;
    return SelectableCard(
      selected: isSelected,
      onTap: onTap,
      child: Row(
        children: [
          AnimatedContainer(
            duration: AppDuration.medium,
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? (accent ? c.accentGradient : c.brandGradient)
                  : null,
              color: isSelected ? null : tint.withValues(alpha: 0.12),
              borderRadius: AppRadius.brSm,
            ),
            child: Icon(
              icon,
              color: isSelected ? Colors.white : tint,
              size: AppIconSize.lg,
            ),
          ),
          AppSpacing.hMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: context.text.bodySmall?.copyWith(
                    color: c.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendantChips() {
    // ponytail: placeholder names from the original screen; the attendant
    // isn't sent to the API yet. Wire to real staff data when it exists.
    final attendants = ['None', 'John Doe', 'Jane Smith', 'Mike Johnson'];

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final attendant in attendants)
          ChoiceChip(
            label: Text(attendant),
            selected: _selectedAttendant == attendant,
            onSelected: (selected) {
              HapticFeedback.selectionClick();
              setState(() => _selectedAttendant = selected ? attendant : null);
            },
          ),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return AppCard(
      color: context.colors.surfaceSubtle,
      shadow: const [],
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: context.colors.textMuted),
          AppSpacing.hSm,
          Expanded(
            child: Text(
              message,
              style: context.text.bodyMedium?.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton() {
    return BottomActionBar(
      primary: AppButton(
        label: 'Start Trip',
        icon: Icons.play_arrow_rounded,
        loading: _isStartingTrip,
        onPressed: _canStartTrip ? _startTrip : null,
      ),
    ).enter(offsetY: 40);
  }
}
