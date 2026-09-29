import 'dart:async';
import 'package:flutter/material.dart';
import '../../../theme/app_spacing.dart';
import 'package:provider/provider.dart';
import '../../../api/services/student_service.dart' as student_service;
import '../../../api/services/route_service.dart' as route_service;
import '../../../api/services/bus_service.dart' as bus_service;
import '../../../models/master_trip.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/trip_provider.dart';
import '../../../theme/app_theme_extension.dart';
import '../../../utils/next_trip_selector.dart';
import '../../../widgets/main_scaffold.dart';
import '../../../widgets/ui/ui.dart';

/// Manage Master Trips Screen
/// Allows admins to create/edit trips and add students to them
class ManageMasterTripsScreen extends StatefulWidget {
  const ManageMasterTripsScreen({super.key});

  @override
  State<ManageMasterTripsScreen> createState() =>
      _ManageMasterTripsScreenState();
}

class _ManageMasterTripsScreenState extends State<ManageMasterTripsScreen> {
  // Form controllers for trip creation/editing
  final _tripFormKey = GlobalKey<FormState>();
  final _tripNameController = TextEditingController();
  final _tripTimeController = TextEditingController();
  final _attendantNameController = TextEditingController();

  // Search controllers
  final _searchController = TextEditingController();
  final _phoneSearchController = TextEditingController();

  // Selected values
  String? _selectedRoute;
  String? _selectedBus;
  String? _selectedDriver;
  String _selectedDirection = 'Pickup';

  // State
  MasterTrip? _editingTrip;
  bool _isCreatingNew = true;
  bool _isLoading = false;
  bool _isLoadingStudents = false;
  String? _errorMessage;

  // Search state
  bool _isSearchingByPhone = false;
  List<student_service.Student> _phoneSearchResults = [];

