import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api/services/trip_service.dart';
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/main_scaffold.dart';

/// Guardian Trips Screen - Shows ACTIVE trips involving guardian's students
/// This is different from driver trip history - guardians only see ongoing trips
class GuardianTripsScreen extends StatefulWidget {
  const GuardianTripsScreen({super.key});

  @override
  State<GuardianTripsScreen> createState() => _GuardianTripsScreenState();
}

class _GuardianTripsScreenState extends State<GuardianTripsScreen> {
  int _currentIndex = 3;
  final TripService _tripService = TripService();
  
  Trip? _activeTrip;
  List<StudentPickup> _myStudents = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadActiveTrip();
  }

  Future<void> _loadActiveTrip() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final guardianPhone = authProvider.userPhone;
      
      if (guardianPhone == null || guardianPhone.isEmpty) {
        setState(() {
          _errorMessage = 'Phone number not found. Please log in again.';
          _isLoading = false;
        });
        return;
      }

      // Fetch active trip for this guardian
      final trip = await _tripService.getActiveTrip(guardianPhone: guardianPhone);

      if (mounted) {
        setState(() {
          _activeTrip = trip;
          _isLoading = false;
        });
        
        // If there's an active trip, filter students for this guardian
        if (trip != null) {
          _filterMyStudents(trip, guardianPhone);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load trip information';
          _isLoading = false;
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
          Navigator.pushReplacementNamed(context, '/landing');
        } else if (index == 1) {
          Navigator.pushNamed(context, '/chat');
        } else if (index == 2) {
          Navigator.pushNamed(context, '/notifications');
        } else if (index == 3) {
          Navigator.pushNamed(context, '/profile');
        }
      },
      body: RefreshIndicator(
        onRefresh: _loadActiveTrip,
        color: const Color(0xFF6B9B5B),
        backgroundColor: provider.cardColor,
        child: _buildBody(provider),
      ),
    );
  }

  Widget _buildBody(AppProvider provider) {
    // Show loading
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF6B9B5B)),
      );
    }

    // Show error
    if (_errorMessage != null) {
      return _buildErrorState(provider);
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

  Widget _buildErrorState(AppProvider provider) {
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
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: provider.textMutedColor,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadActiveTrip,
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
}
