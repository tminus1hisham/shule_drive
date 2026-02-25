import 'dart:async';
import 'package:flutter/foundation.dart';
import '../api/api_client.dart';

/// Guardian Notification Service - Handles SMS/WhatsApp notifications to guardians
/// 
/// Features:
/// - Send SMS notifications via API
/// - Send WhatsApp notifications via API
/// - Format message templates
/// - Queue notifications for retry on failure
/// - Batch notifications for bulk operations
class GuardianNotificationService {
  static final GuardianNotificationService _instance = GuardianNotificationService._internal();
  factory GuardianNotificationService() => _instance;
  GuardianNotificationService._internal();

  // ignore: unused_field
  final ApiClient _apiClient = ApiClient();  // Reserved for future SMS API integration
  
  // Queue for failed notifications to retry later
  final List<QueuedNotification> _notificationQueue = [];
  Timer? _retryTimer;
  
  /// Initialize the service
  Future<void> initialize() async {
    // Start retry timer
    _retryTimer = Timer.periodic(const Duration(minutes: 2), (_) => _processQueue());
    
    if (kDebugMode) {
      print('📱 GuardianNotificationService initialized');
    }
  }

  /// Dispose the service
  void dispose() {
    _retryTimer?.cancel();
  }

  // ============================================================================
  // SMS NOTIFICATIONS
  // ============================================================================

  /// Send SMS to a single guardian
  /// 
  /// [phone] - Guardian phone number
  /// [message] - Message content
  Future<bool> sendSMS({
    required String phone,
    required String message,
  }) async {
    try {
      if (kDebugMode) {
        print('📱 Sending SMS to $phone: $message');
      }

      // TODO: Replace with actual SMS API endpoint when available
      // For now, simulate API call
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Uncomment when SMS endpoint is ready:
      // await _apiClient.post(
      //   Endpoints.sendSMS,
      //   body: {
      //     'phone': phone,
      //     'message': message,
      //   },
      // );

      if (kDebugMode) {
        print('✅ SMS sent successfully to $phone');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to send SMS to $phone: $e');
      }
      
      // Queue for retry
      _queueNotification(QueuedNotification(
        type: NotificationType.sms,
        phone: phone,
        message: message,
        retryCount: 0,
      ));
      
      return false;
    }
  }

