import 'dart:async';
import 'dart:convert';
import 'dart:math' show sin, cos, sqrt, atan2;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../models/map_models.dart';
import '../../utils/mock_tracking_data.dart';
import '../../widgets/main_scaffold.dart';

/// OSM Tracking Screen - Free OpenStreetMap alternative to Google Maps
/// Uses OSRM (Open Source Routing Machine) for routing
class OsmTrackingScreen extends StatefulWidget {
  final String? tripId;
  final String? busId;
  final String? routeId;

  const OsmTrackingScreen({
    super.key,
    this.tripId,
    this.busId,
    this.routeId,
  });

  @override
  State<OsmTrackingScreen> createState() => _OsmTrackingScreenState();
}

class _OsmTrackingScreenState extends State<OsmTrackingScreen> {
  final MapController _mapController = MapController();
  final MockTrackingGenerator _mockGenerator = MockTrackingGenerator();
  
  // State
  BusLocation? _currentLocation;
  List<RouteStop> _stops = [];
  List<LatLng> _routePoints = [];
  final List<GeofenceAlert> _alerts = [];
  bool _isLoading = true;
  bool _followBus = true;
  
  // Stream subscriptions
  StreamSubscription? _locationSubscription;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _initializeTracking();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _refreshTimer?.cancel();
    _mockGenerator.stopTracking();
    super.dispose();
  }

  Future<void> _initializeTracking() async {
    setState(() => _isLoading = true);
    
    // Load mock data
    _stops = _mockGenerator.getMockStops();
    _routePoints = _mockGenerator.getMockRoutePath().polyline
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();
    
    // Start mock tracking
    _mockGenerator.startMockMode();
    _locationSubscription = _mockGenerator.trackBus(widget.busId ?? 'BUS001')
        .listen(_onLocationUpdate);
    
    // Fetch route from OSRM
    await _fetchRouteFromOSRM();
    
    setState(() => _isLoading = false);
    
    // Center map on first stop
    if (_stops.isNotEmpty) {
      _mapController.move(
        LatLng(_stops.first.position.latitude, _stops.first.position.longitude),
        13,
      );
    }
  }

  void _onLocationUpdate(BusLocation location) {
    setState(() {
      _currentLocation = location;
    });
    
    if (_followBus) {
      _mapController.move(
        LatLng(location.position.latitude, location.position.longitude),
        _mapController.camera.zoom,
      );
    }
    
    // Check for geofence alerts
    _checkGeofences(location);
  }

  void _checkGeofences(BusLocation location) {
    for (final stop in _stops) {
      final distance = _calculateDistance(
        LatLng(location.position.latitude, location.position.longitude),
        LatLng(stop.position.latitude, stop.position.longitude),
      );
      
      GeofenceType? alertType;
      if (distance <= 100) {
        alertType = GeofenceType.arrived;
      } else if (distance <= 500) {
        alertType = GeofenceType.arriving;
      } else if (distance <= 2000) {
        alertType = GeofenceType.approaching;
      }
      
      if (alertType != null) {
        final alert = GeofenceAlert(
          id: '${DateTime.now().millisecondsSinceEpoch}_${stop.id}',
          busId: location.busId,
          stopId: stop.id,
          stopName: stop.name,
          type: alertType,
          distance: distance,
          etaSeconds: (distance / 8.33).round(), // ~30 km/h
          timestamp: DateTime.now(),
        );
        
        setState(() {
          _alerts.insert(0, alert);
          if (_alerts.length > 5) _alerts.removeLast();
        });
      }
    }
  }

  /// Fetch route from OSRM (Open Source Routing Machine)
  /// Free API: router.project-osrm.org
  Future<void> _fetchRouteFromOSRM() async {
    if (_stops.length < 2) return;
    
    try {
      // Build coordinates string: lon,lat;lon,lat;...
      final coordinates = _stops.map((s) => 
        '${s.position.longitude},${s.position.latitude}'
      ).join(';');
      
      // OSRM API endpoint (free, no API key needed)
      final url = 'http://router.project-osrm.org/route/v1/driving/'
          '$coordinates?overview=full&geometries=geojson';
      
      final response = await http.get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final geometry = data['routes'][0]['geometry']['coordinates'] as List;
          setState(() {
            _routePoints = geometry.map((coord) => 
              LatLng(coord[1] as double, coord[0] as double)
            ).toList();
          });
        }
      }
    } catch (e) {
      debugPrint('OSRM routing error: $e');
      // Fall back to straight lines between stops
    }
  }

  double _calculateDistance(LatLng p1, LatLng p2) {
    const double earthRadius = 6371000; // meters
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

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final isDarkMode = appProvider.isDarkMode;

    return MainScaffold(
      title: 'Live Tracking (OSM)',
      showBackButton: true,
      showBottomNav: false,
      body: Stack(
        children: [
          // OpenStreetMap
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(-1.286389, 36.817223), // Nairobi
              initialZoom: 13,
              onPositionChanged: (position, hasGesture) {
                if (hasGesture) {
                  setState(() => _followBus = false);
                }
              },
            ),
            children: [
              // Free OpenStreetMap tile layer
              TileLayer(
                urlTemplate: isDarkMode
                    ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                    : 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.example.crossroad',
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

          // Top info bar
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: _buildInfoBar(isDarkMode),
          ),

          // Alerts panel
          if (_alerts.isNotEmpty)
            Positioned(
              top: 80,
              left: 16,
              right: 16,
              child: _buildAlertsPanel(isDarkMode),
            ),

          // Bottom panel
          if (_currentLocation != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _buildBottomPanel(isDarkMode),
            ),

          // Map controls
          Positioned(
            right: 16,
            bottom: _currentLocation != null ? 200 : 100,
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
                      _mapController.move(
                        LatLng(
                          _currentLocation!.position.latitude,
                          _currentLocation!.position.longitude,
                        ),
                        16,
                      );
                      setState(() => _followBus = true);
                    }
                  },
                ),
                const SizedBox(height: 8),
                _buildMapButton(
                  icon: _followBus 
                      ? Icons.navigation 
                      : Icons.navigation_outlined,
                  onPressed: () => setState(() => _followBus = !_followBus),
                  isActive: _followBus,
                ),
              ],
            ),
          ),

          // Powered by OSM badge
          Positioned(
            bottom: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(230),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '© OpenStreetMap',
                    style: TextStyle(fontSize: 10, color: Colors.black54),
                  ),
                  SizedBox(width: 8),
                  Text(
                    '© OSRM',
                    style: TextStyle(fontSize: 10, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Marker> _buildStopMarkers() {
    return _stops.map((stop) {
      final isNext = stop.id == _currentLocation?.nextStopId;
      return Marker(
        point: LatLng(stop.position.latitude, stop.position.longitude),
        width: 40,
        height: 40,
        child: Container(
          decoration: BoxDecoration(
            color: isNext ? const Color(0xFF2196F3) : const Color(0xFFF44336),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(50),
                blurRadius: 4,
              ),
            ],
          ),
          child: Center(
            child: Text(
              '${stop.order}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  Marker _buildBusMarker() {
    return Marker(
      point: LatLng(
        _currentLocation!.position.latitude,
        _currentLocation!.position.longitude,
      ),
      width: 50,
      height: 50,
      child: Transform.rotate(
        angle: _currentLocation!.heading * 3.14159 / 180,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF6B9B5B),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6B9B5B).withAlpha(100),
                blurRadius: 10,
                spreadRadius: 2,
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

  Widget _buildInfoBar(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(30),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF6B9B5B).withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.directions_bus,
              color: Color(0xFF6B9B5B),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bus ${_currentLocation?.busNumber ?? '...'}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                Text(
                  _currentLocation?.status.displayName ?? 'Loading...',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.white70 : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
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
    );
  }

  Widget _buildAlertsPanel(bool isDarkMode) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 150),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _alerts.length.clamp(0, 2),
        itemBuilder: (context, index) {
          final alert = _alerts[index];
          return Dismissible(
            key: Key(alert.id),
            onDismissed: (_) => setState(() => _alerts.removeAt(index)),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _getAlertColor(alert.type).withAlpha(30),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _getAlertColor(alert.type).withAlpha(50),
                ),
              ),
              child: Row(
                children: [
                  Text(alert.type.icon, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alert.type.message,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        Text(
                          '${alert.stopName} • ${alert.formattedDistance}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDarkMode ? Colors.white70 : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => setState(() => _alerts.removeAt(index)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomPanel(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(30),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStat(
                icon: Icons.speed,
                value: '${_currentLocation?.speed.toStringAsFixed(0) ?? '0'} km/h',
                label: 'Speed',
                isDarkMode: isDarkMode,
              ),
              _buildStat(
                icon: Icons.people,
                value: '${_currentLocation?.passengerCount ?? 0}',
                label: 'Students',
                isDarkMode: isDarkMode,
              ),
              _buildStat(
                icon: Icons.access_time,
                value: _currentLocation?.formattedEta ?? '--',
                label: 'ETA Next',
                isDarkMode: isDarkMode,
              ),
            ],
          ),
          if (_stops.isNotEmpty) ...[
            const Divider(height: 24),
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _stops.length,
                itemBuilder: (context, index) {
                  final stop = _stops[index];
                  final isNext = stop.id == _currentLocation?.nextStopId;
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isNext
                          ? const Color(0xFF6B9B5B).withAlpha(30)
                          : (isDarkMode ? Colors.white10 : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(10),
                      border: isNext
                          ? Border.all(color: const Color(0xFF6B9B5B))
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isNext ? Icons.location_on : Icons.location_on_outlined,
                          size: 16,
                          color: isNext ? const Color(0xFF6B9B5B) : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          stop.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isNext ? FontWeight.w600 : FontWeight.normal,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStat({
    required IconData icon,
    required String value,
    required String label,
    required bool isDarkMode,
  }) {
    return Column(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF6B9B5B)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDarkMode ? Colors.white60 : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildMapButton({
    required IconData icon,
    required VoidCallback onPressed,
    bool isActive = false,
  }) {
    return Material(
      color: isActive ? const Color(0xFF6B9B5B) : Colors.white,
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: isActive ? Colors.white : const Color(0xFF6B9B5B),
            size: 20,
          ),
        ),
      ),
    );
  }

  Color _getAlertColor(GeofenceType type) {
    switch (type) {
      case GeofenceType.approaching:
        return const Color(0xFF2196F3);
      case GeofenceType.arriving:
        return const Color(0xFFFF9800);
      case GeofenceType.arrived:
        return const Color(0xFF4CAF50);
    }
  }
}


