import 'dart:async';
import 'dart:math' show sin, cos, sqrt, atan2, pi;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart' as geolocator;
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import 'package:latlong2/latlong.dart' as latlong2;
import 'package:provider/provider.dart';
import '../../api/api.dart' as api;
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/trip_provider.dart';
import '../../models/map_models.dart';
import '../../models/preloaded_trip_data.dart';
import '../../models/master_trip.dart';
import '../../widgets/main_scaffold.dart';
import '../../services/mapbox_service.dart';
import '../../config/map_config.dart';
import '../../services/notification_service.dart';
import '../../mqtt_client.dart';

/// Active Trip Screen - Shows live map tracking with complete trip button
/// This is the main screen drivers see while on an active trip
class ActiveTripScreen extends StatefulWidget {
  const ActiveTripScreen({super.key});

  @override
  State<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends State<ActiveTripScreen> {
  final MapController _mapController = MapController();
  final NotificationService _notificationService = NotificationService();
  final MqttService _mqttService = MqttService();
  
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
  bool _hasLocationPermission = false;
  
  // Trip data
  api.Trip? _activeTrip;
  String? _tripId;
  String? _busPlate;
  
  // Stream subscriptions
  StreamSubscription<geolocator.Position>? _locationSubscription;
  Timer? _refreshTimer;
  
  // Geofence tracking - stores stop IDs that have shown pickup dialog
  final Set<String> _processedStops = {};
  bool _isShowingPickupDialog = false;
  
  // ETA notification tracking - stores stop IDs that have had 2-min ETA notification sent
  final Set<String> _etaNotifiedStops = {};
  
  // Preloaded trip data
  List<Map<String, dynamic>> _preloadedStudents = [];

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
    super.dispose();
  }

  Future<void> _initializeTrip() async {
    setState(() => _isLoading = true);
    
    // Get trip ID from route arguments (can be int or String)
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final dynamic rawTripId = args?['tripId'];
    _tripId = rawTripId?.toString();
    _busPlate = args?['busPlate'] as String? ?? 'BUS001';
    
    // Parse preloaded students from Map
    final preloadedDataMap = args?['preloadedData'] as Map<String, dynamic>?;
    if (preloadedDataMap != null) {
      try {
        final preloadedData = PreloadedTripData.fromJson(preloadedDataMap);
        _preloadedStudents = _convertTripStudentsToMap(preloadedData.students);
        _totalCount = _preloadedStudents.length;
        _pickedCount = _preloadedStudents.where((s) => s['status'] == 'picked').length;
        if (kDebugMode) {
          print('🚌 ActiveTripScreen: Loaded ${_preloadedStudents.length} preloaded students');
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Failed to parse preloaded data: $e');
        }
      }
    }
    
    if (kDebugMode) {
      print('🚌 ActiveTripScreen: Initializing with tripId: $_tripId');
    }
    
    // Load active trip data
    await _loadActiveTrip();
    
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

  Future<void> _initializeLocationTracking() async {
    // Use actual trip stops if available
    if (_activeTrip != null && _activeTrip!.stops.isNotEmpty) {
      _stops = _activeTrip!.stops.map((stop) {
        return RouteStop(
          id: stop.id,
          name: stop.name,
          position: LatLng(stop.latitude ?? 0.0, stop.longitude ?? 0.0),  // Uses google_maps_flutter LatLng
          address: stop.address,
          order: stop.order,
          type: stop.type == 'dropoff' ? StopType.dropoff : StopType.pickup,
        );
      }).toList();
      
      if (kDebugMode) {
        print('🚌 Using actual trip stops: ${_stops.length} stops');
      }
    } else {
      // No stops available - create empty list
      _stops = [];
      if (kDebugMode) {
        print('🚌 No stops available for this trip');
      }
    }
    
    // Request location permission and start tracking
    await _checkLocationPermission();
    
    if (_hasLocationPermission) {
      await _startRealTimeTracking();
    }
    
    // Fetch route from Mapbox
    await _fetchRouteFromMapbox();
    
    // Center map on first stop or default location
    if (_stops.isNotEmpty) {
      _mapController.move(
        latlong2.LatLng(_stops.first.position.latitude, _stops.first.position.longitude),
        13,
      );
    } else {
      _mapController.move(
        const latlong2.LatLng(MapConfig.defaultLatitude, MapConfig.defaultLongitude),
        13,
      );
    }
  }

  Future<void> _checkLocationPermission() async {
    try {
      bool serviceEnabled = await geolocator.Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _hasLocationPermission = false;
        });
        return;
      }

