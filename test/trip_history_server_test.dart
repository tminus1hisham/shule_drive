import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shule_drive/api/services/trip_service.dart';
import 'package:shule_drive/models/master_trip.dart';
import 'package:shule_drive/services/trip_history_service.dart';

const _driverId = 'driver-1';

final _masterTrip = MasterTrip.fromJson({
  'id': 1,
  'tripName': 'morning route',
  'tripTime': '6:00 PM',
  'tripType': 'Normal',
  'tripDirection': 'to_school',
  'route': 'Wangige',
  'createdBy': _driverId,
  'isTripActive': true,
  'createdAt': '2026-09-29T14:44:45Z',
  'updatedAt': '2026-09-29T14:44:45Z',
});

/// Shaped like a live GET /api/trips/get/unique/trips row.
Map<String, dynamic> _row({
  required String run,
  required int studentId,
  String driverId = _driverId,
  bool picked = false,
  bool dropped = false,
  bool notPicked = false,
  bool completed = false,
  String createdAt = '2026-09-30T10:42:24Z',
}) => {
  'id': studentId,
  'tripUniqueIdentity': run,
  'masterTripId': 1,
  'studentId': studentId,
  'studentReg': 'JJH00$studentId',
  'fullname': 'Student $studentId',
  'guardianPhoneNumber': '254710560190',
  'masterTripName': 'morning route',
  'tripDirection': '',
  'numberPlate': 'KDJ 101A',
  'attendantName': '',
  'driverName': 'ObedDriver',
  'driverId': driverId,
  'route': 'Wangige',
  'isTripActive': !completed,
  'isStudentPicked': picked,
  'isStudentDropped': dropped,
  'isTripStarted': true,
  'isTripCompleted': completed,
  'isTripCancelled': false,
  'isStudentNotPicked': notPicked,
  'notPickedReason': notPicked ? 'Sick' : '',
  // The server fills these even when the event never happened.
  'pickedTime': '2026-09-30T10:42:25Z',
  'dropTime': '2026-09-30T10:42:25Z',
  'tripCompletedAt': '2026-09-30T10:44:04Z',
  'createdAt': createdAt,
};

TripHistory _entry(Trip trip) => TripHistory(
  trip: trip,
  driverId: _driverId,
  driverName: 'ObedDriver',
  loggedAt: trip.startTime,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('tripsFromRunRows', () {
    test('folds per-student rows into one trip per run', () {
      final trips = TripService.tripsFromRunRows([
        _row(
          run: 'old',
          studentId: 1,
          picked: true,
          dropped: true,
          completed: true,
          createdAt: '2026-09-29T07:00:00Z',
        ),
        _row(run: 'new', studentId: 1, picked: true),
        _row(run: 'new', studentId: 2),
        _row(run: 'new', studentId: 3, notPicked: true),
      ], masterTrip: _masterTrip);

      expect(trips.map((t) => t.id), ['new', 'old']);

      final running = trips.first;
      expect(running.status, 'active');
      expect(running.endTime, isNull);
      expect(running.routeName, 'morning route');
      expect(running.vehicleNumber, 'KDJ 101A');
      expect(running.masterTripId, 1);
      // Blank on the row, so taken from the master trip.
      expect(running.tripDirection, 'to_school');
      expect(running.students.map((s) => s.status), [
        'picked',
        'pending',
        'absent',
      ]);
      expect(running.students[1].pickupTime, isNull);
      expect(running.students[2].notes, 'Sick');

      final finished = trips.last;
      expect(finished.status, 'completed');
      expect(finished.endTime, DateTime.parse('2026-09-30T10:44:04Z'));
      expect(finished.pickedUpCount, 1);
    });
  });

  group('mergeHistories', () {
    final serverTrip = TripService.tripsFromRunRows([
      _row(run: 'run-1', studentId: 1),
    ], masterTrip: _masterTrip).single;

    test('keeps device-only trips next to server trips', () {
      final deviceOnly = serverTrip.copyWith(
        id: 'offline-run',
        startTime: serverTrip.startTime.add(const Duration(hours: 1)),
      );
      final merged = TripHistoryService.mergeHistories(
        server: [_entry(serverTrip)],
        local: [_entry(deviceOnly)],
      );
      expect(merged.map((h) => h.trip.id), ['offline-run', 'run-1']);
    });

    test('never rolls back progress the device recorded first', () {
      final local = serverTrip.copyWith(
        status: 'completed',
        distance: 12.5,
        students: [serverTrip.students.single.copyWith(status: 'dropped')],
      );
      final merged = TripHistoryService.mergeHistories(
        server: [_entry(serverTrip)],
        local: [_entry(local)],
      ).single.trip;

      expect(merged.status, 'completed');
      expect(merged.distance, 12.5);
      expect(merged.students.single.status, 'dropped');
    });
  });

  test('loads the driver\'s server trips and keeps them offline', () async {
    dotenv.testLoad(fileInput: 'API_BASE_URL=https://example.test');
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    var offline = false;
    final client = MockClient((request) async {
      if (offline) throw http.ClientException('offline');
      if (request.url.path == '/api/trips/get/all/master/trips') {
        return http.Response(jsonEncode([_masterTrip.toJson()]), 200);
      }
      expect(request.url.path, '/api/trips/get/unique/trips');
      expect(request.url.queryParameters['masterTripId'], '1');
      return http.Response(
        jsonEncode([
          _row(
            run: 'mine',
            studentId: 1,
            picked: true,
            dropped: true,
            completed: true,
          ),
          _row(run: 'someone-else', studentId: 2, driverId: 'driver-2'),
        ]),
        200,
      );
    });

    await http.runWithClient(() async {
      final service = TripHistoryService();
      final online = await service.getDriverTripHistory(_driverId);
      expect(online.map((h) => h.trip.id), ['mine']);
      expect(online.single.driverName, 'ObedDriver');

      offline = true;
      final saved = await service.getDriverTripHistory(_driverId);
      expect(saved.map((h) => h.trip.id), ['mine']);
      expect((await service.getDriverStats(_driverId)).totalPicked, 1);
    }, () => client);
    client.close();
  });
}
