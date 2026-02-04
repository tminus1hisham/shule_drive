import '../api_client.dart';
import '../api_exceptions.dart';
import '../endpoints.dart';

/// Student Service - Handles student/children-related API calls
class StudentService {
  final ApiClient _apiClient = ApiClient();
  
  /// Get all students
  /// GET /api/students
  Future<List<Student>> getAllStudents({int page = 1, int limit = 20}) async {
    try {
      final response = await _apiClient.get(
        Endpoints.students,
        queryParams: {
          'page': page.toString(),
          'limit': limit.toString(),
        },
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
      
      final students = studentsData.map((student) => Student.fromJson(student)).toList();
      return students;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }
  
  /// Get student by ID
  /// GET /api/students/get/{id}
  Future<Student> getStudentById(String studentId) async {
    try {
      final response = await _apiClient.get(
        Endpoints.studentDetails(studentId),
      );
      
      return Student.fromJson(response['data']);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }
  
  /// Create a new student (through guardian)
  /// POST /api/guardians/student/create
  Future<Student> createStudent({
    required String name,
    required String className,
    String? schoolId,
    String? guardianId,
    String? photo,
    String? pickupLocation,
    String? dropoffLocation,
    String? emergencyContact,
    String? emergencyPhone,
  }) async {
    try {
      final response = await _apiClient.post(
        Endpoints.createGuardianStudent,
        body: {
          'name': name,
          'class_name': className,
          if (schoolId != null) 'school_id': schoolId,
          if (guardianId != null) 'guardian_id': guardianId,
          if (photo != null) 'photo': photo,
          if (pickupLocation != null) 'pickup_location': pickupLocation,
          if (dropoffLocation != null) 'dropoff_location': dropoffLocation,
          if (emergencyContact != null) 'emergency_contact': emergencyContact,
          if (emergencyPhone != null) 'emergency_phone': emergencyPhone,
        },
      );
      
      return Student.fromJson(response['data']);
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
      if (emergencyContact != null) body['emergency_contact'] = emergencyContact;
      if (emergencyPhone != null) body['emergency_phone'] = emergencyPhone;
      
      final response = await _apiClient.put(
        Endpoints.updateStudent(studentId),
        body: body,
      );
      
      return Student.fromJson(response['data']);
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
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }
  
  /// Get guardian's students
  /// GET /api/guardians/get/students
  Future<List<Student>> getGuardianStudents() async {
    try {
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
      
      final students = studentsData.map((student) => Student.fromJson(student)).toList();
      return students;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }
  
  /// Get students by phone number
  /// GET /api/guardians/get/students/by/phone
  Future<List<Student>> getStudentsByPhone(String phoneNumber) async {
    try {
      final response = await _apiClient.get(
        Endpoints.getGuardianStudentsByPhone,
        queryParams: {'phone': phoneNumber},
      );
      
      final students = (response['data'] as List)
          .map((student) => Student.fromJson(student))
          .toList();
      
      return students;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: e.toString());
    }
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
        body: {
          'student_id': studentId,
          'image_path': imagePath,
        },
      );
      
      return response['data']['image_url'];
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }
  
  /// Get student attendance
  /// GET /api/students/{id}/attendance
  Future<List<AttendanceRecord>> getStudentAttendance(String studentId) async {
    try {
      final response = await _apiClient.get(
        Endpoints.studentAttendance(studentId),
      );
      
      final records = (response['data'] as List)
          .map((r) => AttendanceRecord.fromJson(r))
          .toList();
      
      return records;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: e.toString());
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
  });
  
  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      photo: json['photo'],
      className: json['class_name'] ?? json['class'] ?? '',
      schoolId: json['school_id'],
      schoolName: json['school_name'],
      guardianId: json['guardian_id'],
      guardianName: json['guardian_name'],
      guardianPhone: json['guardian_phone'],
      pickupLocation: json['pickup_location'],
      dropoffLocation: json['dropoff_location'],
      emergencyContact: json['emergency_contact'],
      emergencyPhone: json['emergency_phone'],
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
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
    };
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
      id: json['id'] ?? '',
      studentId: json['student_id'] ?? '',
      tripId: json['trip_id'] ?? '',
      status: json['status'] ?? 'absent',
      date: DateTime.parse(json['date'] ?? DateTime.now().toIso8601String()),
      notes: json['notes'],
    );
  }
}