      geolocator.LocationPermission permission = await geolocator.Geolocator.checkPermission();
      if (permission == geolocator.LocationPermission.denied) {
        permission = await geolocator.Geolocator.requestPermission();
        if (permission == geolocator.LocationPermission.denied) {
          setState(() {
            _hasLocationPermission = false;
          });
          return;
        }
      }

      if (permission == geolocator.LocationPermission.deniedForever) {
        setState(() {
          _hasLocationPermission = false;
        });
        return;
      }

      setState(() {
        _hasLocationPermission = true;
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error checking location permission: $e');
      }
      setState(() {
        _hasLocationPermission = false;
      });
    }
  }

  Future<void> _startRealTimeTracking() async {
    try {
      // Get initial position
      final initialPosition = await geolocator.Geolocator.getCurrentPosition();
      _updateBusLocation(initialPosition);
      
      // Start listening to location updates
      _locationSubscription = geolocator.Geolocator.getPositionStream(
        locationSettings: const geolocator.LocationSettings(
          accuracy: geolocator.LocationAccuracy.high,
          distanceFilter: 10, // Update every 10 meters
        ),
      ).listen(
        _onPositionUpdate,
        onError: (error) {
          if (kDebugMode) {
            print('❌ Location stream error: $error');
          }
        },
      );
      
      if (kDebugMode) {
        print('🚌 Real-time GPS tracking started');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error starting real-time tracking: $e');
      }
    }
  }

  void _onPositionUpdate(geolocator.Position position) {
    _updateBusLocation(position);
    
    // Publish location to MQTT
    _publishLocationToMqtt(position);
  }

  void _updateBusLocation(geolocator.Position position) {
    if (!mounted) return;
    
    final busLocation = BusLocation(
      busId: _busPlate ?? 'BUS001',
      busNumber: _busPlate ?? 'BUS001',
      position: LatLng(position.latitude, position.longitude),  // Uses google_maps_flutter LatLng
      heading: position.heading,
      speed: position.speed * 3.6, // Convert m/s to km/h
      timestamp: DateTime.now(),
    );
    
    setState(() {
      _currentLocation = busLocation;
    });
    
    if (_followBus) {
      _mapController.move(
        latlong2.LatLng(position.latitude, position.longitude),
        _mapController.camera.zoom,
      );
    }
    
    // Check for geofence alerts
    _checkGeofences(busLocation);
  }

  void _publishLocationToMqtt(geolocator.Position position) {
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

  Future<void> _fetchRouteFromMapbox() async {
    if (_stops.length < 2) return;
    
    try {
      final mapboxService = MapboxService();
      
      // Convert stops to waypoints
      final waypoints = _stops.map((stop) => {
        'lat': stop.position.latitude,
        'lng': stop.position.longitude,
      }).toList();
      
      final result = await mapboxService.getRoute(waypoints);
      
      if (result.success && result.coordinates != null) {
        if (mounted) {
          setState(() {
            _routePoints = result.coordinates!.map((pos) => 
              latlong2.LatLng(pos.latitude, pos.longitude)
            ).toList();
          });
        }
        
        if (kDebugMode) {
          print('✅ Mapbox route loaded: ${result.formattedDistance}, ${result.formattedDuration}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Mapbox routing error: $e');
      }
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

  void _checkGeofences(BusLocation location) {
    for (final stop in _stops) {
      final distance = _calculateDistance(
        latlong2.LatLng(location.position.latitude, location.position.longitude),
        latlong2.LatLng(stop.position.latitude, stop.position.longitude),
      );
      
      // Calculate ETA in minutes (using actual speed or default 30 km/h)
      final speed = location.speed > 0 ? location.speed / 3.6 : 8.33; // m/s
      final etaSeconds = speed > 0 ? (distance / speed).round() : 999;
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
      
      // Show local notification
      await _notificationService.showLocalNotification(
        title: '📍 Approaching ${stop.name}',
        body: 'Arriving in $etaMinutes min',
        channelId: 'geofence_alerts',
      );
      
      if (kDebugMode) {
        print('✅ ETA notification sent for stop: ${stop.name}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Failed to send ETA notification: $e');
      }
    }
  }

  Future<void> _showStudentPickupDialog(RouteStop stop, BusLocation busLocation) async {
    if (!mounted || _activeTrip == null) return;
    
    final pendingStudents = _activeTrip!.students
        .where((s) => s.status == 'pending')
        .toList();
    
    if (pendingStudents.isEmpty) {
      _processedStops.add(stop.id);
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
    _processedStops.add(stop.id);
    
    if (result != null && mounted) {
      // Handle pickup results
      final pickedStudentIds = result['picked'] as List<String>? ?? [];
      final absentStudentIds = result['absent'] as List<String>? ?? [];
      
      // Update student statuses
      // TODO: Implement student pick/absent API calls
      // final tripService = api.TripService();
      // for (final studentId in pickedStudentIds) {
      //   await tripService.pickStudent(studentId);
      // }
      // for (final studentId in absentStudentIds) {
      //   await tripService.markStudentAbsent(studentId);
      // }
      
      // Refresh trip data
      await _refreshTripData();
    }
  }

  void _showTripOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.navigation),
              title: const Text('Center on Bus'),
              onTap: () {
                Navigator.pop(context);
                if (_currentLocation != null) {
                  setState(() => _followBus = true);
                  _mapController.move(
                    latlong2.LatLng(
                      _currentLocation!.position.latitude,
                      _currentLocation!.position.longitude,
                    ),
                    16,
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.list),
              title: const Text('View Students'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/students-list');
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat),
              title: const Text('Chat with Guardians'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/chat');
              },
            ),
            ListTile(
              leading: const Icon(Icons.call),
              title: const Text('Emergency Call'),
              onTap: () {
                Navigator.pop(context);
                _showEmergencyDialog();
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
          'Are you sure you want to make an emergency call?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement emergency call
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Call Emergency'),
          ),
        ],
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
          // Mapbox Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const latlong2.LatLng(
                MapConfig.defaultLatitude,
                MapConfig.defaultLongitude,
              ),
              initialZoom: 13,
              onPositionChanged: (position, hasGesture) {
                if (hasGesture) {
                  setState(() => _followBus = false);
                }
              },
            ),
            children: [
              // Mapbox tile layer
              TileLayer(
                urlTemplate: isDarkMode
                    ? MapConfig.mapboxDarkTileUrl
                    : MapConfig.mapboxTileUrl,
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

          // Location permission warning
          if (!_hasLocationPermission && !_isLoading)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_off, color: Colors.orange.shade800),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Location permission required for real-time tracking',
                        style: TextStyle(color: Colors.orange.shade800),
                      ),
                    ),
                    TextButton(
                      onPressed: _checkLocationPermission,
                      child: const Text('Enable'),
                    ),
                  ],
                ),
              ),
            ),

          // Top info bar with trip stats
          Positioned(
            top: _hasLocationPermission ? 16 : 80,
            left: 16,
            right: 16,
            child: _buildTopInfoBar(isDarkMode),
          ),

          // Alerts panel
          if (_alerts.isNotEmpty)
            Positioned(
              top: _hasLocationPermission ? 100 : 164,
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
                      setState(() => _followBus = true);
                      _mapController.move(
                        latlong2.LatLng(
                          _currentLocation!.position.latitude,
                          _currentLocation!.position.longitude,
                        ),
                        16,
                      );
                    }
                  },
                ),
              ],
            ),
          ),

          // Bottom panel with trip controls
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomPanel(isDarkMode),
          ),
        ],
      ),
    );
  }

  List<Marker> _buildStopMarkers() {
    return _stops.map((stop) {
      final isProcessed = _processedStops.contains(stop.id);
      return Marker(
        point: latlong2.LatLng(stop.position.latitude, stop.position.longitude),
        width: 40,
        height: 40,
        child: Container(
          decoration: BoxDecoration(
            color: isProcessed ? Colors.grey : const Color(0xFF6B9B5B),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Center(
            child: Text(
              '${stop.order}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
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
        angle: _currentLocation!.heading * pi / 180,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF6B9B5B),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
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

  Widget _buildMapButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return FloatingActionButton.small(
      onPressed: onPressed,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      child: Icon(icon),
    );
  }

  Widget _buildTopInfoBar(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _activeTrip?.routeName ?? 'Route',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$_pickedCount/$_totalCount students picked',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDarkMode ? Colors.white70 : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF6B9B5B).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.circle,
                  color: Color(0xFF6B9B5B),
                  size: 8,
                ),
                const SizedBox(width: 6),
                Text(
                  'LIVE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF6B9B5B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsPanel(bool isDarkMode) {
    return Column(
      children: _alerts.take(3).map((alert) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            children: [
              Text(alert.type.icon, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.type.displayName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    Text(
                      '${alert.stopName} - ${alert.formattedDistance}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode ? Colors.white70 : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                alert.formattedEta,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF6B9B5B),
                ),
              ),
            ],
          ),
        );
      }).toList(),
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
            color: Colors.black.withOpacity(0.1),
            blurRadius: 16,
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Speed and heading info
            if (_currentLocation != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.speed,
                    size: 16,
                    color: isDarkMode ? Colors.white70 : Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_currentLocation!.speed.toStringAsFixed(0)} km/h',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDarkMode ? Colors.white70 : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.navigation,
                    size: 16,
                    color: isDarkMode ? Colors.white70 : Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_currentLocation!.heading.toStringAsFixed(0)}°',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDarkMode ? Colors.white70 : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            
            // View Students and Complete Trip buttons
            Row(
              children: [
                // View Students button
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _showStudentList,
                      icon: const Icon(Icons.people),
                      label: Text(
                        'Students ($_pickedCount/$_totalCount)',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey[100],
                        foregroundColor: isDarkMode ? Colors.white : Colors.black87,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Complete Trip button
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 56,
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
                        _isEndingTrip ? '...' : 'Complete',
                        style: const TextStyle(
                          fontSize: 14,
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
            // T-minus1 branding
            Center(
              child: Text(
                'T-minus1',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? const Color(0x66FFFFFF) : const Color(0x66000000),
                ),
              ),
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
      ),
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

  /// Update student status locally and refresh UI
  void _updateStudentStatus(String studentId, String newStatus) {
    setState(() {
      // Update in preloaded students list
      for (var student in _preloadedStudents) {
        if (student['id'] == studentId) {
          student['status'] = newStatus;
          break;
        }
      }
      
      // Recalculate counts
      _pickedCount = _preloadedStudents.where((s) => s['status'] == 'picked').length;
    });
    
    Navigator.pop(context);
    
    // Show confirmation
    final statusText = newStatus == 'picked' 
        ? 'Picked up' 
        : newStatus == 'absent' 
            ? 'Marked absent' 
            : 'Dropped off';
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$statusText successfully'),
        backgroundColor: const Color(0xFF6B9B5B),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Chat with student's guardian
  void _chatWithGuardian(Map<String, dynamic> student) {
    final guardianPhone = student['guardianPhone'] as String?;
    final guardianId = student['guardianId'] as String?;
    final studentName = student['name'] as String? ?? 'Student';
    
    if (guardianPhone == null && guardianId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No guardian contact available')),
      );
      return;
    }
    
    Navigator.pushNamed(
      context,
      '/chat',
      arguments: {
        'receiverId': guardianId ?? guardianPhone,
        'receiverName': student['guardianName'] ?? 'Guardian of $studentName',
        'receiverPhone': guardianPhone,
        'receiverAvatar': null,
        'receiverRole': 'guardian',
        'tripId': _tripId,
        'isTripChat': true,
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

  Future<void> _sendBulkMessage(String message) async {
    final students = _buildStudentListFromStops();
    final guardianContacts = <String>{};
    
    for (final student in students) {
      final phone = student['guardianPhone'] as String?;
      if (phone != null && phone.isNotEmpty) guardianContacts.add(phone);
    }
    
    if (guardianContacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No guardian contacts available')),
      );
      return;
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Alert sent to ${guardianContacts.length} guardians')),
    );
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
          pickedCount: _pickedCount,
          absentCount: _totalCount - _pickedCount,
        ),
      );
      
      if (confirmed == true && mounted) {
        // TODO: Implement complete trip API call
        // final tripService = api.TripService();
        // await tripService.completeTrip(_activeTrip?.id ?? '');
        
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/landing');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error completing trip: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to complete trip: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isEndingTrip = false);
      }
    }
  }

  /// Convert preloaded TripStudent objects to map format for UI
  List<Map<String, dynamic>> _convertTripStudentsToMap(List<TripStudent> students) {
    return students.map((s) {
      return {
        'id': s.id.toString(),
        'name': s.fullname,
        'stopName': s.route,
        'status': s.isStudentPicked 
            ? 'picked' 
            : s.isStudentDropped 
                ? 'dropped' 
                : 'pending',
        'guardianPhone': s.guardianPhoneNumber,
        'guardianId': s.guardianPhoneNumber,
        'guardianName': s.guardianPhoneNumber,
        'studentRegNumber': s.studentRegNumber,
        'className': s.classname,
      };
    }).toList();
  }

  /// Build student list from stops data or use preloaded students
  List<Map<String, dynamic>> _buildStudentListFromStops() {
    // If we have preloaded students, use those
    if (_preloadedStudents.isNotEmpty) {
      return _preloadedStudents;
    }
    
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
          });
        }
      } else {
        students.add({
          'id': stop.id,
          'name': stop.name,
          'stopName': 'Stop #${stop.order}',
          'status': _processedStops.contains(stop.id) ? 'picked' : 'pending',
          'guardianPhone': stop.guardianPhone,
          'guardianId': null,
          'guardianName': null,
        });
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

  const _StudentListBottomSheet({
    required this.students,
    required this.pickedCount,
    required this.totalCount,
    required this.onStudentTap,
    required this.onChatWithGuardian,
    required this.onMessageAll,
    required this.onUpdateStatus,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.24),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6B9B5B).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.people, color: Color(0xFF6B9B5B)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Students',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      Text(
                        '$pickedCount of $totalCount picked up',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode ? Colors.white70 : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onMessageAll,
                  icon: const Icon(Icons.campaign, color: Color(0xFF6B9B5B)),
                  tooltip: 'Alert all guardians',
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          
          // Progress bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: totalCount > 0 ? pickedCount / totalCount : 0,
                backgroundColor: isDarkMode ? Colors.white12 : Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6B9B5B)),
                minHeight: 8,
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Message All button
          if (students.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onMessageAll,
                  icon: const Icon(Icons.campaign),
                  label: Text('Alert All Guardians (${students.length})'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B9B5B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          
          if (students.isNotEmpty)
            const SizedBox(height: 16),
          
          // Student list
          Expanded(
            child: students.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: isDarkMode ? Colors.white30 : Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No students in this trip',
                          style: TextStyle(
                            fontSize: 16,
                            color: isDarkMode ? Colors.white60 : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: students.length,
                    itemBuilder: (context, index) {
                      final student = students[index];
                      final status = student['status'] ?? 'pending';
                      final isPicked = status == 'picked';
                      final isDropped = status == 'dropped';
                      final isAbsent = status == 'absent';
                      final isPending = status == 'pending';
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          onTap: () => onStudentTap(student),
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isPicked
                                  ? const Color(0xFF6B9B5B)
                                  : isDropped
                                      ? Colors.blue
                                      : isDarkMode
                                          ? Colors.white12
                                          : Colors.grey[200],
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isPicked ? Icons.check : isDropped ? Icons.logout : Icons.person,
                              color: isPicked || isDropped ? Colors.white : isDarkMode ? Colors.white60 : Colors.grey[600],
                            ),
                          ),
                          title: Text(
                            student['name'] ?? 'Student ${index + 1}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                          ),
                          subtitle: Text(
                            student['stopName'] ?? 'No stop assigned',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDarkMode ? Colors.white60 : Colors.grey[600],
                            ),
                          ),
                          trailing: isPending
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Pick button
                                    _buildMiniActionButton(
                                      icon: Icons.check,
                                      color: const Color(0xFF6B9B5B),
                                      onTap: () => onUpdateStatus(student['id'], 'picked'),
                                    ),
                                    const SizedBox(width: 6),
                                    // Absent button
                                    _buildMiniActionButton(
                                      icon: Icons.person_off,
                                      color: Colors.orange,
                                      onTap: () => onUpdateStatus(student['id'], 'absent'),
                                    ),
                                  ],
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (student['guardianPhone'] != null || student['guardianId'] != null)
                                      IconButton(
                                        onPressed: () => onChatWithGuardian(student),
                                        icon: const Icon(Icons.chat_bubble_outline),
                                        color: const Color(0xFF6B9B5B),
                                      ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isPicked
                                            ? const Color(0xFF6B9B5B).withValues(alpha: 0.1)
                                            : isDropped
                                                ? Colors.blue.withValues(alpha: 0.1)
                                                : Colors.orange.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        isPicked ? 'Picked' : isDropped ? 'Dropped' : 'Absent',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: isPicked ? const Color(0xFF6B9B5B) : isDropped ? Colors.blue : Colors.orange,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
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
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}

/// Modern Student Action Dialog - Shows Pick/Absent/Drop actions
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

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final studentName = student['name'] ?? 'Student';
    final stopName = student['stopName'] as String?;
    final guardianPhone = student['guardianPhone'] as String?;
    final studentClass = student['class'] ?? student['className'] ?? '';
    
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with avatar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _getHeaderGradient(),
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Close button
                  Align(
                    alignment: Alignment.topRight,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                  // Avatar
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 3),
                    ),
                    child: Center(
                      child: Text(
                        _getInitials(studentName),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    studentName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  if (studentClass.isNotEmpty)
                    Text(
                      studentClass,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  const SizedBox(height: 8),
                  _buildStatusBadge(),
                ],
              ),
            ),
            
            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stop info
                  if (stopName != null)
                    _buildInfoRow(Icons.location_on_outlined, 'Stop', stopName),
                  if (guardianPhone != null)
                    _buildInfoRow(Icons.phone_outlined, 'Guardian', guardianPhone),
                  const SizedBox(height: 20),
                  
                  // Actions
                  Text(
                    'Actions',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white70 : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Action buttons row
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.check_circle,
                          label: 'Pick',
                          color: const Color(0xFF6B9B5B),
                          isActive: isPicked,
                          onTap: isPicked ? null : onPick,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.person_off,
                          label: 'Absent',
                          color: Colors.orange,
                          isActive: isAbsent,
                          onTap: isAbsent ? null : onAbsent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.logout,
                          label: 'Drop',
                          color: Colors.blue,
                          isActive: isDropped,
                          onTap: isDropped ? null : onDrop,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Chat button
                  if (guardianPhone != null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: onChat,
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: const Text('Chat with Guardian'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDarkMode ? const Color(0xFF3C3C3C) : Colors.grey[100],
                          foregroundColor: isDarkMode ? Colors.white : Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  List<Color> _getHeaderGradient() {
    if (isPicked) return [const Color(0xFF6B9B5B), const Color(0xFF5A8A4A)];
    if (isAbsent) return [Colors.orange, Colors.deepOrange];
    if (isDropped) return [Colors.blue, Colors.blueAccent];
    return [const Color(0xFF6B9B5B), const Color(0xFF4A7A3A)];
  }
  
  Widget _buildStatusBadge() {
    String label;
    Color color;
    IconData icon;
    
    if (isPicked) {
      label = 'Picked Up';
      color = Colors.white;
      icon = Icons.check_circle;
    } else if (isAbsent) {
      label = 'Absent';
      color = Colors.white;
      icon = Icons.person_off;
    } else if (isDropped) {
      label = 'Dropped Off';
      color = Colors.white;
      icon = Icons.logout;
    } else {
      label = 'Pending Pickup';
      color = Colors.white;
      icon = Icons.schedule;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[500]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[500],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isActive ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
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
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return 'S';
  }
}

/// Modern Alert All Guardians Dialog
class _AlertAllDialog extends StatefulWidget {
  final int studentCount;
  final Function(String) onSend;

  const _AlertAllDialog({
    required this.studentCount,
    required this.onSend,
  });

  @override
  State<_AlertAllDialog> createState() => _AlertAllDialogState();
}

class _AlertAllDialogState extends State<_AlertAllDialog> {
  final TextEditingController _messageController = TextEditingController();
  bool _isSending = false;
  
  final List<Map<String, dynamic>> _quickMessages = [
    {'icon': Icons.schedule, 'text': 'Running late', 'color': Colors.orange},
    {'icon': Icons.traffic, 'text': 'Traffic delay', 'color': Colors.red},
    {'icon': Icons.access_time_filled, 'text': 'Arriving soon', 'color': const Color(0xFF6B9B5B)},
    {'icon': Icons.location_on, 'text': 'At the stop', 'color': Colors.blue},
  ];

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 600),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with animated icon
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6B9B5B), Color(0xFF5A8A4A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    // Close button
                    Align(
                      alignment: Alignment.topRight,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  // Animated broadcast icon
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 3),
                    ),
                    child: const Icon(Icons.campaign, color: Colors.white, size: 36),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Alert All Guardians',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Message will be sent to ${widget.studentCount} guardians',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
            
            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick message chips
                  Text(
                    'Quick Messages',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white70 : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _quickMessages.map((msg) {
                      return GestureDetector(
                        onTap: () => setState(() => _messageController.text = msg['text']),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: (msg['color'] as Color).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: (msg['color'] as Color).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(msg['icon'] as IconData, size: 16, color: msg['color'] as Color),
                              const SizedBox(width: 6),
                              Text(
                                msg['text'] as String,
                                style: TextStyle(
                                  color: msg['color'] as Color,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Message input
                  Text(
                    'Custom Message',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white70 : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _messageController,
                    maxLines: 3,
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Type your alert message...',
                      hintStyle: TextStyle(
                        color: isDarkMode ? Colors.white38 : Colors.grey[400],
                      ),
                      filled: true,
                      fillColor: isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFF6B9B5B), width: 2),
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Character count
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${_messageController.text.length} chars',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDarkMode ? Colors.white38 : Colors.grey[400],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: isDarkMode ? Colors.white60 : Colors.grey[600],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: _isSending || _messageController.text.trim().isEmpty
                              ? null
                              : () async {
                                  setState(() => _isSending = true);
                                  widget.onSend(_messageController.text.trim());
                                  await Future.delayed(const Duration(milliseconds: 500));
                                  if (mounted) Navigator.pop(context);
                                },
                          icon: _isSending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Icon(Icons.send, size: 18),
                          label: Text(_isSending ? 'Sending...' : 'Send Alert'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6B9B5B),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final completionRate = totalStudents > 0 ? pickedCount / totalStudents : 0.0;
    final isComplete = completionRate >= 1.0;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header - Full Width
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isComplete
                          ? [const Color(0xFF6B9B5B), const Color(0xFF4A7A3A)]
                          : [const Color(0xFFFF9800), const Color(0xFFF57C00)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          isComplete ? Icons.check_circle : Icons.warning_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isComplete ? 'Ready to Complete?' : 'Trip Not Complete',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tripName,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                
                // Content
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Stats Row
                      Row(
                        children: [
                          _buildStatCard(
                            value: totalStudents.toString(),
                            label: 'Students',
                            icon: Icons.people_outline,
                            color: Colors.blue,
                            isDarkMode: isDarkMode,
                          ),
                          const SizedBox(width: 10),
                          _buildStatCard(
                            value: pickedCount.toString(),
                            label: 'Picked Up',
                            icon: Icons.check_circle_outline,
                            color: const Color(0xFF6B9B5B),
                            isDarkMode: isDarkMode,
                          ),
                          const SizedBox(width: 10),
                          _buildStatCard(
                            value: absentCount.toString(),
                            label: 'Absent',
                            icon: Icons.person_off_outlined,
                            color: Colors.orange,
                            isDarkMode: isDarkMode,
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Circular Progress
                      Center(
                        child: Column(
                          children: [
                            SizedBox(
                              width: 90,
                              height: 90,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  CircularProgressIndicator(
                                    value: completionRate,
                                    strokeWidth: 8,
                                    backgroundColor: isDarkMode 
                                        ? Colors.white.withValues(alpha: 0.1) 
                                        : Colors.grey[200],
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      isComplete ? const Color(0xFF6B9B5B) : const Color(0xFFFF9800),
                                    ),
                                  ),
                                  Center(
                                    child: Text(
                                      '${(completionRate * 100).toInt()}%',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: isDarkMode ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Warning if not complete
                      if (!isComplete)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.info_outline, size: 16, color: Colors.orange[700]),
                              const SizedBox(width: 6),
                              Text(
                                '$absentCount students still pending',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      
                      const SizedBox(height: 16),
                      
                      // Info Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDarkMode 
                              ? Colors.white.withValues(alpha: 0.05)
                              : const Color(0xFFF5F5F0),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDarkMode 
                                ? Colors.white.withValues(alpha: 0.1) 
                                : const Color(0xFFE0E0D5),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6B9B5B).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.notifications_active_outlined,
                                color: Color(0xFF6B9B5B),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Guardian Notification',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDarkMode ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'All guardians will be notified that the trip has ended.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDarkMode ? Colors.white60 : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pop(context, true),
                          icon: Icon(isComplete ? Icons.check_circle : Icons.warning, size: 20),
                          label: Text(isComplete ? 'Complete Trip' : 'Complete Anyway'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isComplete ? const Color(0xFF6B9B5B) : const Color(0xFFFF9800),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Go Back'),
                          style: TextButton.styleFrom(
                            foregroundColor: isDarkMode ? Colors.white60 : Colors.grey[600],
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildStatCard({
    required String value,
    required String label,
    required IconData icon,
    required Color color,
    required bool isDarkMode,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isDarkMode ? Colors.white60 : color.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Student Pickup Bottom Sheet
class StudentPickupBottomSheet extends StatefulWidget {
  final String stopName;
  final List<dynamic> students;
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

class _StudentPickupBottomSheetState extends State<StudentPickupBottomSheet> {
  final Set<String> _pickedStudents = {};
  final Set<String> _absentStudents = {};

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF6B9B5B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.location_on,
                  color: Color(0xFF6B9B5B),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Arrived at',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      widget.stopName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Select Students',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.students.length,
              itemBuilder: (context, index) {
                final student = widget.students[index];
                final studentId = student.id?.toString() ?? '';
                final studentName = student.fullname ?? student.name ?? 'Student';
                final studentClass = student.classname ?? student.className ?? '';
                final isPicked = _pickedStudents.contains(studentId);
                final isAbsent = _absentStudents.contains(studentId);
                
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: isPicked
                        ? Colors.green
                        : isAbsent
                            ? Colors.orange
                            : Colors.grey[200],
                    child: Text(
                      studentName.isNotEmpty ? studentName[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: isPicked || isAbsent
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                  ),
                  title: Text(studentName),
                  subtitle: studentClass.isNotEmpty ? Text(studentClass) : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () {
                          setState(() {
                            if (isPicked) {
                              _pickedStudents.remove(studentId);
                            } else {
                              _pickedStudents.add(studentId);
                              _absentStudents.remove(studentId);
                            }
                          });
                        },
                        icon: Icon(
                          isPicked ? Icons.check_circle : Icons.check_circle_outline,
                          color: isPicked ? Colors.green : Colors.grey,
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            if (isAbsent) {
                              _absentStudents.remove(studentId);
                            } else {
                              _absentStudents.add(studentId);
                              _pickedStudents.remove(studentId);
                            }
                          });
                        },
                        icon: Icon(
                          isAbsent ? Icons.cancel : Icons.cancel_outlined,
                          color: isAbsent ? Colors.orange : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context, {
                  'picked': _pickedStudents.toList(),
                  'absent': _absentStudents.toList(),
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B9B5B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Confirm',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
