import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:workmanager/workmanager.dart';
import 'local_database_service.dart';
import '../api/api_exceptions.dart';
import '../api/services/trip_service.dart';
import '../api/services/student_service.dart';

/// Background sync task name
const String _syncTaskName = 'shuledrive_background_sync';

/// WorkManager callback dispatcher
@pragma('vm:entry-point')
void _callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (kDebugMode) {
      print('🔄 Background sync task started: $task');
    }

    try {
      final syncManager = OfflineSyncManager();
      final result = await syncManager.syncPendingOperations();
      
      if (kDebugMode) {
        print('🔄 Background sync completed: $result');
      }
      
      return result.success;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Background sync failed: $e');
      }
      return false;
    }
  });
}

/// Offline Sync Manager
/// 
/// Handles synchronization of pending operations when connectivity is restored.
/// Monitors network state and triggers automatic sync.
class OfflineSyncManager {
  static final OfflineSyncManager _instance = OfflineSyncManager._internal();
  factory OfflineSyncManager() => _instance;
  OfflineSyncManager._internal();

  final LocalDatabaseService _db = LocalDatabaseService();
  final Connectivity _connectivity = Connectivity();
  
  TripService? _tripService;
  StudentService? _studentService;

  // Stream subscription for connectivity changes
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  
  // Sync state
  final StreamController<SyncState> _syncStateController = 
      StreamController<SyncState>.broadcast();
  
  Stream<SyncState> get syncStateStream => _syncStateController.stream;
  
  bool _isInitialized = false;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;

  /// Initialize sync manager
  Future<void> initialize() async {
    if (_isInitialized) return;

    if (kDebugMode) {
      print('🔄 Initializing offline sync manager...');
    }

    // Initialize WorkManager for background sync
    await Workmanager().initialize(
      _callbackDispatcher,
      isInDebugMode: kDebugMode,
    );

    // Register periodic sync task
    await _registerBackgroundSync();

    // Listen for connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _onConnectivityChanged,
    );

    // Check initial connectivity
    final initialResult = await _connectivity.checkConnectivity();
    _onConnectivityChanged(initialResult);

    _isInitialized = true;

