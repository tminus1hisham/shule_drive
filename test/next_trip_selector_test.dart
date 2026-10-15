import 'package:flutter_test/flutter_test.dart';
import 'package:shule_drive/models/master_trip.dart';
import 'package:shule_drive/utils/next_trip_selector.dart';

MasterTrip _trip({
  required int id,
  required String tripTime,
  String name = 'Trip',
  bool isActive = true,
}) {
  return MasterTrip(
    id: id,
    tripName: name,
    tripTime: tripTime,
    tripType: 'daily',
    tripDirection: 'pickup',
    route: 'Route A',
    createdBy: 'admin',
    schoolname: 'School',
    adminUserId: 'admin-1',
    isTripActive: isActive,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('parseTripTimeOfDay', () {
    final anchor = DateTime(2026, 7, 21, 9, 0);

    test('parses 12-hour times', () {
      expect(
        parseTripTimeOfDay('07:30 AM', now: anchor),
        DateTime(2026, 7, 21, 7, 30),
      );
      expect(
        parseTripTimeOfDay('4:15 PM', now: anchor),
        DateTime(2026, 7, 21, 16, 15),
      );
      expect(
        parseTripTimeOfDay('12:05 AM', now: anchor),
        DateTime(2026, 7, 21, 0, 5),
      );
      expect(
        parseTripTimeOfDay('12:05 PM', now: anchor),
        DateTime(2026, 7, 21, 12, 5),
      );
    });

    test('parses 24-hour and seconds-bearing times', () {
      expect(
        parseTripTimeOfDay('17:45', now: anchor),
        DateTime(2026, 7, 21, 17, 45),
      );
      expect(
        parseTripTimeOfDay('06:00:00', now: anchor),
        DateTime(2026, 7, 21, 6, 0),
      );
    });

    test('returns null for unusable values', () {
      expect(parseTripTimeOfDay('', now: anchor), isNull);
      expect(parseTripTimeOfDay('morning', now: anchor), isNull);
      expect(parseTripTimeOfDay('25:00', now: anchor), isNull);
    });
  });

  group('selectNextMasterTrip', () {
    final trips = [
      _trip(id: 1, tripTime: '06:30 AM', name: 'Morning pickup'),
      _trip(id: 3, tripTime: '04:30 PM', name: 'Evening dropoff'),
      _trip(id: 2, tripTime: '12:00 PM', name: 'Midday run'),
    ];

    test('picks the soonest upcoming trip, not the first in the list', () {
      final next = selectNextMasterTrip(
        trips,
        now: DateTime(2026, 7, 21, 9, 0),
      );

      expect(next!.trip.id, 2);
      expect(next.scheduledAt, DateTime(2026, 7, 21, 12, 0));
    });

    test('keeps a just-started trip within the grace window', () {
      final next = selectNextMasterTrip(
        trips,
        now: DateTime(2026, 7, 21, 12, 10),
      );

      expect(next!.trip.id, 2);
    });

    test('moves on once the grace window has passed', () {
      final next = selectNextMasterTrip(
        trips,
        now: DateTime(2026, 7, 21, 13, 0),
      );

      expect(next!.trip.id, 3);
    });

    test('rolls over to tomorrow when the day is done', () {
      final now = DateTime(2026, 7, 21, 22, 0);
      final next = selectNextMasterTrip(trips, now: now);

      expect(next!.trip.id, 1);
      expect(next.scheduledAt, DateTime(2026, 7, 22, 6, 30));
      expect(next.isToday(now), isFalse);
    });

    test('prefers active trips but falls back when none are active', () {
      final withInactive = [
        _trip(id: 1, tripTime: '10:00 AM', isActive: false),
        _trip(id: 2, tripTime: '02:00 PM', isActive: true),
      ];
      expect(
        selectNextMasterTrip(
          withInactive,
          now: DateTime(2026, 7, 21, 9, 0),
        )!.trip.id,
        2,
      );

      final allInactive = [
        _trip(id: 1, tripTime: '10:00 AM', isActive: false),
        _trip(id: 2, tripTime: '02:00 PM', isActive: false),
      ];
      expect(
        selectNextMasterTrip(
          allInactive,
          now: DateTime(2026, 7, 21, 9, 0),
        )!.trip.id,
        1,
      );
    });

    test('returns null when there is nothing schedulable', () {
      expect(selectNextMasterTrip([], now: DateTime(2026, 7, 21)), isNull);
      expect(
        selectNextMasterTrip([
          _trip(id: 1, tripTime: 'anytime'),
        ], now: DateTime(2026, 7, 21)),
        isNull,
      );
    });
  });

  group('formatNextTripCountdown', () {
    final now = DateTime(2026, 7, 21, 9, 0);

    ScheduledMasterTrip at(DateTime when) => ScheduledMasterTrip(
      trip: _trip(id: 1, tripTime: '—'),
      scheduledAt: when,
    );

    test('describes the wait ahead', () {
      expect(
        formatNextTripCountdown(at(DateTime(2026, 7, 21, 9, 25)), now: now),
        'in 25 min',
      );
      expect(
        formatNextTripCountdown(at(DateTime(2026, 7, 21, 11, 10)), now: now),
        'in 2h 10m',
      );
      expect(
        formatNextTripCountdown(at(DateTime(2026, 7, 21, 11, 0)), now: now),
        'in 2h',
      );
      expect(
        formatNextTripCountdown(at(DateTime(2026, 7, 21, 8, 55)), now: now),
        'Starting now',
      );
      expect(
        formatNextTripCountdown(at(DateTime(2026, 7, 22, 6, 30)), now: now),
        'Tomorrow',
      );
    });
  });

  group('withoutTripsRunToday', () {
    final now = DateTime(2026, 10, 9, 19, 2);
    final trips = [
      _trip(id: 1, tripTime: '06:00 PM'),
      _trip(id: 2, tripTime: '07:03 PM'),
      _trip(id: 3, tripTime: '08:00 PM'),
    ];

    test('drops trips that already ran (or are running) today', () {
      final left = withoutTripsRunToday(trips, [
        (masterTripId: 2, startTime: DateTime(2026, 10, 9, 17, 57)),
      ], now: now);
      expect(left.map((t) => t.id), [1, 3]);
    });

    test("keeps trips whose only runs were on other days", () {
      final left = withoutTripsRunToday(trips, [
        (masterTripId: 2, startTime: DateTime(2026, 10, 8, 19, 5)),
        (masterTripId: null, startTime: DateTime(2026, 10, 9, 8)),
      ], now: now);
      expect(left.map((t) => t.id), [1, 2, 3]);
    });
  });
}
