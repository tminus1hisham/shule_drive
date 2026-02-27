import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api/services/trip_service.dart';
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/trip_history_service.dart';
import '../../widgets/main_scaffold.dart';

/// Model for guardian trip history entry
/// Groups students by trip so shared trips appear together
class GuardianTripHistoryEntry {
  final String tripId;
  final String routeName;
  final DateTime tripDate;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? vehicleNumber;
  final String status;
  final List<StudentTripInfo> students;

  GuardianTripHistoryEntry({
    required this.tripId,
    required this.routeName,
    required this.tripDate,
    this.startTime,
    this.endTime,
    this.vehicleNumber,
    required this.status,
    required this.students,
  });

  /// Calculate trip duration
  Duration? get duration {
    if (startTime != null && endTime != null) {
      return endTime!.difference(startTime!);
    }
    return null;
    }

  String get formattedDuration {
    final d = duration;
    if (d == null) return '--';
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}

/// Student info within a trip history entry
class StudentTripInfo {
  final String studentId;
  final String name;
  final String? photo;
  final String status;
  final DateTime? pickupTime;
  final DateTime? dropoffTime;

  StudentTripInfo({
    required this.studentId,
    required this.name,
    this.photo,
    required this.status,
    this.pickupTime,
    this.dropoffTime,
  });
}

/// Guardian Trips Screen - Shows ACTIVE trips and TRIP HISTORY for guardian's students
class GuardianTripsScreen extends StatefulWidget {
  const GuardianTripsScreen({super.key});

  @override
  State<GuardianTripsScreen> createState() => _GuardianTripsScreenState();
}

class _GuardianTripsScreenState extends State<GuardianTripsScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 3;
  final TripService _tripService = TripService();
  final TripHistoryService _historyService = TripHistoryService();

  // Tab controller for Active vs History tabs
  late TabController _tabController;

  // Active trip state
  Trip? _activeTrip;
  List<StudentPickup> _myStudents = [];
  bool _isLoadingActive = true;
  String? _activeTripError;

