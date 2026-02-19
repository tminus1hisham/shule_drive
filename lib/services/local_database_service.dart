import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../api/services/trip_service.dart' as api;
import '../api/services/student_service.dart' as api;

/// Local Database Service - SQLite storage for offline support
/// Stores trips, students, routes, and pending operations
class LocalDatabaseService {
  static final LocalDatabaseService _instance = LocalDatabaseService._internal();
  factory LocalDatabaseService() => _instance;
  LocalDatabaseService._internal();

  static Database? _database;
  static const String _databaseName = 'shule_drive.db';
  static const int _databaseVersion = 2;

  // Table names
  static const String _tripsTable = 'trips';
  static const String _studentsTable = 'students';
  static const String _routesTable = 'routes';
  static const String _pendingOperationsTable = 'pending_operations';
  static const String _geofenceAlertsTable = 'geofence_alerts';
  static const String _syncMetadataTable = 'sync_metadata';
  static const String _chatMessagesTable = 'chat_messages';

  /// Get database instance
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  /// Initialize database
  Future<Database> _initDatabase() async {
    final String path = join(await getDatabasesPath(), _databaseName);
    
    if (kDebugMode) {
      print('📦 Initializing local database at: $path');
    }

    return openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Create tables
  Future<void> _onCreate(Database db, int version) async {
    if (kDebugMode) {
      print('📦 Creating database tables...');
    }

    // Trips table
    await db.execute('''
      CREATE TABLE $_tripsTable (
        id TEXT PRIMARY KEY,
        route_name TEXT NOT NULL,
        route_id TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT,
        status TEXT NOT NULL,
        vehicle_id TEXT NOT NULL,
        vehicle_number TEXT,
        distance REAL,
        fare REAL,
        notes TEXT,
        students TEXT,
        stops TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0
      )
    ''');

    // Students table
    await db.execute('''
      CREATE TABLE $_studentsTable (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        photo TEXT,
        class_name TEXT NOT NULL,
        school_id TEXT,
        school_name TEXT,
        guardian_id TEXT,
        guardian_name TEXT,
        guardian_phone TEXT,
        pickup_location TEXT,
        dropoff_location TEXT,
        emergency_contact TEXT,
        emergency_phone TEXT,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0
      )
    ''');

    // Routes table
    await db.execute('''
      CREATE TABLE $_routesTable (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        start_location TEXT NOT NULL,
        end_location TEXT NOT NULL,
        distance REAL,
        estimated_duration INTEGER,
        stops TEXT,
        schedule TEXT,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0
      )
    ''');

    // Pending operations table (for offline queue)
    await db.execute('''
      CREATE TABLE $_pendingOperationsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        operation_type TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id TEXT,
        payload TEXT NOT NULL,
        created_at TEXT NOT NULL,
        retry_count INTEGER DEFAULT 0,
        last_error TEXT,
        priority INTEGER DEFAULT 5
      )
    ''');

    // Geofence alerts table
    await db.execute('''
      CREATE TABLE $_geofenceAlertsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        trip_id TEXT NOT NULL,
        student_id TEXT,
        alert_type TEXT NOT NULL,
        distance_meters REAL,
        eta_minutes INTEGER,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        triggered_at TEXT NOT NULL,
        sent_notification INTEGER DEFAULT 0,
        FOREIGN KEY (trip_id) REFERENCES $_tripsTable (id)
      )
    ''');

    // Sync metadata table
    await db.execute('''
      CREATE TABLE $_syncMetadataTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT UNIQUE NOT NULL,
        last_sync_at TEXT,
        sync_status TEXT,
        pending_changes INTEGER DEFAULT 0
      )
    ''');

    // Chat messages table (for offline support)
    await db.execute('''
      CREATE TABLE $_chatMessagesTable (
        id TEXT PRIMARY KEY,
        sender_id TEXT NOT NULL,
        recipient_id TEXT NOT NULL,
        content TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        status TEXT NOT NULL,
        chat_topic TEXT NOT NULL,
        reply_to_message_id TEXT,
        created_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0
      )
    ''');

    // Create indexes
    await db.execute('CREATE INDEX idx_trips_status ON $_tripsTable(status)');
    await db.execute('CREATE INDEX idx_trips_route_id ON $_tripsTable(route_id)');
    await db.execute('CREATE INDEX idx_students_guardian_id ON $_studentsTable(guardian_id)');
    await db.execute('CREATE INDEX idx_pending_ops_type ON $_pendingOperationsTable(operation_type)');
    await db.execute('CREATE INDEX idx_geofence_trip ON $_geofenceAlertsTable(trip_id)');
    await db.execute('CREATE INDEX idx_chat_messages_topic ON $_chatMessagesTable(chat_topic)');
    await db.execute('CREATE INDEX idx_chat_messages_timestamp ON $_chatMessagesTable(timestamp)');

    if (kDebugMode) {
      print('✅ Database tables created successfully');
    }
  }

  /// Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (kDebugMode) {
      print('📦 Upgrading database from v$oldVersion to v$newVersion');
    }
    