    if (kDebugMode) {
      print('✅ Offline sync manager initialized');
    }
  }

  /// Initialize services (call after login)
  void initializeServices({
    TripService? tripService,
    StudentService? studentService,
  }) {
    _tripService = tripService;
    _studentService = studentService;
  }

  /// Register background sync task
  Future<void> _registerBackgroundSync() async {
    try {
      await Workmanager().registerPeriodicTask(
        _syncTaskName,
        _syncTaskName,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: true,
        ),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
      );

      if (kDebugMode) {
        print('🔄 Background sync registered (every 15 minutes)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to register background sync: $e');
      }
    }
  }

  /// Handle connectivity changes
  void _onConnectivityChanged(List<ConnectivityResult> results) async {
    // Check if any connection is available (not just the first one)
    final hasConnection = results.isNotEmpty && 
        !results.every((r) => r == ConnectivityResult.none);
    
    if (kDebugMode) {
      print('📶 Connectivity changed: $results');
    }

    if (hasConnection && !_isSyncing) {
      // Trigger sync when connection restored
      await syncPendingOperations();
    }
  }

  /// Sync all pending operations
  Future<SyncResult> syncPendingOperations() async {
    if (_isSyncing) {
      return SyncResult.alreadySyncing();
    }

    _isSyncing = true;
    _syncStateController.add(SyncState.inProgress());

    if (kDebugMode) {
      print('🔄 Starting sync...');
    }

    final pendingOps = await _db.getPendingOperations();
    
    if (pendingOps.isEmpty) {
      _isSyncing = false;
      _lastSyncTime = DateTime.now();
      _syncStateController.add(SyncState.completed(0, 0));
      
      if (kDebugMode) {
        print('✅ No pending operations to sync');
      }
      
      return SyncResult.success(synced: 0, failed: 0);
    }

    int successCount = 0;
    int failCount = 0;
    List<String> errors = [];

    // Sort by priority (lower number = higher priority)
    pendingOps.sort((a, b) => a.priority.compareTo(b.priority));

    for (final op in pendingOps) {
      if (kDebugMode) {
        print('🔄 Processing: ${op.operationType} ${op.entityType} (ID: ${op.id})');
      }

      try {
        final success = await _processOperation(op);
        
        if (success) {
          await _db.removePendingOperation(op.id);
          successCount++;
          
          if (kDebugMode) {
            print('✅ Synced: ${op.operationType} ${op.entityType}');
          }
        } else {
          failCount++;
          await _handleOperationFailure(op, 'Processing failed');
        }
      } catch (e) {
        failCount++;
        final errorMsg = e.toString();
        errors.add('${op.id}: $errorMsg');
        
        await _handleOperationFailure(op, errorMsg);
        
        if (kDebugMode) {
          print('❌ Failed to sync: ${op.operationType} ${op.entityType} - $errorMsg');
        }
      }
    }

    _isSyncing = false;
    _lastSyncTime = DateTime.now();
    
    final state = failCount == 0
        ? SyncState.completed(successCount, failCount)
        : SyncState.partial(successCount, failCount, errors);
    
    _syncStateController.add(state);

    // Clear completed operations
    await _db.clearCompletedOperations();

    if (kDebugMode) {
      print('🔄 Sync completed: $successCount success, $failCount failed');
    }

    return SyncResult(
      success: failCount == 0,
      syncedCount: successCount,
      failedCount: failCount,
      errors: errors,
    );
  }

  /// Process a single operation
  Future<bool> _processOperation(PendingOperation op) async {
    final payload = _parsePayload(op.payload);
    
    switch (op.entityType) {
      case 'trip':
        return await _processTripOperation(op, payload);
      case 'student':
        return await _processStudentOperation(op, payload);
      case 'attendance':
        return await _processAttendanceOperation(op, payload);
      default:
        // Unknown entity type - mark as failed
        return false;
    }
  }

  /// Process trip-related operations
  Future<bool> _processTripOperation(
    PendingOperation op, 
    Map<String, dynamic> payload
  ) async {
    if (_tripService == null) return false;

    try {
      switch (op.operationType) {
        case 'create':
          // TODO: Implement trip creation
          break;
        case 'update':
          // TODO: Implement trip update
          break;
        case 'delete':
          // TODO: Implement trip delete
          break;
        case 'start':
          await _tripService!.startTrip(
            routeId: payload['route_id'],
            vehicleId: payload['vehicle_id'],
            studentIds: payload['student_ids']?.cast<String>(),
          );
          return true;
        case 'end':
          if (op.entityId != null) {
            await _tripService!.endTrip(op.entityId!);
            return true;
          }
          break;
        case 'update_student_status':
          await _tripService!.updateStudentStatus(
            tripId: payload['trip_id'],
            studentId: payload['student_id'],
            status: payload['status'],
            notes: payload['notes'],
          );
          return true;
      }
      return false;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw Exception('Trip operation failed: $e');
    }
  }

  /// Process student-related operations
  Future<bool> _processStudentOperation(
    PendingOperation op, 
    Map<String, dynamic> payload
  ) async {
    if (_studentService == null) return false;

    try {
      switch (op.operationType) {
        case 'create':
          await _studentService!.createStudent(
            name: payload['name'],
            className: payload['class_name'],
            schoolId: payload['school_id'],
            guardianId: payload['guardian_id'],
            photo: payload['photo'],
            pickupLocation: payload['pickup_location'],
            dropoffLocation: payload['dropoff_location'],
            emergencyContact: payload['emergency_contact'],
            emergencyPhone: payload['emergency_phone'],
          );
          return true;
        case 'update':
          if (op.entityId != null) {
            await _studentService!.updateStudent(
              studentId: op.entityId!,
              name: payload['name'],
              className: payload['class_name'],
              schoolId: payload['school_id'],
              photo: payload['photo'],
              pickupLocation: payload['pickup_location'],
              dropoffLocation: payload['dropoff_location'],
              emergencyContact: payload['emergency_contact'],
              emergencyPhone: payload['emergency_phone'],
            );
            return true;
          }
          break;
        case 'delete':
          if (op.entityId != null) {
            await _studentService!.deleteStudent(op.entityId!);
            return true;
          }
          break;
      }
      return false;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw Exception('Student operation failed: $e');
    }
  }

  /// Process attendance-related operations
  Future<bool> _processAttendanceOperation(
    PendingOperation op,
    Map<String, dynamic> payload
  ) async {
    // Attendance operations are handled through trip service
    if (_tripService == null) return false;

    try {
      await _tripService!.updateStudentStatus(
        tripId: payload['trip_id'],
        studentId: payload['student_id'],
        status: payload['status'],
        notes: payload['notes'],
      );
      return true;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw Exception('Attendance operation failed: $e');
    }
  }

  /// Handle operation failure
  Future<void> _handleOperationFailure(PendingOperation op, String error) async {
    final newRetryCount = op.retryCount + 1;
    
    await _db.updateOperationRetry(
      op.id,
      retryCount: newRetryCount,
      error: error,
    );

    // If exceeded max retries, could notify user or log for manual review
    if (newRetryCount >= 5) {
      if (kDebugMode) {
        print('⚠️ Operation ${op.id} exceeded max retries');
      }
    }
  }

  /// Parse payload string to map
  Map<String, dynamic> _parsePayload(String payload) {
    try {
      return jsonDecode(payload) as Map<String, dynamic>;
    } catch (e) {
      return {};
    }
  }

  /// Queue operation for later sync
  Future<int> queueOperation({
    required String operationType,
    required String entityType,
    String? entityId,
    required Map<String, dynamic> payload,
    int priority = 5,
  }) async {
    return await _db.queuePendingOperation(
      operationType: operationType,
      entityType: entityType,
      entityId: entityId,
      payload: payload,
      priority: priority,
    );
  }

  /// Get pending operations count
  Future<int> getPendingCount() async {
    final ops = await _db.getPendingOperations();
    return ops.length;
  }

  /// Get sync status
  Future<SyncStatusInfo> getSyncStatus() async {
    final pendingCount = await getPendingCount();
    final metadata = await _db.getAllSyncMetadata();
    
    return SyncStatusInfo(
      isSyncing: _isSyncing,
      lastSyncTime: _lastSyncTime,
      pendingOperations: pendingCount,
      entityMetadata: metadata,
    );
  }

  /// Force immediate sync
  Future<SyncResult> forceSync() async {
    return await syncPendingOperations();
  }

  /// Cancel background sync
  Future<void> cancelBackgroundSync() async {
    await Workmanager().cancelByUniqueName(_syncTaskName);
  }

  /// Dispose
  void dispose() {
    _connectivitySubscription?.cancel();
    _syncStateController.close();
  }
}