  // History state
  List<GuardianTripHistoryEntry> _tripHistory = [];
  bool _isLoadingHistory = true;
  String? _historyError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadActiveTrip();
    _loadTripHistory();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.index == 1 && _tripHistory.isEmpty && !_isLoadingHistory) {
      _loadTripHistory();
    }
  }

  Future<void> _loadActiveTrip() async {
    setState(() {
      _isLoadingActive = true;
      _activeTripError = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final guardianPhone = authProvider.userPhone;
      
      if (guardianPhone == null || guardianPhone.isEmpty) {
        setState(() {
          _activeTripError = 'Phone number not found. Please log in again.';
          _isLoadingActive = false;
        });
        return;
      }

      // Fetch active trip for this guardian
      final trip = await _tripService.getActiveTrip(guardianPhone: guardianPhone);

      if (mounted) {
        setState(() {
          _activeTrip = trip;
          _isLoadingActive = false;
        });

        // If there's an active trip, filter students for this guardian
        if (trip != null) {
          _filterMyStudents(trip, guardianPhone);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _activeTripError = 'Failed to load trip information';
          _isLoadingActive = false;
        });
      }
    }
  }

  /// Load trip history for this guardian's students
  /// Groups students by trip so shared trips appear together
  Future<void> _loadTripHistory() async {
    setState(() {
      _isLoadingHistory = true;
      _historyError = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final guardianPhone = authProvider.userPhone;

      if (guardianPhone == null || guardianPhone.isEmpty) {
        setState(() {
          _historyError = 'Phone number not found';
          _isLoadingHistory = false;
        });
        return;
      }

      // Get all trips from history service
      // Note: In a real implementation, you might want to add a specific
      // API endpoint for guardian trip history. For now, we simulate with local data.
      final allTrips = await _historyService.getAllTripsForGuardian(guardianPhone);

      // Group trips by trip ID and filter for this guardian's students
      final Map<String, GuardianTripHistoryEntry> tripMap = {};

      for (final tripHistory in allTrips) {
        final trip = tripHistory.trip;

        // Filter students belonging to this guardian
        final myStudentsInTrip = trip.students.where((student) {
          return student.parentPhone == guardianPhone ||
              student.parentPhone?.replaceAll(RegExp(r'[^0-9]'), '') ==
                  guardianPhone.replaceAll(RegExp(r'[^0-9]'), '');
        }).toList();

        // Skip if no students from this guardian are in this trip
        if (myStudentsInTrip.isEmpty) continue;

        // Group by trip ID - if trip already exists, add students to it
        if (tripMap.containsKey(trip.id)) {
          final existingEntry = tripMap[trip.id]!;
          final newStudents = myStudentsInTrip.map((s) => StudentTripInfo(
            studentId: s.id,
            name: s.name,
            photo: s.photo,
            status: s.status,
            pickupTime: s.pickupTime,
            dropoffTime: s.dropoffTime,
          )).toList();

          tripMap[trip.id] = GuardianTripHistoryEntry(
            tripId: trip.id,
            routeName: trip.routeName,
            tripDate: trip.startTime,
            startTime: trip.startTime,
            endTime: trip.endTime,
            vehicleNumber: trip.vehicleNumber,
            status: trip.status,
            students: [...existingEntry.students, ...newStudents],
          );
        } else {
          // Create new entry
          tripMap[trip.id] = GuardianTripHistoryEntry(
            tripId: trip.id,
            routeName: trip.routeName,
            tripDate: trip.startTime,
            startTime: trip.startTime,
            endTime: trip.endTime,
            vehicleNumber: trip.vehicleNumber,
            status: trip.status,
            students: myStudentsInTrip.map((s) => StudentTripInfo(
              studentId: s.id,
              name: s.name,
              photo: s.photo,
              status: s.status,
              pickupTime: s.pickupTime,
              dropoffTime: s.dropoffTime,
            )).toList(),
          );
        }
      }

      if (mounted) {
        setState(() {
          _tripHistory = tripMap.values.toList()
            ..sort((a, b) => b.tripDate.compareTo(a.tripDate));
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _historyError = 'Failed to load trip history';
          _isLoadingHistory = false;
        });
      }
    }
  }

  void _filterMyStudents(Trip trip, String guardianPhone) {
    // Filter students whose parent phone matches the guardian's phone
    setState(() {
      _myStudents = trip.students.where((student) {
        return student.parentPhone == guardianPhone ||
               student.parentPhone?.replaceAll(RegExp(r'[^0-9]'), '') == 
               guardianPhone.replaceAll(RegExp(r'[^0-9]'), '');
      }).toList();
    });
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _getTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return MainScaffold(
      title: 'My Trips',
      showBackButton: true,
      showBottomNav: true,
      bottomNavIndex: _currentIndex,
      onBottomNavTap: (index) {
        setState(() => _currentIndex = index);
        if (index == 0) {
          Navigator.pushReplacementNamed(context, '/dashboard');
        } else if (index == 1) {
          Navigator.pushNamed(context, '/chat');
        } else if (index == 2) {
          Navigator.pushNamed(context, '/notifications');
        } else if (index == 3) {
          Navigator.pushNamed(context, '/profile');
        }
      },
      body: Column(
        children: [
          // Tab Bar
          Container(
            color: provider.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            child: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFF6B9B5B),
              labelColor: const Color(0xFF6B9B5B),
              unselectedLabelColor: provider.textMutedColor,
              tabs: const [
                Tab(icon: Icon(Icons.local_shipping), text: 'Active'),
                Tab(icon: Icon(Icons.history), text: 'History'),
              ],
            ),
          ),
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Active Tab
                RefreshIndicator(
                  onRefresh: _loadActiveTrip,
                  color: const Color(0xFF6B9B5B),
                  backgroundColor: provider.cardColor,
                  child: _buildActiveTab(provider),
                ),
                // History Tab
                RefreshIndicator(
                  onRefresh: _loadTripHistory,
                  color: const Color(0xFF6B9B5B),
                  backgroundColor: provider.cardColor,
                  child: _buildHistoryTab(provider),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTab(AppProvider provider) {
    // Show loading
    if (_isLoadingActive) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF6B9B5B)),
      );
    }

    // Show error
    if (_activeTripError != null) {
      return _buildErrorState(provider, _activeTripError!, _loadActiveTrip);
    }

    // No active trip
    if (_activeTrip == null) {
      return _buildNoActiveTripState(provider);
    }

    // Show active trip
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Active Trip Header
          _buildActiveTripHeader(provider),

          const SizedBox(height: 24),

          // My Students Section
          _buildMyStudentsSection(provider),

          const SizedBox(height: 24),

          // Trip Progress
          _buildTripProgress(provider),

          const SizedBox(height: 24),

          // Live Tracking Button
          _buildLiveTrackingButton(),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildHistoryTab(AppProvider provider) {
    // Show loading
    if (_isLoadingHistory) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF6B9B5B)),
      );
    }

    // Show error
    if (_historyError != null) {
      return _buildErrorState(provider, _historyError!, _loadTripHistory);
    }

    // Empty history
    if (_tripHistory.isEmpty) {
      return _buildEmptyHistoryState(provider);
    }

    // Show trip history
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _tripHistory.length,
      itemBuilder: (context, index) {
        return _buildHistoryCard(provider, _tripHistory[index]);
      },
    );
  }

  Widget _buildActiveTripHeader(AppProvider provider) {
    final trip = _activeTrip!;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6B9B5B), Color(0xFF5A8A4A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6B9B5B).withAlpha(100),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'TRIP IN PROGRESS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _getTimeAgo(trip.startTime),
                style: TextStyle(
                  color: Colors.white.withAlpha(230),
                  fontSize: 13,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Route Name
          Text(
            trip.routeName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Vehicle Info
          Row(
            children: [
              const Icon(Icons.directions_bus, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Text(
                trip.vehicleNumber ?? 'School Bus',
                style: TextStyle(
                  color: Colors.white.withAlpha(230),
                  fontSize: 16,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Start Time
          Row(
            children: [
              const Icon(Icons.access_time, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Text(
                'Started: ${_formatTime(trip.startTime)}',
                style: TextStyle(
                  color: Colors.white.withAlpha(230),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMyStudentsSection(AppProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'My Students',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: provider.textColor,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF6B9B5B).withAlpha(20),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_myStudents.length} on this trip',
                style: const TextStyle(
                  color: Color(0xFF6B9B5B),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        if (_myStudents.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: provider.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: provider.isDarkMode ? Colors.white12 : Colors.grey.shade200,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: provider.textMutedColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No students from your account on this trip',
                    style: TextStyle(
                      color: provider.textMutedColor,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _myStudents.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final student = _myStudents[index];
              return _buildStudentCard(provider, student);
            },
          ),
      ],
    );
  }

  Widget _buildStudentCard(AppProvider provider, StudentPickup student) {
    Color statusColor;
    IconData statusIcon;
    String statusText;
    
    switch (student.status) {
      case 'picked':
        statusColor = const Color(0xFF4CAF50);
        statusIcon = Icons.check_circle;
        statusText = 'Picked Up';
        break;
      case 'absent':
        statusColor = const Color(0xFFFF9800);
        statusIcon = Icons.cancel;
        statusText = 'Absent';
        break;
      case 'dropped':
        statusColor = const Color(0xFF2196F3);
        statusIcon = Icons.logout;
        statusText = 'Dropped Off';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.schedule;
        statusText = 'Waiting';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: provider.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withAlpha(50),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(provider.isDarkMode ? 30 : 10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Student Avatar
          _buildStudentAvatar(student),
          const SizedBox(width: 16),
          
          // Student Info
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
                if (student.pickupTime != null)
                  Text(
                    '${student.status == 'picked' ? 'Picked up at' : 'Status updated'} ${_formatTime(student.pickupTime!)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: provider.textMutedColor,
                    ),
                  ),
              ],
            ),
          ),
          
          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(20),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, color: statusColor, size: 16),
                const SizedBox(width: 6),
                Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentAvatar(StudentPickup student) {
    if (student.photo != null && student.photo!.isNotEmpty) {
      return CircleAvatar(
        radius: 28,
        backgroundImage: NetworkImage(student.photo!),
        onBackgroundImageError: (_, __) {},
      );
    }
    
    return CircleAvatar(
      radius: 28,
      backgroundColor: const Color(0xFF6B9B5B).withAlpha(30),
      child: const Icon(Icons.person, color: Color(0xFF6B9B5B)),
    );
  }

  Widget _buildTripProgress(AppProvider provider) {
    final trip = _activeTrip!;
    final totalStudents = trip.students.length;
    final pickedCount = trip.pickedCount;
    final progress = totalStudents > 0 ? pickedCount / totalStudents : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: provider.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(provider.isDarkMode ? 30 : 10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trip Progress',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: provider.textColor,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: provider.isDarkMode 
                  ? Colors.white12 
                  : Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6B9B5B)),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$pickedCount of $totalStudents students picked up',
                style: TextStyle(
                  fontSize: 14,
                  color: provider.textMutedColor,
                ),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6B9B5B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLiveTrackingButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.pushNamed(
            context,
            '/osm-tracking',
            arguments: {
              'tripId': _activeTrip?.id ?? 'TRIP_001',
              'busId': _activeTrip?.vehicleId ?? 'BUS001',
              'routeId': _activeTrip?.routeId ?? 'ROUTE_001',
            },
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6B9B5B),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
          shadowColor: const Color(0xFF6B9B5B).withAlpha(100),
        ),
        icon: const Icon(Icons.location_on, size: 24),
        label: const Text(
          'Live Track Bus',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildNoActiveTripState(AppProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF6B9B5B).withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.local_shipping_outlined,
                size: 60,
                color: provider.textMutedColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Active Trips',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: provider.textColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'There are no active trips involving your children at the moment.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: provider.textMutedColor,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 200,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _loadActiveTrip,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B9B5B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.refresh),
                label: const Text(
                  'Check Again',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(AppProvider provider, String message, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: provider.textMutedColor,
            ),
            const SizedBox(height: 16),
            Text(
              'Oops!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: provider.textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: provider.textMutedColor,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B9B5B),
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyHistoryState(AppProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF6B9B5B).withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.history,
                size: 60,
                color: provider.textMutedColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Trip History',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: provider.textColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Completed trips involving your students will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: provider.textMutedColor,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build a history card that groups students by trip
  /// Shows pick time and drop time for each student
  Widget _buildHistoryCard(AppProvider provider, GuardianTripHistoryEntry entry) {
    final isCompleted = entry.status == 'completed';
    final statusText = isCompleted ? 'Completed' : 'In Progress';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: provider.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(provider.isDarkMode ? 30 : 10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isCompleted
                    ? [const Color(0xFF6B9B5B), const Color(0xFF5A8A4A)]
                    : [const Color(0xFFFF9800), const Color(0xFFF57C00)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(30),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        statusText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      _formatDate(entry.tripDate),
                      style: TextStyle(
                        color: Colors.white.withAlpha(230),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  entry.routeName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.directions_bus, color: Colors.white70, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      entry.vehicleNumber ?? 'School Bus',
                      style: TextStyle(
                        color: Colors.white.withAlpha(230),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Trip Time Info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _buildTimeInfo(
                    provider,
                    'Start',
                    entry.startTime != null ? _formatTime(entry.startTime!) : '--:--',
                    Icons.play_circle_outline,
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: provider.isDarkMode ? Colors.white12 : Colors.grey.shade200,
                ),
                Expanded(
                  child: _buildTimeInfo(
                    provider,
                    'End',
                    entry.endTime != null ? _formatTime(entry.endTime!) : '--:--',
                    Icons.stop_circle_outlined,
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: provider.isDarkMode ? Colors.white12 : Colors.grey.shade200,
                ),
                Expanded(
                  child: _buildTimeInfo(
                    provider,
                    'Duration',
                    entry.formattedDuration,
                    Icons.timer_outlined,
                  ),
                ),
              ],
            ),
          ),

          // Students Section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Students (${entry.students.length})',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: provider.textColor,
                  ),
                ),
                const SizedBox(height: 12),
                ...entry.students.map((student) => _buildHistoryStudentItem(provider, student)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeInfo(AppProvider provider, String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF6B9B5B)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: provider.textColor,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: provider.textMutedColor,
          ),
        ),
      ],
    );
  }

  /// Build student item with pick time and drop time for history
  Widget _buildHistoryStudentItem(AppProvider provider, StudentTripInfo student) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (student.status) {
      case 'picked':
      case 'dropped':
        statusColor = const Color(0xFF4CAF50);
        statusIcon = Icons.check_circle;
        statusText = 'Completed';
        break;
      case 'absent':
        statusColor = const Color(0xFFFF9800);
        statusIcon = Icons.cancel;
        statusText = 'Absent';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.schedule;
        statusText = 'Pending';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: provider.isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withAlpha(30),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Student Avatar
          CircleAvatar(
            radius: 22,
            backgroundColor: statusColor.withAlpha(30),
            backgroundImage: student.photo != null && student.photo!.isNotEmpty
                ? NetworkImage(student.photo!)
                : null,
            child: student.photo == null || student.photo!.isEmpty
                ? Icon(Icons.person, color: statusColor, size: 20)
                : null,
          ),
          const SizedBox(width: 12),

          // Student Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: provider.textColor,
                  ),
                ),
                const SizedBox(height: 4),
                // Pick and Drop times
                Row(
                  children: [
                    if (student.pickupTime != null) ...[
                      Icon(Icons.login, size: 12, color: provider.textMutedColor),
                      const SizedBox(width: 4),
                      Text(
                        _formatTime(student.pickupTime!),
                        style: TextStyle(
                          fontSize: 12,
                          color: provider.textMutedColor,
                        ),
                      ),
                    ],
                    if (student.pickupTime != null && student.dropoffTime != null)
                      Text(
                        ' → ',
                        style: TextStyle(
                          fontSize: 12,
                          color: provider.textMutedColor,
                        ),
                      ),
                    if (student.dropoffTime != null) ...[
                      Icon(Icons.logout, size: 12, color: provider.textMutedColor),
                      const SizedBox(width: 4),
                      Text(
                        _formatTime(student.dropoffTime!),
                        style: TextStyle(
                          fontSize: 12,
                          color: provider.textMutedColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(20),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, color: statusColor, size: 14),
                const SizedBox(width: 4),
                Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
