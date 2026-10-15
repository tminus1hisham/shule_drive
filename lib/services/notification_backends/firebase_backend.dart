import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Firebase Cloud Messaging backend — Android only. iOS guardians get alerts
/// over MQTT instead, so there is no APNs setup.
///
/// Background/killed-app notifications are drawn by Android itself from the
/// FCM notification payload, so no background handler is registered.
class FirebaseNotificationBackend {
  static bool get _supported => !kIsWeb && Platform.isAndroid;

  String? _token;
  String? get token => _token;

  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onOpenedSub;
  StreamSubscription<String>? _onTokenSub;

  /// FCM token to send at login, or null when push isn't available here.
  static Future<String?> currentToken() async {
    if (!_supported) return null;
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

  /// Drops this install's FCM token so the backend's copy goes dead and
  /// the logged-out phone stops getting the account's pushes. The next
  /// login fetches and sends a fresh one.
  // ponytail: offline logout can't reach FCM, so pushes continue until the
  // backend gets a clear-token endpoint.
  static Future<void> forgetToken() async {
    if (!_supported) return;
    try {
      await Firebase.initializeApp();
      await FirebaseMessaging.instance.deleteToken().timeout(
        const Duration(seconds: 5),
      );
    } catch (e) {
      if (kDebugMode) print('⚠️ FCM token delete failed: $e');
    }
  }

  static const _sentTokenKey = 'fcm_token_sent_at_login';

  /// The backend only learns the token at login; remember which one it got.
  static Future<void> rememberSentToken(String token) async {
    if (token.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sentTokenKey, token);
  }

  /// This phone's token when it isn't the one the backend got at the last
  /// login (older build, rotated token, other Firebase project). Returns it at most once per token (see [rememberReloginAsked])
  /// so a login that can't fetch a token never loops.
  static Future<String?> tokenServerLacks() async {
    final current = await currentToken();
    if (current == null || current.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_sentTokenKey) == current ||
        prefs.getString(_askedTokenKey) == current) {
      return null;
    }
    return current;
  }

  /// Call after logout (which clears preferences).
  static Future<void> rememberReloginAsked(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_askedTokenKey, token);
  }

  static const _askedTokenKey = 'fcm_token_relogin_asked';

  Future<bool> initialize({
    required Function(dynamic) onBackgroundMessage,
    required Function(dynamic) onMessage,
    required Function(dynamic) onMessageOpenedApp,
    required Function(String?) onTokenRefresh,
  }) async {
    if (!_supported) return false;

    await Firebase.initializeApp();
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();
    _token = await messaging.getToken();
    if (_token == null) return false;

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
