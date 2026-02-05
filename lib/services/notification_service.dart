import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notification_backends/firebase_backend.dart';
import 'notification_backends/mqtt_backend.dart';
import 'notification_backends/onesignal_backend.dart';

import 'local_database_service.dart';

/// Background message handler for Firebase (must be top-level)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(dynamic message) async {
  if (kDebugMode) {
    print('📨 Background message received: ${message.toString().substring(0, 100)}...');
  }

  // Save geofence alert to local database
  final db = LocalDatabaseService();
  await _handleGeofenceMessage(message, db);
}

Future<void> _handleGeofenceMessage(dynamic message, LocalDatabaseService db) async {
  Map<String, dynamic> data = {};
  
  if (message is Map) {
    data = message.map((k, v) => MapEntry(k.toString(), v));
  }
  
  if (data['type'] == 'geofence_alert' || data.containsKey('geofence_type')) {
    await db.saveGeofenceAlert(
      tripId: data['trip_id']?.toString() ?? data['tripId']?.toString() ?? '',
      studentId: data['student_id']?.toString() ?? data['studentId']?.toString(),
      alertType: data['alert_type']?.toString() ?? data['geofence_type']?.toString() ?? 'approaching',
      distanceMeters: data['distance_meters'] != null 
          ? double.tryParse(data['distance_meters'].toString()) 
          : data['distance'] != null 
              ? double.tryParse(data['distance'].toString())
              : null,
      etaMinutes: data['eta_minutes'] != null 
          ? int.tryParse(data['eta_minutes'].toString()) 
          : data['eta'] != null
              ? int.tryParse(data['eta'].toString())
              : null,
      latitude: double.tryParse(data['latitude']?.toString() ?? '0') ?? 0,
      longitude: double.tryParse(data['longitude']?.toString() ?? '0') ?? 0,
      sentNotification: true,
    );
  }
}

/// Notification Backend Types
enum NotificationBackend {
  /// Firebase Cloud Messaging (FCM)
  firebase,
  
  /// OneSignal (popular Firebase alternative)
  onesignal,
  
  /// MQTT-based notifications (uses existing MQTT connection)
  mqtt,
  
  /// Local notifications only (no push from server)
  localOnly,
}

