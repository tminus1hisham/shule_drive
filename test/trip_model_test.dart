import 'package:flutter_test/flutter_test.dart';
import 'package:shule_drive/api/services/trip_service.dart';

void main() {
  group('StudentPickup', () {
    test('normalizes API status variants', () {
      expect(StudentPickup.normalizeStatus('picked_up'), 'picked');
      expect(StudentPickup.normalizeStatus('DROPPED_OFF'), 'dropped');
      expect(StudentPickup.normalizeStatus('not_available'), 'absent');
      expect(StudentPickup.normalizeStatus('unexpected'), 'pending');
    });

    test('parses defensive API shapes', () {
      final picked = StudentPickup.fromJson({
        'studentId': 42,
        'fullname': 'Amina Otieno',
        'isStudentPicked': true,
      });

      expect(picked.id, '42');
      expect(picked.name, 'Amina Otieno');
      expect(picked.status, 'picked');

      final dropped = StudentPickup.fromJson({
        'studentId': 42,
        'fullname': 'Amina Otieno',
        'isStudentPicked': true,
        'isStudentDropped': true,
      });

      expect(dropped.status, 'dropped');
    });
  });

  group('Trip', () {
    test('parses numeric identifiers and normalizes trip status', () {
      final trip = Trip.fromJson({
        'id': 1001,
        'routeName': 'Morning Route',
        'routeId': 7,
        'vehicleId': 12,
        'status': 'ongoing',
      });

      expect(trip.id, '1001');
      expect(trip.routeId, '7');
      expect(trip.vehicleId, '12');
      expect(trip.status, 'active');
    });

    test('copyWith replaces students without mutating original trip', () {
      final student = StudentPickup(
        id: 's1',
        name: 'Brian',
        status: 'pending',
      );
      final trip = Trip(
        id: 't1',
        routeName: 'Morning Route',
        routeId: 'r1',
        startTime: DateTime(2026),
        status: 'active',
        vehicleId: 'bus1',
        students: [student],
        stops: const [],
      );

      final updated = trip.copyWith(
        students: [student.copyWith(status: 'picked')],
      );

      expect(trip.students.single.status, 'pending');
      expect(updated.students.single.status, 'picked');
      expect(updated.pickedCount, 1);
    });
  });
}
