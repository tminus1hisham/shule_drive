import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_exceptions.dart';

/// Buffer Manager - Provides fallback data caching for API calls
/// This ensures the app remains functional even when API is unavailable
class BufferManager {
  static final BufferManager _instance = BufferManager._internal();
  factory BufferManager() => _instance;
  BufferManager._internal();

  SharedPreferences? _prefs;
  final Map<String, dynamic> _memoryCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};

  /// Default cache duration
  static const Duration defaultCacheDuration = Duration(minutes: 30);

  /// Initialize the buffer manager
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Save data to buffer
  Future<void> saveBuffer<T>({
    required String key,
    required T data,
    Duration? expiration,
  }) async {
    await init();

    final timestamp = DateTime.now();
    final expiry = timestamp.add(expiration ?? defaultCacheDuration);

    // Save to memory cache
    _memoryCache[key] = data;
    _cacheTimestamps[key] = expiry;

    // Save to persistent storage for primitive types
    if (data is String) {
      await _prefs?.setString('buffer_$key', data);
      await _prefs?.setString('buffer_${key}_expiry', expiry.toIso8601String());
    } else if (data is List<String>) {
      await _prefs?.setStringList('buffer_$key', data);
      await _prefs?.setString('buffer_${key}_expiry', expiry.toIso8601String());
    } else if (data is Map<String, dynamic>) {
      await _prefs?.setString('buffer_$key', jsonEncode(data));
      await _prefs?.setString('buffer_${key}_expiry', expiry.toIso8601String());
    } else if (data is List) {
      await _prefs?.setString('buffer_$key', jsonEncode(data));
      await _prefs?.setString('buffer_${key}_expiry', expiry.toIso8601String());
    }

    if (kDebugMode) {
      debugPrint('BufferManager: Saved data for key: $key, expires: $expiry');
    }
  }

  /// Get data from buffer. Typed data (e.g. `List<MasterTrip>`) is stored as
  /// JSON, so reading it back from disk needs [decode]; without it only
  /// String / `List<String>` / `List<dynamic>` survive an app restart.
  Future<T?> getBuffer<T>({
    required String key,
    bool checkExpiry = true,
    T Function(dynamic json)? decode,
  }) async {
    await init();

    // Check memory cache first
    if (_memoryCache.containsKey(key)) {
      if (checkExpiry) {
        final expiry = _cacheTimestamps[key];
        if (expiry != null && DateTime.now().isBefore(expiry)) {
          if (kDebugMode) {
            debugPrint('BufferManager: Memory cache hit for key: $key');
          }
          return _memoryCache[key] as T?;
        }
        // Expired, remove from cache
        _memoryCache.remove(key);
        _cacheTimestamps.remove(key);
      } else {
        return _memoryCache[key] as T?;
      }
    }

    // Check persistent storage
    final expiryString = _prefs?.getString('buffer_${key}_expiry');
    if (expiryString != null) {
      final expiry = DateTime.tryParse(expiryString);
      if (!checkExpiry || (expiry != null && DateTime.now().isBefore(expiry))) {
        // Not expired, try to retrieve data
        if (T == String) {
          final data = _prefs?.getString('buffer_$key');
          if (data != null) {
            _memoryCache[key] = data;
            if (expiry != null) _cacheTimestamps[key] = expiry;
            return data as T?;
          }
        } else if (T == List<String>) {
          final data = _prefs?.getStringList('buffer_$key');
          if (data != null) {
            _memoryCache[key] = data;
            if (expiry != null) _cacheTimestamps[key] = expiry;
            return data as T?;
          }
        } else if (T == List<dynamic>) {
          final jsonString = _prefs?.getString('buffer_$key');
          if (jsonString != null) {
            try {
              final data = jsonDecode(jsonString);
              _memoryCache[key] = data;
              if (expiry != null) _cacheTimestamps[key] = expiry;
              return data as T?;
            } catch (e) {
              debugPrint('BufferManager: Failed to parse JSON for key: $key');
            }
          }
        } else if (decode != null) {
          final jsonString = _prefs?.getString('buffer_$key');
          if (jsonString != null) {
            try {
              final data = decode(jsonDecode(jsonString));
              _memoryCache[key] = data;
              if (expiry != null) _cacheTimestamps[key] = expiry;
              return data;
            } catch (e) {
              debugPrint('BufferManager: Failed to decode $T for key: $key');
            }
          }
        } else {
          // For complex types (like List<Bus>), we can't deserialize from JSON
          // Return null to trigger API call or fallback
          debugPrint(
            'BufferManager: Cannot deserialize complex type $T from JSON for key: $key',
          );
        }
      } else {
        // Expired, clear from storage
        await clearBuffer(key);
      }
    }

    return null;
  }

  /// Check if buffer exists and is valid
  Future<bool> hasValidBuffer(String key) async {
    final buffer = await getBuffer<dynamic>(key: key, checkExpiry: true);
    return buffer != null;
  }

  /// Clear specific buffer
  Future<void> clearBuffer(String key) async {
    await init();
    _memoryCache.remove(key);
    _cacheTimestamps.remove(key);
    await _prefs?.remove('buffer_$key');
    await _prefs?.remove('buffer_${key}_expiry');
  }

  /// Clear all buffers
  Future<void> clearAllBuffers() async {
    await init();
    _memoryCache.clear();
    _cacheTimestamps.clear();

    // Clear all buffer keys from prefs
    final keys = _prefs?.getKeys().where((k) => k.startsWith('buffer_')) ?? [];
    for (final key in keys) {
      await _prefs?.remove(key);
    }
  }

  /// Clear buffers for a specific category (e.g., 'trips', 'students')
  Future<void> clearCategory(String category) async {
    await init();
    final keysToRemove = _memoryCache.keys
        .where((k) => k.startsWith(category))
        .toList();
    for (final key in keysToRemove) {
      _memoryCache.remove(key);
      _cacheTimestamps.remove(key);
    }

    final storageKeys =
        _prefs
            ?.getKeys()
            .where((k) => k.startsWith('buffer_$category'))
            .toList() ??
        [];
    for (final key in storageKeys) {
      await _prefs?.remove(key);
    }
  }

  /// Execute API call with fallback to buffer
  /// Returns API data on success, buffer data on failure
  Future<T> withBuffer<T>({
    required Future<T> Function() apiCall,
    required String bufferKey,
    required T fallbackData,
    Duration? cacheDuration,
    bool saveOnSuccess = true,
    VoidCallback? onFallback,
  }) async {
    try {
      // Try API call
      final result = await apiCall();

      // Save successful result to buffer
      if (saveOnSuccess) {
        await saveBuffer<T>(
          key: bufferKey,
          data: result,
          expiration: cacheDuration ?? defaultCacheDuration,
        );
      }

      return result;
    } catch (e) {
      // API call failed, try to get from buffer
      if (kDebugMode) {
        debugPrint(
          'BufferManager: API call failed for $bufferKey, trying buffer: $e',
        );
      }

      final buffer = await getBuffer<T>(key: bufferKey);
      if (buffer != null) {
        if (kDebugMode) {
          debugPrint('BufferManager: Using buffered data for $bufferKey');
        }
        onFallback?.call();
        return buffer;
      }

      // No buffer available, return fallback data
      if (kDebugMode) {
        debugPrint(
          'BufferManager: No buffer available for $bufferKey, using fallback',
        );
      }
      onFallback?.call();
      return fallbackData;
    }
  }

  /// Execute API call with optional buffer (returns null on failure)
  Future<T?> withOptionalBuffer<T>({
    required Future<T> Function() apiCall,
    required String bufferKey,
    Duration? cacheDuration,
    bool saveOnSuccess = true,
  }) async {
    try {
      final result = await apiCall();

      if (saveOnSuccess) {
        await saveBuffer<T>(
          key: bufferKey,
          data: result,
          expiration: cacheDuration ?? defaultCacheDuration,
        );
      }

      return result;
    } catch (e) {
      final buffer = await getBuffer<T>(key: bufferKey);
      return buffer;
    }
  }

  /// Refresh buffer after successful API call
  Future<void> refreshBuffer<T>({
    required Future<T> Function() apiCall,
    required String bufferKey,
    Duration? cacheDuration,
  }) async {
    try {
      final result = await apiCall();
      await saveBuffer<T>(
        key: bufferKey,
        data: result,
        expiration: cacheDuration ?? defaultCacheDuration,
      );
    } catch (e) {
      // Don't throw on refresh failure - buffer is still available
      debugPrint('BufferManager: Refresh failed for $bufferKey: $e');
    }
  }

  /// Get buffer info for debugging
  Future<Map<String, dynamic>> getBufferInfo() async {
    await init();

    return {
      'memoryCacheKeys': _memoryCache.keys.toList(),
      'persistentCacheKeys': _prefs
          ?.getKeys()
          .where((k) => k.startsWith('buffer_'))
          .toList(),
    };
  }

  /// Execute API call with automatic retry for temporary failures
  /// Retries on ServerUnavailableException with exponential backoff
  Future<T> withRetry<T>({
    required Future<T> Function() apiCall,
    required String operationName,
    int maxRetries = 3,
    Duration initialDelay = const Duration(seconds: 1),
    Duration maxDelay = const Duration(seconds: 10),
  }) async {
    int attempt = 0;
    Duration currentDelay = initialDelay;

    while (attempt < maxRetries) {
      attempt++;
      try {
        if (kDebugMode && attempt > 1) {
          debugPrint('Retry attempt $attempt/$maxRetries for $operationName');
        }
        return await apiCall();
      } on ServerUnavailableException {
        if (attempt >= maxRetries) {
          if (kDebugMode) {
            debugPrint(
              'Max retries ($maxRetries) reached for $operationName. Giving up.',
            );
          }
          rethrow;
        }

        // Add jitter to avoid thundering herd
        final jitter = Duration(milliseconds: math.Random().nextInt(500));
        final waitTime = currentDelay + jitter;

        if (kDebugMode) {
          debugPrint(
            'Server unavailable for $operationName. Retrying in ${waitTime.inMilliseconds}ms... (attempt $attempt/$maxRetries)',
          );
        }

        await Future.delayed(waitTime);

        // Exponential backoff with max cap
        currentDelay = Duration(
          milliseconds: math.min(
            currentDelay.inMilliseconds * 2,
            maxDelay.inMilliseconds,
          ),
        );
      } on TimeoutException {
        if (attempt >= maxRetries) {
          if (kDebugMode) {
            debugPrint(
              'Max retries ($maxRetries) reached for timeout on $operationName. Giving up.',
            );
          }
          rethrow;
        }

        final jitter = Duration(milliseconds: math.Random().nextInt(500));
        final waitTime = currentDelay + jitter;

        if (kDebugMode) {
          debugPrint(
            'Request timeout for $operationName. Retrying in ${waitTime.inMilliseconds}ms... (attempt $attempt/$maxRetries)',
          );
        }

        await Future.delayed(waitTime);
        currentDelay = Duration(
          milliseconds: math.min(
            currentDelay.inMilliseconds * 2,
            maxDelay.inMilliseconds,
          ),
        );
      }
    }

    // Should never reach here
    throw ApiException(message: 'Unexpected error in retry logic');
  }
}

