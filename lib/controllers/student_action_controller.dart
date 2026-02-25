import 'dart:async';
import 'package:flutter/material.dart';
import '../models/student.dart';
import '../services/notification_service.dart';
import '../services/guardian_notification_service.dart' show GuardianNotificationService, StudentGuardianInfo;
import '../mqtt_client.dart';
import '../utils/offline_storage.dart';

/// Student Action Controller - Handles pick, drop, and absent actions
/// 
/// Features:
/// - Pick individual students
/// - Drop individual students
/// - Mark students as absent
/// - Pick all students (bulk)
/// - Drop all students (complete trip)
/// - Local notifications for driver
/// - Guardian notifications via SMS/WhatsApp/MQTT
/// - Offline support with sync queue
class StudentActionController extends ChangeNotifier {
  final NotificationService _notificationService = NotificationService();
  final GuardianNotificationService _guardianService = GuardianNotificationService();
  final MqttService _mqttService = MqttService();
  final OfflineStorage _offlineStorage = OfflineStorage();

  bool _isLoading = false;
  String? _error;
  String? _currentTripId;
  String? _busPlate;
  List<Student> _students = [];
  Set<String> _processedStudentIds = {};
  Set<String> _notifiedStudentIds = {}; // For proximity alerts

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Student> get students => List.unmodifiable(_students);
  List<Student> get activeStudents => _students.where((s) => 
    s.status == StudentStatus.pending).toList();
  List<Student> get pickedStudents => _students.where((s) => 
    s.status == StudentStatus.picked).toList();
  List<Student> get absentStudents => _students.where((s) => 
    s.status == StudentStatus.absent).toList();

  /// Initialize controller
  Future<void> initialize({
    required String tripId,
    String? busPlate,
    required List<Student> students,
  }) async {
    _currentTripId = tripId;
    _busPlate = busPlate;
    _students = students;
    
    // Load persisted state
    await _loadPersistedState();
    
    notifyListeners();
  }

  /// Load persisted student states
  Future<void> _loadPersistedState() async {
    for (final student in _students) {
      final status = await _offlineStorage.getStudentStatus(
        tripId: _currentTripId ?? '',
        studentId: student.id,
      );
      if (status != null) {
        student.status = status;
      }
    }
  }

  // ============================================================================
  // INDIVIDUAL STUDENT ACTIONS
  // ============================================================================

  /// Pick a single student
  Future<bool> pickStudent({
    required BuildContext context,
    required Student student,
    required String guardianPhone,
    double? latitude,
    double? longitude,
    bool notifyGuardian = true,
    bool useWhatsApp = false,
  }) async {
    if (_processedStudentIds.contains(student.id)) return false;
    
    final confirmed = await _showConfirmationDialog(
      context: context,
      title: 'Pick ${student.name}?',
      message: 'Are you sure you want to pick ${student.name}?',
      confirmText: 'Pick Up',
      confirmColor: const Color(0xFF6B9B5B),
    );
    
    if (!confirmed) return false;

    _setLoading(true);
    _processedStudentIds.add(student.id);

    try {
      // 1. Call API (with offline fallback)
      await _callPickStudentAPI(
        studentId: student.id,
        latitude: latitude,
        longitude: longitude,
      );

      // 2. Update local state
      student.status = StudentStatus.picked;
      await _offlineStorage.saveStudentStatus(
        tripId: _currentTripId ?? '',
        studentId: student.id,
        status: StudentStatus.picked,
      );

      // 3. Show local notification
      await _notificationService.notifyChildPickedUp(
        studentName: student.name,
        tripId: _currentTripId ?? '',
      );

      // 4. Notify guardian
      if (notifyGuardian) {
        await _guardianService.notifyStudentPicked(
          guardianPhone: guardianPhone,
          studentName: student.name,
          busPlate: _busPlate,
          useWhatsApp: useWhatsApp,
        );
      }

      // 5. Publish MQTT
      _publishStudentAction(
        student: student,
        action: 'Picked',
        latitude: latitude,
        longitude: longitude,
      );

      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _processedStudentIds.remove(student.id);
      _setError('Failed to pick ${student.name}');
      _setLoading(false);
      return false;
    }
  }

