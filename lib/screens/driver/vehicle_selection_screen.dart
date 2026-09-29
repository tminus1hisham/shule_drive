import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme_extension.dart';
import '../../widgets/ui/ui.dart';
import 'package:flutter/services.dart';
import '../../models/master_trip.dart';
import '../../models/preloaded_trip_data.dart';
import '../../api/services/bus_service.dart';
import '../../widgets/main_scaffold.dart';

/// Vehicle Selection Screen
/// Allows driver to select which vehicle they're using for the trip
class VehicleSelectionScreen extends StatefulWidget {
  final MasterTrip? masterTrip;

  const VehicleSelectionScreen({super.key, this.masterTrip});

  @override
  State<VehicleSelectionScreen> createState() => _VehicleSelectionScreenState();
}

class _VehicleSelectionScreenState extends State<VehicleSelectionScreen> {
  bool _isLoading = true;
  String? _error;
  List<Bus> _vehicles = [];
  Bus? _selectedVehicle;
  PreloadedTripData? _preloadedData;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get preloaded data from route arguments (parse from Map)
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final preloadedDataMap = args?['preloadedData'] as Map<String, dynamic>?;
    if (preloadedDataMap != null) {
      _preloadedData = PreloadedTripData.fromJson(preloadedDataMap);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final busService = BusService();
      debugPrint('🚗 VehicleSelection: Fetching driver assigned vehicles');

      final buses = await busService.getBusesByUser();

      if (mounted) {
        debugPrint('🚗 VehicleSelection: Final vehicle count: ${buses.length}');
        setState(() {
          _vehicles = buses;
          _isLoading = false;

          // Pre-select if master trip has a vehicle assigned
          if (widget.masterTrip?.numberPlate != null && buses.isNotEmpty) {
            try {
              _selectedVehicle = buses.firstWhere(
                (v) =>
                    v.registrationNumber.toLowerCase() ==
                    widget.masterTrip!.numberPlate!.toLowerCase(),
              );
              debugPrint(
                '🚗 Pre-selected vehicle: ${_selectedVehicle?.registrationNumber}',
              );
            } catch (e) {
              // No matching vehicle found
              _selectedVehicle = null;
              debugPrint(
                '🚗 No matching vehicle found for: ${widget.masterTrip?.numberPlate}',
              );
            }
          }

          // If there is only one vehicle and none was selected by master trip, select it
          if (_selectedVehicle == null && buses.length == 1) {
            _selectedVehicle = buses.first;
            debugPrint(
              '🚗 Auto-selected only vehicle: ${_selectedVehicle?.registrationNumber}',
            );
          }
        });

        // Auto-advance if a vehicle is already selected
        if (_selectedVehicle != null) {
          // Add a small delay for visualization
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) _onConfirm();
          });
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ VehicleSelection: Error loading vehicles: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _error = 'Failed to load vehicles. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  void _onVehicleSelected(Bus vehicle) {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedVehicle = vehicle;
    });
    // Auto-advance on selection
    _onConfirm();
  }

  void _onConfirm() {
    if (_selectedVehicle == null) return;

    HapticFeedback.mediumImpact();

    // Update preloaded data with selected vehicle
    final updatedPreloadedData = _preloadedData?.copyWith(
      vehicle: _selectedVehicle,
    );

    // Navigate to start-trip screen which will call the startTrip API
    // This ensures a unique trip ID is generated for pick/drop operations
    Navigator.pushReplacementNamed(
      context,
      '/start-trip',
      arguments: {
        'masterTrip': widget.masterTrip,
        'vehicle': _selectedVehicle,
        'preSelectedRoute': widget.masterTrip?.route,
        'preloadedData': updatedPreloadedData?.toJson(),
      },
    );
  }

  void _goBack() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final ready = !_isLoading && _error == null && _vehicles.isNotEmpty;

    return MainScaffold(
      title: 'Select Vehicle',
      showBackButton: true,
      body: Stack(
        children: [
          const Positioned.fill(child: AppBackdrop()),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: AsyncBody(
                    loading: _isLoading,
                    error: _error,
                    onRetry: _loadVehicles,
                    isEmpty: _vehicles.isEmpty,
                    skeleton: ListView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      itemCount: 4,
                      itemBuilder: (_, _) => const Padding(
                        padding: EdgeInsets.only(bottom: AppSpacing.sm),
                        child: AppSkeleton(
                          height: 96,
                          borderRadius: AppRadius.brLg,
                        ),
                      ),
                    ),
                    empty: _buildEmptyState(),
                    onRefresh: _loadVehicles,
                    child: _buildVehiclesList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomBar: ready ? _buildBottomButton() : null,
    );
  }

  Widget _buildHeader() {
    final c = context.colors;
    final sub = context.text.bodyMedium?.copyWith(color: c.textSecondary);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: c.accentGradient,
              borderRadius: AppRadius.brXl,
              boxShadow: [
                BoxShadow(
                  color: c.accent.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.directions_bus_rounded,
              color: Colors.white,
              size: 36,
            ),
          ).pop(),
          AppSpacing.vLg,
          Text(
            'Select Your Vehicle',
            style: context.text.headlineSmall,
          ).enter(delay: const Duration(milliseconds: 80)),
          AppSpacing.vXs,
          if (widget.masterTrip != null) ...[
            Text('Trip: ${widget.masterTrip!.tripName}', style: sub),
            AppSpacing.vXxs,
            Text('Route: ${widget.masterTrip!.route}', style: sub),
          ] else
            Text(
              'Choose the vehicle you\'ll be using for this trip',
              textAlign: TextAlign.center,
              style: sub,
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final empty = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        EmptyState(
          icon: Icons.directions_bus_rounded,
          iconColor: context.colors.accent,
          title: 'No Vehicles Available',
          message:
              'No vehicles are assigned to you. Please contact your '
              'administrator.',
          actionLabel: 'Retry',
          onAction: _loadVehicles,
        ),
        TextButton.icon(
          onPressed: _goBack,
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Go Back'),
        ),
      ],
    );
    if (!kDebugMode) return empty;

    // Debug builds only: long-press to add a mock vehicle for testing.
    return GestureDetector(
      onLongPress: () {
        debugPrint('🚗 Adding mock vehicle for testing...');
        setState(() {
          _vehicles = [
            Bus(
              id: 'mock-bus-001',
              registrationNumber: 'KXX 123X',
              model: 'Toyota Coaster',
              capacity: '30',
              schoolId: 'test-school',
              isActive: true,
              createdAt: DateTime.now(),
            ),
          ];
        });
        AppSnackbar.info(context, 'Mock vehicle added for testing');
      },
      child: empty,
    );
  }

  Widget _buildVehiclesList() {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      itemCount: _vehicles.length,
      separatorBuilder: (_, _) => AppSpacing.vSm,
      itemBuilder: (context, index) {
        final vehicle = _vehicles[index];
        return _buildVehicleCard(
          vehicle,
          _selectedVehicle?.id == vehicle.id,
        ).enterList(index);
      },
    );
  }

  Widget _buildVehicleCard(Bus vehicle, bool isSelected) {
    final c = context.colors;
    return SelectableCard(
      selected: isSelected,
      onTap: () => _onVehicleSelected(vehicle),
      child: Row(
        children: [
          AnimatedContainer(
            duration: AppDuration.medium,
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: isSelected ? c.accentGradient : null,
              color: isSelected ? null : c.accentSoft,
              borderRadius: AppRadius.brSm,
            ),
            child: Icon(
              Icons.directions_bus_filled_rounded,
              color: isSelected ? Colors.white : c.accent,
              size: 28,
            ),
          ),
          AppSpacing.hMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vehicle.registrationNumber,
                  style: context.text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                if (vehicle.model != null && vehicle.model!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    vehicle.model!,
                    style: context.text.bodyMedium?.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
                ],
                AppSpacing.vXs,
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xxs,
                  children: [
                    StatusPill(
                      label: '${vehicle.capacity} seats',
                      color: c.textSecondary,
                      icon: Icons.event_seat_rounded,
                      dense: true,
                    ),
                    StatusPill(
                      label: vehicle.isActive ? 'Active' : 'Inactive',
                      color: vehicle.isActive ? c.success : c.warning,
                      dense: true,
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

  Widget _buildBottomButton() {
    return BottomActionBar(
      primary: AppButton(
        label: 'Confirm Vehicle',
        icon: Icons.check_rounded,
        onPressed: _selectedVehicle != null ? _onConfirm : null,
      ),
      secondary: AppButton(
        label: 'Back to Trip Selection',
        variant: AppButtonVariant.tertiary,
        size: AppButtonSize.medium,
        onPressed: _goBack,
      ),
    ).enter(offsetY: 40);
  }
}