  /// Send bulk SMS to multiple guardians
  /// 
  /// Returns list of failed phone numbers
  Future<List<String>> sendBulkSMS({
    required List<SMSRecipient> recipients,
  }) async {
    final failedRecipients = <String>[];
    
    // Process in batches of 10 to avoid overwhelming the API
    const batchSize = 10;
    for (var i = 0; i < recipients.length; i += batchSize) {
      final batch = recipients.skip(i).take(batchSize).toList();
      
      await Future.wait(batch.map((recipient) async {
        final success = await sendSMS(
          phone: recipient.phone,
          message: recipient.message,
        );
        if (!success) {
          failedRecipients.add(recipient.phone);
        }
      }));
      
      // Small delay between batches
      if (i + batchSize < recipients.length) {
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    if (kDebugMode) {
      print('📱 Bulk SMS complete: ${recipients.length - failedRecipients.length}/${recipients.length} sent');
    }
    
    return failedRecipients;
  }

  // ============================================================================
  // WHATSAPP NOTIFICATIONS
  // ============================================================================

  /// Send WhatsApp message to a single guardian
  /// 
  /// [phone] - Guardian phone number (with country code)
  /// [message] - Message content
  Future<bool> sendWhatsApp({
    required String phone,
    required String message,
  }) async {
    try {
      if (kDebugMode) {
        print('💬 Sending WhatsApp to $phone: $message');
      }

      // TODO: Replace with actual WhatsApp API endpoint when available
      // For now, simulate API call
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Uncomment when WhatsApp endpoint is ready:
      // await _apiClient.post(
      //   Endpoints.sendWhatsApp,
      //   body: {
      //     'phone': phone,
      //     'message': message,
      //   },
      // );

      if (kDebugMode) {
        print('✅ WhatsApp sent successfully to $phone');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to send WhatsApp to $phone: $e');
      }
      
      // Queue for retry
      _queueNotification(QueuedNotification(
        type: NotificationType.whatsapp,
        phone: phone,
        message: message,
        retryCount: 0,
      ));
      
      return false;
    }
  }

  // ============================================================================
  // MESSAGE TEMPLATES
  // ============================================================================

  /// Format message based on notification type
  String formatMessage({
    required NotificationActionType type,
    required String studentName,
    String? busPlate,
    String? stopName,
    String? eta,
  }) {
    final appName = 'ShuleDrive';
    final timeStr = _formatTime(DateTime.now());
    
    switch (type) {
      case NotificationActionType.picked:
        return '$appName: $studentName has been picked up. Bus: ${busPlate ?? 'N/A'}. Time: $timeStr';
        
      case NotificationActionType.dropped:
        return '$appName: $studentName has been dropped off at home. Time: $timeStr';
        
      case NotificationActionType.absent:
        return '$appName: $studentName was not available for pickup today. Please contact the school if this was a mistake.';
        
      case NotificationActionType.proximity:
        return '$appName: The bus is ${eta ?? '1 minute'} away from $stopName. Please get $studentName ready.';
        
      case NotificationActionType.tripStarted:
        return '$appName: The school bus for $studentName has started. Bus: ${busPlate ?? 'N/A'}. Track in real-time on the app.';
        
      case NotificationActionType.tripCompleted:
        return '$appName: The trip has been completed. $studentName has been safely dropped off.';
        
      case NotificationActionType.pickAll:
        return '$appName: Your child $studentName has been picked up along with other students. Bus: ${busPlate ?? 'N/A'}.';
        
      case NotificationActionType.dropAll:
        return '$appName: $studentName and all other students have been dropped off safely. Thank you!';
    }
  }

  /// Format time for messages
  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  // ============================================================================
  // HIGH-LEVEL NOTIFICATION METHODS
  // ============================================================================

  /// Notify guardian that student was picked up
  Future<bool> notifyStudentPicked({
    required String guardianPhone,
    required String studentName,
    String? busPlate,
    bool useWhatsApp = false,
  }) async {
    final message = formatMessage(
      type: NotificationActionType.picked,
      studentName: studentName,
      busPlate: busPlate,
    );

    if (useWhatsApp) {
      return await sendWhatsApp(phone: guardianPhone, message: message);
    } else {
      return await sendSMS(phone: guardianPhone, message: message);
    }
  }

  /// Notify guardian that student was dropped off
  Future<bool> notifyStudentDropped({
    required String guardianPhone,
    required String studentName,
    bool useWhatsApp = false,
  }) async {
    final message = formatMessage(
      type: NotificationActionType.dropped,
      studentName: studentName,
    );

    if (useWhatsApp) {
      return await sendWhatsApp(phone: guardianPhone, message: message);
    } else {
      return await sendSMS(phone: guardianPhone, message: message);
    }
  }

  /// Notify guardian that student was marked absent
  Future<bool> notifyStudentAbsent({
    required String guardianPhone,
    required String studentName,
    String? reason,
    bool useWhatsApp = false,
  }) async {
    final message = formatMessage(
      type: NotificationActionType.absent,
      studentName: studentName,
    );

    if (useWhatsApp) {
      return await sendWhatsApp(phone: guardianPhone, message: message);
    } else {
      return await sendSMS(phone: guardianPhone, message: message);
    }
  }

  /// Notify guardian of proximity alert (bus approaching)
  Future<bool> notifyProximityAlert({
    required String guardianPhone,
    required String studentName,
    required String stopName,
    String? eta,
    bool useWhatsApp = false,
  }) async {
    final message = formatMessage(
      type: NotificationActionType.proximity,
      studentName: studentName,
      stopName: stopName,
      eta: eta,
    );

    if (useWhatsApp) {
      return await sendWhatsApp(phone: guardianPhone, message: message);
    } else {
      return await sendSMS(phone: guardianPhone, message: message);
    }
  }

  /// Send trip started notification to all guardians
  Future<void> notifyTripStarted({
    required List<StudentGuardianInfo> students,
    String? busPlate,
    bool useWhatsApp = false,
  }) async {
    final recipients = students.map((student) => SMSRecipient(
      phone: student.guardianPhone,
      message: formatMessage(
        type: NotificationActionType.tripStarted,
        studentName: student.studentName,
        busPlate: busPlate,
      ),
    )).toList();

    await sendBulkSMS(recipients: recipients);
  }

  /// Send bulk pick notification to all guardians
  Future<void> notifyPickAll({
    required List<StudentGuardianInfo> students,
    String? busPlate,
    bool useWhatsApp = false,
  }) async {
    final recipients = students.map((student) => SMSRecipient(
      phone: student.guardianPhone,
      message: formatMessage(
        type: NotificationActionType.pickAll,
        studentName: student.studentName,
        busPlate: busPlate,
      ),
    )).toList();

    await sendBulkSMS(recipients: recipients);
  }

  /// Send trip completed notification to all guardians
  Future<void> notifyTripCompleted({
    required List<StudentGuardianInfo> students,
    bool useWhatsApp = false,
  }) async {
    final recipients = students.map((student) => SMSRecipient(
      phone: student.guardianPhone,
      message: formatMessage(
        type: NotificationActionType.tripCompleted,
        studentName: student.studentName,
      ),
    )).toList();

    await sendBulkSMS(recipients: recipients);
  }

  // ============================================================================
  // QUEUE MANAGEMENT
  // ============================================================================

  /// Add notification to retry queue
  void _queueNotification(QueuedNotification notification) {
    _notificationQueue.add(notification);
    
    if (kDebugMode) {
      print('📥 Notification queued for retry: ${notification.phone}');
    }
  }

  /// Process queued notifications
  Future<void> _processQueue() async {
    if (_notificationQueue.isEmpty) return;

    if (kDebugMode) {
      print('🔄 Processing ${_notificationQueue.length} queued notifications');
    }

    final queueCopy = List<QueuedNotification>.from(_notificationQueue);
    _notificationQueue.clear();

    for (final notification in queueCopy) {
      if (notification.retryCount >= 3) {
        if (kDebugMode) {
          print('❌ Max retries reached for ${notification.phone}');
        }
        continue;
      }

      bool success = false;
      if (notification.type == NotificationType.sms) {
        success = await sendSMS(
          phone: notification.phone,
          message: notification.message,
        );
      } else {
        success = await sendWhatsApp(
          phone: notification.phone,
          message: notification.message,
        );
      }

      if (!success) {
        // Re-queue with incremented retry count
        _notificationQueue.add(notification.copyWith(
          retryCount: notification.retryCount + 1,
        ));
      }

      // Small delay between retries
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  /// Get pending notification count
  int get pendingCount => _notificationQueue.length;

  /// Clear all pending notifications
  void clearQueue() {
    _notificationQueue.clear();
  }
}

// ============================================================================
// DATA MODELS
// ============================================================================

enum NotificationType { sms, whatsapp }

enum NotificationActionType {
  picked,
  dropped,
  absent,
  proximity,
  tripStarted,
  tripCompleted,
  pickAll,
  dropAll,
}

class SMSRecipient {
  final String phone;
  final String message;

  SMSRecipient({
    required this.phone,
    required this.message,
  });
}

class StudentGuardianInfo {
  final String studentId;
  final String studentName;
  final String guardianPhone;

  StudentGuardianInfo({
    required this.studentId,
    required this.studentName,
    required this.guardianPhone,
  });
}

class QueuedNotification {
  final NotificationType type;
  final String phone;
  final String message;
  final int retryCount;
  final DateTime queuedAt;

  QueuedNotification({
    required this.type,
    required this.phone,
    required this.message,
    this.retryCount = 0,
    DateTime? queuedAt,
  }) : queuedAt = queuedAt ?? DateTime.now();

  QueuedNotification copyWith({
    NotificationType? type,
    String? phone,
    String? message,
    int? retryCount,
    DateTime? queuedAt,
  }) {
    return QueuedNotification(
      type: type ?? this.type,
      phone: phone ?? this.phone,
      message: message ?? this.message,
      retryCount: retryCount ?? this.retryCount,
      queuedAt: queuedAt ?? this.queuedAt,
    );
  }
}
