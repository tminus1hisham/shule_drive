import '../services/notification_service.dart';

/// Notification Helper
///
/// Convenience methods for showing common app notifications
class NotificationHelper {
  static final NotificationService _notifications = NotificationService();

  /// Show child picked up notification
  static Future<void> showChildPickedUp({
    required String studentName,
    required String tripId,
    String? stopName,
  }) async {
    await _notifications.notifyChildPickedUp(
      studentName: studentName,
      tripId: tripId,
      stopName: stopName,
      pickupTime: _formatTime(DateTime.now()),
    );
  }

  /// Show child absent notification
  static Future<void> showChildAbsent({
    required String studentName,
    required String tripId,
    String? stopName,
    String? reason,
  }) async {
    await _notifications.notifyChildAbsent(
      studentName: studentName,
      tripId: tripId,
      stopName: stopName,
      reason: reason,
    );
  }

  /// Show trip completed notification
  static Future<void> showTripCompleted({
    required String tripId,
    required String routeName,
    int? totalStudents,
    int? pickedCount,
    int? absentCount,
  }) async {
    await _notifications.notifyTripCompleted(
      tripId: tripId,
      routeName: routeName,
      totalStudents: totalStudents,
      pickedCount: pickedCount,
      absentCount: absentCount,
    );
  }

  /// Show trip started notification
  static Future<void> showTripStarted({
    required String tripId,
    required String routeName,
    String? vehicleNumber,
    int? studentCount,
  }) async {
    await _notifications.notifyTripStarted(
      tripId: tripId,
      routeName: routeName,
      vehicleNumber: vehicleNumber,
      studentCount: studentCount,
    );
  }

  /// Show generic success notification
  static Future<void> showSuccess({
    required String title,
    required String message,
  }) async {
    await _notifications.showLocalNotification(
      title: '✅ $title',
      body: message,
      channelId: 'trip_updates',
    );
  }

  /// Show generic error notification
  static Future<void> showError({
    required String title,
    required String message,
  }) async {
    await _notifications.showLocalNotification(
      title: '❌ $title',
      body: message,
      channelId: 'trip_updates',
    );
  }

  /// Format time for display
  static String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
