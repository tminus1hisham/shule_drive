import 'dart:developer' as developer;

import '../api/services/student_service.dart';
import '../api/api_exceptions.dart';

/// Service for managing student pickup/dropoff location coordinates.
/// 
/// This service handles:
/// - Checking if a student has valid location coordinates
/// - Saving/updating student location via API
/// - Filtering students who need location setup
class StudentLocationService {
  static final StudentLocationService _instance = StudentLocationService._internal();
  
  factory StudentLocationService() => _instance;
  
  StudentLocationService._internal();

  final StudentService _studentService = StudentService();

  /// Checks if a student has valid location coordinates.
  /// 
  /// Returns `true` if both latitude and longitude are not 0.
  /// 
  /// Example:
  /// ```dart
  /// final hasLocation = StudentLocationService().hasValidLocation(student);
  /// ```
  bool hasValidLocation(Map<String, dynamic> student) {
    final latitude = student['latitude'];
    final longitude = student['longitude'];
    
    return latitude != 0 && longitude != 0 &&
           latitude != null && longitude != null;
  }

  /// Saves or updates a student's location coordinates via API.
  /// 
  /// Parameters:
  /// - [studentId]: The unique identifier of the student
  /// - [latitude]: The latitude coordinate
  /// - [longitude]: The longitude coordinate
  /// 
  /// Returns a [LocationResult] indicating success or failure.
  /// 
  /// Example:
  /// ```dart
  /// final result = await StudentLocationService().saveStudentLocation(
  ///   520,
  ///   -1.2921,
  ///   36.8219,
  /// );
  /// if (result.success) {
  ///   // Location saved successfully
  /// }
  /// ```
  Future<LocationResult> saveStudentLocation(
    int studentId,
    double latitude,
    double longitude,
  ) async {
    try {
      // Validate coordinates
      if (!_isValidCoordinate(latitude, longitude)) {
        return LocationResult.failure('Invalid coordinates provided');
      }

      developer.log(
        'Saving location for student $studentId: ($latitude, $longitude)',
        name: 'StudentLocationService',
      );

      await _studentService.updateStudent(
        studentId: studentId.toString(),
        latitude: latitude,
        longitude: longitude,
      );

      developer.log(
        'Location saved successfully for student $studentId',
        name: 'StudentLocationService',
      );
      return LocationResult.success();
    } on ApiException catch (e) {
      developer.log(
        'API error while saving student location',
        name: 'StudentLocationService',
        error: e,
      );
      return LocationResult.failure(e.message);
    } catch (e, stackTrace) {
      developer.log(
        'Exception while saving student location',
        name: 'StudentLocationService',
        error: e,
        stackTrace: stackTrace,
      );
      return LocationResult.failure('Network error: ${e.toString()}');
    }
  }

  /// Filters a list of students to return only those without valid locations.
  /// 
  /// Students with latitude=0 or longitude=0 (or null) are considered
  /// to need location setup.
  /// 
  /// Example:
  /// ```dart
  /// final studentsNeedingLocation = StudentLocationService()
  ///   .filterStudentsWithoutLocation(allStudents);
  /// ```
  List<Map<String, dynamic>> filterStudentsWithoutLocation(
    List<dynamic> students,
  ) {
    return students
        .whereType<Map<String, dynamic>>()
        .where((student) => !hasValidLocation(student))
        .toList();
  }

  /// Validates that coordinates are within valid ranges.
  bool _isValidCoordinate(double latitude, double longitude) {
    return latitude >= -90 && 
           latitude <= 90 && 
           longitude >= -180 && 
           longitude <= 180;
  }

}

/// Result class for location save operations.
class LocationResult {
  final bool success;
  final String? errorMessage;

  const LocationResult._({required this.success, this.errorMessage});

  factory LocationResult.success() => const LocationResult._(success: true);

  factory LocationResult.failure(String message) => 
      LocationResult._(success: false, errorMessage: message);

  bool get hasError => errorMessage != null;

  @override
  String toString() => 
      success ? 'LocationResult.success()' : 'LocationResult.failure($errorMessage)';
}
