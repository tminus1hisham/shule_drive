import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import '../../config/map_config.dart';
import '../../services/mapbox_service.dart';
import '../../api/services/trip_service.dart';
import '../../models/master_trip.dart';
import '../../models/preloaded_trip_data.dart';

/// Driver Map Screen - Shows driver their route with all students as pins on the map
/// 
/// Features:
/// - Full screen Mapbox map using native SDK
/// - Student markers with different colors based on status
/// - Route line from driver location through all student pickup points
/// - Driver location marker (green bus icon)
/// - Tap student marker to show bottom sheet with pickup action
/// - Route recalculation after each pickup
class DriverMapScreen extends StatefulWidget {
  final String tripId;
  final Map<String, dynamic>? preloadedData;

  const DriverMapScreen({
    super.key,
    required this.tripId,
    this.preloadedData,
  });

  @override
  State<DriverMapScreen> createState() => _DriverMapScreenState();
}

class _DriverMapScreenState extends State<DriverMapScreen> {
  // Services
  final MapboxService _mapboxService = MapboxService();
  final TripService _tripService = TripService();

  // Mapbox controller
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointAnnotationManager;
  PolylineAnnotationManager? _polylineAnnotationManager;

  // Location tracking
  geo.Position? _currentPosition;
  StreamSubscription<geo.Position>? _positionStream;

  // State
  List<TripStudent> _students = [];
  bool _isLoading = true;
  bool _isLoadingRoute = false;
  String? _errorMessage;
  RouteResult? _currentRoute;
  
  // Track student status updates locally
  final Map<int, String> _studentStatusUpdates = {};
  final Map<int, bool> _studentPickedUpdates = {};
  final Map<int, bool> _studentActiveUpdates = {};

  @override
  void initState() {
    super.initState();
    _initializeMapbox();
    _loadStudentsFromPreloadedData();
    _initializeLocation();
  }

  /// Load students from preloaded data if available
  void _loadStudentsFromPreloadedData() {
    if (widget.preloadedData != null) {
      try {
        final preloaded = PreloadedTripData.fromJson(widget.preloadedData!);
        _students = preloaded.students;
        developer.log('Loaded ${_students.length} students from preloaded data', 
            name: 'DriverMapScreen');
      } catch (e) {
        developer.log('Error parsing preloaded data: $e', name: 'DriverMapScreen');
      }
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _mapboxMap?.dispose();
    super.dispose();
  }

  /// Initialize Mapbox with access token
  void _initializeMapbox() {
    MapboxOptions.setAccessToken(MapConfig.mapboxAccessToken);
  }

  /// Initialize location services and request permissions
  Future<void> _initializeLocation() async {
    try {
      bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _errorMessage = 'Location services are disabled.';
          _isLoading = false;
        });
        return;
      }

