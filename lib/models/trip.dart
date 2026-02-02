enum TripStatus { upcoming, ongoing, completed, cancelled }
enum StopStatus { pending, picked, dropped, delay, completed }

class TripStop {
  final String name;
  final String address;
  final String time;
  final StopStatus status;

  TripStop({
    required this.name,
    required this.address,
    required this.time,
    required this.status,
  });
}

class Trip {
  final String id;
  final String routeName;
  final String date;
  final String time;
  final double fare;
  final double distance;
  final TripStatus status;
  final List<TripStop> stops;

  Trip({
    required this.id,
    required this.routeName,
    required this.date,
    required this.time,
    required this.fare,
    required this.distance,
    required this.status,
    required this.stops,
  });
}
