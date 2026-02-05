import 'package:flutter/foundation.dart';
import '../api_client.dart';
import '../api_exceptions.dart';
import '../endpoints.dart';
import '../../utils/buffer_manager.dart';
import '../../services/token_storage.dart';

/// Student Service - Handles student/children-related API calls with fallback buffers
class StudentService {
  final ApiClient _apiClient = ApiClient();
  final BufferManager _buffer = BufferManager();
  final TokenStorage _tokenStorage = TokenStorage();

  /// Get all students with buffer fallback
  /// GET /api/students
  Future<List<Student>> getAllStudents({int page = 1, int limit = 20}) async {
    return _buffer.withBuffer<List<Student>>(
      apiCall: () async {
        final response = await _apiClient.get(
          Endpoints.students,
          queryParams: {'page': page.toString(), 'limit': limit.toString()},
        );

        // Handle both wrapped ({"data": [...]}) and unwrapped ([...]) responses
        List<dynamic> studentsData;
        if (response is List) {
          studentsData = response;
        } else if (response is Map && response['data'] != null) {
          studentsData = response['data'] as List;
        } else {
          studentsData = [];
        }

        final students = studentsData
            .map((student) => Student.fromJson(student))
            .toList();
        return students;
      },
      bufferKey: BufferKeys.students(),
      fallbackData: <Student>[],
      cacheDuration: const Duration(minutes: 20),
    );
  }

  /// Get student by ID with buffer fallback
  /// GET /api/students/get/{id}
  Future<Student?> getStudentById(String studentId) async {
    return _buffer.withOptionalBuffer<Student>(
      apiCall: () async {
        final response = await _apiClient.get(
          Endpoints.studentDetails(studentId),
        );

        return Student.fromJson(response['data'] ?? response);
      },
      bufferKey: BufferKeys.studentDetails(studentId),
      cacheDuration: const Duration(minutes: 15),
    );
  }