    // Migration from v1 to v2: Add chat_messages table
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $_chatMessagesTable (
          id TEXT PRIMARY KEY,
          sender_id TEXT NOT NULL,
          recipient_id TEXT NOT NULL,
          content TEXT NOT NULL,
          timestamp TEXT NOT NULL,
          status TEXT NOT NULL,
          chat_topic TEXT NOT NULL,
          reply_to_message_id TEXT,
          created_at TEXT NOT NULL,
          synced INTEGER DEFAULT 0
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_chat_messages_topic ON $_chatMessagesTable(chat_topic)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_chat_messages_timestamp ON $_chatMessagesTable(timestamp)');
      
      if (kDebugMode) {
        print('✅ Chat messages table created in migration');
      }
    }
  }

  // ==================== TRIP OPERATIONS ====================

  /// Save or update trip
  Future<void> saveTrip(api.Trip trip) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    
    await db.insert(
      _tripsTable,
      {
        'id': trip.id,
        'route_name': trip.routeName,
        'route_id': trip.routeId,
        'start_time': trip.startTime.toIso8601String(),
        'end_time': trip.endTime?.toIso8601String(),
        'status': trip.status,
        'vehicle_id': trip.vehicleId,
        'vehicle_number': trip.vehicleNumber,
        'distance': trip.distance,
        'fare': trip.fare,
        'notes': trip.notes,
        'students': _encodeJson(trip.students.map((s) => s.toJson()).toList()),
        'stops': _encodeJson(trip.stops.map((s) => s.toJson()).toList()),
        'created_at': trip.startTime.toIso8601String(),
        'updated_at': now,
        'synced': 1,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await _updateSyncMetadata('trips');
  }

  /// Get trip by ID
  Future<api.Trip?> getTrip(String tripId) async {
    final db = await database;
    final maps = await db.query(
      _tripsTable,
      where: 'id = ?',
      whereArgs: [tripId],
    );

    if (maps.isEmpty) return null;
    return _tripFromMap(maps.first);
  }

  /// Get all trips
  Future<List<api.Trip>> getAllTrips({String? status, int limit = 100}) async {
    final db = await database;
    
    String? whereClause;
    List<dynamic>? whereArgs;
    
    if (status != null) {
      whereClause = 'status = ?';
      whereArgs = [status];
    }

    final maps = await db.query(
      _tripsTable,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'start_time DESC',
      limit: limit,
    );

    return maps.map(_tripFromMap).toList();
  }

  /// Get active trips
  Future<List<api.Trip>> getActiveTrips() async {
    return getAllTrips(status: 'active');
  }

  /// Delete trip
  Future<void> deleteTrip(String tripId) async {
    final db = await database;
    await db.delete(
      _tripsTable,
      where: 'id = ?',
      whereArgs: [tripId],
    );
  }

  // ==================== STUDENT OPERATIONS ====================

  /// Save or update student
  Future<void> saveStudent(api.Student student) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    
    await db.insert(
      _studentsTable,
      {
        'id': student.id,
        'name': student.name,
        'photo': student.photo,
        'class_name': student.className,
        'school_id': student.schoolId,
        'school_name': student.schoolName,
        'guardian_id': student.guardianId,
        'guardian_name': student.guardianName,
        'guardian_phone': student.guardianPhone,
        'pickup_location': student.pickupLocation,
        'dropoff_location': student.dropoffLocation,
        'emergency_contact': student.emergencyContact,
        'emergency_phone': student.emergencyPhone,
        'is_active': student.isActive ? 1 : 0,
        'created_at': student.createdAt.toIso8601String(),
        'updated_at': now,
        'synced': 1,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await _updateSyncMetadata('students');
  }

  /// Save multiple students
  Future<void> saveStudents(List<api.Student> students) async {
    final db = await database;
    
    await db.transaction((txn) async {
      for (final student in students) {
        await _saveStudentInTransaction(txn, student);
      }
    });

    await _updateSyncMetadata('students');
  }

  Future<void> _saveStudentInTransaction(Transaction txn, api.Student student) async {
    final now = DateTime.now().toIso8601String();
    
    await txn.insert(
      _studentsTable,
      {
        'id': student.id,
        'name': student.name,
        'photo': student.photo,
        'class_name': student.className,
        'school_id': student.schoolId,
        'school_name': student.schoolName,
        'guardian_id': student.guardianId,
        'guardian_name': student.guardianName,
        'guardian_phone': student.guardianPhone,
        'pickup_location': student.pickupLocation,
        'dropoff_location': student.dropoffLocation,
        'emergency_contact': student.emergencyContact,
        'emergency_phone': student.emergencyPhone,
        'is_active': student.isActive ? 1 : 0,
        'created_at': student.createdAt.toIso8601String(),
        'updated_at': now,
        'synced': 1,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get student by ID
  Future<api.Student?> getStudent(String studentId) async {
    final db = await database;
    final maps = await db.query(
      _studentsTable,
      where: 'id = ?',
      whereArgs: [studentId],
    );

    if (maps.isEmpty) return null;
    return _studentFromMap(maps.first);
  }

  /// Get students by guardian ID
  Future<List<api.Student>> getStudentsByGuardian(String guardianId) async {
    final db = await database;
    final maps = await db.query(
      _studentsTable,
      where: 'guardian_id = ? AND is_active = 1',
      whereArgs: [guardianId],
      orderBy: 'name ASC',
    );

    return maps.map(_studentFromMap).toList();
  }

  /// Get all students
  Future<List<api.Student>> getAllStudents() async {
    final db = await database;
    final maps = await db.query(
      _studentsTable,
      orderBy: 'name ASC',
    );

    return maps.map(_studentFromMap).toList();
  }

  /// Search students
  Future<List<api.Student>> searchStudents(String query) async {
    final db = await database;
    final maps = await db.query(
      _studentsTable,
      where: 'name LIKE ? OR class_name LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'name ASC',
    );

    return maps.map(_studentFromMap).toList();
  }

  // ==================== PENDING OPERATIONS ====================

  /// Queue operation for sync when online
  Future<int> queuePendingOperation({
    required String operationType, // 'create', 'update', 'delete'
    required String entityType, // 'trip', 'student', 'route'
    String? entityId,
    required Map<String, dynamic> payload,
    int priority = 5,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    final id = await db.insert(
      _pendingOperationsTable,
      {
        'operation_type': operationType,
        'entity_type': entityType,
        'entity_id': entityId,
        'payload': _encodeJson(payload),
        'created_at': now,
        'retry_count': 0,
        'priority': priority,
      },
    );

    await _incrementPendingChanges(entityType);
    
    if (kDebugMode) {
      print('📤 Queued $operationType operation for $entityType (ID: $id)');
    }

    return id;
  }

  /// Get pending operations
  Future<List<PendingOperation>> getPendingOperations({
    String? entityType,
    int limit = 50,
  }) async {
    final db = await database;
    
    String? whereClause;
    List<dynamic>? whereArgs;
    
    if (entityType != null) {
      whereClause = 'entity_type = ?';
      whereArgs = [entityType];
    }

    final maps = await db.query(
      _pendingOperationsTable,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'priority ASC, created_at ASC',
      limit: limit,
    );

    return maps.map(_pendingOperationFromMap).toList();
  }

  /// Remove pending operation
  Future<void> removePendingOperation(int operationId) async {
    final db = await database;
    await db.delete(
      _pendingOperationsTable,
      where: 'id = ?',
      whereArgs: [operationId],
    );
  }

  /// Update retry count and error
  Future<void> updateOperationRetry(
    int operationId, {
    required int retryCount,
    String? error,
  }) async {
    final db = await database;
    await db.update(
      _pendingOperationsTable,
      {
        'retry_count': retryCount,
        'last_error': error,
      },
      where: 'id = ?',
      whereArgs: [operationId],
    );
  }

  /// Clear all completed/failed operations
  Future<void> clearCompletedOperations({int maxRetries = 5}) async {
    final db = await database;
    await db.delete(
      _pendingOperationsTable,
      where: 'retry_count >= ?',
      whereArgs: [maxRetries],
    );
  }

  // ==================== GEOFENCE ALERTS ====================

  /// Save geofence alert
  Future<int> saveGeofenceAlert({
    required String tripId,
    String? studentId,
    required String alertType, // 'approaching', 'arriving', 'arrived'
    double? distanceMeters,
    int? etaMinutes,
    required double latitude,
    required double longitude,
    bool sentNotification = false,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    return await db.insert(
      _geofenceAlertsTable,
      {
        'trip_id': tripId,
        'student_id': studentId,
        'alert_type': alertType,
        'distance_meters': distanceMeters,
        'eta_minutes': etaMinutes,
        'latitude': latitude,
        'longitude': longitude,
        'triggered_at': now,
        'sent_notification': sentNotification ? 1 : 0,
      },
    );
  }

  /// Get recent geofence alerts for a trip
  Future<List<GeofenceAlert>> getGeofenceAlerts(
    String tripId, {
    String? alertType,
    int limit = 50,
  }) async {
    final db = await database;
    
    String whereClause = 'trip_id = ?';
    List<dynamic> whereArgs = [tripId];
    
    if (alertType != null) {
      whereClause += ' AND alert_type = ?';
      whereArgs.add(alertType);
    }

    final maps = await db.query(
      _geofenceAlertsTable,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'triggered_at DESC',
      limit: limit,
    );

    return maps.map(_geofenceAlertFromMap).toList();
  }

  /// Get unsent notifications
  Future<List<GeofenceAlert>> getUnsentAlerts() async {
    final db = await database;
    final maps = await db.query(
      _geofenceAlertsTable,
      where: 'sent_notification = 0',
      orderBy: 'triggered_at ASC',
    );

    return maps.map(_geofenceAlertFromMap).toList();
  }

  /// Mark alert as sent
  Future<void> markAlertSent(int alertId) async {
    final db = await database;
    await db.update(
      _geofenceAlertsTable,
      {'sent_notification': 1},
      where: 'id = ?',
      whereArgs: [alertId],
    );
  }

  /// Clear old alerts (keep last 7 days)
  Future<void> clearOldAlerts({int daysToKeep = 7}) async {
    final db = await database;
    final cutoff = DateTime.now().subtract(Duration(days: daysToKeep));
    
    await db.delete(
      _geofenceAlertsTable,
      where: 'triggered_at < ?',
      whereArgs: [cutoff.toIso8601String()],
    );
  }

  // ==================== CHAT MESSAGES ====================

  /// Save a chat message locally
  Future<void> saveChatMessage({
    required String id,
    required String senderId,
    required String recipientId,
    required String content,
    required DateTime timestamp,
    required String status,
    required String chatTopic,
    String? replyToMessageId,
    bool synced = false,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    await db.insert(
      _chatMessagesTable,
      {
        'id': id,
        'sender_id': senderId,
        'recipient_id': recipientId,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        'status': status,
        'chat_topic': chatTopic,
        'reply_to_message_id': replyToMessageId,
        'created_at': now,
        'synced': synced ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get all messages for a chat topic
  Future<List<Map<String, dynamic>>> getChatMessages(String chatTopic, {int limit = 100}) async {
    final db = await database;
    
    final messages = await db.query(
      _chatMessagesTable,
      where: 'chat_topic = ?',
      whereArgs: [chatTopic],
      orderBy: 'timestamp ASC',
      limit: limit,
    );
    
    return messages;
  }

  /// Update message status
  Future<void> updateChatMessageStatus(String messageId, String status, {bool synced = true}) async {
    final db = await database;
    
    await db.update(
      _chatMessagesTable,
      {
        'status': status,
        'synced': synced ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  /// Get unsynced messages (for retry when back online)
  Future<List<Map<String, dynamic>>> getUnsyncedChatMessages() async {
    final db = await database;
    
    final messages = await db.query(
      _chatMessagesTable,
      where: 'synced = 0',
      orderBy: 'timestamp ASC',
    );
    
    return messages;
  }

  /// Mark messages as delivered for a chat
  Future<void> markChatMessagesAsDelivered(String chatTopic, String senderId) async {
    final db = await database;
    
    await db.update(
      _chatMessagesTable,
      {'status': 'delivered'},
      where: 'chat_topic = ? AND sender_id = ? AND status = ?',
      whereArgs: [chatTopic, senderId, 'sent'],
    );
  }

  /// Clear old chat messages (keep last 30 days)
  Future<int> clearOldChatMessages({int daysToKeep = 30}) async {
    final db = await database;
    final cutoff = DateTime.now().subtract(Duration(days: daysToKeep));
    
    final deleted = await db.delete(
      _chatMessagesTable,
      where: 'timestamp < ?',
      whereArgs: [cutoff.toIso8601String()],
    );
    
    if (kDebugMode && deleted > 0) {
      print('🗑️ Cleared $deleted old chat messages');
    }
    
    return deleted;
  }

  /// Delete a specific chat message
  Future<void> deleteChatMessage(String messageId) async {
    final db = await database;
    
    await db.delete(
      _chatMessagesTable,
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  // ==================== SYNC METADATA ====================

  Future<void> _updateSyncMetadata(String entityType) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    await db.insert(
      _syncMetadataTable,
      {
        'entity_type': entityType,
        'last_sync_at': now,
        'sync_status': 'synced',
        'pending_changes': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _incrementPendingChanges(String entityType) async {
    final db = await database;
    
    await db.execute('''
      INSERT INTO $_syncMetadataTable (entity_type, pending_changes)
      VALUES (?, 1)
      ON CONFLICT(entity_type) DO UPDATE SET
        pending_changes = pending_changes + 1
    ''', [entityType]);
  }

  /// Get sync status
  Future<SyncMetadata?> getSyncMetadata(String entityType) async {
    final db = await database;
    final maps = await db.query(
      _syncMetadataTable,
      where: 'entity_type = ?',
      whereArgs: [entityType],
    );

    if (maps.isEmpty) return null;
    return _syncMetadataFromMap(maps.first);
  }

  /// Get all sync metadata
  Future<List<SyncMetadata>> getAllSyncMetadata() async {
    final db = await database;
    final maps = await db.query(_syncMetadataTable);
    return maps.map(_syncMetadataFromMap).toList();
  }

  // ==================== UTILITY METHODS ====================

  /// Clear all data (for logout)
  Future<void> clearAllData() async {
    final db = await database;
    
    await db.delete(_tripsTable);
    await db.delete(_studentsTable);
    await db.delete(_routesTable);
    await db.delete(_pendingOperationsTable);
    await db.delete(_geofenceAlertsTable);
    await db.delete(_syncMetadataTable);
    await db.delete(_chatMessagesTable);

    if (kDebugMode) {
      print('🗑️ All local data cleared');
    }
  }

  /// Close database
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  // ==================== JSON HELPERS ====================

  String _encodeJson(dynamic data) {
    if (data == null) return '';
    return data.toString();
  }

  // ==================== MODEL CONVERTERS ====================

  api.Trip _tripFromMap(Map<String, dynamic> map) {
    return api.Trip(
      id: map['id'] as String,
      routeName: map['route_name'] as String,
      routeId: map['route_id'] as String,
      startTime: DateTime.parse(map['start_time'] as String),
      endTime: map['end_time'] != null ? DateTime.parse(map['end_time'] as String) : null,
      status: map['status'] as String,
      vehicleId: map['vehicle_id'] as String,
      vehicleNumber: map['vehicle_number'] as String?,
      distance: map['distance'] as double?,
      fare: map['fare'] as double?,
      notes: map['notes'] as String?,
      students: [], // Parse from JSON if needed
      stops: [], // Parse from JSON if needed
    );
  }

  api.Student _studentFromMap(Map<String, dynamic> map) {
    return api.Student(
      id: map['id'] as String,
      name: map['name'] as String,
      photo: map['photo'] as String?,
      className: map['class_name'] as String,
      schoolId: map['school_id'] as String?,
      schoolName: map['school_name'] as String?,
      guardianId: map['guardian_id'] as String?,
      guardianName: map['guardian_name'] as String?,
      guardianPhone: map['guardian_phone'] as String?,
      pickupLocation: map['pickup_location'] as String?,
      dropoffLocation: map['dropoff_location'] as String?,
      emergencyContact: map['emergency_contact'] as String?,
      emergencyPhone: map['emergency_phone'] as String?,
      isActive: (map['is_active'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  PendingOperation _pendingOperationFromMap(Map<String, dynamic> map) {
    return PendingOperation(
      id: map['id'] as int,
      operationType: map['operation_type'] as String,
      entityType: map['entity_type'] as String,
      entityId: map['entity_id'] as String?,
      payload: map['payload'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      retryCount: map['retry_count'] as int,
      lastError: map['last_error'] as String?,
      priority: map['priority'] as int,
    );
  }

  GeofenceAlert _geofenceAlertFromMap(Map<String, dynamic> map) {
    return GeofenceAlert(
      id: map['id'] as int,
      tripId: map['trip_id'] as String,
      studentId: map['student_id'] as String?,
      alertType: map['alert_type'] as String,
      distanceMeters: map['distance_meters'] as double?,
      etaMinutes: map['eta_minutes'] as int?,
      latitude: map['latitude'] as double,
      longitude: map['longitude'] as double,
      triggeredAt: DateTime.parse(map['triggered_at'] as String),
      sentNotification: (map['sent_notification'] as int) == 1,
    );
  }

  SyncMetadata _syncMetadataFromMap(Map<String, dynamic> map) {
    return SyncMetadata(
      entityType: map['entity_type'] as String,
      lastSyncAt: map['last_sync_at'] != null 
          ? DateTime.parse(map['last_sync_at'] as String) 
          : null,
      syncStatus: map['sync_status'] as String?,
      pendingChanges: map['pending_changes'] as int? ?? 0,
    );
  }
}

/// Pending operation model
class PendingOperation {
  final int id;
  final String operationType;
  final String entityType;
  final String? entityId;
  final String payload;
  final DateTime createdAt;
  final int retryCount;
  final String? lastError;
  final int priority;

  PendingOperation({
    required this.id,
    required this.operationType,
    required this.entityType,
    this.entityId,
    required this.payload,
    required this.createdAt,
    required this.retryCount,
    this.lastError,
    required this.priority,
  });

  bool get isCreate => operationType == 'create';
  bool get isUpdate => operationType == 'update';
  bool get isDelete => operationType == 'delete';
  bool get exceededMaxRetries => retryCount >= 5;
}

/// Geofence alert model
class GeofenceAlert {
  final int id;
  final String tripId;
  final String? studentId;
  final String alertType;
  final double? distanceMeters;
  final int? etaMinutes;
  final double latitude;
  final double longitude;
  final DateTime triggeredAt;
  final bool sentNotification;

  GeofenceAlert({
    required this.id,
    required this.tripId,
    this.studentId,
    required this.alertType,
    this.distanceMeters,
    this.etaMinutes,
    required this.latitude,
    required this.longitude,
    required this.triggeredAt,
    required this.sentNotification,
  });

  String get title {
    switch (alertType) {
      case 'approaching':
        return '🚌 Bus Approaching';
      case 'arriving':
        return '🚌 Bus Arriving Soon';
      case 'arrived':
        return '🛑 Bus Has Arrived';
      default:
        return '🚌 Bus Update';
    }
  }

  String get message {
    if (etaMinutes != null) {
      return 'Bus is approximately $etaMinutes minutes away';
    }
    final dist = distanceMeters;
    if (dist != null) {
      final distance = dist < 1000 
          ? '${dist.toInt()}m' 
          : '${(dist / 1000).toStringAsFixed(1)}km';
      return 'Bus is $distance away from your stop';
    }
    return 'Bus status update available';
  }
}

/// Sync metadata model
class SyncMetadata {
  final String entityType;
  final DateTime? lastSyncAt;
  final String? syncStatus;
  final int pendingChanges;

  SyncMetadata({
    required this.entityType,
    this.lastSyncAt,
    this.syncStatus,
    required this.pendingChanges,
  });

  bool get hasPendingChanges => pendingChanges > 0;
  bool get isSynced => syncStatus == 'synced' && pendingChanges == 0;
}
