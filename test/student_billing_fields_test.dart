import 'package:flutter_test/flutter_test.dart';
import 'package:shule_drive/api/services/student_service.dart';

void main() {
  test('paid status and expiry survive a round trip (not reset on update)', () {
    final student = Student.fromJson({
      'id': 7,
      'fullname': 'Paid Kid',
      'hasStudentPaid': true,
      'expirelyDate': '2027-01-31T00:00:00Z',
    });

    final json = student.toJson();
    expect(json['hasStudentPaid'], isTrue);
    expect(json['expirelyDate'], '2027-01-31T00:00:00Z');
  });
}
