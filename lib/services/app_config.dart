import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// AppConfig - Centralized configuration management
///
/// Priority order for configuration values:
/// 1. dart-define (compile-time, highest priority) - for production builds
/// 2. Secure Storage (runtime) - for tokens fetched from API
/// 3. .env file (runtime) - for development
/// 4. Default values (fallback)
///
/// Usage:
/// ```dart
/// // Initialize in main.dart before app starts
/// await AppConfig().initialize();
///
/// // Access anywhere
/// final token = AppConfig().mapboxAccessToken;
/// ```
class AppConfig {
  static final AppConfig _instance = AppConfig._internal();
  factory AppConfig() => _instance;
  AppConfig._internal();

  // Cached values
  String? _cachedMapboxToken;
  String? _cachedApiBaseUrl;
  String? _cachedEnvironment;

  bool _initialized = false;

  /// Check if config has been initialized
  bool get isInitialized => _initialized;

  /// Initialize configuration
  /// Call this in main.dart before running the app
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      await dotenv.load(fileName: ".env");
      if (kDebugMode) {
        print('[AppConfig] .env file loaded successfully');
      }
    } catch (e) {
      // CI builds ship a missing or empty .env (load throws on both). Init
      // dotenv empty, or every dotenv.env read throws NotInitializedError and
      // kills startup; values then come from dart-define or defaults.
      dotenv.testLoad();
      if (kDebugMode) {
        print('[AppConfig] No usable .env ($e), using dart-define/defaults');
      }
    }

    // Pre-load commonly used values
    _cachedMapboxToken = _getMapboxToken();
    _cachedApiBaseUrl = _getApiBaseUrl();
    _cachedEnvironment = _getEnvironment();

    _initialized = true;

    if (kDebugMode) {
      print('[AppConfig] Initialized');
      print('[AppConfig] Environment: $_cachedEnvironment');
      print('[AppConfig] API Base URL: $_cachedApiBaseUrl');
      print(
        '[AppConfig] Mapbox token available: ${_cachedMapboxToken != null && _cachedMapboxToken!.isNotEmpty}',
      );
    }
  }

  /// Get Mapbox Access Token
  /// Priority: dart-define > secure storage > .env file
  String get mapboxAccessToken {
    if (_cachedMapboxToken != null) return _cachedMapboxToken!;

    // This should not happen if initialize() was called
    // But we provide a fallback for safety
    _cachedMapboxToken = _getMapboxToken();
    return _cachedMapboxToken ?? '';
  }

  String? _getMapboxToken() {
    // Priority 1: dart-define MAPBOX_ACCESS_TOKEN (new standard)
    const dartDefineToken = String.fromEnvironment('MAPBOX_ACCESS_TOKEN');
    if (dartDefineToken.isNotEmpty) {
      if (kDebugMode)
        print(
          '[AppConfig] Using Mapbox token from dart-define (MAPBOX_ACCESS_TOKEN)',
        );
      return dartDefineToken;
    }

    // Priority 1b: dart-define ACCESS_TOKEN (legacy support)
    const legacyToken = String.fromEnvironment('ACCESS_TOKEN');
    if (legacyToken.isNotEmpty) {
      if (kDebugMode)
        print(
          '[AppConfig] Using Mapbox token from dart-define (ACCESS_TOKEN - legacy)',
        );
      return legacyToken;
    }

    // Priority 2: Secure storage (for tokens fetched from API at runtime)
    // Note: This is async, so we use the cached value or return null
    // For production, you might fetch the token from your backend
    // and store it here securely

    // Priority 3: .env file MAPBOX_ACCESS_TOKEN
    final envToken = dotenv.env['MAPBOX_ACCESS_TOKEN'];
    if (envToken != null && envToken.isNotEmpty) {
      if (kDebugMode) print('[AppConfig] Using Mapbox token from .env file');
      return envToken;
    }

    // Priority 3b: .env file ACCESS_TOKEN (legacy)
    final legacyEnvToken = dotenv.env['ACCESS_TOKEN'];
    if (legacyEnvToken != null && legacyEnvToken.isNotEmpty) {
      if (kDebugMode)
        print(
          '[AppConfig] Using Mapbox token from .env file (ACCESS_TOKEN - legacy)',
        );
      return legacyEnvToken;
    }

    if (kDebugMode) {
      print('[AppConfig] WARNING: No Mapbox token found!');
      print('[AppConfig] Set it via:');
      print('  1. --dart-define=MAPBOX_ACCESS_TOKEN=pk.your_token');
      print('  2. Add MAPBOX_ACCESS_TOKEN=pk.your_token to .env file');
    }
    return null;
  }

  /// Get API Base URL
  /// Priority: dart-define > .env file > default
  String get apiBaseUrl {
    if (_cachedApiBaseUrl != null) return _cachedApiBaseUrl!;
    _cachedApiBaseUrl = _getApiBaseUrl();
    return _cachedApiBaseUrl!;
  }

  String _getApiBaseUrl() {
    // Priority 1: dart-define
    const dartDefineUrl = String.fromEnvironment('API_BASE_URL');
    if (dartDefineUrl.isNotEmpty) {
      return dartDefineUrl;
    }

    // Priority 2: .env file
    final envUrl = dotenv.env['API_BASE_URL'];
    if (envUrl != null && envUrl.isNotEmpty) {
      return envUrl;
    }

    // Priority 3: Default based on environment
    return isProduction
        ? 'https://myshule.transfa.org'
        : 'https://myshule.transfa.org';
  }

  /// Get current environment
  String get environment {
    if (_cachedEnvironment != null) return _cachedEnvironment!;
    _cachedEnvironment = _getEnvironment();
    return _cachedEnvironment!;
  }

  String _getEnvironment() {
    // Priority 1: dart-define
    const dartDefineEnv = String.fromEnvironment('ENVIRONMENT');
    if (dartDefineEnv.isNotEmpty) {
      return dartDefineEnv;
    }

    // Priority 2: .env file
    final envValue = dotenv.env['ENVIRONMENT'];
    if (envValue != null && envValue.isNotEmpty) {
      return envValue;
    }

    // Priority 3: Default based on build mode
    return kReleaseMode ? 'production' : 'development';
  }

  /// Check if running in production
  bool get isProduction => environment == 'production';

  /// Check if running in staging
  bool get isStaging => environment == 'staging';

  /// Check if running in development
  bool get isDevelopment => environment == 'development';

  /// Store Mapbox token securely (e.g., after fetching from backend)
  Future<void> setMapboxToken(String token) async {
    _cachedMapboxToken = token;
    // Optionally store in secure storage if you want it to persist across sessions
    // await _secureStorage._secureStorage.write(key: _mapboxTokenKey, value: token);
  }

  /// Get a config value by key (for custom values)
  /// Priority: dart-define > .env file
  String? get(String key) {
    // Priority 1: dart-define
    final dartDefineValue = String.fromEnvironment(key);
    if (dartDefineValue.isNotEmpty) {
      return dartDefineValue;
    }

    // Priority 2: .env file
    return dotenv.env[key];
  }

  /// Get a config value by key with default fallback
  String getOrDefault(String key, String defaultValue) {
    return get(key) ?? defaultValue;
  }

  /// Refresh configuration (useful after login when you might fetch new tokens)
  Future<void> refresh() async {
    _cachedMapboxToken = null;
    _cachedApiBaseUrl = null;
    _cachedEnvironment = null;
    _initialized = false;
    await initialize();
  }

  /// Validate that required configuration is present
  bool validate({bool requireMapboxToken = true}) {
    if (requireMapboxToken && mapboxAccessToken.isEmpty) {
      if (kDebugMode) {
        print('[AppConfig] VALIDATION FAILED: Mapbox token is required');
      }
      return false;
    }
    return true;
  }

  /// Print current configuration (for debugging)
  void printConfig() {
    if (!kDebugMode) return;

    print('=== AppConfig ===');
    print('Environment: $environment');
    print('API Base URL: $apiBaseUrl');
    print(
      'Mapbox Token: ${mapboxAccessToken.isNotEmpty ? "[SET]" : "[NOT SET]"}',
    );
    print('=================');
  }
}

/// Global getter for convenience
/// Usage: import this file and use `appConfig.mapboxAccessToken`
AppConfig get appConfig => AppConfig();
