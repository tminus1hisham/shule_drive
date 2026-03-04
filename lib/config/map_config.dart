import '../services/app_config.dart';

/// Map Configuration - Mapbox Only
///
/// Mapbox Access Token is loaded from multiple sources (priority order):
/// 1. --dart-define ACCESS_TOKEN=pk.your_token (production builds)
/// 2. --dart-define MAPBOX_ACCESS_TOKEN=pk.your_token (alternative)
/// 3. .env file MAPBOX_ACCESS_TOKEN=pk.your_token (development)
///
/// Setup:
/// 1. Copy .env.example to .env and add your token
/// 2. Or pass via dart-define during build
class MapConfig {
  /// Mapbox Access Token - Now uses AppConfig for flexible configuration
  /// Priority: dart-define > .env file > empty string
  static String get mapboxAccessToken => AppConfig().mapboxAccessToken;

  /// Check if access token is available
  static bool get hasAccessToken => mapboxAccessToken.isNotEmpty;

  /// Mapbox base URLs
  static const String mapboxBaseUrl = 'https://api.mapbox.com';

  /// Mapbox Directions API endpoint
  static String get directionsUrl =>
      '$mapboxBaseUrl/directions/v5/mapbox/driving';

  /// Mapbox Geocoding API endpoint
  static String get geocodingUrl => '$mapboxBaseUrl/geocoding/v5/mapbox.places';

  /// Mapbox Static Tiles endpoint for flutter_map
  /// Uses Mapbox Streets style (raster tiles)
  static String get mapboxTileUrl =>
      'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/{z}/{x}/{y}@2x?access_token=$mapboxAccessToken';

  /// Mapbox Dark tiles for dark mode
  static String get mapboxDarkTileUrl =>
      'https://api.mapbox.com/styles/v1/mapbox/dark-v11/tiles/{z}/{x}/{y}@2x?access_token=$mapboxAccessToken';

  /// Mapbox Satellite tiles
  static String get mapboxSatelliteTileUrl =>
      'https://api.mapbox.com/styles/v1/mapbox/satellite-streets-v12/tiles/{z}/{x}/{y}@2x?access_token=$mapboxAccessToken';

  /// Mapbox Outdoors tiles (navigation/terrain view)
  static String get mapboxOutdoorsTileUrl =>
      'https://api.mapbox.com/styles/v1/mapbox/outdoors-v12/tiles/{z}/{x}/{y}@2x?access_token=$mapboxAccessToken';

  /// Mapbox Navigation Day tiles
  static String get mapboxNavigationDayTileUrl =>
      'https://api.mapbox.com/styles/v1/mapbox/navigation-day-v1/tiles/{z}/{x}/{y}@2x?access_token=$mapboxAccessToken';

  /// Mapbox Navigation Night tiles
  static String get mapboxNavigationNightTileUrl =>
      'https://api.mapbox.com/styles/v1/mapbox/navigation-night-v1/tiles/{z}/{x}/{y}@2x?access_token=$mapboxAccessToken';

  /// Default map style (for Mapbox SDK)
  static const String mapStyle = 'mapbox://styles/mapbox/streets-v12';

  /// Satellite style
  static const String satelliteStyle =
      'mapbox://styles/mapbox/satellite-streets-v12';

  /// Dark style
  static const String darkStyle = 'mapbox://styles/mapbox/dark-v11';

  /// Default location (Nairobi, Kenya)
  static const double defaultLatitude = -1.286389;
  static const double defaultLongitude = 36.817223;

  /// Route line color
  static const String routeLineColor = '#6B9B5B';

  /// Route line width
  static const double routeLineWidth = 4.0;

  /// Student marker colors
  static const String pendingStudentColor = '#F44336'; // Red
  static const String pickedStudentColor = '#4CAF50'; // Green
  static const String droppedStudentColor = '#2196F3'; // Blue
  static const String absentStudentColor = '#9E9E9E'; // Grey

  /// Bus marker color
  static const String busMarkerColor = '#6B9B5B';

  /// Get time-of-day appropriate tile URL
  /// Dawn (5-7): Navigation Day, Day (7-17): Streets, Dusk (17-19): Outdoors, Night (19-5): Dark
  static String getTimeBasedTileUrl() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 7) {
      // Dawn - warm navigation style
      return mapboxNavigationDayTileUrl;
    } else if (hour >= 7 && hour < 17) {
      // Day - standard streets
      return mapboxTileUrl;
    } else if (hour >= 17 && hour < 19) {
      // Dusk - outdoors style with warm tones
      return mapboxOutdoorsTileUrl;
    } else {
      // Night - dark mode
      return mapboxDarkTileUrl;
    }
  }
}
