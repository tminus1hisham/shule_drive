import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

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

  /// Base API URL - should be configured based on your environment
  String get _baseUrl => const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.example.com',
  );

  /// API endpoint for updating student location
  String get _updateLocationEndpoint => '/api/students/update-location';

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

      final url = Uri.parse('$_baseUrl$_updateLocationEndpoint');
      
      developer.log(
        'Saving location for student $studentId: ($latitude, $longitude)',
        name: 'StudentLocationService',
      );

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'studentId': studentId,
          'latitude': latitude,
          'longitude': longitude,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        developer.log(
          'Location saved successfully for student $studentId',
          name: 'StudentLocationService',
        );
        return LocationResult.success();
      } else {
        final errorMessage = _parseErrorMessage(response);
        developer.log(
          'Failed to save location: ${response.statusCode} - $errorMessage',
          name: 'StudentLocationService',
          error: response.body,
        );
        return LocationResult.failure(errorMessage);
      }
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

  /// Parses error message from API response.
  String _parseErrorMessage(http.Response response) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body['message'] ?? 
             body['error'] ?? 
             'Failed with status code ${response.statusCode}';
    } catch (_) {
      return 'Failed with status code ${response.statusCode}';
    }
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
