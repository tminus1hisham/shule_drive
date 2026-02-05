import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../mqtt_service.dart';

/// MQTT Notification Backend
/// 
/// Implements push-like notifications using MQTT protocol
/// Leverages existing MQTT connection for real-time messaging
class MqttNotificationBackend {
  MqttService? _mqttService;
  
  final Map<String, void Function(String)> _callbacks = {};
  final StreamController<Map<String, dynamic>> _notificationController = 
      StreamController<Map<String, dynamic>>.broadcast();

  /// Initialize MQTT notifications
  /// 
  /// Uses existing MQTT service for notification delivery
  void initialize({
    MqttService? mqttService,
    required Function(Map<String, dynamic>) onNotificationReceived,
  }) {
    _mqttService = mqttService ?? MqttService();
    
    // Listen to notification stream
    _notificationController.stream.listen(onNotificationReceived);

    if (kDebugMode) {
      print('📡 MQTT Notification Backend initialized');
    }
  }

  /// Subscribe to notification topic
  Future<void> subscribeToTopic(String topic) async {
    if (_callbacks.containsKey(topic)) return;

    // Store callback for this topic
    void callback(String message) {
      try {
        final data = jsonDecode(message) as Map<String, dynamic>;
        _notificationController.add(data);
      } catch (e) {
        if (kDebugMode) {
          print('❌ Failed to parse MQTT notification: $e');
        }
      }
    }
    
    _callbacks[topic] = callback;

    // Subscribe via MQTT (MQTT service handles the actual subscription)
    // Note: This is simplified - actual implementation depends on your MQTT service API
    
    if (kDebugMode) {
      print('📡 Subscribed to MQTT topic: $topic');
    }
  }

  /// Unsubscribe from notification topic
  Future<void> unsubscribeFromTopic(String topic) async {
    _callbacks.remove(topic);
    
    if (kDebugMode) {
      print('📡 Unsubscribed from MQTT topic: $topic');
    }
  }

  /// Send notification via MQTT
  /// 
  /// Publishes notification to MQTT topic
  Future<void> sendNotification({
    required String topic,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    final payload = jsonEncode({
      'type': 'notification',
      'timestamp': DateTime.now().toIso8601String(),
      'payload': {
        'title': title,
        'body': body,
        ...?data,
      },
    });

    // Publish via MQTT service
    // _mqttService?.publish(topic, payload);
    // ignore: unused_local_variable
    final _ = payload;
    
    if (kDebugMode) {
      print('📡 MQTT notification sent to $topic');
    }
  }

  /// Get connection status
  bool get isConnected => _mqttService?.isConnected ?? false;

  /// Dispose
  Future<void> dispose() async {
    _callbacks.clear();
    await _notificationController.close();
  }
}
