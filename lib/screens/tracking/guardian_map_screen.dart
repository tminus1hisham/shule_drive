import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../config/map_config.dart';
import '../../services/mapbox_service.dart';
import '../../api/services/trip_service.dart';
import '../../api/services/student_service.dart';

/// Guardian Map Screen - Shows driver location, child status, and trip progress
///
/// Features:
/// - Full screen Mapbox map
/// - Real-time driver location with green bus marker
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

  final MapController _mapController = MapController();

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
    _loadInitialData();
    _startLocationPolling();
  }

  @override
  void dispose() {
    _locationPollTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  // MapConfig mapbox token is injected directly in TileLayer.

  void _startLocationPolling() {
    _locationPollTimer = Timer.periodic(_pollInterval, (_) {
      _fetchDriverLocation();
    });
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);

    try {
      // Load trip details
      final trip = await _tripService.getTripDetails(widget.tripId);
      if (trip != null) {
        setState(() => _trip = trip);
      }

      // Load student details
      final student = await _studentService.getStudentById(widget.studentId);
      if (student != null) {
        setState(() => _student = student);
      }

      // Fetch driver location
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
      // TODO: Replace with actual driver location API
      // For now, simulate driver movement
      await _simulateDriverLocation();
    } catch (e) {
      debugPrint('Error fetching driver location: $e');
    }
  }

  /// Simulate driver location (replace with real API)
  Future<void> _simulateDriverLocation() async {
    // Default to Nairobi if no student location
    double studentLat = MapConfig.defaultLatitude;
    double studentLng = MapConfig.defaultLongitude;

    // Use student location if available
    if (_student != null && _student!.hasValidLocation()) {
      studentLat = _student!.latitude;
      studentLng = _student!.longitude;
    }

    // Simulate driver approaching student
    final now = DateTime.now();
    final random = now.millisecond / 1000;

    // Simulate driver within 1km of student
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

    // Calculate route and ETA
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
      setState(() {
        _routeResult = result;
      });
      _updateMapAnnotations();
    }
  }

  void _onMapReady() {
    // Camera centers automatically via MapOptions.initialCenter
  }

  void _updateMapAnnotations() {
    _updateMarkers();
    _updateRouteLine();
  }

  void _updateMarkers() {
    if (mounted) {
      setState(() {});
    }
  }

  String _getStudentStatusEmoji() {
    // Check trip student status if available
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

  void _updateRouteLine() {
    if (mounted) {
      setState(() {});
    }
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
        return const Color(0xFF4CAF50);
      case 'dropped':
        return const Color(0xFF2196F3);
      case 'absent':
        return const Color(0xFF9E9E9E);
      default:
        return const Color(0xFFFF9800);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Bus'),
        backgroundColor: const Color(0xFF6B9B5B),
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
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(
                MapConfig.defaultLatitude,
                MapConfig.defaultLongitude,
              ),
              initialZoom: 13,
              onMapReady: _onMapReady,
            ),
            children: [
              TileLayer(
                urlTemplate: MapConfig.mapboxTileUrl,
              ),
              PolylineLayer(
                polylines: [
                  if (_routeResult?.coordinates != null)
                    Polyline(
                      points: _routeResult!.coordinates!
                          .map((p) => LatLng(p.latitude, p.longitude))
                          .toList(),
                      color: const Color(0xFF6B9B5B),
                      strokeWidth: MapConfig.routeLineWidth,
                    ),
                ],
              ),
              MarkerLayer(
                markers: [
                  // Student marker
                  if (_student != null && _student!.hasValidLocation())
                    Marker(
                      point: LatLng(_student!.latitude, _student!.longitude),
                      width: 40,
                      height: 40,
                      child: Text(
                        _getStudentStatusEmoji(),
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  // Driver marker
                  if (_driverLocation != null)
                    Marker(
                      point: LatLng(
                        _driverLocation!.latitude,
                        _driverLocation!.longitude,
                      ),
                      width: 40,
                      height: 40,
                      child: const Text('🚌', style: TextStyle(fontSize: 28)),
                    ),
                ],
              ),
            ],
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
                    if (_driverLocation != null)
                      Text(
                        '${_driverLocation!.speed.toStringAsFixed(0)} km/h',
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
                        color: Colors.grey.shade600,
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
                color: Colors.grey.shade100,
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
