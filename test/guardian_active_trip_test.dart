import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shule_drive/api/services/trip_service.dart';

/// Shaped like a live GET /api/trips/get/student/active/trip row.
Map<String, dynamic> _row({
  required String run,
  required int studentId,
  bool picked = false,
  bool completed = false,
}) => {
  'id': studentId,
  'tripUniqueIdentity': run,
  'masterTripId': 2,
  'studentId': studentId,
  'studentReg': 'JJH00$studentId',
  'fullname': 'Student $studentId',
  'guardianPhoneNumber': '254710560190',
  'masterTripName': 'evening wangige',
  'numberPlate': 'KDJ 303C',
  'isTripActive': !completed,
  'isStudentPicked': picked,
  'isStudentDropped': completed,
  'isTripStarted': true,
  'isTripCompleted': completed,
  'pickedTime': '2026-10-06T11:47:00Z',
  'dropTime': '2026-10-06T11:47:00Z',
  'tripCompletedAt': '2026-10-06T11:47:00Z',
  'createdAt': completed ? '2026-10-05T16:06:07Z' : '2026-10-06T11:46:50Z',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('guardian sees the running trip, not an old run', () async {
    dotenv.testLoad(fileInput: 'API_BASE_URL=https://example.test');
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final client = MockClient((request) async {
      if (request.url.path == '/api/guardians/get/students') {
        return http.Response(
          jsonEncode([
            {'id': 1, 'fullname': 'Student 1'},
            {'id': 2, 'fullname': 'Student 2'},
          ]),
          200,
        );
      }
      expect(request.url.path, '/api/trips/get/student/active/trip');
      expect(request.url.queryParameters['guardianPhone'], '254710560190');
      final id = int.parse(request.url.queryParameters['studentId']!);
      // Live shape: every run the child was on, oldest first.
      return http.Response(
        jsonEncode([
          _row(run: 'old', studentId: id, picked: true, completed: true),
          _row(run: 'now', studentId: id, picked: id == 1),
        ]),
        200,
      );
    });

    await http.runWithClient(() async {
      final trip = await TripService().getActiveTrip(
        guardianPhone: '254710560190',
      );
      expect(trip!.id, 'now');
      expect(trip.status, 'active');
      expect(trip.students.map((s) => s.status), ['picked', 'pending']);
    }, () => client);
    client.close();
  });

}
