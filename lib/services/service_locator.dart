import 'local_database_service.dart';
import 'notification_service.dart';
import 'geofence_notification_handler.dart';
import 'offline_sync_manager.dart';
import '../api/services/trip_service.dart';
import '../api/services/student_service.dart';

/// Service Locator
/// 
/// Centralized access to all services and their initialization.
/// Call initialize() at app startup and initializeWithServices() after login.
class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();

  // Services
  final LocalDatabaseService database = LocalDatabaseService();
  final NotificationService notifications = NotificationService();
  final GeofenceNotificationHandler geofence = GeofenceNotificationHandler();
  final OfflineSyncManager syncManager = OfflineSyncManager();

  // API Services (initialized after login)
  TripService? _tripService;
  StudentService? _studentService;

  TripService get tripService {
    if (_tripService == null) {
      throw StateError('TripService not initialized. Call initializeWithServices() first.');
    }
    return _tripService!;
  }

  StudentService get studentService {
    if (_studentService == null) {
      throw StateError('StudentService not initialized. Call initializeWithServices() first.');
    }
    return _studentService!;
  }

  bool _initialized = false;
  bool get isInitialized => _initialized;

  /// Initialize core services (call at app startup)
  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize database
    await database.database;

    // Initialize notifications
    await notifications.initialize();

    // Initialize sync manager
    await syncManager.initialize();

    _initialized = true;
  }

  /// Initialize API services (call after login)
  void initializeWithServices({
    TripService? tripService,
    StudentService? studentService,
  }) {
    _tripService = tripService;
    _studentService = studentService;

    // Pass services to sync manager
    syncManager.initializeServices(
      tripService: tripService,
      studentService: studentService,
    );
  }

  /// Dispose all services (call on logout)
  Future<void> dispose() async {
    await geofence.stopMonitoring();
    notifications.dispose();
    syncManager.dispose();
    await database.close();

    _tripService = null;
    _studentService = null;
    _initialized = false;
  }
}

/// Global accessor for services
ServiceLocator get services => ServiceLocator();