  /// Mark student as absent
  Future<bool> markStudentAbsent({
    required BuildContext context,
    required Student student,
    required String guardianPhone,
    String? reason,
    bool notifyGuardian = true,
    bool useWhatsApp = false,
  }) async {
    if (_processedStudentIds.contains(student.id)) return false;

    final confirmed = await _showConfirmationDialog(
      context: context,
      title: 'Mark ${student.name} Absent?',
      message: 'Are you sure you want to mark ${student.name} as absent?',
      confirmText: 'Mark Absent',
      confirmColor: Colors.orange,
    );

    if (!confirmed) return false;

    _setLoading(true);
    _processedStudentIds.add(student.id);

    try {
      await _callAbsentStudentAPI(
        studentId: student.id,
        reason: reason ?? 'Student not available',
      );

      student.status = StudentStatus.absent;
      await _offlineStorage.saveStudentStatus(
        tripId: _currentTripId ?? '',
        studentId: student.id,
        status: StudentStatus.absent,
      );

      await _notificationService.notifyChildAbsent(
        studentName: student.name,
        tripId: _currentTripId ?? '',
        reason: reason,
      );

      if (notifyGuardian) {
        await _guardianService.notifyStudentAbsent(
          guardianPhone: guardianPhone,
          studentName: student.name,
          reason: reason,
          useWhatsApp: useWhatsApp,
        );
      }

      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _processedStudentIds.remove(student.id);
      _setError('Failed to mark ${student.name} as absent');
      _setLoading(false);
      return false;
    }
  }

  // ============================================================================
  // BULK ACTIONS
  // ============================================================================

  /// Pick all pending students
  Future<bool> pickAllStudents({
    required BuildContext context,
    required List<StudentGuardianPair> studentGuardians,
    double? latitude,
    double? longitude,
    bool notifyGuardians = true,
    bool useWhatsApp = false,
  }) async {
    final pendingStudents = activeStudents;
    if (pendingStudents.isEmpty) return false;

    final confirmed = await _showConfirmationDialog(
      context: context,
      title: 'Pick All Students?',
      message: 'Pick all ${pendingStudents.length} students?',
      confirmText: 'Pick All',
      confirmColor: const Color(0xFF6B9B5B),
    );

    if (!confirmed) return false;

    _setLoading(true);

    try {
      await _callPickAllAPI(
        latitude: latitude,
        longitude: longitude,
      );

      for (final student in pendingStudents) {
        student.status = StudentStatus.picked;
        await _offlineStorage.saveStudentStatus(
          tripId: _currentTripId ?? '',
          studentId: student.id,
          status: StudentStatus.picked,
        );
      }

      await _notificationService.showLocalNotification(
        title: '🚌 All Students Picked',
        body: '${pendingStudents.length} students picked',
        channelId: 'trip_updates',
      );

      if (notifyGuardians) {
        final guardianInfo = studentGuardians
            .where((sg) => pendingStudents.any((s) => s.id == sg.student.id))
            .map((sg) => StudentGuardianInfo(
                  studentId: sg.student.id,
                  studentName: sg.student.name,
                  guardianPhone: sg.guardianPhone,
                ))
            .toList();

        await _guardianService.notifyPickAll(
          students: guardianInfo,
          busPlate: _busPlate,
          useWhatsApp: useWhatsApp,
        );
      }

      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to pick all students');
      _setLoading(false);
      return false;
    }
  }

