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

    test('keeps local students the server run never had', () {
      final local = _trip('t1', [
        _student('s1', 'pending'),
        _student('late', 'picked'),
      ]);
      final fetched = _trip('t1', [_student('s1', 'picked')]);

      final merged = TripProvider.mergeWithLocalStatuses(fetched, local);

      expect(merged.students.map((s) => s.id), ['s1', 'late']);
      expect(merged.students.last.status, 'picked');
    });

    test('recognises the server refusing a student added mid-trip', () {
      expect(TripProvider.isStudentNotOnRun('Student not found.'), isTrue);
      expect(TripProvider.isStudentNotOnRun('Invalid request'), isFalse);
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

  group('TripProvider.completeTripFromResponse', () {
    test('preserves local metadata for an acknowledgement-only response', () {
      final startedAt = DateTime(2026, 6, 10, 7, 30);
      final completedAt = DateTime(2026, 6, 10, 9, 15);
      final stop = TripStop(
        id: 'stop-1',
        name: 'School',
        address: 'Nairobi',
        order: 1,
      );
      final original = Trip(
        id: 'trip-1',
        routeName: 'Morning Route',
        routeId: 'route-7',
        masterTripId: 117,
        tripDirection: 'to_school',
        startTime: startedAt,
        status: 'active',
        vehicleId: 'bus-12',
        vehicleNumber: 'KDA 123A',
        students: [_student('s1', 'dropped')],
        stops: [stop],
        distance: 12.4,
        fare: 500,
        notes: 'Use east gate',
      );

      final completed = TripProvider.completeTripFromResponse(
        tripId: original.id,
        originalTrip: original,
        responseTrip: null,
        completedAt: completedAt,
      );

      expect(completed.status, 'completed');
      expect(completed.endTime, completedAt);
      expect(completed.startTime, startedAt);
      expect(completed.routeName, original.routeName);
      expect(completed.routeId, original.routeId);
      expect(completed.masterTripId, original.masterTripId);
      expect(completed.tripDirection, original.tripDirection);
      expect(completed.vehicleNumber, original.vehicleNumber);
      expect(completed.students, same(original.students));
      expect(completed.stops, same(original.stops));
      expect(completed.distance, original.distance);
      expect(completed.fare, original.fare);
      expect(completed.notes, original.notes);
    });
  });
}
