/// Guardian model representing a student's guardian/parent
class Guardian {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? relationship;
  final bool isPrimary;
  final bool isExtended;
  final String? avatar;
  final bool isActive;

  Guardian({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.relationship,
    this.isPrimary = false,
    this.isExtended = false,
    this.avatar,
    this.isActive = true,
  });

  factory Guardian.fromJson(Map<String, dynamic> json) {
    return Guardian(
      id: json['id']?.toString() ?? json['guardianId']?.toString() ?? '',
      name: json['name'] ?? json['fullname'] ?? json['guardianName'] ?? 'Unknown',
      phone: json['phone'] ?? json['phoneNumber'] ?? json['guardianPhone'] ?? json['guardianPhoneNumber'],
      email: json['email'],
      relationship: json['relationship'] ?? json['relation'],
      isPrimary: json['isPrimary'] ?? json['is_primary'] ?? false,
      isExtended: json['isExtended'] ?? json['is_extended'] ?? false,
      avatar: json['avatar'] ?? json['profileImage'] ?? json['photo'],
      isActive: json['isActive'] ?? json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'relationship': relationship,
      'isPrimary': isPrimary,
      'isExtended': isExtended,
      'avatar': avatar,
      'isActive': isActive,
    };
  }

  /// Create a Guardian from student guardian fields
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
      isPrimary: isPrimary,
      isExtended: false,
    );
  }
}
