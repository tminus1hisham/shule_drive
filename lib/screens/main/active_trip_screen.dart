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
    
    // Get trip ID from route arguments
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _tripId = args?['tripId'] as String?;
    _busPlate = args?['busPlate'] as String? ?? 'BUS001';
    
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
            
            // Complete trip button
            SizedBox(
              width: double.infinity,
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
            const SizedBox(height: 8),
            
            // © Mapbox attribution
            Center(
              child: Text(
                '© Mapbox',
                style: TextStyle(
                  fontSize: 10,
                  color: isDarkMode ? Colors.white38 : Colors.black38,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _completeTrip() async {
    setState(() => _isEndingTrip = true);
    
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Complete Trip?'),
          content: const Text(
            'Are you sure you want to complete this trip? This will notify all guardians that the trip has ended.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B9B5B),
                foregroundColor: Colors.white,
              ),
              child: const Text('Complete'),
            ),
          ],
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
