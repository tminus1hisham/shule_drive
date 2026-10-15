import 'package:flutter_test/flutter_test.dart';
import 'package:shule_drive/api/api_exceptions.dart';
import 'package:shule_drive/providers/trip_provider.dart';
import 'package:shule_drive/services/guardian_trip_notification_service.dart';

Map<String, dynamic> _alert(String phone, DateTime createdAt) => {
  'topic': GuardianTripNotificationService.topicForPhone(phone),
  'payload': {'studentId': phone},
  'phone': phone,
  'title': 't',
  'message': 'm $phone',
  'createdAt': createdAt.toUtc().toIso8601String(),
};

void main() {
  final now = DateTime(2026, 9, 25, 7, 30);

  test('pick all: every guardian gets MQTT and push, outbox empties', () async {
    final outbox = [_alert('254700000001', now), _alert('254700000002', now)];
    final published = <String>[];
    final pushed = <String>[];

    await TripProvider.deliverGuardianAlerts(
      outbox,
      mqttConnected: true,
      publish: (a) async => published.add(a['phone']),
      push: (a) async => pushed.add(a['phone']),
      now: now,
    );

    expect(published, ['254700000001', '254700000002']);
    expect(pushed, ['254700000001', '254700000002']);
    expect(outbox, isEmpty);
  });

  test('offline: alerts stay queued and retry only the failed channel', () async {
    final outbox = [_alert('254700000001', now), _alert('254700000002', now)];
    var pushCalls = 0;

    await TripProvider.deliverGuardianAlerts(
      outbox,
      mqttConnected: false,
      publish: (a) async => fail('must not publish while disconnected'),
      push: (a) async {
        pushCalls++;
        throw Exception('no network');
      },
      now: now,
    );
    expect(pushCalls, 1, reason: 'stop pushing after first failure');
    expect(outbox, hasLength(2));

    // Back online: MQTT delivers, push delivers, queue drains.
    final published = <String>[];
    await TripProvider.deliverGuardianAlerts(
      outbox,
      mqttConnected: true,
      publish: (a) async => published.add(a['phone']),
      push: (a) async {},
      now: now,
    );
    expect(published, hasLength(2));
    expect(outbox, isEmpty);
  });

  test('server rejection gives up on that push, not the next one', () async {
    final outbox = [_alert('254700000001', now), _alert('254700000002', now)];
    final pushed = <String>[];

    await TripProvider.deliverGuardianAlerts(
      outbox,
      mqttConnected: true,
      publish: (a) async {},
      push: (a) async {
        if (a['phone'] == '254700000001') {
          throw ApiException(message: 'no FCM token', statusCode: 500);
        }
        pushed.add(a['phone']);
      },
      now: now,
    );
    expect(pushed, ['254700000002']);
    expect(outbox, isEmpty, reason: 'rejected push must not be retried');
  });

  test('drops alerts older than the max age', () async {
    final stale = now.subtract(TripProvider.guardianAlertMaxAge * 2);
    final outbox = [_alert('254700000001', stale)];

    await TripProvider.deliverGuardianAlerts(
      outbox,
      mqttConnected: true,
      publish: (a) async => fail('stale alert must not be sent'),
      push: (a) async => fail('stale alert must not be sent'),
      now: now,
    );
    expect(outbox, isEmpty);
  });

  test('same alert text over MQTT and push shows once', () {
    final service = GuardianTripNotificationService();
    final body = GuardianTripNotificationService.describe(
      status: 'picked',
      studentName: 'Outbox Test Kid',
      vehicleNumber: 'KDA 1A',
    )!.body;
    expect(service.markSeen(body), isTrue);
    expect(service.markSeen(body), isFalse);
  });
}
