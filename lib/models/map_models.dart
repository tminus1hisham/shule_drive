import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Bus Location Model - Real-time position updates
class BusLocation {
  final String busId;
  final String busNumber;
  final LatLng position;
  final double heading; // Direction in degrees (0-360)
  final double speed; // Speed in km/h
  final DateTime timestamp;
  final String? driverName;
  final String? driverPhone;
  final BusStatus status;
  final int? passengerCount;
  final String? nextStopId;
  final double? distanceToNextStop; // in meters
  final int? etaToNextStop; // in seconds

  BusLocation({
    required this.busId,
    required this.busNumber,
    required this.position,
    required this.heading,
    required this.speed,
    required this.timestamp,
    this.driverName,
    this.driverPhone,
    this.status = BusStatus.unknown,
    this.passengerCount,
    this.nextStopId,
    this.distanceToNextStop,
    this.etaToNextStop,
  });

  factory BusLocation.fromJson(Map<String, dynamic> json) {
    return BusLocation(
      busId: json['busId'] ?? json['bus_id'] ?? '',
      busNumber: json['busNumber'] ?? json['bus_number'] ?? '',
      position: LatLng(
        json['latitude'] ?? json['lat'] ?? 0.0,
        json['longitude'] ?? json['lng'] ?? json['lon'] ?? 0.0,
      ),
      heading: (json['heading'] ?? json['direction'] ?? 0.0).toDouble(),
      speed: (json['speed'] ?? 0.0).toDouble(),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      driverName: json['driverName'] ?? json['driver_name'],
      driverPhone: json['driverPhone'] ?? json['driver_phone'],
      status: BusStatus.fromString(json['status'] ?? 'unknown'),
      passengerCount: json['passengerCount'] ?? json['passenger_count'],
      nextStopId: json['nextStopId'] ?? json['next_stop_id'],
      distanceToNextStop: json['distanceToNextStop'] != null
          ? (json['distanceToNextStop'] as num).toDouble()
          : null,
      etaToNextStop: json['etaToNextStop'] ?? json['eta_to_next_stop'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'busId': busId,
      'busNumber': busNumber,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'heading': heading,
      'speed': speed,
      'timestamp': timestamp.toIso8601String(),
      'driverName': driverName,
      'driverPhone': driverPhone,
      'status': status.name,
      'passengerCount': passengerCount,
      'nextStopId': nextStopId,
      'distanceToNextStop': distanceToNextStop,
      'etaToNextStop': etaToNextStop,
    };
  }

  /// Check if location is stale (older than 2 minutes)
  bool get isStale {
    return DateTime.now().difference(timestamp).inMinutes > 2;
  }

  /// Get formatted ETA
  String? get formattedEta {
    if (etaToNextStop == null) return null;
    if (etaToNextStop! < 60) return '< 1 min';
    if (etaToNextStop! < 3600) {
      final mins = (etaToNextStop! / 60).round();
      return '$mins min${mins > 1 ? 's' : ''}';
    }
    final hours = (etaToNextStop! / 3600).floor();
    final mins = ((etaToNextStop! % 3600) / 60).round();
    return '${hours}h ${mins}m';
  }
}

/// Bus Status Enum
enum BusStatus {
  active,
  idle,
  maintenance,
  offline,
  unknown;

  static BusStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'active':
      case 'online':
      case 'moving':
        return BusStatus.active;
      case 'idle':
      case 'stopped':
        return BusStatus.idle;
      case 'maintenance':
      case 'repair':
        return BusStatus.maintenance;
      case 'offline':
        return BusStatus.offline;
      default:
        return BusStatus.unknown;
    }
  }

  String get displayName {
    switch (this) {
      case BusStatus.active:
        return 'Active';
      case BusStatus.idle:
        return 'Idle';
      case BusStatus.maintenance:
        return 'Maintenance';
      case BusStatus.offline:
        return 'Offline';
      case BusStatus.unknown:
        return 'Unknown';
    }
  }

  String get colorHex {
    switch (this) {
      case BusStatus.active:
        return '#4CAF50'; // Green
      case BusStatus.idle:
        return '#FFC107'; // Amber
      case BusStatus.maintenance:
        return '#FF9800'; // Orange
      case BusStatus.offline:
        return '#9E9E9E'; // Grey
      case BusStatus.unknown:
        return '#607D8B'; // Blue Grey
    }
  }
}

