import 'dart:async';
import 'dart:math' show sin, cos, sqrt, atan2;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:provider/provider.dart';
import '../../api/api.dart' as api;
import '../../providers/auth_provider.dart';
import '../../providers/trip_provider.dart';
import '../../models/map_models.dart';
import '../../models/preloaded_trip_data.dart';
import '../../models/master_trip.dart';
import '../../services/mapbox_service.dart';
import '../../config/map_config.dart';
import '../../services/notification_service.dart';
import '../../mqtt_client.dart';
import '../../utils/student_trip_logic.dart';
import '../../utils/location_settings.dart';
import '../../widgets/main_scaffold.dart';
import '../../widgets/next_student_trip_action_card.dart';
import '../../widgets/ui/ui.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme_extension.dart';

/// Active Trip Screen - Shows live map tracking with flutter_map
///
/// Features:
/// - Mapbox raster tiles via flutter_map
/// - Center on bus functionality
/// - Live bus tracking with location updates
/// - Student pickup/dropoff actions
/// - Geofence alerts
class ActiveTripScreen extends StatefulWidget {
  const ActiveTripScreen({super.key});

  @override
  State<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends State<ActiveTripScreen> {
  // flutter_map controller
  final MapController _mapController = MapController();

  // No longer using Mapbox GL annotations manager, flutter_map handles this declaratively
  Widget? _busMarkerWidget;

  final NotificationService _notificationService = NotificationService();
  final MqttService _mqttService = MqttService();
  final MapboxService _mapboxService = MapboxService();

  // State
  BusLocation? _currentLocation;
  List<RouteStop> _stops = [];
  List<LatLng> _routePoints = [];
  final List<GeofenceAlert> _alerts = [];
  bool _isLoading = true;
  bool _followBus = true;
  bool _isEndingTrip = false;
  bool _isMapInitialized = false;
  bool _isUpdatingStudentStatus = false;
  int _pickedCount = 0;
  int _totalCount = 0;
  bool _hasLocationPermission = false;

  // Trip data
  api.Trip? _activeTrip;
  String? _tripId;
  String? _busPlate;

  // Stream subscriptions
  StreamSubscription<geo.Position>? _locationSubscription;
  Timer? _refreshTimer;

  // Geofence tracking
  final Set<String> _processedStops = {};
  final Set<String> _shownStudentProximityAlerts = {};
  bool _isShowingPickupDialog = false;
  final Set<String> _etaNotifiedStops = {};

  // Preloaded trip data
  List<Map<String, dynamic>> _preloadedStudents = [];
  // Roster (as StudentPickup) used to seed the provider's active trip so it
  // becomes the single source of truth shared with the students-list screen
  // and preserved by endTrip.
  List<api.StudentPickup> _preloadedRoster = [];
  String? _masterTripName;
  String? _masterTripPlate;

  // Provider reference kept for listener add/remove.
  TripProvider? _tripProvider;

  // Map style
  String _currentMapStyle = 'mapbox://styles/mapbox/streets-v12';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _tripProvider = context.read<TripProvider>();
      _tripProvider?.addListener(_onTripProviderChanged);
      _initializeTrip();
    });
  }

  @override
  void dispose() {
    _tripProvider?.removeListener(_onTripProviderChanged);
    _locationSubscription?.cancel();
    _refreshTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  /// Mirror provider status changes (e.g. picks made on the students-list
  /// screen) into this screen's working copy so all screens stay in sync.
  void _onTripProviderChanged() {
    if (!mounted) return;
    final providerTrip = _tripProvider?.activeTrip;
    if (providerTrip == null) return;

    final byId = {for (final s in providerTrip.students) s.id: s};
    for (final student in _preloadedStudents) {
      final match = byId[student['id']?.toString()];
      if (match != null && student['status'] != match.status) {
        student['status'] = match.status;
      }
    }

    setState(() {
      _activeTrip = providerTrip;
      _recomputeCounts();
    });
  }

  List<String> get _statuses => _preloadedStudents.isNotEmpty
      ? [for (final s in _preloadedStudents) '${s['status']}']
      : [...?_activeTrip?.students.map((s) => s.status)];

  void _recomputeCounts() {
    if (_preloadedStudents.isNotEmpty) {
      _totalCount = _preloadedStudents.length;
      _pickedCount = _preloadedStudents
          .where((s) => s['status'] == 'picked')
          .length;
    } else if (_activeTrip != null) {
      _totalCount = _activeTrip!.students.length;
      _pickedCount = _activeTrip!.pickedCount;
    }
  }

  Future<void> _initializeTrip() async {
    setState(() => _isLoading = true);

    // Get trip ID from route arguments
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final dynamic rawTripId = args?['tripId'];
    _tripId = rawTripId?.toString();
    _busPlate = args?['busPlate'] as String? ?? 'BUS001';

    // Parse preloaded students
    final preloadedDataMap = args?['preloadedData'] as Map<String, dynamic>?;
    if (preloadedDataMap != null) {
      try {
        final preloadedData = PreloadedTripData.fromJson(preloadedDataMap);
        _preloadedStudents = _convertTripStudentsToMap(preloadedData.students);
        // Build the StudentPickup roster used to seed the provider. TripStudent
        // serialises to exactly the keys StudentPickup.fromJson reads.
        _preloadedRoster = preloadedData.students
            .map((s) => api.StudentPickup.fromJson(s.toJson()))
            .toList();
        _masterTripName = preloadedData.masterTrip.tripName;
        _masterTripPlate = preloadedData.masterTrip.numberPlate;
        _totalCount = _preloadedStudents.length;
        _pickedCount = _preloadedStudents
            .where((s) => s['status'] == 'picked')
            .length;
      } catch (e) {
        debugPrint('⚠️ Failed to parse preloaded data: $e');
      }
    }

    // Load active trip data
    await _loadActiveTrip();

    // Seed the provider's active trip with the full roster so it becomes the
    // single source of truth (fixes cross-screen status drift and empty
    // trip-details after completion).
    _hydrateProviderFromPreloaded();

    // Initialize location tracking
    await _initializeLocationTracking();

    // Start periodic refresh
    _startPeriodicRefresh();

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadActiveTrip() async {
    try {
      final tripProvider = context.read<TripProvider>();

      if (_tripId != null) {
        try {
          _activeTrip = tripProvider.trips.firstWhere((t) => t.id == _tripId);
        } catch (_) {
          _activeTrip = null;
        }
      }

      _activeTrip ??= tripProvider.activeTrip;

      if (_activeTrip != null) {
        setState(() {
          _totalCount = _activeTrip!.students.length;
          _pickedCount = _activeTrip!.pickedCount;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading active trip: $e');
    }
  }

  /// Push the preloaded roster (and any missing vehicle/route details) into the
  /// provider's active trip, then adopt the provider's merged copy locally.
  void _hydrateProviderFromPreloaded() {
    if (!mounted) return;
    final tripProvider = context.read<TripProvider>();
    if (tripProvider.activeTrip == null) return;
    // Prefer the real master-trip plate; the _busPlate arg can be the
    // 'BUS001' placeholder.
    final plate = (_masterTripPlate != null && _masterTripPlate!.isNotEmpty)
        ? _masterTripPlate
        : _busPlate;

    if (_preloadedRoster.isEmpty && (plate == null || plate.isEmpty)) {
      return;
    }

    tripProvider.hydrateActiveTrip(
      roster: _preloadedRoster,
      vehicleNumber: plate,
      routeName: _masterTripName,
    );

    _activeTrip = tripProvider.activeTrip ?? _activeTrip;
    // Mirror the merged provider statuses into the working list + counts.
    _onTripProviderChanged();
  }

  void _onMapReady() {
    setState(() {
      _isMapInitialized = true;
    });

    if (_stops.isNotEmpty) {
      _moveCameraToPosition(
        _stops.first.position.latitude,
        _stops.first.position.longitude,
        zoom: 13,
      );
    }
  }

  /// Move camera to position with flutter_map
  void _moveCameraToPosition(
    double latitude,
    double longitude, {
    double zoom = 15,
  }) {
    if (_isMapInitialized) {
      _mapController.move(LatLng(latitude, longitude), zoom);
    }
  }

  /// Center on bus
  void _centerOnBus() {
    if (_currentLocation == null) return;

    setState(() => _followBus = true);
    HapticFeedback.mediumImpact();

    if (_isMapInitialized) {
      // flutter_map doesn't have 3D pitch, so we just pan and zoom
      _mapController.move(
        LatLng(
          _currentLocation!.position.latitude,
          _currentLocation!.position.longitude,
        ),
        17,
      );
      // flutter_map rotation is handled via rotate method
      _mapController.rotate(-161.81);
    }

    debugPrint('🎥 Camera centered on bus');
  }

  /// Update bus marker position
  void _updateBusMarker() {
    if (_currentLocation == null) return;

    // Create the bus marker widget
    _busMarkerWidget = Transform.rotate(
      angle: _currentLocation!.heading * (pi / 180),
      child: Image.asset('assets/images/bus_marker.png', width: 40, height: 40),
    );

    if (mounted) {
      setState(() {});
    }

    // Follow bus if enabled
    if (_followBus && _isMapInitialized) {
      _mapController.move(
        LatLng(
          _currentLocation!.position.latitude,
          _currentLocation!.position.longitude,
        ),
        17,
      );
    }
  }

  Future<void> _initializeLocationTracking() async {
    // Use actual trip stops if available
    if (_activeTrip != null && _activeTrip!.stops.isNotEmpty) {
      _stops = _activeTrip!.stops.map((stop) {
        return RouteStop(
          id: stop.id,
          name: stop.name,
          position: LatLng(stop.latitude ?? 0.0, stop.longitude ?? 0.0),
          address: stop.address,
          order: stop.order,
          type: stop.type == 'dropoff' ? StopType.dropoff : StopType.pickup,
        );
      }).toList();
    } else {
      _stops = [];
    }

    // Request location permission and start tracking
    await _checkLocationPermission();

    if (_hasLocationPermission) {
      await _startRealTimeTracking();
    }

    // Fetch route from Mapbox
    _fetchRouteFromMapbox();
  }

  Future<void> _checkLocationPermission() async {
    try {
      bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _hasLocationPermission = false);
        return;
      }

      geo.LocationPermission permission =
          await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
        if (permission == geo.LocationPermission.denied) {
          setState(() => _hasLocationPermission = false);
          return;
        }
      }

      if (permission == geo.LocationPermission.deniedForever) {
        setState(() => _hasLocationPermission = false);
        return;
      }

      setState(() => _hasLocationPermission = true);
    } catch (e) {
      setState(() => _hasLocationPermission = false);
    }
  }

  Future<void> _startRealTimeTracking() async {
    try {
      final initialPosition = await geo.Geolocator.getCurrentPosition();
      _updateBusLocation(initialPosition);

      _locationSubscription =
          geo.Geolocator.getPositionStream(
            locationSettings: driverLocationSettings(),
          ).listen(
            _onPositionUpdate,
            onError: (error) => debugPrint('❌ Location stream error: $error'),
          );
    } catch (e) {
      debugPrint('❌ Error starting real-time tracking: $e');
    }
  }

  void _onPositionUpdate(geo.Position position) {
    _updateBusLocation(position);
    _publishLocationToMqtt(position);
  }

  void _updateBusLocation(geo.Position position) {
    if (!mounted) return;

    final busLocation = BusLocation(
      busId: _busPlate ?? 'BUS001',
      busNumber: _busPlate ?? 'BUS001',
      position: LatLng(position.latitude, position.longitude),
      heading: position.heading,
      speed: position.speed * 3.6,
      timestamp: DateTime.now(),
    );

    setState(() {
      _currentLocation = busLocation;
    });

    _updateBusMarker();
    _checkGeofences(busLocation);
  }

  Future<void> _fetchRouteFromMapbox() async {
    if (_stops.length < 2) return;

    try {
      final waypoints = _stops
          .map(
            (stop) => {
              'lat': stop.position.latitude,
              'lng': stop.position.longitude,
            },
          )
          .toList();

      final result = await _mapboxService.getRoute(waypoints);

      if (result.success && result.coordinates != null) {
        setState(() {
          _routePoints = result.coordinates!
              .map((pos) => LatLng(pos.latitude, pos.longitude))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('❌ Mapbox routing error: $e');
    }
  }

  void _publishLocationToMqtt(geo.Position position) {
    if (!_mqttService.isConnected) return;

    final topic = 'driver/$_busPlate/location';
    final payload = {
      'busId': _busPlate ?? 'BUS001',
      'latitude': position.latitude,
      'longitude': position.longitude,
      'heading': position.heading,
      'speed': position.speed * 3.6,
      'timestamp': DateTime.now().toIso8601String(),
      'tripId': _tripId,
    };

    _mqttService.publishJson(topic, payload);
  }

  void _startPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _refreshTripData();
    });
  }

  Future<void> _refreshTripData() async {
    try {
      final tripProvider = context.read<TripProvider>();

      if (tripProvider.activeTrip != null && mounted) {
        setState(() {
          _activeTrip = tripProvider.activeTrip;
          _totalCount = _activeTrip!.students.length;
          _pickedCount = _activeTrip!.pickedCount;
        });
      }
    } catch (e) {
      debugPrint('❌ Error refreshing trip data: $e');
    }
  }

  Map<String, dynamic>? _nextActionableStudent() {
    final students = List<Map<String, dynamic>>.from(
      _buildStudentListFromStops(),
    );
    if (students.isEmpty) return null;

    students.sort((a, b) => _asInt(a['order']).compareTo(_asInt(b['order'])));

    final isReturnTrip = isReturnTripDirection(_activeTrip?.tripDirection);
    if (isReturnTrip) {
      return _firstStudentWithStatus(students, 'picked') ??
          _firstStudentWithStatus(students, 'pending');
    }

    return _firstStudentWithStatus(students, 'pending') ??
        _firstStudentWithStatus(students, 'picked');
  }

  Map<String, dynamic>? _firstStudentWithStatus(
    List<Map<String, dynamic>> students,
    String status,
  ) {
    for (final student in students) {
      if ((student['status'] ?? 'pending').toString() == status) {
        return student;
      }
    }
    return null;
  }

  StudentTripActionMode _actionModeForStudent(Map<String, dynamic> student) {
    final status = (student['status'] ?? 'pending').toString();
    return status == 'picked'
        ? StudentTripActionMode.dropoff
        : StudentTripActionMode.pickup;
  }

  LatLng? _targetLocationForStudent(
    Map<String, dynamic> student,
    StudentTripActionMode mode,
  ) {
    final targetLatitude = mode == StudentTripActionMode.dropoff
        ? _firstValidDouble([student['homeLatitude'], student['latitude']])
        : _asDouble(student['latitude']);
    final targetLongitude = mode == StudentTripActionMode.dropoff
        ? _firstValidDouble([student['homeLongitude'], student['longitude']])
        : _asDouble(student['longitude']);

    if (!hasValidStudentCoordinate(targetLatitude, targetLongitude)) {
      return null;
    }

    return LatLng(targetLatitude!, targetLongitude!);
  }

  double? _distanceToStudent(
    Map<String, dynamic> student, {
    BusLocation? location,
  }) {
    final busLocation = location ?? _currentLocation;
    if (busLocation == null) return null;

    final mode = _actionModeForStudent(student);
    final target = _targetLocationForStudent(student, mode);
    if (target == null) return null;

    return calculateStudentDistanceMeters(
      vehicleLatitude: busLocation.position.latitude,
      vehicleLongitude: busLocation.position.longitude,
      targetLatitude: target.latitude,
      targetLongitude: target.longitude,
    );
  }

  NextStudentTripTarget? _nextStudentTripTarget() {
    final student = _nextActionableStudent();
    if (student == null) return null;

    return _studentTripTargetForStudent(student);
  }

  List<NextStudentTripTarget> _studentTripTargets() {
    return _buildStudentListFromStops()
        .map(_studentTripTargetForStudent)
        .toList();
  }

  NextStudentTripTarget _studentTripTargetForStudent(
    Map<String, dynamic> student,
  ) {
    final mode = _actionModeForStudent(student);
    final targetLocation = _targetLocationForStudent(student, mode);

    return NextStudentTripTarget(
      id: student['id']?.toString() ?? '',
      name: student['name']?.toString() ?? 'Unknown Student',
      status: (student['status'] ?? 'pending').toString(),
      photoUrl: student['photo']?.toString(),
      destinationLabel: _destinationLabelForStudent(student, mode),
      latitude: targetLocation?.latitude,
      longitude: targetLocation?.longitude,
    );
  }

  StudentTripActionMode _actionModeForTripTarget(NextStudentTripTarget target) {
    final student = _findStudentById(target.id);
    if (student != null) return _actionModeForStudent(student);

    return target.status == 'picked'
        ? StudentTripActionMode.dropoff
        : StudentTripActionMode.pickup;
  }

  double? _distanceForTripTarget(NextStudentTripTarget target) {
    final student = _findStudentById(target.id);
    return student == null ? null : _distanceToStudent(student);
  }

  String _destinationLabelForStudent(
    Map<String, dynamic> student,
    StudentTripActionMode mode,
  ) {
    final address = student['address']?.toString();
    if (address != null && address.isNotEmpty) return address;

    final stopName = student['stopName']?.toString();
    if (stopName != null && stopName.isNotEmpty) return stopName;

    return mode == StudentTripActionMode.dropoff
        ? 'Saved home destination'
        : 'Pickup location';
  }

  double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  double? _firstValidDouble(List<dynamic> values) {
    for (final value in values) {
      final parsed = _asDouble(value);
      if (parsed != null && parsed != 0) return parsed;
    }
    return null;
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  void _checkGeofences(BusLocation location) {
    for (final stop in _stops) {
      final distance = _calculateDistance(
        location.position.latitude,
        location.position.longitude,
        stop.position.latitude,
        stop.position.longitude,
      );

      final speed = location.speed > 0 ? location.speed / 3.6 : 8.33;
      final etaSeconds = speed > 0 ? (distance / speed).round() : 999;
      final etaMinutes = (etaSeconds / 60).ceil();

      GeofenceType? alertType;
      if (distance <= 100) {
        alertType = GeofenceType.arrived;
      } else if (distance <= 500) {
        alertType = GeofenceType.arriving;
      } else if (distance <= 2000) {
        alertType = GeofenceType.approaching;
      }

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

    _maybeShowNextStudentProximityPrompt(location);
  }

  double _calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const double earthRadius = 6371000;
    final lat1Rad = lat1 * pi / 180;
    final lat2Rad = lat2 * pi / 180;
    final deltaLat = (lat2 - lat1) * pi / 180;
    final deltaLng = (lng2 - lng1) * pi / 180;

    final a =
        sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(deltaLng / 2) * sin(deltaLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  Future<void> _sendEtaNotification(RouteStop stop, int etaMinutes) async {
    if (_activeTrip == null) return;

    try {
      final tripProvider = context.read<TripProvider>();
      final studentsAtStop = _activeTrip!.students
          .where((s) => s.status == 'pending')
          .toList();

      for (final student in studentsAtStop) {
        await tripProvider.sendEtaNotification(
          tripId: _activeTrip!.id,
          studentId: student.id,
          stopId: stop.id,
          stopName: stop.name,
          etaMinutes: etaMinutes,
        );
      }

      _etaNotifiedStops.add(stop.id);

      await _notificationService.showLocalNotification(
        title: '📍 Approaching ${stop.name}',
        body: 'Arriving in $etaMinutes min',
        channelId: 'geofence_alerts',
      );
    } catch (e) {
      debugPrint('⚠️ Failed to send ETA notification: $e');
    }
  }

  void _maybeShowNextStudentProximityPrompt(
    BusLocation location, {
    bool force = false,
  }) {
    if (_isShowingPickupDialog || _activeTrip == null || !mounted) return;

    final student = _nextActionableStudent();
    if (student == null) return;

    final mode = _actionModeForStudent(student);
    final distance = _distanceToStudent(student, location: location);
    if (distance == null) return;
    if (!force && !isWithinStudentProximity(distance)) return;

    final promptKey =
        '${student['id']}_${mode.name}_${student['status'] ?? 'pending'}';
    if (_shownStudentProximityAlerts.contains(promptKey)) return;
    _shownStudentProximityAlerts.add(promptKey);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isShowingPickupDialog) return;
      _showNextStudentProximitySheet(student, mode, distance);
    });
  }

  Future<void> _showNextStudentProximitySheet(
    Map<String, dynamic> student,
    StudentTripActionMode mode,
    double distance,
  ) async {
    _isShowingPickupDialog = true;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: NextStudentTripActionCard(
              student: _studentTripTargetForStudent(student),
              students: _studentTripTargets(),
              mode: mode,
              distanceMeters: distance,
              modeForStudent: _actionModeForTripTarget,
              distanceForStudent: _distanceForTripTarget,
              isSubmitting: _isUpdatingStudentStatus,
              errorMessage: context.read<TripProvider>().errorMessage,
              onPickedUpStudent: (target) {
                Navigator.pop(sheetContext);
                _updateStudentStatus(target.id, 'picked');
              },
              onDroppedOffStudent: (target) {
                Navigator.pop(sheetContext);
                _updateStudentStatus(target.id, 'dropped');
              },
              onAbsentStudent: (target) {
                Navigator.pop(sheetContext);
                _updateStudentStatus(target.id, 'absent');
              },
              onChat: () {
                Navigator.pop(sheetContext);
                _openTripChat();
              },
              onStudents: () {
                Navigator.pop(sheetContext);
                _showStudentList();
              },
              onNotify: () {
                Navigator.pop(sheetContext);
                _showNotifyOptions();
              },
            ),
          ),
        );
      },
    ).whenComplete(() {
      _isShowingPickupDialog = false;
    });
  }

  void _showTripOptions() {
    showAppBottomSheet<void>(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppListTile(
            icon: Icons.my_location_rounded,
            title: 'Center on Bus',
            onTap: () {
              Navigator.pop(context);
              _centerOnBus();
            },
          ).enterList(0),
          AppListTile(
            icon: Icons.list_alt_rounded,
            title: 'View Students',
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(
                context,
                '/students-list',
                arguments: {'tripId': _tripId},
              );
            },
          ).enterList(1),
          AppListTile(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'Chat with Guardians',
            iconColor: context.colors.info,
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/chat');
            },
          ).enterList(2),
          AppListTile(
            icon: Icons.call_rounded,
            title: 'Emergency Call',
            destructive: true,
            onTap: () {
              Navigator.pop(context);
              _showEmergencyDialog();
            },
          ).enterList(3),
        ],
      ),
    );
  }

  void _showEmergencyDialog() {
    confirmDialog(
      context,
      title: 'Emergency',
      message: 'Are you sure you want to make an emergency call?',
      confirmLabel: 'Call Emergency',
      icon: Icons.warning_rounded,
      destructive: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return MainScaffold(
      title: _activeTrip?.routeName ?? 'Active Trip',
      showBackButton: false,
      showBottomNav: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.more_vert),
          tooltip: 'Trip options',
          onPressed: _showTripOptions,
        ),
      ],
      body: Stack(
        children: [
          // Map with flutter_map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(
                MapConfig.defaultLatitude,
                MapConfig.defaultLongitude,
              ),
              initialZoom: 13,
              onMapReady: _onMapReady,
              onPositionChanged: (position, hasGesture) {
                if (hasGesture && _followBus) {
                  setState(() => _followBus = false);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: MapConfig.getMapboxUrl(_currentMapStyle),
                maxZoom: 22,
              ),
              PolylineLayer(
                polylines: [
                  if (_routePoints.isNotEmpty)
                    Polyline(
                      points: _routePoints,
                      color: c.brand,
                      strokeWidth: 5,
                      borderColor: Colors.white.withValues(alpha: 0.8),
                      borderStrokeWidth: 2,
                    ),
                ],
              ),
              MarkerLayer(
                markers: [
                  // Stop markers
                  ..._stops.map((stop) {
                    final isProcessed = _processedStops.contains(stop.id);
                    return Marker(
                      point: LatLng(
                        stop.position.latitude,
                        stop.position.longitude,
                      ),
                      width: 30,
                      height: 30,
                      child: AnimatedContainer(
                        duration: AppDuration.slow,
                        decoration: BoxDecoration(
                          color: isProcessed ? c.textMuted : c.brand,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: c.shadowSm,
                        ),
                        child: Center(
                          child: Text(
                            '${stop.order}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  // Bus marker
                  if (_currentLocation != null && _busMarkerWidget != null)
                    Marker(
                      point: LatLng(
                        _currentLocation!.position.latitude,
                        _currentLocation!.position.longitude,
                      ),
                      width: 60,
                      height: 60,
                      child: _busMarkerWidget!,
                    ),
                  // Fallback circle for bus if no image
                  if (_currentLocation != null && _busMarkerWidget == null)
                    Marker(
                      point: LatLng(
                        _currentLocation!.position.latitude,
                        _currentLocation!.position.longitude,
                      ),
                      width: 24,
                      height: 24,
                      child: Container(
                        decoration: BoxDecoration(
                          color: c.accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: c.shadowMd,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Loading scrim fades away once the trip is ready.
          IgnorePointer(
            ignoring: !_isLoading,
            child: AnimatedOpacity(
              opacity: _isLoading ? 1 : 0,
              duration: AppDuration.slow,
              child: ColoredBox(
                color: Colors.black.withValues(
                  alpha: context.isDark ? 0.5 : 0.25,
                ),
                child: Center(
                  child: GlassPanel(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                      vertical: AppSpacing.lg,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: c.brand),
                        AppSpacing.vMd,
                        Text('Loading trip…', style: context.text.titleSmall),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Top overlays: permission banner, trip bar, geofence alerts.
          Positioned(
            top: AppSpacing.md,
            left: AppSpacing.md,
            right: 72,
            child: RepaintBoundary(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AnimatedSize(
                    duration: AppDuration.medium,
                    curve: AppCurves.easeOut,
                    child: !_hasLocationPermission && !_isLoading
                        ? Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.xs,
                            ),
                            child: _buildPermissionBanner(),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                  _buildTopInfoBar().enter(offsetY: -40),
                  if (_alerts.isNotEmpty) ...[
                    AppSpacing.vXs,
                    _buildAlertsPanel(),
                  ],
                ],
              ),
            ),
          ),

          // Map controls
          Positioned(
            right: AppSpacing.md,
            top: AppSpacing.md,
            child: Column(
              children: [
                _MapButton(
                  icon: _followBus
                      ? Icons.my_location_rounded
                      : Icons.location_searching_rounded,
                  tooltip: 'Center on bus',
                  highlighted: true,
                  onPressed: _centerOnBus,
                ),
                AppSpacing.vXs,
                _MapButton(
                  icon: Icons.add_rounded,
                  tooltip: 'Zoom in',
                  onPressed: () {
                    final currentZoom = _mapController.camera.zoom;
                    _mapController.move(
                      _mapController.camera.center,
                      currentZoom + 1,
                    );
                  },
                ),
                AppSpacing.vXs,
                _MapButton(
                  icon: Icons.remove_rounded,
                  tooltip: 'Zoom out',
                  onPressed: () {
                    final currentZoom = _mapController.camera.zoom;
                    _mapController.move(
                      _mapController.camera.center,
                      currentZoom - 1,
                    );
                  },
                ),
                AppSpacing.vXs,
                _buildMapStyleSelector(),
              ],
            ).enter(delay: const Duration(milliseconds: 150)),
          ),

          // Bottom panel
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: RepaintBoundary(
              child: _buildBottomPanel().enter(
                offsetY: 80,
                delay: const Duration(milliseconds: 80),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionBanner() {
    final c = context.colors;
    return GlassPanel(
      tint: c.warning,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.xxs,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Icon(Icons.location_off_rounded, color: c.warning),
          AppSpacing.hXs,
          Expanded(
            child: Text(
              'Location permission required for real-time tracking',
              style: context.text.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: _checkLocationPermission,
            child: const Text('Enable'),
          ),
        ],
      ),
    ).enter(offsetY: -20);
  }

  Widget _buildMapStyleSelector() {
    final c = context.colors;
    final styles = [
      {'key': MapConfig.mapboxLightStyle, 'label': 'Light', 'icon': Icons.map},
      {
        'key': MapConfig.mapboxDarkStyle,
        'label': 'Dark',
        'icon': Icons.dark_mode,
      },
      {
        'key': MapConfig.mapboxSatelliteStyle,
        'label': 'Satellite',
        'icon': Icons.satellite_alt,
      },
    ];

    return PopupMenuButton<String>(
      tooltip: 'Map style',
      onSelected: (style) {
        HapticFeedback.selectionClick();
        setState(() => _currentMapStyle = style);
      },
      offset: const Offset(-50, 0),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.brMd),
      itemBuilder: (context) => styles.map((style) {
        final isSelected = _currentMapStyle == style['key'];
        return PopupMenuItem<String>(
          value: style['key'] as String,
          child: Row(
            children: [
              Icon(
                style['icon'] as IconData,
                size: AppIconSize.md,
                color: isSelected ? c.brand : c.textSecondary,
              ),
              AppSpacing.hSm,
              Text(
                style['label'] as String,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? c.brand : null,
                ),
              ),
              if (isSelected) ...[
                const Spacer(),
                Icon(Icons.check, size: 18, color: c.brand),
              ],
            ],
          ),
        );
      }).toList(),
      child: const _MapButton(icon: Icons.layers_rounded, onPressed: null),
    );
  }

  Widget _buildTopInfoBar() {
    final c = context.colors;
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _activeTrip?.routeName ?? 'Route',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              StatusPill(
                label: 'LIVE',
                color: c.brand,
                pulse: true,
                dense: true,
              ),
            ],
          ),
          AppSpacing.vXxs,
          Row(
            children: [
              AnimatedCount(
                _pickedCount,
                style: context.text.bodySmall?.copyWith(
                  color: c.brand,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '/$_totalCount students picked',
                style: context.text.bodySmall?.copyWith(color: c.textSecondary),
              ),
            ],
          ),
          AppSpacing.vXs,
          TripProgress.bar(
            done: _pickedCount,
            total: _totalCount,
            thickness: 5,
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsPanel() {
    final c = context.colors;
    return Column(
      children: _alerts.take(3).map((alert) {
        return Padding(
          key: ValueKey('${alert.stopName}-${alert.type.name}'),
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: GlassPanel(
            tint: c.accent,
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                Text(alert.type.icon, style: const TextStyle(fontSize: 24)),
                AppSpacing.hSm,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alert.type.displayName,
                        style: context.text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${alert.stopName} - ${alert.formattedDistance}',
                        style: context.text.bodySmall?.copyWith(
                          color: c.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusPill(
                  label: alert.formattedEta,
                  color: c.brand,
                  showDot: false,
                  dense: true,
                ),
              ],
            ),
          ).enter(offsetY: -16),
        );
      }).toList(),
    );
  }

  Widget _buildBottomPanel() {
    final c = context.colors;
    final nextStudent = _nextActionableStudent();
    final nextMode = nextStudent == null
        ? StudentTripActionMode.pickup
        : _actionModeForStudent(nextStudent);
    final nextDistance = nextStudent == null
        ? null
        : _distanceToStudent(nextStudent);
    final studentTargets = _studentTripTargets();

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: context.scheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
        border: Border(top: BorderSide(color: c.outline)),
        boxShadow: c.shadowLg,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Grabber
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              decoration: BoxDecoration(
                color: c.outline,
                borderRadius: AppRadius.brPill,
              ),
            ),
            // Speed and heading info
            if (_currentLocation != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _TelemetryChip(
                    icon: Icons.speed_rounded,
                    value: _currentLocation!.speed.round(),
                    unit: ' km/h',
                  ),
                  AppSpacing.hXs,
                  _TelemetryChip(
                    icon: Icons.navigation_rounded,
                    value: _currentLocation!.heading.round(),
                    unit: '°',
                  ),
                ],
              ),
              AppSpacing.vSm,
            ],

            NextStudentTripActionCard(
              student: _nextStudentTripTarget(),
              students: studentTargets,
              mode: nextMode,
              distanceMeters: nextDistance,
              modeForStudent: _actionModeForTripTarget,
              distanceForStudent: _distanceForTripTarget,
              isSubmitting: _isUpdatingStudentStatus,
              errorMessage: context.watch<TripProvider>().errorMessage,
              onPickedUpStudent: (target) =>
                  _updateStudentStatus(target.id, 'picked'),
              onDroppedOffStudent: (target) =>
                  _updateStudentStatus(target.id, 'dropped'),
              onAbsentStudent: (target) =>
                  _updateStudentStatus(target.id, 'absent'),
              onChat: _openTripChat,
              onStudents: _showStudentList,
              onNotify: _showNotifyOptions,
            ),
            AppSpacing.vSm,

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Students ($_pickedCount/$_totalCount)',
                    icon: Icons.people_rounded,
                    variant: AppButtonVariant.secondary,
                    onPressed: _showStudentList,
                  ),
                ),
                AppSpacing.hSm,
                Expanded(
                  child: AppButton(
                    label: 'Complete',
                    icon: Icons.flag_rounded,
                    loading: _isEndingTrip,
                    onPressed: _completeTrip,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Show student list bottom sheet
  void _showStudentList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _StudentListBottomSheet(
        students: _buildStudentListFromStops(),
        pickedCount: _pickedCount,
        totalCount: _totalCount,
        onStudentTap: (student) {
          Navigator.pop(context);
          _showStudentDetails(student);
        },
        onChatWithGuardian: (student) {
          _chatWithGuardian(student);
        },
        onMessageAll: () {
          Navigator.pop(context);
          _showMessageAllDialog();
        },
        onUpdateStatus: (studentId, newStatus) {
          _updateStudentStatus(studentId, newStatus);
        },
        onPickAll: () {
          Navigator.pop(context);
          _pickAllStudents();
        },
        onDropAll: () {
          Navigator.pop(context);
          _dropAllStudents();
        },
      ),
    );
  }

  Future<void> _pickAllStudents() async {
    if (_tripId == null) return;

    final confirm = await confirmDialog(
      context,
      title: 'Pick All Students',
      message: 'Are you sure you want to mark all pending students as picked?',
      confirmLabel: 'Pick All',
      icon: Icons.done_all_rounded,
    );

    if (!confirm) return;

    if (!mounted) return;
    final tripProvider = context.read<TripProvider>();
    final success = await tripProvider.pickAllStudents(
      _tripId!,
      latitude: _currentLocation?.position.latitude ?? 0,
      longitude: _currentLocation?.position.longitude ?? 0,
    );

    if (success && mounted) {
      // Background refresh of the actual trip data
      final authProvider = context.read<AuthProvider>();
      if (authProvider.isDriver) {
        // Just refresh the provider so context readers see it
        await _loadActiveTrip();
      }

      setState(() {
        for (var s in _preloadedStudents) {
          if (s['status'] == 'pending') s['status'] = 'picked';
        }
        _pickedCount = _preloadedStudents
            .where((s) => s['status'] == 'picked')
            .length;

        if (_activeTrip != null) {
          _totalCount = _activeTrip!.students.length;
          _pickedCount = _activeTrip!.pickedCount;
        }
      });
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      AppSnackbar.success(context, 'All pending students marked as picked');
    }
  }

  Future<void> _dropAllStudents() async {
    if (_tripId == null) return;

    final confirm = await confirmDialog(
      context,
      title: 'Drop All Students',
      message: 'Are you sure you want to mark all picked students as dropped?',
      confirmLabel: 'Drop All',
      icon: Icons.done_all_rounded,
    );

    if (!confirm) return;

    if (!mounted) return;
    final tripProvider = context.read<TripProvider>();
    final success = await tripProvider.dropAllStudents(
      _tripId!,
      latitude: _currentLocation?.position.latitude ?? 0,
      longitude: _currentLocation?.position.longitude ?? 0,
    );

    if (success && mounted) {
      // Background refresh of the actual trip data
      final authProvider = context.read<AuthProvider>();
      if (authProvider.isDriver) {
        // Just refresh the provider so context readers see it
        await _loadActiveTrip();
      }

      setState(() {
        for (var s in _preloadedStudents) {
          if (s['status'] == 'picked') s['status'] = 'dropped';
        }
        _pickedCount = _preloadedStudents
            .where((s) => s['status'] == 'picked')
            .length;

        if (_activeTrip != null) {
          _totalCount = _activeTrip!.students.length;
          _pickedCount = _activeTrip!.pickedCount;
        }
      });
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      AppSnackbar.success(context, 'All students marked as dropped');
    }
  }

  Map<String, dynamic>? _findStudentById(String studentId) {
    for (final student in _buildStudentListFromStops()) {
      if (student['id']?.toString() == studentId) return student;
    }
    return null;
  }

  bool _studentHasSavedHomeDestination(Map<String, dynamic> student) {
    return hasValidStudentCoordinate(
          _asDouble(student['homeLatitude']),
          _asDouble(student['homeLongitude']),
        ) ||
        hasValidStudentCoordinate(
          _asDouble(student['latitude']),
          _asDouble(student['longitude']),
        );
  }

  /// Show student action dialog - Modern UI with Pick/Absent/Drop actions
  void _showStudentDetails(Map<String, dynamic> student) {
    final status = student['status'] ?? 'pending';
    final isPicked = status == 'picked';
    final isDropped = status == 'dropped';
    final isAbsent = status == 'absent';

    showDialog(
      context: context,
      builder: (context) => _StudentActionDialog(
        student: student,
        isPicked: isPicked,
        isDropped: isDropped,
        isAbsent: isAbsent,
        onPick: () => _updateStudentStatus(student['id'], 'picked'),
        onAbsent: () => _updateStudentStatus(student['id'], 'absent'),
        onDrop: () => _updateStudentStatus(student['id'], 'dropped'),
        onChat: () {
          Navigator.pop(context);
          _chatWithGuardian(student);
        },
      ),
    );
  }

  /// Update student status via provider/API, then refresh local UI state.
  Future<void> _updateStudentStatus(String studentId, String newStatus) async {
    if (_tripId == null || _isUpdatingStudentStatus) return;

    setState(() => _isUpdatingStudentStatus = true);

    // Close the sheet/dialog the action came from — but only if one is open.
    // (`canPop` alone would pop this screen itself when it was pushed.)
    if (ModalRoute.of(context)?.isCurrent == false) {
      Navigator.of(context).pop();
    }

    final tripProvider = context.read<TripProvider>();
    final success = await tripProvider.updateStudentStatus(
      tripId: _tripId!,
      studentId: studentId,
      status: newStatus,
      latitude: _currentLocation?.position.latitude,
      longitude: _currentLocation?.position.longitude,
    );

    if (!mounted) return;

    setState(() {
      _isUpdatingStudentStatus = false;
      if (success) {
        for (final student in _preloadedStudents) {
          if (student['id'] == studentId) {
            student['status'] = newStatus;
            if (newStatus == 'picked' &&
                _currentLocation != null &&
                !_studentHasSavedHomeDestination(student)) {
              student['homeLatitude'] = _currentLocation!.position.latitude;
              student['homeLongitude'] = _currentLocation!.position.longitude;
            }
            if (newStatus == 'dropped' && _currentLocation != null) {
              student['droppedLatitude'] = _currentLocation!.position.latitude;
              student['droppedLongitude'] =
                  _currentLocation!.position.longitude;
            }
            break;
          }
        }

        _activeTrip = tripProvider.activeTrip ?? _activeTrip;
        if (_preloadedStudents.isNotEmpty) {
          _totalCount = _preloadedStudents.length;
          _pickedCount = _preloadedStudents
              .where((s) => s['status'] == 'picked')
              .length;
        } else if (_activeTrip != null) {
          _totalCount = _activeTrip!.students.length;
          _pickedCount = _activeTrip!.pickedCount;
        }
      }
    });

    if (!success) {
      AppSnackbar.error(
        context,
        tripProvider.errorMessage ?? 'Failed to update status',
      );
      return;
    }

    // Enhanced haptic feedback based on action
    if (newStatus == 'picked') {
      HapticFeedback.mediumImpact();
    } else if (newStatus == 'absent') {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.lightImpact();
    }

    // Show confirmation
    final statusText = newStatus == 'picked'
        ? 'Picked up'
        : newStatus == 'absent'
        ? 'Marked absent'
        : 'Dropped off';

    if (newStatus == 'absent') {
      AppSnackbar.info(context, statusText);
    } else {
      AppSnackbar.success(context, statusText);
    }
  }

  /// Open the group chat for this active trip.
  void _openTripChat() {
    final tripId = _tripId ?? _activeTrip?.id;
    Navigator.pushNamed(
      context,
      '/chat-detail',
      arguments: {
        'tripId': tripId,
        'receiverPhone': 'trip_${tripId ?? 'active'}',
        'receiverName': _activeTrip?.routeName ?? 'Trip Chat',
        'receiverRole': 'Group',
        'isTripChat': true,
        'memberPhones': _guardianPhones(),
      },
    );
  }

  /// Chat with student's guardian
  void _chatWithGuardian(Map<String, dynamic> student) {
    final guardianPhone = student['guardianPhone'] as String?;
    final guardianId = student['guardianId'] as String?;
    final studentName = student['name'] as String? ?? 'Student';

    if (guardianPhone == null && guardianId == null) {
      AppSnackbar.info(context, 'No guardian contact available');

      return;
    }

    Navigator.pushNamed(
      context,
      '/chat-detail',
      arguments: {
        'receiverName': student['guardianName'] ?? 'Guardian of $studentName',
        'receiverPhone': guardianPhone,
        'receiverAvatar': null,
        'receiverRole': 'guardian',
        'tripId': _tripId,
        'isTripChat': true,
      },
    );
  }

  void _showNotifyOptions() {
    showAppBottomSheet<void>(
      context: context,
      builder: (context) {
        final c = context.colors;
        final options = [
          (
            Icons.schedule_rounded,
            'Running Late',
            c.warning,
            'The bus is running late.',
          ),
          (
            Icons.traffic_rounded,
            'Traffic Delay',
            c.accent,
            'Traffic is delaying the trip.',
          ),
          (
            Icons.check_circle_rounded,
            'On Schedule',
            c.brand,
            'The bus is on schedule.',
          ),
        ];
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Notify guardians',
              subtitle: 'Send a quick update to every guardian on this trip',
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            ),
            AppSpacing.vSm,
            for (final (i, o) in options.indexed)
              AppListTile(
                icon: o.$1,
                title: o.$2,
                iconColor: o.$3,
                onTap: () {
                  Navigator.pop(context);
                  _sendBulkMessage(o.$4, title: '🚌 ${o.$2}');
                },
              ).enterList(i),
            AppListTile(
              icon: Icons.edit_note_rounded,
              title: 'Custom Message',
              iconColor: c.info,
              onTap: () {
                Navigator.pop(context);
                _showMessageAllDialog();
              },
            ).enterList(options.length),
          ],
        );
      },
    );
  }

  /// Show modern dialog to send message to all guardians
  void _showMessageAllDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => _AlertAllDialog(
        studentCount: _totalCount,
        onSend: (message) {
          _sendBulkMessage(message);
        },
      ),
    );
  }

  List<String> _guardianPhones() => {
    for (final student in _buildStudentListFromStops())
      if ((student['guardianPhone'] as String?)?.isNotEmpty ?? false)
        student['guardianPhone'] as String,
  }.toList();

  Future<void> _sendBulkMessage(
    String message, {
    String title = '🚌 Message from your driver',
  }) async {
    final route = _activeTrip?.routeName;
    final sent = await context.read<TripProvider>().alertGuardians(
      phones: _guardianPhones(),
      title: title,
      message: route == null || route.isEmpty ? message : '$message ($route)',
      tripId: _tripId ?? _activeTrip?.id,
    );
    if (!mounted) return;
    if (sent == 0) {
      AppSnackbar.info(context, 'No guardian contacts available');
    } else {
      AppSnackbar.success(context, 'Alert sent to $sent guardians');
    }
  }

  Future<void> _completeTrip() async {
    setState(() => _isEndingTrip = true);

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _CompleteTripDialog(
          tripName: _activeTrip?.routeName ?? 'Trip',
          totalStudents: _totalCount,
          pickedCount: _statuses
              .where((s) => s == 'picked' || s == 'dropped')
              .length,
          absentCount: _statuses.where((s) => s == 'absent').length,
        ),
      );

      if (confirmed == true && mounted) {
        HapticFeedback.heavyImpact();

        // Show trip summary before navigating away
        await _showTripSummary();

        if (mounted) {
          final authProvider = context.read<AuthProvider>();
          final driverId = authProvider.userData['id']?.toString();
          final driverName = authProvider.userData['name']?.toString();

          final tripProvider = context.read<TripProvider>();
          final success = await tripProvider.endTrip(
            _tripId!,
            driverId: driverId,
            driverName: driverName,
          );

          if (mounted) {
            if (success) {
              AppSnackbar.success(context, 'Trip completed successfully');

              Navigator.pushNamedAndRemoveUntil(
                context,
                '/dashboard',
                (r) => false,
                arguments: {'fromTripEnd': true},
              );
            } else {
              AppSnackbar.error(
                context,
                'Failed to complete trip: '
                '${tripProvider.errorMessage ?? "Unknown error"}',
              );
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, 'Error: $e');
      }
    } finally {
      if (mounted) setState(() => _isEndingTrip = false);
    }
  }

  /// Celebratory trip summary shown after a trip is confirmed complete.
  Future<void> _showTripSummary() async {
    final absentCount = _preloadedStudents
        .where((s) => s['status'] == 'absent')
        .length;
    final droppedCount = _preloadedStudents
        .where((s) => s['status'] == 'dropped')
        .length;
    // Dropped students were picked first; count them as picked up.
    final pickedUp = _pickedCount + droppedCount;
    final endedAt = TimeOfDay.now();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final c = context.colors;
        return Dialog(
          clipBehavior: Clip.antiAlias,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.brXl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GradientHeroCard(
                borderRadius: BorderRadius.zero,
                child: Column(
                  children: [
                    TripProgress.ring(
                      done: _pickedCount + droppedCount,
                      total: _totalCount,
                      onBrand: true,
                      size: 88,
                      thickness: 8,
                      center: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 40,
                      ).pop(delay: const Duration(milliseconds: 350)),
                    ),
                    AppSpacing.vMd,
                    Text(
                      'Trip Complete!',
                      style: context.text.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    AppSpacing.vXxs,
                    Text(
                      _activeTrip?.routeName ?? '-',
                      textAlign: TextAlign.center,
                      style: context.text.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ).celebrate(delay: const Duration(milliseconds: 500)),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: StatTile(
                            icon: Icons.check_circle_rounded,
                            value: '$pickedUp',
                            label: 'Picked',
                            color: c.brand,
                          ),
                        ),
                        Expanded(
                          child: StatTile(
                            icon: Icons.cancel_rounded,
                            value: '$absentCount',
                            label: 'Absent',
                            color: c.warning,
                          ),
                        ),
                        if (droppedCount > 0)
                          Expanded(
                            child: StatTile(
                              icon: Icons.home_rounded,
                              value: '$droppedCount',
                              label: 'Dropped',
                              color: c.info,
                            ),
                          ),
                        Expanded(
                          child: StatTile(
                            icon: Icons.groups_rounded,
                            value: '$_totalCount',
                            label: 'Total',
                          ),
                        ),
                      ],
                    ).enter(delay: const Duration(milliseconds: 200)),
                    AppSpacing.vMd,
                    Text(
                      'Ended at ${endedAt.format(context)} · '
                      '${_totalCount > 0 ? (pickedUp / _totalCount * 100).toInt() : 0}% pickup rate',
                      style: context.text.bodySmall?.copyWith(
                        color: c.textSecondary,
                      ),
                    ),
                    AppSpacing.vLg,
                    AppButton(
                      label: 'Done',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Convert preloaded TripStudent objects to map format for UI
  List<Map<String, dynamic>> _convertTripStudentsToMap(
    List<TripStudent> students,
  ) {
    return students.asMap().entries.map((entry) {
      final index = entry.key;
      final s = entry.value;
      return {
        'id': s.studentId.toString(),
        'tripStudentId': s.id.toString(),
        'name': s.fullname,
        'stopName': s.route,
        'route': s.route,
        'address': s.address,
        'status': s.isStudentDropped
            ? 'dropped'
            : s.isStudentPicked
            ? 'picked'
            : !s.isStudentActive
            ? 'absent'
            : 'pending',
        'guardianPhone': s.guardianPhoneNumber,
        'guardianId': s.guardianPhoneNumber,
        'guardianName': s.guardianPhoneNumber,
        'studentRegNumber': s.studentRegNumber,
        'className': s.classname,
        'schoolName': s.schoolname,
        'transportOrg': s.transportOrg,
        'photo': s.profileImage,
        'latitude': s.latitude,
        'longitude': s.longitude,
        'homeLatitude': s.pickedLatitude != 0 ? s.pickedLatitude : s.latitude,
        'homeLongitude': s.pickedLongitude != 0
            ? s.pickedLongitude
            : s.longitude,
        'pickedLatitude': s.pickedLatitude,
        'pickedLongitude': s.pickedLongitude,
        'droppedLatitude': s.droppedLatitude,
        'droppedLongitude': s.droppedLongitude,
        'pickupTime': s.pickedTime,
        'dropoffTime': s.dropTime,
        'order': index,
      };
    }).toList();
  }

  /// Build student list from stops data or use preloaded students
  List<Map<String, dynamic>> _buildStudentListFromStops() {
    // If we have preloaded students, use those
    if (_preloadedStudents.isNotEmpty) {
      return _preloadedStudents;
    }

    // Use actual students from the active trip
    if (_activeTrip != null && _activeTrip!.students.isNotEmpty) {
      return _activeTrip!.students.asMap().entries.map((entry) {
        final s = entry.value;
        final stop = _stops.firstWhere(
          (stop) => stop.studentIds?.contains(s.id) ?? false,
          orElse: () => RouteStop(
            id: '',
            name: s.route ?? 'Unknown Stop',
            position: LatLng(s.latitude ?? 0, s.longitude ?? 0),
            order: entry.key,
          ),
        );

        return {
          'id': s.id,
          'tripStudentId': s.tripStudentId,
          'name': s.name,
          'stopName': stop.name,
          'status': s.status,
          'guardianPhone': s.parentPhone,
          'guardianId': null,
          'guardianName': null,
          'photo': s.photo,
          'studentRegNumber': s.studentRegNumber,
          'className': s.className,
          'schoolName': s.schoolName,
          'route': s.route,
          'address': s.address ?? stop.address,
          'latitude': s.latitude ?? stop.position.latitude,
          'longitude': s.longitude ?? stop.position.longitude,
          'homeLatitude': s.homeLatitude,
          'homeLongitude': s.homeLongitude,
          'pickedLatitude': s.pickedLatitude,
          'pickedLongitude': s.pickedLongitude,
          'droppedLatitude': s.droppedLatitude,
          'droppedLongitude': s.droppedLongitude,
          'pickupTime': s.pickupTime,
          'dropoffTime': s.dropoffTime,
          'order': stop.order == 0 ? entry.key : stop.order,
        };
      }).toList();
    }

    // Fallback to stops if no students in trip
    final List<Map<String, dynamic>> students = [];
    for (final stop in _stops) {
      if (stop.studentIds != null && stop.studentIds!.isNotEmpty) {
        for (final studentId in stop.studentIds!) {
          students.add({
            'id': studentId,
            'name': 'Student $studentId',
            'stopName': stop.name,
            'status': _processedStops.contains(stop.id) ? 'picked' : 'pending',
            'guardianPhone': stop.guardianPhone,
            'guardianId': null,
            'guardianName': null,
            'address': stop.address,
            'latitude': stop.position.latitude,
            'longitude': stop.position.longitude,
            'homeLatitude': stop.position.latitude,
            'homeLongitude': stop.position.longitude,
            'order': stop.order,
          });
        }
      }
    }

    return students;
  }
}

/// Student List Bottom Sheet
class _StudentListBottomSheet extends StatelessWidget {
  final List<Map<String, dynamic>> students;
  final int pickedCount;
  final int totalCount;
  final Function(Map<String, dynamic>) onStudentTap;
  final Function(Map<String, dynamic>) onChatWithGuardian;
  final VoidCallback onMessageAll;
  final Function(String, String) onUpdateStatus;
  final VoidCallback onPickAll;
  final VoidCallback onDropAll;

  const _StudentListBottomSheet({
    required this.students,
    required this.pickedCount,
    required this.totalCount,
    required this.onStudentTap,
    required this.onChatWithGuardian,
    required this.onMessageAll,
    required this.onUpdateStatus,
    required this.onPickAll,
    required this.onDropAll,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: context.scheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: AppSpacing.sm),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: c.outline,
              borderRadius: AppRadius.brPill,
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                TripProgress.ring(
                  done: pickedCount,
                  total: totalCount,
                  size: 52,
                  thickness: 5,
                ),
                AppSpacing.hMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Students', style: context.text.headlineSmall),
                      Text(
                        '$pickedCount of $totalCount picked up',
                        style: context.text.bodyMedium?.copyWith(
                          color: c.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onMessageAll,
                  icon: Icon(Icons.campaign_rounded, color: c.brand),
                  tooltip: 'Alert all guardians',
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),

          if (students.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Column(
                children: [
                  AppButton(
                    label: 'Alert All Guardians (${students.length})',
                    icon: Icons.campaign_rounded,
                    size: AppButtonSize.medium,
                    onPressed: onMessageAll,
                  ),
                  AppSpacing.vSm,
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: 'Pick All',
                          icon: Icons.done_all_rounded,
                          variant: AppButtonVariant.secondary,
                          size: AppButtonSize.medium,
                          onPressed: onPickAll,
                        ),
                      ),
                      AppSpacing.hSm,
                      Expanded(
                        child: AppButton(
                          label: 'Drop All',
                          icon: Icons.home_rounded,
                          variant: AppButtonVariant.outline,
                          size: AppButtonSize.medium,
                          onPressed: onDropAll,
                        ),
                      ),
                    ],
                  ),
                ],
              ).enter(),
            ),

          // Student list
          Expanded(
            child: students.isEmpty
                ? const EmptyState(
                    icon: Icons.people_outline_rounded,
                    title: 'No students in this trip',
                    compact: true,
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    itemCount: students.length,
                    separatorBuilder: (_, _) => AppSpacing.vXs,
                    itemBuilder: (context, index) {
                      final student = students[index];
                      final String status = student['status'] ?? 'pending';
                      final isPicked = status == 'picked';
                      final isPending = status == 'pending';
                      final id = student['id'].toString();
                      final hasGuardian =
                          student['guardianPhone'] != null ||
                          student['guardianId'] != null;

                      final row = StudentStatusRow(
                        name: student['name'] ?? 'Student ${index + 1}',
                        status: status,
                        photoUrl: student['photo'] as String?,
                        subtitle: student['stopName'] ?? 'No stop assigned',
                        onTap: () => onStudentTap(student),
                        trailing: isPending
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildMiniActionButton(
                                    icon: Icons.check_rounded,
                                    color: c.brand,
                                    tooltip: 'Pick up',
                                    onTap: () => onUpdateStatus(id, 'picked'),
                                  ),
                                  const SizedBox(width: 6),
                                  _buildMiniActionButton(
                                    icon: Icons.person_off_rounded,
                                    color: c.warning,
                                    tooltip: 'Mark absent',
                                    onTap: () => onUpdateStatus(id, 'absent'),
                                  ),
                                ],
                              )
                            : hasGuardian
                            ? IconButton(
                                onPressed: () => onChatWithGuardian(student),
                                icon: const Icon(
                                  Icons.chat_bubble_outline_rounded,
                                ),
                                color: c.brand,
                                tooltip: 'Chat with guardian',
                              )
                            : null,
                      ).enterList(index);

                      if (!isPending && !isPicked) return row;

                      // Pending: swipe right to pick up, left for absent.
                      // Picked: swipe right to drop off.
                      return SwipeAction(
                        key: ValueKey('bs_swipe_$id'),
                        start: SwipeSpec(
                          label: isPending ? 'Pick Up' : 'Drop Off',
                          icon: isPending
                              ? Icons.check_circle_rounded
                              : Icons.home_rounded,
                          color: isPending ? c.brand : c.info,
                          onTrigger: () async {
                            onUpdateStatus(
                              id,
                              isPending ? 'picked' : 'dropped',
                            );
                            return false;
                          },
                        ),
                        end: isPending
                            ? SwipeSpec(
                                label: 'Absent',
                                icon: Icons.cancel_rounded,
                                color: c.warning,
                                onTrigger: () async {
                                  onUpdateStatus(id, 'absent');
                                  return false;
                                },
                              )
                            : null,
                        child: row,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniActionButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: PressScale(
        scale: 0.9,
        child: Material(
          color: color.withValues(alpha: 0.12),
          borderRadius: AppRadius.brSm,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.brSm,
            child: SizedBox.square(
              dimension: 40,
              child: Icon(icon, color: color, size: AppIconSize.md),
            ),
          ),
        ),
      ),
    );
  }
}

/// Student action dialog: status-tinted header with Pick / Absent / Drop.
class _StudentActionDialog extends StatelessWidget {
  final Map<String, dynamic> student;
  final bool isPicked;
  final bool isDropped;
  final bool isAbsent;
  final VoidCallback onPick;
  final VoidCallback onAbsent;
  final VoidCallback onDrop;
  final VoidCallback onChat;

  const _StudentActionDialog({
    required this.student,
    required this.isPicked,
    required this.isDropped,
    required this.isAbsent,
    required this.onPick,
    required this.onAbsent,
    required this.onDrop,
    required this.onChat,
  });

  String get _status => isPicked
      ? 'picked'
      : isDropped
      ? 'dropped'
      : isAbsent
      ? 'absent'
      : 'pending';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final studentName = student['name'] ?? 'Student';
    final stopName = student['stopName'] as String?;
    final guardianPhone = student['guardianPhone'] as String?;
    final studentClass = student['class'] ?? student['className'] ?? '';
    final style = StudentStatusStyle.of(context, _status);
    // Pending reads as the brand; any settled status tints the header.
    final headerColor = _status == 'pending' ? c.brand : style.color;

    return Dialog(
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.brXl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with avatar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.xl,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    headerColor,
                    Color.alphaBlend(
                      Colors.black.withValues(alpha: 0.25),
                      headerColor,
                    ),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Close',
                      icon: const Icon(Icons.close_rounded),
                      color: Colors.white,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                  StatusAvatar(
                    name: studentName,
                    photoUrl: student['photo'] as String?,
                    color: Colors.white,
                    size: 80,
                  ).pop(),
                  AppSpacing.vMd,
                  Text(
                    studentName,
                    textAlign: TextAlign.center,
                    style: context.text.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (studentClass.isNotEmpty)
                    Text(
                      studentClass,
                      style: context.text.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  AppSpacing.vXs,
                  StatusPill(
                    label: _status == 'pending'
                        ? 'Pending Pickup'
                        : style.label,
                    color: Colors.white,
                    icon: style.icon,
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (stopName != null)
                    _buildInfoRow(
                      context,
                      Icons.location_on_outlined,
                      'Stop',
                      stopName,
                    ),
                  if (guardianPhone != null)
                    _buildInfoRow(
                      context,
                      Icons.phone_outlined,
                      'Guardian',
                      guardianPhone,
                    ),
                  AppSpacing.vSm,
                  Text(
                    'Actions',
                    style: context.text.labelLarge?.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
                  AppSpacing.vSm,
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.check_circle_rounded,
                          label: 'Pick',
                          color: c.brand,
                          isActive: isPicked,
                          onTap: isPicked ? null : onPick,
                        ).enterList(0),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.person_off_rounded,
                          label: 'Absent',
                          color: c.warning,
                          isActive: isAbsent,
                          onTap: isAbsent ? null : onAbsent,
                        ).enterList(1),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.home_rounded,
                          label: 'Drop',
                          color: c.info,
                          isActive: isDropped,
                          onTap: isDropped ? null : onDrop,
                        ).enterList(2),
                      ),
                    ],
                  ),
                  if (guardianPhone != null) ...[
                    AppSpacing.vMd,
                    AppButton(
                      label: 'Chat with Guardian',
                      icon: Icons.chat_bubble_outline_rounded,
                      variant: AppButtonVariant.secondary,
                      onPressed: onChat,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final muted = context.colors.textMuted;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 18, color: muted),
          AppSpacing.hXs,
          Text(
            '$label: ',
            style: context.text.bodySmall?.copyWith(color: muted),
          ),
          Expanded(
            child: Text(
              value,
              style: context.text.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool isActive,
    required VoidCallback? onTap,
  }) {
    return PressScale(
      enabled: onTap != null,
      child: Material(
        color: isActive ? color : color.withValues(alpha: 0.1),
        borderRadius: AppRadius.brSm,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.brSm,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              borderRadius: AppRadius.brSm,
              border: Border.all(
                color: isActive ? color : color.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                Icon(icon, color: isActive ? Colors.white : color, size: 24),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: isActive ? Colors.white : color,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Modern Alert All Guardians Dialog
class _AlertAllDialog extends StatefulWidget {
  final int studentCount;
  final Function(String) onSend;

  const _AlertAllDialog({required this.studentCount, required this.onSend});

  @override
  State<_AlertAllDialog> createState() => _AlertAllDialogState();
}

class _AlertAllDialogState extends State<_AlertAllDialog> {
  final TextEditingController _messageController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final quickMessages = [
      (Icons.schedule_rounded, 'Running late', c.warning),
      (Icons.traffic_rounded, 'Traffic delay', c.error),
      (Icons.access_time_filled_rounded, 'Arriving soon', c.brand),
      (Icons.location_on_rounded, 'At the stop', c.info),
    ];
    final canSend = !_isSending && _messageController.text.trim().isNotEmpty;

    return Dialog(
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xl,
      ),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.brXl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 600),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GradientHeroCard(
                borderRadius: BorderRadius.zero,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.sm,
                  AppSpacing.sm,
                  AppSpacing.xl,
                ),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        tooltip: 'Close',
                        icon: const Icon(Icons.close_rounded),
                        color: Colors.white,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4),
                          width: 3,
                        ),
                      ),
                      child: const Icon(
                        Icons.campaign_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ).pop(),
                    AppSpacing.vMd,
                    Text(
                      'Alert All Guardians',
                      style: context.text.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    AppSpacing.vXxs,
                    Text(
                      'Message will be sent to ${widget.studentCount} guardians',
                      style: context.text.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick Messages',
                      style: context.text.labelLarge?.copyWith(
                        color: c.textSecondary,
                      ),
                    ),
                    AppSpacing.vSm,
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        for (final (i, m) in quickMessages.indexed)
                          ActionChip(
                            avatar: Icon(m.$1, size: 16, color: m.$3),
                            label: Text(m.$2),
                            labelStyle: context.text.labelMedium?.copyWith(
                              color: m.$3,
                              fontWeight: FontWeight.w600,
                            ),
                            backgroundColor: m.$3.withValues(alpha: 0.1),
                            side: BorderSide(
                              color: m.$3.withValues(alpha: 0.3),
                            ),
                            shape: const StadiumBorder(),
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              setState(() => _messageController.text = m.$2);
                            },
                          ).enterList(i),
                      ],
                    ),
                    AppSpacing.vLg,
                    AppTextField(
                      label: 'Custom Message',
                      controller: _messageController,
                      hint: 'Type your alert message…',
                      maxLines: 3,
                      onChanged: (_) => setState(() {}),
                    ),
                    AppSpacing.vXs,
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${_messageController.text.length} chars',
                        style: context.text.labelSmall?.copyWith(
                          color: c.textMuted,
                        ),
                      ),
                    ),
                    AppSpacing.vMd,
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            label: 'Cancel',
                            variant: AppButtonVariant.tertiary,
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                        AppSpacing.hSm,
                        Expanded(
                          flex: 2,
                          child: AppButton(
                            label: 'Send Alert',
                            icon: Icons.send_rounded,
                            loading: _isSending,
                            onPressed: canSend
                                ? () async {
                                    setState(() => _isSending = true);
                                    widget.onSend(
                                      _messageController.text.trim(),
                                    );
                                    await Future.delayed(
                                      const Duration(milliseconds: 500),
                                    );
                                    if (!context.mounted) return;
                                    Navigator.pop(context);
                                  }
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Complete Trip Dialog - Professional confirmation dialog with trip summary
class _CompleteTripDialog extends StatelessWidget {
  final String tripName;
  final int totalStudents;
  final int pickedCount;
  final int absentCount;

  const _CompleteTripDialog({
    required this.tripName,
    required this.totalStudents,
    required this.pickedCount,
    required this.absentCount,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final completionRate = totalStudents > 0
        ? pickedCount / totalStudents
        : 0.0;
    final isComplete = completionRate >= 1.0;
    final tone = isComplete ? c.brand : c.warning;
    // Named for what it really counts: everyone not picked up yet.
    final notPicked = absentCount;

    return Dialog(
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xl,
      ),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.brXl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.xl,
                  AppSpacing.xl,
                  AppSpacing.lg,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      tone,
                      Color.alphaBlend(
                        Colors.black.withValues(alpha: 0.22),
                        tone,
                      ),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  children: [
                    TripProgress.ring(
                      done: pickedCount,
                      total: totalStudents,
                      onBrand: true,
                      size: 84,
                      thickness: 8,
                    ),
                    AppSpacing.vSm,
                    Text(
                      isComplete ? 'Ready to Complete?' : 'Trip Not Complete',
                      textAlign: TextAlign.center,
                      style: context.text.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    AppSpacing.vXxs,
                    Text(
                      tripName,
                      textAlign: TextAlign.center,
                      style: context.text.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _buildStatCard(
                          context,
                          value: totalStudents,
                          label: 'Students',
                          icon: Icons.people_outline_rounded,
                          color: c.info,
                        ),
                        const SizedBox(width: 10),
                        _buildStatCard(
                          context,
                          value: pickedCount,
                          label: 'Picked Up',
                          icon: Icons.check_circle_outline_rounded,
                          color: c.brand,
                        ),
                        const SizedBox(width: 10),
                        _buildStatCard(
                          context,
                          value: notPicked,
                          label: 'Not picked',
                          icon: Icons.person_off_outlined,
                          color: c.warning,
                        ),
                      ],
                    ).enter(delay: const Duration(milliseconds: 120)),
                    if (!isComplete) ...[
                      AppSpacing.vMd,
                      StatusPill(
                        label: '$notPicked students not yet picked up',
                        color: c.warning,
                        icon: Icons.info_outline_rounded,
                      ),
                    ],
                    AppSpacing.vMd,
                    AppCard(
                      color: c.surfaceSubtle,
                      shadow: const [],
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.notifications_active_outlined,
                            color: c.brand,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Guardian Notification',
                                  style: context.text.labelLarge,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'All guardians will be notified that the trip has ended.',
                                  style: context.text.bodySmall?.copyWith(
                                    color: c.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    AppSpacing.vLg,
                    AppButton(
                      label: isComplete ? 'Complete Trip' : 'Complete Anyway',
                      icon: isComplete
                          ? Icons.check_circle_rounded
                          : Icons.warning_rounded,
                      variant: isComplete
                          ? AppButtonVariant.primary
                          : AppButtonVariant.danger,
                      onPressed: () => Navigator.pop(context, true),
                    ),
                    AppSpacing.vXs,
                    AppButton(
                      label: 'Go Back',
                      variant: AppButtonVariant.tertiary,
                      onPressed: () => Navigator.pop(context, false),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required int value,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: AppRadius.brSm,
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: StatTile(
          icon: icon,
          value: '$value',
          label: label,
          color: color,
        ),
      ),
    );
  }
}
// ============================================================================
// MAP OVERLAY WIDGETS
// ============================================================================

/// Round floating map control. [highlighted] gives the brand fill used for
/// the primary "center on bus" action.
class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.highlighted = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final button = PressScale(
      scale: 0.9,
      enabled: onPressed != null,
      child: Material(
        color: highlighted ? c.brand : context.scheme.surface,
        shape: const CircleBorder(),
        elevation: 0,
        shadowColor: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: c.shadowMd,
            border: highlighted ? null : Border.all(color: c.outline),
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed == null
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    onPressed!();
                  },
            child: SizedBox.square(
              dimension: 44,
              child: AnimatedSwitcher(
                duration: AppDuration.medium,
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: Icon(
                  icon,
                  key: ValueKey(icon),
                  size: AppIconSize.md,
                  color: highlighted
                      ? context.scheme.onPrimary
                      : context.scheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Small live readout (speed, heading) whose number rolls as it updates.
class _TelemetryChip extends StatelessWidget {
  const _TelemetryChip({
    required this.icon,
    required this.value,
    required this.unit,
  });

  final IconData icon;
  final int value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final style = context.text.labelMedium?.copyWith(
      color: context.scheme.onSurface,
      fontWeight: FontWeight.w700,
    );
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: c.surfaceSubtle,
        borderRadius: AppRadius.brPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppIconSize.sm, color: c.accent),
          const SizedBox(width: 6),
          AnimatedCount(value, style: style, suffix: unit),
        ],
      ),
    );
  }
}
