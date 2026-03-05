import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../api/services/trip_service.dart';
import '../../models/master_trip.dart';
import '../../models/preloaded_trip_data.dart';
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/main_scaffold.dart';

/// Trip Selection Screen
/// Displays available master trips for the driver to select from
class TripSelectionScreen extends StatefulWidget {
  const TripSelectionScreen({super.key});

  @override
  State<TripSelectionScreen> createState() => _TripSelectionScreenState();
}

class _TripSelectionScreenState extends State<TripSelectionScreen>
    with SingleTickerProviderStateMixin {
  final TripService _tripService = TripService();

  bool _isLoading = true;
  String? _error;
  List<MasterTrip> _masterTrips = [];
  MasterTrip? _selectedTrip;

  // Pre-loaded trip data for instant navigation
  PreloadedTripData? _preloadedData;
  bool _isPreloading = false;

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _loadMasterTrips();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadMasterTrips() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final driverId = authProvider.currentUser?.id;
      if (driverId == null || driverId.isEmpty) {
        setState(() {
          _error = 'Driver ID not found. Please log in again.';
          _isLoading = false;
        });
        return;
      }

      debugPrint('🚌 TripSelection: Loading trips for driver ID: $driverId');

      // Use cache-first pattern: show cached data immediately, refresh in background
      final trips = await _tripService.getMasterTripsByDriverCached(
        driverId,
        onRefresh: (freshTrips) {
          // Background refresh callback - update UI with fresh data
          if (mounted && freshTrips.isNotEmpty) {
            debugPrint(
              '🔄 TripSelection: Background refresh with ${freshTrips.length} trips',
            );
            setState(() {
              _masterTrips = freshTrips;
            });
            // Show subtle indicator that data was updated
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Trips updated'),
                duration: Duration(seconds: 1),
                behavior: SnackBarBehavior.floating,
                width: 120,
              ),
            );
          }
        },
      );

      debugPrint(
        '🚌 TripSelection: Loaded ${trips.length} trips (from cache or API)',
      );

      if (mounted) {
        setState(() {
          _masterTrips = trips;
          _isLoading = false;
        });
        _animationController.forward();

        // Auto-select and advance if there's only 1 trip
        if (trips.length == 1) {
          _onTripSelected(trips.first);
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ TripSelection: Error loading trips: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _error = 'Failed to load trips. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  void _onTripSelected(MasterTrip trip) {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedTrip = trip;
    });

    // Pre-load trip data in background and auto-advance
    _preloadTripData(trip).then((_) {
      if (mounted) {
        _onContinue();
      }
    });
  }

  /// Pre-load all trip data in background
  Future<void> _preloadTripData(MasterTrip trip) async {
    if (_isPreloading) return;

    setState(() {
      _isPreloading = true;
    });

    try {
      debugPrint('🚀 Pre-loading trip data for: ${trip.tripName}');

      final tripData = await _tripService.fetchCompleteTripData(
        masterTrip: trip,
      );

      if (mounted) {
        setState(() {
          _preloadedData = PreloadedTripData(
            masterTrip: tripData['masterTrip'],
            students: tripData['students'],
            vehicle: tripData['vehicle'],
            routeId: tripData['routeId'],
          );
          _isPreloading = false;
        });

        debugPrint('✅ Trip data pre-loaded:');
        debugPrint('   📊 Students: ${_preloadedData!.students.length}');
        debugPrint(
          '   🚗 Vehicle: ${_preloadedData!.vehicle?.registrationNumber ?? 'Not selected'}',
        );
      }
    } catch (e) {
      debugPrint('⚠️ Failed to pre-load trip data: $e');
      if (mounted) {
        setState(() {
          _isPreloading = false;
          _preloadedData = null;
        });
      }
    }
  }

  void _onContinue() {
    if (_selectedTrip == null) return;

    HapticFeedback.mediumImpact();

    // Navigate to vehicle selection with pre-loaded data (as Map for serialization)
    Navigator.pushNamed(
      context,
      '/vehicle-selection',
      arguments: {
        'masterTrip': _selectedTrip,
        'preloadedData': _preloadedData?.toJson(),
      },
    );
  }

  void _skipToStartTrip() {
    // Skip master trip selection and go directly to start trip
    Navigator.pushReplacementNamed(context, '/start-trip');
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final isDarkMode = appProvider.isDarkMode;

    return MainScaffold(
      title: 'Select Trip',
      showBackButton: false,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(isDarkMode),

            // Content
            Expanded(
              child: _isLoading
                  ? _buildLoadingState(isDarkMode)
                  : _error != null
                  ? _buildErrorState(isDarkMode)
                  : _masterTrips.isEmpty
                  ? _buildEmptyState(isDarkMode)
                  : _buildTripsList(isDarkMode),
            ),

            // Bottom button
            if (!_isLoading && _error == null && _masterTrips.isNotEmpty)
              _buildBottomButton(isDarkMode),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6B9B5B), Color(0xFF5A8A4A)],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6B9B5B).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.calendar_today,
              color: Colors.white,
              size: 36,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Your Scheduled Trips',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select a trip to get started',
            style: TextStyle(
              fontSize: 15,
              color: isDarkMode ? Colors.white60 : const Color(0xFF666666),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(bool isDarkMode) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: 4,
      itemBuilder: (context, index) => _buildSkeletonItem(isDarkMode),
    );
  }

  Widget _buildSkeletonItem(bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFE5E5EA),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isDarkMode
                  ? const Color(0xFF2C2C2C)
                  : const Color(0xFFE5E5EA),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 150,
                  height: 16,
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? const Color(0xFF2C2C2C)
                        : const Color(0xFFE5E5EA),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 100,
                  height: 14,
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? const Color(0xFF2C2C2C)
                        : const Color(0xFFE5E5EA),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(bool isDarkMode) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: isDarkMode ? Colors.white60 : const Color(0xFF666666),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadMasterTrips,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B9B5B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _skipToStartTrip,
              child: const Text('Skip to Start Trip'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.05)
                    : const Color(0xFF6B9B5B).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.calendar_today,
                size: 48,
                color: isDarkMode ? Colors.white30 : const Color(0xFF6B9B5B),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Scheduled Trips',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You don\'t have any master trips assigned. Start a new trip instead.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.white60 : const Color(0xFF666666),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _skipToStartTrip,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Start New Trip'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B9B5B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripsList(bool isDarkMode) {
    return RefreshIndicator(
      onRefresh: _loadMasterTrips,
      color: const Color(0xFF6B9B5B),
      backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _masterTrips.length,
        itemBuilder: (context, index) {
          final trip = _masterTrips[index];
          final isSelected = _selectedTrip?.id == trip.id;

          final isPreloadingThisTrip = isSelected && _isPreloading;

          return AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              final delay = index * 0.1;
              final value =
                  (_animationController.value - delay).clamp(0.0, 1.0) /
                  (1 - delay);

              return Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: Opacity(opacity: value, child: child),
              );
            },
            child: _buildTripCard(
              trip,
              isSelected,
              isPreloadingThisTrip,
              isDarkMode,
            ),
          );
        },
      ),
    );
  }

  Widget _buildTripCard(
    MasterTrip trip,
    bool isSelected,
    bool isPreloading,
    bool isDarkMode,
  ) {
    final dateFormat = DateFormat('EEE, MMM d');

    return GestureDetector(
      onTap: () => _onTripSelected(trip),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF6B9B5B)
                : isDarkMode
                ? const Color(0xFF2C2C2C)
                : const Color(0xFFE5E5EA),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF6B9B5B).withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Selection indicator
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? const Color(0xFF6B9B5B)
                      : isDarkMode
                      ? const Color(0xFF2C2C2C)
                      : const Color(0xFFE5E5EA),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF6B9B5B)
                        : isDarkMode
                        ? const Color(0xFF3A3A3C)
                        : const Color(0xFFD1D1D6),
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? isPreloading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 16,
                            )
                    : null,
              ),
              const SizedBox(width: 16),

              // Trip icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF6B9B5B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.directions_bus,
                  color: Color(0xFF6B9B5B),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),

              // Trip details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.tripName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode
                            ? Colors.white
                            : const Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      trip.route,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode
                            ? Colors.white60
                            : const Color(0xFF666666),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.4)
                              : const Color(0xFF999999),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          trip.tripTime,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDarkMode
                                ? Colors.white60
                                : const Color(0xFF666666),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.4)
                              : const Color(0xFF999999),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          dateFormat.format(trip.createdAt),
                          style: TextStyle(
                            fontSize: 13,
                            color: isDarkMode
                                ? Colors.white60
                                : const Color(0xFF666666),
                          ),
                        ),
                      ],
                    ),
                    if (trip.numberPlate != null &&
                        trip.numberPlate!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.confirmation_number,
                            size: 14,
                            color: isDarkMode
                                ? Colors.white.withOpacity(0.4)
                                : const Color(0xFF999999),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            trip.numberPlate!,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDarkMode
                                  ? Colors.white60
                                  : const Color(0xFF666666),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomButton(bool isDarkMode) {
    final canContinue = _selectedTrip != null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDarkMode
                ? const Color(0xFF2C2C2C)
                : const Color(0xFFE5E5EA),
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: canContinue ? _onContinue : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B9B5B),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: isDarkMode
                      ? const Color(0xFF2C2C2C)
                      : const Color(0xFFE5E5EA),
                  disabledForegroundColor: isDarkMode
                      ? Colors.white30
                      : const Color(0xFF999999),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _skipToStartTrip,
              child: Text(
                'Start a Different Trip',
                style: TextStyle(
                  color: isDarkMode ? Colors.white60 : const Color(0xFF666666),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
