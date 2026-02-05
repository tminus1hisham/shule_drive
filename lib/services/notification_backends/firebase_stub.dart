import 'dart:async';
import 'package:flutter/foundation.dart';

/// Firebase Notification Backend Stub
/// 
/// Used for web builds or when Firebase is not configured
/// Falls back to local-only notifications
class FirebaseNotificationBackend {
  String? get token => null;

  Future<bool> initialize({
    required Function(dynamic) onBackgroundMessage,
    required Function(dynamic) onMessage,
    required Function(dynamic) onMessageOpenedApp,
    required Function(String?) onTokenRefresh,
  }) async {
    if (kDebugMode) {
      print('🔔 Firebase: Not available (stub implementation)');
    }
    return false;
  }

  Future<void> subscribeToTopic(String topic) async {}
  Future<void> unsubscribeFromTopic(String topic) async {}
  Future<void> dispose() async {}
}
