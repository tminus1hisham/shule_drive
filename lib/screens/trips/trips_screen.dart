import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api/api.dart' as api;
import '../../api/services/trip_service.dart';
import '../../providers/app_provider.dart';
import '../../widgets/main_scaffold.dart';

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  int _currentIndex = 3;
  final TripService _tripService = TripService();
  List<api.Trip> _trips = [];
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
      final trips = await _tripService.getTrips();
      if (mounted) {
        setState(() {
          _trips = trips;
          _isLoading = false;
        });
      }
    } on api.NotFoundException catch (e) {
      // Endpoint not found - show empty state instead of error
      if (mounted) {
        setState(() {
          _trips = [];
          _isLoading = false;
        });
      }
    } on api.ApiException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
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

    return MainScaffold(
      title: 'Trip History',
      showBackButton: true,
      showBottomNav: true,
      bottomNavIndex: _currentIndex,
      onBottomNavTap: (index) {
        setState(() => _currentIndex = index);
        if (index == 0) {
          Navigator.pushReplacementNamed(context, '/landing');
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

    // Show empty state
    if (_trips.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 80,
              color: provider.textMutedColor.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No trips yet',
              style: TextStyle(
                fontSize: 20,
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
          ],
        ),
      );
    }

    // Show trips list
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _trips.length,
      itemBuilder: (context, index) {
        final trip = _trips[index];
        return _buildTripCard(context, provider, trip);
      },
    );
  }

  Widget _buildTripCard(BuildContext context, AppProvider provider, api.Trip trip) {
    final isCompleted = trip.isCompleted;
    final statusText = isCompleted ? 'Completed' : 'Active';
    final statusColor = isCompleted
        ? const Color(0xFF6B9B5B)
        : const Color(0xFFFF9800);

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/trip-details'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: provider.cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: provider.isDarkMode ? 0.2 : 0.05),
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
                      fontSize: 15,
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
                    color: statusColor.withValues(alpha: provider.isDarkMode ? 0.2 : 0.1),
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
                _buildStatItem(
                  provider,
                  Icons.people_outline,
                  '${trip.pickedCount}/${trip.students.length} students',
                ),
                if (trip.distance != null)
                  _buildStatItem(
                    provider,
                    Icons.route_outlined,
                    '${trip.distance!.toStringAsFixed(1)} km',
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

  Widget _buildStatItem(AppProvider provider, IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: provider.isDarkMode
              ? const Color(0xFF8BC48B)
              : const Color(0xFF6B9B5B),
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
