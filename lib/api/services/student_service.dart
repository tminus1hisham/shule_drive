import 'package:flutter/foundation.dart';
import '../api_client.dart';
import '../api_exceptions.dart';
import '../endpoints.dart';
import '../../utils/buffer_manager.dart';
import '../../services/token_storage.dart';
import '../../models/guardian.dart';

/// Student Service - Handles student/children-related API calls with fallback buffers
class StudentService {
  final ApiClient _apiClient = ApiClient();
  final BufferManager _buffer = BufferManager();
  final TokenStorage _tokenStorage = TokenStorage();

  /// Get all students with buffer fallback
  /// GET /api/guardians/get/students
  Future<List<Student>> getAllStudents({int page = 1, int limit = 20}) async {
    return _buffer.withBuffer<List<Student>>(
      apiCall: () async {
        // api.md's students endpoint is not paginated, so page/limit are not
        // sent (they are kept on the signature only for caller compatibility).
        final response = await _apiClient.get(Endpoints.students);

        final studentsData = ApiClient.unwrapList(response);

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
  /// api.md exposes no get-by-id student endpoint; this filters guardian students.
  Future<Student?> getStudentById(String studentId) async {
    return _buffer.withOptionalBuffer<Student>(
      apiCall: () async {
        final students = await getGuardianStudents();
        for (final student in students) {
          if (student.id == studentId) return student;
        }
        throw NotFoundException(message: 'Student not found');
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
      final resolvedGuardianPhone =
          guardianPhoneNumber ?? await _tokenStorage.getUserPhone() ?? '';
      if (resolvedGuardianPhone.isEmpty) {
        throw ApiException(message: 'Guardian phone number is required');
      }
      if (schoolname == null || schoolname.isEmpty) {
        throw ApiException(message: 'School name is required');
      }

      final response = await _apiClient.post(
        Endpoints.createGuardianStudent,
        body: {
          'fullname': fullname,
          'guardianPhoneNumber': resolvedGuardianPhone,
          'studentRegNumber': 'STD-${DateTime.now().microsecondsSinceEpoch}',
          'schoolname': schoolname,
          'classname': classname ?? '',
          'route': route ?? pickupLocation ?? '',
          'createdAt': DateTime.now().toUtc().toIso8601String(),
        },
      );

      // Handle both wrapped ({"data": {...}}) and unwrapped ({...}) responses
      final student = response is Map
          ? Student.fromJson(
              Map<String, dynamic>.from(response['data'] ?? response),
            )
          : Student(
              id: '',
              name: fullname,
              className: classname ?? '',
              schoolName: schoolname,
              guardianPhone: resolvedGuardianPhone,
              createdAt: DateTime.now(),
              route: route ?? pickupLocation,
              studentRegNumber: 'STD-${DateTime.now().microsecondsSinceEpoch}',
            );

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
  /// PUT /api/guardians/student/update
  Future<Student> updateStudent({
    required String studentId,
    String? name,
    String? className,
    String? schoolId,
    String? schoolName,
    String? photo,
    String? pickupLocation,
    String? dropoffLocation,
    String? emergencyContact,
    String? emergencyPhone,
    String? guardianPhoneNumber,
    String? studentRegNumber,
    String? transportOrg,
    bool? isActive,
    DateTime? createdAt,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final body = <String, dynamic>{};
      Student? current;
      try {
        current = await getStudentById(studentId);
      } catch (e) {
        debugPrint('StudentService.updateStudent: lookup failed: $e');
      }
      // PUT replaces the whole record. Without the current one we would reset
      // paid status and expiry (and blank unknown fields), so refuse.
      if (current == null) {
        throw ApiException(
          message: 'Student $studentId not found; refusing to overwrite it',
        );
      }
      body['id'] = int.tryParse(studentId) ?? 0;
      body['fullname'] = name ?? current.name;
      body['guardianPhoneNumber'] =
          guardianPhoneNumber ??
          current.guardianPhone ??
          await _tokenStorage.getUserPhone() ??
          '';
      body['studentRegNumber'] =
          studentRegNumber ?? current.studentRegNumber ?? '';
      body['schoolname'] = schoolName ?? schoolId ?? current.schoolName ?? '';
      body['transportOrg'] = transportOrg ?? current.transportOrg ?? '';
      body['classname'] = className ?? current.className;
      body['route'] = pickupLocation ?? current.route ?? '';
      body['latitude'] = latitude ?? current.latitude;
      body['longitude'] = longitude ?? current.longitude;
      body['profileImage'] = photo ?? current.photo ?? '';
      body['hasStudentPaid'] = current.hasStudentPaid;
      body['isStudentActive'] = isActive ?? current.isActive;
      body['isStudentDeleted'] = false;
      if (current.expiryDate != null) {
        body['expirelyDate'] = current.expiryDate;
      }
      body['createdAt'] =
          createdAt?.toUtc().toIso8601String() ??
          current.createdAt.toUtc().toIso8601String();
      body['updatedAt'] = DateTime.now().toUtc().toIso8601String();

      final response = await _apiClient.put(
        Endpoints.updateStudent,
        body: body,
      );

      final student = response is Map
          ? Student.fromJson(
              Map<String, dynamic>.from(response['data'] ?? response),
            )
          : Student(
              id: studentId,
              name: body['fullname']?.toString() ?? '',
              className: body['classname']?.toString() ?? '',
              schoolName: body['schoolname']?.toString(),
              guardianPhone: body['guardianPhoneNumber']?.toString(),
              photo: body['profileImage']?.toString(),
              isActive: body['isStudentActive'] == true,
              createdAt: current.createdAt,
              route: body['route']?.toString(),
              studentRegNumber: body['studentRegNumber']?.toString(),
              transportOrg: body['transportOrg']?.toString(),
              latitude: (body['latitude'] as num?)?.toDouble() ?? 0,
              longitude: (body['longitude'] as num?)?.toDouble() ?? 0,
              hasStudentPaid: current.hasStudentPaid,
              expiryDate: current.expiryDate,
            );

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

  /// Save a student's home destination using api.md's full Students update body.
  Future<Student> saveStudentHomeDestination({
    required String studentId,
    required String name,
    required String guardianPhoneNumber,
    required double latitude,
    required double longitude,
    String? studentRegNumber,
    String? schoolName,
    String? className,
    String? route,
    String? photo,
    String? transportOrg,
  }) {
    return updateStudent(
      studentId: studentId,
      name: name,
      guardianPhoneNumber: guardianPhoneNumber,
      studentRegNumber: studentRegNumber,
      schoolName: schoolName,
      className: className,
      pickupLocation: route,
      photo: photo,
      transportOrg: transportOrg,
      latitude: latitude,
      longitude: longitude,
      isActive: true,
    );
  }

  /// Delete student
  /// DELETE /api/guardians/student/delete/{id}
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

        final studentsData = ApiClient.unwrapList(response);

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
          queryParams: {'phoneNumber': phoneNumber},
        );

        final studentsData = ApiClient.unwrapList(response);

        final students = studentsData
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
      final student = await getStudentById(studentId);
      final fileName = imagePath.split(RegExp(r'[\\/]')).last;
      final response = await _apiClient.post(
        Endpoints.updateGuardianChildImage,
        body: {
          'guardianPhoneNumber':
              student?.guardianPhone ??
              await _tokenStorage.getUserPhone() ??
              '',
          'studentFullName': student?.name ?? studentId,
          'imageUrl': fileName,
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        },
      );

      String imageUrl = fileName;
      if (response is String && response.isNotEmpty) {
        imageUrl = response;
      } else if (response is Map) {
        final data = response['data'];
        if (data is String && data.isNotEmpty) {
          imageUrl = data;
        } else if (data is Map) {
          imageUrl =
              data['imageUrl']?.toString() ??
              data['image_url']?.toString() ??
              imageUrl;
        } else {
          imageUrl = response['imageUrl']?.toString() ?? imageUrl;
        }
      }

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
  /// No student attendance endpoint is defined in api.md.
  Future<List<AttendanceRecord>> getStudentAttendance(String studentId) async {
    return _buffer.withBuffer<List<AttendanceRecord>>(
      apiCall: () async {
        return <AttendanceRecord>[];
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

  /// Get students by school ID
  /// Filters students by the school ID to ensure school-scoped data
  Future<List<Student>> getStudentsBySchool(String schoolId) async {
    return _buffer.withBuffer<List<Student>>(
      apiCall: () async {
        // Get all students and filter by school
        final response = await _apiClient.get(Endpoints.students);

        final studentsData = ApiClient.unwrapList(response);

        final students = studentsData
            .map((student) => Student.fromJson(student))
            .where((s) => s.schoolId == schoolId)
            .toList();

        return students;
      },
      bufferKey: '${BufferKeys.students()}_school_$schoolId',
      fallbackData: <Student>[],
      cacheDuration: const Duration(minutes: 15),
    );
  }

  /// Clear all student-related buffers
  Future<void> clearStudentBuffers() async {
    await _buffer.clearCategory('students');
  }

  /// Get students from multiple phone numbers in PARALLEL
  /// Optimized for speed - uses Future.wait for concurrent requests
  /// Returns cached data immediately if available, fetches in background
  Future<List<Student>> getStudentsByPhonesParallel(
    List<String> phoneNumbers, {
    bool useCache = true,
  }) async {
    if (phoneNumbers.isEmpty) return [];

    final uniquePhones = phoneNumbers.toSet().toList();
    debugPrint(
      '🚀 Parallel fetching students for ${uniquePhones.length} phone numbers',
    );

    // Check cache first if enabled
    if (useCache) {
      final cachedStudents = <Student>[];
      final phonesToFetch = <String>[];

      for (final phone in uniquePhones) {
        final bufferKey = '${BufferKeys.students()}_phone_$phone';
        final cached = await _buffer.getBuffer<List<dynamic>>(key: bufferKey);
        if (cached != null) {
          cachedStudents.addAll(cached.map((s) => s as Student));
          debugPrint('  💾 Cache hit for $phone: ${cached.length} students');
        } else {
          phonesToFetch.add(phone);
        }
      }

      // If all cached, return immediately
      if (phonesToFetch.isEmpty) {
        debugPrint('✅ All data from cache: ${cachedStudents.length} students');
        return cachedStudents;
      }

      // Fetch missing data in parallel
      final freshStudents = await _fetchStudentsParallel(phonesToFetch);
      return [...cachedStudents, ...freshStudents];
    }

    // No cache - fetch all in parallel
    return _fetchStudentsParallel(uniquePhones);
  }

  /// Internal method to fetch students in parallel
  Future<List<Student>> _fetchStudentsParallel(
    List<String> phoneNumbers,
  ) async {
    final stopwatch = Stopwatch()..start();

    // Create all futures and run them in parallel
    final futures = phoneNumbers.map((phone) async {
      try {
        return await getStudentsByPhone(phone);
      } catch (e) {
        debugPrint('  ❌ Failed for $phone: $e');
        return <Student>[];
      }
    }).toList();

    // Wait for all to complete
    final results = await Future.wait(futures);

    // Combine results
    final allStudents = <Student>[];
    for (final studentList in results) {
      allStudents.addAll(studentList);
    }

    stopwatch.stop();
    debugPrint(
      '⚡ Parallel fetch completed: ${allStudents.length} students in ${stopwatch.elapsedMilliseconds}ms',
    );
    return allStudents;
  }

  /// Get extended guardians for the current user
  /// GET /api/guardians/get/extended/guardians
  Future<List<Guardian>> getExtendedGuardians() async {
    return _buffer.withBuffer<List<Guardian>>(
      apiCall: () async {
        final response = await _apiClient.get(Endpoints.getExtendedGuardians);

        final guardiansData = ApiClient.unwrapList(response);

        final guardians = guardiansData
            .map((guardian) => Guardian.fromJson(guardian))
            .toList();
        return guardians;
      },
      bufferKey: 'extended_guardians',
      fallbackData: <Guardian>[],
      cacheDuration: const Duration(minutes: 15),
    );
  }

  /// Get all guardians for a specific student by student ID
  /// This combines the primary guardian from student data with extended guardians
  Future<List<Guardian>> getStudentGuardians(String studentId) async {
    try {
      // First get the student details to get the primary guardian
      final student = await getStudentById(studentId);

      // Get extended guardians
      final extendedGuardians = await getExtendedGuardians();

      // Create a list to hold all guardians
      final List<Guardian> allGuardians = [];

      // Add primary guardian if available
      if (student != null &&
          (student.guardianName != null || student.guardianPhone != null)) {
        allGuardians.add(
          Guardian.fromStudentGuardian(
            guardianId: student.guardianId,
            guardianName: student.guardianName,
            guardianPhone: student.guardianPhone,
            isPrimary: true,
          ),
        );
      }

      // Add extended guardians (filter by student ID if API supports it)
      // Note: The API might return all extended guardians for the current user,
      // so we might need to filter based on student relationship
      allGuardians.addAll(extendedGuardians);

      return allGuardians;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: 'Failed to fetch student guardians: $e');
    }
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
  // Location fields
  final double latitude;
  final double longitude;
  // Billing fields: must be echoed back unchanged on update.
  final bool hasStudentPaid;
  final String? expiryDate;

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
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.hasStudentPaid = false,
    this.expiryDate,
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
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      hasStudentPaid: json['hasStudentPaid'] == true,
      expiryDate: json['expirelyDate']?.toString(),
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
      'id': int.tryParse(id) ?? 0,
      'fullname': name,
      'guardianPhoneNumber': guardianPhone ?? '',
      'studentRegNumber': studentRegNumber ?? '',
      'schoolname': schoolName ?? schoolId ?? '',
      'transportOrg': transportOrg ?? '',
      'classname': className,
      'route': route ?? pickupLocation ?? '',
      'latitude': latitude,
      'longitude': longitude,
      'profileImage': photo ?? '',
      'hasStudentPaid': hasStudentPaid,
      'isStudentActive': isActive,
      'isStudentDeleted': false,
      'expirelyDate': ?expiryDate,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    };
  }

  /// Returns true if the student has a valid location (not default 0,0)
  bool hasValidLocation() {
    return latitude != 0.0 && longitude != 0.0;
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