/// Route Stop Model
class RouteStop {
  final String id;
  final String name;
  final LatLng position;
  final String? address;
  final int order;
  final DateTime? estimatedArrival;
  final DateTime? actualArrival;
  final StopType type;
  final List<String>? studentIds;
  final String? guardianPhone;

  RouteStop({
    required this.id,
    required this.name,
    required this.position,
    this.address,
    required this.order,
    this.estimatedArrival,
    this.actualArrival,
    this.type = StopType.pickup,
    this.studentIds,
    this.guardianPhone,
  });

  factory RouteStop.fromJson(Map<String, dynamic> json) {
    return RouteStop(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      position: LatLng(
        json['latitude'] ?? json['lat'] ?? 0.0,
        json['longitude'] ?? json['lng'] ?? json['lon'] ?? 0.0,
      ),
      address: json['address'],
      order: json['order'] ?? 0,
      estimatedArrival: json['estimatedArrival'] != null
          ? DateTime.tryParse(json['estimatedArrival'])
          : null,
      actualArrival: json['actualArrival'] != null
          ? DateTime.tryParse(json['actualArrival'])
          : null,
      type: StopType.fromString(json['type'] ?? 'pickup'),
      studentIds: json['studentIds'] != null
          ? List<String>.from(json['studentIds'])
          : null,
      guardianPhone: json['guardianPhone'] ?? json['guardian_phone'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'address': address,
      'order': order,
      'estimatedArrival': estimatedArrival?.toIso8601String(),
      'actualArrival': actualArrival?.toIso8601String(),
      'type': type.name,
      'studentIds': studentIds,
      'guardianPhone': guardianPhone,
    };
  }
}

/// Stop Type Enum
enum StopType {
  pickup,
  dropoff,
  school,
  other;

  static StopType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'pickup':
        return StopType.pickup;
      case 'dropoff':
      case 'drop-off':
        return StopType.dropoff;
      case 'school':
        return StopType.school;
      default:
        return StopType.other;
    }
  }

  String get displayName {
    switch (this) {
      case StopType.pickup:
        return 'Pickup';
      case StopType.dropoff:
        return 'Drop-off';
      case StopType.school:
        return 'School';
      case StopType.other:
        return 'Stop';
    }
  }

  String get iconAsset {
    switch (this) {
      case StopType.pickup:
        return 'assets/icons/pickup.png';
      case StopType.dropoff:
        return 'assets/icons/dropoff.png';
      case StopType.school:
        return 'assets/icons/school.png';
      case StopType.other:
        return 'assets/icons/stop.png';
    }
  }
}

/// Route Path Model
class RoutePath {
  final String id;
  final String name;
  final List<LatLng> polyline;
  final String? color;
  final double? distance; // in km
  final int? duration; // in minutes

  RoutePath({
    required this.id,
    required this.name,
    required this.polyline,
    this.color,
    this.distance,
    this.duration,
  });

  factory RoutePath.fromJson(Map<String, dynamic> json) {
    return RoutePath(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      polyline: _decodePolyline(json['polyline'] ?? ''),
      color: json['color'],
      distance: json['distance']?.toDouble(),
      duration: json['duration'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'polyline': _encodePolyline(polyline),
      'color': color,
      'distance': distance,
      'duration': duration,
    };
  }

  /// Decode Google polyline string to list of LatLng
  static List<LatLng> _decodePolyline(String encoded) {
    if (encoded.isEmpty) return [];
    
    List<LatLng> points = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;
      
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    
    return points;
  }

  /// Encode list of LatLng to Google polyline string
  static String _encodePolyline(List<LatLng> points) {
    if (points.isEmpty) return '';
    
    StringBuffer result = StringBuffer();
    int prevLat = 0;
    int prevLng = 0;

    for (var point in points) {
      int lat = (point.latitude * 1E5).round();
      int lng = (point.longitude * 1E5).round();

      int dLat = lat - prevLat;
      int dLng = lng - prevLng;

      _encodeValue(result, dLat);
      _encodeValue(result, dLng);

      prevLat = lat;
      prevLng = lng;
    }

    return result.toString();
  }

  static void _encodeValue(StringBuffer result, int value) {
    value = value < 0 ? ~(value << 1) : (value << 1);
    while (value >= 0x20) {
      result.write(String.fromCharCode((0x20 | (value & 0x1f)) + 63));
      value >>= 5;
    }
    result.write(String.fromCharCode(value + 63));
  }
}

/// Geofence Alert Model
class GeofenceAlert {
  final String id;
  final String busId;
  final String stopId;
  final String stopName;
  final GeofenceType type;
  final double distance; // in meters
  final int etaSeconds;
  final DateTime timestamp;
  final bool isDismissed;

