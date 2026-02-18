import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../api/services/student_service.dart' as student_service;
import '../../../api/services/route_service.dart' as route_service;
import '../../../api/services/bus_service.dart' as bus_service;
import '../../../api/services/driver_service.dart' as driver_service;
import '../../../api/services/guardian_service.dart' as guardian_service;
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
  bool _triedLoadingStudents = false;
  String? _errorMessage;
  
  // Search state
  bool _isSearchingByPhone = false;
  List<student_service.Student> _phoneSearchResults = [];
  
  // Data lists for dropdowns
  List<route_service.BusRoute> _routes = [];
  List<bus_service.Bus> _buses = [];
  List<driver_service.Driver> _drivers = [];
  List<student_service.Student> _students = [];
  List<student_service.Student> _filteredStudents = [];
  
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
    _searchController.dispose();
    _phoneSearchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    // Start animation immediately without blocking
    _animationController.forward();
    
    // Load data silently in the background - don't block UI
    _loadDataInBackground();
  }
  
  Future<void> _loadDataInBackground() async {
    debugPrint('🔄 Starting background data load...');
    
    try {
      final tripProvider = context.read<TripProvider>();
      
      // Load critical data first (trips, routes, buses, drivers) concurrently
      await Future.wait([
        tripProvider.fetchMasterTrips().then((_) => debugPrint('✅ Master trips loaded')),
        _loadRoutes(),
        _loadBuses(),
        _loadDrivers(),
      ]);
      
      debugPrint('✅ Routes, Buses, Drivers loaded');
      
      // Load students in background (takes longest)
      _loadStudents().then((_) {
        debugPrint('✅ Students loaded');
      }).catchError((e) {
        debugPrint('❌ Error loading students: $e');
      });
      
    } catch (e) {
      debugPrint('❌ Background load error: $e');
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
      final authProvider = context.read<AuthProvider>();
      final driverName = authProvider.userName;
      final userId = authProvider.userId;
      
      if (mounted && driverName != null && driverName.isNotEmpty) {
        // Use driver name from JWT token directly - instant load
        setState(() {
          _drivers = [driver_service.Driver(id: userId ?? '', name: driverName)];
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
      debugPrint('📚 Loading students using companyOrgId approach...');
      final studentService = student_service.StudentService();
      final guardianService = guardian_service.GuardianService();
      final busService = bus_service.BusService();
      
      // Get driver's companyOrgId from bus
      String? companyOrgId;
      try {
        final buses = await busService.getBusesByUser();
        if (buses.isNotEmpty) {
          companyOrgId = buses.first.schoolId;
          debugPrint('🚌 Got companyOrgId from bus: $companyOrgId');
        }
      } catch (e) {
        debugPrint('❌ Failed to get bus: $e');
      }
      
      if (companyOrgId == null || companyOrgId.isEmpty) {
        // Fallback to getAllStudents
        debugPrint('⚠️ No companyOrgId, falling back to getAllStudents');
        final students = await studentService.getAllStudents(limit: 100);
        if (mounted) {
          setState(() {
            _students = students;
            _filteredStudents = students;
          });
        }
      } else {
        // Get guardians with same companyOrgId
        final guardians = await guardianService.getAllGuardians(companyOrgId: companyOrgId);
        
        // Collect unique phone numbers
        final uniquePhones = guardians
            .map((g) => g.bestPhoneNumber)
            .where((p) => p != null && p.isNotEmpty)
            .cast<String>()
            .toSet();
        
        debugPrint('👥 Found ${guardians.length} guardians with ${uniquePhones.length} unique phones');
        
        if (uniquePhones.isNotEmpty) {
          final students = await studentService.getStudentsByPhonesParallel(
            uniquePhones.toList(),
            useCache: true,
          );
          if (mounted) {
            setState(() {
              _students = students;
              _filteredStudents = students;
            });
            debugPrint('✅ Loaded ${students.length} students in parallel');
          }
        } else {
          setState(() {
            _students = [];
            _filteredStudents = [];
          });
        }
      }
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
          _filteredStudents = students;
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
    
    setState(() {
      _editingTrip = null;
      _isCreatingNew = true;
      _tripNameController.clear();
      _tripTimeController.clear();
      _attendantNameController.clear();
      _selectedRoute = null;
      _selectedBus = null;
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
            
            // Driver Display (Read-only)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDarkMode ? Colors.white24 : Colors.grey.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    color: isDarkMode ? Colors.white60 : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Driver',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDarkMode ? Colors.white60 : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selectedDriver ?? 'Loading...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6B9B5B).withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 14,
                          color: Color(0xFF6B9B5B),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Assigned',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B9B5B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
            
            // Extra padding after the create button
            const SizedBox(height: 32),
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
    // Open dialog immediately with phone search as default
    // Students will load in the background
    _showAddStudentDialogWithList(
      [], // Empty initially
      initialShowPhoneSearch: true,
      isLoadingStudents: _isLoadingStudents,
    );
    
    // If students not loaded yet, trigger background loading
    if (_students.isEmpty && !_isLoadingStudents) {
      debugPrint('📚 Loading students in background...');
      _loadStudents().then((_) {
        debugPrint('✅ Students loaded in background: ${_students.length}');
      }).catchError((e) {
        debugPrint('❌ Error loading students in background: $e');
      });
    }
  }
  
  void _showAddStudentDialogWithList(
    List<student_service.Student> availableStudents, {
    bool initialShowPhoneSearch = false,
    bool isLoadingStudents = false,
  }) {
    student_service.Student? selectedStudent;
    String searchQuery = '';
    bool showPhoneSearch = initialShowPhoneSearch;
    bool localIsLoadingStudents = isLoadingStudents;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          // Periodically check loading state while students are loading
          if (_isLoadingStudents) {
            Future.delayed(const Duration(seconds: 1), () {
              if (context.mounted) setState(() {});
            });
          }
          
          // Update local loading state
          if (localIsLoadingStudents != _isLoadingStudents) {
            localIsLoadingStudents = _isLoadingStudents;
          }
          
          // Get current available students (including newly loaded ones)
          final currentStudents = _students.isNotEmpty ? _students : availableStudents;
          
          // Filter students based on search query
          var filteredStudents = currentStudents;
          if (searchQuery.isNotEmpty && !showPhoneSearch) {
            filteredStudents = currentStudents.where((s) {
              return s.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
                     s.className.toLowerCase().contains(searchQuery.toLowerCase()) ||
                     (s.schoolName?.toLowerCase().contains(searchQuery.toLowerCase()) ?? false);
            }).toList();
          }
          
          // Also filter out students already in the trip
          final tripProvider = context.read<TripProvider>();
          final tripStudentIds = tripProvider.tripStudents
              .map((s) => s.studentId.toString())
              .toSet();
          
          if (!showPhoneSearch) {
            filteredStudents = filteredStudents
                .where((s) => !tripStudentIds.contains(s.id) && !tripStudentIds.contains(int.tryParse(s.id)?.toString()))
                .toList();
          }
          
          // Use phone search results if available
          if (showPhoneSearch && _phoneSearchResults.isNotEmpty) {
            filteredStudents = _phoneSearchResults
                .where((s) => !tripStudentIds.contains(s.id))
                .toList();
          }

          return BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: Colors.white.withAlpha(50),
                  width: 1,
                ),
              ),
              elevation: 20,
              shadowColor: Colors.black.withAlpha(100),
              backgroundColor: Colors.white,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.7,
              padding: const EdgeInsets.all(0),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF6B9B5B), Color(0xFF4A7C59)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(30),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.person_add,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Add Student to Trip',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close, color: Colors.white),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Search toggle tabs
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(30),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      showPhoneSearch = false;
                                      _phoneSearchResults = [];
                                      _phoneSearchController.clear();
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: !showPhoneSearch ? Colors.white : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: !showPhoneSearch
                                          ? [BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 4)]
                                          : null,
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.search,
                                          size: 16,
                                          color: !showPhoneSearch ? const Color(0xFF6B9B5B) : Colors.white70,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'By Name',
                                          style: TextStyle(
                                            color: !showPhoneSearch ? const Color(0xFF6B9B5B) : Colors.white70,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => showPhoneSearch = true),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: showPhoneSearch ? Colors.white : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: showPhoneSearch
                                          ? [BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 4)]
                                          : null,
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.phone,
                                          size: 16,
                                          color: showPhoneSearch ? const Color(0xFF6B9B5B) : Colors.white70,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'By Phone',
                                          style: TextStyle(
                                            color: showPhoneSearch ? const Color(0xFF6B9B5B) : Colors.white70,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Show hint when students are loading
                        if (_isLoadingStudents) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(30),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white.withAlpha(200),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Loading student list... You can search by phone now!',
                                    style: TextStyle(
                                      color: Colors.white.withAlpha(230),
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  // Search Field
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: showPhoneSearch
                        ? Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _phoneSearchController,
                                    keyboardType: TextInputType.phone,
                                    decoration: InputDecoration(
                                      hintText: 'Enter guardian phone...',
                                      hintStyle: TextStyle(color: Colors.grey.shade500),
                                      border: InputBorder.none,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      prefixIcon: Icon(Icons.phone, color: Colors.grey.shade500),
                                    ),
                                    onSubmitted: (_) async {
                                      await _searchStudentsByPhone();
                                      setState(() {});
                                    },
                                  ),
                                ),
                                if (_isSearchingByPhone)
                                  const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  )
                                else
                                  Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    child: ElevatedButton(
                                      onPressed: () async {
                                        await _searchStudentsByPhone();
                                        setState(() {});
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF6B9B5B),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      ),
                                      child: const Text('Search'),
                                    ),
                                  ),
                              ],
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: 'Search by name, class or school...',
                                hintStyle: TextStyle(color: Colors.grey.shade500),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
                              ),
                              onChanged: (value) => setState(() => searchQuery = value),
                            ),
                          ),
                  ),
                  
                  // Results header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6B9B5B).withAlpha(20),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${filteredStudents.length} students',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6B9B5B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (_isLoadingStudents && !showPhoneSearch) ...[
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: const Color(0xFF6B9B5B),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const Spacer(),
                        if (_isLoadingStudents && !showPhoneSearch)
                          Text(
                            'Loading...',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                              fontStyle: FontStyle.italic,
                            ),
                          )
                        else if (selectedStudent != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.withAlpha(20),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle, size: 14, color: Colors.blue.shade700),
                                const SizedBox(width: 4),
                                Text(
                                  'Selected',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Student list
                  Expanded(
                    child: filteredStudents.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    shape: BoxShape.circle,
                                  ),
                                  child: _isLoadingStudents && !showPhoneSearch
                                    ? const SizedBox(
                                        width: 48,
                                        height: 48,
                                        child: CircularProgressIndicator(
                                          color: Color(0xFF6B9B5B),
                                        ),
                                      )
                                    : Icon(
                                        showPhoneSearch ? Icons.phone_android : Icons.search_off,
                                        size: 48,
                                        color: Colors.grey.shade400,
                                      ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  showPhoneSearch
                                      ? 'Search by phone to find students'
                                      : _isLoadingStudents
                                          ? 'Loading students...'
                                          : currentStudents.isEmpty
                                              ? 'No students loaded. Try searching by phone.'
                                              : 'No students match your search',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: filteredStudents.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final student = filteredStudents[index];
                              final isSelected = selectedStudent?.id == student.id;
                              
                              return GestureDetector(
                                onTap: () => setState(() => selectedStudent = student),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFF6B9B5B).withAlpha(15) : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected ? const Color(0xFF6B9B5B) : Colors.grey.shade200,
                                      width: isSelected ? 2 : 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withAlpha(10),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: isSelected
                                                ? [const Color(0xFF6B9B5B), const Color(0xFF4A7C59)]
                                                : [Colors.grey.shade300, Colors.grey.shade400],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Center(
                                          child: Text(
                                            student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              student.name,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: isSelected ? const Color(0xFF6B9B5B) : const Color(0xFF1A1A1A),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(Icons.school, size: 12, color: Colors.grey.shade500),
                                                const SizedBox(width: 4),
                                                Text(
                                                  student.className,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Icon(Icons.route, size: 12, color: Colors.grey.shade500),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    student.route ?? 'N/A',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey.shade600,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (student.schoolName != null && student.schoolName!.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 4),
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.location_on, size: 12, color: Colors.grey.shade500),
                                                    const SizedBox(width: 4),
                                                    Expanded(
                                                      child: Text(
                                                        student.schoolName!,
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: Colors.grey.shade500,
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF6B9B5B),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Icon(
                                            Icons.check,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        )
                                      else
                                        Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Icon(
                                            Icons.add,
                                            color: Colors.grey.shade400,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  
                  // Bottom action bar
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                      border: Border(top: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey.shade700,
                              side: BorderSide(color: Colors.grey.shade300),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Cancel', style: TextStyle(fontSize: 16)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: selectedStudent == null
                                ? null
                                : () {
                                    Navigator.pop(context);
                                    _addStudentToTrip(selectedStudent!);
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6B9B5B),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey.shade300,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.person_add, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  selectedStudent == null ? 'Select Student' : 'Add Student',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
