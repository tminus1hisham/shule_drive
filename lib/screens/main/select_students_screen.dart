import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api/api.dart' as api;
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/trip_provider.dart';
import '../../services/trip_history_service.dart';
import '../../widgets/main_scaffold.dart';

class SelectStudentsScreen extends StatefulWidget {
  const SelectStudentsScreen({super.key});

  @override
  State<SelectStudentsScreen> createState() => _SelectStudentsScreenState();
}

class _SelectStudentsScreenState extends State<SelectStudentsScreen> {
  int _currentIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  
  // Data
  List<api.Student> _allStudents = [];
  List<api.Student> _filteredStudents = [];
  List<api.MasterTrip> _existingTrips = [];
  api.MasterTrip? _selectedMasterTrip;
  List<api.TripStudent> _masterTripStudents = [];
  
  // UI State
  bool _isLoading = true;
  bool _isCreatingTrip = false;
  bool _isStartingTrip = false;
  bool _showCreateForm = false;
  
  // Trip configuration from previous screen
  String? _routeId;
  String? _vehicleId;
  String? _attendant;
  String? _routeName;
  String? _schoolName;
  String? _schoolId;

  // Form controllers for new master trip
  final _tripNameController = TextEditingController();
  final _tripTimeController = TextEditingController();
  String _tripType = 'Morning';
  String _tripDirection = 'Pickup';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        setState(() {
          _routeId = args['routeId'] as String?;
          _vehicleId = args['vehicleId'] as String?;
          _attendant = args['attendant'] as String?;
        });
        if (kDebugMode) {
          print('📋 Trip Config: routeId=$_routeId, vehicleId=$_vehicleId, attendant=$_attendant');
        }
      }
      _loadData();
    });
    _searchController.addListener(_filterStudents);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tripNameController.dispose();
    _tripTimeController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final provider = context.read<AppProvider>();
    final tripProvider = context.read<TripProvider>();
    final authProvider = context.read<AuthProvider>();
    
    try {
      _schoolId = authProvider.currentUser?.schoolId;
      
      // Get route details
      if (_routeId != null) {
        final route = provider.routes.firstWhere(
          (r) => r.id == _routeId,
          orElse: () => provider.routes.first,
        );
        _routeName = route.name;
        _schoolName = route.schoolName;
        
        if (kDebugMode) {
          print('🛣️ Selected route: $_routeName (ID: $_routeId)');
          print('🏫 School: $_schoolName (ID: $_schoolId)');
        }
      }
      
      // Load all students
      await _loadAllStudents();
      
      // Load existing master trips for this route
      await _loadExistingTrips();
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading data: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadAllStudents() async {
    try {
      final studentService = api.StudentService();
      _allStudents = await studentService.getAllStudents(limit: 1000);
      _filteredStudents = _allStudents;
      
      if (kDebugMode) {
        print('👨‍🎓 Loaded ${_allStudents.length} students');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading students: $e');
      }
      _allStudents = [];
      _filteredStudents = [];
    }
  }

  Future<void> _loadExistingTrips() async {
    try {
      final tripProvider = context.read<TripProvider>();
      await tripProvider.fetchMasterTrips();
      
      // Filter trips for this route/school
      _existingTrips = tripProvider.masterTrips.where((trip) {
        final matchesRoute = trip.route == _routeName || 
                            trip.route.contains(_routeName ?? '');
        final matchesSchool = trip.adminUserId == _schoolId ||
                             trip.schoolname == _schoolName;
        return matchesRoute || matchesSchool;
      }).toList();
      
      if (kDebugMode) {
        print('🚌 Found ${_existingTrips.length} existing trips for this route');
        for (final trip in _existingTrips) {
          print('   - ${trip.tripName} (${trip.route}) - Active: ${trip.isTripActive}');
        }
      }
      
      // If there's an active trip, select it by default
      if (_existingTrips.isNotEmpty) {
        _selectedMasterTrip = _existingTrips.firstWhere(
          (t) => t.isTripActive,
          orElse: () => _existingTrips.first,
        );
        await _loadMasterTripStudents();
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading existing trips: $e');
      }
      _existingTrips = [];
    }
  }

  Future<void> _loadMasterTripStudents() async {
    if (_selectedMasterTrip == null) return;
    
    try {
      final tripProvider = context.read<TripProvider>();
      await tripProvider.fetchMasterTripStudents(_selectedMasterTrip!.id);
      _masterTripStudents = tripProvider.tripStudents;
      
      if (kDebugMode) {
        print('👨‍🎓 Loaded ${_masterTripStudents.length} students in master trip');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading master trip students: $e');
      }
      _masterTripStudents = [];
    }
  }

  void _filterStudents() {
    final query = _searchController.text.toLowerCase();
    
    setState(() {
      if (query.isEmpty) {
        _filteredStudents = _allStudents;
      } else {
        _filteredStudents = _allStudents.where((student) {
          return student.name.toLowerCase().contains(query) ||
                 student.className.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  bool _isStudentInMasterTrip(String studentId) {
    return _masterTripStudents.any((s) => s.studentId.toString() == studentId);
  }

  Future<void> _addStudentToMasterTrip(api.Student student) async {
    if (_selectedMasterTrip == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or create a master trip first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final tripService = api.TripService();
      
      await tripService.addStudentToMasterTrip(
        masterTripId: _selectedMasterTrip!.id,
        fullname: student.name,
        studentRegNumber: student.id,
        studentId: int.tryParse(student.id) ?? 0,
        classname: student.className,
        route: _routeName ?? '',
        latitude: 0.0,
        longitude: 0.0,
        guardianPhoneNumber: student.guardianPhone ?? '',
        schoolname: _schoolName ?? '',
      );

      // Reload students
      await _loadMasterTripStudents();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${student.name} added to trip'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error adding student: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding student: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeStudentFromMasterTrip(api.TripStudent student) async {
    try {
      final tripService = api.TripService();
      
      await tripService.deleteStudentFromMasterTrip(
        masterTripId: _selectedMasterTrip!.id,
        studentTripId: student.id,
      );

      // Reload students
      await _loadMasterTripStudents();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${student.fullname} removed from trip'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error removing student: $e');
      }
    }
  }

  Future<void> _createMasterTrip() async {
    if (_tripNameController.text.isEmpty || _tripTimeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isCreatingTrip = true);

    try {
      final tripService = api.TripService();
      final authProvider = context.read<AuthProvider>();
      final driverName = authProvider.userName ?? 'Unknown Driver';
      
      final newTrip = await tripService.createMasterTrip(
        tripName: _tripNameController.text,
        tripTime: _tripTimeController.text,
        tripDirection: _tripDirection == 'Pickup' ? 'to_school' : 'from_school',
        route: _routeName ?? '',
        numberPlate: _vehicleId ?? '',
        attendantName: _attendant ?? '',
        driverName: driverName,
      );

      // Reload trips
      await _loadExistingTrips();
      
      setState(() {
        _selectedMasterTrip = newTrip;
        _showCreateForm = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Master trip "${newTrip.tripName}" created'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error creating master trip: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating trip: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isCreatingTrip = false);
    }
  }

  Future<void> _startTrip() async {
    if (_routeId == null || _vehicleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Missing route or vehicle information'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isStartingTrip = true);

    try {
      final tripProvider = context.read<TripProvider>();
      final authProvider = context.read<AuthProvider>();
      
      // Get student IDs from master trip
      final studentIds = _masterTripStudents.map((s) => s.studentId.toString()).toList();
      
      if (kDebugMode) {
        print('🚀 Starting trip...');
        print('   ├─ Route ID: $_routeId');
        print('   ├─ Vehicle ID: $_vehicleId');
        print('   ├─ Students: ${studentIds.length}');
        print('   └─ Master Trip: ${_selectedMasterTrip?.tripName}');
      }

      // Get driver details
      final driverName = authProvider.userName ?? 'Unknown Driver';
      final driverPhone = authProvider.userPhone ?? '';
      
      // Get bus number plate from app provider
      String numberPlate = _vehicleId!;
      final appProvider = context.read<AppProvider>();
      for (final bus in appProvider.buses) {
        if (bus.id == _vehicleId) {
          numberPlate = bus.registrationNumber;
          break;
        }
      }
      
      // Call API to start trip with all required fields
      final trip = await tripProvider.startTrip(
        routeId: _routeId!,
        vehicleId: _vehicleId!,
        studentIds: studentIds,
        route: _routeName ?? '',
        tripName: _selectedMasterTrip?.tripName ?? 'Trip',
        driverName: driverName,
        numberPlate: numberPlate,
        driverPhoneNumber: driverPhone,
      );

      if (!mounted) return;

      if (trip != null) {
        if (kDebugMode) {
          print('✅ Trip started successfully: ${trip.id}');
        }
        
        // Save trip to local history
        if (authProvider.isDriver) {
          await TripHistoryService().saveTripToHistory(
            trip: trip,
            driverId: authProvider.userData['id'] ?? '',
            driverName: authProvider.userData['name'] ?? '',
            attendantName: _attendant,
          );
        }

        // Navigate to active trip screen
        if (mounted) {
          Navigator.pushReplacementNamed(
            context,
            '/active-trip',
            arguments: {'tripId': trip.id},
          );
        }
      } else {
        // Show error if trip is null
        final errorMsg = tripProvider.errorMessage ?? 'Failed to start trip';
        if (kDebugMode) {
          print('❌ Failed to start trip: $errorMsg');
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $errorMsg'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error starting trip: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting trip: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isStartingTrip = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return MainScaffold(
      title: 'Manage Trip Students',
      showBackButton: true,
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF6B9B5B),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Route Info Header
                          _buildRouteHeader(provider),
                          
                          const SizedBox(height: 20),
                          
                          // Existing Master Trips Section
                          if (_existingTrips.isNotEmpty) ...[
                            _buildSectionTitle('Existing Trips', provider),
                            const SizedBox(height: 8),
                            _buildExistingTripsList(provider),
                            const SizedBox(height: 20),
                          ],
                          
                          // Create New Trip Button
                          if (!_showCreateForm)
                            ElevatedButton.icon(
                              onPressed: () => setState(() => _showCreateForm = true),
                              icon: const Icon(Icons.add),
                              label: const Text('Create New Master Trip'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6B9B5B),
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 48),
                              ),
                            ),
                          
                          // Create Trip Form
                          if (_showCreateForm) ...[
                            _buildCreateTripForm(provider),
                            const SizedBox(height: 20),
                          ],
                          
                          // Current Trip Students Section
                          if (_selectedMasterTrip != null) ...[
                            _buildSectionTitle(
                              'Students in ${_selectedMasterTrip!.tripName}',
                              provider,
                            ),
                            const SizedBox(height: 8),
                            _buildMasterTripStudentsList(provider),
                            const SizedBox(height: 20),
                          ],
                          
                          // Available Students Section
                          _buildSectionTitle('Available Students', provider),
                          const SizedBox(height: 8),
                          
                          // Search Bar
                          _buildSearchBar(provider),
                          const SizedBox(height: 12),
                          
                          // Available Students List
                          _buildAvailableStudentsList(provider),
                        ],
                      ),
                    ),
                  ),
          ),

          // Bottom Start Trip Button
          if (_selectedMasterTrip != null)
            _buildBottomButton(provider),
        ],
      ),
    );
  }

  Widget _buildRouteHeader(AppProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF6B9B5B).withAlpha(30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF6B9B5B).withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.route, color: Color(0xFF6B9B5B)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _routeName ?? 'Unknown Route',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: provider.textColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'School: ${_schoolName ?? 'Unknown'}',
            style: TextStyle(
              fontSize: 14,
              color: provider.textMutedColor,
            ),
          ),
          if (_selectedMasterTrip != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Selected Trip: ${_selectedMasterTrip!.tripName}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, AppProvider provider) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: provider.textColor,
      ),
    );
  }

  Widget _buildExistingTripsList(AppProvider provider) {
    return Column(
      children: _existingTrips.map((trip) {
        final isSelected = _selectedMasterTrip?.id == trip.id;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            onTap: () async {
              setState(() => _selectedMasterTrip = trip);
              await _loadMasterTripStudents();
            },
            selected: isSelected,
            selectedTileColor: const Color(0xFF6B9B5B).withAlpha(30),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isSelected ? const Color(0xFF6B9B5B) : Colors.grey.withAlpha(100),
              ),
            ),
            leading: Icon(
              trip.isTripActive ? Icons.check_circle : Icons.circle_outlined,
              color: trip.isTripActive ? Colors.green : Colors.grey,
            ),
            title: Text(
              trip.tripName,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: provider.textColor,
              ),
            ),
            subtitle: Text(
              '${trip.tripType} • ${trip.tripTime} • ${trip.route}',
              style: TextStyle(
                fontSize: 12,
                color: provider.textMutedColor,
              ),
            ),
            trailing: isSelected
                ? const Icon(Icons.check, color: Color(0xFF6B9B5B))
                : null,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCreateTripForm(AppProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: provider.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withAlpha(100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Create New Master Trip',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: provider.textColor,
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _showCreateForm = false),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tripNameController,
            decoration: const InputDecoration(
              labelText: 'Trip Name *',
              hintText: 'e.g., Morning Pickup - Route A',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tripTimeController,
            decoration: const InputDecoration(
              labelText: 'Trip Time *',
              hintText: 'e.g., 07:30 AM',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _tripType,
            decoration: const InputDecoration(
              labelText: 'Trip Type',
              border: OutlineInputBorder(),
            ),
            items: ['Morning', 'Afternoon', 'Evening', 'Special']
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (v) => setState(() => _tripType = v!),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _tripDirection,
            decoration: const InputDecoration(
              labelText: 'Direction',
              border: OutlineInputBorder(),
            ),
            items: ['Pickup', 'Dropoff']
                .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                .toList(),
            onChanged: (v) => setState(() => _tripDirection = v!),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isCreatingTrip ? null : _createMasterTrip,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B9B5B),
                foregroundColor: Colors.white,
              ),
              child: _isCreatingTrip
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Create Trip'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMasterTripStudentsList(AppProvider provider) {
    if (_masterTripStudents.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: provider.cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            'No students in this trip yet.\nAdd students from below.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: provider.textMutedColor,
            ),
          ),
        ),
      );
    }

    return Column(
      children: _masterTripStudents.map((student) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF6B9B5B).withAlpha(20),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF6B9B5B).withAlpha(50)),
          ),
          child: Row(
            children: [
              _buildAvatar(student.profileImage),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.fullname,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: provider.textColor,
                      ),
                    ),
                    Text(
                      student.classname,
                      style: TextStyle(
                        fontSize: 12,
                        color: provider.textMutedColor,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _removeStudentFromMasterTrip(student),
                icon: const Icon(Icons.remove_circle, color: Colors.red),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSearchBar(AppProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: provider.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: provider.textColor),
        decoration: InputDecoration(
          hintText: 'Search students to add...',
          hintStyle: TextStyle(
            color: provider.textMutedColor,
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: provider.textMutedColor,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildAvailableStudentsList(AppProvider provider) {
    if (_filteredStudents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'No students found',
            style: TextStyle(
              color: provider.textMutedColor,
            ),
          ),
        ),
      );
    }

    // Filter out students already in the master trip
    final availableStudents = _filteredStudents.where(
      (s) => !_isStudentInMasterTrip(s.id),
    ).toList();

    if (availableStudents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'All students are already in this trip',
            style: TextStyle(
              color: provider.textMutedColor,
            ),
          ),
        ),
      );
    }

    return Column(
      children: availableStudents.map((student) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: provider.cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              _buildAvatar(student.photo),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: provider.textColor,
                      ),
                    ),
                    Text(
                      student.className,
                      style: TextStyle(
                        fontSize: 12,
                        color: provider.textMutedColor,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _addStudentToMasterTrip(student),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF9800),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBottomButton(AppProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: provider.cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(26),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _masterTripStudents.isNotEmpty && !_isStartingTrip
                ? _startTrip
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B9B5B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              disabledBackgroundColor: Colors.grey.withAlpha(100),
            ),
            child: _isStartingTrip
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    'Start Trip (${_masterTripStudents.length} students)',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(String? photoUrl) {
    if (photoUrl != null &&
        photoUrl.isNotEmpty &&
        (photoUrl.startsWith('http://') || photoUrl.startsWith('https://'))) {
      return CircleAvatar(
        radius: 24,
        backgroundImage: NetworkImage(photoUrl),
        backgroundColor: const Color(0xFF6B9B5B).withAlpha(50),
        onBackgroundImageError: (_, __) {},
      );
    }

    return CircleAvatar(
      radius: 24,
      backgroundColor: const Color(0xFF6B9B5B).withAlpha(50),
      child: const Icon(
        Icons.person,
        color: Color(0xFF6B9B5B),
        size: 24,
      ),
    );
  }
}
