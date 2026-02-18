import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/services/trip_service.dart';

/// Trip History Service - Stores completed trips locally for drivers
/// This allows drivers to see their trip history even offline
class TripHistoryService {
  static final TripHistoryService _instance = TripHistoryService._internal();
  factory TripHistoryService() => _instance;
  TripHistoryService._internal();

  static const String _tripsKey = 'driver_trip_history';
  static const String _statsKey = 'driver_trip_stats';

  /// Save a completed trip to local history
  Future<void> saveTripToHistory({
    required Trip trip,
    required String driverId,
    required String driverName,
    String? attendantName,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get existing trips
      final existingTrips = await getTripHistory(driverId);
      
      // Create history entry
      final historyEntry = TripHistory(
        trip: trip,
        driverId: driverId,
        driverName: driverName,
        attendantName: attendantName,
        loggedAt: DateTime.now(),
      );
      
      // Add to beginning of list
      existingTrips.insert(0, historyEntry);
      
      // Keep only last 100 trips to prevent storage bloat
      if (existingTrips.length > 100) {
        existingTrips.removeRange(100, existingTrips.length);
      }
      
      // Convert to JSON
      final tripsJson = existingTrips.map((t) => t.toJson()).toList();
      final jsonString = jsonEncode(tripsJson);
      
      if (kDebugMode) {
        print('💾 Saving trip to history:');
        print('   Trip ID: ${trip.id}');
        print('   Students count: ${trip.students.length}');
        print('   JSON size: ${jsonString.length} bytes');
        // Verify first student is properly serialized
        if (trip.students.isNotEmpty) {
          final firstStudentJson = trip.students.first.toJson();
          print('   First student JSON: $firstStudentJson');
        }
      }
      
      // Save to storage
      await prefs.setString('${_tripsKey}_$driverId', jsonString);
      
      // Update stats
      await _updateStats(prefs, driverId, trip);
      
      if (kDebugMode) {
        print('✅ Trip saved to history: ${trip.id}');
        print('   ├─ Driver: $driverName');
        print('   ├─ Route: ${trip.routeName}');
        print('   ├─ Students: ${trip.students.length}');
        print('   └─ Total trips stored: ${existingTrips.length}');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ Failed to save trip history: $e');
        print(stackTrace);
      }
    }
  }

  /// Get trip history for a driver
  Future<List<TripHistory>> getTripHistory(String driverId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tripsString = prefs.getString('${_tripsKey}_$driverId');
      
      if (tripsString == null || tripsString.isEmpty) {
        return [];
      }
      
      final tripsJson = jsonDecode(tripsString) as List;
      
      if (kDebugMode) {
        print('📜 Loading trip history for driver: $driverId');
        print('   Trips count: ${tripsJson.length}');
      }
      
      final history = <TripHistory>[];
      for (var i = 0; i < tripsJson.length; i++) {
        try {
          final tripHistory = TripHistory.fromJson(tripsJson[i]);
          history.add(tripHistory);
        } catch (e) {
          if (kDebugMode) {
            print('❌ Failed to parse trip history entry $i: $e');
          }
        }
      }
      
      return history;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ Failed to load trip history: $e');
        print(stackTrace);
      }
      return [];
    }
  }

  /// Get driver statistics
  Future<DriverStats> getDriverStats(String driverId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final statsString = prefs.getString('${_statsKey}_$driverId');
      
      if (statsString != null) {
        return DriverStats.fromJson(jsonDecode(statsString));
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to load driver stats: $e');
      }
    }
    
    return DriverStats.empty();
  }

  /// Update driver statistics
  Future<void> _updateStats(SharedPreferences prefs, String driverId, Trip trip) async {
    try {
      final stats = await getDriverStats(driverId);
      
      final updatedStats = DriverStats(
        totalTrips: stats.totalTrips + 1,
        totalStudents: stats.totalStudents + trip.students.length,
        totalPicked: stats.totalPicked + trip.pickedCount,
        totalAbsent: stats.totalAbsent + trip.absentCount,
        totalDistance: stats.totalDistance + (trip.distance ?? 0),
        lastTripDate: DateTime.now(),
      );
      
      await prefs.setString('${_statsKey}_$driverId', jsonEncode(updatedStats.toJson()));
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to update stats: $e');
      }
    }
  }

  /// Clear trip history for a driver
  Future<void> clearTripHistory(String driverId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('${_tripsKey}_$driverId');
      await prefs.remove('${_statsKey}_$driverId');
      
      if (kDebugMode) {
        print('🗑️ Trip history cleared for driver: $driverId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to clear trip history: $e');
      }
    }
  }

  /// Search trip history
  Future<List<TripHistory>> searchTrips(String driverId, String query) async {
    final allTrips = await getTripHistory(driverId);
    final lowerQuery = query.toLowerCase();
    
    return allTrips.where((t) {
      return t.trip.routeName.toLowerCase().contains(lowerQuery) ||
          t.trip.vehicleNumber?.toLowerCase().contains(lowerQuery) == true ||
          t.trip.students.any((s) => s.name.toLowerCase().contains(lowerQuery));
    }).toList();
  }

  /// Get trips for a specific date range
  Future<List<TripHistory>> getTripsInRange(
    String driverId,
    DateTime start,
    DateTime end,
  ) async {
    final allTrips = await getTripHistory(driverId);
    
    return allTrips.where((t) {
      final tripDate = t.trip.startTime;
      return tripDate.isAfter(start) && tripDate.isBefore(end);
    }).toList();
  }

  /// Get all trips for a guardian (across all drivers)
  /// This searches through all stored trip history for trips involving the guardian's students
  Future<List<TripHistory>> getAllTripsForGuardian(String guardianPhone) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get all keys that match the trip history pattern
      final allKeys = prefs.getKeys();
      final tripKeys = allKeys.where((key) => key.startsWith(_tripsKey)).toList();
      
      final List<TripHistory> allTrips = [];
      
      for (final key in tripKeys) {
        try {
          final tripsString = prefs.getString(key);
          if (tripsString == null || tripsString.isEmpty) continue;
          
          final tripsJson = jsonDecode(tripsString) as List;
          
          for (var i = 0; i < tripsJson.length; i++) {
            try {
              final tripHistory = TripHistory.fromJson(tripsJson[i]);
              // Check if any student in this trip belongs to the guardian
              final hasGuardianStudent = tripHistory.trip.students.any((student) {
                return student.parentPhone == guardianPhone ||
                    student.parentPhone?.replaceAll(RegExp(r'[^0-9]'), '') ==
                        guardianPhone.replaceAll(RegExp(r'[^0-9]'), '');
              });
              
              if (hasGuardianStudent) {
                allTrips.add(tripHistory);
              }
            } catch (e) {
              if (kDebugMode) {
                print('❌ Failed to parse trip history entry $i: $e');
              }
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('❌ Failed to load trips from key $key: $e');
          }
        }
      }
      
      // Sort by date, newest first
      allTrips.sort((a, b) => b.trip.startTime.compareTo(a.trip.startTime));
      
      if (kDebugMode) {
        print('📜 Found ${allTrips.length} trips for guardian: $guardianPhone');
      }
      
      return allTrips;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ Failed to load guardian trip history: $e');
        print(stackTrace);
      }
      return [];
    }
  }
}

