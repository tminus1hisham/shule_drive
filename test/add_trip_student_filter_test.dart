import 'package:flutter_test/flutter_test.dart';
import 'package:shule_drive/api/services/student_service.dart';
import 'package:shule_drive/widgets/add_trip_student_sheet.dart';

Student _s(String id, String name, [String? reg]) => Student(
  id: id,
  name: name,
  className: '4B',
  studentRegNumber: reg,
  createdAt: DateTime(2026),
);

void main() {
  final all = [
    _s('1', 'Amani Wanjiru', 'REG-001'),
    _s('2', 'Brian Otieno', 'REG-002'),
    _s('3', 'Mary Njeri', 'REG-003'),
  ];

  test('filters as you type, case-insensitive, by name or reg no.', () {
    expect(filterAddableStudents(all, 'an', {}).map((s) => s.id), ['1', '2']);
    expect(filterAddableStudents(all, 'NJERI', {}).single.id, '3');
    expect(filterAddableStudents(all, 'reg-002', {}).single.id, '2');
  });

  test('hides students already on the trip', () {
    expect(filterAddableStudents(all, '', {'1', '3'}).single.id, '2');
  });
}
