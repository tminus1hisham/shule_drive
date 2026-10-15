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

  group('alert history', () {
    final now = DateTime(2026, 10, 9, 19, 0);
    List<Map<String, dynamic>> add(
      List<Map<String, dynamic>> h,
      String body,
      DateTime at,
    ) => GuardianTripNotificationService.appendAlert(
      h,
      title: 't',
      body: body,
      now: at,
    );

    test('newest first, unread', () {
      final h = add(add([], 'A picked', now), 'A dropped', now);
      expect(h.map((a) => a['body']), ['A dropped', 'A picked']);
      expect(h.every((a) => a['read'] == false), isTrue);
    });

    test('a redelivered alert within 10 minutes is kept once', () {
      final h = add([], 'A picked', now);
      expect(add(h, 'A picked', now.add(const Duration(minutes: 3))), same(h));
      expect(add(h, 'A picked', now.add(const Duration(minutes: 11))), hasLength(2));
    });

    test('caps the log', () {
      var h = <Map<String, dynamic>>[];
      for (var i = 0; i < GuardianTripNotificationService.historyMax + 5; i++) {
        h = add(h, 'alert $i', now);
      }
      expect(h, hasLength(GuardianTripNotificationService.historyMax));
      expect(h.first['body'], 'alert ${GuardianTripNotificationService.historyMax + 4}');
    });
  });
}
