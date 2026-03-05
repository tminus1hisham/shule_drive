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
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _phoneSearchController = TextEditingController();

  // Data
  List<api.Student> _allStudents = [];
  List<api.Student> _filteredStudents = [];
  List<api.Student> _phoneSearchResults = [];
  List<api.MasterTrip> _existingTrips = [];
  api.MasterTrip? _selectedMasterTrip;
  List<api.TripStudent> _masterTripStudents = [];
  Map<String, dynamic>? _preloadedData; // Store preloaded data for driver map

  // UI State
  bool _isLoading = false; // Start false to show UI immediately
  bool _isLoadingStudents = false;
  bool _isCreatingTrip = false;
  bool _isStartingTrip = false;
  bool _showCreateForm = false;
  bool _isSearchingByPhone = false;
  bool _showPhoneSearch = true; // Default to phone search while loading

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
    debugPrint('🚀 SelectStudentsScreen initState()');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('🚀 SelectStudentsScreen postFrameCallback');
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        setState(() {
          _routeId = args['routeId'] as String?;
          _vehicleId = args['vehicleId'] as String?;
          _attendant = args['attendant'] as String?;
          _routeName = args['routeName'] as String?;
          _selectedMasterTrip = args['masterTrip'] as api.MasterTrip?;
        });
        debugPrint(
          '📋 Trip Config: routeId=$_routeId, vehicleId=$_vehicleId, attendant=$_attendant',
        );
        debugPrint('📋 Master Trip: ${_selectedMasterTrip?.tripName}');

        // If preloaded data has students, use them
        final preloadedDataMap = args['preloadedData'] as Map<String, dynamic>?;
        if (preloadedDataMap != null) {
          _preloadedData = preloadedDataMap; // Store for driver map
          if (preloadedDataMap['students'] != null) {
            final studentsJson = preloadedDataMap['students'] as List<dynamic>;
            _masterTripStudents = studentsJson
                .map((s) => api.TripStudent.fromJson(s as Map<String, dynamic>))
                .toList();
            debugPrint('📋 Preloaded students: ${_masterTripStudents.length}');
          }
        }

        // If we have a master trip but no students loaded yet, fetch them
        if (_selectedMasterTrip != null && _masterTripStudents.isEmpty) {
          _loadMasterTripStudents();
        }
      }
      _loadData();
    });
    _searchController.addListener(_filterStudents);

    // Listen to TripProvider changes to sync local state
    final tripProvider = context.read<TripProvider>();
    tripProvider.addListener(_onTripProviderChanged);
  }

  @override
  void dispose() {
    // Remove TripProvider listener
    final tripProvider = context.read<TripProvider>();
    tripProvider.removeListener(_onTripProviderChanged);

    _searchController.dispose();
    _phoneSearchController.dispose();
    _tripNameController.dispose();
    _tripTimeController.dispose();
    super.dispose();
  }

  void _onTripProviderChanged() {
    final tripProvider = context.read<TripProvider>();
    // Only update if we're not currently loading and data changed
    if (!_isLoadingStudents && mounted) {
      final providerStudents = tripProvider.tripStudents;
      if (providerStudents != _masterTripStudents) {
        setState(() {
          _masterTripStudents = providerStudents;
        });
      }
    }
  }

  Future<void> _loadData() async {
    // Don't block UI - start loading in background
    // setState(() => _isLoading = true);

    final provider = context.read<AppProvider>();
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

      // Load existing master trips first (fast)
      await _loadExistingTrips();

      // Load all students in background (slow)
      _loadAllStudents().then(
        (_) {
          if (kDebugMode) {
            print('✅ Students loaded in background');
          }
          // Switch to name search once students are loaded
          if (mounted && context.mounted && _allStudents.isNotEmpty) {
            setState(() {
              _showPhoneSearch = false;
            });
          }
        },
        onError: (e) {
          if (kDebugMode) {
            print('❌ Error loading students: $e');
          }
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading data: $e');
      }
    }
  }

  Future<void> _loadAllStudents() async {
    debugPrint('🔍 _loadAllStudents() STARTED');
    try {
      final studentService = api.StudentService();
      final guardianService = api.GuardianService();
      final busService = api.BusService();

      // Get driver's companyOrgId from bus (same approach as debug button)
      String? companyOrgId;
      try {
        debugPrint('🚌 Fetching buses...');
        final buses = await busService.getBusesByUser();
        debugPrint('🚌 Got ${buses.length} buses');
        if (buses.isNotEmpty) {
          companyOrgId = buses.first.schoolId;
          debugPrint('🚌 Got companyOrgId from bus: $companyOrgId');
        } else {
          debugPrint('⚠️ No buses found!');
        }
      } catch (e) {
        debugPrint('❌ Failed to get bus: $e');
      }

      if (companyOrgId == null || companyOrgId.isEmpty) {
        debugPrint('⚠️ No companyOrgId, falling back to getAllStudents');
        // Fallback: try getAllStudents (which might fail)
        _allStudents = await studentService.getAllStudents(limit: 1000);
        debugPrint('📊 Fallback loaded ${_allStudents.length} students');
      } else {
        debugPrint('🔍 Fetching guardians for companyOrgId: $companyOrgId');
        // Get all guardians with same companyOrgId
        final guardians = await guardianService.getAllGuardians(
          companyOrgId: companyOrgId,
        );
        debugPrint('👥 Found ${guardians.length} guardians');

        // Collect unique phone numbers
        final uniquePhones = guardians
            .map((g) => g.bestPhoneNumber)
            .where((p) => p != null && p.isNotEmpty)
            .cast<String>()
            .toSet();

        debugPrint('📞 Unique phone numbers: $uniquePhones');

        if (uniquePhones.isEmpty) {
          debugPrint('⚠️ No phone numbers found!');
          _allStudents = [];
        } else {
          debugPrint(
            '🚀 Fetching students for ${uniquePhones.length} phones...',
          );
          // Fetch all students in parallel
          _allStudents = await studentService.getStudentsByPhonesParallel(
            uniquePhones.toList(),
            useCache: true,
          );
          debugPrint(
            '✅ Parallel fetch returned ${_allStudents.length} students',
          );
        }
      }

      _filteredStudents = _allStudents;

      debugPrint('👨‍🎓 FINAL: Loaded ${_allStudents.length} students total');

      // Notify UI to update only if still mounted
      if (mounted && context.mounted) {
        setState(() {});
      }
    } catch (e, stackTrace) {
      debugPrint('❌❌❌ ERROR in _loadAllStudents: $e');
      debugPrint('Stack trace: $stackTrace');

      // Only update state if still mounted
      if (mounted && context.mounted) {
        _allStudents = [];
        _filteredStudents = [];
        setState(() {});
      }
    }
    debugPrint('🔍 _loadAllStudents() COMPLETED');
  }

  Future<void> _loadExistingTrips() async {
    try {
      final tripProvider = context.read<TripProvider>();
      await tripProvider.fetchMasterTrips();

      // Filter trips for this route/school
      _existingTrips = tripProvider.masterTrips.where((trip) {
        final matchesRoute =
            trip.route == _routeName || trip.route.contains(_routeName ?? '');
        final matchesSchool =
            trip.adminUserId == _schoolId || trip.schoolname == _schoolName;
        return matchesRoute || matchesSchool;
      }).toList();

      if (kDebugMode) {
        print(
          '🚌 Found ${_existingTrips.length} existing trips for this route',
        );
        for (final trip in _existingTrips) {
          print(
            '   - ${trip.tripName} (${trip.route}) - Active: ${trip.isTripActive}',
          );
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

    setState(() => _isLoadingStudents = true);

    try {
      final tripProvider = context.read<TripProvider>();
      await tripProvider.fetchMasterTripStudents(_selectedMasterTrip!.id);
      setState(() {
        _masterTripStudents = tripProvider.tripStudents;
        _isLoadingStudents = false;
      });

      if (kDebugMode) {
        print(
          '👨‍🎓 Loaded ${_masterTripStudents.length} students in master trip',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading master trip students: $e');
      }
      setState(() {
        _masterTripStudents = [];
        _isLoadingStudents = false;
      });
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

  /// Search students by phone number using the API endpoint
  Future<void> _searchStudentsByPhone() async {
    final phoneNumber = _phoneSearchController.text.trim();

    if (phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a phone number'),
          backgroundColor: Colors.orange,
        ),
      );
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
      final studentService = api.StudentService();
      final students = await studentService.getStudentsByPhone(normalizedPhone);

      setState(() {
        _phoneSearchResults = students;
        _isSearchingByPhone = false;
      });

      if (students.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No students found for phone: $normalizedPhone'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        if (kDebugMode) {
          print(
            '✅ Found ${students.length} students for phone: $normalizedPhone',
          );
        }
      }
    } catch (e) {
      setState(() => _isSearchingByPhone = false);
      if (kDebugMode) {
        print('❌ Error searching students by phone: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error searching: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
      final tripProvider = context.read<TripProvider>();

      await tripProvider.addStudentToMasterTrip(
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

      // Reload students is not strictly necessary anymore, TripProvider handles the optimistic update
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
      final tripProvider = context.read<TripProvider>();

      await tripProvider.deleteStudentFromMasterTrip(
        studentTripId: student.id,
        masterTripId: _selectedMasterTrip!.id,
      );

      // Reload students is not strictly necessary anymore, TripProvider handles optimistic update
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
      final studentIds = _masterTripStudents
          .map((s) => s.studentId.toString())
          .toList();

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

        // Merge original master trip students with API response
        // The API might return incomplete student data, so we preserve the original
        api.Trip mergedTrip = trip;
        if (_masterTripStudents.isNotEmpty &&
            (trip.students.isEmpty ||
                trip.students.any(
                  (s) =>
                      s.name == 'Unknown Student' ||
                      s.name == 'string' ||
                      s.name == '0',
                ))) {
          if (kDebugMode) {
            print('🔄 Merging original student data with API response');
            print('   Original students: ${_masterTripStudents.length}');
          }

          // Create StudentPickup list from master trip students
          final originalStudents = _masterTripStudents
              .map(
                (s) => api.StudentPickup(
                  id: s.studentId.toString(),
                  name: s.fullname.isNotEmpty ? s.fullname : 'Unknown Student',
                  photo: s.profileImage.isNotEmpty ? s.profileImage : null,
                  status: 'pending',
                  parentPhone: s.guardianPhoneNumber.isNotEmpty
                      ? s.guardianPhoneNumber
                      : null,
                ),
              )
              .toList();

          mergedTrip = api.Trip(
            id: trip.id,
            routeName: trip.routeName,
            routeId: trip.routeId,
            startTime: trip.startTime,
            endTime: trip.endTime,
            status: trip.status,
            vehicleId: trip.vehicleId,
            vehicleNumber: trip.vehicleNumber,
            students: originalStudents,
            stops: trip.stops,
            distance: trip.distance,
            fare: trip.fare,
            notes: trip.notes,
          );
        }

        // Save trip to local history
        if (authProvider.isDriver) {
          await TripHistoryService().saveTripToHistory(
            trip: mergedTrip,
            driverId: authProvider.userData['id'] ?? '',
            driverName: authProvider.userData['name'] ?? '',
            attendantName: _attendant,
          );
        }

        // Update the provider with merged trip data
        if (mergedTrip != trip) {
          tripProvider.updateActiveTrip(mergedTrip);
        }

        // Navigate to native Mapbox driver map (vector tiles - crisp and clear)
        if (mounted) {
          Navigator.pushReplacementNamed(
            context,
            '/driver-map',
            arguments: {
              'tripId': mergedTrip.id,
              'preloadedData': _preloadedData,
            },
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

    // Watch TripProvider to rebuild when students change
    // ignore: unused_local_variable
    final tripProvider = context.watch<TripProvider>();

    return MainScaffold(
      title: 'Manage Trip Students',
      showBackButton: true,
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
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

                    // Space between create button/form and students section
                    if ((!_showCreateForm) || _selectedMasterTrip != null)
                      const SizedBox(height: 40),

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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionTitle('Available Students', provider),
                        if (_isLoadingStudents)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: provider.textMutedColor,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Loading...',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: provider.textMutedColor,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          )
                        else
                          Text(
                            '${_filteredStudents.length} students',
                            style: TextStyle(
                              fontSize: 12,
                              color: provider.textMutedColor,
                            ),
                          ),
                      ],
                    ),
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
          if (_selectedMasterTrip != null) _buildBottomButton(provider),
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
            style: TextStyle(fontSize: 14, color: provider.textMutedColor),
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
                color: isSelected
                    ? const Color(0xFF6B9B5B)
                    : Colors.grey.withAlpha(100),
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
              style: TextStyle(fontSize: 12, color: provider.textMutedColor),
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
            initialValue: _tripType,
            decoration: const InputDecoration(
              labelText: 'Trip Type',
              border: OutlineInputBorder(),
            ),
            items: [
              'Morning',
              'Afternoon',
              'Evening',
              'Special',
            ].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
            onChanged: (v) => setState(() => _tripType = v!),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _tripDirection,
            decoration: const InputDecoration(
              labelText: 'Direction',
              border: OutlineInputBorder(),
            ),
            items: [
              'Pickup',
              'Dropoff',
            ].map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
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
    if (_isLoadingStudents) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: provider.cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            children: [
              SizedBox(
                width: 24,
                height: 24,
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
                style: TextStyle(color: provider.textMutedColor, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

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
            style: TextStyle(color: provider.textMutedColor),
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
    return Column(
      children: [
        // Toggle between local search and phone search
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Search by Name'),
                    if (_isLoadingStudents) ...[
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: provider.textMutedColor,
                        ),
                      ),
                    ],
                  ],
                ),
                selected: !_showPhoneSearch,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _showPhoneSearch = false;
                      _phoneSearchResults = [];
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ChoiceChip(
                label: const Text('Search by Phone'),
                selected: _showPhoneSearch,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _showPhoneSearch = true;
                    });
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Show appropriate search field
        if (_showPhoneSearch)
          _buildPhoneSearchBar(provider)
        else
          Container(
            decoration: BoxDecoration(
              color: provider.cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: provider.textColor),
              decoration: InputDecoration(
                hintText: 'Search students by name or class...',
                hintStyle: TextStyle(
                  color: provider.textMutedColor,
                  fontSize: 14,
                ),
                prefixIcon: Icon(Icons.search, color: provider.textMutedColor),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPhoneSearchBar(AppProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: provider.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _phoneSearchController,
              keyboardType: TextInputType.phone,
              style: TextStyle(color: provider.textColor),
              decoration: InputDecoration(
                hintText: 'Enter guardian phone (e.g., 254789133844)',
                hintStyle: TextStyle(
                  color: provider.textMutedColor,
                  fontSize: 14,
                ),
                prefixIcon: Icon(Icons.phone, color: provider.textMutedColor),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
              onSubmitted: (_) => _searchStudentsByPhone(),
            ),
          ),
          if (_isSearchingByPhone)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              onPressed: _searchStudentsByPhone,
              icon: const Icon(Icons.search),
              color: AppProvider.primaryGreen,
            ),
        ],
      ),
    );
  }

  Widget _buildPhoneSearchResultsList(AppProvider provider) {
    // Filter out students already in the master trip
    final availableStudents = _phoneSearchResults
        .where((s) => !_isStudentInMasterTrip(s.id))
        .toList();

    if (availableStudents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, size: 48, color: Colors.green),
              const SizedBox(height: 16),
              Text(
                'All students from this guardian\nare already in the trip',
                textAlign: TextAlign.center,
                style: TextStyle(color: provider.textMutedColor),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header showing search results count
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Icon(Icons.search, size: 16, color: AppProvider.primaryGreen),
              const SizedBox(width: 8),
              Text(
                'Found ${availableStudents.length} student(s) from phone: ${_phoneSearchController.text}',
                style: TextStyle(
                  fontSize: 12,
                  color: provider.textMutedColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        // List of students
        ...availableStudents.map((student) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: provider.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppProvider.primaryGreen.withAlpha(50),
                width: 1,
              ),
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
                        '${student.className} • ${student.schoolName ?? 'N/A'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: provider.textMutedColor,
                        ),
                      ),
                      if (student.guardianPhone != null &&
                          student.guardianPhone!.isNotEmpty)
                        Text(
                          'Guardian: ${student.guardianPhone}',
                          style: TextStyle(
                            fontSize: 11,
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        // Clear results button
        const SizedBox(height: 12),
        Center(
          child: TextButton.icon(
            onPressed: () {
              setState(() {
                _phoneSearchResults = [];
                _phoneSearchController.clear();
              });
            },
            icon: const Icon(Icons.clear),
            label: const Text('Clear Search'),
          ),
        ),
      ],
    );
  }

  Widget _buildAvailableStudentsList(AppProvider provider) {
    debugPrint(
      '🎨 _buildAvailableStudentsList: _isLoading=$_isLoading, _filteredStudents=${_filteredStudents.length}, _showPhoneSearch=$_showPhoneSearch',
    );

    // Show phone search results if available
    if (_showPhoneSearch && _phoneSearchResults.isNotEmpty) {
      return _buildPhoneSearchResultsList(provider);
    }

    // Show phone search empty state
    if (_showPhoneSearch &&
        _phoneSearchController.text.isNotEmpty &&
        !_isSearchingByPhone) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'No students found for this phone number.\nTry searching with a different number.',
            textAlign: TextAlign.center,
            style: TextStyle(color: provider.textMutedColor),
          ),
        ),
      );
    }

    // Show phone search initial state
    if (_showPhoneSearch && _phoneSearchController.text.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.phone_android,
                size: 48,
                color: provider.textMutedColor,
              ),
              const SizedBox(height: 16),
              Text(
                'Enter a guardian phone number\nto search for students',
                textAlign: TextAlign.center,
                style: TextStyle(color: provider.textMutedColor),
              ),
            ],
          ),
        ),
      );
    }

    // Default: show filtered students list
    if (_isLoadingStudents) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppProvider.primaryGreen),
              const SizedBox(height: 16),
              Text(
                'Loading students...\nYou can search by phone meanwhile',
                textAlign: TextAlign.center,
                style: TextStyle(color: provider.textMutedColor),
              ),
            ],
          ),
        ),
      );
    }

    if (_filteredStudents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off, size: 48, color: provider.textMutedColor),
              const SizedBox(height: 16),
              Text(
                'No students found',
                textAlign: TextAlign.center,
                style: TextStyle(color: provider.textMutedColor),
              ),
              const SizedBox(height: 8),
              Text(
                'Try searching by phone number instead',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: provider.textMutedColor),
              ),
            ],
          ),
        ),
      );
    }

    // Filter out students already in the master trip
    final availableStudents = _filteredStudents
        .where((s) => !_isStudentInMasterTrip(s.id))
        .toList();

    if (availableStudents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'All students are already in this trip',
            style: TextStyle(color: provider.textMutedColor),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
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
        onBackgroundImageError: (e, s) {},
      );
    }

    return CircleAvatar(
      radius: 24,
      backgroundColor: const Color(0xFF6B9B5B).withAlpha(50),
      child: const Icon(Icons.person, color: Color(0xFF6B9B5B), size: 24),
    );
  }
}