  /// Create a new student (through guardian)
  /// POST /api/guardians/student/create
  /// API expects: fullname, schoolname, classname, route, pickupLocation, profileImage
  Future<Student> createStudent({
    required String fullname,
    String? schoolname,
    String? classname,
    String? route,
    String? pickupLocation,
    String? photo,
    String? guardianPhoneNumber,
  }) async {
    try {
      final response = await _apiClient.post(
        Endpoints.createGuardianStudent,
        body: {
          'fullname': fullname,
          if (schoolname != null && schoolname.isNotEmpty)
            'schoolname': schoolname,
          if (classname != null && classname.isNotEmpty) 'classname': classname,
          if (route != null && route.isNotEmpty) 'route': route,
          if (pickupLocation != null && pickupLocation.isNotEmpty)
            'pickupLocation': pickupLocation,
          if (photo != null && photo.isNotEmpty) 'profileImage': photo,
          if (guardianPhoneNumber != null && guardianPhoneNumber.isNotEmpty)
            'guardianPhoneNumber': guardianPhoneNumber,
        },
      );

      // Handle both wrapped ({"data": {...}}) and unwrapped ({...}) responses
      final studentData = response['data'] ?? response;
      final student = Student.fromJson(studentData);

      // Clear students cache to force refresh
      await _buffer.clearCategory('students');

      return student;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }

  /// Update student
  /// PUT /api/students/update/{id}
  Future<Student> updateStudent({
    required String studentId,
    String? name,
    String? className,
    String? schoolId,
    String? photo,
    String? pickupLocation,
    String? dropoffLocation,
    String? emergencyContact,
    String? emergencyPhone,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (className != null) body['class_name'] = className;
      if (schoolId != null) body['school_id'] = schoolId;
      if (photo != null) body['photo'] = photo;
      if (pickupLocation != null) body['pickup_location'] = pickupLocation;
      if (dropoffLocation != null) body['dropoff_location'] = dropoffLocation;
      if (emergencyContact != null)
        body['emergency_contact'] = emergencyContact;
      if (emergencyPhone != null) body['emergency_phone'] = emergencyPhone;

      final response = await _apiClient.put(
        Endpoints.updateStudent(studentId),
        body: body,
      );

      final student = Student.fromJson(response['data']);

      // Update buffers
      await _buffer.saveBuffer(
        key: BufferKeys.studentDetails(studentId),
        data: student,
        expiration: const Duration(minutes: 15),
      );
      await _buffer.clearBuffer(BufferKeys.students());

      return student;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }

  /// Delete student
  /// DELETE /api/students/delete/{id}
  Future<void> deleteStudent(String studentId) async {
    try {
      await _apiClient.delete(Endpoints.deleteStudent(studentId));

      // Clear related buffers
      await _buffer.clearBuffer(BufferKeys.studentDetails(studentId));
      await _buffer.clearCategory('students');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }

  /// Get guardian's students with buffer fallback
  /// GET /api/guardians/get/students
  Future<List<Student>> getGuardianStudents() async {
    // Get guardian ID for buffer key
    final guardianId = await _tokenStorage.getUserId();

    return _buffer.withBuffer<List<Student>>(
      apiCall: () async {
        final response = await _apiClient.get(Endpoints.getGuardianStudents);

        // Handle both wrapped ({"data": [...]}) and unwrapped ([...]) responses
        List<dynamic> studentsData;
        if (response is List) {
          studentsData = response;
        } else if (response is Map && response['data'] != null) {
          studentsData = response['data'] as List;
        } else {
          studentsData = [];
        }

        final students = studentsData
            .map((student) => Student.fromJson(student))
            .toList();
        return students;
      },
      bufferKey: BufferKeys.students(guardianId: guardianId),
      fallbackData: <Student>[],
      cacheDuration: const Duration(minutes: 20),
    );
  }

  /// Get students by phone number with buffer fallback
  /// GET /api/guardians/get/students/by/phone
  Future<List<Student>> getStudentsByPhone(String phoneNumber) async {
    return _buffer.withBuffer<List<Student>>(
      apiCall: () async {
        final response = await _apiClient.get(
          Endpoints.getGuardianStudentsByPhone,
          queryParams: {'phone': phoneNumber},
        );

        final students = (response['data'] as List? ?? [])
            .map((student) => Student.fromJson(student))
            .toList();

        return students;
      },
      bufferKey: '${BufferKeys.students()}_phone_$phoneNumber',
      fallbackData: <Student>[],
      cacheDuration: const Duration(minutes: 15),
    );
  }

  /// Update student image
  /// POST /api/guardians/update/child/image
  Future<String> updateStudentImage({
    required String studentId,
    required String imagePath,
  }) async {
    try {
      final response = await _apiClient.post(
        Endpoints.updateGuardianChildImage,
        body: {'student_id': studentId, 'image_path': imagePath},
      );

      final imageUrl = response['data']['image_url']?.toString() ?? '';

      // Clear student detail cache to force refresh
      await _buffer.clearBuffer(BufferKeys.studentDetails(studentId));
      await _buffer.clearCategory('students');

      return imageUrl;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }

  /// Get student attendance with buffer fallback
  /// GET /api/students/{id}/attendance
  Future<List<AttendanceRecord>> getStudentAttendance(String studentId) async {
    return _buffer.withBuffer<List<AttendanceRecord>>(
      apiCall: () async {
        final response = await _apiClient.get(
          Endpoints.studentAttendance(studentId),
        );

        final records = (response['data'] as List? ?? [])
            .map((r) => AttendanceRecord.fromJson(r))
            .toList();

        return records;
      },
      bufferKey: 'students/attendance_$studentId',
      fallbackData: <AttendanceRecord>[],
      cacheDuration: const Duration(minutes: 30),
    );
  }

  /// Refresh guardian students cache in background
  Future<void> refreshGuardianStudentsCache() async {
    final guardianId = await _tokenStorage.getUserId();
    await _buffer.refreshBuffer<List<Student>>(
      apiCall: () => getGuardianStudents(),
      bufferKey: BufferKeys.students(guardianId: guardianId),
      cacheDuration: const Duration(minutes: 20),
    );
  }

  /// Clear all student-related buffers
  Future<void> clearStudentBuffers() async {
    await _buffer.clearCategory('students');
  }
}

/// Student Model
class Student {
  final String id;
  final String name;
  final String? photo;
  final String className;
  final String? schoolId;
  final String? schoolName;
  final String? guardianId;
  final String? guardianName;
  final String? guardianPhone;
  final String? pickupLocation;
  final String? dropoffLocation;
  final String? emergencyContact;
  final String? emergencyPhone;
  final bool isActive;
  final DateTime createdAt;
  // Additional fields from guardian API
  final String? route;
  final String? studentRegNumber;
  final String? transportOrg;

  Student({
    required this.id,
    required this.name,
    this.photo,
    required this.className,
    this.schoolId,
    this.schoolName,
    this.guardianId,
    this.guardianName,
    this.guardianPhone,
    this.pickupLocation,
    this.dropoffLocation,
    this.emergencyContact,
    this.emergencyPhone,
    this.isActive = true,
    required this.createdAt,
    this.route,
    this.studentRegNumber,
    this.transportOrg,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    // Debug logging to see raw API response
    if (kDebugMode) {
      print('👨‍🎓 Student raw JSON: $json');
    }

    return Student(
      id: json['id']?.toString() ?? '',
      // Support both API formats: fullname (guardian API) and name (standard)
      name: json['fullname'] ?? json['name'] ?? '',
      photo: json['profileImage'] ?? json['photo'] ?? json['image'],
      className:
          json['classname'] ??
          json['class_name'] ??
          json['class'] ??
          json['className'] ??
          '',
      schoolId: json['school_id'] ?? json['schoolId'],
      // Support both schoolname (guardian API) and school_name
      schoolName:
          json['schoolname'] ?? json['school_name'] ?? json['schoolName'],
      guardianId: json['guardian_id'] ?? json['guardianId'],
      guardianName: json['guardian_name'] ?? json['guardianName'],
      // Support guardianPhoneNumber from guardian API
      guardianPhone:
          json['guardianPhoneNumber'] ??
          json['guardian_phone'] ??
          json['guardianPhone'],
      pickupLocation: json['pickup_location'] ?? json['pickupLocation'],
      dropoffLocation: json['dropoff_location'] ?? json['dropoffLocation'],
      emergencyContact: json['emergency_contact'] ?? json['emergencyContact'],
      emergencyPhone: json['emergency_phone'] ?? json['emergencyPhone'],
      // Additional fields from guardian API
      route: json['route'],
      studentRegNumber: json['studentRegNumber'],
      transportOrg: json['transportOrg'],
      isActive:
          json['isStudentActive'] ??
          json['is_active'] ??
          json['isActive'] ??
          true,
      createdAt:
          _parseDateTime(json['createdAt'] ?? json['created_at']) ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'photo': photo,
      'class_name': className,
      'school_id': schoolId,
      'school_name': schoolName,
      'guardian_id': guardianId,
      'guardian_name': guardianName,
      'guardian_phone': guardianPhone,
      'pickup_location': pickupLocation,
      'dropoff_location': dropoffLocation,
      'emergency_contact': emergencyContact,
      'emergency_phone': emergencyPhone,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'route': route,
      'studentRegNumber': studentRegNumber,
      'transportOrg': transportOrg,
    };
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    try {
      return DateTime.parse(value.toString());
    } catch (e) {
      debugPrint('Failed to parse date: $value');
      return null;
    }
  }
}

/// Attendance Record Model
class AttendanceRecord {
  final String id;
  final String studentId;
  final String tripId;
  final String status; // 'present', 'absent', 'picked', 'dropped'
  final DateTime date;
  final String? notes;

  AttendanceRecord({
    required this.id,
    required this.studentId,
    required this.tripId,
    required this.status,
    required this.date,
    this.notes,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id']?.toString() ?? '',
      studentId:
          json['student_id']?.toString() ?? json['studentId']?.toString() ?? '',
      tripId: json['trip_id']?.toString() ?? json['tripId']?.toString() ?? '',
      status: json['status'] ?? 'absent',
      date: Student._parseDateTime(json['date']) ?? DateTime.now(),
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'trip_id': tripId,
      'status': status,
      'date': date.toIso8601String(),
      'notes': notes,
    };
  }
}
