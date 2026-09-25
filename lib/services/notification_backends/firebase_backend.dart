import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Firebase Cloud Messaging backend — Android only. iOS guardians get alerts
/// over MQTT instead, so there is no APNs setup.
///
/// Background/killed-app notifications are drawn by Android itself from the
/// FCM notification payload, so no background handler is registered.
class FirebaseNotificationBackend {
  String? _token;
  String? get token => _token;

  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onOpenedSub;
  StreamSubscription<String>? _onTokenSub;

  /// FCM token to send at login, or null when push isn't available here.
  static Future<String?> currentToken() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    try {
      await Firebase.initializeApp();
      return await FirebaseMessaging.instance.getToken().timeout(
        const Duration(seconds: 5),
      );
    } catch (e) {
      if (kDebugMode) print('⚠️ FCM token unavailable: $e');
      return null;
    }
  }

  Future<bool> initialize({
    required Function(dynamic) onBackgroundMessage,
    required Function(dynamic) onMessage,
    required Function(dynamic) onMessageOpenedApp,
    required Function(String?) onTokenRefresh,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return false;

    await Firebase.initializeApp();
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();
    _token = await messaging.getToken();

    _onMessageSub = FirebaseMessaging.onMessage.listen(
      (m) => onMessage(_toMap(m)),
    );
    _onOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen(
      (m) => onMessageOpenedApp(_toMap(m)),
    );
    // ponytail: the backend only learns the token at login, so a rotated
    // token stops pushes until the next login. Needs a token-update endpoint.
    _onTokenSub = messaging.onTokenRefresh.listen((t) {
      _token = t;
      onTokenRefresh(t);
    });
    return _token != null;
  }

  /// Shape NotificationService._extractMessageData expects.
  static Map<String, dynamic> _toMap(RemoteMessage m) => {
    'data': Map<String, dynamic>.from(m.data),
    'notification': <String, dynamic>{
      'title': m.notification?.title,
      'body': m.notification?.body,
    },
  };

  Future<void> subscribeToTopic(String topic) =>
      FirebaseMessaging.instance.subscribeToTopic(topic);

  Future<void> unsubscribeFromTopic(String topic) =>
      FirebaseMessaging.instance.unsubscribeFromTopic(topic);

  Future<void> dispose() async {
    await _onMessageSub?.cancel();
    await _onOpenedSub?.cancel();
    await _onTokenSub?.cancel();
  }
}