/// Trip History Entry
class TripHistory {
  final Trip trip;
  final String driverId;
  final String driverName;
  final String? attendantName;
  final DateTime loggedAt;

  TripHistory({
    required this.trip,
    required this.driverId,
    required this.driverName,
    this.attendantName,
    required this.loggedAt,
  });

  factory TripHistory.fromJson(Map<String, dynamic> json) {
    return TripHistory(
      trip: Trip.fromJson(json['trip']),
      driverId: json['driverId'] ?? '',
      driverName: json['driverName'] ?? '',
      attendantName: json['attendantName'],
      loggedAt: DateTime.parse(json['loggedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'trip': trip.toJson(),
      'driverId': driverId,
      'driverName': driverName,
      'attendantName': attendantName,
      'loggedAt': loggedAt.toIso8601String(),
    };
  }
}

/// Driver Statistics
class DriverStats {
  final int totalTrips;
  final int totalStudents;
  final int totalPicked;
  final int totalAbsent;
  final double totalDistance;
  final DateTime? lastTripDate;

  DriverStats({
    required this.totalTrips,
    required this.totalStudents,
    required this.totalPicked,
    required this.totalAbsent,
    required this.totalDistance,
    this.lastTripDate,
  });

  factory DriverStats.empty() {
    return DriverStats(
      totalTrips: 0,
      totalStudents: 0,
      totalPicked: 0,
      totalAbsent: 0,
      totalDistance: 0,
      lastTripDate: null,
    );
  }

  factory DriverStats.fromJson(Map<String, dynamic> json) {
    return DriverStats(
      totalTrips: json['totalTrips'] ?? 0,
      totalStudents: json['totalStudents'] ?? 0,
      totalPicked: json['totalPicked'] ?? 0,
      totalAbsent: json['totalAbsent'] ?? 0,
      totalDistance: (json['totalDistance'] as num?)?.toDouble() ?? 0,
      lastTripDate: json['lastTripDate'] != null
          ? DateTime.parse(json['lastTripDate'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalTrips': totalTrips,
      'totalStudents': totalStudents,
      'totalPicked': totalPicked,
      'totalAbsent': totalAbsent,
      'totalDistance': totalDistance,
      'lastTripDate': lastTripDate?.toIso8601String(),
    };
  }

  double get completionRate => totalStudents > 0
      ? (totalPicked / totalStudents) * 100
      : 0;
}
