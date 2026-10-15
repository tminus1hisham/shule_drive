import '../models/master_trip.dart';

/// How long after its scheduled time a master trip is still treated as the one
/// coming up, instead of being skipped in favour of the trip after it.
const Duration nextTripGrace = Duration(minutes: 30);

/// A master trip paired with the concrete date/time it is next due.
///
/// Master trips only carry a time of day ("07:30 AM"), so the date is derived
/// from the moment the selection was made.
class ScheduledMasterTrip {
  const ScheduledMasterTrip({required this.trip, required this.scheduledAt});

  final MasterTrip trip;
  final DateTime scheduledAt;

  bool isToday(DateTime now) =>
      scheduledAt.year == now.year &&
      scheduledAt.month == now.month &&
      scheduledAt.day == now.day;
}

/// Parse a master trip's `tripTime` ("07:30 AM", "7:30", "17:45:00") into a
/// [DateTime] anchored to the day of [now]. Returns null when unparsable.
DateTime? parseTripTimeOfDay(String tripTime, {DateTime? now}) {
  final cleaned = tripTime.trim().toUpperCase();
  if (cleaned.isEmpty) return null;

  final isPm = cleaned.contains('PM');
  final isAm = cleaned.contains('AM');

  final parts = cleaned.replaceAll(RegExp(r'[^0-9:]'), '').split(':');
  final hour = parts.isEmpty ? null : int.tryParse(parts[0]);
  final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;

  if (hour == null || hour < 0 || hour > 23) return null;
  if (minute < 0 || minute > 59) return null;

  var normalizedHour = hour;
  if (isPm && hour != 12) normalizedHour += 12;
  if (isAm && hour == 12) normalizedHour = 0;
  if (normalizedHour > 23) return null;

  final anchor = now ?? DateTime.now();
  return DateTime(
    anchor.year,
    anchor.month,
    anchor.day,
    normalizedHour,
    minute,
  );
}

/// Pick the trip that is actually next relative to [now].
///
/// The soonest trip that has not started yet wins; a trip that started less
/// than [grace] ago still counts, so a driver running a few minutes late is not
/// pushed on to the following trip. When every trip for today has passed, the
/// earliest trip rolls over to tomorrow.
ScheduledMasterTrip? selectNextMasterTrip(
  List<MasterTrip> trips, {
  DateTime? now,
  Duration grace = nextTripGrace,
}) {
  final current = now ?? DateTime.now();

  // Prefer trips the driver can actually run, matching how trips are picked in
  // the selection screen; fall back to all of them when none are flagged.
  var candidates = trips.where((t) => t.isTripActive).toList();
  if (candidates.isEmpty) candidates = trips;

  final scheduled = <ScheduledMasterTrip>[];
  for (final trip in candidates) {
    final at = parseTripTimeOfDay(trip.tripTime, now: current);
    if (at != null) {
      scheduled.add(ScheduledMasterTrip(trip: trip, scheduledAt: at));
    }
  }
  if (scheduled.isEmpty) return null;

  scheduled.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

  final cutoff = current.subtract(grace);
  for (final candidate in scheduled) {
    if (!candidate.scheduledAt.isBefore(cutoff)) return candidate;
  }

  // Today is done - the first trip of tomorrow is up next.
  final first = scheduled.first;
  final at = first.scheduledAt;
  return ScheduledMasterTrip(
    trip: first.trip,
    scheduledAt: DateTime(at.year, at.month, at.day + 1, at.hour, at.minute),
  );
}

/// [trips] minus those already run on [now]'s day. Each master trip runs at
/// most once a day, so a run that started today (finished or still going)
/// means its "starts in 5 min" reminder is stale. [runs] are (masterTripId,
/// startTime) pairs from trip history; server times may be UTC.
List<MasterTrip> withoutTripsRunToday(
  List<MasterTrip> trips,
  Iterable<({int? masterTripId, DateTime startTime})> runs, {
  DateTime? now,
}) {
  final today = (now ?? DateTime.now()).toLocal();
  final ranToday = {
    for (final run in runs)
      if (run.masterTripId != null &&
          _sameDay(run.startTime.toLocal(), today))
        run.masterTripId,
  };
  return trips.where((t) => !ranToday.contains(t.id)).toList();
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Short human label for when a scheduled trip starts, e.g. "in 25 min",
/// "in 2h 10m", "Starting now" or "Tomorrow".
String formatNextTripCountdown(ScheduledMasterTrip next, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final diff = next.scheduledAt.difference(current);

  if (!next.isToday(current)) return 'Tomorrow';
  if (diff.inMinutes <= 0) return 'Starting now';
  if (diff.inMinutes < 60) return 'in ${diff.inMinutes} min';

  final minutes = diff.inMinutes.remainder(60);
  return minutes == 0
      ? 'in ${diff.inHours}h'
      : 'in ${diff.inHours}h ${minutes}m';
}
