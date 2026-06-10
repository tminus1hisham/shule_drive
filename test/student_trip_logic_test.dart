import 'package:flutter_test/flutter_test.dart';
import 'package:shule_drive/utils/student_trip_logic.dart';

void main() {
  group('student proximity', () {
    test('detects locations within 100 meters', () {
      final distance = calculateStudentDistanceMeters(
        vehicleLatitude: -1.2921,
        vehicleLongitude: 36.8219,
        targetLatitude: -1.2925,
        targetLongitude: 36.8221,
      );

      expect(distance, lessThan(studentProximityThresholdMeters));
      expect(isWithinStudentProximity(distance), isTrue);
    });

    test('detects locations outside 100 meters', () {
      final distance = calculateStudentDistanceMeters(
        vehicleLatitude: -1.2921,
        vehicleLongitude: 36.8219,
        targetLatitude: -1.3000,
        targetLongitude: 36.8300,
      );

      expect(distance, greaterThan(studentProximityThresholdMeters));
      expect(isWithinStudentProximity(distance), isFalse);
    });

    test('recognizes API trip direction values for return trips', () {
      expect(isReturnTripDirection('from_school'), isTrue);
      expect(isReturnTripDirection('Dropoff'), isTrue);
      expect(isReturnTripDirection('to_school'), isFalse);
      expect(isReturnTripDirection('Pickup'), isFalse);
    });
  });
}

