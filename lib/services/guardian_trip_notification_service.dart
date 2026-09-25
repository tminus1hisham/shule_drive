import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../mqtt_client.dart';
import '../utils/student_trip_logic.dart';
import 'notification_service.dart';

/// A live student pick/drop/absent update received by a guardian over MQTT.
class GuardianStudentStatusEvent {
  final String studentId;
  final String studentName;
  final String status; // 'picked' | 'dropped' | 'absent'
  final String? tripId;
  final String? vehicleNumber;
  final DateTime timestamp;

  GuardianStudentStatusEvent({
    required this.studentId,
    required this.studentName,
    required this.status,
    this.tripId,
    this.vehicleNumber,
    required this.timestamp,
  });
}

/// Listens over MQTT for the driver's per-student pick/drop/absent events
/// addressed to this guardian's phone, raises a local notification, and
/// re-broadcasts them so guardian screens can live-update.
///
/// The driver side publishes from `TripProvider`; both ends agree on
/// [topicForPhone] / [buildPayload]. MQTT only delivers while the app is
/// connected (foreground) — true background delivery would need push (FCM).
class GuardianTripNotificationService {
  static final GuardianTripNotificationService _instance =
      GuardianTripNotificationService._internal();
  factory GuardianTripNotificationService() => _instance;
  GuardianTripNotificationService._internal();

  final MqttService _mqtt = MqttService();
  final NotificationService _notifications = NotificationService();

  final StreamController<GuardianStudentStatusEvent> _controller =
      StreamController<GuardianStudentStatusEvent>.broadcast();

  /// Live student status updates for the currently-listening guardian.
  Stream<GuardianStudentStatusEvent> get updates => _controller.stream;

  String? _subscribedTopic;

  static const String _eventType = 'student_status';

  /// MQTT topic a guardian listens on / a driver publishes to for a phone.
  static String topicForPhone(String guardianPhone) {
    final digits = normalizeGuardianPhone(guardianPhone);
    return 'shuledrive/guardians/$digits/student-status';
  }

  /// Payload a driver publishes for a single student status change.
  static Map<String, dynamic> buildPayload({
    required String studentId,
    required String studentName,
    required String status,
    String? tripId,
    String? vehicleNumber,
  }) {
    return {
      'event': _eventType,
      'studentId': studentId,
      'studentName': studentName,
      'status': status,
      'tripId': tripId,
      'vehicleNumber': vehicleNumber,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };
  }

  /// Start listening for [guardianPhone]'s student updates. Idempotent; when
  /// the phone changes it re-subscribes to the new topic.
  Future<void> start(String guardianPhone) async {
    final digits = normalizeGuardianPhone(guardianPhone);
    if (digits.isEmpty) return;

    final topic = topicForPhone(guardianPhone);
    if (_subscribedTopic == topic) return; // already listening

    await stop();

    // MqttService keeps the callback registered even if this first connect
    // fails, and subscribes it once a reconnect succeeds.
    _subscribedTopic = topic;
    try {
      await _mqtt.subscribe(topic, _onMessage);
      if (kDebugMode) {
        print('🔔 Guardian listening for student updates on $topic');
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ Guardian topic pending MQTT reconnect: $e');
    }
  }

  /// Stop listening (e.g. on logout).
  Future<void> stop() async {
    final topic = _subscribedTopic;
    if (topic == null) return;
    _subscribedTopic = null;
    try {
      await _mqtt.unsubscribe(topic, _onMessage);
    } catch (_) {
      // Ignore; nothing actionable if unsubscribe fails.
    }
  }

  void _onMessage(String topic, String message) {
    try {
      final decoded = jsonDecode(message);
      if (decoded is! Map) return;
      final data = Map<String, dynamic>.from(decoded);
      if (data['event'] != _eventType) return;

      final status = data['status']?.toString() ?? '';
      if (status != 'picked' && status != 'dropped' && status != 'absent') {
        return;
      }

      final event = GuardianStudentStatusEvent(
        studentId: data['studentId']?.toString() ?? '',
        studentName: data['studentName']?.toString() ?? 'Your child',
        status: status,
        tripId: data['tripId']?.toString(),
        vehicleNumber: data['vehicleNumber']?.toString(),
        timestamp:
            DateTime.tryParse(data['timestamp']?.toString() ?? '') ??
            DateTime.now(),
      );

      _showNotification(event);
      _controller.add(event);
    } catch (e) {
      if (kDebugMode) print('⚠️ Bad guardian status message: $e');
    }
  }

  /// Title/body for a status alert. Driver push and guardian MQTT both use
  /// this, so the body doubles as the de-dup key across the two channels.
  static ({String title, String body})? describe({
    required String status,
    required String studentName,
    String? vehicleNumber,
  }) {
    final bus = (vehicleNumber != null && vehicleNumber.isNotEmpty)
        ? ' (bus $vehicleNumber)'
        : '';
    switch (status) {
      case 'picked':
        return (
          title: '✅ $studentName picked up',
          body: '$studentName has been picked up$bus.',
        );
      case 'dropped':
        return (
          title: '🏠 $studentName dropped off',
          body: '$studentName has been dropped off$bus.',
        );
      case 'absent':
        return (
          title: '⚠️ $studentName marked absent',
          body: '$studentName was marked absent for this trip.',
        );
    }
    return null;
  }

  final List<String> _recentBodies = [];

  /// Show a local notification unless the same alert was shown recently
  /// (it can arrive over both MQTT and Firebase).
  Future<void> showOnce({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!markSeen(body)) return;
    await _notifications.showLocalNotification(
      title: title,
      body: body,
      channelId: 'trip_updates',
      payload: payload,
    );
  }

  /// Returns false if [body] was already seen. Keeps the last 50.
  @visibleForTesting
  bool markSeen(String body) {
    if (_recentBodies.contains(body)) return false;
    _recentBodies.add(body);
    if (_recentBodies.length > 50) _recentBodies.removeAt(0);
    return true;
  }

  Future<void> _showNotification(GuardianStudentStatusEvent e) async {
    final text = describe(
      status: e.status,
      studentName: e.studentName,
      vehicleNumber: e.vehicleNumber,
    );
    if (text == null) return;

    await showOnce(
      title: text.title,
      body: text.body,
      payload: jsonEncode({
        'type': 'guardian_student_status',
        'studentId': e.studentId,
        'status': e.status,
        'tripId': e.tripId,
      }),
    );
  }
}
