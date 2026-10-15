import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// GPS stream settings for the driver's phone (the bus position guardians
/// follow). On iOS the defaults let CoreLocation pause updates when the bus
/// stops and stop them when the screen locks, freezing the bus on every map.
/// Background updates also need UIBackgroundModes `location` in Info.plist;
/// without it geolocator silently keeps foreground-only behaviour.
LocationSettings driverLocationSettings() {
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    return AppleSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
      activityType: ActivityType.automotiveNavigation,
      pauseLocationUpdatesAutomatically: false,
      allowBackgroundLocationUpdates: true,
      showBackgroundLocationIndicator: true,
    );
  }
  return const LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 10,
  );
}
