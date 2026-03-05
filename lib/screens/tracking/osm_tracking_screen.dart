import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import '../../config/map_config.dart';
import '../../services/mapbox_service.dart';
import '../../api/services/trip_service.dart';
import '../../models/master_trip.dart';

/// Mapbox Tracking Screen - Real-time trip tracking with Mapbox native SDK
///
/// Features:
/// - Full screen Mapbox map using native SDK
/// - Real-time driver location tracking
/// - Student markers with status colors
/// - Route line through all stops
/// - Works for both driver and guardian views
class OsmTrackingScreen extends StatefulWidget {
  final String? tripId;
  final String? busId;
  final String? routeId;

  const OsmTrackingScreen({super.key, this.tripId, this.busId, this.routeId});

  @override
  State<OsmTrackingScreen> createState() => _OsmTrackingScreenState();
}

class _OsmTrackingScreenState extends State<OsmTrackingScreen> {
  // Services
  final MapboxService _mapboxService = MapboxService();
  final TripService _tripService = TripService();

  // Mapbox
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointAnnotationManager;
  PolylineAnnotationManager? _polylineAnnotationManager;

  // Location
  geo.Position? _currentPosition;
  StreamSubscription<geo.Position>? _positionStream;

  // Data
  Trip? _trip;
  List<TripStudent> _students = [];
  RouteResult? _routeResult;

  // State
  bool _isLoading = true;
  bool _isLoadingRoute = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeMapbox();
    _initializeLocation();
    _loadTripData();
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

  /// Called when map is created
  void _onMapCreated(MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;

    mapboxMap.annotations.createPointAnnotationManager().then((manager) {
      _pointAnnotationManager = manager;
      _updateMarkers();
    });

    mapboxMap.annotations.createPolylineAnnotationManager().then((manager) {
      _polylineAnnotationManager = manager;
      if (_routeResult != null) {
        _updateRouteLine();
      }
    });
  }

  Future<void> _initializeLocation() async {
    try {
      bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _errorMessage = 'Location services are disabled.';
        });
        return;
      }

      geo.LocationPermission permission =
          await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
        if (permission == geo.LocationPermission.denied) {
          setState(() {
            _errorMessage = 'Location permissions denied';
          });
          return;
        }
      }

      final position = await geo.Geolocator.getCurrentPosition();
      setState(() => _currentPosition = position);

      _positionStream = geo.Geolocator.getPositionStream(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen(_onLocationUpdate);
    } catch (e) {
      developer.log('Location init error: $e', name: 'TrackingScreen');
    }
  }

  void _onLocationUpdate(geo.Position position) {
    setState(() => _currentPosition = position);
    _updateDriverMarker();
  }

  Future<void> _loadTripData() async {
    if (widget.tripId == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'No trip ID provided';
      });
      return;
    }

    try {
      final trip = await _tripService.getTripDetails(widget.tripId!);
      if (trip != null) {
        setState(() {
          _trip = trip;
          _students = trip.students
              .map(
                (s) => TripStudent(
                  id: int.tryParse(s.id) ?? 0,
                  masterTripId: int.tryParse(widget.tripId!) ?? 0,
                  studentId: int.tryParse(s.id) ?? 0,
                  fullname: s.name,
                  studentRegNumber: '',
                  guardianPhoneNumber: s.parentPhone ?? '',
                  schoolname: '',
                  transportOrg: '',
                  classname: '',
                  route: '',
                  latitude: 0,
                  longitude: 0,
                  pickedLatitude: 0,
                  pickedLongitude: 0,
                  droppedLatitude: 0,
                  droppedLongitude: 0,
                  isStudentPicked: s.status == 'picked',
                  isStudentDropped: s.status == 'dropped',
                  profileImage: s.photo ?? '',
                  address: '',
                  createdBy: '',
                  hasStudentPaid: false,
                  isStudentActive: s.status != 'absent',
                  isStudentDeleted: false,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                ),
              )
              .toList();
          _isLoading = false;
        });
        _calculateRoute();
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Trip not found';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading trip: $e';
      });
    }
  }

  Future<void> _calculateRoute() async {
    if (_currentPosition == null || _students.isEmpty) return;
    if (_isLoadingRoute) return;

    setState(() => _isLoadingRoute = true);

    try {
      final waypoints = <Map<String, double>>[
        {'lat': _currentPosition!.latitude, 'lng': _currentPosition!.longitude},
      ];

      // Add pending students with valid locations
      for (final student in _students) {
        if (!student.isStudentPicked &&
            !student.isStudentDropped &&
            student.isStudentActive &&
            (student.latitude != 0 || student.longitude != 0)) {
          waypoints.add({'lat': student.latitude, 'lng': student.longitude});
        }
      }

      if (waypoints.length >= 2) {
        final result = await _mapboxService.getRoute(waypoints);
        if (result.success) {
          setState(() => _routeResult = result);
          _updateRouteLine();
        }
      }
    } catch (e) {
      developer.log('Route error: $e', name: 'TrackingScreen');
    } finally {
      setState(() => _isLoadingRoute = false);
    }
  }

  /// Update route line on map
  Future<void> _updateRouteLine() async {
    if (_polylineAnnotationManager == null || _routeResult == null) return;

    await _polylineAnnotationManager!.deleteAll();

    final coordinates = _routeResult!.coordinates;
    if (coordinates == null || coordinates.isEmpty) return;

    // Create line coordinates
    final lineCoords = coordinates.map((pos) {
      return Position(pos.longitude, pos.latitude);
    }).toList();

    await _polylineAnnotationManager!.create(
      PolylineAnnotationOptions(
        geometry: LineString(coordinates: lineCoords),
        lineColor: 0xFF6B9B5B, // Mapbox expects int color
        lineWidth: 4.0,
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

    String emoji;
    if (student.isStudentDropped) {
      emoji = '🏠';
    } else if (student.isStudentPicked) {
      emoji = '✅';
    } else if (!student.isStudentActive) {
      emoji = '❌';
    } else {
      emoji = '👤';
    }

    await _pointAnnotationManager!.create(
      PointAnnotationOptions(
        geometry: Point(
          coordinates: Position(student.longitude, student.latitude),
        ),
        textField: emoji,
        textSize: 20,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_trip?.routeName ?? 'Live Tracking'),
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
              zoom: 13,
            ),
          ),

          // Loading
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFF6B9B5B)),
              ),
            ),

          // Error
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
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(_errorMessage!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadTripData,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),

          // Loading route
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

          // Map controls
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
                  child: const Icon(
                    Icons.my_location,
                    color: Color(0xFF6B9B5B),
                  ),
                ),
              ],
            ),
          ),

          // Info panel
          if (!_isLoading && _errorMessage == null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _buildInfoPanel(),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 20),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Driver/Bus info
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF6B9B5B).withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('🚌', style: TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _trip?.vehicleNumber ?? 'Bus ${_trip?.vehicleId ?? ''}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_currentPosition != null)
                      Text(
                        '${_currentPosition!.speed.toStringAsFixed(0)} km/h',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'LIVE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Divider(height: 24),

          // Students summary
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStat(
                icon: Icons.people,
                value: '${_students.length}',
                label: 'Students',
              ),
              _buildStat(
                icon: Icons.check_circle,
                value: '${_students.where((s) => s.isStudentPicked).length}',
                label: 'Picked',
              ),
              if (_routeResult != null)
                _buildStat(
                  icon: Icons.access_time,
                  value: _routeResult!.formattedDuration,
                  label: 'ETA',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF6B9B5B)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}
