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

  /// Update the active history entry for [trip] with fresh trip data, e.g.
  /// after student pickup statuses change mid-trip. Without this, restoring
  /// the active trip from history resurrects the statuses saved at trip
  /// start. Scans all drivers' histories since callers don't always know the
  /// driver ID; completed entries are left untouched.
  Future<void> updateTripInHistory(Trip trip) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tripKeys = prefs
          .getKeys()
          .where((key) => key.startsWith(_tripsKey))
          .toList();

      for (final key in tripKeys) {
        final tripsString = prefs.getString(key);
        if (tripsString == null || tripsString.isEmpty) continue;

        final tripsJson = jsonDecode(tripsString) as List;
        var updated = false;
        for (var i = 0; i < tripsJson.length; i++) {
          try {
            final entry = TripHistory.fromJson(tripsJson[i]);
            if (entry.trip.id != trip.id || entry.trip.isCompleted) continue;
            tripsJson[i] = TripHistory(
              trip: trip,
              driverId: entry.driverId,
              driverName: entry.driverName,
              attendantName: entry.attendantName,
              loggedAt: entry.loggedAt,
            ).toJson();
            updated = true;
          } catch (_) {
            // Skip unparseable entries, same as getTripHistory
          }
        }

        if (updated) {
          await prefs.setString(key, jsonEncode(tripsJson));
          if (kDebugMode) {
            print('💾 Updated active trip in history: ${trip.id}');
          }
          return;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to update trip in history: $e');
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
  /// Always recomputed from trip history so picked counts stay accurate
  /// even when trips are updated after the initial save.
  Future<DriverStats> getDriverStats(String driverId) async {
    try {
      final history = await getTripHistory(driverId);
      if (history.isNotEmpty) {
        int totalStudents = 0;
        int totalPicked = 0;
        int totalAbsent = 0;
        double totalDistance = 0;
        DateTime? lastTripDate;

        for (final entry in history) {
          totalStudents += entry.trip.students.length;
          totalPicked += entry.trip.pickedCount;
          totalAbsent += entry.trip.absentCount;
          totalDistance += entry.trip.distance ?? 0;
          if (lastTripDate == null ||
              entry.trip.startTime.isAfter(lastTripDate)) {
            lastTripDate = entry.trip.startTime;
          }
        }

        return DriverStats(
          totalTrips: history.length,
          totalStudents: totalStudents,
          totalPicked: totalPicked,
          totalAbsent: totalAbsent,
          totalDistance: totalDistance,
          lastTripDate: lastTripDate,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to load driver stats: $e');
      }
    }

    return DriverStats.empty();
  }

  /// Clear trip history for a driver
  Future<void> clearTripHistory(String driverId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('${_tripsKey}_$driverId');

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
      final tripKeys = allKeys
          .where((key) => key.startsWith(_tripsKey))
          .toList();

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
              final hasGuardianStudent = tripHistory.trip.students.any((
                student,
              ) {
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

  double get completionRate =>
      totalStudents > 0 ? (totalPicked / totalStudents) * 100 : 0;
}