  GeofenceAlert({
    required this.id,
    required this.busId,
    required this.stopId,
    required this.stopName,
    required this.type,
    required this.distance,
    required this.etaSeconds,
    required this.timestamp,
    this.isDismissed = false,
  });

  factory GeofenceAlert.fromJson(Map<String, dynamic> json) {
    return GeofenceAlert(
      id: json['id'] ?? '',
      busId: json['busId'] ?? json['bus_id'] ?? '',
      stopId: json['stopId'] ?? json['stop_id'] ?? '',
      stopName: json['stopName'] ?? json['stop_name'] ?? '',
      type: GeofenceType.fromString(json['type'] ?? 'approaching'),
      distance: (json['distance'] ?? 0.0).toDouble(),
      etaSeconds: json['etaSeconds'] ?? json['eta_seconds'] ?? 0,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      isDismissed: json['isDismissed'] ?? json['is_dismissed'] ?? false,
    );
  }

  /// Get formatted distance
  String get formattedDistance {
    if (distance < 1000) {
      return '${distance.round()} m';
    }
    return '${(distance / 1000).toStringAsFixed(1)} km';
  }

  /// Get formatted ETA
  String get formattedEta {
    if (etaSeconds < 60) return 'Arriving now';
    if (etaSeconds < 3600) {
      final mins = (etaSeconds / 60).round();
      return '$mins min${mins > 1 ? 's' : ''}';
    }
    final hours = (etaSeconds / 3600).floor();
    final mins = ((etaSeconds % 3600) / 60).round();
    return '${hours}h ${mins}m';
  }
}

/// Geofence Type Enum
enum GeofenceType {
  approaching, // 5 mins away
  arriving, // 1 min away
  arrived; // At stop

  static GeofenceType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'approaching':
        return GeofenceType.approaching;
      case 'arriving':
        return GeofenceType.arriving;
      case 'arrived':
        return GeofenceType.arrived;
      default:
        return GeofenceType.approaching;
    }
  }

  String get message {
    switch (this) {
      case GeofenceType.approaching:
        return 'Bus is 5 minutes away';
      case GeofenceType.arriving:
        return 'Bus is arriving now!';
      case GeofenceType.arrived:
        return 'Bus has arrived';
    }
  }

  String get icon {
    switch (this) {
      case GeofenceType.approaching:
        return '🚌';
      case GeofenceType.arriving:
        return '🚨';
      case GeofenceType.arrived:
        return '✅';
    }
  }

  String get displayName {
    switch (this) {
      case GeofenceType.approaching:
        return 'Approaching';
      case GeofenceType.arriving:
        return 'Arriving';
      case GeofenceType.arrived:
        return 'Arrived';
    }
  }
}

/// Map View State
enum MapViewState {
  loading,
  ready,
  error,
  noPermission,
}

/// Trip Tracking Info
class TripTrackingInfo {
  final String tripId;
  final String routeName;
  final BusLocation busLocation;
  final List<RouteStop> stops;
  final RoutePath? routePath;
  final DateTime startTime;
  final DateTime? estimatedEndTime;

  TripTrackingInfo({
    required this.tripId,
    required this.routeName,
    required this.busLocation,
    required this.stops,
    this.routePath,
    required this.startTime,
    this.estimatedEndTime,
  });

  /// Get next upcoming stop
  RouteStop? get nextStop {
    if (busLocation.nextStopId == null) return null;
    try {
      return stops.firstWhere((s) => s.id == busLocation.nextStopId);
    } catch (_) {
      return null;
    }
  }

  /// Get stops remaining
  int get remainingStops {
    if (busLocation.nextStopId == null) return 0;
    final nextIndex = stops.indexWhere((s) => s.id == busLocation.nextStopId);
    if (nextIndex == -1) return 0;
    return stops.length - nextIndex;
  }
}