/// Buffer keys for different data types
class BufferKeys {
  // Auth
  static const String currentUser = 'auth/current_user';

  // Trips
  static String trips({int page = 1, int limit = 20}) =>
      'trips/list_page_${page}_$limit';
  static String tripDetails(String tripId) => 'trips/details_$tripId';
  static const String activeTrip = 'trips/active';

  // Students
  static String students({String? guardianId}) =>
      guardianId != null ? 'students/guardian_$guardianId' : 'students/all';
  static String studentDetails(String studentId) =>
      'students/details_$studentId';

  // Routes
  static const String routes = 'routes/all';
  static String routeDetails(String routeId) => 'routes/details_$routeId';

  // Buses
  static const String buses = 'buses/all';
  static String busDetails(String busId) => 'buses/details_$busId';

  // Notifications
  static const String notifications = 'notifications/all';
  static const String unreadNotificationsCount = 'notifications/unread_count';

  // Chat
  static const String conversations = 'chat/conversations';
  static String chatMessages(String conversationId) =>
      'chat/messages_$conversationId';

  // User
  static String userProfile(String userId) => 'users/profile_$userId';
  static String userChildren(String userId) => 'users/children_$userId';

  // Guardians
  static String guardians({String? companyOrgId}) =>
      companyOrgId != null ? 'guardians/org_$companyOrgId' : 'guardians/all';
}