      geo.LocationPermission permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
        if (permission == geo.LocationPermission.denied) {
          setState(() {
            _errorMessage = 'Location permissions denied';
            _isLoading = false;
          });
          return;
        }
      }

      if (permission == geo.LocationPermission.deniedForever) {
        setState(() {
          _errorMessage = 'Location permissions permanently denied';
          _isLoading = false;
        });
        return;
      }

      // Get current position
      final position = await geo.Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = position;
        _isLoading = false;
      });

      // Start location stream
      _positionStream = geo.Geolocator.getPositionStream(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen(_onLocationUpdate);

      // Calculate initial route
      _calculateRoute();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error initializing location: $e';
        _isLoading = false;
      });
    }
  }

  void _onLocationUpdate(geo.Position position) {
    setState(() {
      _currentPosition = position;
    });
    _updateDriverMarker();
  }

  /// Called when map is created
  void _onMapCreated(MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;
    
    mapboxMap.annotations.createPointAnnotationManager().then((manager) {
      _pointAnnotationManager = manager;
      _updateMarkers();
    });

    mapboxMap.annotations.createPolylineAnnotationManager().then((manager) {
      _polylineAnnotationManager = manager;
      if (_currentRoute != null) {
        _updateRouteLine();
      }
    });
  }

  /// Calculate route through all pending students
  Future<void> _calculateRoute() async {
    if (_currentPosition == null) return;
    if (_isLoadingRoute) return;

    setState(() => _isLoadingRoute = true);

    try {
      // Build waypoints: driver location + pending students with valid locations
      final waypoints = <Map<String, double>>[
        {
          'lat': _currentPosition!.latitude,
          'lng': _currentPosition!.longitude,
        },
      ];

      // Add pending students with valid locations
      for (final student in _students) {
        if (!student.isStudentPicked && 
            !student.isStudentDropped && 
            student.isStudentActive &&
            (student.latitude != 0 || student.longitude != 0)) {
          waypoints.add({
            'lat': student.latitude,
            'lng': student.longitude,
          });
        }
      }

      if (waypoints.length < 2) {
        setState(() => _isLoadingRoute = false);
        return;
      }

      final result = await _mapboxService.getRoute(waypoints);
      
      if (result.success) {
        setState(() {
          _currentRoute = result;
        });
        _updateRouteLine();
      }
    } catch (e) {
      developer.log('Error calculating route: $e', name: 'DriverMapScreen');
    } finally {
      setState(() => _isLoadingRoute = false);
    }
  }

  /// Update route line on map
  Future<void> _updateRouteLine() async {
    if (_polylineAnnotationManager == null || _currentRoute == null) return;

    await _polylineAnnotationManager!.deleteAll();

    final coordinates = _currentRoute!.coordinates;
    if (coordinates == null || coordinates.isEmpty) return;

    // Create line coordinates
    final lineCoords = coordinates.map((pos) {
      return Position(pos.longitude, pos.latitude);
    }).toList();

    await _polylineAnnotationManager!.create(
      PolylineAnnotationOptions(
        geometry: LineString(coordinates: lineCoords),
        lineColor: 0xFF6B9B5B, // Mapbox expects int color
        lineWidth: MapConfig.routeLineWidth,
      ),
    );
  }

  /// Update all markers on map
  Future<void> _updateMarkers() async {
    if (_pointAnnotationManager == null) return;
    await _pointAnnotationManager!.deleteAll();
    await _updateDriverMarker();
    for (final student in _students) {
      await _addStudentMarker(student);
    }
  }

  /// Update driver marker on map
  Future<void> _updateDriverMarker() async {
    if (_pointAnnotationManager == null || _currentPosition == null) return;

    await _pointAnnotationManager!.create(
      PointAnnotationOptions(
        geometry: Point(
          coordinates: Position(
            _currentPosition!.longitude,
            _currentPosition!.latitude,
          ),
        ),
        textField: '🚌',
        textSize: 24,
      ),
    );
  }

  /// Add student marker to map
  Future<void> _addStudentMarker(TripStudent student) async {
    if (_pointAnnotationManager == null) return;
    if (student.latitude == 0 && student.longitude == 0) return;

    await _pointAnnotationManager!.create(
      PointAnnotationOptions(
        geometry: Point(
          coordinates: Position(student.longitude, student.latitude),
        ),
        textField: _getStatusEmoji(student),
        textSize: 20,
      ),
    );
  }

  /// Get effective status considering local updates
  String _getStudentStatus(TripStudent student) {
    // Check local updates first
    if (_studentStatusUpdates.containsKey(student.studentId)) {
      return _studentStatusUpdates[student.studentId]!;
    }
    // Fall back to original status
    if (student.isStudentDropped) return 'dropped';
    if (student.isStudentPicked) return 'picked';
    if (!student.isStudentActive) return 'absent';
    return 'pending';
  }

  String _getStatusEmoji(TripStudent student) {
    final status = _getStudentStatus(student);
    switch (status) {
      case 'dropped':
        return '🏠';
      case 'picked':
        return '✅';
      case 'absent':
        return '❌';
      default:
        return '👤';
    }
  }

  /// Handle student selection from list
  void _onStudentSelected(TripStudent student) {
    // Move map to student location
    if (_mapboxMap != null && 
        student.latitude != 0 && 
        student.longitude != 0) {
      _mapboxMap!.setCamera(
        CameraOptions(
          center: Point(
            coordinates: Position(student.longitude, student.latitude),
          ),
          zoom: 16,
        ),
      );
    }

    // Show bottom sheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildStudentBottomSheet(student),
    );
  }

  /// Handle pick student action
  Future<void> _pickStudent(TripStudent student) async {
    try {
      HapticFeedback.mediumImpact();

      // If first time (no location), save current location
      if (student.latitude == 0 && student.longitude == 0 && _currentPosition != null) {
        developer.log(
          'Saving location for student ${student.studentId}: '
          '${_currentPosition!.latitude}, ${_currentPosition!.longitude}',
          name: 'DriverMapScreen',
        );
      }

      // Update status via API
      await _tripService.updateStudentStatus(
        tripId: widget.tripId,
        studentId: student.studentId.toString(),
        status: 'picked',
      );

      // Update local state
      setState(() {
        _studentStatusUpdates[student.studentId] = 'picked';
        _studentPickedUpdates[student.studentId] = true;
      });

      // Recalculate route
      _calculateRoute();
      _updateMarkers();

      if (!mounted) return;
      Navigator.pop(context); // Close bottom sheet

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${student.fullname} picked up'),
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Handle mark absent action
  Future<void> _markAbsent(TripStudent student) async {
    try {
      HapticFeedback.mediumImpact();

      await _tripService.updateStudentStatus(
        tripId: widget.tripId,
        studentId: student.studentId.toString(),
        status: 'absent',
      );

      setState(() {
        _studentStatusUpdates[student.studentId] = 'absent';
        _studentActiveUpdates[student.studentId] = false;
      });

      _calculateRoute();
      _updateMarkers();

      if (!mounted) return;
      Navigator.pop(context);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${student.fullname} marked absent'),
          backgroundColor: const Color(0xFF9E9E9E),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip Map'),
        backgroundColor: const Color(0xFF6B9B5B),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _calculateRoute,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Mapbox MapWidget
          MapWidget(
            onMapCreated: _onMapCreated,
            cameraOptions: CameraOptions(
              center: Point(
                coordinates: Position(
                  MapConfig.defaultLongitude,
                  MapConfig.defaultLatitude,
                ),
              ),
              zoom: 12,
            ),
          ),

          // Loading indicator
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFF6B9B5B)),
              ),
            ),

          // Error state
          if (_errorMessage != null)
            Center(
              child: Container(
                margin: const EdgeInsets.all(32),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _initializeLocation,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),

          // Loading route indicator
          if (_isLoadingRoute)
            const Positioned(
              top: 80,
              left: 0,
              right: 0,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF6B9B5B),
                    ),
                  ),
                ),
              ),
            ),

          // Floating action buttons
          Positioned(
            right: 16,
            bottom: 200,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'center',
                  onPressed: () {
                    if (_mapboxMap != null && _currentPosition != null) {
                      _mapboxMap!.setCamera(
                        CameraOptions(
                          center: Point(
                            coordinates: Position(
                              _currentPosition!.longitude,
                              _currentPosition!.latitude,
                            ),
                          ),
                          zoom: 16,
                        ),
                      );
                    }
                  },
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.my_location, color: Color(0xFF6B9B5B)),
                ),
              ],
            ),
          ),

          // Students list at bottom
          if (!_isLoading && _errorMessage == null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildStudentsList(),
            ),
        ],
      ),
    );
  }

  Widget _buildStudentsList() {
    final pendingCount = _students.where((s) {
      final status = _getStudentStatus(s);
      return status == 'pending';
    }).length;
    
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(30),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF6B9B5B).withAlpha(20),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                const Icon(Icons.people, color: Color(0xFF6B9B5B)),
                const SizedBox(width: 8),
                Text(
                  'Students ($pendingCount pending)',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_currentRoute != null)
                  Text(
                    '${_currentRoute!.formattedDuration} • ${_currentRoute!.formattedDistance}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B9B5B),
                    ),
                  ),
              ],
            ),
          ),
          
          // Students list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              scrollDirection: Axis.horizontal,
              itemCount: _students.length,
              itemBuilder: (context, index) {
                final student = _students[index];
                return _buildStudentCard(student);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard(TripStudent student) {
    final status = _getStudentStatus(student);
    final isPending = status == 'pending';
    final hasLocation = student.latitude != 0 || student.longitude != 0;

    Color statusColor;
    String statusText;
    switch (status) {
      case 'dropped':
        statusColor = const Color(0xFF2196F3);
        statusText = 'Dropped';
        break;
      case 'picked':
        statusColor = const Color(0xFF4CAF50);
        statusText = 'Picked';
        break;
      case 'absent':
        statusColor = const Color(0xFF9E9E9E);
        statusText = 'Absent';
        break;
      default:
        statusColor = const Color(0xFFF44336);
        statusText = 'Pending';
    }

    return GestureDetector(
      onTap: () => _onStudentSelected(student),
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isPending ? statusColor.withAlpha(20) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPending ? statusColor : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: statusColor,
                  child: Text(
                    _getStatusEmoji(student),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                const Spacer(),
                if (!hasLocation)
                  const Icon(Icons.location_off, size: 16, color: Colors.orange),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              student.fullname,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  fontSize: 11,
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentBottomSheet(TripStudent student) {
    final status = _getStudentStatus(student);
    final isPending = status == 'pending';
    final hasLocation = student.latitude != 0 || student.longitude != 0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFF6B9B5B).withAlpha(30),
                child: Text(
                  _getStatusEmoji(student),
                  style: const TextStyle(fontSize: 28),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.fullname,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${student.classname} • ${student.schoolname}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (!hasLocation)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'First time pickup! Current location will be saved as pickup point.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          
          const SizedBox(height: 24),
          
          if (isPending) ...[
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () => _pickStudent(student),
                icon: const Icon(Icons.check_circle),
                label: const Text(
                  'Pick Student',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton.icon(
                onPressed: () => _markAbsent(student),
                icon: const Icon(Icons.cancel, color: Colors.grey),
                label: const Text(
                  'Mark Absent',
                  style: TextStyle(fontSize: 16),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey.shade700,
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ] else ...[
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: student.isStudentPicked 
                      ? const Color(0xFF4CAF50).withAlpha(30)
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  student.isStudentDropped 
                      ? 'Student dropped off'
                      : student.isStudentPicked 
                          ? 'Student picked up'
                          : 'Student absent',
                  style: TextStyle(
                    fontSize: 16,
                    color: student.isStudentPicked 
                        ? const Color(0xFF4CAF50)
                        : Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
