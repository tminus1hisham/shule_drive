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
  
  List<api.Student> _filteredStudents = [];
  List<api.Student> _selectedStudents = [];
  bool _isLoading = true;
  bool _isStartingTrip = false;
  
  // Trip configuration from previous screen
  String? _routeId;
  String? _vehicleId;
  String? _attendant;

  @override
  void initState() {
    super.initState();
    // Get arguments from previous screen
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
      _loadStudents();
    });
    _searchController.addListener(_filterStudents);
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    
    final provider = context.read<AppProvider>();
    final authProvider = context.read<AuthProvider>();
    
    try {
      // Get school ID from driver's profile
      final schoolId = authProvider.currentUser?.schoolId;
      
      if (schoolId != null && schoolId.isNotEmpty) {
        if (kDebugMode) {
          print('🏫 SelectStudentsScreen: Loading students for school $schoolId');
        }
        // Fetch students by school (for drivers)
        await provider.fetchStudentsBySchool(schoolId);
      } else {
        if (kDebugMode) {
          print('⚠️ SelectStudentsScreen: No school ID, falling back to guardian students');
        }
        // Fallback for guardians or if school ID is not available
        await provider.fetchGuardianStudents();
      }
      
      if (mounted) {
        setState(() {
          _filteredStudents = provider.apiStudents;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ SelectStudentsScreen: Error loading students: $e');
      }
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterStudents() {
    final provider = context.read<AppProvider>();
    final query = _searchController.text.toLowerCase();
    
    setState(() {
      if (query.isEmpty) {
        _filteredStudents = provider.apiStudents;
      } else {
        _filteredStudents = provider.apiStudents.where((student) {
          return student.name.toLowerCase().contains(query) ||
                 student.className.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleStudent(api.Student student) {
    setState(() {
      if (_selectedStudents.any((s) => s.id == student.id)) {
        _selectedStudents.removeWhere((s) => s.id == student.id);
      } else {
        _selectedStudents.add(student);
      }
    });
  }

  bool _isSelected(api.Student student) {
    return _selectedStudents.any((s) => s.id == student.id);
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
      
      // Get selected student IDs
      final studentIds = _selectedStudents.map((s) => s.id).toList();
      
      if (kDebugMode) {
        print('🚀 Starting trip...');
        print('   ├─ Route ID: $_routeId');
        print('   ├─ Vehicle ID: $_vehicleId');
        print('   ├─ Students: ${studentIds.length}');
        print('   └─ Driver: ${authProvider.userData?['name'] ?? 'Unknown'}');
      }

      // Call API to start trip
      final trip = await tripProvider.startTrip(
        routeId: _routeId!,
        vehicleId: _vehicleId!,
        studentIds: studentIds,
      );

      if (trip != null && mounted) {
        // Save trip to local history (for driver)
        if (authProvider.isDriver) {
          await TripHistoryService().saveTripToHistory(
            trip: trip,
            driverId: authProvider.userData?['id'] ?? '',
            driverName: authProvider.userData?['name'] ?? '',
            attendantName: _attendant,
          );
          
          if (kDebugMode) {
            print('✅ Trip saved to driver history');
          }
        }

        // Navigate to active trip screen
        Navigator.pushReplacementNamed(
          context,
          '/active-trip',
          arguments: {'tripId': trip.id},
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tripProvider.errorMessage ?? 'Failed to start trip'),
            backgroundColor: Colors.red,
          ),
        );
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
    final students = provider.apiStudents;

    return MainScaffold(
      title: 'Select Students',
      showBackButton: true,
      body: Column(
        children: [
          Expanded(
            child: _isLoading || provider.isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF6B9B5B),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadStudents,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select Students scheduled for this trip.',
                            style: TextStyle(fontSize: 14, color: provider.textMutedColor),
                          ),
                          const SizedBox(height: 16),

                          // Search Bar
                          Container(
                            decoration: BoxDecoration(
                              color: provider.cardColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextField(
                              controller: _searchController,
                              style: TextStyle(color: provider.textColor),
                              decoration: InputDecoration(
                                hintText: 'Search Students',
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
                          ),

                          const SizedBox(height: 20),

                          // Selected Count
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Students added to the list',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: provider.textColor,
                                ),
                              ),
                              Text(
                                '${_selectedStudents.length}/${students.length}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppProvider.primaryGreen,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Empty State
                          if (students.isEmpty)
                            Center(
                              child: Column(
                                children: [
                                  const SizedBox(height: 40),
                                  Icon(
                                    Icons.school_outlined,
                                    size: 64,
                                    color: provider.textMutedColor,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No students found',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: provider.textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Add students in the Manage Children section',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: provider.textMutedColor,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            // Students List
                            ..._filteredStudents.map((student) => _buildStudentCard(student, provider)),
                        ],
                      ),
                    ),
                  ),
          ),

          // Bottom Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: provider.cardColor,
              boxShadow: [
                BoxShadow(
                  color: provider.isDarkMode
                      ? Colors.black.withAlpha(51)
                      : Colors.black.withAlpha(13),
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
                  onPressed: _selectedStudents.isNotEmpty && !_isStartingTrip
                      ? () => _startTrip()
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppProvider.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                    disabledBackgroundColor: provider.isDarkMode
                        ? Colors.grey[800]
                        : const Color(0xFFE0E0E0),
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
                          'Start Trip (${_selectedStudents.length})',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard(api.Student student, AppProvider provider) {
    final isSelected = _isSelected(student);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: provider.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: isSelected
            ? Border.all(color: AppProvider.primaryGreen, width: 2)
            : null,
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
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: provider.textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  student.className,
                  style: TextStyle(
                    fontSize: 14,
                    color: provider.textMutedColor,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _toggleStudent(student),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppProvider.primaryGreen
                    : const Color(0xFFFF9800),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isSelected ? 'Added' : 'Add',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String? photoUrl) {
    // Check if it's a valid network URL
    if (photoUrl != null &&
        photoUrl.isNotEmpty &&
        (photoUrl.startsWith('http://') || photoUrl.startsWith('https://'))) {
      return CircleAvatar(
        radius: 28,
        backgroundImage: NetworkImage(photoUrl),
        backgroundColor: const Color(0xFF6B9B5B).withAlpha(50),
        onBackgroundImageError: (e, s) {
          if (kDebugMode) print('⚠️ Failed to load photo: $e');
        },
      );
    }

    // Fallback to default avatar
    return CircleAvatar(
      radius: 28,
      backgroundColor: const Color(0xFF6B9B5B).withAlpha(50),
      child: const Icon(
        Icons.person,
        color: Color(0xFF6B9B5B),
        size: 28,
      ),
    );
  }
}
