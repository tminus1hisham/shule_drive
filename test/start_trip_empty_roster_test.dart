import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shule_drive/api/api_exceptions.dart';
import 'package:shule_drive/api/services/trip_service.dart';

// Own file: ApiClient caches its http.Client for the whole test process.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('starting a trip with no students explains why it failed', () async {
    dotenv.testLoad(fileInput: 'API_BASE_URL=https://example.test');
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    // Mirrors the live server: an empty master trip rejects the start with a
    // bare "Invalid request" and reports the trip itself as not found.
    final client = MockClient((request) async {
      if (request.url.path == '/api/trips/start') {
        return http.Response(jsonEncode({'message': 'Invalid request'}), 400);
      }
      return http.Response(
        jsonEncode({'message': 'Master trip not found'}),
        404,
      );
    });

    await http.runWithClient(() async {
      await expectLater(
        TripService().startTrip(
          masterTripId: 1,
          routeId: '1',
          route: 'Wangige',
          vehicleId: 'bus-1',
          numberPlate: 'KDJ 101A',
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('no students'),
          ),
        ),
      );
    }, () => client);
    client.close();
  });
}
