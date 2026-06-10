/// Driver model.
class Driver {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? licenseNumber;
  final String? schoolId;
  final String? schoolName;
  final String? companyOrgId;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Driver({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.licenseNumber,
    this.schoolId,
    this.schoolName,
    this.companyOrgId,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory Driver.fromJson(Map<String, dynamic> json) {
    return Driver(
      id: json['id']?.toString() ?? json['userId']?.toString() ?? '',
      name: json['name'] ?? json['fullname'] ?? '',
      email: json['email'],
      phone: json['phone'] ?? json['phoneNumber'],
      licenseNumber: json['licenseNumber'] ?? json['license_number'],
      // Try multiple possible fields for school ID
      schoolId:
          json['school_id'] ??
          json['schoolId'] ??
          json['companyOrgId'] ??
          json['school']?['id']?.toString(),
      schoolName:
          json['school_name'] ??
          json['schoolName'] ??
          json['companyOrgName'] ??
          json['school']?['name'],
      companyOrgId: json['companyOrgId'],
      isActive:
          json['isDriverActive'] ??
          json['isActive'] ??
          json['is_active'] ??
          true,
      createdAt: _parseDateTime(json['createdAt'] ?? json['created_at']),
      updatedAt: _parseDateTime(json['updatedAt'] ?? json['updated_at']),
    );
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
