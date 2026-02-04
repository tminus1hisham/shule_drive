import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../providers/tracking_provider.dart';
import '../../models/map_models.dart';
import '../../widgets/main_scaffold.dart';

/// Live Tracking Screen - Real-time bus location on map
class LiveTrackingScreen extends StatefulWidget {
  final String? tripId;
  final String? busId;
  final String? routeId;

  const LiveTrackingScreen({
    super.key,
    this.tripId,
    this.busId,
    this.routeId,
  });

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  @override
  void initState() {
    super.initState();
    _initializeTracking();
  }

  Future<void> _initializeTracking() async {
    final provider = context.read<TrackingProvider>();
    await provider.initialize();
    
    if (widget.tripId != null && widget.busId != null) {
      await provider.startTrackingTrip(
        tripId: widget.tripId!,
        busId: widget.busId!,
        routeId: widget.routeId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TrackingProvider>();
    final appProvider = context.watch<AppProvider>();
    final isDarkMode = appProvider.isDarkMode;

    return MainScaffold(
      title: 'Live Tracking',
      showBackButton: true,
      showBottomNav: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.layers_outlined),
          onPressed: provider.toggleMapType,
        ),
        IconButton(
          icon: Icon(
            provider.showTraffic ? Icons.traffic : Icons.traffic_outlined,
          ),
          onPressed: provider.toggleTraffic,
        ),
      ],
      body: Stack(
        children: [
          // Map
          GoogleMap(
            mapType: provider.mapType,
            trafficEnabled: provider.showTraffic,
            initialCameraPosition: const CameraPosition(
              target: LatLng(-1.286389, 36.817223), // Nairobi default
              zoom: 12,
            ),
            markers: provider.markers,
            polylines: provider.polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            onMapCreated: provider.setMapController,
          ),

          // Loading indicator
          if (provider.viewState == MapViewState.loading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF6B9B5B),
                ),
              ),
            ),

          // Error state
          if (provider.viewState == MapViewState.error)
            _buildErrorState(),

          // Bottom info panel
          if (provider.viewState == MapViewState.ready)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _buildInfoPanel(provider, isDarkMode),
            ),

          // Alerts panel
          if (provider.alerts.isNotEmpty)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: _buildAlertsPanel(provider, isDarkMode),
            ),

          // Map controls
          Positioned(
            right: 16,
            bottom: provider.viewState == MapViewState.ready ? 200 : 100,
            child: Column(
              children: [
                _buildMapButton(
                  icon: Icons.my_location,
                  onPressed: provider.centerOnBus,
                ),
                const SizedBox(height: 8),
                _buildMapButton(
                  icon: provider.followBus 
                      ? Icons.navigation 
                      : Icons.navigation_outlined,
                  onPressed: provider.toggleFollowBus,
                  isActive: provider.followBus,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
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
              const Text(
                'Failed to load map',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please check your connection and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _initializeTracking,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B9B5B),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoPanel(TrackingProvider provider, bool isDarkMode) {
    final info = provider.tripInfo;
    final location = provider.currentBusLocation;

    if (info == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(30),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Bus info header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF6B9B5B).withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.directions_bus,
                  color: Color(0xFF6B9B5B),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bus ${info['busNumber']}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    Text(
                      'Driver: ${info['driverName']}',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDarkMode ? Colors.white70 : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor(location?.status).withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  info['status'],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _getStatusColor(location?.status),
                  ),
                ),
              ),
            ],
          ),

          const Divider(height: 24),

          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStat(
                icon: Icons.speed,
                value: info['speed'],
                label: 'Speed',
                isDarkMode: isDarkMode,
              ),
              _buildStat(
                icon: Icons.people,
                value: '${info['passengers']}',
                label: 'Passengers',
                isDarkMode: isDarkMode,
              ),
              if (info['nextStop'] != null)
                _buildStat(
                  icon: Icons.location_on,
                  value: info['eta'] ?? '...',
                  label: 'To ${info['nextStop']}',
                  isDarkMode: isDarkMode,
                ),
            ],
          ),

          // Stops list
          if (provider.stops.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Upcoming Stops',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 60,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: provider.stops.length,
                itemBuilder: (context, index) {
                  final stop = provider.stops[index];
                  final isNext = stop.id == location?.nextStopId;
                  final eta = provider.getEtaForStop(stop.id);

                  return Container(
                    width: 120,
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isNext
                          ? const Color(0xFF6B9B5B).withAlpha(30)
                          : (isDarkMode ? Colors.white10 : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(12),
                      border: isNext
                          ? Border.all(
                              color: const Color(0xFF6B9B5B),
                              width: 1,
                            )
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          stop.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isNext ? FontWeight.w600 : FontWeight.normal,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        if (eta != null)
                          Text(
                            eta,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF6B9B5B),
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

  Widget _buildAlertsPanel(TrackingProvider provider, bool isDarkMode) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: provider.alerts.length.clamp(0, 3),
        itemBuilder: (context, index) {
          final alert = provider.alerts[index];
          return Dismissible(
            key: Key(alert.id),
            onDismissed: (_) => provider.dismissAlert(alert.id),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getAlertColor(alert.type).withAlpha(30),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _getAlertColor(alert.type).withAlpha(50),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    alert.type.icon,
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alert.type.message,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        Text(
                          '${alert.stopName} • ${alert.formattedDistance} • ${alert.formattedEta}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDarkMode ? Colors.white70 : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => provider.dismissAlert(alert.id),
                  ),
                ],
              ),
            ),
          );
        },
      ),
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
            fontSize: 14,
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

  Color _getStatusColor(BusStatus? status) {
    switch (status) {
      case BusStatus.active:
        return const Color(0xFF4CAF50);
      case BusStatus.idle:
        return const Color(0xFFFFC107);
      case BusStatus.maintenance:
        return const Color(0xFFFF9800);
      case BusStatus.offline:
        return const Color(0xFF9E9E9E);
      default:
        return const Color(0xFF607D8B);
    }
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

/// Compact tracking widget for embedding in other screens
class LiveTrackingMiniMap extends StatelessWidget {
  final String? tripId;
  final String? busId;
  final double height;

  const LiveTrackingMiniMap({
    super.key,
    this.tripId,
    this.busId,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (tripId != null && busId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LiveTrackingScreen(
                tripId: tripId,
                busId: busId,
              ),
            ),
          );
        }
      },
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.grey.shade200,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Placeholder map
              Container(
                color: const Color(0xFFE8F5E9),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.map_outlined,
                        size: 48,
                        color: Colors.green.shade300,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to view live tracking',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Live indicator
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Expand button
              Positioned(
                bottom: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(30),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.fullscreen,
                    size: 20,
                    color: Color(0xFF6B9B5B),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