/// Sync state
class SyncState {
  final SyncStatus status;
  final int syncedCount;
  final int failedCount;
  final List<String>? errors;
  final DateTime? timestamp;

  SyncState({
    required this.status,
    this.syncedCount = 0,
    this.failedCount = 0,
    this.errors,
    this.timestamp,
  });

  factory SyncState.idle() => SyncState(status: SyncStatus.idle);
  factory SyncState.inProgress() => SyncState(
    status: SyncStatus.inProgress,
    timestamp: DateTime.now(),
  );
  factory SyncState.completed(int synced, int failed) => SyncState(
    status: SyncStatus.completed,
    syncedCount: synced,
    failedCount: failed,
    timestamp: DateTime.now(),
  );
  factory SyncState.partial(int synced, int failed, List<String> errors) => SyncState(
    status: SyncStatus.partial,
    syncedCount: synced,
    failedCount: failed,
    errors: errors,
    timestamp: DateTime.now(),
  );
  factory SyncState.error(List<String> errors) => SyncState(
    status: SyncStatus.error,
    errors: errors,
    timestamp: DateTime.now(),
  );

  bool get isIdle => status == SyncStatus.idle;
  bool get isInProgress => status == SyncStatus.inProgress;
  bool get isCompleted => status == SyncStatus.completed;
  bool get hasErrors => failedCount > 0 || (errors?.isNotEmpty ?? false);
}

enum SyncStatus {
  idle,
  inProgress,
  completed,
  partial,
  error,
}

/// Sync result
class SyncResult {
  final bool success;
  final int syncedCount;
  final int failedCount;
  final List<String> errors;

  SyncResult({
    required this.success,
    required this.syncedCount,
    required this.failedCount,
    this.errors = const [],
  });

  factory SyncResult.success({required int synced, int failed = 0}) => SyncResult(
    success: failed == 0,
    syncedCount: synced,
    failedCount: failed,
  );

  factory SyncResult.alreadySyncing() => SyncResult(
    success: false,
    syncedCount: 0,
    failedCount: 0,
    errors: ['Sync already in progress'],
  );

  factory SyncResult.failure(String error) => SyncResult(
    success: false,
    syncedCount: 0,
    failedCount: 1,
    errors: [error],
  );
}

/// Sync status info
class SyncStatusInfo {
  final bool isSyncing;
  final DateTime? lastSyncTime;
  final int pendingOperations;
  final List<SyncMetadata> entityMetadata;

  SyncStatusInfo({
    required this.isSyncing,
    this.lastSyncTime,
    required this.pendingOperations,
    required this.entityMetadata,
  });

  bool get hasPendingOperations => pendingOperations > 0;
  bool get needsSync => hasPendingOperations;

  String get lastSyncText {
    if (lastSyncTime == null) return 'Never synced';
    
    final diff = DateTime.now().difference(lastSyncTime!);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
