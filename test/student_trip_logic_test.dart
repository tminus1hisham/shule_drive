import 'package:flutter_test/flutter_test.dart';
import 'package:shule_drive/utils/student_trip_logic.dart';

void main() {
  group('student proximity', () {
    test('detects locations within the prompt radius', () {
      final distance = calculateStudentDistanceMeters(
        vehicleLatitude: -1.2921,
        vehicleLongitude: 36.8219,
        targetLatitude: -1.2925,
        targetLongitude: 36.8221,
      );

      expect(distance, lessThan(studentProximityThresholdMeters));
      expect(isWithinStudentProximity(distance), isTrue);
    });

    test('detects locations outside the prompt radius', () {
      final distance = calculateStudentDistanceMeters(
        vehicleLatitude: -1.2921,
        vehicleLongitude: 36.8219,
        targetLatitude: -1.3000,
        targetLongitude: 36.8300,
      );

      expect(distance, greaterThan(studentProximityThresholdMeters));
      expect(isWithinStudentProximity(distance), isFalse);
    });

    test('prompts from 200 m, the top of the 100-200 m approach range', () {
      expect(isWithinStudentProximity(150), isTrue);
      expect(isWithinStudentProximity(200), isTrue);
      expect(isWithinStudentProximity(201), isFalse);
    });

    test('nearestBy picks the closest known distance, ignores unknown', () {
      final distances = {'a': 900.0, 'b': null, 'c': 120.0};
      expect(nearestBy(distances.keys, (k) => distances[k]), 'c');
      expect(nearestBy(['b'], (k) => distances[k]), isNull);
    });

    test('formats distance for the "Pick X in ..." prompt', () {
      expect(formatStudentDistance(149.6), '150 m');
      expect(formatStudentDistance(1240), '1.2 km');
    });

    test('off-route distance: on the line ~0, one street over ~111 m', () {
      // A road running east along latitude -1.2921 (Nairobi).
      final road = [(lat: -1.2921, lng: 36.8200), (lat: -1.2921, lng: 36.8300)];
      expect(
        distanceToPolylineMeters((lat: -1.2921, lng: 36.8250), road),
        lessThan(1),
      );
      // 0.001 deg of latitude north of the road ~= 111 m -> off route.
      final off = distanceToPolylineMeters((lat: -1.2911, lng: 36.8250), road);
      expect(off, closeTo(111, 2));
      // Past the end of the road, distance is to the endpoint.
      final past = distanceToPolylineMeters((lat: -1.2921, lng: 36.8310), road);
      expect(past, closeTo(111, 2));
    });

    test('orders stops nearest-first from the bus', () {
      const bus = (lat: 0.0, lng: 0.0);
      final stops = {
        'far': (lat: 0.0, lng: 0.03),
        'near': (lat: 0.0, lng: 0.01),
        'mid': (lat: 0.0, lng: 0.02),
      };
      expect(
        orderNearestFirst(bus, stops.keys, (k) => stops[k]!),
        ['near', 'mid', 'far'],
      );
    });

    test('recognizes API trip direction values for return trips', () {
      expect(isReturnTripDirection('from_school'), isTrue);
      expect(isReturnTripDirection('Dropoff'), isTrue);
      expect(isReturnTripDirection('to_school'), isFalse);
      expect(isReturnTripDirection('Pickup'), isFalse);
    });
  });
}

