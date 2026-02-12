import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api/services/trip_service.dart';
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/trip_history_service.dart';
import '../../widgets/main_scaffold.dart';

/// Trip Details Screen - Shows detailed trip information for DRIVERS ONLY
/// Includes: trip info, students picked/dropped, timeline, stats
class TripDetailsScreen extends StatefulWidget {
  const TripDetailsScreen({super.key});

  @override
  State<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends State<TripDetailsScreen> {
  TripHistory? _tripHistory;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTripDetails();
  }

  Future<void> _loadTripDetails() async {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    
    if (args != null && args['history'] != null) {
      setState(() {
        _tripHistory = args['history'] as TripHistory;
        _isLoading = false;
      });
    } else if (args != null && args['tripId'] != null) {
      // Load from history service
      final authProvider = context.read<AuthProvider>();
      final driverId = authProvider.userData?['id'] ?? '';
      final history = await TripHistoryService().getTripHistory(driverId);
      
      final tripHistory = history.firstWhere(
        (h) => h.trip.id == args['tripId'],
        orElse: () => throw Exception('Trip not found'),
      );
      
      if (mounted) {
        setState(() {
          _tripHistory = tripHistory;
          _isLoading = false;
        });
      }
    } else {
      setState(() => _isLoading = false);
    }
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final authProvider = context.watch<AuthProvider>();

    // GUARDIAN CHECK: Only drivers should see this screen
    if (!authProvider.isDriver) {
      return _buildGuardianBlockedView(provider);
    }

    if (_isLoading) {
      return const MainScaffold(
        title: 'Trip Details',
        showBackButton: true,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF6B9B5B)),
        ),
      );
    }

    if (_tripHistory == null) {
      return MainScaffold(
        title: 'Trip Details',
        showBackButton: true,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: provider.textMutedColor),
              const SizedBox(height: 16),
              Text(
                'Trip not found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: provider.textColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final trip = _tripHistory!.trip;
    final history = _tripHistory!;

    return MainScaffold(
      title: 'Trip Details',
      showBackButton: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Trip Header Card
            _buildTripHeaderCard(provider, trip, history),
            
            const SizedBox(height: 20),
            
            // Trip Stats
            _buildTripStats(provider, trip),
            
            const SizedBox(height: 24),
            
            // Students Section
            _buildStudentsSection(provider, trip),
            
            const SizedBox(height: 24),
            
            // Trip Timeline (if stops available)
            if (trip.stops.isNotEmpty) ...[
              _buildTimelineSection(provider, trip),
              const SizedBox(height: 24),
            ],
            
            // Driver Info
            _buildDriverInfoCard(provider, history),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildGuardianBlockedView(AppProvider provider) {
    return MainScaffold(
      title: 'Trip Details',
      showBackButton: true,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_outline,
                  size: 64,
                  color: Colors.orange.shade400,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Driver Feature Only',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: provider.textColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Trip details are only available for drivers.',
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
      ),
    );
  }

  Widget _buildTripHeaderCard(AppProvider provider, Trip trip, TripHistory history) {
    final isCompleted = trip.isCompleted;
    
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isCompleted ? 'COMPLETED' : 'ACTIVE',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                _formatDate(trip.startTime),
                style: TextStyle(
                  color: Colors.white.withAlpha(230),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            trip.routeName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.directions_bus, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Text(
                trip.vehicleNumber ?? 'Unknown Vehicle',
                style: TextStyle(
                  color: Colors.white.withAlpha(230),
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
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
          if (trip.endTime != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Ended: ${_formatTime(trip.endTime!)}',
                  style: TextStyle(
                    color: Colors.white.withAlpha(230),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTripStats(AppProvider provider, Trip trip) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: provider.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(provider.isDarkMode ? 51 : 13),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trip Statistics',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: provider.textColor,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatBox(
                provider,
                trip.students.length.toString(),
                'Total Students',
                Icons.people,
                const Color(0xFF6B9B5B),
              ),
              const SizedBox(width: 12),
              _buildStatBox(
                provider,
                trip.pickedCount.toString(),
                'Picked Up',
                Icons.check_circle,
                const Color(0xFF4CAF50),
              ),
              const SizedBox(width: 12),
              _buildStatBox(
                provider,
                trip.absentCount.toString(),
                'Absent',
                Icons.cancel,
                const Color(0xFFFF9800),
              ),
            ],
          ),
          if (trip.distance != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _buildStatBox(
                  provider,
                  '${trip.distance!.toStringAsFixed(1)} km',
                  'Distance',
                  Icons.route,
                  const Color(0xFF2196F3),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatBox(
    AppProvider provider,
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withAlpha(provider.isDarkMode ? 30 : 15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: provider.textMutedColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentsSection(AppProvider provider, Trip trip) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Students (${trip.students.length})',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: provider.textColor,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF6B9B5B).withAlpha(20),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFF6B9B5B), size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${trip.pickedCount}/${trip.students.length}',
                    style: const TextStyle(
                      color: Color(0xFF6B9B5B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: trip.students.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final student = trip.students[index];
            return _buildStudentItem(provider, student);
          },
        ),
      ],
    );
  }

  Widget _buildStudentItem(AppProvider provider, StudentPickup student) {
    Color statusColor;
    IconData statusIcon;
    String statusText;
    
    switch (student.status) {
      case 'picked':
        statusColor = const Color(0xFF4CAF50);
        statusIcon = Icons.check_circle;
        statusText = 'Picked';
        break;
      case 'absent':
        statusColor = const Color(0xFFFF9800);
        statusIcon = Icons.cancel;
        statusText = 'Absent';
        break;
      case 'dropped':
        statusColor = const Color(0xFF2196F3);
        statusIcon = Icons.logout;
        statusText = 'Dropped';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.schedule;
        statusText = 'Pending';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: provider.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withAlpha(50),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Student Avatar
          _buildStudentAvatar(student),
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
                if (student.parentPhone != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Parent: ${student.parentPhone}',
                    style: TextStyle(
                      fontSize: 12,
                      color: provider.textMutedColor,
                    ),
                  ),
                ],
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

  Widget _buildStudentAvatar(StudentPickup student) {
    if (student.photo != null && student.photo!.isNotEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundImage: NetworkImage(student.photo!),
        onBackgroundImageError: (_, __) {},
      );
    }
    
    return CircleAvatar(
      radius: 24,
      backgroundColor: const Color(0xFF6B9B5B).withAlpha(30),
      child: const Icon(Icons.person, color: Color(0xFF6B9B5B)),
    );
  }

  Widget _buildTimelineSection(AppProvider provider, Trip trip) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Trip Timeline',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: provider.textColor,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: provider.cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: trip.stops.map((stop) {
              final index = trip.stops.indexOf(stop);
              final isLast = index == trip.stops.length - 1;
              
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: const Color(0xFF6B9B5B),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: provider.cardColor,
                            width: 2,
                          ),
                        ),
                      ),
                      if (!isLast)
                        Container(
                          width: 2,
                          height: 40,
                          color: const Color(0xFF6B9B5B).withAlpha(50),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stop.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: provider.textColor,
                          ),
                        ),
                        if (stop.address.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            stop.address,
                            style: TextStyle(
                              fontSize: 12,
                              color: provider.textMutedColor,
                            ),
                          ),
                        ],
                        if (!isLast) const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDriverInfoCard(AppProvider provider, TripHistory history) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: provider.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(provider.isDarkMode ? 51 : 13),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trip Information',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: provider.textColor,
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.person, 'Driver', history.driverName),
          if (history.attendantName != null)
            _buildInfoRow(Icons.assistant, 'Attendant', history.attendantName!),
          _buildInfoRow(
            Icons.access_time,
            'Logged At',
            '${_formatDate(history.loggedAt)} ${_formatTime(history.loggedAt)}',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    final provider = context.read<AppProvider>();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: provider.textMutedColor),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 14,
              color: provider.textMutedColor,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: provider.textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
