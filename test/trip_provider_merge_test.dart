import 'package:flutter_test/flutter_test.dart';
import 'package:shule_drive/api/services/trip_service.dart';
import 'package:shule_drive/providers/trip_provider.dart';

Trip _trip(String id, List<StudentPickup> students) {
  return Trip(
    id: id,
    routeName: 'Morning Route',
    routeId: '7',
    startTime: DateTime(2026, 6, 10, 7, 30),
    status: 'active',
    vehicleId: '12',
    students: students,
    stops: const [],
  );
}

StudentPickup _student(String id, String status) {
  return StudentPickup(id: id, name: 'Student $id', status: status);
}

void main() {
  group('TripProvider.mergeWithLocalStatuses', () {
    test('keeps locally recorded picked status over stale pending', () {
      final local = _trip('t1', [
        _student('s1', 'picked'),
        _student('s2', 'pending'),
      ]);
      final fetched = _trip('t1', [
        _student('s1', 'pending'),
        _student('s2', 'pending'),
      ]);

      final merged = TripProvider.mergeWithLocalStatuses(fetched, local);

      expect(merged.students[0].status, 'picked');
      expect(merged.students[1].status, 'pending');
    });

    test('takes fetched status when it is further along', () {
      final local = _trip('t1', [_student('s1', 'picked')]);
      final fetched = _trip('t1', [_student('s1', 'dropped')]);

      final merged = TripProvider.mergeWithLocalStatuses(fetched, local);

      expect(merged.students.single.status, 'dropped');
    });

    test('keeps local absent over fetched pending', () {
      final local = _trip('t1', [_student('s1', 'absent')]);
      final fetched = _trip('t1', [_student('s1', 'pending')]);

      final merged = TripProvider.mergeWithLocalStatuses(fetched, local);

      expect(merged.students.single.status, 'absent');
    });

    test('returns fetched unchanged for a different trip', () {
      final local = _trip('t1', [_student('s1', 'picked')]);
      final fetched = _trip('t2', [_student('s1', 'pending')]);

      final merged = TripProvider.mergeWithLocalStatuses(fetched, local);

      expect(merged.students.single.status, 'pending');
    });

    test('preserves local students when fetched trip has none', () {
      final local = _trip('t1', [
        _student('s1', 'picked'),
        _student('s2', 'absent'),
      ]);
      final fetched = _trip('t1', const []);

      final merged = TripProvider.mergeWithLocalStatuses(fetched, local);

      expect(merged.students.length, 2);
      expect(merged.students[0].status, 'picked');
      expect(merged.students[1].status, 'absent');
    });

    test('keeps fetched students that are unknown locally', () {
      final local = _trip('t1', [_student('s1', 'picked')]);
      final fetched = _trip('t1', [
        _student('s1', 'pending'),
        _student('s3', 'pending'),
      ]);

      final merged = TripProvider.mergeWithLocalStatuses(fetched, local);

      expect(merged.students.length, 2);
      expect(merged.students[0].status, 'picked');
      expect(merged.students[1].id, 's3');
    });
  });
}
