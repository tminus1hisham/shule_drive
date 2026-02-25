/// Map Configuration - Mapbox Only
/// 
/// Mapbox Access Token is passed via --dart-define in .vscode/launch.json
/// ACCESS_TOKEN=pk.eyJ1Ijoic2h1bGVkcml2ZSIsImEiOiJjbWx0azl0c2gwMTBrM2NzaDVmMnV4a2Q2In0.4nKQxxM4e2DcmF110KhyyA
class MapConfig {
  /// Mapbox Access Token from dart-define
  static const String mapboxAccessToken = String.fromEnvironment(
    'ACCESS_TOKEN',
    defaultValue: '',
  );

  /// Check if access token is available
  static bool get hasAccessToken => mapboxAccessToken.isNotEmpty;

  /// Mapbox base URLs
  static const String mapboxBaseUrl = 'https://api.mapbox.com';
  
  /// Mapbox Directions API endpoint
  static String get directionsUrl => '$mapboxBaseUrl/directions/v5/mapbox/driving';
  
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

  /// Default map style (for Mapbox SDK)
  static const String mapStyle = 'mapbox://styles/mapbox/streets-v12';
  
  /// Satellite style
  static const String satelliteStyle = 'mapbox://styles/mapbox/satellite-streets-v12';
  
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
}
