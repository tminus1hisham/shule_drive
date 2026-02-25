import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/student.dart';

/// Offline Storage - Persists student states and trip data locally
/// 
/// Features:
/// - Save student pick/absent status
/// - Load student status on app restart
/// - Queue actions for sync when online
/// - Clear data after trip completion
class OfflineStorage {
  static final OfflineStorage _instance = OfflineStorage._internal();
  factory OfflineStorage() => _instance;
  OfflineStorage._internal();

  SharedPreferences? _prefs;
  bool _initialized = false;

  // Storage keys
  static const String _studentStatusPrefix = 'student_status_';
  static const String _actionQueuePrefix = 'action_queue_';
  static const String _tripDataPrefix = 'trip_data_';

  /// Initialize storage
  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
  }

  /// Ensure initialized
  Future<void> _ensureInitialized() async {
    if (!_initialized) await init();
  }

  // ============================================================================
  // STUDENT STATUS
  // ============================================================================

  /// Save student status
  Future<bool> saveStudentStatus({
    required String tripId,
    required String studentId,
    required StudentStatus status,
  }) async {
    await _ensureInitialized();
    final key = '$_studentStatusPrefix${tripId}_$studentId';
    return await _prefs!.setString(key, status.name);
  }

  /// Get student status
  Future<StudentStatus?> getStudentStatus({
    required String tripId,
    required String studentId,
  }) async {
    await _ensureInitialized();
    final key = '$_studentStatusPrefix${tripId}_$studentId';
    final value = _prefs!.getString(key);
    if (value == null) return null;
    
    return StudentStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => StudentStatus.pending,
    );
  }

  /// Get all student statuses for a trip
  Future<Map<String, StudentStatus>> getAllStudentStatuses(String tripId) async {
    await _ensureInitialized();
    final prefix = '$_studentStatusPrefix${tripId}_';
    final result = <String, StudentStatus>{};
    
    for (final key in _prefs!.getKeys()) {
      if (key.startsWith(prefix)) {
        final studentId = key.substring(prefix.length);
        final value = _prefs!.getString(key);
        if (value != null) {
          result[studentId] = StudentStatus.values.firstWhere(
            (s) => s.name == value,
            orElse: () => StudentStatus.pending,
          );
        }
      }
    }
    
    return result;
  }

  // ============================================================================
  // ACTION QUEUE (for offline sync)
  // ============================================================================

  /// Queue an action for later sync
  Future<bool> queueAction({
    required String tripId,
    required QueuedAction action,
  }) async {
    await _ensureInitialized();
    final key = '$_actionQueuePrefix$tripId';
    final existing = _prefs!.getStringList(key) ?? [];
    
    final actionJson = jsonEncode({
      'type': action.type.name,
      'studentId': action.studentId,
      'timestamp': action.timestamp.toIso8601String(),
      'data': action.data,
    });
    
    existing.add(actionJson);
    return await _prefs!.setStringList(key, existing);
  }

  /// Get queued actions for a trip
  Future<List<QueuedAction>> getQueuedActions(String tripId) async {
    await _ensureInitialized();
    final key = '$_actionQueuePrefix$tripId';
    final actionsJson = _prefs!.getStringList(key) ?? [];
    
    return actionsJson.map((json) {
      final data = jsonDecode(json) as Map<String, dynamic>;
      return QueuedAction(
        type: ActionType.values.firstWhere(
          (t) => t.name == data['type'],
          orElse: () => ActionType.pick,
        ),
        studentId: data['studentId'] as String,
        timestamp: DateTime.parse(data['timestamp'] as String),
        data: data['data'] as Map<String, dynamic>?,
      );
    }).toList();
  }

  /// Remove processed actions from queue
  Future<bool> removeQueuedActions(String tripId, List<String> studentIds) async {
    await _ensureInitialized();
    final key = '$_actionQueuePrefix$tripId';
    final existing = _prefs!.getStringList(key) ?? [];
    
    existing.removeWhere((json) {
      final data = jsonDecode(json) as Map<String, dynamic>;
      return studentIds.contains(data['studentId'] as String);
    });
    
    return await _prefs!.setStringList(key, existing);
  }

  /// Clear all queued actions for a trip
  Future<bool> clearQueuedActions(String tripId) async {
    await _ensureInitialized();
    final key = '$_actionQueuePrefix$tripId';
    return await _prefs!.remove(key);
  }

  // ============================================================================
  // TRIP DATA
  // ============================================================================

  /// Save trip data
  Future<bool> saveTripData({
    required String tripId,
    required Map<String, dynamic> data,
  }) async {
    await _ensureInitialized();
    final key = '$_tripDataPrefix$tripId';
    return await _prefs!.setString(key, jsonEncode(data));
  }

  /// Get trip data
  Future<Map<String, dynamic>?> getTripData(String tripId) async {
    await _ensureInitialized();
    final key = '$_tripDataPrefix$tripId';
    final value = _prefs!.getString(key);
    if (value == null) return null;
    return jsonDecode(value) as Map<String, dynamic>;
  }

  /// Clear all trip data
  Future<bool> clearTripData(String tripId) async {
    await _ensureInitialized();
    
    // Clear student statuses
    final prefix = '$_studentStatusPrefix${tripId}_';
    for (final key in _prefs!.getKeys().toList()) {
      if (key.startsWith(prefix)) {
        await _prefs!.remove(key);
      }
    }
    
    // Clear action queue
    await clearQueuedActions(tripId);
    
    // Clear trip data
    final tripKey = '$_tripDataPrefix$tripId';
    await _prefs!.remove(tripKey);
    
    return true;
  }

  // ============================================================================
  // GLOBAL CLEAR
  // ============================================================================

  /// Clear all stored data (use with caution)
  Future<bool> clearAll() async {
    await _ensureInitialized();
    
    for (final key in _prefs!.getKeys().toList()) {
      if (key.startsWith(_studentStatusPrefix) ||
          key.startsWith(_actionQueuePrefix) ||
          key.startsWith(_tripDataPrefix)) {
        await _prefs!.remove(key);
      }
    }
    
    return true;
  }
}

// ============================================================================
// DATA MODELS
// ============================================================================

enum ActionType {
  pick,
  absent,
  drop,
  pickAll,
  dropAll,
}

class QueuedAction {
  final ActionType type;
  final String studentId;
  final DateTime timestamp;
  final Map<String, dynamic>? data;

  QueuedAction({
    required this.type,
    required this.studentId,
    required this.timestamp,
    this.data,
  });
}
