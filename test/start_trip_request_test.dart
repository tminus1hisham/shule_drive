import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shule_drive/api/api_exceptions.dart';
import 'package:shule_drive/api/services/trip_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('start trip sends a nonblank route or rejects before posting', () async {
    dotenv.testLoad(fileInput: 'API_BASE_URL=https://example.test');
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final bodies = <Map<String, dynamic>>[];
    final client = MockClient((request) async {
      expect(request.url.path, '/api/trips/start');
      bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
      return http.Response('{"tripUniqueId":"trip-1"}', 200);
    });

    await http.runWithClient(() async {
      final service = TripService();
      for (final route in [' Selected Route ', '', '   ', null]) {
        await service.startTrip(
          masterTripId: 7,
          routeId: '42',
          vehicleId: 'bus-1',
          route: route,
        );
      }
      expect(bodies.map((body) => body['route']).toList(), [
        'Selected Route',
        '42',
        '42',
        '42',
      ]);
      expect(bodies.every((body) => body['masterTripId'] == 7), isTrue);

      // Numeric route/vehicle IDs must never be used as a master trip ID.
      for (final masterTripId in <int?>[null, 0, -1]) {
        await expectLater(
          service.startTrip(
            masterTripId: masterTripId,
            routeId: '1',
            vehicleId: '2',
            route: 'Wangige',
          ),
          throwsA(
            isA<ApiException>().having(
              (error) => error.message,
              'message',
              'Select a scheduled trip before starting',
            ),
          ),
        );
      }

      await expectLater(
        service.startTrip(
          masterTripId: 7,
          routeId: ' ',
          vehicleId: 'bus-1',
          route: ' ',
        ),
        throwsA(isA<ApiException>()),
      );
      expect(bodies, hasLength(4));
    }, () => client);
    client.close();
  });
}
