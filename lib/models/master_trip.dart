import 'package:flutter/foundation.dart';

/// Master Trip Model
/// Represents a trip created by admin/organization
class MasterTrip {
  final int id;
  final String tripName;
  final String tripTime;
  final String tripType;
  final String tripDirection;
  final String route;
  final String createdBy;
  final String schoolname;
  final String adminUserId;
  final bool isTripActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  MasterTrip({
    required this.id,
    required this.tripName,
    required this.tripTime,
    required this.tripType,
    required this.tripDirection,
    required this.route,
    required this.createdBy,
    required this.schoolname,
    required this.adminUserId,
    required this.isTripActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MasterTrip.fromJson(Map<String, dynamic> json) {
    return MasterTrip(
      id: json['id'] ?? 0,
      tripName: json['tripName'] ?? '',
      tripTime: json['tripTime'] ?? '',
      tripType: json['tripType'] ?? '',
      tripDirection: json['tripDirection'] ?? '',
      route: json['route'] ?? '',
      createdBy: json['createdBy'] ?? '',
      schoolname: json['schoolname'] ?? '',
      adminUserId: json['adminUserId'] ?? '',
      isTripActive: json['isTripActive'] ?? false,
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDateTime(json['updatedAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tripName': tripName,
      'tripTime': tripTime,
      'tripType': tripType,
      'tripDirection': tripDirection,
      'route': route,
      'createdBy': createdBy,
      'schoolname': schoolname,
      'adminUserId': adminUserId,
      'isTripActive': isTripActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
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

/// Trip Student Model
/// Represents a student assigned to a master trip
class TripStudent {
  final int id;
  final int masterTripId;
  final String fullname;
  final int studentId;
  final String guardianPhoneNumber;
  final String studentRegNumber;
  final String schoolname;
  final String transportOrg;
  final String classname;
  final String route;
  final double latitude;
  final double longitude;
  final double pickedLatitude;
  final double pickedLongitude;
  final double droppedLatitude;
  final double droppedLongitude;
  final bool isStudentPicked;
  final bool isStudentDropped;
  final String profileImage;
  final String address;
  final String createdBy;
  final bool hasStudentPaid;
  final bool isStudentActive;
  final bool isStudentDeleted;
  final DateTime? pickedTime;
  final DateTime? dropTime;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  TripStudent({
    required this.id,
    required this.masterTripId,
    required this.fullname,
    required this.studentId,
    required this.guardianPhoneNumber,
    required this.studentRegNumber,
    required this.schoolname,
    required this.transportOrg,
    required this.classname,
    required this.route,
    required this.latitude,
    required this.longitude,
    required this.pickedLatitude,
    required this.pickedLongitude,
    required this.droppedLatitude,
    required this.droppedLongitude,
    required this.isStudentPicked,
    required this.isStudentDropped,
    required this.profileImage,
    required this.address,
    required this.createdBy,
    required this.hasStudentPaid,
    required this.isStudentActive,
    required this.isStudentDeleted,
    this.pickedTime,
    this.dropTime,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TripStudent.fromJson(Map<String, dynamic> json) {
    return TripStudent(
      id: json['id'] ?? 0,
      masterTripId: json['masterTripId'] ?? 0,
      fullname: json['fullname'] ?? '',
      studentId: json['studentId'] ?? 0,
      guardianPhoneNumber: json['guardianPhoneNumber'] ?? '',
      studentRegNumber: json['studentRegNumber'] ?? '',
      schoolname: json['schoolname'] ?? '',
      transportOrg: json['transportOrg'] ?? '',
      classname: json['classname'] ?? '',
      route: json['route'] ?? '',
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
      pickedLatitude: (json['pickedLatitude'] ?? 0).toDouble(),
      pickedLongitude: (json['pickedLongitude'] ?? 0).toDouble(),
      droppedLatitude: (json['droppedLatitude'] ?? 0).toDouble(),
      droppedLongitude: (json['droppedLongitude'] ?? 0).toDouble(),
      isStudentPicked: json['isStudentPicked'] ?? false,
      isStudentDropped: json['isStudentDropped'] ?? false,
      profileImage: json['profileImage'] ?? '',
      address: json['address'] ?? '',
      createdBy: json['createdBy'] ?? '',
      hasStudentPaid: json['hasStudentPaid'] ?? false,
      isStudentActive: json['isStudentActive'] ?? false,
      isStudentDeleted: json['isStudentDeleted'] ?? false,
      pickedTime: _parseDateTime(json['pickedTime']),
      dropTime: _parseDateTime(json['dropTime']),
      completedAt: _parseDateTime(json['completedAt']),
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDateTime(json['updatedAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'masterTripId': masterTripId,
      'fullname': fullname,
      'studentId': studentId,
      'guardianPhoneNumber': guardianPhoneNumber,
      'studentRegNumber': studentRegNumber,
      'schoolname': schoolname,
      'transportOrg': transportOrg,
      'classname': classname,
      'route': route,
      'latitude': latitude,
      'longitude': longitude,
      'pickedLatitude': pickedLatitude,
      'pickedLongitude': pickedLongitude,
      'droppedLatitude': droppedLatitude,
      'droppedLongitude': droppedLongitude,
      'isStudentPicked': isStudentPicked,
      'isStudentDropped': isStudentDropped,
      'profileImage': profileImage,
      'address': address,
      'createdBy': createdBy,
      'hasStudentPaid': hasStudentPaid,
      'isStudentActive': isStudentActive,
      'isStudentDeleted': isStudentDeleted,
      'pickedTime': pickedTime?.toIso8601String(),
      'dropTime': dropTime?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
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

/// Trip Guardian Model
/// Represents a guardian of students in a master trip (for drivers)
class TripGuardian {
  final int id;
  final String userId;
  final String fullname;
  final String phoneNumber;
  final String securityToken;
  final String email;
  final String schoolname;
  final String companyOrgId;
  final String userType;
  final bool userActive;
  final bool isGuardianDeleted;
  final String createdById;
  final String editedById;
  final String firebaseToken;
  final String extendedUsers;
  final String adminPhoneNumber;
  final DateTime createdAt;
  final DateTime updatedAt;

  TripGuardian({
    required this.id,
    required this.userId,
    required this.fullname,
    required this.phoneNumber,
    required this.securityToken,
    required this.email,
    required this.schoolname,
    required this.companyOrgId,
    required this.userType,
    required this.userActive,
    required this.isGuardianDeleted,
    required this.createdById,
    required this.editedById,
    required this.firebaseToken,
    required this.extendedUsers,
    required this.adminPhoneNumber,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TripGuardian.fromJson(Map<String, dynamic> json) {
    return TripGuardian(
      id: json['id'] ?? 0,
      userId: json['userId'] ?? '',
      fullname: json['fullname'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      securityToken: json['securityToken'] ?? '',
      email: json['email'] ?? '',
      schoolname: json['schoolname'] ?? '',
      companyOrgId: json['companyOrgId'] ?? '',
      userType: json['userType'] ?? '',
      userActive: json['userActive'] ?? false,
      isGuardianDeleted: json['isGuardianDeleted'] ?? false,
      createdById: json['createdById'] ?? '',
      editedById: json['editedById'] ?? '',
      firebaseToken: json['firebaseToken'] ?? '',
      extendedUsers: json['extendedUsers'] ?? '',
      adminPhoneNumber: json['adminPhoneNumber'] ?? '',
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDateTime(json['updatedAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'fullname': fullname,
      'phoneNumber': phoneNumber,
      'securityToken': securityToken,
      'email': email,
      'schoolname': schoolname,
      'companyOrgId': companyOrgId,
      'userType': userType,
      'userActive': userActive,
      'isGuardianDeleted': isGuardianDeleted,
      'createdById': createdById,
      'editedById': editedById,
      'firebaseToken': firebaseToken,
      'extendedUsers': extendedUsers,
      'adminPhoneNumber': adminPhoneNumber,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
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
