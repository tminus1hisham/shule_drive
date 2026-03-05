import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/master_trip.dart';
import '../../models/preloaded_trip_data.dart';
import '../../api/services/bus_service.dart';
import '../../providers/app_provider.dart';
import '../../widgets/main_scaffold.dart';

/// Vehicle Selection Screen
/// Allows driver to select which vehicle they're using for the trip
class VehicleSelectionScreen extends StatefulWidget {
  final MasterTrip? masterTrip;

  const VehicleSelectionScreen({super.key, this.masterTrip});

  @override
  State<VehicleSelectionScreen> createState() => _VehicleSelectionScreenState();
}

class _VehicleSelectionScreenState extends State<VehicleSelectionScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _error;
  List<Bus> _vehicles = [];
  Bus? _selectedVehicle;
  PreloadedTripData? _preloadedData;

  late AnimationController _animationController;

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
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _loadVehicles();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
        _animationController.forward();

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
    final appProvider = context.watch<AppProvider>();
    final isDarkMode = appProvider.isDarkMode;

    return MainScaffold(
      title: 'Select Vehicle',
      showBackButton: true,
      body: SafeArea(
        child: Column(
          children: [
            // Header with trip info
            _buildHeader(isDarkMode),

            // Content
            Expanded(
              child: _isLoading
                  ? _buildLoadingState(isDarkMode)
                  : _error != null
                  ? _buildErrorState(isDarkMode)
                  : _vehicles.isEmpty
                  ? _buildEmptyState(isDarkMode)
                  : _buildVehiclesList(isDarkMode),
            ),

            // Bottom button
            if (!_isLoading && _error == null && _vehicles.isNotEmpty)
              _buildBottomButton(isDarkMode),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2196F3).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.directions_bus,
              color: Colors.white,
              size: 36,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Select Your Vehicle',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          if (widget.masterTrip != null) ...[
            Text(
              'Trip: ${widget.masterTrip!.tripName}',
              style: TextStyle(
                fontSize: 15,
                color: isDarkMode ? Colors.white60 : const Color(0xFF666666),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Route: ${widget.masterTrip!.route}',
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.white60 : const Color(0xFF666666),
              ),
            ),
          ] else ...[
            Text(
              'Choose the vehicle you\'ll be using for this trip',
              style: TextStyle(
                fontSize: 15,
                color: isDarkMode ? Colors.white60 : const Color(0xFF666666),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingState(bool isDarkMode) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: 4,
      itemBuilder: (context, index) => _buildSkeletonItem(isDarkMode),
    );
  }

  Widget _buildSkeletonItem(bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFE5E5EA),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isDarkMode
                  ? const Color(0xFF2C2C2C)
                  : const Color(0xFFE5E5EA),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 150,
                  height: 18,
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? const Color(0xFF2C2C2C)
                        : const Color(0xFFE5E5EA),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 100,
                  height: 14,
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? const Color(0xFF2C2C2C)
                        : const Color(0xFFE5E5EA),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(bool isDarkMode) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: isDarkMode ? Colors.white60 : const Color(0xFF666666),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadVehicles,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B9B5B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.05)
                    : const Color(0xFF2196F3).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.directions_bus,
                size: 48,
                color: isDarkMode ? Colors.white30 : const Color(0xFF2196F3),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Vehicles Available',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No vehicles are assigned to you. Please contact your administrator.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.white60 : const Color(0xFF666666),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _loadVehicles,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B9B5B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                TextButton.icon(
                  onPressed: _goBack,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Go Back'),
                  style: TextButton.styleFrom(
                    foregroundColor: isDarkMode
                        ? Colors.white70
                        : const Color(0xFF666666),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'If the problem persists, please contact your administrator.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDarkMode
                    ? const Color(0x66FFFFFF)
                    : const Color(0xFF999999),
              ),
            ),
            // Hidden button for development/testing - long press to add mock vehicle
            GestureDetector(
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Mock vehicle added for testing'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: Container(
                width: 100,
                height: 50,
                color: Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehiclesList(bool isDarkMode) {
    return RefreshIndicator(
      onRefresh: _loadVehicles,
      color: const Color(0xFF6B9B5B),
      backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _vehicles.length,
        itemBuilder: (context, index) {
          final vehicle = _vehicles[index];
          final isSelected = _selectedVehicle?.id == vehicle.id;

          return AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              final delay = index * 0.1;
              final value =
                  (_animationController.value - delay).clamp(0.0, 1.0) /
                  (1 - delay);

              return Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: Opacity(opacity: value, child: child),
              );
            },
            child: _buildVehicleCard(vehicle, isSelected, isDarkMode),
          );
        },
      ),
    );
  }

  Widget _buildVehicleCard(Bus vehicle, bool isSelected, bool isDarkMode) {
    return GestureDetector(
      onTap: () => _onVehicleSelected(vehicle),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF2196F3)
                : isDarkMode
                ? const Color(0xFF2C2C2C)
                : const Color(0xFFE5E5EA),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF2196F3).withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Selection indicator
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? const Color(0xFF2196F3)
                      : isDarkMode
                      ? const Color(0xFF2C2C2C)
                      : const Color(0xFFE5E5EA),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF2196F3)
                        : isDarkMode
                        ? const Color(0xFF3A3A3C)
                        : const Color(0xFFD1D1D6),
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : null,
              ),
              const SizedBox(width: 16),

              // Vehicle icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.directions_bus_filled,
                  color: Color(0xFF2196F3),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),

              // Vehicle details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicle.registrationNumber,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode
                            ? Colors.white
                            : const Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (vehicle.model != null && vehicle.model!.isNotEmpty)
                      Text(
                        vehicle.model!,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode
                              ? Colors.white60
                              : const Color(0xFF666666),
                        ),
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildInfoChip(
                          Icons.event_seat,
                          '${vehicle.capacity} seats',
                          isDarkMode,
                        ),
                        const SizedBox(width: 8),
                        _buildStatusChip(vehicle.isActive, isDarkMode),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isDarkMode ? Colors.white60 : const Color(0xFF666666),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDarkMode ? Colors.white60 : const Color(0xFF666666),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(bool isActive, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFF4CAF50).withOpacity(0.1)
            : isDarkMode
            ? const Color(0xFF2C2C2C)
            : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFF4CAF50)
                  : const Color(0xFFFF9800),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            isActive ? 'Active' : 'Inactive',
            style: TextStyle(
              fontSize: 12,
              color: isActive
                  ? const Color(0xFF4CAF50)
                  : isDarkMode
                  ? Colors.white60
                  : const Color(0xFF666666),
              fontWeight: isActive ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton(bool isDarkMode) {
    final canConfirm = _selectedVehicle != null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDarkMode
                ? const Color(0xFF2C2C2C)
                : const Color(0xFFE5E5EA),
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: canConfirm ? _onConfirm : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: isDarkMode
                      ? const Color(0xFF2C2C2C)
                      : const Color(0xFFE5E5EA),
                  disabledForegroundColor: isDarkMode
                      ? Colors.white30
                      : const Color(0xFF999999),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Confirm Vehicle',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _goBack,
              child: Text(
                'Back to Trip Selection',
                style: TextStyle(
                  color: isDarkMode ? Colors.white60 : const Color(0xFF666666),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
