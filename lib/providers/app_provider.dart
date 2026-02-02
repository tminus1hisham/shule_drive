import 'package:flutter/material.dart';
import '../models/student.dart';
import '../models/trip.dart';
import '../models/child.dart';

class AppProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  // Theme colors
  static const Color primaryGreen = Color(0xFF6B9B5B);
  static const Color lightBackground = Color(0xFFF5F5F0);
  static const Color darkBackground = Color(0xFF121212);
  static const Color cardLight = Colors.white;
  static const Color cardDark = Color(0xFF1E1E1E);
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF666666);
  static const Color accentGreen = Color(0xFFE8F5E9);

  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  Color get backgroundColor => _isDarkMode ? darkBackground : lightBackground;
  Color get cardColor => _isDarkMode ? cardDark : cardLight;
  Color get textColor => _isDarkMode ? Colors.white : textPrimary;
  Color get textMutedColor => _isDarkMode ? Colors.white70 : textSecondary;

  // User data
  Map<String, dynamic> userData = {
    'name': 'James Kadere',
    'phone': '+254 701 234 567',
    'email': 'jameskadere@yahoo.co.ke',
    'role': 'Attendant',
    'avatar': 'https://i.pravatar.cc/150?img=11',
  };

  // Students data
  List<Student> students = [
    Student(
      id: '1',
      name: 'Mary Mwasuga',
      className: 'Class 4 West',
      avatar: 'https://i.pravatar.cc/150?img=5',
      status: StudentStatus.pending,
    ),
    Student(
      id: '2',
      name: 'John Mwasuga',
      className: 'Class 4 West',
      avatar: 'https://i.pravatar.cc/150?img=3',
      status: StudentStatus.pending,
    ),
    Student(
      id: '3',
      name: 'Sarah Mwasuga',
      className: 'Class 4 West',
      avatar: 'https://i.pravatar.cc/150?img=9',
      status: StudentStatus.picked,
    ),
    Student(
      id: '4',
      name: 'Peter Mwasuga',
      className: 'Class 4 West',
      avatar: 'https://i.pravatar.cc/150?img=12',
      status: StudentStatus.absent,
    ),
    Student(
      id: '5',
      name: 'Lucy Mwasuga',
      className: 'Class 4 West',
      avatar: 'https://i.pravatar.cc/150?img=8',
      status: StudentStatus.pending,
    ),
  ];

  // Trips data
  List<Trip> trips = [
    Trip(
      id: '1',
      routeName: 'Westlands - Kilimani Route',
      date: 'May 12, 2025',
      time: '8:30 AM - 9:10 AM',
      fare: 120.0,
      distance: 22.4,
      status: TripStatus.completed,
      stops: [
        TripStop(
          name: 'Step 1: Amina Mohammed',
          address: 'Museum Hill, Nairobi',
          time: '12 June 2025, 10:42 AM',
          status: StopStatus.picked,
        ),
        TripStop(
          name: 'Short Delay - Traffic',
          address: 'Haille Selassie Avenue',
          time: '12 June 2025, 10:56 AM',
          status: StopStatus.delay,
        ),
        TripStop(
          name: 'Step 2: Glory Mutiso',
          address: 'Museum Hill, Nairobi',
          time: '12 June 2025, 11:04 AM',
          status: StopStatus.picked,
        ),
        TripStop(
          name: 'Step 3: James Amani Primary',
          address: 'Museum Hill, Nairobi',
          time: '12 June 2025, 11:15 AM',
          status: StopStatus.picked,
        ),
        TripStop(
          name: 'All Students Dropped Off - Ozone Valley Day School',
          address: 'Kilimani, Nairobi',
          time: '12 June 2025, 11:42 AM',
          status: StopStatus.completed,
        ),
      ],
    ),
    Trip(
      id: '2',
      routeName: 'Westlands - Kilimani Route',
      date: 'May 12, 2025',
      time: '6:30 AM - 7:10 AM',
      fare: 120.0,
      distance: 22.4,
      status: TripStatus.completed,
      stops: [],
    ),
    Trip(
      id: '3',
      routeName: 'Westlands - Kilimani Route',
      date: 'May 12, 2025',
      time: '6:30 AM - 7:10 AM',
      fare: 120.0,
      distance: 22.4,
      status: TripStatus.completed,
      stops: [],
    ),
    Trip(
      id: '4',
      routeName: 'Westlands - Kilimani Route',
      date: 'May 12, 2025',
      time: '6:30 AM - 7:10 AM',
      fare: 120.0,
      distance: 22.4,
      status: TripStatus.completed,
      stops: [],
    ),
  ];

  // Children data
  List<Child> children = [
    Child(
      id: '1',
      name: 'Mary Mwasuga',
      school: 'Ozone Valley Day School',
      className: 'Class 4 West',
      avatar: 'https://i.pravatar.cc/150?img=5',
      parentName: 'John Mwasuga',
      parentPhone: '+254 712 345 678',
    ),
    Child(
      id: '2',
      name: 'Peter Mwasuga',
      school: 'Ozone Valley Day School',
      className: 'Class 4 West',
      avatar: 'https://i.pravatar.cc/150?img=12',
      parentName: 'John Mwasuga',
      parentPhone: '+254 712 345 678',
    ),
  ];

  // Trip status
  bool _hasActiveTrip = false;
  bool get hasActiveTrip => _hasActiveTrip;

  int _pickedStudentsCount = 5;
  int get pickedStudentsCount => _pickedStudentsCount;

  final int _totalStudentsCount = 18;
  int get totalStudentsCount => _totalStudentsCount;

  void startTrip() {
    _hasActiveTrip = true;
    notifyListeners();
  }

  void completeTrip() {
    _hasActiveTrip = false;
    notifyListeners();
  }

  void updateStudentStatus(String studentId, StudentStatus status) {
    final student = students.firstWhere((s) => s.id == studentId);
    student.status = status;
    if (status == StudentStatus.picked) {
      _pickedStudentsCount++;
    } else if (status == StudentStatus.pending &&
        student.status == StudentStatus.picked) {
      _pickedStudentsCount--;
    }
    notifyListeners();
  }

  void updateUserData(Map<String, dynamic> newData) {
    userData = {...userData, ...newData};
    notifyListeners();
  }

  // Quick stats
  int get totalTrips => trips.length;
  int get completedTrips => trips.where((t) => t.status == TripStatus.completed).length;
  double get totalDistance => trips.fold(0, (sum, t) => sum + t.distance);
}
