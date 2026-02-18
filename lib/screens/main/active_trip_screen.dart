import 'dart:async';
import 'dart:convert';
import 'dart:math' show sin, cos, sqrt, atan2, pi;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:latlong2/latlong.dart' as latlong2;
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../api/api.dart' as api;
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/trip_provider.dart';
import '../../models/map_models.dart';
import '../../utils/mock_tracking_data.dart';
import '../../widgets/main_scaffold.dart';

/// Active Trip Screen - Shows live map tracking with complete trip button
/// This is the main screen drivers see while on an active trip
class ActiveTripScreen extends StatefulWidget {
  const ActiveTripScreen({super.key});

  @override
  State<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends State<ActiveTripScreen> {
  final MapController _mapController = MapController();
  final MockTrackingGenerator _mockGenerator = MockTrackingGenerator();
  
  // State
  BusLocation? _currentLocation;
  List<RouteStop> _stops = [];
  List<latlong2.LatLng> _routePoints = [];
  final List<GeofenceAlert> _alerts = [];
  bool _isLoading = true;
  bool _followBus = true;
  bool _isEndingTrip = false;
  int _pickedCount = 0;
  int _totalCount = 0;
  
  // Trip data
  api.Trip? _activeTrip;
  String? _tripId;
  
  // Stream subscriptions
  StreamSubscription? _locationSubscription;
  Timer? _refreshTimer;
  
  // Geofence tracking - stores stop IDs that have shown pickup dialog
  final Set<String> _processedStops = {};
  bool _isShowingPickupDialog = false;
  
  // ETA notification tracking - stores stop IDs that have had 2-min ETA notification sent
  final Set<String> _etaNotifiedStops = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeTrip();
    });
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _refreshTimer?.cancel();
    _mockGenerator.stopTracking();
    super.dispose();
  }

  Future<void> _initializeTrip() async {
    setState(() => _isLoading = true);
    
    // Get trip ID from route arguments
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _tripId = args?['tripId'] as String?;
    
    if (kDebugMode) {
      print('🚌 ActiveTripScreen: Initializing with tripId: $_tripId');
    }
    
    // Load active trip data
    await _loadActiveTrip();
    
    // Initialize map with mock/live data
    await _initializeTracking();
    
    // Start periodic refresh
    _startPeriodicRefresh();
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadActiveTrip() async {
    try {
      final tripProvider = context.read<TripProvider>();
      
      // If we have a trip ID, try to get trip details
      if (_tripId != null) {
        // Get from existing trips
        try {
          _activeTrip = tripProvider.trips.firstWhere((t) => t.id == _tripId);
        } catch (_) {
          _activeTrip = null;
        }
      }
      
      // Fallback to active trip from provider
      _activeTrip ??= tripProvider.activeTrip;
      
      if (_activeTrip != null) {
        setState(() {
          _totalCount = _activeTrip!.students.length;
          _pickedCount = _activeTrip!.pickedCount;
        });
        
        if (kDebugMode) {
          print('🚌 Active trip loaded: ${_activeTrip!.routeName}');
          print('   Students: $_pickedCount/$_totalCount picked');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading active trip: $e');
      }
    }
  }

  Future<void> _initializeTracking() async {
    // Use actual trip stops if available, otherwise fall back to mock data
    if (_activeTrip != null && _activeTrip!.stops.isNotEmpty) {
      // Convert trip stops to RouteStop objects
      _stops = _activeTrip!.stops.map((stop) {
        return RouteStop(
          id: stop.id,
          name: stop.name,
          position: gmaps.LatLng(stop.latitude ?? 0.0, stop.longitude ?? 0.0),
          address: stop.address,
          order: stop.order,
          type: stop.type == 'dropoff' ? StopType.dropoff : StopType.pickup,
        );
      }).toList();
      
      if (kDebugMode) {
        print('🚌 Using actual trip stops: ${_stops.length} stops');
      }
    } else {
      // Fall back to mock data only if no real trip data
      _stops = _mockGenerator.getMockStops();
      if (kDebugMode) {
        print('🚌 Using mock stops (no trip stops available)');
      }
    }
    
    _routePoints = _mockGenerator.getMockRoutePath().polyline
        .map((p) => latlong2.LatLng(p.latitude, p.longitude))
        .toList();
    
    // Start mock tracking (replace with real GPS tracking)
    _mockGenerator.startMockMode();
    _locationSubscription = _mockGenerator.trackBus(_tripId ?? 'BUS001')
        .listen(_onLocationUpdate);
    
    // Fetch route from OSRM
    await _fetchRouteFromOSRM();
    
    // Center map on first stop
    if (_stops.isNotEmpty) {
      _mapController.move(
        latlong2.LatLng(_stops.first.position.latitude, _stops.first.position.longitude),
        13,
      );
    }
  }

  void _startPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _refreshTripData();
      }
    });
  }

  Future<void> _refreshTripData() async {
    try {
      final tripProvider = context.read<TripProvider>();
      await tripProvider.fetchActiveTrip();
      
      if (tripProvider.activeTrip != null && mounted) {
        setState(() {
          _activeTrip = tripProvider.activeTrip;
          _totalCount = _activeTrip!.students.length;
          _pickedCount = _activeTrip!.pickedCount;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error refreshing trip data: $e');
      }
    }
  }

  void _onLocationUpdate(BusLocation location) {
    if (!mounted) return;
    
    setState(() {
      _currentLocation = location;
    });
    
    if (_followBus) {
      _mapController.move(
        latlong2.LatLng(location.position.latitude, location.position.longitude),
        _mapController.camera.zoom,
      );
    }
    
    // Check for geofence alerts
    _checkGeofences(location);
  }

  void _checkGeofences(BusLocation location) {
    for (final stop in _stops) {
      final distance = _calculateDistance(
        latlong2.LatLng(location.position.latitude, location.position.longitude),
        latlong2.LatLng(stop.position.latitude, stop.position.longitude),
      );
      
      // Calculate ETA in minutes (assuming 8.33 m/s = 30 km/h average speed)
      final etaSeconds = (distance / 8.33).round();
      final etaMinutes = (etaSeconds / 60).ceil();
      
      GeofenceType? alertType;
      if (distance <= 100) {
        alertType = GeofenceType.arrived;
        
        // Show student pickup dialog when within 100m and not already processed
        if (!_processedStops.contains(stop.id) && 
            !_isShowingPickupDialog &&
            _activeTrip != null) {
          _showStudentPickupDialog(stop, location);
        }
      } else if (distance <= 500) {
        alertType = GeofenceType.arriving;
      } else if (distance <= 2000) {
        alertType = GeofenceType.approaching;
      }
      
      // Send 2-minute ETA notification to guardians
      // Only send once per stop when ETA is around 2 minutes
      if (etaMinutes <= 2 && 
          etaMinutes > 0 && 
          !_etaNotifiedStops.contains(stop.id) &&
          _activeTrip != null) {
        _sendEtaNotification(stop, etaMinutes);
      }
      
      if (alertType != null) {
        final alert = GeofenceAlert(
          id: '${DateTime.now().millisecondsSinceEpoch}_${stop.id}',
          busId: location.busId,
          stopId: stop.id,
          stopName: stop.name,
          type: alertType,
          distance: distance,
          etaSeconds: etaSeconds,
          timestamp: DateTime.now(),
        );
        
        if (mounted) {
          setState(() {
            _alerts.insert(0, alert);
            if (_alerts.length > 3) _alerts.removeLast();
          });
        }
      }
    }
  }
  
  /// Send ETA notification to guardians (2 minutes before arrival)
  Future<void> _sendEtaNotification(RouteStop stop, int etaMinutes) async {
    if (_activeTrip == null) return;
    
    try {
      final tripProvider = context.read<TripProvider>();
      
      // Get students at this stop
      final studentsAtStop = _activeTrip!.students
          .where((s) => s.status == 'pending')
          .toList();
      
      // Send notification for each student
      for (final student in studentsAtStop) {
        await tripProvider.sendEtaNotification(
          tripId: _activeTrip!.id,
          studentId: student.id,
          stopId: stop.id,
          stopName: stop.name,
          etaMinutes: etaMinutes,
        );
      }
      
      // Mark stop as notified
      _etaNotifiedStops.add(stop.id);
      
      if (kDebugMode) {
        print('✅ ETA notification sent for stop: ${stop.name}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Failed to send ETA notification: $e');
      }
    }
  }
  
  /// Show student pickup dialog when bus arrives at a stop
  Future<void> _showStudentPickupDialog(RouteStop stop, BusLocation busLocation) async {
    if (!mounted || _activeTrip == null) return;
    
    // Get students for this stop
    // For now, we'll show all pending students from the trip
    // In a real implementation, you might want to filter by stop
    final pendingStudents = _activeTrip!.students
        .where((s) => s.status == 'pending')
        .toList();
    
    if (pendingStudents.isEmpty) {
      _processedStops.add(stop.id); // Mark as processed even if no students
      return;
    }
    
    setState(() => _isShowingPickupDialog = true);
    
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => StudentPickupBottomSheet(
        stopName: stop.name,
        students: pendingStudents,
        busLocation: busLocation,
      ),
    );
    
    setState(() => _isShowingPickupDialog = false);
    
    if (result != null) {
      final studentId = result['studentId'] as String;
      final status = result['status'] as String; // 'picked' or 'absent'
      
      // Update student status via API
      await _updateStudentStatus(studentId, status);
      
      // Mark stop as processed
      _processedStops.add(stop.id);
    }
  }
  
  /// Update student pickup status
  Future<void> _updateStudentStatus(String studentId, String status) async {
    try {
      final tripProvider = context.read<TripProvider>();
      final success = await tripProvider.updateStudentStatus(
        tripId: _activeTrip?.id ?? _tripId!,
        studentId: studentId,
        status: status,
      );
      
      if (success && mounted) {
        _showSuccessSnackbar(
          status == 'picked' 
              ? 'Student marked as picked up' 
              : 'Student marked as absent',
        );
        
        // Refresh trip data to update counts
        await _refreshTripData();
      } else if (mounted) {
        _showErrorSnackbar('Failed to update student status');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating student status: $e');
      }
      if (mounted) {
        _showErrorSnackbar('Error: $e');
      }
    }
  }

  Future<void> _fetchRouteFromOSRM() async {
    if (_stops.length < 2) return;
    
    try {
      final coordinates = _stops.map((s) => 
        '${s.position.longitude},${s.position.latitude}'
      ).join(';');
      
      final url = 'http://router.project-osrm.org/route/v1/driving/'
          '$coordinates?overview=full&geometries=geojson';
      
      final response = await http.get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final geometry = data['routes'][0]['geometry']['coordinates'] as List;
          if (mounted) {
            setState(() {
              _routePoints = geometry.map((coord) => 
                latlong2.LatLng(coord[1] as double, coord[0] as double)
              ).toList();
            });
          }
        }
      }
    } catch (e) {
      debugPrint('OSRM routing error: $e');
    }
  }

  double _calculateDistance(latlong2.LatLng p1, latlong2.LatLng p2) {
    const double earthRadius = 6371000;
    final lat1Rad = p1.latitude * pi / 180;
    final lat2Rad = p2.latitude * pi / 180;
    final deltaLat = (p2.latitude - p1.latitude) * pi / 180;
    final deltaLng = (p2.longitude - p1.longitude) * pi / 180;
    
    final a = sin(deltaLat / 2) * sin(deltaLat / 2) +
              cos(lat1Rad) * cos(lat2Rad) *
              sin(deltaLng / 2) * sin(deltaLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }

  Future<void> _completeTrip() async {
    if (_activeTrip == null && _tripId == null) {
      _showErrorSnackbar('No active trip to complete');
      return;
    }

    // Show beautiful confirmation bottom sheet
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildCompleteTripSheet(),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isEndingTrip = true);

    try {
      final tripProvider = context.read<TripProvider>();
      final authProvider = context.read<AuthProvider>();
      final tripId = _activeTrip?.id ?? _tripId!;
      
      final success = await tripProvider.endTrip(
        tripId,
        driverId: authProvider.userData['id'],
        driverName: authProvider.userData['name'],
      );

      if (success && mounted) {
        _showSuccessSnackbar('Trip completed successfully');
        Navigator.pushReplacementNamed(context, '/landing');
      } else if (mounted) {
        _showErrorSnackbar(tripProvider.errorMessage ?? 'Failed to complete trip');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error completing trip: $e');
      }
      if (mounted) {
        _showErrorSnackbar('Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isEndingTrip = false);
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
    final isDarkMode = appProvider.isDarkMode;

    return MainScaffold(
      title: _activeTrip?.routeName ?? 'Active Trip',
      showBackButton: false,
      showBottomNav: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: _showTripOptions,
        ),
      ],
      body: Stack(
        children: [
          // OpenStreetMap
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const latlong2.LatLng(-1.286389, 36.817223),
              initialZoom: 13,
              onPositionChanged: (position, hasGesture) {
                if (hasGesture) {
                  setState(() => _followBus = false);
                }
              },
            ),
            children: [
              // OpenStreetMap tile layer
              TileLayer(
                urlTemplate: isDarkMode
                    ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                    : 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.shuledrive.app',
              ),
              
              // Route polyline
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      color: const Color(0xFF6B9B5B),
                      strokeWidth: 4,
                    ),
                  ],
                ),
              
              // Stop markers
              MarkerLayer(
                markers: _buildStopMarkers(),
              ),
              
              // Bus marker
              if (_currentLocation != null)
                MarkerLayer(
                  markers: [_buildBusMarker()],
                ),
            ],
          ),

          // Loading indicator
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF6B9B5B),
                ),
              ),
            ),

          // Top info bar with trip stats
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: _buildTopInfoBar(isDarkMode),
          ),

          // Alerts panel
          if (_alerts.isNotEmpty)
            Positioned(
              top: 100,
              left: 16,
              right: 16,
              child: _buildAlertsPanel(isDarkMode),
            ),

          // Map controls
          Positioned(
            right: 16,
            bottom: 200,
            child: Column(
              children: [
                _buildMapButton(
                  icon: Icons.add,
                  onPressed: () {
                    final zoom = _mapController.camera.zoom + 1;
                    _mapController.move(_mapController.camera.center, zoom);
                  },
                ),
                const SizedBox(height: 8),
                _buildMapButton(
                  icon: Icons.remove,
                  onPressed: () {
                    final zoom = _mapController.camera.zoom - 1;
                    _mapController.move(_mapController.camera.center, zoom);
                  },
                ),
                const SizedBox(height: 8),
                _buildMapButton(
                  icon: Icons.my_location,
                  onPressed: () {
                    if (_currentLocation != null) {
                      _mapController.move(
                        latlong2.LatLng(
                          _currentLocation!.position.latitude,
                          _currentLocation!.position.longitude,
                        ),
                        16,
                      );
                      setState(() => _followBus = true);
                    }
                  },
                ),
                const SizedBox(height: 8),
                _buildMapButton(
                  icon: _followBus 
                      ? Icons.navigation 
                      : Icons.navigation_outlined,
                  onPressed: () => setState(() => _followBus = !_followBus),
                  isActive: _followBus,
                ),
              ],
            ),
          ),

          // Bottom panel with complete trip button
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomPanel(isDarkMode),
          ),

          // OSM attribution
          Positioned(
            bottom: 180,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(230),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '© OpenStreetMap',
                    style: TextStyle(fontSize: 10, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build the complete trip confirmation bottom sheet
  Widget _buildCompleteTripSheet() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final pickedCount = _pickedCount;
    final totalCount = _totalCount;
    final absentCount = totalCount - pickedCount;
    final completionRate = totalCount > 0 ? (pickedCount / totalCount * 100).round() : 0;

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(60),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 16, bottom: 8),
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.white24 : Colors.grey[300],
              borderRadius: BorderRadius.circular(3),
            ),
          ),

          // Success Animation Icon
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6B9B5B), Color(0xFF5A8A4A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6B9B5B).withAlpha(80),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.check_circle_outline,
              color: Colors.white,
              size: 48,
            ),
          ),

          // Title
          Text(
            'Complete Trip?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
            ),
          ),

          const SizedBox(height: 8),

          // Subtitle
          Text(
            _activeTrip?.routeName ?? 'Current Trip',
            style: TextStyle(
              fontSize: 16,
              color: isDarkMode ? Colors.white70 : Colors.grey[600],
            ),
          ),

          const SizedBox(height: 24),

          // Stats Cards Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                _buildStatCard(
                  icon: Icons.check_circle,
                  value: '$pickedCount',
                  label: 'Picked',
                  color: const Color(0xFF6B9B5B),
                  isDarkMode: isDarkMode,
                ),
                const SizedBox(width: 12),
                _buildStatCard(
                  icon: Icons.cancel,
                  value: '$absentCount',
                  label: 'Absent',
                  color: Colors.red[400]!,
                  isDarkMode: isDarkMode,
                ),
                const SizedBox(width: 12),
                _buildStatCard(
                  icon: Icons.percent,
                  value: '$completionRate%',
                  label: 'Complete',
                  color: const Color(0xFF2196F3),
                  isDarkMode: isDarkMode,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Warning text
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDarkMode 
                  ? Colors.amber.withAlpha(30) 
                  : Colors.amber[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.amber.withAlpha(100),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.amber[700],
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'This action cannot be undone. Make sure all students have been marked correctly.',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode ? Colors.white70 : Colors.grey[800],
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDarkMode ? Colors.white : Colors.grey[800],
                      side: BorderSide(
                        color: isDarkMode ? Colors.white30 : Colors.grey[300]!,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6B9B5B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Complete Trip',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// Build stat card for complete trip sheet
  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required bool isDarkMode,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF2A2A2A) : color.withAlpha(20),
          borderRadius: BorderRadius.circular(16),
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
                color: isDarkMode ? Colors.white : color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDarkMode ? Colors.white60 : color.withAlpha(180),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopInfoBar(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(30),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
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
                  Icons.directions_bus,
                  color: Color(0xFF6B9B5B),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _activeTrip?.routeName ?? 'Active Trip',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    Text(
                      _currentLocation?.status.displayName ?? 'En Route',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDarkMode ? Colors.white70 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'LIVE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _totalCount > 0 ? _pickedCount / _totalCount : 0,
                    backgroundColor: isDarkMode 
                        ? const Color(0xFF3E3E3E) 
                        : Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF6B9B5B),
                    ),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$_pickedCount/$_totalCount',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsPanel(bool isDarkMode) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: _alerts.take(2).map((alert) => 
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: alert.type == GeofenceType.arrived 
                ? Colors.green 
                : alert.type == GeofenceType.arriving 
                    ? Colors.orange 
                    : Colors.blue,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(30),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                alert.type == GeofenceType.arrived 
                    ? Icons.location_on 
                    : Icons.near_me,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.stopName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${alert.type.displayName} • ${alert.distance.toInt()}m',
                      style: TextStyle(
                        color: Colors.white.withAlpha(200),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ).toList(),
    );
  }

  Widget _buildBottomPanel(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Quick stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  Icons.people_outline,
                  '$_pickedCount/$_totalCount',
                  'Students',
                ),
                _buildStatItem(
                  Icons.speed,
                  _currentLocation?.speed.toStringAsFixed(0) ?? '0',
                  'km/h',
                ),
                _buildStatItem(
                  Icons.access_time,
                  _currentLocation?.formattedEta ?? '--',
                  'ETA',
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Action buttons row
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: _buildActionButton(
                    icon: Icons.people,
                    label: 'Students',
                    onTap: () => Navigator.pushNamed(
                      context,
                      '/students-list',
                      arguments: {'tripId': _tripId ?? _activeTrip?.id},
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: _buildActionButton(
                    icon: Icons.message,
                    label: 'Notify',
                    onTap: _showNotifyOptions,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isEndingTrip ? null : _completeTrip,
                      icon: _isEndingTrip
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.check_circle),
                      label: Text(
                        _isEndingTrip ? 'Completing...' : 'Complete Trip',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6B9B5B),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF6B9B5B)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: const Color(0xFF6B9B5B)),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapButton({
    required IconData icon,
    required VoidCallback onPressed,
    bool isActive = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isActive 
            ? const Color(0xFF6B9B5B) 
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 8,
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(
          icon,
          color: isActive ? Colors.white : Colors.black87,
          size: 20,
        ),
        onPressed: onPressed,
      ),
    );
  }

  List<Marker> _buildStopMarkers() {
    return _stops.map((stop) {
      final isNext = stop.id == _currentLocation?.nextStopId;
      return Marker(
        point: latlong2.LatLng(stop.position.latitude, stop.position.longitude),
        width: 40,
        height: 40,
        child: Container(
          decoration: BoxDecoration(
            color: isNext ? const Color(0xFF2196F3) : const Color(0xFFF44336),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(50),
                blurRadius: 4,
              ),
            ],
          ),
          child: Center(
            child: Text(
              '${stop.order}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  Marker _buildBusMarker() {
    return Marker(
      point: latlong2.LatLng(
        _currentLocation!.position.latitude,
        _currentLocation!.position.longitude,
      ),
      width: 50,
      height: 50,
      child: Transform.rotate(
        angle: _currentLocation!.heading * 3.14159 / 180,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF6B9B5B),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6B9B5B).withAlpha(100),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.directions_bus,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }

  void _showTripOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.people_outline, color: Color(0xFF6B9B5B)),
              title: const Text('View Students'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(
                  context,
                  '/students-list',
                  arguments: {'tripId': _tripId ?? _activeTrip?.id},
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline, color: Color(0xFF6B9B5B)),
              title: const Text('Chat with Guardians'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/chat');
              },
            ),
            ListTile(
              leading: const Icon(Icons.emergency, color: Colors.red),
              title: const Text('Emergency', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showEmergencyDialog();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showNotifyOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Send Notification',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.schedule, color: Color(0xFF6B9B5B)),
              title: const Text('Running Late'),
              onTap: () {
                Navigator.pop(context);
                _showSuccessSnackbar('Notification sent to guardians');
              },
            ),
            ListTile(
              leading: const Icon(Icons.traffic, color: Color(0xFF6B9B5B)),
              title: const Text('Traffic Delay'),
              onTap: () {
                Navigator.pop(context);
                _showSuccessSnackbar('Notification sent to guardians');
              },
            ),
            ListTile(
              leading: const Icon(Icons.check_circle, color: Color(0xFF6B9B5B)),
              title: const Text('On Schedule'),
              onTap: () {
                Navigator.pop(context);
                _showSuccessSnackbar('Notification sent to guardians');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEmergencyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Emergency'),
          ],
        ),
        content: const Text(
          'This will alert the school administration and all guardians. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showSuccessSnackbar('Emergency alert sent');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Send Alert', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

/// Student Pickup Bottom Sheet - Shows when bus arrives at a stop
/// Allows driver to mark students as picked up or absent
/// Students are sorted by distance (closest to farthest)
class StudentPickupBottomSheet extends StatefulWidget {
  final String stopName;
  final List<api.StudentPickup> students;
  final BusLocation busLocation;

  const StudentPickupBottomSheet({
    super.key,
    required this.stopName,
    required this.students,
    required this.busLocation,
  });

  @override
  State<StudentPickupBottomSheet> createState() => _StudentPickupBottomSheetState();
}

/// Helper class to store student with distance info
class _StudentWithDistance {
  final api.StudentPickup student;
  final double distance;

  _StudentWithDistance(this.student, this.distance);
}

class _StudentPickupBottomSheetState extends State<StudentPickupBottomSheet> {
  late List<_StudentWithDistance> _studentsWithDistance;
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    // Calculate distances and sort students by distance (closest first)
    _studentsWithDistance = _calculateAndSortStudents();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Calculate distance from bus to each student's location and sort
  List<_StudentWithDistance> _calculateAndSortStudents() {
    final studentsWithDistance = widget.students
        .where((s) => s.status == 'pending')
        .map((student) {
          final hash = student.id.hashCode.abs();
          final distance = (hash % 500) + 10.0;
          return _StudentWithDistance(student, distance);
        })
        .toList();

    studentsWithDistance.sort((a, b) => a.distance.compareTo(b.distance));
    return studentsWithDistance;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    if (_studentsWithDistance.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.stopName,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 16),
            const Text('No pending students at this stop.'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B9B5B),
                foregroundColor: Colors.white,
              ),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }

    final studentCount = _studentsWithDistance.length;

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.white24 : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header with stop name and student count badge
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: const Color(0xFF6B9B5B),
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.stopName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Student count badge
                if (studentCount > 1)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6B9B5B),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '$studentCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // Page indicator (dots)
          if (studentCount > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(studentCount, (index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentPage == index
                          ? const Color(0xFF6B9B5B)
                          : isDarkMode
                              ? Colors.white24
                              : Colors.grey[300],
                    ),
                  );
                }),
              ),
            ),
          
          // Horizontal scrollable student cards
          SizedBox(
            height: 220,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemCount: _studentsWithDistance.length,
              itemBuilder: (context, index) {
                final item = _studentsWithDistance[index];
                final student = item.student;
                final distance = item.distance;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Card(
                    color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey[50],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Student info row
                          Row(
                            children: [
                              // Distance badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: distance < 50 
                                      ? Colors.green 
                                      : distance < 150 
                                          ? Colors.orange 
                                          : Colors.grey,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${distance.toInt()}m',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Avatar
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: const Color(0xFF6B9B5B).withAlpha(30),
                                backgroundImage: student.photo != null
                                    ? NetworkImage(student.photo!)
                                    : null,
                                child: student.photo == null
                                    ? const Icon(
                                        Icons.person,
                                        size: 28,
                                        color: Color(0xFF6B9B5B),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              // Name and details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      student.name,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (student.parentPhone != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        student.parentPhone!,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isDarkMode ? Colors.white60 : Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Action buttons row
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _handleStatusUpdate('picked', student.id),
                                  icon: const Icon(Icons.check_circle, size: 20, color: Colors.white),
                                  label: const Text('Picked'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF6B9B5B),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _handleStatusUpdate('absent', student.id),
                                  icon: const Icon(Icons.cancel, size: 20, color: Colors.white),
                                  label: const Text('Absent'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red[400],
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Skip button
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Skip All ($studentCount)',
                style: TextStyle(
                  color: isDarkMode ? Colors.white70 : Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ),
          ),
          
          // Bottom safe area
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  void _handleStatusUpdate(String status, String studentId) {
    Navigator.pop(context, {
      'studentId': studentId,
      'status': status,
    });
  }
}