/// Notification Service - Handles push notifications through multiple backends
/// 
/// Supports: Firebase, OneSignal, MQTT, or Local-only mode
/// Default: Firebase (if configured), falls back to Local-only
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final LocalDatabaseService _db = LocalDatabaseService();

  // Backend instances
  FirebaseNotificationBackend? _firebaseBackend;
  MqttNotificationBackend? _mqttBackend;
  OneSignalNotificationBackend? _oneSignalBackend;

  // Current backend
  NotificationBackend _currentBackend = NotificationBackend.localOnly;
  
  // Stream controllers for notification events
  final StreamController<GeofenceAlert> _geofenceAlertController = 
      StreamController<GeofenceAlert>.broadcast();
  
  Stream<GeofenceAlert> get geofenceAlertStream => _geofenceAlertController.stream;

  // Notification channels
  static const String _geofenceChannelId = 'geofence_alerts';
  static const String _geofenceChannelName = 'Geofence Alerts';
  static const String _geofenceChannelDesc = 'Notifications when bus is approaching pickup location';
  
  static const String _tripChannelId = 'trip_updates';
  static const String _tripChannelName = 'Trip Updates';
  static const String _tripChannelDesc = 'General trip status updates';
  
  static const String _chatChannelId = 'chat_messages';
  static const String _chatChannelName = 'Chat Messages';
  static const String _chatChannelDesc = 'New chat messages from driver/guardians';

  bool _initialized = false;
  String? _pushToken;

  /// Get current backend
  NotificationBackend get currentBackend => _currentBackend;
  
  /// Get push token
  String? get pushToken => _pushToken;

  /// Initialize notification service with selected backend
  /// 
  /// [preferredBackend] - Preferred notification backend. If not available,
  /// falls back to local-only mode.
  Future<void> initialize({
    NotificationBackend preferredBackend = NotificationBackend.firebase,
  }) async {
    if (_initialized) return;

    if (kDebugMode) {
      print('🔔 Initializing notification service with backend: $preferredBackend...');
    }

    // Request permission
    await _requestPermission();

    // Initialize local notifications (always needed)
    await _initializeLocalNotifications();

    // Try to initialize preferred backend
    await _initializeBackend(preferredBackend);

    _initialized = true;

    if (kDebugMode) {
      print('✅ Notification service initialized with backend: $_currentBackend');
    }
  }

  /// Initialize specific backend
  Future<void> _initializeBackend(NotificationBackend backend) async {
    switch (backend) {
      case NotificationBackend.firebase:
        if (await _tryInitializeFirebase()) {
          _currentBackend = NotificationBackend.firebase;
          return;
        }
        break;
        
      case NotificationBackend.onesignal:
        if (await _tryInitializeOneSignal()) {
          _currentBackend = NotificationBackend.onesignal;
          return;
        }
        break;
        
      case NotificationBackend.mqtt:
        _initializeMqtt();
        _currentBackend = NotificationBackend.mqtt;
        return;
        
      case NotificationBackend.localOnly:
        // No backend initialization needed
        _currentBackend = NotificationBackend.localOnly;
        return;
    }
    
    // Fallback to local-only
    if (kDebugMode) {
      print('⚠️ Preferred backend unavailable, falling back to local-only mode');
    }
    _currentBackend = NotificationBackend.localOnly;
  }

  /// Try to initialize Firebase
  Future<bool> _tryInitializeFirebase() async {
    try {
      _firebaseBackend = FirebaseNotificationBackend();
      final success = await _firebaseBackend!.initialize(
        onBackgroundMessage: _firebaseMessagingBackgroundHandler,
        onMessage: _handleForegroundMessage,
        onMessageOpenedApp: _handleMessageOpenedApp,
        onTokenRefresh: (token) {
          _pushToken = token;
          if (kDebugMode) {
            print('🔑 FCM Token refreshed: $token');
          }
        },
      );
      
      if (success) {
        _pushToken = _firebaseBackend!.token;
        return true;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Firebase initialization failed: $e');
      }
    }
    return false;
  }

  /// Try to initialize OneSignal
  Future<bool> _tryInitializeOneSignal() async {
    try {
      _oneSignalBackend = OneSignalNotificationBackend();
      final success = await _oneSignalBackend!.initialize(
        onNotificationReceived: _handleOneSignalNotification,
        onNotificationOpened: (data) => _handleNotificationNavigation(data.cast<String, dynamic>()),
      );
      
      if (success) {
        _pushToken = _oneSignalBackend!.playerId;
        return true;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ OneSignal initialization failed: $e');
      }
    }
    return false;
  }

  /// Initialize MQTT backend
  void _initializeMqtt() {
    _mqttBackend = MqttNotificationBackend();
    _mqttBackend!.initialize(
      onNotificationReceived: (data) => _handleMqttNotification(data),
    );
    
    if (kDebugMode) {
      print('📡 MQTT notification backend initialized');
    }
  }

  /// Switch to different backend
  Future<void> switchBackend(NotificationBackend backend) async {
    if (_currentBackend == backend) return;
    
    // Clean up current backend
    await _cleanupCurrentBackend();
    
    // Initialize new backend
    await _initializeBackend(backend);
  }

  Future<void> _cleanupCurrentBackend() async {
    switch (_currentBackend) {
      case NotificationBackend.firebase:
        await _firebaseBackend?.dispose();
        _firebaseBackend = null;
        break;
      case NotificationBackend.onesignal:
        await _oneSignalBackend?.dispose();
        _oneSignalBackend = null;
        break;
      case NotificationBackend.mqtt:
        await _mqttBackend?.dispose();
        _mqttBackend = null;
        break;
      case NotificationBackend.localOnly:
        // Nothing to clean up
        break;
    }
  }

  /// Request notification permissions
  Future<void> _requestPermission() async {
    if (Platform.isIOS) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    } else if (Platform.isAndroid) {
      // Android permissions are handled in manifest
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
    }
  }

  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create notification channels for Android
    await _createNotificationChannels();
  }

  /// Create Android notification channels
  Future<void> _createNotificationChannels() async {
    if (Platform.isAndroid) {
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      // Geofence alerts channel (high importance)
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _geofenceChannelId,
          _geofenceChannelName,
          description: _geofenceChannelDesc,
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        ),
      );

      // Trip updates channel (default importance)
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _tripChannelId,
          _tripChannelName,
          description: _tripChannelDesc,
          importance: Importance.defaultImportance,
          playSound: true,
          enableVibration: true,
        ),
      );

      // Chat messages channel (high importance)
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _chatChannelId,
          _chatChannelName,
          description: _chatChannelDesc,
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        ),
      );
    }
  }

  /// Handle foreground FCM messages
  Future<void> _handleForegroundMessage(dynamic message) async {
    if (kDebugMode) {
      print('📨 Foreground message received');
    }

    final data = _extractMessageData(message);
    
    // Handle geofence alerts
    if (data['type'] == 'geofence_alert' || data.containsKey('geofence_type')) {
      await _handleGeofenceAlert(data);
    }
    // Handle regular notifications
    else {
      await showLocalNotification(
        title: data['title']?.toString() ?? 'ShuleDrive',
        body: data['body']?.toString() ?? '',
        payload: jsonEncode(data),
        channelId: _getChannelIdForType(data['type']?.toString()),
      );
    }
  }

  /// Handle OneSignal notifications
  Future<void> _handleOneSignalNotification(Map<String, dynamic> data) async {
    if (kDebugMode) {
      print('📨 OneSignal notification received: $data');
    }

    if (data['type'] == 'geofence_alert' || data.containsKey('geofence_type')) {
      await _handleGeofenceAlert(data);
    } else {
      await showLocalNotification(
        title: data['title']?.toString() ?? 'ShuleDrive',
        body: data['body']?.toString() ?? '',
        payload: jsonEncode(data),
        channelId: _getChannelIdForType(data['type']?.toString()),
      );
    }
  }

  /// Handle MQTT notifications
  Future<void> _handleMqttNotification(Map<String, dynamic> data) async {
    if (kDebugMode) {
      print('📨 MQTT notification received: $data');
    }

    if (data['type'] == 'notification') {
      final payload = data['payload'] as Map<String, dynamic>? ?? {};
      
      if (payload['type'] == 'geofence_alert' || payload.containsKey('geofence_type')) {
        await _handleGeofenceAlert(payload);
      } else {
        await showLocalNotification(
          title: payload['title']?.toString() ?? 'ShuleDrive',
          body: payload['body']?.toString() ?? '',
          payload: jsonEncode(payload),
          channelId: _getChannelIdForType(payload['type']?.toString()),
        );
      }
    }
  }

  /// Extract data from message (handles different message formats)
  Map<String, dynamic> _extractMessageData(dynamic message) {
    if (message is Map<String, dynamic>) {
      // FCM message with notification
      if (message.containsKey('notification')) {
        final notification = message['notification'] as Map<String, dynamic>;
        final data = message['data'] as Map<String, dynamic>? ?? {};
        return {
          ...data,
          'title': notification['title'],
          'body': notification['body'],
        };
      }
      // Data-only message
      return message;
    }
    return {};
  }

  /// Handle geofence alert
  Future<void> _handleGeofenceAlert(Map<String, dynamic> data) async {
    final alertId = await _db.saveGeofenceAlert(
      tripId: data['trip_id']?.toString() ?? data['tripId']?.toString() ?? '',
      studentId: data['student_id']?.toString() ?? data['studentId']?.toString(),
      alertType: data['alert_type']?.toString() ?? data['geofence_type']?.toString() ?? 'approaching',
      distanceMeters: data['distance_meters'] != null 
          ? double.tryParse(data['distance_meters'].toString()) 
          : data['distance'] != null
              ? double.tryParse(data['distance'].toString())
              : null,
      etaMinutes: data['eta_minutes'] != null 
          ? int.tryParse(data['eta_minutes'].toString()) 
          : data['eta'] != null
              ? int.tryParse(data['eta'].toString())
              : null,
      latitude: double.tryParse(data['latitude']?.toString() ?? '0') ?? 0,
      longitude: double.tryParse(data['longitude']?.toString() ?? '0') ?? 0,
    );

    final alert = GeofenceAlert(
      id: alertId,
      tripId: data['trip_id']?.toString() ?? data['tripId']?.toString() ?? '',
      studentId: data['student_id']?.toString() ?? data['studentId']?.toString(),
      alertType: data['alert_type']?.toString() ?? data['geofence_type']?.toString() ?? 'approaching',
      distanceMeters: data['distance_meters'] != null 
          ? double.tryParse(data['distance_meters'].toString()) 
          : data['distance'] != null
              ? double.tryParse(data['distance'].toString())
              : null,
      etaMinutes: data['eta_minutes'] != null 
          ? int.tryParse(data['eta_minutes'].toString()) 
          : data['eta'] != null
              ? int.tryParse(data['eta'].toString())
              : null,
      latitude: double.tryParse(data['latitude']?.toString() ?? '0') ?? 0,
      longitude: double.tryParse(data['longitude']?.toString() ?? '0') ?? 0,
      triggeredAt: DateTime.now(),
      sentNotification: false,
    );

    // Show local notification
    await showLocalNotification(
      title: alert.title,
      body: alert.message,
      payload: jsonEncode({
        'type': 'geofence_alert',
        'trip_id': alert.tripId,
        'student_id': alert.studentId,
        'alert_id': alertId,
      }),
      channelId: _geofenceChannelId,
      importance: Importance.high,
    );

    // Mark as sent
    await _db.markAlertSent(alertId);

    // Emit to stream
    _geofenceAlertController.add(alert);
  }

  /// Handle notification tap when app is in background
  void _handleMessageOpenedApp(dynamic message) {
    if (kDebugMode) {
      print('📨 Notification opened app');
    }
    
    final data = _extractMessageData(message);
    _handleNotificationNavigation(data);
  }

  /// Handle local notification tap
  void _onNotificationTap(NotificationResponse response) {
    if (kDebugMode) {
      print('📨 Local notification tapped: ${response.payload}');
    }

    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        _handleNotificationNavigation(data);
      } catch (e) {
        if (kDebugMode) {
          print('❌ Error parsing notification payload: $e');
        }
      }
    }
  }

  /// Handle navigation based on notification data
  void _handleNotificationNavigation(Map<String, dynamic> data) {
    final type = data['type'];
    
    switch (type) {
      case 'geofence_alert':
        _navigateToTracking(data['trip_id'], data['student_id']);
        break;
      case 'trip_update':
      case 'trip_started':
      case 'trip_completed':
        _navigateToTrip(data['trip_id']);
        break;
      case 'student_picked_up':
      case 'student_absent':
        _navigateToTrip(data['trip_id']);
        break;
      case 'chat_message':
        _navigateToChat(data['conversation_id']);
        break;
    }
  }

  void _navigateToTracking(String? tripId, String? studentId) {
    // TODO: Implement navigation to tracking screen
    // This will be called when the app is opened from a geofence notification
  }

  void _navigateToTrip(String? tripId) {
    // TODO: Implement navigation to trip details
  }

  void _navigateToChat(String? conversationId) {
    // TODO: Implement navigation to chat screen
  }

  /// Show local notification
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
    String channelId = _tripChannelId,
    Importance importance = Importance.defaultImportance,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      _getChannelName(channelId),
      channelDescription: _getChannelDescription(channelId),
      importance: importance,
      priority: importance == Importance.high ? Priority.high : Priority.defaultPriority,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecond,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Show geofence notification directly (used by geofence handler)
  Future<void> showGeofenceNotification({
    required String title,
    required String body,
    required String tripId,
    String? studentId,
    Map<String, dynamic>? additionalData,
  }) async {
    final payload = jsonEncode({
      'type': 'geofence_alert',
      'trip_id': tripId,
      'student_id': studentId,
      ...?additionalData,
    });

    await showLocalNotification(
      title: title,
      body: body,
      payload: payload,
      channelId: _geofenceChannelId,
      importance: Importance.high,
    );
  }

  // ==================== TRIP & STUDENT NOTIFICATIONS ====================

  /// Notify when a child is picked up
  Future<void> notifyChildPickedUp({
    required String studentName,
    required String tripId,
    String? stopName,
    String? pickupTime,
  }) async {
    final title = '✅ $studentName Picked Up';
    final body = stopName != null 
        ? '$studentName has been picked up at $stopName${pickupTime != null ? ' at $pickupTime' : ''}'
        : '$studentName has been picked up successfully';

    await showLocalNotification(
      title: title,
      body: body,
      payload: jsonEncode({
        'type': 'student_picked_up',
        'trip_id': tripId,
        'student_name': studentName,
        'timestamp': DateTime.now().toIso8601String(),
      }),
      channelId: _tripChannelId,
      importance: Importance.high,
    );

    if (kDebugMode) {
      print('🔔 Child picked up notification: $studentName');
    }
  }

  /// Notify when a child is marked absent
  Future<void> notifyChildAbsent({
    required String studentName,
    required String tripId,
    String? stopName,
    String? reason,
  }) async {
    final title = '⚠️ $studentName Marked Absent';
    final body = reason != null 
        ? '$studentName is absent: $reason'
        : stopName != null 
            ? '$studentName was marked absent at $stopName'
            : '$studentName was marked absent for today\'s trip';

    await showLocalNotification(
      title: title,
      body: body,
      payload: jsonEncode({
        'type': 'student_absent',
        'trip_id': tripId,
        'student_name': studentName,
        'timestamp': DateTime.now().toIso8601String(),
      }),
      channelId: _tripChannelId,
      importance: Importance.high,
    );

    if (kDebugMode) {
      print('🔔 Child absent notification: $studentName');
    }
  }

  /// Notify when a trip is completed
  Future<void> notifyTripCompleted({
    required String tripId,
    required String routeName,
    int? totalStudents,
    int? pickedCount,
    int? absentCount,
  }) async {
    final title = '🎉 Trip Completed!';
    
    String body;
    if (pickedCount != null && totalStudents != null) {
      final percentage = ((pickedCount / totalStudents) * 100).round();
      body = 'Route "$routeName" completed. $pickedCount of $totalStudents students picked up ($percentage%). Great job!';
    } else {
      body = 'Route "$routeName" has been completed successfully. Great job!';
    }

    await showLocalNotification(
      title: title,
      body: body,
      payload: jsonEncode({
        'type': 'trip_completed',
        'trip_id': tripId,
        'route_name': routeName,
        'total_students': totalStudents,
        'picked_count': pickedCount,
        'absent_count': absentCount,
        'timestamp': DateTime.now().toIso8601String(),
      }),
      channelId: _tripChannelId,
      importance: Importance.high,
    );

    if (kDebugMode) {
      print('🔔 Trip completed notification: $routeName');
    }
  }

  /// Notify when a trip starts
  Future<void> notifyTripStarted({
    required String tripId,
    required String routeName,
    String? vehicleNumber,
    int? studentCount,
  }) async {
    final title = '🚌 Trip Started';
    final body = vehicleNumber != null 
        ? 'Route "$routeName" has started with vehicle $vehicleNumber${studentCount != null ? ' ($studentCount students)' : ''}'
        : 'Route "$routeName" has started${studentCount != null ? ' with $studentCount students' : ''}';

    await showLocalNotification(
      title: title,
      body: body,
      payload: jsonEncode({
        'type': 'trip_started',
        'trip_id': tripId,
        'route_name': routeName,
        'timestamp': DateTime.now().toIso8601String(),
      }),
      channelId: _tripChannelId,
      importance: Importance.high,
    );

    if (kDebugMode) {
      print('🔔 Trip started notification: $routeName');
    }
  }

  /// Subscribe to topic (backend-specific)
  Future<void> subscribeToTopic(String topic) async {
    switch (_currentBackend) {
      case NotificationBackend.firebase:
        await _firebaseBackend?.subscribeToTopic(topic);
        break;
      case NotificationBackend.onesignal:
        await _oneSignalBackend?.subscribeToTag('topic', topic);
        break;
      case NotificationBackend.mqtt:
        await _mqttBackend?.subscribeToTopic('notifications/$topic');
        break;
      case NotificationBackend.localOnly:
        // No-op
        break;
    }
    
    if (kDebugMode) {
      print('📌 Subscribed to topic: $topic');
    }
  }

  /// Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    switch (_currentBackend) {
      case NotificationBackend.firebase:
        await _firebaseBackend?.unsubscribeFromTopic(topic);
        break;
      case NotificationBackend.onesignal:
        await _oneSignalBackend?.unsubscribeFromTag('topic', topic);
        break;
      case NotificationBackend.mqtt:
        await _mqttBackend?.unsubscribeFromTopic('notifications/$topic');
        break;
      case NotificationBackend.localOnly:
        // No-op
        break;
    }
    
    if (kDebugMode) {
      print('📌 Unsubscribed from topic: $topic');
    }
  }

  /// Subscribe to trip updates
  Future<void> subscribeToTrip(String tripId) async {
    await subscribeToTopic('trip_$tripId');
  }

  /// Unsubscribe from trip updates
  Future<void> unsubscribeFromTrip(String tripId) async {
    await unsubscribeFromTopic('trip_$tripId');
  }

  /// Subscribe to student/guardian updates
  Future<void> subscribeToStudent(String studentId) async {
    await subscribeToTopic('student_$studentId');
  }

  /// Unsubscribe from student updates
  Future<void> unsubscribeFromStudent(String studentId) async {
    await unsubscribeFromTopic('student_$studentId');
  }

  /// Send token to backend
  Future<void> sendTokenToBackend(String userId) async {
    if (_pushToken == null) return;
    
    // TODO: Implement API call to register push token with backend
    // await _apiService.registerPushToken(
    //   userId: userId, 
    //   token: _pushToken!,
    //   backend: _currentBackend.name,
    // );
    
    if (kDebugMode) {
      print('📤 Push token registered for user: $userId (backend: $_currentBackend)');
    }
  }

  /// Helper methods
  String _getChannelIdForType(String? type) {
    switch (type) {
      case 'geofence_alert':
        return _geofenceChannelId;
      case 'chat_message':
        return _chatChannelId;
      default:
        return _tripChannelId;
    }
  }

  String _getChannelName(String channelId) {
    switch (channelId) {
      case _geofenceChannelId:
        return _geofenceChannelName;
      case _chatChannelId:
        return _chatChannelName;
      default:
        return _tripChannelName;
    }
  }

  String _getChannelDescription(String channelId) {
    switch (channelId) {
      case _geofenceChannelId:
        return _geofenceChannelDesc;
      case _chatChannelId:
        return _chatChannelDesc;
      default:
        return _tripChannelDesc;
    }
  }

  /// Dispose
  void dispose() {
    _geofenceAlertController.close();
    _cleanupCurrentBackend();
  }
}

/// Geofence notification types
enum GeofenceAlertType {
  approaching,  // ~5 minutes away / 2km
  arriving,     // ~1 minute away / 500m
  arrived,      // At stop / 100m
}

extension GeofenceAlertTypeExtension on GeofenceAlertType {
  String get displayName {
    switch (this) {
      case GeofenceAlertType.approaching:
        return 'Bus Approaching';
      case GeofenceAlertType.arriving:
        return 'Bus Arriving Soon';
      case GeofenceAlertType.arrived:
        return 'Bus Has Arrived';
    }
  }

  String get description {
    switch (this) {
      case GeofenceAlertType.approaching:
        return 'The bus is about 5 minutes away from your stop';
      case GeofenceAlertType.arriving:
        return 'The bus will arrive at your stop in about 1 minute';
      case GeofenceAlertType.arrived:
        return 'The bus has arrived at your stop';
    }
  }
}
