import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../config/map_config.dart';
import '../../services/mapbox_service.dart';
import '../../api/services/trip_service.dart';
import '../../api/services/student_service.dart';

import '../../theme/app_colors.dart';
/// Guardian Map Screen - Shows driver location, child status, and trip progress
///
/// Features:
/// - Full screen Mapbox map (native SDK)
/// - Real-time driver location with bus marker
/// - Child's pickup/dropoff location marker
/// - Route display from driver to child's location
/// - Status information: Waiting, Picked up, Dropped off
/// - Driver ETA and trip duration
class GuardianMapScreen extends StatefulWidget {
  final String tripId;
  final String studentId;
  final String driverId;

  const GuardianMapScreen({
    super.key,
    required this.tripId,
    required this.studentId,
    required this.driverId,
  });

  @override
  State<GuardianMapScreen> createState() => _GuardianMapScreenState();
}

class _GuardianMapScreenState extends State<GuardianMapScreen> {
  final MapboxService _mapboxService = MapboxService();
  final TripService _tripService = TripService();
  final StudentService _studentService = StudentService();

  // Mapbox
  PointAnnotationManager? _pointAnnotationManager;
  PolylineAnnotationManager? _polylineAnnotationManager;
  PointAnnotation? _driverAnnotation;
  PointAnnotation? _studentAnnotation;
  PolylineAnnotation? _routeAnnotation;

  Timer? _locationPollTimer;
  static const Duration _pollInterval = Duration(seconds: 10);