  // Data lists for dropdowns
  List<route_service.BusRoute> _routes = [];
  List<bus_service.Bus> _buses = [];
  List<student_service.Student> _students = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadInitialData();
    });
  }

  @override
  void dispose() {
    _tripNameController.dispose();
    _tripTimeController.dispose();
    _attendantNameController.dispose();
    _searchController.dispose();
    _phoneSearchController.dispose();
    _stateTick.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    // Load data silently in the background - don't block UI
    _loadDataInBackground();
  }

  Future<void> _loadDataInBackground() async {
    debugPrint('🔄 Starting background data load...');

    try {
      final tripProvider = context.read<TripProvider>();

      // Load critical data first (trips, routes, buses, drivers) concurrently
      // Use timeout to prevent indefinite loading
      await Future.wait([
        tripProvider
            .fetchMasterTrips()
            .then((_) => debugPrint('✅ Master trips loaded'))
            .catchError((e) => debugPrint('❌ Error loading master trips: $e')),
        _loadRoutes().catchError(
          (e) => debugPrint('❌ Error loading routes: $e'),
        ),
        _loadBuses().catchError((e) => debugPrint('❌ Error loading buses: $e')),
        _loadDrivers().catchError(
          (e) => debugPrint('❌ Error loading drivers: $e'),
        ),
      ]).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint(
            '⚠️ Timeout loading initial data - some data may be missing',
          );
          // Don't throw - allow UI to load with available data
          return [];
        },
      );

      debugPrint('✅ Routes, Buses, Drivers loaded');

      // Load students in background (takes longest)
      // Wrap in try-catch to prevent unhandled errors
      try {
        await _loadStudents().timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            debugPrint(
              '⚠️ Timeout loading students - you can still search by phone',
            );
            if (mounted) {
              setState(() => _isLoadingStudents = false);
            }
          },
        );
        debugPrint('✅ Students loaded');
      } catch (e) {
        debugPrint('❌ Error loading students: $e');
        if (mounted) {
          setState(() => _isLoadingStudents = false);
        }
      }
    } catch (e) {
      debugPrint('❌ Background load error: $e');
    }
  }

  Future<void> _loadRoutes() async {
    try {
      final routeService = route_service.RouteService();
      final routes = await routeService.getAllRoutes().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint('⚠️ Timeout loading routes');
          return [];
        },
      );
      if (mounted) {
        setState(() => _routes = routes);
      }
    } catch (e) {
      debugPrint('Error loading routes: $e');
      // Don't show error - routes will just be empty
    }
  }

  Future<void> _loadBuses() async {
    try {
      final busService = bus_service.BusService();
      // Load buses linked to the current user
      final buses = await busService.getBusesByUser();
      if (mounted) {
        setState(() => _buses = buses);

        // Pre-populate bus selection if only one bus is available and none is selected
        if (_selectedBus == null && buses.isNotEmpty) {
          setState(() {
            _selectedBus = buses.first.registrationNumber;
          });
          debugPrint('✅ Auto-selected bus: ${_selectedBus}');
        }
      }
    } catch (e) {
      debugPrint('Error loading buses: $e');
      // Don't show error - buses will just be empty
    }
  }

  Future<void> _loadDrivers() async {
    try {
      final authProvider = context.read<AuthProvider>();
      final driverName = authProvider.userName;

      if (mounted && driverName != null && driverName.isNotEmpty) {
        // Use driver name from JWT token directly - instant load
        setState(() {
          if (_selectedDriver == null) {
            _selectedDriver = driverName;
          }
        });
        debugPrint('✅ Set driver from JWT: $driverName');
      }
    } catch (e) {
      debugPrint('Error setting driver: $e');
    }
  }

  Future<void> _loadStudents() async {
    if (_isLoadingStudents) return;

    setState(() => _isLoadingStudents = true);

    try {
      final students = await student_service.StudentService()
          .getSchoolStudents();
      if (mounted) setState(() => _students = students);
    } catch (e) {
      debugPrint('❌ Error loading students: $e');
      // Try fallback endpoint
      await _loadStudentsFromGuardianEndpoint();
    } finally {
      if (mounted) {
        setState(() => _isLoadingStudents = false);
      }
    }
  }

  Future<void> _loadStudentsFromGuardianEndpoint() async {
    try {
      debugPrint('📚 Trying guardian students endpoint...');
      final studentService = student_service.StudentService();
      final students = await studentService.getGuardianStudents();
      if (mounted) {
        setState(() {
          _students = students;
        });
        debugPrint(
          '✅ Loaded ${students.length} students from guardian endpoint',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading students from guardian endpoint: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Search students by phone number
  Future<void> _searchStudentsByPhone() async {
    final phoneNumber = _phoneSearchController.text.trim();

    if (phoneNumber.isEmpty) {
      _showErrorSnackbar('Please enter a phone number');
      return;
    }

    // Normalize phone number
    String normalizedPhone = phoneNumber;
    if (normalizedPhone.startsWith('+')) {
      normalizedPhone = normalizedPhone.substring(1);
    }
    if (normalizedPhone.startsWith('0') && normalizedPhone.length == 10) {
      normalizedPhone = '254${normalizedPhone.substring(1)}';
    }

    setState(() => _isSearchingByPhone = true);

    try {
      final studentService = student_service.StudentService();
      final students = await studentService.getStudentsByPhone(normalizedPhone);

      setState(() {
        _phoneSearchResults = students;
        _isSearchingByPhone = false;
      });

      if (students.isEmpty) {
        _showErrorSnackbar('No students found for phone: $normalizedPhone');
      }
    } catch (e) {
      setState(() => _isSearchingByPhone = false);
      _showErrorSnackbar('Error searching: $e');
    }
  }

  void _startCreatingNew() {
    final authProvider = context.read<AuthProvider>();
    final driverName = authProvider.userName;

    // Pre-populate bus if only one is available
    final busToSelect = _buses.length == 1
        ? _buses.first.registrationNumber
        : null;

    setState(() {
      _editingTrip = null;
      _isCreatingNew = true;
      _tripNameController.clear();
      _tripTimeController.clear();
      _attendantNameController.clear();
      _selectedRoute = null;
      // Auto-select bus if only one is available
      _selectedBus = busToSelect;
      // Use driver name from JWT token directly
      _selectedDriver = driverName;
      _selectedDirection = 'Pickup';
      _errorMessage = null;
    });
    context.read<TripProvider>().clearMasterTripData();
  }

  void _startEditingTrip(MasterTrip trip) {
    final tripProvider = context.read<TripProvider>();

    // Clear previous students immediately if selecting a different trip
    if (_editingTrip?.id != trip.id) {
      tripProvider.clearMasterTripData();
    }

    // Get driver name from JWT token directly
    final authProvider = context.read<AuthProvider>();
    final driverName = authProvider.userName;

    setState(() {
      _editingTrip = trip;
      _isCreatingNew = false;
      _isLoadingStudents = true;
      _tripNameController.text = trip.tripName;
      _tripTimeController.text = trip.tripTime;
      _attendantNameController.text = trip.attendantName ?? '';
      _selectedRoute = trip.route;
      // Use trip's driver if available, otherwise use JWT driver name
      _selectedDriver = trip.driverName ?? driverName;
      _selectedBus = trip.numberPlate;
      _selectedDirection = trip.tripDirection == 'to_school'
          ? 'Pickup'
          : 'Dropoff';
      _errorMessage = null;
    });

    // Fetch students for this trip
    tripProvider.fetchMasterTripStudents(trip.id).then((_) {
      if (mounted) {
        setState(() => _isLoadingStudents = false);
      }
    });
  }

  Future<void> _pickTripTime() async {
    final current = parseTripTimeOfDay(_tripTimeController.text);
    final selected = await showTimePicker(
      context: context,
      initialTime: current == null
          ? TimeOfDay.now()
          : TimeOfDay.fromDateTime(current),
    );
    if (!mounted || selected == null) return;
    _tripTimeController.text = const DefaultMaterialLocalizations()
        .formatTimeOfDay(selected);
  }

  Future<void> _saveTrip() async {
    if (!_tripFormKey.currentState!.validate()) return;

    final tripProvider = context.read<TripProvider>();

    setState(() => _isLoading = true);

    if (_isCreatingNew) {
      // Create new trip
      final trip = await tripProvider.createMasterTrip(
        tripName: _tripNameController.text.trim(),
        tripTime: _tripTimeController.text.trim(),
        tripDirection: _selectedDirection == 'Pickup'
            ? 'to_school'
            : 'from_school',
        route: _selectedRoute ?? '',
        numberPlate: _selectedBus ?? '',
        attendantName: _attendantNameController.text.trim(),
        driverName: _selectedDriver ?? '',
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (trip != null) {
          _startEditingTrip(trip);
          _showSuccessSnackbar('Trip created successfully');
        } else if (tripProvider.errorMessage != null) {
          setState(() => _errorMessage = tripProvider.errorMessage);
        }
      }
    } else if (_editingTrip != null) {
      // Update existing trip
      final trip = await tripProvider.editMasterTrip(
        tripId: _editingTrip!.id,
        tripName: _tripNameController.text.trim(),
        tripTime: _tripTimeController.text.trim(),
        tripDirection: _selectedDirection == 'Pickup'
            ? 'to_school'
            : 'from_school',
        route: _selectedRoute,
        numberPlate: _selectedBus,
        attendantName: _attendantNameController.text.trim(),
        driverName: _selectedDriver,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (trip != null) {
          _showSuccessSnackbar('Trip updated successfully');
        } else if (tripProvider.errorMessage != null) {
          setState(() => _errorMessage = tripProvider.errorMessage);
        }
      }
    }
  }

  Future<void> _deleteTrip(MasterTrip trip) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Delete Trip',
      message: 'Are you sure you want to delete "${trip.tripName}"?',
      confirmLabel: 'Delete',
      icon: Icons.delete_outline_rounded,
      destructive: true,
    );

    if (confirmed) {
      if (!mounted) return;
      final tripProvider = context.read<TripProvider>();
      setState(() => _isLoading = true);

      final success = await tripProvider.deleteMasterTrip(trip.id);

      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
          if (_editingTrip?.id == trip.id) {
            _startCreatingNew();
          }
          _showSuccessSnackbar('Trip deleted successfully');
        } else {
          _showErrorSnackbar(
            tripProvider.errorMessage ?? 'Failed to delete trip',
          );
        }
      }
    }
  }

  void _showSuccessSnackbar(String message) =>
      AppSnackbar.success(context, message);

  void _showErrorSnackbar(String message) =>
      AppSnackbar.error(context, message);

  /// The add-student sheet lives on its own route, so it can't see this
  /// State's rebuilds. Every setState here ticks this notifier and the sheet
  /// listens to it (replaces a 1s re-render poll).
  final _stateTick = ValueNotifier<int>(0);

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _stateTick.value++;
  }

  @override
  Widget build(BuildContext context) {
    final tripProvider = context.watch<TripProvider>();

    return MainScaffold(
      title: _isCreatingNew ? 'Create Trip' : 'Edit Trip',
      showBackButton: true,
      showBottomNav: false,
      actions: [
        if (!_isCreatingNew)
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: _startCreatingNew,
            tooltip: 'Create New Trip',
          ),
      ],
      body: Stack(
        children: [
          const Positioned.fill(child: AppBackdrop()),
          AsyncBody(
            loading: _isLoading && tripProvider.masterTrips.isEmpty,
            onRefresh: _loadInitialData,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _buildExistingTripsSection(tripProvider).enter(),
                ),
                SliverToBoxAdapter(child: _buildTripFormSection().enterList(1)),
                // Students section slides open once a trip is being edited.
                SliverToBoxAdapter(
                  child: AnimatedSize(
                    duration: AppDuration.slow,
                    curve: AppCurves.easeOut,
                    alignment: Alignment.topCenter,
                    child: !_isCreatingNew && _editingTrip != null
                        ? _buildStudentsSection(tripProvider)
                        : const SizedBox(width: double.infinity),
                  ),
                ),
                const SliverPadding(
                  padding: EdgeInsets.only(bottom: AppSpacing.xxl),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExistingTripsSection(TripProvider tripProvider) {
    final c = context.colors;
    final trips = tripProvider.masterTrips;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: SectionHeader(title: 'Existing Trips')),
              if (trips.isNotEmpty)
                StatusPill(
                  label: '${trips.length} trips',
                  color: c.brand,
                  showDot: false,
                  dense: true,
                ),
            ],
          ),
          AppSpacing.vSm,
          if (trips.isEmpty)
            AppCard(
              color: c.surfaceSubtle,
              shadow: const [],
              child: const EmptyState(
                icon: Icons.route_outlined,
                title: 'No trips yet',
                message: 'Create your first trip below',
                compact: true,
              ),
            )
          else
            SizedBox(
              height: 148,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: trips.length,
                separatorBuilder: (_, _) => AppSpacing.hSm,
                itemBuilder: (context, index) =>
                    _buildTripCard(trips[index]).enterList(index),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTripCard(MasterTrip trip) {
    final c = context.colors;
    final isSelected = _editingTrip?.id == trip.id;
    final isPickup = trip.tripDirection == 'to_school';
    final fg = isSelected ? Colors.white : context.scheme.onSurface;
    final muted = isSelected
        ? Colors.white.withValues(alpha: 0.8)
        : c.textSecondary;

    // The selected trip fills with the brand gradient; others stay quiet.
    return PressScale(
      child: GestureDetector(
        onTap: () => _startEditingTrip(trip),
        child: AnimatedContainer(
          duration: AppDuration.medium,
          curve: AppCurves.easeOut,
          width: 208,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            gradient: isSelected ? c.brandGradient : null,
            color: isSelected ? null : context.scheme.surface,
            borderRadius: AppRadius.brLg,
            border: Border.all(
              color: isSelected ? Colors.transparent : c.outline,
            ),
            boxShadow: isSelected ? c.shadowMd : c.shadowSm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      trip.tripName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleSmall?.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  AnimatedScale(
                    scale: isSelected ? 1 : 0,
                    duration: AppDuration.medium,
                    curve: Curves.easeOutBack,
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),
              AppSpacing.vXxs,
              Text(
                trip.route,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodySmall?.copyWith(color: muted),
              ),
              const Spacer(),
              Row(
                children: [
                  Icon(Icons.access_time_rounded, size: 14, color: muted),
                  const SizedBox(width: 4),
                  Text(
                    trip.tripTime,
                    style: context.text.labelMedium?.copyWith(color: muted),
                  ),
                ],
              ),
              AppSpacing.vXs,
              Row(
                children: [
                  StatusPill(
                    label: isPickup ? 'Pickup' : 'Dropoff',
                    color: isSelected
                        ? Colors.white
                        : (isPickup ? c.info : c.accent),
                    icon: isPickup
                        ? Icons.arrow_forward_rounded
                        : Icons.arrow_back_rounded,
                    dense: true,
                  ),
                  const Spacer(),
                  if (!isSelected)
                    IconButton(
                      onPressed: () => _deleteTrip(trip),
                      tooltip: 'Delete trip',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: c.textMuted,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTripFormSection() {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _tripFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: c.brandGradient,
                      borderRadius: AppRadius.brSm,
                    ),
                    child: const Icon(
                      Icons.edit_note_rounded,
                      color: Colors.white,
                    ),
                  ),
                  AppSpacing.hSm,
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: AppDuration.medium,
                      child: SectionHeader(
                        key: ValueKey(_isCreatingNew),
                        title: _isCreatingNew ? 'Create New Trip' : 'Edit Trip',
                        subtitle: _isCreatingNew
                            ? 'Fill in the details below'
                            : 'Update trip details',
                      ),
                    ),
                  ),
                ],
              ),
              AppSpacing.vXl,
              AppTextField(
                controller: _tripNameController,
                label: 'Trip Name',
                hint: 'e.g., Morning Route A',
                prefixIcon: Icons.label_outline_rounded,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a trip name';
                  }
                  return null;
                },
              ),
              AppSpacing.vMd,
              AppTextField(
                controller: _tripTimeController,
                label: 'Trip Time',
                hint: 'e.g., 07:30 AM',
                prefixIcon: Icons.access_time_rounded,
                suffixIcon: IconButton(
                  tooltip: 'Choose trip time',
                  icon: const Icon(Icons.schedule_rounded),
                  onPressed: _pickTripTime,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter trip time';
                  }
                  return null;
                },
              ),
              AppSpacing.vMd,
              Text('Trip Direction', style: context.text.titleSmall),
              AppSpacing.vXs,
              SegmentedFilter(
                selected: _selectedDirection == 'Pickup' ? 0 : 1,
                onChanged: (i) => setState(
                  () => _selectedDirection = i == 0 ? 'Pickup' : 'Dropoff',
                ),
                segments: const [
                  FilterSegment('Pickup'),
                  FilterSegment('Dropoff'),
                ],
              ),
              AppSpacing.vMd,
              _buildDropdown(
                // Keyed so the field picks up the new value when switching trips.
                key: ValueKey('route-${_editingTrip?.id}'),
                value: _selectedRoute,
                label: 'Route',
                hint: 'Select a route',
                icon: Icons.route_rounded,
                items: _routes.map((r) => r.name).toList(),
                onChanged: (value) => setState(() => _selectedRoute = value),
              ),
              AppSpacing.vMd,
              _buildDropdown(
                key: ValueKey('bus-${_editingTrip?.id}'),
                value: _selectedBus,
                label: 'Bus (Number Plate)',
                hint: 'Select a bus',
                icon: Icons.directions_bus_rounded,
                items: _buses.map((b) => b.registrationNumber).toList(),
                onChanged: (value) => setState(() => _selectedBus = value),
              ),
              AppSpacing.vMd,
              // Driver (read-only)
              AppCard(
                color: c.surfaceSubtle,
                shadow: const [],
                border: Border.all(color: c.outline),
                child: Row(
                  children: [
                    AppAvatar(name: _selectedDriver, size: 36),
                    AppSpacing.hSm,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Driver',
                            style: context.text.labelSmall?.copyWith(
                              color: c.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _selectedDriver ?? 'Loading...',
                            style: context.text.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    StatusPill(
                      label: 'Assigned',
                      color: c.brand,
                      icon: Icons.check_circle_rounded,
                      dense: true,
                    ),
                  ],
                ),
              ),
              AppSpacing.vMd,
              AppTextField(
                controller: _attendantNameController,
                label: 'Attendant Name',
                hint: 'e.g., John Doe',
                prefixIcon: Icons.badge_outlined,
              ),
              AnimatedSize(
                duration: AppDuration.medium,
                curve: AppCurves.easeOut,
                child: _errorMessage == null
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.md),
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: c.error.withValues(alpha: 0.08),
                            borderRadius: AppRadius.brSm,
                            border: Border.all(
                              color: c.error.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                color: c.error,
                                size: 20,
                              ),
                              AppSpacing.hXs,
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: context.text.bodySmall?.copyWith(
                                    color: c.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
              AppSpacing.vXl,
              AppButton(
                label: _isCreatingNew ? 'Create Trip' : 'Update Trip',
                icon: _isCreatingNew ? Icons.add_rounded : Icons.save_rounded,
                loading: _isLoading,
                onPressed: _saveTrip,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required Key key,
    required String? value,
    required String label,
    required String hint,
    required IconData icon,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      key: key,
      initialValue: value,
      isExpanded: true,
      borderRadius: AppRadius.brMd,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: context.colors.brand),
      ),
      hint: Text(hint),
      icon: Icon(Icons.expand_more_rounded, color: context.colors.brand),
      items: [
        for (final item in items)
          DropdownMenuItem<String>(
            value: item,
            child: Text(item, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
    );
  }

  Widget _buildStudentsSection(TripProvider tripProvider) {
    final c = context.colors;
    final tripStudents = tripProvider.tripStudents;
    final countStyle = context.text.bodySmall?.copyWith(color: c.textSecondary);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: c.info.withValues(alpha: 0.14),
                    borderRadius: AppRadius.brSm,
                  ),
                  child: Icon(Icons.people_outline_rounded, color: c.info),
                ),
                AppSpacing.hSm,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Students', style: context.text.titleMedium),
                      Row(
                        children: [
                          AnimatedCount(tripStudents.length, style: countStyle),
                          Text(' students assigned', style: countStyle),
                        ],
                      ),
                    ],
                  ),
                ),
                AppButton(
                  label: 'Add',
                  icon: Icons.add_rounded,
                  size: AppButtonSize.small,
                  expand: false,
                  onPressed: _showAddStudentDialog,
                ),
              ],
            ),
            AppSpacing.vMd,
            AnimatedSwitcher(
              duration: AppDuration.medium,
              child: _isLoadingStudents
                  ? const Column(
                      key: ValueKey('loading'),
                      children: [SkeletonListTile(), SkeletonListTile()],
                    )
                  : tripStudents.isEmpty
                  ? AppCard(
                      key: const ValueKey('empty'),
                      color: c.surfaceSubtle,
                      shadow: const [],
                      child: const EmptyState(
                        icon: Icons.person_off_outlined,
                        title: 'No students assigned',
                        message: 'Add students to this trip',
                        compact: true,
                      ),
                    )
                  : Column(
                      key: const ValueKey('list'),
                      children: [
                        for (final (i, student) in tripStudents.indexed)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.xs,
                            ),
                            child: _buildStudentTile(
                              student,
                              tripProvider,
                            ).enterList(i),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentTile(TripStudent student, TripProvider tripProvider) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: c.surfaceSubtle,
        borderRadius: AppRadius.brSm,
      ),
      child: Row(
        children: [
          AppAvatar(name: student.fullname, size: 40),
          AppSpacing.hSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.fullname,
                  style: context.text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${student.classname} • ${student.route}',
                  style: context.text.bodySmall?.copyWith(
                    color: c.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _removeStudentFromTrip(student, tripProvider),
            tooltip: 'Remove from trip',
            icon: Icon(
              Icons.remove_circle_outline_rounded,
              color: c.error.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddStudentDialog() async {
    // Open immediately with phone search as default; the student list keeps
    // loading in the background and the sheet updates when it arrives.
    _showAddStudentDialogWithList([], initialShowPhoneSearch: true);

    if (_students.isEmpty && !_isLoadingStudents) {
      _loadStudents().catchError((e) {
        debugPrint('❌ Error loading students in background: $e');
      });
    }
  }

  void _showAddStudentDialogWithList(
    List<student_service.Student> availableStudents, {
    bool initialShowPhoneSearch = false,
  }) {
    student_service.Student? selectedStudent;
    String searchQuery = '';
    bool showPhoneSearch = initialShowPhoneSearch;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => ListenableBuilder(
        listenable: _stateTick,
        builder: (context, _) => StatefulBuilder(
          builder: (context, setSheetState) {
            final c = context.colors;
            final currentStudents = _students.isNotEmpty
                ? _students
                : availableStudents;

            // Filter students based on search query
            var filteredStudents = currentStudents;
            if (searchQuery.isNotEmpty && !showPhoneSearch) {
              final q = searchQuery.toLowerCase();
              filteredStudents = currentStudents.where((s) {
                return s.name.toLowerCase().contains(q) ||
                    s.className.toLowerCase().contains(q) ||
                    (s.schoolName?.toLowerCase().contains(q) ?? false);
              }).toList();
            }

            // Also filter out students already in the trip
            final tripStudentIds = context
                .read<TripProvider>()
                .tripStudents
                .map((s) => s.studentId.toString())
                .toSet();

            if (!showPhoneSearch) {
              filteredStudents = filteredStudents
                  .where(
                    (s) =>
                        !tripStudentIds.contains(s.id) &&
                        !tripStudentIds.contains(
                          int.tryParse(s.id)?.toString(),
                        ),
                  )
                  .toList();
            }

            // Use phone search results if available
            if (showPhoneSearch && _phoneSearchResults.isNotEmpty) {
              filteredStudents = _phoneSearchResults
                  .where((s) => !tripStudentIds.contains(s.id))
                  .toList();
            }

            Future<void> searchPhone() async {
              await _searchStudentsByPhone();
              setSheetState(() {});
            }

            return SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.8,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Column(
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.xs,
                        AppSpacing.xs,
                        0,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.xs),
                            decoration: BoxDecoration(
                              gradient: c.brandGradient,
                              borderRadius: AppRadius.brSm,
                            ),
                            child: const Icon(
                              Icons.person_add_rounded,
                              color: Colors.white,
                            ),
                          ),
                          AppSpacing.hSm,
                          Expanded(
                            child: Text(
                              'Add Student to Trip',
                              style: context.text.titleLarge,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            tooltip: 'Close',
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: SegmentedFilter(
                        selected: showPhoneSearch ? 1 : 0,
                        onChanged: (i) => setSheetState(() {
                          showPhoneSearch = i == 1;
                          if (!showPhoneSearch) {
                            _phoneSearchResults = [];
                            _phoneSearchController.clear();
                          }
                        }),
                        segments: const [
                          FilterSegment('By Name'),
                          FilterSegment('By Phone'),
                        ],
                      ),
                    ),
                    if (_isLoadingStudents)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        child: StatusPill(
                          label:
                              'Loading student list… You can search by phone now!',
                          color: c.info,
                          pulse: true,
                          dense: true,
                        ),
                      ),
                    // Search field
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: AnimatedSwitcher(
                        duration: AppDuration.medium,
                        child: showPhoneSearch
                            ? Row(
                                key: const ValueKey('phone'),
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _phoneSearchController,
                                      keyboardType: TextInputType.phone,
                                      decoration: const InputDecoration(
                                        hintText: 'Enter guardian phone...',
                                        prefixIcon: Icon(Icons.phone_rounded),
                                      ),
                                      onSubmitted: (_) => searchPhone(),
                                    ),
                                  ),
                                  AppSpacing.hXs,
                                  AppButton(
                                    label: 'Search',
                                    size: AppButtonSize.medium,
                                    expand: false,
                                    loading: _isSearchingByPhone,
                                    onPressed: searchPhone,
                                  ),
                                ],
                              )
                            : TextField(
                                key: const ValueKey('name'),
                                decoration: const InputDecoration(
                                  hintText:
                                      'Search by name, class or school...',
                                  prefixIcon: Icon(Icons.search_rounded),
                                ),
                                onChanged: (value) =>
                                    setSheetState(() => searchQuery = value),
                              ),
                      ),
                    ),
                    // Results header
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: Row(
                        children: [
                          StatusPill(
                            label: '${filteredStudents.length} students',
                            color: c.brand,
                            showDot: false,
                            dense: true,
                          ),
                          const Spacer(),
                          AnimatedScale(
                            scale: selectedStudent != null ? 1 : 0,
                            duration: AppDuration.medium,
                            curve: Curves.easeOutBack,
                            child: StatusPill(
                              label: 'Selected',
                              color: c.info,
                              icon: Icons.check_circle_rounded,
                              dense: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AppSpacing.vSm,
                    // Student list
                    Expanded(
                      child: filteredStudents.isEmpty
                          ? (_isLoadingStudents && !showPhoneSearch
                                ? ListView(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.md,
                                    ),
                                    children: const [
                                      SkeletonListTile(),
                                      SkeletonListTile(),
                                      SkeletonListTile(),
                                    ],
                                  )
                                : EmptyState(
                                    icon: showPhoneSearch
                                        ? Icons.phone_android_rounded
                                        : Icons.search_off_rounded,
                                    title: showPhoneSearch
                                        ? 'Search by phone to find students'
                                        : currentStudents.isEmpty
                                        ? 'No students loaded. Try searching by phone.'
                                        : 'No students match your search',
                                    compact: true,
                                  ))
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                              ),
                              itemCount: filteredStudents.length,
                              separatorBuilder: (_, _) => AppSpacing.vXs,
                              itemBuilder: (context, index) {
                                final student = filteredStudents[index];
                                final details = [
                                  student.className,
                                  student.route ?? 'N/A',
                                  if (student.schoolName?.isNotEmpty ?? false)
                                    student.schoolName!,
                                ].join(' • ');
                                return SelectableCard(
                                  selected: selectedStudent?.id == student.id,
                                  padding: const EdgeInsets.all(AppSpacing.sm),
                                  onTap: () => setSheetState(
                                    () => selectedStudent = student,
                                  ),
                                  child: Row(
                                    children: [
                                      AppAvatar(name: student.name, size: 44),
                                      AppSpacing.hSm,
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              student.name,
                                              style: context.text.titleSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              details,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: context.text.bodySmall
                                                  ?.copyWith(
                                                    color: c.textSecondary,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ).enterList(index);
                              },
                            ),
                    ),
                    BottomActionBar(
                      primary: AppButton(
                        label: selectedStudent == null
                            ? 'Select Student'
                            : 'Add Student',
                        icon: Icons.person_add_rounded,
                        onPressed: selectedStudent == null
                            ? null
                            : () {
                                Navigator.pop(context);
                                _addStudentToTrip(selectedStudent!);
                              },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _addStudentToTrip(student_service.Student student) async {
    if (_editingTrip == null) return;

    final tripProvider = context.read<TripProvider>();
    setState(() => _isLoading = true);

    // Parse lat/lng from pickup location if available
    double latitude = 0.0;
    double longitude = 0.0;

    // Try to get coordinates from student's pickup location
    if (student.pickupLocation != null && student.pickupLocation!.isNotEmpty) {
      // In a real app, you'd geocode the address or store coordinates
      // For now, we'll use default values or parse if they're stored
      final coords = _parseCoordinates(student.pickupLocation!);
      if (coords != null) {
        latitude = coords['lat'] ?? 0.0;
        longitude = coords['lng'] ?? 0.0;
      }
    }

    try {
      final result = await tripProvider.addStudentToMasterTrip(
        masterTripId: _editingTrip!.id,
        fullname: student.name,
        studentRegNumber: student.studentRegNumber ?? '',
        studentId: int.tryParse(student.id) ?? 0,
        guardianPhoneNumber: student.guardianPhone ?? '',
        schoolname: student.schoolName ?? '',
        classname: student.className,
        route: student.route ?? _selectedRoute ?? '',
        latitude: latitude,
        longitude: longitude,
      );

      if (mounted) {
        if (result != null) {
          _showSuccessSnackbar('${student.name} added to trip');
        } else {
          _showErrorSnackbar(
            tripProvider.errorMessage ?? 'Failed to add student',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        debugPrint('❌ Error adding student: $e');
        _showErrorSnackbar('Error adding student: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Map<String, double>? _parseCoordinates(String location) {
    // Simple parser for "lat,lng" format
    // In a real app, you'd use geocoding or store coordinates separately
    try {
      final parts = location.split(',');
      if (parts.length == 2) {
        return {
          'lat': double.parse(parts[0].trim()),
          'lng': double.parse(parts[1].trim()),
        };
      }
    } catch (e) {
      debugPrint('Error parsing coordinates: $e');
    }
    return null;
  }

  Future<void> _removeStudentFromTrip(
    TripStudent student,
    TripProvider tripProvider,
  ) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Remove Student',
      message: 'Remove ${student.fullname} from this trip?',
      confirmLabel: 'Remove',
      icon: Icons.person_remove_outlined,
      destructive: true,
    );

    if (confirmed) {
      setState(() => _isLoading = true);

      final success = await tripProvider.deleteStudentFromMasterTrip(
        studentTripId: student.id,
        masterTripId: student.masterTripId,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
          _showSuccessSnackbar('${student.fullname} removed from trip');
        } else {
          _showErrorSnackbar(
            tripProvider.errorMessage ?? 'Failed to remove student',
          );
        }
      }
    }
  }
}
