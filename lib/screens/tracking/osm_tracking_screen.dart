import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:provider/provider.dart';
import '../../config/map_config.dart';
import '../../mqtt_client.dart' show MqttService;
import '../../services/mapbox_service.dart';
import '../../api/services/student_service.dart' as student_api;
import '../../api/services/trip_service.dart';
import '../../models/master_trip.dart';
import '../../models/preloaded_trip_data.dart';
import '../../providers/auth_provider.dart';
import '../../providers/trip_provider.dart';
import '../../services/guardian_trip_notification_service.dart';
import '../../utils/student_trip_logic.dart';
import '../../utils/location_settings.dart';
import '../../widgets/add_trip_student_sheet.dart';
import '../../widgets/main_scaffold.dart' show openDriverChat;
import '../../theme/app_spacing.dart';
import '../../theme/app_theme_extension.dart';
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
  StreamSubscription<GuardianStudentStatusEvent>? _guardianStatusSub;

  /// Guardians follow the bus over MQTT instead of their own GPS.
  String? _busTopic;
  DateTime? _lastLocationPublish;

  // Animation for smooth bus movement
  late AnimationController _animationController;
  Animation<double>? _latAnimation;
  Animation<double>? _lngAnimation;
  Animation<double>? _bearingAnimation;

  Uint8List? _busIconBytes;

  // Data
  Trip? _trip;
  PreloadedTripData? _preloadedData;
  List<TripStudent> _allStudents = [];

  /// Set for guardians only. Their trip roster is cut down to their own
  /// children so the map never shows other families' kids.
  String? _guardianPhone;

  List<TripStudent> get _students {
    if (_guardianPhone == null) return _allStudents;
    final phone = normalizeGuardianPhone(_guardianPhone);
    return _allStudents
        .where(
          (s) =>
              phone.isNotEmpty &&
              normalizeGuardianPhone(s.guardianPhoneNumber) == phone,
        )
        .toList();
  }

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
  TripStudent? _proximityStudent;

  // Navigation
  bool _followBus = true;
  int _offRouteFixes = 0;
  DateTime? _lastRouteRequestAt;
  static const _offRouteMeters = 50.0;
  static const _offRouteFixesBeforeReroute = 3;
  static const _rerouteCooldown = Duration(seconds: 20);
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

    final auth = context.read<AuthProvider>();
    if (!auth.isDriver) {
      _guardianPhone = auth.userPhone ?? '';
      // A guardian's TripProvider only refreshes on its dashboard poll, so
      // apply the driver's live pick/drop/absent events here directly.
      _guardianStatusSub = GuardianTripNotificationService().updates.listen(
        _onGuardianStatusEvent,
      );
    }

    _initializeMapbox();
    _loadPreloadedData();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _tripProvider = context.read<TripProvider>();
      _tripProvider?.addListener(_onTripProviderChanged);
      // GPS doesn't depend on the roster; don't queue it behind a network
      // fallback (_loadProviderTripData may fetch the master trip).
      unawaited(_initializeLocation());
      await _loadProviderTripData();
      _syncRosterToProvider();
      _onTripProviderChanged();
      _loadTripData();
    });
  }

  @override
  void dispose() {
    _tripProvider?.removeListener(_onTripProviderChanged);
    _guardianStatusSub?.cancel();
    _animationController.stop();
    _animationController.dispose();
    _positionStream?.cancel();
    final busTopic = _busTopic;
    if (busTopic != null) {
      MqttService().unsubscribe(busTopic, _onBusLocationMessage);
    }
    _hasPendingBusUpdate = false;
    _busAnnotation = null;
    _pointAnnotationManager = null;
    _studentAnnotationManager = null;
    _polylineAnnotationManager = null;
    _mapboxMap = null;
    // MapWidget owns the MapboxMap and disposes it with its platform view.
    super.dispose();
  }

  void _onGuardianStatusEvent(GuardianStudentStatusEvent event) {
    final id = int.tryParse(event.studentId);
    final tripId = event.tripId;
    if (!mounted || id == null) return;
    if (tripId != null && tripId.isNotEmpty && tripId != _activeTripId) return;
    setState(() => _studentStatusUpdates[id] = event.status);
    _updateMarkers();
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

  // Run rows (the resume path's _trip) carry a blank direction; fall through
  // so a fresh start and a resume agree.
  String? get _tripDirection =>
      _nonEmpty(_trip?.tripDirection) ??
      _nonEmpty(_preloadedData?.masterTrip.tripDirection) ??
      _nonEmpty(_providerTrip?.tripDirection);

  String? get _activeTripId {
    final id = widget.tripId ?? _trip?.id ?? _tripProvider?.activeTrip?.id;
    return id == null || id.trim().isEmpty ? null : id;
  }

  /// The provider's copy of this trip. After an app restart it is restored
  /// before this screen fetches its own, so labels can use it meanwhile.
  Trip? get _providerTrip {
    final trip = _tripProvider?.activeTrip;
    return trip != null && trip.id == _activeTripId ? trip : null;
  }

  String get _routeName =>
      _trip?.routeName ??
      _preloadedData?.masterTrip.tripName ??
      _nonEmpty(_providerTrip?.routeName) ??
      _preloadedData?.masterTrip.route ??
      'Live Tracking';

  String get _vehicleLabel {
    final vehicleNumber =
        _trip?.vehicleNumber ??
        _preloadedData?.vehicle?.registrationNumber ??
        _preloadedData?.masterTrip.numberPlate ??
        _providerTrip?.vehicleNumber;
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
      _preloadedData?.masterTrip.numberPlate ??
      _providerTrip?.vehicleNumber;

  static String? _nonEmpty(String? v) => v == null || v.isEmpty ? null : v;

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
    // A guardian's phone is not on the bus: show where the driver is.
    if (_guardianPhone != null) {
      _followBusOverMqtt();
      return;
    }
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
      }
      if (permission == geo.LocationPermission.denied ||
          permission == geo.LocationPermission.deniedForever) {
        setState(() {
          _errorMessage = 'Location permissions denied';
        });
        return;
      }

      // Subscribe first: awaiting a fresh fix (getCurrentPosition has no
      // time limit) left the stream unsubscribed, so the bus never moved or
      // published when GPS was slow to lock.
      _positionStream = geo.Geolocator.getPositionStream(
        locationSettings: driverLocationSettings(),
      ).listen(
        _onLocationUpdate,
        onError: (Object e) => debugPrint('📍 GPS stream error: $e'),
      );
      final last = await geo.Geolocator.getLastKnownPosition();
      if (last != null && _currentPosition == null) _onLocationUpdate(last);
    } catch (e) {
      debugPrint('📍 Location init error: $e');
    }
  }

  /// Subscribe to the driver's published GPS. The plate can arrive after
  /// the first call (trip still loading), so this is retried from
  /// [_loadTripData].
  void _followBusOverMqtt() {
    final plate = _numberPlate;
    if (_busTopic != null || plate == null || plate.isEmpty) return;
    _busTopic = 'driver/$plate/location';
    MqttService().subscribe(_busTopic!, _onBusLocationMessage).catchError((e) {
      developer.log(
        'Bus location subscribe failed: $e',
        name: 'TrackingScreen',
      );
    });
  }

  void _onBusLocationMessage(String topic, String message) {
    try {
      final data = jsonDecode(message) as Map<String, dynamic>;
      final tripId = data['tripId']?.toString();
      if (tripId != null && tripId.isNotEmpty && tripId != _activeTripId) {
        return; // the same bus on another run
      }
      final position = geo.Position(
        latitude: (data['latitude'] as num).toDouble(),
        longitude: (data['longitude'] as num).toDouble(),
        timestamp:
            DateTime.tryParse(data['timestamp']?.toString() ?? '') ??
            DateTime.now(),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: (data['heading'] as num?)?.toDouble() ?? 0,
        headingAccuracy: 0,
        // Published in km/h.
        speed: ((data['speed'] as num?)?.toDouble() ?? 0) / 3.6,
        speedAccuracy: 0,
      );
      if (_currentPosition == null) {
        setState(() {
          _currentPosition = position;
          _previousPosition = position;
        });
        _updateDriverMarker();
        _followBusCamera(position);
      } else {
        _onLocationUpdate(position);
      }
    } catch (e) {
      developer.log('Bad bus location: $e', name: 'TrackingScreen');
    }
  }

  /// Driver only: share the bus position with guardians, at most every 5 s.
  void _publishBusLocation(geo.Position position) {
    final plate = _numberPlate;
    final now = DateTime.now();
    if (_guardianPhone != null || plate == null || plate.isEmpty) return;
    if (_lastLocationPublish != null &&
        now.difference(_lastLocationPublish!) < const Duration(seconds: 5)) {
      return;
    }
    final mqtt = MqttService();
    if (!mqtt.isConnected) return;
    _lastLocationPublish = now;
    mqtt
        .publishJson('driver/$plate/location', {
          'busId': plate,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'heading': position.heading,
          'speed': position.speed * 3.6,
          'timestamp': now.toUtc().toIso8601String(),
          'tripId': _activeTripId,
        })
        .catchError((_) {});
  }

  void _onLocationUpdate(geo.Position position) {
    if (!mounted) return;
    _publishBusLocation(position);

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
    _followBusCamera(position);
    _maybeReroute(position);
  }

  /// Keep the bus centred, pointing the way it drives. GPS heading is noise
  /// when standing still, so the bearing only updates while moving.
  void _followBusCamera(geo.Position position) {
    final map = _mapboxMap;
    if (!_followBus || map == null) return;
    final moving = position.speed > 1.5; // m/s
    map.easeTo(
      CameraOptions(
        center: Point(
          coordinates: Position(position.longitude, position.latitude),
        ),
        zoom: 16,
        pitch: 45,
        bearing: moving ? position.heading : null,
      ),
      MapAnimationOptions(duration: 900),
    );
  }

  /// Draw the route if it's missing, and recalculate it when the bus has
  /// been off it for a few fixes in a row (wrong turn).
  void _maybeReroute(geo.Position position) {
    if (_isLoadingRoute) return;
    final last = _lastRouteRequestAt;
    if (last != null && DateTime.now().difference(last) < _rerouteCooldown) {
      return;
    }

    final line = _routeResult?.coordinates;
    if (line == null || line.isEmpty) {
      _calculateRoute();
      return;
    }

    final offBy = distanceToPolylineMeters(
      (lat: position.latitude, lng: position.longitude),
      [for (final p in line) (lat: p.latitude, lng: p.longitude)],
    );
    _offRouteFixes = offBy > _offRouteMeters ? _offRouteFixes + 1 : 0;
    if (_offRouteFixes >= _offRouteFixesBeforeReroute) {
      _offRouteFixes = 0;
      _calculateRoute();
    }
  }

  void _loadPreloadedData() {
    final rawData = widget.preloadedData;
    if (rawData == null) return;

    try {
      final preloadedData = PreloadedTripData.fromJson(rawData);
      if (preloadedData.students.isEmpty) return;

      _preloadedData = preloadedData;
      _allStudents = List<TripStudent>.from(preloadedData.students);
      _isLoading = false;
    } catch (e) {
      developer.log(
        'Failed to parse preloaded trip data: $e',
        name: 'TrackingScreen',
      );
    }
  }

  Future<void> _loadProviderTripData() async {
    if (!mounted || _allStudents.isNotEmpty) return;

    final activeTrip = context.read<TripProvider>().activeTrip;
    if (activeTrip == null) return;
    if (activeTrip.students.isEmpty) {
      await _loadMasterTripStudentsFallback(
        activeTrip.masterTripId ?? int.tryParse(activeTrip.routeId),
      );
      return;
    }

    setState(() {
      _allStudents = activeTrip.students
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
        if (_allStudents.isEmpty) {
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
            _allStudents = fetchedStudents;
          }
          _errorMessage = null;
          _isLoading = false;
        });
        if (_guardianPhone != null) _followBusOverMqtt();
        if (fetchedStudents.isEmpty) {
          await _loadMasterTripStudentsFallback(_resolvedMasterTripId);
        }
        _syncRosterToProvider();
        _calculateRoute();
      } else {
        setState(() {
          _isLoading = false;
          if (_allStudents.isEmpty) {
            _errorMessage = 'Trip not found';
          }
        });
        await _loadMasterTripStudentsFallback(_resolvedMasterTripId);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        if (_allStudents.isEmpty) {
          _errorMessage = 'Error loading trip: $e';
        }
      });
      await _loadMasterTripStudentsFallback(_resolvedMasterTripId);
    }
  }

  Future<void> _loadMasterTripStudentsFallback(int? masterTripId) async {
    if (masterTripId == null || masterTripId <= 0 || _allStudents.isNotEmpty) {
      return;
    }

    try {
      final students = await _tripService.getMasterTripStudents(masterTripId);
      if (!mounted || students.isEmpty) return;

      setState(() {
        _allStudents = students;
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
      final here = (
        lat: _currentPosition!.latitude,
        lng: _currentPosition!.longitude,
      );
      // Stops still ahead: homes to pick from on the way to school, homes to
      // drop at on the way back.
      final stopStatus = isReturnTripDirection(_tripDirection)
          ? 'picked'
          : 'pending';
      final stops = <GeoPoint>[];
      for (final student in _students) {
        if (_getStudentStatus(student) != stopStatus) continue;
        final target = _targetLocationForStudent(
          student,
          _actionModeForStudent(student),
        );
        if (target != null) {
          stops.add((lat: target.latitude, lng: target.longitude));
        }
      }

      if (stops.isEmpty) {
        // Nothing left to drive to: clear the old line.
        if (_routeResult != null) {
          setState(() => _routeResult = null);
          await _polylineAnnotationManager?.deleteAll();
        }
        return;
      }

      // Mapbox Directions takes at most 25 coordinates (bus + 24 stops).
      final ordered = orderNearestFirst(here, stops, (p) => p).take(24);
      final waypoints = [
        for (final p in [here, ...ordered]) {'lat': p.lat, 'lng': p.lng},
      ];
      _lastRouteRequestAt = DateTime.now();
      final result = await _mapboxService.getRoute(waypoints);
      if (result.success && mounted) {
        _offRouteFixes = 0;
        setState(() => _routeResult = result);
        _updateRouteLine();
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

    // Live status (picks made this session), not the roster's load-time flags.
    final emoji = switch (_getStudentStatus(student)) {
      'dropped' => '🏠',
      'picked' => '✅',
      'absent' => '❌',
      _ => '👤',
    };

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

  /// Nearest student still needing an action (list order when GPS or their
  /// coordinates are unknown). Return trips: picked students to drop, then
  /// any still waiting to board at school. Otherwise: waiting students to
  /// pick, then picked ones.
  TripStudent? _nextActionableStudent() {
    final statuses = isReturnTripDirection(_tripDirection)
        ? const ['picked', 'pending']
        : const ['pending', 'picked'];
    for (final status in statuses) {
      final candidates = _students
          .where((s) => _getStudentStatus(s) == status)
          .toList();
      if (candidates.isEmpty) continue;
      return nearestBy(candidates, _distanceToStudent) ?? candidates.first;
    }
    return null;
  }

  /// The action follows the student's status, not the trip direction: on a
  /// return trip a student who hasn't boarded yet still needs picking (or
  /// marking absent) before they can be dropped.
  StudentTripActionMode _actionModeForStudent(TripStudent student) {
    return _getStudentStatus(student) == 'picked'
        ? StudentTripActionMode.dropoff
        : StudentTripActionMode.pickup;
  }

  ({double latitude, double longitude})? _targetLocationForStudent(
    TripStudent student,
    StudentTripActionMode mode,
  ) {
    // The saved spot is where the student gets on (to school) or off (return
    // trip). Today's pickup spot is only a fallback: on a return trip it's
    // the school.
    final useSaved = hasValidStudentCoordinate(
      student.latitude,
      student.longitude,
    );
    final latitude = useSaved ? student.latitude : student.pickedLatitude;
    final longitude = useSaved ? student.longitude : student.pickedLongitude;

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

  /// Prompt on the map when the bus is within
  /// [studentProximityThresholdMeters] of the nearest student to act on. Only
  /// the leg that happens at the student's spot is prompted: pickups on the
  /// way to school, drop-offs on the way back (school stops use Pick/Drop all).
  void _maybeShowNextStudentProximityPrompt() {
    if (!mounted || _isUpdatingStudentStatus || _currentPosition == null) {
      return;
    }
    // Guardians watch; only the driver acts on students.
    if (_guardianPhone != null) return;

    final student = _nextActionableStudent();
    if (student == null) return;

    final mode = _actionModeForStudent(student);
    final promptedMode = isReturnTripDirection(_tripDirection)
        ? StudentTripActionMode.dropoff
        : StudentTripActionMode.pickup;
    if (mode != promptedMode) return;

    final distance = _distanceToStudent(student);
    if (distance == null || !isWithinStudentProximity(distance)) return;

    final promptKey =
        '${student.studentId}_${mode.name}_${_getStudentStatus(student)}';
    if (!_shownStudentProximityAlerts.add(promptKey)) return;

    setState(() => _proximityStudent = student);
  }

  /// The prompted student, while they still need that action.
  TripStudent? get _activeProximityStudent {
    final student = _proximityStudent;
    if (student == null) return null;
    final status = _getStudentStatus(student);
    final pickup =
        _actionModeForStudent(student) == StudentTripActionMode.pickup;
    return (pickup ? status == 'pending' : status == 'picked') ? student : null;
  }

  Widget _buildProximityBanner(TripStudent student) {
    final pickup =
        _actionModeForStudent(student) == StudentTripActionMode.pickup;
    final distance = _distanceToStudent(student);
    final verb = pickup ? 'Pick' : 'Drop';
    final title = distance == null
        ? '$verb ${student.fullname}'
        : '$verb ${student.fullname} in ${formatStudentDistance(distance)}';

    return Material(
      color: context.colors.brand,
      elevation: 6,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.xs,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  pickup ? Icons.directions_bus_rounded : Icons.home_rounded,
                  color: Colors.white,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    title,
                    style: context.text.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Dismiss',
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => setState(() => _proximityStudent = null),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: pickup ? 'Picked up' : 'Dropped off',
                      variant: AppButtonVariant.onBrand,
                      onPressed: _isUpdatingStudentStatus
                          ? null
                          : () => _updateStudentStatus(
                              student,
                              pickup ? 'picked' : 'dropped',
                            ),
                    ),
                  ),
                  if (pickup) ...[
                    const SizedBox(width: AppSpacing.sm),
                    TextButton(
                      onPressed: _isUpdatingStudentStatus
                          ? null
                          : () => _updateStudentStatus(student, 'absent'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Absent'),
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

  Future<void> _updateStudentStatus(TripStudent student, String status) async {
    final tripId = _activeTripId;
    // Every pick/drop/absent button on this screen lands here; guardians
    // view the same screen and must never change a student's status.
    if (tripId == null || _isUpdatingStudentStatus || _guardianPhone != null) {
      return;
    }
    // Absent alerts the guardian immediately and has no undo endpoint.
    if (status == 'absent' &&
        !await confirmAbsent(context, student.fullname)) {
      return;
    }
    if (!mounted) return;

    setState(() {
      _isUpdatingStudentStatus = true;
      _statusErrorMessage = null;
    });

    final tripProvider = context.read<TripProvider>();
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

      if (!mounted) return;
      final message = '${student.fullname} ${_statusMessage(status)}';
      final notice = tripProvider.statusNotice;
      if (notice != null) {
        AppSnackbar.info(context, notice);
      } else if (status == 'absent') {
        AppSnackbar.info(context, message);
      } else {
        AppSnackbar.success(context, message);
      }
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
      if (!mounted) return;
      AppSnackbar.success(
        context,
        pick ? '$count students picked up' : '$count students dropped off',
      );
    } finally {
      if (mounted) setState(() => _isUpdatingStudentStatus = false);
    }
  }

  void _showStatusError(String message) {
    setState(() => _statusErrorMessage = message);
    AppSnackbar.error(context, message);
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
      // The server's copy, so later picks send what the server stored.
      parentPhone: added.guardianPhoneNumber.isNotEmpty
          ? added.guardianPhoneNumber
          : phone,
      route: _routeName,
      latitude: position.latitude,
      longitude: position.longitude,
      status: 'pending',
      photo: student.photo,
      studentRegNumber: added.studentRegNumber.isNotEmpty
          ? added.studentRegNumber
          : student.studentRegNumber,
      className: student.className,
      schoolName: student.schoolName,
    );
    setState(() {
      _allStudents = [..._allStudents, tripStudent];
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
    // A guardian's roster is only their own children, so the group below
    // would fan out to their own inbox. They talk to the driver instead.
    if (_guardianPhone != null) {
      final trip = [_providerTrip, _trip]
          .whereType<Trip>()
          .where((t) => t.driverPhone != null)
          .firstOrNull;
      if (trip != null) return openDriverChat(context, trip);
      AppSnackbar.info(context, "The driver's contact isn't available yet");
      return;
    }
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
        'memberPhones': _guardianPhones(),
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
    showAppBottomSheet<void>(
      context: context,
      builder: (context) {
        final c = context.colors;
        final options = [
          (
            Icons.schedule_rounded,
            'Running Late',
            'The bus is running late.',
            c.warning,
          ),
          (
            Icons.traffic_rounded,
            'Traffic Delay',
            'Traffic is delaying the trip.',
            c.accent,
          ),
          (
            Icons.check_circle_rounded,
            'On Schedule',
            'The bus is on schedule.',
            c.brand,
          ),
        ];
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Notify guardians',
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            ),
            AppSpacing.vSm,
            for (final (i, o) in options.indexed)
              AppListTile(
                icon: o.$1,
                title: o.$2,
                iconColor: o.$4,
                onTap: () {
                  Navigator.pop(context);
                  _alertGuardians(o.$2, o.$3);
                },
              ).enterList(i),
          ],
        );
      },
    );
  }

  List<String> _guardianPhones() => _students
      .map((s) => s.guardianPhoneNumber)
      .where((phone) => phone.isNotEmpty)
      .toSet()
      .toList();

  Future<void> _alertGuardians(String label, String message) async {
    final sent = await context.read<TripProvider>().alertGuardians(
      phones: _guardianPhones(),
      title: '🚌 $label',
      message: '$message ($_routeName)',
      tripId: _activeTripId,
    );
    if (!mounted) return;
    if (sent == 0) {
      AppSnackbar.info(context, 'No guardian contacts on this trip');
    } else {
      AppSnackbar.success(context, '$label sent to $sent guardians');
    }
  }

  void _showTripCompletionError(String? message) {
    final errorMessage = message ?? 'Unknown error';
    AppSnackbar.error(context, 'Failed to complete trip: $errorMessage');
  }

  Future<void> _completeTrip() async {
    if (_isEndingTrip) return;

    final tripId = _activeTripId;
    if (tripId == null) {
      AppSnackbar.error(context, 'Unable to complete this trip');

      return;
    }

    final remaining = _students.where((student) {
      final status = _getStudentStatus(student);
      return status == 'pending' || status == 'picked';
    }).length;
    final confirmed = await confirmDialog(
      context,
      title: 'Complete Trip?',
      message: remaining == 0
          ? 'This will end live tracking and show the trip details.'
          : '$remaining students still have actions remaining. '
                'Complete the trip anyway?',
      confirmLabel: 'Complete Trip',
      icon: Icons.flag_rounded,
    );
    if (!confirmed || !mounted) return;

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

      AppSnackbar.success(context, 'Trip completed successfully');

      // Show the finished trip; Back from there lands on the dashboard.
      Navigator.of(context)
        ..pushNamedAndRemoveUntil(
          '/dashboard',
          (route) => false,
          arguments: {'fromTripEnd': true},
        )
        ..pushNamed('/trip-details', arguments: {'tripId': tripId});
    } catch (error) {
      if (mounted) _showTripCompletionError(error.toString());
    } finally {
      if (mounted) setState(() => _isEndingTrip = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDriver = context.select<AuthProvider, bool>((a) => a.isDriver);
    final proximity = _activeProximityStudent;

    return Scaffold(
      appBar: AppBar(
        title: Text(_routeName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Recalculate route',
            onPressed: _calculateRoute,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Mapbox MapWidget
          MapWidget(
            onMapCreated: _onMapCreated,
            onScrollListener: (_) {
              if (_followBus) setState(() => _followBus = false);
            },
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

          // Loading scrim fades out once the trip is ready.
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

          // Error
          if (_errorMessage != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: GlassPanel(
                  tint: c.error,
                  child: EmptyState.error(
                    message: _errorMessage,
                    onRetry: _loadTripData,
                  ),
                ),
              ).enter(),
            ),

          // Route recalculating indicator drops in under the app bar.
          Positioned(
            top: AppSpacing.md,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: AnimatedScale(
                  scale: _isLoadingRoute ? 1 : 0,
                  duration: AppDuration.medium,
                  curve: _isLoadingRoute
                      ? Curves.easeOutBack
                      : AppCurves.easeOut,
                  child: GlassPanel(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: c.brand,
                          ),
                        ),
                        AppSpacing.hXs,
                        Text('Updating route', style: context.text.labelLarge),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Proximity prompt ("Pick Amani in 150 m") slides down when the
          // bus nears a student; leaves room for the map buttons.
          Positioned(
            top: AppSpacing.md,
            left: AppSpacing.md,
            right: 72,
            child: AnimatedSwitcher(
              duration: AppDuration.slow,
              switchInCurve: Curves.easeOutBack,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, -0.4),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: proximity == null
                  ? const SizedBox.shrink()
                  : KeyedSubtree(
                      key: ValueKey(proximity.studentId),
                      child: _buildProximityBanner(proximity),
                    ),
            ),
          ),

          // Map controls
          Positioned(
            top: AppSpacing.md,
            right: AppSpacing.md,
            child: Column(
              children: [
                if (isDriver) ...[
                  _MapFab(
                    icon: Icons.person_add_alt_1_rounded,
                    tooltip: 'Add student',
                    highlighted: true,
                    onPressed: _isUpdatingStudentStatus ? null : _addStudent,
                  ),
                  AppSpacing.vXs,
                ],
                _MapFab(
                  icon: _followBus
                      ? Icons.navigation_rounded
                      : Icons.my_location_rounded,
                  tooltip: 'Follow bus',
                  onPressed: () {
                    setState(() => _followBus = true);
                    final position = _currentPosition;
                    if (position != null) _followBusCamera(position);
                  },
                ),
              ],
            ).enter(delay: const Duration(milliseconds: 150)),
          ),

          // Info panel rises in once the trip has loaded.
          if (!_isLoading && _errorMessage == null)
            Positioned(
              left: AppSpacing.md,
              right: AppSpacing.md,
              bottom: AppSpacing.md,
              child: RepaintBoundary(
                child: _buildInfoPanel().enter(offsetY: 80),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoPanel() {
    final c = context.colors;
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
    final showBulk =
        canCompleteTrip && (waitingStudents > 0 || pickedStudents > 0);

    return SafeArea(
      top: false,
      child: GlassPanel(
        padding: const EdgeInsets.all(14),
        borderRadius: AppRadius.brXl,
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
                        gradient: c.accentGradient,
                        borderRadius: AppRadius.brSm,
                        boxShadow: [
                          BoxShadow(
                            color: c.accent.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.directions_bus_filled_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    AppSpacing.hSm,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _vehicleLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          AppSpacing.vXxs,
                          Wrap(
                            spacing: 10,
                            runSpacing: 4,
                            children: [
                              if (_currentPosition != null)
                                _buildVehicleMetric(
                                  icon: Icons.speed_rounded,
                                  value: (_currentPosition!.speed * 3.6)
                                      .round(),
                                  unit: ' km/h',
                                ),
                              if (_currentPosition != null)
                                _buildVehicleMetric(
                                  icon: Icons.navigation_rounded,
                                  value: _currentPosition!.heading.round(),
                                  unit: ' deg',
                                ),
                              _buildVehicleMetric(
                                icon: Icons.route_rounded,
                                value: totalStudents,
                                unit: ' students',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    AppSpacing.hXs,
                    StatusPill(label: 'LIVE', color: c.success, pulse: true),
                  ],
                ),
                AppSpacing.vSm,
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
                  onPickedUpStudent: !canCompleteTrip
                      ? null
                      : (target) {
                          final selected = _studentForCardTarget(target);
                          if (selected != null) {
                            _updateStudentStatus(selected, 'picked');
                          }
                        },
                  onDroppedOffStudent: !canCompleteTrip
                      ? null
                      : (target) {
                          final selected = _studentForCardTarget(target);
                          if (selected != null) {
                            _updateStudentStatus(selected, 'dropped');
                          }
                        },
                  onAbsentStudent: !canCompleteTrip
                      ? null
                      : (target) {
                          final selected = _studentForCardTarget(target);
                          if (selected != null) {
                            _updateStudentStatus(selected, 'absent');
                          }
                        },
                  onChat: _openTripChat,
                  onStudents: canCompleteTrip ? _openStudentsList : null,
                  onNotify: canCompleteTrip ? _showNotifyOptions : null,
                ),
                AppSpacing.vSm,
                Row(
                  children: [
                    Expanded(
                      child: _buildCompactStat(
                        icon: Icons.people_outline_rounded,
                        value: '$totalStudents',
                        label: 'Total',
                        color: c.brand,
                      ),
                    ),
                    AppSpacing.hXs,
                    Expanded(
                      child: _buildCompactStat(
                        icon: Icons.pending_actions_rounded,
                        value: '$waitingStudents',
                        label: 'Waiting',
                        color: c.warning,
                      ),
                    ),
                    AppSpacing.hXs,
                    Expanded(
                      child: _buildCompactStat(
                        icon: _routeResult == null
                            ? Icons.check_circle_outline_rounded
                            : Icons.access_time_rounded,
                        value:
                            _routeResult?.formattedDuration ??
                            '$pickedStudents',
                        label: _routeResult == null ? 'Picked' : 'ETA',
                        color: _routeResult == null ? c.success : c.info,
                      ),
                    ),
                  ],
                ),
                // Bulk actions slide open/closed as they become relevant.
                AnimatedSize(
                  duration: AppDuration.medium,
                  curve: AppCurves.easeOut,
                  alignment: Alignment.topCenter,
                  child: !showBulk
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.sm),
                          child: Row(
                            children: [
                              if (waitingStudents > 0)
                                Expanded(
                                  child: AppButton(
                                    label: 'Pick all',
                                    icon: Icons.done_all_rounded,
                                    variant: AppButtonVariant.secondary,
                                    size: AppButtonSize.medium,
                                    onPressed: _isUpdatingStudentStatus
                                        ? null
                                        : () => _updateAllStudents(pick: true),
                                  ),
                                ),
                              if (waitingStudents > 0 && pickedStudents > 0)
                                AppSpacing.hXs,
                              if (pickedStudents > 0)
                                Expanded(
                                  child: AppButton(
                                    label: 'Drop all',
                                    icon: Icons.home_rounded,
                                    variant: AppButtonVariant.outline,
                                    size: AppButtonSize.medium,
                                    onPressed: _isUpdatingStudentStatus
                                        ? null
                                        : () => _updateAllStudents(pick: false),
                                  ),
                                ),
                            ],
                          ),
                        ),
                ),
                if (canCompleteTrip) ...[
                  AppSpacing.vSm,
                  _buildCompleteTripButton(allDone: waitingStudents == 0),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompleteTripButton({required bool allDone}) {
    final button = AppButton(
      label: _isEndingTrip ? 'Completing…' : 'Complete Trip',
      icon: Icons.flag_rounded,
      loading: _isEndingTrip,
      onPressed: _activeTripId == null ? null : _completeTrip,
    );
    // Once nobody is waiting, a light sweep nudges the driver to finish.
    return KeyedSubtree(
      key: ValueKey(allDone),
      child: allDone ? button.celebrate() : button,
    );
  }

  Widget _buildVehicleMetric({
    required IconData icon,
    required int value,
    required String unit,
  }) {
    final c = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: c.accent),
        const SizedBox(width: 4),
        AnimatedCount(
          value,
          suffix: unit,
          style: context.text.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: c.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactStat({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    final c = context.colors;
    final valueStyle = context.text.titleSmall?.copyWith(
      fontWeight: FontWeight.w900,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.brSm,
        border: Border.all(color: color.withValues(alpha: 0.16)),
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
                if (int.tryParse(value) case final n?)
                  AnimatedCount(n, style: valueStyle)
                else
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: valueStyle,
                  ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: c.textSecondary,
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

/// Round floating map control; [highlighted] gets the brand fill.
class _MapFab extends StatelessWidget {
  const _MapFab({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.highlighted = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Tooltip(
      message: tooltip,
      child: PressScale(
        scale: 0.9,
        enabled: onPressed != null,
        child: Material(
          color: highlighted ? c.brand : context.scheme.surface,
          shape: const CircleBorder(),
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
                    color: highlighted ? context.scheme.onPrimary : c.brand,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