  /// Complete trip / Drop all
  Future<bool> completeTrip({
    required BuildContext context,
    required List<StudentGuardianPair> studentGuardians,
    double? latitude,
    double? longitude,
    bool isDroppingAll = true,
    bool notifyGuardians = true,
    bool useWhatsApp = false,
    VoidCallback? onComplete,
  }) async {
    final confirmed = await _showConfirmationDialog(
      context: context,
      title: 'Complete Trip?',
      message: 'Are you sure you want to complete this trip?',
      confirmText: 'Complete Trip',
      confirmColor: const Color(0xFF6B9B5B),
    );

    if (!confirmed) return false;

    _setLoading(true);

    try {
      await _callCompleteTripAPI(
        latitude: latitude,
        longitude: longitude,
        isDroppingAll: isDroppingAll,
      );

      await _offlineStorage.clearTripData(_currentTripId ?? '');

      await _notificationService.notifyTripCompleted(
        tripId: _currentTripId ?? '',
        routeName: 'Current Trip',
        totalStudents: _students.length,
        pickedCount: pickedStudents.length,
        absentCount: absentStudents.length,
      );

      if (notifyGuardians) {
        final guardianInfo = studentGuardians.map((sg) => StudentGuardianInfo(
              studentId: sg.student.id,
              studentName: sg.student.name,
              guardianPhone: sg.guardianPhone,
            )).toList();

        await _guardianService.notifyTripCompleted(
          students: guardianInfo,
          useWhatsApp: useWhatsApp,
        );
      }

      _setLoading(false);
      onComplete?.call();
      return true;
    } catch (e) {
      _setError('Failed to complete trip');
      _setLoading(false);
      return false;
    }
  }

  // ============================================================================
  // PROXIMITY ALERTS
  // ============================================================================

  Future<void> handleProximityAlert({
    required Student student,
    required String guardianPhone,
    required double distanceMeters,
    String? eta,
    bool notifyGuardian = true,
    bool useWhatsApp = false,
  }) async {
    if (_notifiedStudentIds.contains(student.id)) return;
    _notifiedStudentIds.add(student.id);

    await _notificationService.showLocalNotification(
      title: '📍 Approaching ${student.name}',
      body: eta != null 
          ? 'Bus is $eta away'
          : '${(distanceMeters / 1000).toStringAsFixed(1)} km away',
      channelId: 'geofence_alerts',
    );

    if (notifyGuardian) {
      await _guardianService.notifyProximityAlert(
        guardianPhone: guardianPhone,
        studentName: student.name,
        stopName: 'pickup',
        eta: eta ?? '1 minute',
        useWhatsApp: useWhatsApp,
      );
    }
  }

  // ============================================================================
  // API CALLS (Stubs)
  // ============================================================================

  Future<void> _callPickStudentAPI({
    required String studentId,
    double? latitude,
    double? longitude,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
  }

  Future<void> _callAbsentStudentAPI({
    required String studentId,
    required String reason,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
  }

  Future<void> _callPickAllAPI({
    double? latitude,
    double? longitude,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> _callCompleteTripAPI({
    double? latitude,
    double? longitude,
    required bool isDroppingAll,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
  }

  // ============================================================================
  // MQTT
  // ============================================================================

  void _publishStudentAction({
    required Student student,
    required String action,
    double? latitude,
    double? longitude,
  }) {
    if (!_mqttService.isConnected) return;

    final topic = 'driver/$_busPlate/student/${student.id}/${action.toLowerCase()}';
    final payload = {
      'tripsMaster': true,
      'studentReg': student.id,
      'uniqueTripIdentity': _currentTripId,
      'numberPlate': _busPlate,
      'action': action,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': DateTime.now().toIso8601String(),
    };

    _mqttService.publishJson(topic, payload);
  }

  // ============================================================================
  // UI HELPERS
  // ============================================================================

  Future<bool> _showConfirmationDialog({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmText,
    required Color confirmColor,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _error = message;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _guardianService.dispose();
    super.dispose();
  }
}

// ============================================================================
// DATA MODELS
// ============================================================================

class StudentGuardianPair {
  final Student student;
  final String guardianPhone;

  StudentGuardianPair({
    required this.student,
    required this.guardianPhone,
  });
}