  // Data
  _DriverLocation? _driverLocation;
  Student? _student;
  Trip? _trip;
  RouteResult? _routeResult;

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    MapboxOptions.setAccessToken(MapConfig.mapboxAccessToken);
    _loadInitialData();
    _startLocationPolling();
  }

  @override
  void dispose() {
    _locationPollTimer?.cancel();
    _driverAnnotation = null;
    _studentAnnotation = null;
    _routeAnnotation = null;
    _pointAnnotationManager = null;
    _polylineAnnotationManager = null;
    // MapWidget owns the MapboxMap and disposes it with its platform view.
    super.dispose();
  }

  void _startLocationPolling() {
    _locationPollTimer = Timer.periodic(_pollInterval, (_) {
      _fetchDriverLocation();
    });
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);

    try {
      final trip = await _tripService.getTripDetails(widget.tripId);
      if (trip != null) {
        setState(() => _trip = trip);
      }

      final student = await _studentService.getStudentById(widget.studentId);
      if (student != null) {
        setState(() => _student = student);
      }

      await _fetchDriverLocation();

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading data: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchDriverLocation() async {
    try {
      await _simulateDriverLocation();
    } catch (e) {
      debugPrint('Error fetching driver location: $e');
    }
  }

  /// Simulate driver location (replace with real API)
  Future<void> _simulateDriverLocation() async {
    double studentLat = MapConfig.defaultLatitude;
    double studentLng = MapConfig.defaultLongitude;

    if (_student != null && _student!.hasValidLocation()) {
      studentLat = _student!.latitude;
      studentLng = _student!.longitude;
    }

    final now = DateTime.now();
    final random = now.millisecond / 1000;

    final driverLat = studentLat + (random - 0.5) * 0.01;
    final driverLng = studentLng + (random - 0.5) * 0.01;

    setState(() {
      _driverLocation = _DriverLocation(
        latitude: driverLat,
        longitude: driverLng,
        heading: random * 360,
        speed: 20 + random * 15,
        timestamp: now,
      );
    });

    await _calculateRoute();
  }

  Future<void> _calculateRoute() async {
    if (_driverLocation == null) return;
    if (_student == null || !_student!.hasValidLocation()) return;

    final result = await _mapboxService.getRoute([
      {'lat': _driverLocation!.latitude, 'lng': _driverLocation!.longitude},
      {'lat': _student!.latitude, 'lng': _student!.longitude},
    ]);

    if (result.success) {
      setState(() => _routeResult = result);
      _updateMapAnnotations();
    }
  }

  void _onMapCreated(MapboxMap mapboxMap) async {
    _pointAnnotationManager = await mapboxMap.annotations
        .createPointAnnotationManager();
    _polylineAnnotationManager = await mapboxMap.annotations
        .createPolylineAnnotationManager();
    _updateMapAnnotations();
  }

  void _updateMapAnnotations() {
    _updateMarkers();
    _updateRouteLine();
  }

  Future<void> _updateMarkers() async {
    if (_pointAnnotationManager == null) return;

    // Driver (bus) marker
    if (_driverLocation != null) {
      final driverPoint = Point(
        coordinates: Position(
          _driverLocation!.longitude,
          _driverLocation!.latitude,
        ),
      );

      if (_driverAnnotation != null) {
        _driverAnnotation!.geometry = driverPoint;
        _driverAnnotation!.iconRotate = _driverLocation!.heading;
        await _pointAnnotationManager!.update(_driverAnnotation!);
      } else {
        _driverAnnotation = await _pointAnnotationManager!.create(
          PointAnnotationOptions(
            geometry: driverPoint,
            textField: '🚌',
            textSize: 28,
            iconRotate: _driverLocation!.heading,
          ),
        );
      }
    }

    // Student marker
    if (_student != null && _student!.hasValidLocation()) {
      final studentPoint = Point(
        coordinates: Position(_student!.longitude, _student!.latitude),
      );
      final emoji = _getStudentStatusEmoji();

      if (_studentAnnotation != null) {
        _studentAnnotation!.geometry = studentPoint;
        _studentAnnotation!.textField = emoji;
        await _pointAnnotationManager!.update(_studentAnnotation!);
      } else {
        _studentAnnotation = await _pointAnnotationManager!.create(
          PointAnnotationOptions(
            geometry: studentPoint,
            textField: emoji,
            textSize: 24,
          ),
        );
      }
    }
  }

  Future<void> _updateRouteLine() async {
    if (_polylineAnnotationManager == null) return;
    if (_routeResult?.coordinates == null) return;

    final coords = _routeResult!.coordinates!
        .map((p) => Position(p.longitude, p.latitude))
        .toList();

    if (_routeAnnotation != null) {
      _routeAnnotation!.geometry = LineString(coordinates: coords);
      await _polylineAnnotationManager!.update(_routeAnnotation!);
    } else {
      _routeAnnotation = await _polylineAnnotationManager!.create(
        PolylineAnnotationOptions(
          geometry: LineString(coordinates: coords),
          lineColor: 0xFF6B9B5B,
          lineWidth: MapConfig.routeLineWidth,
        ),
      );
    }
  }

  String _getStudentStatusEmoji() {
    final tripStudent = _trip?.students.firstWhere(
      (s) => s.id == widget.studentId,
      orElse: () => StudentPickup(id: '', name: '', status: 'pending'),
    );

    if (tripStudent != null) {
      if (tripStudent.status == 'dropped') return '🏠';
      if (tripStudent.status == 'picked') return '✅';
      if (tripStudent.status == 'absent') return '❌';
    }
    return '👤';
  }

  String _getStudentStatus() {
    final tripStudent = _trip?.students.firstWhere(
      (s) => s.id == widget.studentId,
      orElse: () => StudentPickup(id: '', name: '', status: 'pending'),
    );

    switch (tripStudent?.status) {
      case 'picked':
        return 'Picked Up';
      case 'dropped':
        return 'Dropped Off';
      case 'absent':
        return 'Absent';
      default:
        return 'Waiting for Pickup';
    }
  }

  Color _getStatusColor() {
    final tripStudent = _trip?.students.firstWhere(
      (s) => s.id == widget.studentId,
      orElse: () => StudentPickup(id: '', name: '', status: 'pending'),
    );

    switch (tripStudent?.status) {
      case 'picked':
        return AppPalette.success;
      case 'dropped':
        return AppPalette.info;
      case 'absent':
        return AppPalette.textMutedLight;
      default:
        return AppPalette.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Bus'),
        backgroundColor: AppPalette.emerald,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInitialData,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Map
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
                child: CircularProgressIndicator(color: AppPalette.emerald),
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
                      color: AppPalette.error,
                    ),
                    const SizedBox(height: 16),
                    Text(_errorMessage!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadInitialData,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
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

          // Legend
          if (!_isLoading)
            Positioned(top: 80, right: 16, child: _buildLegend()),
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
          // Driver info
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppPalette.emerald.withAlpha(30),
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
                    if (_driverLocation != null)
                      Text(
                        '${_driverLocation!.speed.toStringAsFixed(0)} km/h',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppPalette.textSecondaryLight,
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
                  color: AppPalette.success.withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppPalette.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'LIVE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppPalette.success,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Divider(height: 24),

          // Student info
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _getStatusColor().withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getStudentStatusEmoji(),
                  style: const TextStyle(fontSize: 24),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _student?.name ?? 'Loading...',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _student?.className ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppPalette.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor().withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _getStudentStatus(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _getStatusColor(),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ETA info
          if (_routeResult != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppPalette.surfaceSubtleLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStat(
                    icon: Icons.access_time,
                    value: _routeResult!.formattedDuration,
                    label: 'ETA',
                  ),
                  _buildStat(
                    icon: Icons.directions,
                    value: _routeResult!.formattedDistance,
                    label: 'Distance',
                  ),
                  _buildStat(
                    icon: Icons.schedule,
                    value: _trip != null
                        ? '${DateTime.now().difference(_trip!.startTime).inMinutes} min'
                        : '--',
                    label: 'Trip Time',
                  ),
                ],
              ),
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
        Icon(icon, size: 20, color: AppPalette.emerald),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: AppPalette.textSecondaryLight),
        ),
      ],
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(230),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildLegendItem(emoji: '🚌', label: 'Bus'),
          const SizedBox(height: 8),
          _buildLegendItem(emoji: '👤', label: 'Waiting'),
          const SizedBox(height: 8),
          _buildLegendItem(emoji: '✅', label: 'Picked'),
          const SizedBox(height: 8),
          _buildLegendItem(emoji: '🏠', label: 'Dropped'),
        ],
      ),
    );
  }

  Widget _buildLegendItem({required String emoji, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

/// Simple driver location model
class _DriverLocation {
  final double latitude;
  final double longitude;
  final double heading;
  final double speed;
  final DateTime timestamp;

  _DriverLocation({
    required this.latitude,
    required this.longitude,
    required this.heading,
    required this.speed,
    required this.timestamp,
  });
}
