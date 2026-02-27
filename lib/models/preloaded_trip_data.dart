import 'master_trip.dart';
import '../api/services/bus_service.dart';

/// Preloaded Trip Data Model
/// Holds all essential data for a trip to enable instant navigation
/// without loading delays between screens
class PreloadedTripData {
  final MasterTrip masterTrip;
  final List<TripStudent> students;
  final Bus? vehicle;
  final String? routeId;
  final bool isComplete;

  PreloadedTripData({
    required this.masterTrip,
    this.students = const [],
    this.vehicle,
    this.routeId,
    this.isComplete = false,
  });

  /// Check if all essential data is loaded
  bool get hasStudents => students.isNotEmpty;
  bool get hasVehicle => vehicle != null;
  bool get isReady => hasStudents && hasVehicle;

  /// Get counts for UI display
  int get totalStudents => students.length;
  int get pickedCount => students.where((s) => s.isStudentPicked).length;
  int get pendingCount => students.where((s) => !s.isStudentPicked && !s.isStudentDropped).length;

  /// Create a copy with updated fields
  PreloadedTripData copyWith({
    MasterTrip? masterTrip,
    List<TripStudent>? students,
    Bus? vehicle,
    String? routeId,
    bool? isComplete,
  }) {
    return PreloadedTripData(
      masterTrip: masterTrip ?? this.masterTrip,
      students: students ?? this.students,
      vehicle: vehicle ?? this.vehicle,
      routeId: routeId ?? this.routeId,
      isComplete: isComplete ?? this.isComplete,
    );
  }

  factory PreloadedTripData.fromJson(Map<String, dynamic> json) {
    return PreloadedTripData(
      masterTrip: MasterTrip.fromJson(json['masterTrip']),
      students: (json['students'] as List? ?? [])
          .map((s) => TripStudent.fromJson(s))
          .toList(),
      vehicle: json['vehicle'] != null ? Bus.fromJson(json['vehicle']) : null,
      routeId: json['routeId'],
      isComplete: json['isComplete'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'masterTrip': masterTrip.toJson(),
      'students': students.map((s) => s.toJson()).toList(),
      'vehicle': vehicle?.toJson(),
      'routeId': routeId,
      'isComplete': isComplete,
    };
  }
}

/// Trip Data Loading State
/// Used to track loading progress when fetching trip data
class TripDataLoadingState {
  final bool isLoading;
  final String? error;
  final double progress; // 0.0 to 1.0
  final String currentStep; // Description of current loading step

  const TripDataLoadingState({
    this.isLoading = false,
    this.error,
    this.progress = 0.0,
    this.currentStep = '',
  });

  TripDataLoadingState copyWith({
    bool? isLoading,
    String? error,
    double? progress,
    String? currentStep,
  }) {
    return TripDataLoadingState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      progress: progress ?? this.progress,
      currentStep: currentStep ?? this.currentStep,
    );
  }
}
