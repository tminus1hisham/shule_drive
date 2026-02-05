import 'dart:async';
import 'package:flutter/foundation.dart';

/// Firebase Notification Backend
/// 
/// This is a stub implementation. When Firebase is not available,
/// the service falls back to local-only mode.
/// 
/// To use Firebase:
/// 1. Uncomment firebase dependencies in pubspec.yaml
/// 2. Replace this file with the full Firebase implementation
class FirebaseNotificationBackend {
  String? _token;
  String? get token => _token;

  Future<bool> initialize({
    required Function(dynamic) onBackgroundMessage,
    required Function(dynamic) onMessage,
    required Function(dynamic) onMessageOpenedApp,
    required Function(String?) onTokenRefresh,
  }) async {
    // Firebase not configured - return false to trigger fallback
    if (kDebugMode) {
      print('🔔 Firebase: Not configured (stub implementation)');
      print('   To use Firebase, uncomment dependencies in pubspec.yaml');
    }
    return false;
  }

  Future<void> subscribeToTopic(String topic) async {}
  Future<void> unsubscribeFromTopic(String topic) async {}
  Future<void> dispose() async {}
}
