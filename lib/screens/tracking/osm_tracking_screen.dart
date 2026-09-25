import 'dart:async';
import 'dart:developer' as developer;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:provider/provider.dart';
import '../../config/map_config.dart';
import '../../services/mapbox_service.dart';
import '../../api/services/student_service.dart' as student_api;
import '../../api/services/trip_service.dart';
import '../../models/master_trip.dart';
import '../../models/preloaded_trip_data.dart';
import '../../providers/auth_provider.dart';
import '../../providers/trip_provider.dart';
import '../../utils/student_trip_logic.dart';
import '../../widgets/add_trip_student_sheet.dart';
import '../../widgets/next_student_trip_action_card.dart';
import '../../widgets/ui/ui.dart';

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
  final Map<String, dynamic>? preloadedData;

  const OsmTrackingScreen({
    super.key,
    this.tripId,
    this.busId,
    this.routeId,
    this.preloadedData,
  });

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
  PointAnnotationManager? _studentAnnotationManager;
  PolylineAnnotationManager? _polylineAnnotationManager;
  PointAnnotation? _busAnnotation;
  bool _isCreatingBusAnnotation = false;
  bool _isBusUpdateInFlight = false;
  bool _hasPendingBusUpdate = false;

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
  PreloadedTripData? _preloadedData;
  List<TripStudent> _students = [];
  RouteResult? _routeResult;

  // State
  bool _isLoading = true;
  bool _isLoadingRoute = false;
  bool _isUpdatingStudentStatus = false;
  bool _isEndingTrip = false;
  String? _errorMessage;
  String? _statusErrorMessage;
  final Map<int, String> _studentStatusUpdates = {};
  final Set<String> _shownStudentProximityAlerts = {};
  Future<List<student_api.Student>>? _schoolStudents;

  // Provider reference kept for listener add/remove. The provider is the single
  // source of truth for student status shared with the students-list screen.
  TripProvider? _tripProvider;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2), // Smooth 2s interpolation
    )..addListener(_onAnimationUpdate);

    _initializeMapbox();
    _loadPreloadedData();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _tripProvider = context.read<TripProvider>();
      _tripProvider?.addListener(_onTripProviderChanged);
      await _loadProviderTripData();
      _syncRosterToProvider();
      _onTripProviderChanged();
      _initializeLocation();
      _loadTripData();
    });
  }

  @override
  void dispose() {
    _tripProvider?.removeListener(_onTripProviderChanged);
    _animationController.stop();
    _animationController.dispose();
    _positionStream?.cancel();
    _hasPendingBusUpdate = false;
    _busAnnotation = null;
    _pointAnnotationManager = null;
    _studentAnnotationManager = null;
    _polylineAnnotationManager = null;
    _mapboxMap = null;
    // MapWidget owns the MapboxMap and disposes it with its platform view.
    super.dispose();
  }

  /// Mirror status changes made elsewhere (e.g. picks on the students-list
  /// screen, which go through TripProvider) into this screen's local status
  /// cache so the info panel and next-pickup card stay in sync. Keyed by
  /// student id: [StudentPickup.id] parses to [TripStudent.studentId].
  void _onTripProviderChanged() {
    if (!mounted) return;
    final providerTrip = _tripProvider?.activeTrip;
    if (providerTrip == null || providerTrip.students.isEmpty) return;

    var changed = false;
    for (final student in providerTrip.students) {
      final key = int.tryParse(student.id);
      if (key == null) continue;
      final normalized = StudentPickup.normalizeStatus(student.status);
      if (_studentStatusUpdates[key] != normalized) {
        _studentStatusUpdates[key] = normalized;
        changed = true;
      }
    }

    if (changed) {
      setState(() {});
      _updateMarkers();
    }
  }

  /// Seed the provider with this screen's roster. Every pick/drop/absent goes
  /// through TripProvider, and it can only alert a guardian for a student it
  /// holds. Merge keeps whichever status is further along.
  void _syncRosterToProvider() {
    if (_students.isEmpty) return;
    _tripProvider?.hydrateActiveTrip(
      roster: _students.map((s) => StudentPickup.fromJson(s.toJson())).toList(),
      vehicleNumber: _numberPlate,
      routeName: _routeName,
    );
  }

  String? get _tripDirection =>
      _trip?.tripDirection ?? _preloadedData?.masterTrip.tripDirection;

  String? get _activeTripId {
    final id = widget.tripId ?? _trip?.id ?? _tripProvider?.activeTrip?.id;
    return id == null || id.trim().isEmpty ? null : id;
  }

  String get _routeName =>
      _trip?.routeName ??
      _preloadedData?.masterTrip.tripName ??
      _preloadedData?.masterTrip.route ??
      'Live Tracking';

  String get _vehicleLabel {
    final vehicleNumber =
        _trip?.vehicleNumber ??
        _preloadedData?.vehicle?.registrationNumber ??
        _preloadedData?.masterTrip.numberPlate;
    if (vehicleNumber != null && vehicleNumber.isNotEmpty) {
      return vehicleNumber;
    }

    final vehicleId = _trip?.vehicleId ?? widget.busId;
    return vehicleId == null || vehicleId.isEmpty ? 'Bus' : 'Bus $vehicleId';
  }

  /// Raw vehicle number plate (no "Bus" label) for API calls that require it.
  String? get _numberPlate =>
      _trip?.vehicleNumber ??
      _preloadedData?.vehicle?.registrationNumber ??
      _preloadedData?.masterTrip.numberPlate;

  int? get _resolvedMasterTripId {
    return _trip?.masterTripId ??
        _preloadedData?.masterTrip.id ??
        int.tryParse(widget.routeId ?? '') ??
        int.tryParse(_trip?.routeId ?? '');
  }

  void _onAnimationUpdate() {
    if (!mounted || _busAnnotation == null || _pointAnnotationManager == null) {
      return;
    }

    final lat = _latAnimation?.value ?? _currentPosition?.latitude ?? 0.0;
    final lng = _lngAnimation?.value ?? _currentPosition?.longitude ?? 0.0;
    final bearing =
        _bearingAnimation?.value ?? _currentPosition?.heading ?? 0.0;

    _busAnnotation!.geometry = Point(coordinates: Position(lng, lat));
    _busAnnotation!.iconRotate = bearing;
    _scheduleBusAnnotationUpdate();
  }

  /// Coalesce animation frames while a platform update is in flight. Sending
  /// one update per frame can otherwise leave stale native calls queued while
  /// the map is being torn down.
  void _scheduleBusAnnotationUpdate() {
    _hasPendingBusUpdate = true;
    if (_isBusUpdateInFlight) return;

    _isBusUpdateInFlight = true;
    unawaited(_flushBusAnnotationUpdates());
  }

  Future<void> _flushBusAnnotationUpdates() async {
    try {
      while (mounted && _hasPendingBusUpdate) {
        _hasPendingBusUpdate = false;
        final manager = _pointAnnotationManager;
        final annotation = _busAnnotation;
        if (manager == null || annotation == null) return;

        await manager.update(annotation);
        if (!identical(manager, _pointAnnotationManager) ||
            !identical(annotation, _busAnnotation)) {
          return;
        }
      }
    } catch (error, stackTrace) {
      if (mounted) {
        developer.log(
          'Failed to update bus annotation: $error',
          name: 'TrackingScreen',
          stackTrace: stackTrace,
        );
      }
    } finally {
      _isBusUpdateInFlight = false;
      if (mounted && _hasPendingBusUpdate) {
        _scheduleBusAnnotationUpdate();
      }
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

    if (!mounted || !identical(_mapboxMap, mapboxMap)) return;

    try {
      final busManager = await mapboxMap.annotations
          .createPointAnnotationManager();
      if (!mounted || !identical(_mapboxMap, mapboxMap)) return;
      _pointAnnotationManager = busManager;

      // Student markers are rebuilt as their pickup state changes. Keeping
      // them in a separate manager means deleteAll() never invalidates the
      // bus annotation that the animation loop updates.
      final studentManager = await mapboxMap.annotations
          .createPointAnnotationManager();
      if (!mounted || !identical(_mapboxMap, mapboxMap)) return;
      _studentAnnotationManager = studentManager;

      final polylineManager = await mapboxMap.annotations
          .createPolylineAnnotationManager();
      if (!mounted || !identical(_mapboxMap, mapboxMap)) return;
      _polylineAnnotationManager = polylineManager;

      await _updateMarkers();
      if (_routeResult != null) {
        await _updateRouteLine();
      }
    } catch (error, stackTrace) {
      if (mounted) {
        developer.log(
          'Failed to initialize map annotations: $error',
          name: 'TrackingScreen',
          stackTrace: stackTrace,
        );
      }
    }
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
      await _updateDriverMarker();
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

  void _loadPreloadedData() {
    final rawData = widget.preloadedData;
    if (rawData == null) return;

    try {
      final preloadedData = PreloadedTripData.fromJson(rawData);
      if (preloadedData.students.isEmpty) return;

      _preloadedData = preloadedData;
      _students = List<TripStudent>.from(preloadedData.students);
      _isLoading = false;
    } catch (e) {
      developer.log(
        'Failed to parse preloaded trip data: $e',
        name: 'TrackingScreen',
      );
    }
  }

  Future<void> _loadProviderTripData() async {
    if (!mounted || _students.isNotEmpty) return;

    final activeTrip = context.read<TripProvider>().activeTrip;
    if (activeTrip == null) return;
    if (activeTrip.students.isEmpty) {
      await _loadMasterTripStudentsFallback(
        activeTrip.masterTripId ?? int.tryParse(activeTrip.routeId),
      );
      return;
    }

    setState(() {
      _students = activeTrip.students
          .map(
            (s) => _tripStudentFromPickup(
              id: s.id,
              masterTripId: activeTrip.masterTripId ?? 0,
              name: s.name,
              parentPhone: s.parentPhone,
              route: s.route,
              latitude: s.latitude,
              longitude: s.longitude,
              pickedLatitude: s.pickedLatitude,
              pickedLongitude: s.pickedLongitude,
              droppedLatitude: s.droppedLatitude,
              droppedLongitude: s.droppedLongitude,
              status: s.status,
              photo: s.photo,
              address: s.address,
              studentRegNumber: s.studentRegNumber,
              className: s.className,
              schoolName: s.schoolName,
            ),
          )
          .toList();
      _isLoading = false;
      _errorMessage = null;
    });
  }

  TripStudent _tripStudentFromPickup({
    required String id,
    required int masterTripId,
    required String name,
    String? parentPhone,
    String? route,
    double? latitude,
    double? longitude,
    double? pickedLatitude,
    double? pickedLongitude,
    double? droppedLatitude,
    double? droppedLongitude,
    required String status,
    String? photo,
    String? address,
    String? studentRegNumber,
    String? className,
    String? schoolName,
  }) {
    final normalizedStatus = status.trim().toLowerCase();

    return TripStudent(
      id: int.tryParse(id) ?? 0,
      masterTripId: masterTripId,
      studentId: int.tryParse(id) ?? 0,
      fullname: name,
      studentRegNumber: studentRegNumber ?? '',
      guardianPhoneNumber: parentPhone ?? '',
      schoolname: schoolName ?? '',
      transportOrg: '',
      classname: className ?? '',
      route: route ?? '',
      latitude: latitude ?? 0,
      longitude: longitude ?? 0,
      pickedLatitude: pickedLatitude ?? 0,
      pickedLongitude: pickedLongitude ?? 0,
      droppedLatitude: droppedLatitude ?? 0,
      droppedLongitude: droppedLongitude ?? 0,
      isStudentPicked: normalizedStatus == 'picked',
      isStudentDropped: normalizedStatus == 'dropped',
      profileImage: photo ?? '',
      address: address ?? '',
      createdBy: '',
      hasStudentPaid: false,
      isStudentActive: normalizedStatus != 'absent',
      isStudentDeleted: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Future<void> _loadTripData() async {
    if (widget.tripId == null) {
      setState(() {
        _isLoading = false;
        if (_students.isEmpty) {
          _errorMessage = 'No trip ID provided';
        }
      });
      return;
    }

    try {
      final trip = await _tripService.getTripDetails(widget.tripId!);
      if (trip != null) {
        final fetchedStudents = trip.students
            .map(
              (s) => _tripStudentFromPickup(
                id: s.id,
                masterTripId: trip.masterTripId ?? 0,
                name: s.name,
                parentPhone: s.parentPhone,
                route: s.route,
                latitude: s.latitude,
                longitude: s.longitude,
                pickedLatitude: s.pickedLatitude,
                pickedLongitude: s.pickedLongitude,
                droppedLatitude: s.droppedLatitude,
                droppedLongitude: s.droppedLongitude,
                status: s.status,
                photo: s.photo,
                address: s.address,
                studentRegNumber: s.studentRegNumber,
                className: s.className,
                schoolName: s.schoolName,
              ),
            )
            .toList();

        setState(() {
          _trip = trip;
          if (fetchedStudents.isNotEmpty) {
            _students = fetchedStudents;
          }
          _errorMessage = null;
          _isLoading = false;
        });
        if (fetchedStudents.isEmpty) {
          await _loadMasterTripStudentsFallback(_resolvedMasterTripId);
        }
        _syncRosterToProvider();
        _calculateRoute();
      } else {
        setState(() {
          _isLoading = false;
          if (_students.isEmpty) {
            _errorMessage = 'Trip not found';
          }
        });
        await _loadMasterTripStudentsFallback(_resolvedMasterTripId);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        if (_students.isEmpty) {
          _errorMessage = 'Error loading trip: $e';
        }
      });
      await _loadMasterTripStudentsFallback(_resolvedMasterTripId);
    }
  }

  Future<void> _loadMasterTripStudentsFallback(int? masterTripId) async {
    if (masterTripId == null || masterTripId <= 0 || _students.isNotEmpty) {
      return;
    }

    try {
      final students = await _tripService.getMasterTripStudents(masterTripId);
      if (!mounted || students.isEmpty) return;

      setState(() {
        _students = students;
        _isLoading = false;
        _errorMessage = null;
      });
      _syncRosterToProvider();
    } catch (e) {
      developer.log(
        'Failed to load master trip students: $e',
        name: 'TrackingScreen',
      );
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
    if (!mounted) return;

    try {
      await _updateDriverMarker();

      final manager = _studentAnnotationManager;
      if (manager == null) return;
      await manager.deleteAll();
      if (!mounted || !identical(manager, _studentAnnotationManager)) return;

      for (final student in _students) {
        await _addStudentMarker(student);
        if (!mounted || !identical(manager, _studentAnnotationManager)) return;
      }
    } catch (error, stackTrace) {
      if (mounted) {
        developer.log(
          'Failed to rebuild map markers: $error',
          name: 'TrackingScreen',
          stackTrace: stackTrace,
        );
      }
    }
  }

  /// Update driver marker on map
  Future<void> _updateDriverMarker() async {
    final manager = _pointAnnotationManager;
    final position = _currentPosition;
    if (!mounted ||
        manager == null ||
        position == null ||
        _busAnnotation != null ||
        _isCreatingBusAnnotation) {
      return;
    }

    _isCreatingBusAnnotation = true;
    try {
      final annotation = await manager.create(
        PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(position.longitude, position.latitude),
          ),
          iconSize: 1.0,
          image: _busIconBytes,
        ),
      );

      if (mounted && identical(manager, _pointAnnotationManager)) {
        _busAnnotation = annotation;
      }
    } catch (error, stackTrace) {
      if (mounted) {
        developer.log(
          'Failed to create bus annotation: $error',
          name: 'TrackingScreen',
          stackTrace: stackTrace,
        );
      }
    } finally {
      _isCreatingBusAnnotation = false;
    }
  }

  /// Add student marker to map
  Future<void> _addStudentMarker(TripStudent student) async {
    final manager = _studentAnnotationManager;
    if (!mounted || manager == null) return;
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

    await manager.create(
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

    if (isReturnTripDirection(_tripDirection)) {
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
    if (isReturnTripDirection(_tripDirection)) {
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
    final latitude =
        mode == StudentTripActionMode.dropoff && student.pickedLatitude != 0
        ? student.pickedLatitude
        : student.latitude;
    final longitude =
        mode == StudentTripActionMode.dropoff && student.pickedLongitude != 0
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

  List<NextStudentTripTarget> _cardTargetsForStudents() {
    return _students.map(_cardTargetForStudent).toList();
  }

  TripStudent? _studentForCardTarget(NextStudentTripTarget target) {
    for (final student in _students) {
      if (student.studentId.toString() == target.id) return student;
    }
    return null;
  }

  StudentTripActionMode _modeForCardTarget(NextStudentTripTarget target) {
    final student = _studentForCardTarget(target);
    if (student != null) return _actionModeForStudent(student);

    return target.status == 'picked'
        ? StudentTripActionMode.dropoff
        : StudentTripActionMode.pickup;
  }

  double? _distanceForCardTarget(NextStudentTripTarget target) {
    final student = _studentForCardTarget(target);
    return student == null ? null : _distanceToStudent(student);
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
              students: _cardTargetsForStudents(),
              mode: mode,
              distanceMeters: distance,
              modeForStudent: _modeForCardTarget,
              distanceForStudent: _distanceForCardTarget,
              isSubmitting: _isUpdatingStudentStatus,
              errorMessage: _statusErrorMessage,
              onPickedUpStudent: (target) {
                final selected = _studentForCardTarget(target);
                if (selected == null) return;
                Navigator.pop(sheetContext);
                _updateStudentStatus(selected, 'picked');
              },
              onDroppedOffStudent: (target) {
                final selected = _studentForCardTarget(target);
                if (selected == null) return;
                Navigator.pop(sheetContext);
                _updateStudentStatus(selected, 'dropped');
              },
              onAbsentStudent: (target) {
                final selected = _studentForCardTarget(target);
                if (selected == null) return;
                Navigator.pop(sheetContext);
                _updateStudentStatus(selected, 'absent');
              },
              onChat: () {
                Navigator.pop(sheetContext);
                _openTripChat();
              },
              onStudents: () {
                Navigator.pop(sheetContext);
                _openStudentsList();
              },
              onNotify: () {
                Navigator.pop(sheetContext);
                _showNotifyOptions();
              },
            ),
          ),
        ),
      );
    });
  }

  Future<void> _updateStudentStatus(TripStudent student, String status) async {
    final tripId = _activeTripId;
    if (tripId == null || _isUpdatingStudentStatus) return;

    setState(() {
      _isUpdatingStudentStatus = true;
      _statusErrorMessage = null;
    });

    final tripProvider = context.read<TripProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      // The provider calls the API, updates every screen and alerts the
      // guardian (MQTT + push, queued if offline).
      final ok = await tripProvider.updateStudentStatus(
        tripId: tripId,
        studentId: student.studentId.toString(),
        status: status,
        latitude: _currentPosition?.latitude,
        longitude: _currentPosition?.longitude,
        studentReg: student.studentRegNumber,
        guardianPhoneNumber: student.guardianPhoneNumber,
        numberPlate: _numberPlate,
      );
      if (!mounted) return;
      if (!ok) {
        _showStatusError(
          tripProvider.errorMessage ?? 'Failed to update status',
        );
        return;
      }

      setState(() => _studentStatusUpdates[student.studentId] = status);
      await _calculateRoute();
      await _updateMarkers();

      messenger.showSnackBar(
        SnackBar(
          content: Text('${student.fullname} ${_statusMessage(status)}'),
          backgroundColor: status == 'absent'
              ? Colors.orange
              : const Color(0xFF6B9B5B),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdatingStudentStatus = false);
      }
    }
  }

  /// Pick every waiting student, or drop every picked one.
  Future<void> _updateAllStudents({required bool pick}) async {
    final tripId = _activeTripId;
    if (tripId == null || _isUpdatingStudentStatus) return;

    final from = pick ? 'pending' : 'picked';
    final count = _students.where((s) => _getStudentStatus(s) == from).length;
    final confirmed = await confirmDialog(
      context,
      title: pick ? 'Pick all students?' : 'Drop all students?',
      message: pick
          ? 'Mark all $count waiting students as picked up? '
                'Each guardian will be notified.'
          : 'Mark all $count picked students as dropped off? '
                'Each guardian will be notified.',
      confirmLabel: pick ? 'Pick all' : 'Drop all',
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _isUpdatingStudentStatus = true;
      _statusErrorMessage = null;
    });
    final tripProvider = context.read<TripProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final lat = _currentPosition?.latitude ?? 0;
      final lng = _currentPosition?.longitude ?? 0;
      final ok = pick
          ? await tripProvider.pickAllStudents(
              tripId,
              latitude: lat,
              longitude: lng,
            )
          : await tripProvider.dropAllStudents(
              tripId,
              latitude: lat,
              longitude: lng,
            );
      if (!mounted) return;
      if (!ok) {
        _showStatusError(tripProvider.errorMessage ?? 'Failed to update');
        return;
      }

      final to = pick ? 'picked' : 'dropped';
      setState(() {
        for (final s in _students) {
          if (_getStudentStatus(s) == from) {
            _studentStatusUpdates[s.studentId] = to;
          }
        }
      });
      await _calculateRoute();
      await _updateMarkers();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            pick ? '$count students picked up' : '$count students dropped off',
          ),
          backgroundColor: const Color(0xFF6B9B5B),
        ),
      );
    } finally {
      if (mounted) setState(() => _isUpdatingStudentStatus = false);
    }
  }

  void _showStatusError(String message) {
    setState(() => _statusErrorMessage = message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  /// Add a student who isn't on this trip yet. Their spot is saved as the
  /// bus's current GPS on the trip's student row, so the next run of this
  /// trip can prompt the driver when approaching it.
  Future<void> _addStudent() async {
    final masterTripId = _resolvedMasterTripId;
    if (_activeTripId == null || masterTripId == null || masterTripId <= 0) {
      _showStatusError('Trip is still loading, try again in a moment');
      return;
    }

    final choice = await showAddTripStudentSheet(
      context,
      students: _schoolStudents ??= student_api.StudentService()
          .getSchoolStudents(),
      excludeIds: _students.map((s) => s.studentId.toString()).toSet(),
      suggested: isReturnTripDirection(_tripDirection)
          ? AddStudentAction.drop
          : AddStudentAction.pick,
    );
    if (choice == null || !mounted) return;

    final student = choice.student;
    final studentId = int.tryParse(student.id) ?? 0;
    final phone = student.guardianPhone?.trim() ?? '';
    final position = _currentPosition;
    if (studentId <= 0 || phone.isEmpty) {
      _showStatusError(
        '${student.name} has no guardian phone on file, so they can\'t be '
        'added or notified',
      );
      return;
    }
    if (position == null) {
      _showStatusError('Waiting for GPS, try again in a moment');
      return;
    }

    setState(() => _isUpdatingStudentStatus = true);
    final tripProvider = context.read<TripProvider>();
    final added = await tripProvider.addStudentToMasterTrip(
      masterTripId: masterTripId,
      fullname: student.name,
      studentRegNumber: student.studentRegNumber ?? '',
      studentId: studentId,
      guardianPhoneNumber: phone,
      schoolname: student.schoolName ?? '',
      classname: student.className,
      route: _routeName,
      latitude: position.latitude,
      longitude: position.longitude,
    );
    if (!mounted) return;
    setState(() => _isUpdatingStudentStatus = false);
    if (added == null) {
      _showStatusError(tripProvider.errorMessage ?? 'Could not add student');
      return;
    }

    final tripStudent = _tripStudentFromPickup(
      id: student.id,
      masterTripId: masterTripId,
      name: student.name,
      parentPhone: phone,
      route: _routeName,
      latitude: position.latitude,
      longitude: position.longitude,
      status: 'pending',
      photo: student.photo,
      studentRegNumber: student.studentRegNumber,
      className: student.className,
      schoolName: student.schoolName,
    );
    setState(() {
      _students = [..._students, tripStudent];
      _errorMessage = null;
    });
    _syncRosterToProvider();

    await _updateStudentStatus(
      tripStudent,
      choice.action == AddStudentAction.pick ? 'picked' : 'dropped',
    );
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

  void _openTripChat() {
    final tripId = widget.tripId;
    Navigator.pushNamed(
      context,
      '/chat-detail',
      arguments: {
        'tripId': tripId,
        'receiverPhone': 'trip_${tripId ?? 'active'}',
        'receiverName': _routeName,
        'receiverRole': 'Group',
        'isTripChat': true,
      },
    );
  }

  void _openStudentsList() {
    Navigator.pushNamed(
      context,
      '/students-list',
      arguments: {'tripId': widget.tripId},
    );
  }

  void _showNotifyOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Notify guardians',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.schedule, color: Color(0xFF6B9B5B)),
                title: const Text('Running Late'),
                onTap: () {
                  Navigator.pop(context);
                  _showNotificationSent('Running late');
                },
              ),
              ListTile(
                leading: const Icon(Icons.traffic, color: Color(0xFF6B9B5B)),
                title: const Text('Traffic Delay'),
                onTap: () {
                  Navigator.pop(context);
                  _showNotificationSent('Traffic delay');
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.check_circle,
                  color: Color(0xFF6B9B5B),
                ),
                title: const Text('On Schedule'),
                onTap: () {
                  Navigator.pop(context);
                  _showNotificationSent('On schedule');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNotificationSent(String label) {
    final guardians = _students
        .map((s) => s.guardianPhoneNumber)
        .where((phone) => phone.isNotEmpty)
        .toSet()
        .length;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label notification sent to $guardians guardians'),
        backgroundColor: const Color(0xFF6B9B5B),
      ),
    );
  }

  void _showTripCompletionError(String? message) {
    final errorMessage = message ?? 'Unknown error';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Failed to complete trip: $errorMessage'),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _completeTrip() async {
    if (_isEndingTrip) return;

    final tripId = _activeTripId;
    if (tripId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to complete this trip')),
      );
      return;
    }

    final remaining = _students.where((student) {
      final status = _getStudentStatus(student);
      return status == 'pending' || status == 'picked';
    }).length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Complete Trip?'),
        content: Text(
          remaining == 0
              ? 'This will end live tracking and return to the dashboard.'
              : '$remaining students still have actions remaining. Complete the trip anyway?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Complete Trip'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isEndingTrip = true);
    final authProvider = context.read<AuthProvider>();
    final tripProvider = context.read<TripProvider>();
    final position = _currentPosition;
    try {
      final success = await tripProvider.endTrip(
        tripId,
        driverId: authProvider.userId,
        driverName: authProvider.userName,
        latitude: position?.latitude ?? 0,
        longitude: position?.longitude ?? 0,
      );
      if (!mounted) return;

      if (!success) {
        _showTripCompletionError(tripProvider.errorMessage);
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trip completed successfully'),
          backgroundColor: Color(0xFF6B9B5B),
        ),
      );
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/dashboard',
        (route) => false,
        arguments: {'fromTripEnd': true},
      );
    } catch (error) {
      if (mounted) _showTripCompletionError(error.toString());
    } finally {
      if (mounted) setState(() => _isEndingTrip = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_routeName),
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
            top: 16,
            right: 16,
            child: Column(
              children: [
                if (context.select<AuthProvider, bool>((a) => a.isDriver)) ...[
                  FloatingActionButton.small(
                    heroTag: 'add-student',
                    tooltip: 'Add student',
                    onPressed: _isUpdatingStudentStatus ? null : _addStudent,
                    backgroundColor: const Color(0xFF6B9B5B),
                    child: const Icon(
                      Icons.person_add_alt_1_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
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
    final nextDistance = nextStudent == null
        ? null
        : _distanceToStudent(nextStudent);
    final totalStudents = _students.length;
    final waitingStudents = _students
        .where((s) => _getStudentStatus(s) == 'pending')
        .length;
    final pickedStudents = _students
        .where((s) => _getStudentStatus(s) == 'picked')
        .length;
    final canCompleteTrip = context.select<AuthProvider, bool>(
      (authProvider) => authProvider.isDriver,
    );
    final maxPanelHeight = MediaQuery.sizeOf(context).height * 0.45;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.55),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxPanelHeight),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      height: 44,
                      width: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6B9B5B).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.directions_bus_filled_rounded,
                        color: Color(0xFF2E6B3D),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _vehicleLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF101828),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 10,
                            runSpacing: 4,
                            children: [
                              if (_currentPosition != null)
                                _buildVehicleMetric(
                                  icon: Icons.speed_rounded,
                                  label:
                                      '${_currentPosition!.speed.toStringAsFixed(0)} km/h',
                                ),
                              if (_currentPosition != null)
                                _buildVehicleMetric(
                                  icon: Icons.navigation_rounded,
                                  label:
                                      '${_currentPosition!.heading.toStringAsFixed(0)} deg',
                                ),
                              _buildVehicleMetric(
                                icon: Icons.route_rounded,
                                label: '${totalStudents.toString()} students',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _buildLiveChip(),
                  ],
                ),
                const SizedBox(height: 12),
                NextStudentTripActionCard(
                  student: nextStudent == null
                      ? null
                      : _cardTargetForStudent(nextStudent),
                  students: _cardTargetsForStudents(),
                  mode: nextMode,
                  distanceMeters: nextDistance,
                  modeForStudent: _modeForCardTarget,
                  distanceForStudent: _distanceForCardTarget,
                  isSubmitting: _isUpdatingStudentStatus,
                  errorMessage: _statusErrorMessage,
                  compact: true,
                  embedded: true,
                  padding: EdgeInsets.zero,
                  onPickedUpStudent: (target) {
                    final selected = _studentForCardTarget(target);
                    if (selected != null) {
                      _updateStudentStatus(selected, 'picked');
                    }
                  },
                  onDroppedOffStudent: (target) {
                    final selected = _studentForCardTarget(target);
                    if (selected != null) {
                      _updateStudentStatus(selected, 'dropped');
                    }
                  },
                  onAbsentStudent: (target) {
                    final selected = _studentForCardTarget(target);
                    if (selected != null) {
                      _updateStudentStatus(selected, 'absent');
                    }
                  },
                  onChat: _openTripChat,
                  onStudents: _openStudentsList,
                  onNotify: _showNotifyOptions,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildCompactStat(
                        icon: Icons.people_outline_rounded,
                        value: '$totalStudents',
                        label: 'Total',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildCompactStat(
                        icon: Icons.pending_actions_rounded,
                        value: '$waitingStudents',
                        label: 'Waiting',
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildCompactStat(
                        icon: _routeResult == null
                            ? Icons.check_circle_outline_rounded
                            : Icons.access_time_rounded,
                        value:
                            _routeResult?.formattedDuration ??
                            '$pickedStudents',
                        label: _routeResult == null ? 'Picked' : 'ETA',
                        color: _routeResult == null
                            ? Colors.green
                            : Colors.blue,
                      ),
                    ),
                  ],
                ),
                if (canCompleteTrip &&
                    (waitingStudents > 0 || pickedStudents > 0)) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (waitingStudents > 0)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isUpdatingStudentStatus
                                ? null
                                : () => _updateAllStudents(pick: true),
                            icon: const Icon(Icons.done_all_rounded),
                            label: const Text('Pick all'),
                          ),
                        ),
                      if (waitingStudents > 0 && pickedStudents > 0)
                        const SizedBox(width: 8),
                      if (pickedStudents > 0)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isUpdatingStudentStatus
                                ? null
                                : () => _updateAllStudents(pick: false),
                            icon: const Icon(Icons.home_rounded),
                            label: const Text('Drop all'),
                          ),
                        ),
                    ],
                  ),
                ],
                if (canCompleteTrip) ...[
                  const SizedBox(height: 12),
                  _buildCompleteTripButton(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompleteTripButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: _activeTripId == null || _isEndingTrip
            ? null
            : _completeTrip,
        icon: _isEndingTrip
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.check_circle_outline_rounded),
        label: Text(
          _isEndingTrip ? 'Completing...' : 'Complete Trip',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6B9B5B),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          disabledForegroundColor: Colors.grey.shade600,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleMetric({required IconData icon, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildLiveChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
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
              boxShadow: [BoxShadow(color: Colors.green, blurRadius: 4)],
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'LIVE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStat({
    required IconData icon,
    required String value,
    required String label,
    Color color = const Color(0xFF6B9B5B),
  }) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: Color(0xFF101828),
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