/// Extension methods for easy buffer access
extension BufferManagerExtension on BufferManager {
  /// Get trips from buffer
  Future<List<Map<String, dynamic>>?> getTripsBuffer({
    int page = 1,
    int limit = 20,
  }) async {
    final buffer = await getBuffer<List<dynamic>>(
      key: BufferKeys.trips(page: page, limit: limit),
    );
    if (buffer == null) return null;
    return buffer.cast<Map<String, dynamic>>();
  }

  /// Get students from buffer
  Future<List<Map<String, dynamic>>?> getStudentsBuffer({
    String? guardianId,
  }) async {
    final buffer = await getBuffer<List<dynamic>>(
      key: BufferKeys.students(guardianId: guardianId),
    );
    if (buffer == null) return null;
    return buffer.cast<Map<String, dynamic>>();
  }

  /// Get routes from buffer
  Future<List<Map<String, dynamic>>?> getRoutesBuffer() async {
    final buffer = await getBuffer<List<dynamic>>(key: BufferKeys.routes);
    if (buffer == null) return null;
    return buffer.cast<Map<String, dynamic>>();
  }

  /// Get notifications from buffer
  Future<List<Map<String, dynamic>>?> getNotificationsBuffer() async {
    final buffer = await getBuffer<List<dynamic>>(
      key: BufferKeys.notifications,
    );
    if (buffer == null) return null;
    return buffer.cast<Map<String, dynamic>>();
  }
}
