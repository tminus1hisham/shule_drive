import 'dart:async';
import 'dart:developer' as developer;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import '../../config/map_config.dart';
import '../../services/mapbox_service.dart';
import '../../api/services/trip_service.dart';
import '../../models/master_trip.dart';
import '../../utils/student_trip_logic.dart';
import '../../widgets/next_student_trip_action_card.dart';

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

class _OsmTrackingScreenState extends State<OsmTrackingScreen>
    with SingleTickerProviderStateMixin {
  // Services
  final MapboxService _mapboxService = MapboxService();
  final TripService _tripService = TripService();

  // Mapbox
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointAnnotationManager;
  PolylineAnnotationManager? _polylineAnnotationManager;
  PointAnnotation? _busAnnotation;

  // Location
  geo.Position? _currentPosition;
  geo.Position? _previousPosition;
  StreamSubscription<geo.Position>? _positionStream;

  // Animation for smooth bus movement
  late AnimationController _animationController;
  Animation<double>? _latAnimation;
  Animation<double>? _lngAnimation;
  Animation<double>? _bearingAnimation;

  Uint8List? _busIconBytes;

  // Data
  Trip? _trip;
  List<TripStudent> _students = [];
  RouteResult? _routeResult;

  // State
  bool _isLoading = true;
  bool _isLoadingRoute = false;
  bool _isUpdatingStudentStatus = false;
  String? _errorMessage;
  String? _statusErrorMessage;
  final Map<int, String> _studentStatusUpdates = {};
  final Set<String> _shownStudentProximityAlerts = {};

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2), // Smooth 2s interpolation
    )..addListener(_onAnimationUpdate);

    _initializeMapbox();
    _initializeLocation();
    _loadTripData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _positionStream?.cancel();
    _mapboxMap?.dispose();
    super.dispose();
  }

  void _onAnimationUpdate() {
    if (_busAnnotation != null && _pointAnnotationManager != null) {
      final lat = _latAnimation?.value ?? _currentPosition?.latitude ?? 0.0;
      final lng = _lngAnimation?.value ?? _currentPosition?.longitude ?? 0.0;
      final bearing =
          _bearingAnimation?.value ?? _currentPosition?.heading ?? 0.0;

      // Update annotation geometry and rotation
      _busAnnotation!.geometry = Point(coordinates: Position(lng, lat));
      // Mapbox iconRotate is in degrees, positive is clockwise. heading in Geolocator is also in degrees 0-359
      _busAnnotation!.iconRotate = bearing;

      _pointAnnotationManager?.update(_busAnnotation!);
    }
  }

  // Helper to get shortest rotation path (prevents spinning 360)
  double _getShortestAngle(double from, double to) {
    double difference = (to - from) % 360.0;
    if (difference > 180.0) {
      difference -= 360.0;
    } else if (difference < -180.0) {
      difference += 360.0;
    }
    return from + difference;
  }

  /// Initialize Mapbox with access token
  void _initializeMapbox() {
    MapboxOptions.setAccessToken(MapConfig.mapboxAccessToken);
  }

  /// Called when map is created
  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;

    // Load custom image into Mapbox style
    try {
      final byteData = await DefaultAssetBundle.of(
        context,
      ).load('assets/images/bus_marker.png');
      final Uint8List list = byteData.buffer.asUint8List();
      _busIconBytes = list;
    } catch (e) {
      developer.log(
        'Error loading bus marker image: $e',
        name: 'TrackingScreen',
      );
    }

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
      setState(() {
        _currentPosition = position;
        _previousPosition = position;
      });
      _maybeShowNextStudentProximityPrompt();

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
    if (!mounted) return;

    setState(() {
      _previousPosition = _currentPosition ?? position;
      _currentPosition = position;
    });

    // Start interpolation animation
    _latAnimation =
        Tween<double>(
          begin: _previousPosition!.latitude,
          end: position.latitude,
        ).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.linear),
        );

    _lngAnimation =
        Tween<double>(
          begin: _previousPosition!.longitude,
          end: position.longitude,
        ).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.linear),
        );

    _bearingAnimation =
        Tween<double>(
          begin: _previousPosition!.heading,
          end: _getShortestAngle(_previousPosition!.heading, position.heading),
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeInOut,
          ),
        );

    _animationController.forward(from: 0.0);
    _updateDriverMarker();
    _maybeShowNextStudentProximityPrompt();
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
                  route: s.route ?? '',
                  latitude: s.latitude ?? 0,
                  longitude: s.longitude ?? 0,
                  pickedLatitude: s.pickedLatitude ?? 0,
                  pickedLongitude: s.pickedLongitude ?? 0,
                  droppedLatitude: s.droppedLatitude ?? 0,
                  droppedLongitude: s.droppedLongitude ?? 0,
                  isStudentPicked: s.status == 'picked',
                  isStudentDropped: s.status == 'dropped',
                  profileImage: s.photo ?? '',
                  address: s.address ?? '',
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
        final status = _getStudentStatus(student);
        if (status == 'pending' &&
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

    if (_busAnnotation == null) {
      _busAnnotation = await _pointAnnotationManager!.create(
        PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(
              _currentPosition!.longitude,
              _currentPosition!.latitude,
            ),
          ),
          iconSize: 1.0,
          image: _busIconBytes,
        ),
      );
    }
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

  String _getStudentStatus(TripStudent student) {
    final updated = _studentStatusUpdates[student.studentId];
    if (updated != null) return updated;
    if (student.isStudentDropped) return 'dropped';
    if (student.isStudentPicked) return 'picked';
    if (!student.isStudentActive) return 'absent';
    return 'pending';
  }

  TripStudent? _nextActionableStudent() {
    final sorted = List<TripStudent>.from(_students);
    sorted.sort((a, b) => a.id.compareTo(b.id));

    if (isReturnTripDirection(_trip?.tripDirection)) {
      return _firstStudentWithStatus(sorted, 'picked');
    }

    return _firstStudentWithStatus(sorted, 'pending') ??
        _firstStudentWithStatus(sorted, 'picked');
  }

  TripStudent? _firstStudentWithStatus(
    List<TripStudent> students,
    String status,
  ) {
    for (final student in students) {
      if (_getStudentStatus(student) == status) return student;
    }
    return null;
  }

  StudentTripActionMode _actionModeForStudent(TripStudent student) {
    if (isReturnTripDirection(_trip?.tripDirection)) {
      return StudentTripActionMode.dropoff;
    }

    return _getStudentStatus(student) == 'picked'
        ? StudentTripActionMode.dropoff
        : StudentTripActionMode.pickup;
  }

  ({double latitude, double longitude})? _targetLocationForStudent(
    TripStudent student,
    StudentTripActionMode mode,
  ) {
    final latitude = mode == StudentTripActionMode.dropoff &&
            student.pickedLatitude != 0
        ? student.pickedLatitude
        : student.latitude;
    final longitude = mode == StudentTripActionMode.dropoff &&
            student.pickedLongitude != 0
        ? student.pickedLongitude
        : student.longitude;

    if (!hasValidStudentCoordinate(latitude, longitude)) return null;
    return (latitude: latitude, longitude: longitude);
  }

  double? _distanceToStudent(TripStudent student) {
    if (_currentPosition == null) return null;
    final mode = _actionModeForStudent(student);
    final target = _targetLocationForStudent(student, mode);
    if (target == null) return null;

    return calculateStudentDistanceMeters(
      vehicleLatitude: _currentPosition!.latitude,
      vehicleLongitude: _currentPosition!.longitude,
      targetLatitude: target.latitude,
      targetLongitude: target.longitude,
    );
  }

  NextStudentTripTarget _cardTargetForStudent(TripStudent student) {
    final mode = _actionModeForStudent(student);
    final target = _targetLocationForStudent(student, mode);

    return NextStudentTripTarget(
      id: student.studentId.toString(),
      name: student.fullname,
      status: _getStudentStatus(student),
      photoUrl: student.profileImage,
      destinationLabel: student.address.isNotEmpty
          ? student.address
          : student.route.isNotEmpty
              ? student.route
              : mode == StudentTripActionMode.dropoff
                  ? 'Saved home destination'
                  : 'Pickup location',
      latitude: target?.latitude,
      longitude: target?.longitude,
    );
  }

  void _maybeShowNextStudentProximityPrompt() {
    if (!mounted || _isUpdatingStudentStatus || _currentPosition == null) {
      return;
    }

    final student = _nextActionableStudent();
    if (student == null) return;

    final mode = _actionModeForStudent(student);
    final distance = _distanceToStudent(student);
    if (distance == null || !isWithinStudentProximity(distance)) return;

    final promptKey =
        '${student.studentId}_${mode.name}_${_getStudentStatus(student)}';
    if (_shownStudentProximityAlerts.contains(promptKey)) return;
    _shownStudentProximityAlerts.add(promptKey);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: NextStudentTripActionCard(
              student: _cardTargetForStudent(student),
              mode: mode,
              distanceMeters: distance,
              isSubmitting: _isUpdatingStudentStatus,
              errorMessage: _statusErrorMessage,
              onPickedUp: () {
                Navigator.pop(sheetContext);
                _updateStudentStatus(student, 'picked');
              },
              onDroppedOff: () {
                Navigator.pop(sheetContext);
                _updateStudentStatus(student, 'dropped');
              },
              onAbsent: () {
                Navigator.pop(sheetContext);
                _updateStudentStatus(student, 'absent');
              },
            ),
          ),
        ),
      );
    });
  }

  Future<void> _updateStudentStatus(TripStudent student, String status) async {
    if (widget.tripId == null || _isUpdatingStudentStatus) return;

    setState(() {
      _isUpdatingStudentStatus = true;
      _statusErrorMessage = null;
    });

    try {
      await _tripService.updateStudentStatus(
        tripId: widget.tripId!,
        studentId: student.studentId.toString(),
        status: status,
        latitude: _currentPosition?.latitude,
        longitude: _currentPosition?.longitude,
      );

      if (!mounted) return;
      setState(() {
        _studentStatusUpdates[student.studentId] = status;
      });

      await _calculateRoute();
      await _updateMarkers();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${student.fullname} ${_statusMessage(status)}'),
          backgroundColor: status == 'absent'
              ? Colors.orange
              : const Color(0xFF6B9B5B),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusErrorMessage = 'Failed to update status: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_statusErrorMessage!),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdatingStudentStatus = false);
      }
    }
  }

  String _statusMessage(String status) {
    switch (status) {
      case 'picked':
        return 'picked up';
      case 'dropped':
        return 'dropped off';
      case 'absent':
        return 'marked absent';
      default:
        return 'updated';
    }
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
    final nextStudent = _nextActionableStudent();
    final nextMode = nextStudent == null
        ? StudentTripActionMode.pickup
        : _actionModeForStudent(nextStudent);
    final nextDistance =
        nextStudent == null ? null : _distanceToStudent(nextStudent);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9), // Glassmorphism base
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 20),
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Driver/Bus info
          Row(
            children: [
              Container(
                height: 56,
                width: 56,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6B9B5B), Color(0xFF86ba74)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6B9B5B).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text('🚌', style: TextStyle(fontSize: 28)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _trip?.vehicleNumber ?? 'Bus ${_trip?.vehicleId ?? ''}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (_currentPosition != null)
                      Row(
                        children: [
                          Icon(
                            Icons.speed,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${_currentPosition!.speed.toStringAsFixed(0)} km/h',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.2),
                  ),
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
                        boxShadow: [
                          BoxShadow(color: Colors.green, blurRadius: 4),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'LIVE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),
          NextStudentTripActionCard(
            student:
                nextStudent == null ? null : _cardTargetForStudent(nextStudent),
            mode: nextMode,
            distanceMeters: nextDistance,
            isSubmitting: _isUpdatingStudentStatus,
            errorMessage: _statusErrorMessage,
            onPickedUp: nextStudent == null
                ? null
                : () => _updateStudentStatus(nextStudent, 'picked'),
            onDroppedOff: nextStudent == null
                ? null
                : () => _updateStudentStatus(nextStudent, 'dropped'),
            onAbsent: nextStudent == null
                ? null
                : () => _updateStudentStatus(nextStudent, 'absent'),
          ),

          const SizedBox(height: 24),
          const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
          const SizedBox(height: 24),

          // Students summary
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStat(
                icon: Icons.people_outline_rounded,
                value: '${_students.length}',
                label: 'Total',
              ),
              Container(width: 1, height: 40, color: const Color(0xFFEEEEEE)),
              _buildStat(
                icon: Icons.check_circle_outline_rounded,
                value: '${_students.where((s) => s.isStudentPicked).length}',
                label: 'Picked',
                iconColor: Colors.green,
              ),
              if (_routeResult != null) ...[
                Container(width: 1, height: 40, color: const Color(0xFFEEEEEE)),
                _buildStat(
                  icon: Icons.access_time_rounded,
                  value: _routeResult!.formattedDuration,
                  label: 'ETA',
                  iconColor: Colors.blue,
                ),
              ],
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
    Color? iconColor,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (iconColor ?? const Color(0xFF6B9B5B)).withValues(
              alpha: 0.1,
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 22,
            color: iconColor ?? const Color(0xFF6B9B5B),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}
