import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/trip_history_service.dart';
import '../../widgets/main_scaffold.dart';
import 'guardian_trips_screen.dart';

/// Trips Screen - Shows trip history for DRIVERS
/// Shows ACTIVE trips for GUARDIANS (involving their students)
class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  int _currentIndex = 3;
  final TripHistoryService _historyService = TripHistoryService();
  
  List<TripHistory> _trips = [];
  DriverStats _stats = DriverStats.empty();
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final driverId = authProvider.userData?['id'] ?? '';
      
      if (driverId.isEmpty) {
        setState(() {
          _errorMessage = 'Driver ID not found';
          _isLoading = false;
        });
        return;
      }

      // Load from local storage
      final trips = await _historyService.getTripHistory(driverId);
      final stats = await _historyService.getDriverStats(driverId);

      if (mounted) {
        setState(() {
          _trips = trips;
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load trips';
          _isLoading = false;
        });
      }
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

    // For guardians, show the GuardianTripsScreen (active trips view)
    if (!authProvider.isDriver) {
      return const GuardianTripsScreen();
    }

    return MainScaffold(
      title: 'Trip History',
      showBackButton: true,
      showBottomNav: true,
      bottomNavIndex: _currentIndex,
      onBottomNavTap: (index) {
        setState(() => _currentIndex = index);
        if (index == 0) {
          Navigator.pushReplacementNamed(context, '/dashboard');
        }
      },
      body: RefreshIndicator(
        onRefresh: _loadTrips,
        child: _buildBody(provider),
      ),
    );
  }

  Widget _buildBody(AppProvider provider) {
    // Show loading
    if (_isLoading && _trips.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF6B9B5B),
        ),
      );
    }

    // Show error
    if (_errorMessage != null && _trips.isEmpty) {
      return _buildErrorState(provider);
    }

    return CustomScrollView(
      slivers: [
        // Stats Card
        SliverToBoxAdapter(
          child: _buildStatsCard(provider),
        ),
        
        // Section Title
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Trips',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: provider.textColor,
                  ),
                ),
                if (_trips.isNotEmpty)
                  Text(
                    '${_trips.length} trips',
                    style: TextStyle(
                      fontSize: 14,
                      color: provider.textMutedColor,
                    ),
                  ),
              ],
            ),
          ),
        ),
        
        // Empty State
        if (_trips.isEmpty)
          SliverFillRemaining(
            child: _buildEmptyState(provider),
          )
        else
          // Trips List
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildTripCard(context, provider, _trips[index]),
                childCount: _trips.length,
              ),
            ),
          ),
        
        const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
      ],
    );
  }

  Widget _buildStatsCard(AppProvider provider) {
    return Container(
      margin: const EdgeInsets.all(16),
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
              const Text(
                'Your Stats',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Driver',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildStatItem('Trips', _stats.totalTrips.toString(), Icons.route),
              _buildStatDivider(),
              _buildStatItem('Students', _stats.totalStudents.toString(), Icons.people),
              _buildStatDivider(),
              _buildStatItem(
                'Picked',
                '${_stats.completionRate.toStringAsFixed(0)}%',
                Icons.check_circle,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withAlpha(180),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 50,
      color: Colors.white.withAlpha(30),
    );
  }

  Widget _buildErrorState(AppProvider provider) {
    return Center(
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
            'Error loading trips',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: provider.textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage!,
            style: TextStyle(
              fontSize: 14,
              color: provider.textMutedColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadTrips,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B9B5B),
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppProvider provider) {
    return Center(
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
            'No trips yet',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: provider.textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a new trip to see it here',
            style: TextStyle(
              fontSize: 14,
              color: provider.textMutedColor,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: 200,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/start-trip'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B9B5B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text(
                'Start New Trip',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripCard(BuildContext context, AppProvider provider, TripHistory history) {
    final trip = history.trip;
    final isCompleted = trip.isCompleted;
    final statusText = isCompleted ? 'Completed' : 'Active';
    final statusColor = isCompleted
        ? const Color(0xFF6B9B5B)
        : const Color(0xFFFF9800);

    // Calculate trip duration
    final duration = trip.endTime != null
        ? trip.endTime!.difference(trip.startTime)
        : null;
    final durationText = duration != null
        ? duration.inHours > 0
            ? '${duration.inHours}h ${duration.inMinutes.remainder(60)}m'
            : '${duration.inMinutes}m'
        : '--';

    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        '/trip-details',
        arguments: {'tripId': trip.id, 'history': history},
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    trip.routeName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: provider.textColor,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(provider.isDarkMode ? 51 : 26),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildInfoItem(
                  provider,
                  Icons.calendar_today,
                  'Date: ${_formatDate(trip.startTime)}',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildInfoItem(
                  provider,
                  Icons.access_time,
                  'Time: ${_formatTime(trip.startTime)}',
                ),
              ],
            ),
            // Add trip duration info
            const SizedBox(height: 8),
            Row(
              children: [
                _buildInfoItem(
                  provider,
                  Icons.timer_outlined,
                  'Duration: $durationText',
                ),
              ],
            ),
            if (trip.vehicleNumber != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildInfoItem(
                    provider,
                    Icons.directions_bus,
                    'Vehicle: ${trip.vehicleNumber}',
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Divider(
              height: 1,
              color: provider.isDarkMode
                  ? Colors.grey[700]
                  : Colors.grey[300],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildTripStatItem(
                  provider,
                  Icons.people_outline,
                  '${trip.pickedCount}/${trip.students.length} students',
                ),
                if (history.attendantName != null)
                  _buildTripStatItem(
                    provider,
                    Icons.person_outline,
                    'Att: ${history.attendantName}',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(AppProvider provider, IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: provider.textMutedColor,
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: provider.textMutedColor,
          ),
        ),
      ],
    );
  }

  Widget _buildTripStatItem(AppProvider provider, IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: const Color(0xFF6B9B5B),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: provider.isDarkMode
                ? const Color(0xFF8BC48B)
                : const Color(0xFF6B9B5B),
          ),
        ),
      ],
    );
  }
}
