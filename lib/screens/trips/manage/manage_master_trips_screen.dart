import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../api/services/student_service.dart' as student_service;
import '../../../api/services/route_service.dart' as route_service;
import '../../../api/services/bus_service.dart' as bus_service;
import '../../../api/services/driver_service.dart' as driver_service;
import '../../../models/master_trip.dart';
import '../../../providers/app_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/trip_provider.dart';
import '../../../widgets/main_scaffold.dart';

/// Manage Master Trips Screen
/// Allows admins to create/edit trips and add students to them
class ManageMasterTripsScreen extends StatefulWidget {
  const ManageMasterTripsScreen({super.key});

  @override
  State<ManageMasterTripsScreen> createState() => _ManageMasterTripsScreenState();
}

class _ManageMasterTripsScreenState extends State<ManageMasterTripsScreen>
    with SingleTickerProviderStateMixin {
  // Form controllers for trip creation/editing
  final _tripFormKey = GlobalKey<FormState>();
  final _tripNameController = TextEditingController();
  final _tripTimeController = TextEditingController();
  final _attendantNameController = TextEditingController();
  
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
  bool _triedLoadingStudents = false;
  String? _errorMessage;
  
  // Data lists for dropdowns
  List<route_service.BusRoute> _routes = [];
  List<bus_service.Bus> _buses = [];
  List<driver_service.Driver> _drivers = [];
  List<student_service.Student> _students = [];
  
  // Animation
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    
    _loadInitialData();
  }

  @override
  void dispose() {
    _tripNameController.dispose();
    _tripTimeController.dispose();
    _attendantNameController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    
    try {
      final tripProvider = context.read<TripProvider>();
      
      // Fetch all master trips
      await tripProvider.fetchMasterTrips();
      
      // Fetch dropdown data
      await Future.wait([
        _loadRoutes(),
        _loadBuses(),
        _loadDrivers(),
        _loadStudents(),
      ]);
      
      if (mounted) {
        setState(() => _isLoading = false);
        _animationController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load data';
        });
      }
    }
  }

  Future<void> _loadRoutes() async {
    try {
      final routeService = route_service.RouteService();
      final routes = await routeService.getAllRoutes();
      if (mounted) {
        setState(() => _routes = routes);
      }
    } catch (e) {
      debugPrint('Error loading routes: $e');
    }
  }

  Future<void> _loadBuses() async {
    try {
      final busService = bus_service.BusService();
      final buses = await busService.getAllBuses();
      if (mounted) {
        setState(() => _buses = buses);
      }
    } catch (e) {
      debugPrint('Error loading buses: $e');
    }
  }

  Future<void> _loadDrivers() async {
    try {
      final driverService = driver_service.DriverService();
      final schoolId = context.read<AuthProvider>().userData['schoolId']?.toString();
      
      List<driver_service.Driver> drivers;
      if (schoolId != null && schoolId.isNotEmpty) {
        drivers = await driverService.getDriversBySchool(schoolId);
      } else {
        // Fallback to getting all drivers
        drivers = [];
      }
      
      if (mounted) {
        setState(() => _drivers = drivers);
      }
    } catch (e) {
      debugPrint('Error loading drivers: $e');
    }
  }

  Future<void> _loadStudents() async {
    if (_isLoadingStudents) return;
    
    setState(() => _isLoadingStudents = true);
    
    try {
      debugPrint('📚 Loading students from primary endpoint...');
      final studentService = student_service.StudentService();
      // Load more students (100 instead of default 20)
      final students = await studentService.getAllStudents(limit: 100);
      if (mounted) {
        setState(() => _students = students);
        debugPrint('✅ Loaded ${students.length} students from primary endpoint');
      }
    } catch (e) {
      debugPrint('❌ Error loading students from primary endpoint: $e');
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
          _triedLoadingStudents = true;
        });
        debugPrint('✅ Loaded ${students.length} students from guardian endpoint');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading students from guardian endpoint: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() => _triedLoadingStudents = true);
      }
    }
  }

  void _startCreatingNew() {
    setState(() {
      _editingTrip = null;
      _isCreatingNew = true;
      _tripNameController.clear();
      _tripTimeController.clear();
      _attendantNameController.clear();
      _selectedRoute = null;
      _selectedBus = null;
      _selectedDriver = null;
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
    
    setState(() {
      _editingTrip = trip;
      _isCreatingNew = false;
      _isLoadingStudents = true;
      _tripNameController.text = trip.tripName;
      _tripTimeController.text = trip.tripTime;
      _attendantNameController.text = '';
      _selectedRoute = trip.route;
      _selectedDirection = trip.tripDirection == 'to_school' ? 'Pickup' : 'Dropoff';
      _errorMessage = null;
    });
    
    // Fetch students for this trip
    tripProvider.fetchMasterTripStudents(trip.id).then((_) {
      if (mounted) {
        setState(() => _isLoadingStudents = false);
      }
    });
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
        tripDirection: _selectedDirection == 'Pickup' ? 'to_school' : 'from_school',
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
        tripDirection: _selectedDirection == 'Pickup' ? 'to_school' : 'from_school',
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Trip'),
        content: Text('Are you sure you want to delete "${trip.tripName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
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
          _showErrorSnackbar(tripProvider.errorMessage ?? 'Failed to delete trip');
        }
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final tripProvider = context.watch<TripProvider>();
    final isDarkMode = appProvider.isDarkMode;

    return MainScaffold(
      title: _isCreatingNew ? 'Create Trip' : 'Edit Trip',
      showBackButton: true,
      showBottomNav: false,
      actions: [
        if (!_isCreatingNew)
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _startCreatingNew,
            tooltip: 'Create New Trip',
          ),
      ],
      body: RefreshIndicator(
        onRefresh: _loadInitialData,
        color: const Color(0xFF6B9B5B),
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        child: _buildBody(isDarkMode, tripProvider),
      ),
    );
  }

  Widget _buildBody(bool isDarkMode, TripProvider tripProvider) {
    if (_isLoading && tripProvider.masterTrips.isEmpty) {
      return _buildLoadingState(isDarkMode);
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: CustomScrollView(
        slivers: [
          // Existing Trips Section
          SliverToBoxAdapter(
            child: _buildExistingTripsSection(isDarkMode, tripProvider),
          ),
          
          // Trip Form Section
          SliverToBoxAdapter(
            child: _buildTripFormSection(isDarkMode),
          ),
          
          // Students Section (only when editing)
          if (!_isCreatingNew && _editingTrip != null)
            SliverToBoxAdapter(
              child: _buildStudentsSection(isDarkMode, tripProvider),
            ),
          
          const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
        ],
      ),
    );
  }

  Widget _buildLoadingState(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: const Color(0xFF6B9B5B),
            backgroundColor: isDarkMode ? Colors.white24 : Colors.grey.shade200,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading trips...',
            style: TextStyle(
              color: isDarkMode ? Colors.white70 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExistingTripsSection(bool isDarkMode, TripProvider tripProvider) {
    final trips = tripProvider.masterTrips;

    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Existing Trips',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
                ),
              ),
              if (trips.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6B9B5B).withAlpha(30),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${trips.length} trips',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B9B5B),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          
          if (trips.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDarkMode ? Colors.white12 : Colors.grey.shade200,
                ),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.route_outlined,
                      size: 48,
                      color: isDarkMode ? Colors.white38 : Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No trips yet',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white70 : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Create your first trip below',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.white54 : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: trips.length,
                itemBuilder: (context, index) => _buildTripCard(
                  trips[index],
                  isDarkMode,
                  tripProvider,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTripCard(MasterTrip trip, bool isDarkMode, TripProvider tripProvider) {
    final isSelected = _editingTrip?.id == trip.id;
    
    return GestureDetector(
      onTap: () => _startEditingTrip(trip),
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF6B9B5B)
              : isDarkMode
                  ? const Color(0xFF1E1E1E)
                  : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDarkMode ? 30 : 10),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    trip.tripName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Colors.white
                          : isDarkMode
                              ? Colors.white
                              : const Color(0xFF1A1A1A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 20,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              trip.route,
              style: TextStyle(
                fontSize: 13,
                color: isSelected
                    ? Colors.white.withAlpha(200)
                    : isDarkMode
                        ? Colors.white70
                        : Colors.grey.shade600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: isSelected
                      ? Colors.white.withAlpha(180)
                      : isDarkMode
                          ? Colors.white54
                          : Colors.grey.shade500,
                ),
                const SizedBox(width: 4),
                Text(
                  trip.tripTime,
                  style: TextStyle(
                    fontSize: 12,
                    color: isSelected
                        ? Colors.white.withAlpha(180)
                        : isDarkMode
                            ? Colors.white54
                            : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withAlpha(30)
                        : trip.tripDirection == 'to_school'
                            ? Colors.blue.withAlpha(30)
                            : Colors.orange.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    trip.tripDirection == 'to_school' ? 'Pickup' : 'Dropoff',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : trip.tripDirection == 'to_school'
                              ? Colors.blue
                              : Colors.orange,
                    ),
                  ),
                ),
                if (!isSelected)
                  GestureDetector(
                    onTap: () => _deleteTrip(trip),
                    child: Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: isDarkMode ? Colors.white54 : Colors.grey.shade500,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripFormSection(bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDarkMode ? 30 : 10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
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
                    color: const Color(0xFF6B9B5B).withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.edit_note,
                    color: Color(0xFF6B9B5B),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isCreatingNew ? 'Create New Trip' : 'Edit Trip',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
                        ),
                      ),
                      Text(
                        _isCreatingNew
                            ? 'Fill in the details below'
                            : 'Update trip details',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode ? Colors.white60 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Trip Name
            _buildTextField(
              controller: _tripNameController,
              label: 'Trip Name',
              hint: 'e.g., Morning Route A',
              icon: Icons.label_outline,
              isDarkMode: isDarkMode,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a trip name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Trip Time
            _buildTextField(
              controller: _tripTimeController,
              label: 'Trip Time',
              hint: 'e.g., 07:30 AM',
              icon: Icons.access_time,
              isDarkMode: isDarkMode,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter trip time';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Trip Direction
            _buildDirectionSelector(isDarkMode),
            const SizedBox(height: 16),
            
            // Route Dropdown
            _buildDropdown<String>(
              value: _selectedRoute,
              label: 'Route',
              hint: 'Select a route',
              icon: Icons.route,
              isDarkMode: isDarkMode,
              items: _routes.map((r) => r.name).toList(),
              onChanged: (value) => setState(() => _selectedRoute = value),
            ),
            const SizedBox(height: 16),
            
            // Bus/Number Plate Dropdown
            _buildDropdown<String>(
              value: _selectedBus,
              label: 'Bus (Number Plate)',
              hint: 'Select a bus',
              icon: Icons.directions_bus,
              isDarkMode: isDarkMode,
              items: _buses.map((b) => b.registrationNumber).toList(),
              onChanged: (value) => setState(() => _selectedBus = value),
            ),
            const SizedBox(height: 16),
            
            // Driver Dropdown
            _buildDropdown<String>(
              value: _selectedDriver,
              label: 'Driver',
              hint: 'Select a driver',
              icon: Icons.person_outline,
              isDarkMode: isDarkMode,
              items: _drivers.map((d) => d.name).toList(),
              onChanged: (value) => setState(() => _selectedDriver = value),
            ),
            const SizedBox(height: 16),
            
            // Attendant Name
            _buildTextField(
              controller: _attendantNameController,
              label: 'Attendant Name',
              hint: 'e.g., John Doe',
              icon: Icons.badge_outlined,
              isDarkMode: isDarkMode,
            ),
            
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withAlpha(50)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 24),
            
            // Save Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveTrip,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Icon(_isCreatingNew ? Icons.add : Icons.save),
                label: Text(
                  _isCreatingNew ? 'Create Trip' : 'Update Trip',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDarkMode,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      style: TextStyle(
        color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF6B9B5B)),
        filled: true,
        fillColor: isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF6B9B5B), width: 2),
        ),
        labelStyle: TextStyle(
          color: isDarkMode ? Colors.white70 : Colors.grey.shade700,
        ),
        hintStyle: TextStyle(
          color: isDarkMode ? Colors.white38 : Colors.grey.shade500,
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDarkMode,
    required List<T> items,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF6B9B5B)),
        filled: true,
        fillColor: isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF6B9B5B), width: 2),
        ),
        labelStyle: TextStyle(
          color: isDarkMode ? Colors.white70 : Colors.grey.shade700,
        ),
      ),
      hint: Text(
        hint,
        style: TextStyle(
          color: isDarkMode ? Colors.white38 : Colors.grey.shade500,
        ),
      ),
      dropdownColor: isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
      style: TextStyle(
        color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
      ),
      items: items.map((item) {
        return DropdownMenuItem<T>(
          value: item,
          child: Text(
            item.toString(),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildDirectionSelector(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Trip Direction',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDarkMode ? Colors.white70 : Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildDirectionOption(
                'Pickup',
                Icons.arrow_forward,
                Colors.blue,
                isDarkMode,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDirectionOption(
                'Dropoff',
                Icons.arrow_back,
                Colors.orange,
                isDarkMode,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDirectionOption(
    String direction,
    IconData icon,
    Color color,
    bool isDarkMode,
  ) {
    final isSelected = _selectedDirection == direction;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedDirection = direction),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withAlpha(30)
              : isDarkMode
                  ? const Color(0xFF2C2C2C)
                  : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? color : isDarkMode ? Colors.white54 : Colors.grey.shade500,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              direction,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? color
                    : isDarkMode
                        ? Colors.white70
                        : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentsSection(bool isDarkMode, TripProvider tripProvider) {
    final tripStudents = tripProvider.tripStudents;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDarkMode ? 30 : 10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.withAlpha(30),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.people_outline,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Students',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
                        ),
                      ),
                      Text(
                        '${tripStudents.length} students assigned',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode ? Colors.white60 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddStudentDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (_isLoadingStudents)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Column(
                  children: [
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          const Color(0xFF6B9B5B),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Loading students...',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.white60 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (tripStudents.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.person_off_outlined,
                      size: 48,
                      color: isDarkMode ? Colors.white38 : Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No students assigned',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white70 : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Add students to this trip',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.white54 : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: tripStudents.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final student = tripStudents[index];
                return _buildStudentTile(student, isDarkMode, tripProvider);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildStudentTile(TripStudent student, bool isDarkMode, TripProvider tripProvider) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF6B9B5B).withAlpha(30),
            child: Text(
              student.fullname.isNotEmpty ? student.fullname[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Color(0xFF6B9B5B),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.fullname,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${student.classname} • ${student.route}',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDarkMode ? Colors.white60 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _removeStudentFromTrip(student, tripProvider),
            icon: Icon(
              Icons.remove_circle_outline,
              color: Colors.red.withAlpha(200),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddStudentDialog() async {
    // Reload students if empty (with guard to prevent infinite loops)
    if (_students.isEmpty && !_isLoadingStudents) {
      debugPrint('📚 Students empty, reloading...');
      await _loadStudents();
    }
    
    // If still empty after reload, show error
    if (_students.isEmpty) {
      _showErrorSnackbar('Unable to load students. Please check your connection or contact support.');
      return;
    }
    
    // Filter out students already in the trip
    final tripProvider = context.read<TripProvider>();
    final tripStudentIds = tripProvider.tripStudents
        .map((s) => s.studentId.toString())
        .toSet();
    
    debugPrint('📋 Trip students: ${tripStudentIds.length}');
    debugPrint('📋 All students loaded: ${_students.length}');
    debugPrint('📋 Selected route: $_selectedRoute');
    
    // First filter by route if a route is selected
    var routeStudents = _students;
    if (_selectedRoute != null && _selectedRoute!.isNotEmpty) {
      routeStudents = _students.where((s) {
        // Check if student's route matches the selected route
        final studentRoute = s.route ?? '';
        final matches = studentRoute.toLowerCase() == _selectedRoute!.toLowerCase() ||
                        studentRoute.contains(_selectedRoute!) ||
                        _selectedRoute!.contains(studentRoute);
        debugPrint('  Student ${s.name} route: $studentRoute, matches: $matches');
        return matches;
      }).toList();
      debugPrint('📋 Students matching route "$_selectedRoute": ${routeStudents.length}');
    }
    
    // Then filter out students already in the trip
    final availableStudents = routeStudents
        .where((s) => !tripStudentIds.contains(s.id) && !tripStudentIds.contains(int.tryParse(s.id)?.toString()))
        .toList();
    
    debugPrint('📋 Available students after filter: ${availableStudents.length}');

    if (availableStudents.isEmpty) {
      if (_students.isEmpty) {
        _showErrorSnackbar('No students loaded. Please check your connection.');
      } else if (routeStudents.isEmpty) {
        _showErrorSnackbar('No students found for route "$_selectedRoute"');
      } else if (tripStudentIds.isEmpty) {
        // If no trip students but we have students, show all route students
        _showAddStudentDialogWithList(routeStudents);
        return;
      } else {
        _showErrorSnackbar('All students are already in this trip');
      }
      return;
    }
    
    _showAddStudentDialogWithList(availableStudents);
  }
  
  void _showAddStudentDialogWithList(List<student_service.Student> availableStudents) {
    student_service.Student? selectedStudent;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Student to Trip'),
        content: StatefulBuilder(
          builder: (context, setState) {
            return SizedBox(
              width: double.maxFinite,
              child: DropdownButtonFormField<student_service.Student>(
                value: selectedStudent,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Select Student',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: availableStudents.map((student) {
                  return DropdownMenuItem<student_service.Student>(
                    value: student,
                    child: Text('${student.name} (${student.className})'),
                  );
                }).toList(),
                onChanged: (value) => setState(() => selectedStudent = value),
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: selectedStudent == null
                ? null
                : () {
                    Navigator.pop(context);
                    _addStudentToTrip(selectedStudent!);
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B9B5B),
              foregroundColor: Colors.white,
            ),
            child: const Text('Add'),
          ),
        ],
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
      setState(() => _isLoading = false);
      if (result != null) {
        _showSuccessSnackbar('${student.name} added to trip');
      } else {
        _showErrorSnackbar(tripProvider.errorMessage ?? 'Failed to add student');
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

  Future<void> _removeStudentFromTrip(TripStudent student, TripProvider tripProvider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Student'),
        content: Text('Remove ${student.fullname} from this trip?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
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
          _showErrorSnackbar(tripProvider.errorMessage ?? 'Failed to remove student');
        }
      }
    }
  }
}
