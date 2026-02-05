import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// OneSignal Notification Backend
/// 
/// Implements push notifications using OneSignal API
/// OneSignal is a popular Firebase alternative with a generous free tier
class OneSignalNotificationBackend {
  static const String _restApiBase = 'https://onesignal.com/api/v1';
  
  String? _appId;
  String? _restApiKey;
  String? _playerId;
  String? get playerId => _playerId;

  /// Initialize OneSignal
  /// 
  /// [appId] - Your OneSignal App ID
  /// [restApiKey] - Your OneSignal REST API Key (for server-side operations)
  /// 
  /// Note: For production, use the official OneSignal SDK instead of HTTP API
  Future<bool> initialize({
    String? appId,
    String? restApiKey,
    required Function(Map<String, dynamic>) onNotificationReceived,
    required Function(Map<String, dynamic>) onNotificationOpened,
  }) async {
    _appId = appId;
    _restApiKey = restApiKey;

    // Note: For proper OneSignal integration, you should use the official
    // onesignal_flutter package. This is a simplified HTTP-based implementation.
    
    // For now, we'll simulate initialization
    // In production, initialize the OneSignal SDK here
    
    if (kDebugMode) {
      print('🔔 OneSignal: Initializing...');
      print('   Note: Install onesignal_flutter package for full functionality');
    }

    // Generate a mock player ID (in production, get from OneSignal SDK)
    _playerId = 'onesignal_${DateTime.now().millisecondsSinceEpoch}';

    return true;
  }

  /// Register device with OneSignal
  /// 
  /// Call this after getting push token from platform
  Future<void> registerDevice({
    required String pushToken,
    required String platform, // 'ios' or 'android'
    String? externalUserId,
  }) async {
    if (_appId == null || _restApiKey == null) return;

    try {
      final response = await http.post(
        Uri.parse('$_restApiBase/players'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'app_id': _appId,
          'identifier': pushToken,
          'device_type': platform == 'ios' ? 0 : 1,
          'external_user_id': externalUserId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _playerId = data['id'];
        
        if (kDebugMode) {
          print('🔑 OneSignal: Player ID: $_playerId');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ OneSignal registration error: $e');
      }
    }
  }

  /// Subscribe to tag/topic
  Future<void> subscribeToTag(String key, String value) async {
    if (_playerId == null || _appId == null) return;

    try {
      await http.put(
        Uri.parse('$_restApiBase/players/$_playerId'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'app_id': _appId,
          'tags': {key: value},
        }),
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ OneSignal subscribe error: $e');
      }
    }
  }

  /// Unsubscribe from tag/topic
  Future<void> unsubscribeFromTag(String key, String value) async {
    if (_playerId == null || _appId == null) return;

    try {
      // Remove tag by setting empty value
      await http.put(
        Uri.parse('$_restApiBase/players/$_playerId'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'app_id': _appId,
          'tags': {key: ''},
        }),
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ OneSignal unsubscribe error: $e');
      }
    }
  }

  /// Send notification to specific users (server-side operation)
  /// 
  /// This should typically be called from your backend server
  Future<void> sendNotification({
    required List<String> playerIds,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    if (_appId == null || _restApiKey == null) {
      throw Exception('OneSignal not properly initialized');
    }

    try {
      await http.post(
        Uri.parse('$_restApiBase/notifications'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic $_restApiKey',
        },
        body: jsonEncode({
          'app_id': _appId,
          'include_player_ids': playerIds,
          'headings': {'en': title},
          'contents': {'en': body},
          'data': data,
        }),
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ OneSignal send error: $e');
      }
    }
  }

  /// Dispose
  Future<void> dispose() async {
    // Cleanup if needed
  }
}
