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
        'id': 777,
        'studentId': 42,
        'fullname': 'Amina Otieno',
        'isStudentPicked': true,
        'latitude': -1.2921,
        'longitude': 36.8219,
      });

      expect(picked.id, '42');
      expect(picked.tripStudentId, '777');
      expect(picked.name, 'Amina Otieno');
      expect(picked.status, 'picked');
      expect(picked.latitude, -1.2921);
      expect(picked.longitude, 36.8219);

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
      final student = StudentPickup(id: 's1', name: 'Brian', status: 'pending');
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

    test('builds api.md pick/drop all payload', () {
      final payload = TripService.buildPickDropAllBody(
        uniqueTripIdentity: 'trip-123',
        latitude: -1.2921,
        longitude: 36.8219,
        isDroppingAll: false,
        updatedAt: DateTime.utc(2026, 6, 9, 10, 30),
      );

      expect(payload, {
        'uniqueTripIdentity': 'trip-123',
        'latitude': -1.2921,
        'longitude': 36.8219,
        'isDroppingAll': false,
        'updatedAt': '2026-06-09T10:30:00.000Z',
      });
    });

    test('treats a message-only end response as an acknowledgement', () {
      final trip = TripService.parseEndTripResponse({
        'message': 'Drop all success.',
      }, tripId: 'trip-123');

      expect(trip, isNull);
    });

    test('builds api.md student not picked payload', () {
      final payload = TripService.buildStudentNotPickedBody(
        tripUniqueIdentity: 'trip-123',
        studentId: 42,
        reason: 'Absent',
        updatedAt: DateTime.utc(2026, 6, 9, 10, 30),
      );

      expect(payload, {
        'tripUniqueIdentity': 'trip-123',
        'studentId': 42,
        'reason': 'Absent',
        'updatedAt': '2026-06-09T10:30:00.000Z',
      });
    });

    test('builds api.md single student pick payload', () {
      final payload = TripService.buildPickSingleStudentBody(
        uniqueTripIdentity: 'trip-123',
        studentReg: 'REG-001',
        guardianPhoneNumber: '+254700000000',
        numberPlate: 'KDA 123A',
        isDropping: false,
        latitude: -1.2921,
        longitude: 36.8219,
      );

      expect(payload, {
        'uniqueTripIdentity': 'trip-123',
        'studentReg': 'REG-001',
        'guardianPhoneNumber': '+254700000000',
        'numberPlate': 'KDA 123A',
        'action': 'picked',
        'latitude': -1.2921,
        'longitude': 36.8219,
      });
    });

    test('builds api.md single student drop payload', () {
      final payload = TripService.buildPickSingleStudentBody(
        uniqueTripIdentity: 'trip-123',
        studentReg: 'REG-001',
        guardianPhoneNumber: '+254700000000',
        numberPlate: 'KDA 123A',
        isDropping: true,
      );

      expect(payload['action'], 'dropped');
      expect(payload['latitude'], 0);
      expect(payload['longitude'], 0);
    });
  });
}
