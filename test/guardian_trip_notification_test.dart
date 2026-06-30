import 'package:flutter_test/flutter_test.dart';
import 'package:shule_drive/services/guardian_trip_notification_service.dart';

void main() {
  group('GuardianTripNotificationService topic', () {
    test('normalizes phone to digits so driver and guardian agree', () {
      expect(
        GuardianTripNotificationService.topicForPhone('+254 712 345 678'),
        'shuledrive/guardians/254712345678/student-status',
      );
      // Same number, different formatting -> same topic.
      expect(
        GuardianTripNotificationService.topicForPhone('254-712-345-678'),
        GuardianTripNotificationService.topicForPhone('+254 712 345 678'),
      );
    });
  });

  group('GuardianTripNotificationService payload', () {
    test('carries the fields the guardian listener reads', () {
      final payload = GuardianTripNotificationService.buildPayload(
        studentId: '42',
        studentName: 'Levi Ackerman',
        status: 'picked',
        tripId: 'trip-1',
        vehicleNumber: 'KDA 123A',
      );

      expect(payload['event'], 'student_status');
      expect(payload['studentId'], '42');
      expect(payload['studentName'], 'Levi Ackerman');
      expect(payload['status'], 'picked');
      expect(payload['tripId'], 'trip-1');
      expect(payload['vehicleNumber'], 'KDA 123A');
      expect(payload['timestamp'], isA<String>());
    });
  });
}
