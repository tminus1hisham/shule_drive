/// Guardian model representing a student's guardian/parent.
///
/// This is the single canonical Guardian model. It unifies the fields needed by
/// the API layer (companyOrgId/schoolId/timestamps/bestPhoneNumber) and the UI
/// layer (relationship/isPrimary/isExtended/avatar) so there is only one type.
class Guardian {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? phoneNumber;
  final String? relationship;
  final bool isPrimary;
  final bool isExtended;
  final String? avatar;
  final String? companyOrgId;
  final String? schoolId;
  final String? schoolName;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Guardian({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.phoneNumber,
    this.relationship,
    this.isPrimary = false,
    this.isExtended = false,
    this.avatar,
    this.companyOrgId,
    this.schoolId,
    this.schoolName,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  /// Best phone number to use for contacting the guardian.
  String? get bestPhoneNumber => phoneNumber ?? phone;

  factory Guardian.fromJson(Map<String, dynamic> json) {
    return Guardian(
      id:
          json['id']?.toString() ??
          json['guardianId']?.toString() ??
          json['userId']?.toString() ??
          '',
      name:
          json['name'] ?? json['fullname'] ?? json['guardianName'] ?? 'Unknown',
      email: json['email'],
      phone:
          json['phone'] ??
          json['phoneNumber'] ??
          json['guardianPhone'] ??
          json['guardianPhoneNumber'],
      phoneNumber:
          json['phoneNumber'] ??
          json['phone'] ??
          json['guardianPhoneNumber'] ??
          json['guardianPhone'],
      relationship: json['relationship'] ?? json['relation'],
      isPrimary: json['isPrimary'] ?? json['is_primary'] ?? false,
      isExtended: json['isExtended'] ?? json['is_extended'] ?? false,
      avatar: json['avatar'] ?? json['profileImage'] ?? json['photo'],
      companyOrgId:
          json['companyOrgId'] ??
          json['company_org_id'] ??
          json['school_id'] ??
          json['schoolId'],
      schoolId: json['school_id'] ?? json['schoolId'],
      schoolName:
          json['schoolname'] ?? json['school_name'] ?? json['schoolName'],
      isActive:
          json['userActive'] ?? json['isActive'] ?? json['is_active'] ?? true,
      createdAt: _parseDateTime(json['createdAt'] ?? json['created_at']),
      updatedAt: _parseDateTime(json['updatedAt'] ?? json['updated_at']),
    );
  }

  /// Create a Guardian from a student's denormalized guardian fields.
  factory Guardian.fromStudentGuardian({
    required String? guardianId,
    required String? guardianName,
    required String? guardianPhone,
    bool isPrimary = true,
  }) {
    return Guardian(
      id: guardianId ?? '0',
      name: guardianName ?? 'Not Available',
      phone: guardianPhone,
      phoneNumber: guardianPhone,
      isPrimary: isPrimary,
      isExtended: false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'phoneNumber': phoneNumber,
      'relationship': relationship,
      'isPrimary': isPrimary,
      'isExtended': isExtended,
      'avatar': avatar,
      'companyOrgId': companyOrgId,
      'school_id': schoolId,
      'school_name': schoolName,
      'userActive': isActive,
      'createdAt': createdAt?.toUtc().toIso8601String(),
      'updatedAt': updatedAt?.toUtc().toIso8601String(),
    };
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    try {
      return DateTime.parse(value.toString());
    } catch (e) {
      return null;
    }
  }
}
