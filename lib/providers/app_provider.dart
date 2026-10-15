import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api.dart' as api;
import '../models/student.dart';
import '../models/trip.dart';
import '../models/child.dart';
import '../services/guardian_trip_notification_service.dart';
import '../theme/app_colors.dart';

class AppProvider extends ChangeNotifier with WidgetsBindingObserver {
  // API Services
  final api.RouteService _routeService = api.RouteService();
  final api.StudentService _studentService = api.StudentService();
  final api.BusService _busService = api.BusService();

  // Loading states
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // Current school ID for school-scoped data
  String? _currentSchoolId;
  String? get currentSchoolId => _currentSchoolId;

  /// Set current school ID (called after login or when driver changes school)
  void setCurrentSchoolId(String? schoolId) {
    _currentSchoolId = schoolId;
    if (kDebugMode) {
      print('🏫 AppProvider: School ID set to $schoolId');
    }
    notifyListeners();
  }

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // Theme mode: null = system default, true = dark, false = light
  bool? _manualDarkMode;

  // Legacy color names, kept for older screens; values come from the design
  // system palette so every screen shares one brand.
  static const Color primaryGreen = AppPalette.emerald;
  static const Color lightBackground = AppPalette.bgLight;
  static const Color darkBackground = AppPalette.bgDark;
  static const Color cardLight = AppPalette.surfaceLight;
  static const Color cardDark = AppPalette.surfaceDark;
  static const Color textPrimary = AppPalette.textPrimaryLight;
  static const Color textSecondary = AppPalette.textSecondaryLight;
  static const Color accentGreen = AppPalette.emeraldSoftLight;

  AppProvider() {
    WidgetsBinding.instance.addObserver(this);
    // Warm the persisted preferences so the UI shows the saved values as soon
    // as possible; screens that need a guaranteed value await
    // ensurePreferencesLoaded().
    ensurePreferencesLoaded();
    _alerts.unreadAlerts.addListener(_syncAlertBadge);
  }

  final _alerts = GuardianTripNotificationService();
  void _syncAlertBadge() => setUnreadAlertCount(_alerts.unreadAlerts.value);

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _alerts.unreadAlerts.removeListener(_syncAlertBadge);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    // Notify listeners when system brightness changes
    if (_manualDarkMode == null) {
      notifyListeners();
    }
  }

  /// Returns true if dark mode is active (either manual or system)
  bool get isDarkMode {
    if (_manualDarkMode != null) {
      return _manualDarkMode!;
    }
    // Use system default
    return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark;
  }

  /// Returns true if manually set to dark mode
  bool? get manualDarkMode => _manualDarkMode;

  /// Returns the theme mode for MaterialApp
  ThemeMode get themeMode {
    if (_manualDarkMode == null) {
      return ThemeMode.system;
    }
    return _manualDarkMode! ? ThemeMode.dark : ThemeMode.light;
  }

  /// Toggle between light and dark (overrides system)
  void toggleTheme() {
    _manualDarkMode = !isDarkMode;
    notifyListeners();
  }

  /// Reset to system default
  void useSystemTheme() {
    _manualDarkMode = null;
    notifyListeners();
  }

  // ==========================================================================
  // USER PREFERENCES
  // ==========================================================================

  static const String _autoloadTripsKey = 'autoload_scheduled_trips';

  /// When enabled, the app fetches the driver's scheduled trips on login and
  /// takes them straight to trip selection. When disabled the driver lands on
  /// the dashboard and opens their scheduled trips themselves.
  bool _autoloadTrips = true;
  bool get autoloadTrips => _autoloadTrips;

  Future<void>? _preferencesLoad;

  /// Loads persisted preferences once. Safe to await from anywhere — repeat
  /// calls share the same in-flight future.
  Future<void> ensurePreferencesLoaded() {
    return _preferencesLoad ??= _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _autoloadTrips = prefs.getBool(_autoloadTripsKey) ?? true;
      if (kDebugMode) {
        print('⚙️ AppProvider: autoload trips = $_autoloadTrips');
      }
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ AppProvider: Failed to load preferences - $e');
      }
    }
  }

  /// Persist the autoload preference.
  Future<void> setAutoloadTrips(bool value) async {
    if (_autoloadTrips == value) return;
    _autoloadTrips = value;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_autoloadTripsKey, value);
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ AppProvider: Failed to save autoload preference - $e');
      }
    }
  }

  Color get backgroundColor => isDarkMode ? darkBackground : lightBackground;
  Color get cardColor => isDarkMode ? cardDark : cardLight;
  Color get textColor =>
      isDarkMode ? AppPalette.textPrimaryDark : AppPalette.textPrimaryLight;
  Color get textMutedColor =>
      isDarkMode ? AppPalette.textSecondaryDark : AppPalette.textSecondaryLight;

  // ==========================================================================
  // API INTEGRATION - ROUTES
  // ==========================================================================

  List<api.BusRoute> _routes = [];
  List<api.BusRoute> get routes => _routes;

  /// Fetch all routes from API
  Future<void> fetchRoutes() async {
    _setLoading(true);
    _clearError();

    try {
      if (kDebugMode) {
        print('📍 AppProvider: Fetching all routes...');
      }
      _routes = await _routeService.getAllRoutes();
      if (kDebugMode) {
        print('✅ AppProvider: Fetched ${_routes.length} routes');
      }
      notifyListeners();
    } on api.NotFoundException {
      // Endpoint not available - show empty list
      if (kDebugMode) {
        print('⚠️ AppProvider: Routes endpoint not found (404)');
      }
      _routes = [];
      notifyListeners();
    } on api.ApiException catch (e) {
      if (kDebugMode) {
        print('❌ AppProvider: API Exception - ${e.message}');
      }
      _setError(e.message);
    } catch (e) {
      if (kDebugMode) {
        print('❌ AppProvider: Error fetching routes - $e');
      }
      _setError('Failed to fetch routes');
    } finally {
      _setLoading(false);
    }
  }

  /// Fetch routes by current user
  Future<void> fetchRoutesByUser() async {
    _setLoading(true);
    _clearError();

    try {
      _routes = await _routeService.getRoutesByUser();
      notifyListeners();
    } on api.NotFoundException {
      // Endpoint not available - show empty list
      _routes = [];
      notifyListeners();
    } on api.ApiException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError('Failed to fetch routes');
    } finally {
      _setLoading(false);
    }
  }

  /// Create a new route
  Future<api.BusRoute?> createRoute({
    required String name,
    required String description,
    required List<api.RouteStop> stops,
    String? schoolId,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final route = await _routeService.createRoute(
        name: name,
        description: description,
        stops: stops,
        schoolId: schoolId,
      );
      _routes.add(route);
      notifyListeners();
      return route;
    } on api.ApiException catch (e) {
      _setError(e.message);
      return null;
    } catch (e) {
      _setError('Failed to create route');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Update a route
  Future<api.BusRoute?> updateRoute({
    required String routeId,
    String? name,
    String? description,
    List<api.RouteStop>? stops,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final updatedRoute = await _routeService.updateRoute(
        routeId: routeId,
        name: name,
        description: description,
        stops: stops,
      );

      final index = _routes.indexWhere((r) => r.id == routeId);
      if (index != -1) {
        _routes[index] = updatedRoute;
        notifyListeners();
      }
      return updatedRoute;
    } on api.ApiException catch (e) {
      _setError(e.message);
      return null;
    } catch (e) {
      _setError('Failed to update route');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Delete a route
  Future<bool> deleteRoute(String routeId) async {
    _setLoading(true);
    _clearError();

    try {
      await _routeService.deleteRoute(routeId);
      _routes.removeWhere((r) => r.id == routeId);
      notifyListeners();
      return true;
    } on api.ApiException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Failed to delete route');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ==========================================================================
  // API INTEGRATION - BUSES/VEHICLES
  // ==========================================================================

  List<api.Bus> _buses = [];
  List<api.Bus> get buses => _buses;

  /// Fetch all buses from API with cache-first pattern
  /// Shows cached data immediately, then refreshes in background
  Future<void> fetchBuses({bool useCache = true}) async {
    _setLoading(true);
    _clearError();

    try {
      if (kDebugMode) {
        print('🚌 AppProvider: Fetching buses (cache-first: $useCache)...');
      }

      if (useCache) {
        // Use cache-first pattern
        final buses = await _busService.getAllBusesCached(
          onRefresh: (freshBuses) {
            // Background refresh callback
            if (kDebugMode) {
              print(
                '🔄 AppProvider: Background refresh with ${freshBuses.length} buses',
              );
            }
            _buses = freshBuses;
            notifyListeners();
          },
        );
        _buses = buses;
        notifyListeners();
      } else {
        // Direct API call (no cache)
        _buses = await _busService.getAllBuses();
        notifyListeners();
      }

      if (kDebugMode) {
        print('✅ AppProvider: Fetched ${_buses.length} buses');
      }
    } on api.NotFoundException {
      if (kDebugMode) {
        print('⚠️ AppProvider: Buses endpoint not found (404)');
      }
      _buses = [];
      notifyListeners();
    } on api.ApiException catch (e) {
      if (kDebugMode) {
        print('❌ AppProvider: API Exception - ${e.message}');
      }
      _setError(e.message);
    } catch (e) {
      if (kDebugMode) {
        print('❌ AppProvider: Error fetching buses - $e');
      }
      _setError('Failed to fetch buses');
    } finally {
      _setLoading(false);
    }
  }

  /// Fetch buses by current user
  Future<void> fetchBusesByUser() async {
    _setLoading(true);
    _clearError();

    try {
      _buses = await _busService.getBusesByUser();
      notifyListeners();
    } on api.NotFoundException {
      // Endpoint not available - show empty list
      _buses = [];
      notifyListeners();
    } on api.ApiException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError('Failed to fetch buses');
    } finally {
      _setLoading(false);
    }
  }

  /// Fetch active buses
  Future<void> fetchActiveBuses() async {
    _setLoading(true);
    _clearError();

    try {
      _buses = await _busService.getActiveBuses();
      notifyListeners();
    } on api.NotFoundException {
      // Endpoint not available - show empty list
      _buses = [];
      notifyListeners();
    } on api.ApiException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError('Failed to fetch buses');
    } finally {
      _setLoading(false);
    }
  }

  // ==========================================================================
  // SCHOOL-SCOPED DATA FETCHING (for drivers)
  // ==========================================================================

  /// Fetch routes by school ID
  Future<void> fetchRoutesBySchool(
    String schoolId, {
    String? schoolName,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      if (kDebugMode) {
        print(
          '📍 AppProvider: Fetching routes for school $schoolId (name: $schoolName)...',
        );
      }
      _routes = await _routeService.getRoutesBySchool(
        schoolId,
        schoolName: schoolName,
      );
      _currentSchoolId = schoolId;
      if (kDebugMode) {
        print(
          '✅ AppProvider: Fetched ${_routes.length} routes for school $schoolId',
        );
      }
      notifyListeners();
    } on api.NotFoundException {
      if (kDebugMode) {
        print('⚠️ AppProvider: Routes endpoint not found (404)');
      }
      _routes = [];
      notifyListeners();
    } on api.ApiException catch (e) {
      if (kDebugMode) {
        print('❌ AppProvider: API Exception - ${e.message}');
      }
      _setError(e.message);
    } catch (e) {
      if (kDebugMode) {
        print('❌ AppProvider: Error fetching routes - $e');
      }
      _setError('Failed to fetch routes');
    } finally {
      _setLoading(false);
    }
  }

  /// Fetch buses (vehicles) by school ID
  Future<void> fetchBusesBySchool(String schoolId) async {
    _setLoading(true);
    _clearError();

    try {
      if (kDebugMode) {
        print('🚌 AppProvider: Fetching buses for school $schoolId...');
      }
      _buses = await _busService.getBusesBySchool(schoolId);
      _currentSchoolId = schoolId;
      if (kDebugMode) {
        print(
          '✅ AppProvider: Fetched ${_buses.length} buses for school $schoolId',
        );
      }
      notifyListeners();
    } on api.NotFoundException {
      if (kDebugMode) {
        print('⚠️ AppProvider: Buses endpoint not found (404)');
      }
      _buses = [];
      notifyListeners();
    } on api.ApiException catch (e) {
      if (kDebugMode) {
        print('❌ AppProvider: API Exception - ${e.message}');
      }
      _setError(e.message);
    } catch (e) {
      if (kDebugMode) {
        print('❌ AppProvider: Error fetching buses - $e');
      }
      _setError('Failed to fetch buses');
    } finally {
      _setLoading(false);
    }
  }

  /// Fetch students by school ID
  Future<void> fetchStudentsBySchool(String schoolId) async {
    _setLoading(true);
    _clearError();

    try {
      if (kDebugMode) {
        print('👨‍🎓 AppProvider: Fetching students for school $schoolId...');
      }
      _apiStudents = await _studentService.getStudentsBySchool(schoolId);
      _currentSchoolId = schoolId;
      if (kDebugMode) {
        print(
          '✅ AppProvider: Fetched ${_apiStudents.length} students for school $schoolId',
        );
      }
      notifyListeners();
    } on api.NotFoundException {
      if (kDebugMode) {
        print('⚠️ AppProvider: Students endpoint not found (404)');
      }
      _apiStudents = [];
      notifyListeners();
    } on api.ApiException catch (e) {
      if (kDebugMode) {
        print('❌ AppProvider: API Exception - ${e.message}');
      }
      _setError(e.message);
    } catch (e) {
      if (kDebugMode) {
        print('❌ AppProvider: Error fetching students - $e');
      }
      _setError('Failed to fetch students');
    } finally {
      _setLoading(false);
    }
  }

  /// Fetch all school-scoped data at once (routes, buses, students)
  Future<void> fetchAllSchoolData(String schoolId, {String? schoolName}) async {
    _setLoading(true);
    _clearError();

    try {
      if (kDebugMode) {
        print(
          '🏫 AppProvider: Fetching all data for school $schoolId (name: $schoolName)...',
        );
      }

      // Fetch all data in parallel
      final results = await Future.wait([
        _routeService.getRoutesBySchool(schoolId, schoolName: schoolName),
        _busService.getBusesBySchool(schoolId),
        _studentService.getStudentsBySchool(schoolId),
      ]);

      _routes = results[0] as List<api.BusRoute>;
      _buses = results[1] as List<api.Bus>;
      _apiStudents = results[2] as List<api.Student>;
      _currentSchoolId = schoolId;

      if (kDebugMode) {
        print('✅ AppProvider: School data loaded:');
        print('   📍 Routes: ${_routes.length}');
        print('   🚌 Buses: ${_buses.length}');
        print('   👨‍🎓 Students: ${_apiStudents.length}');
      }

      notifyListeners();
    } on api.ApiException catch (e) {
      if (kDebugMode) {
        print('❌ AppProvider: API Exception - ${e.message}');
      }
      _setError(e.message);
    } catch (e) {
      if (kDebugMode) {
        print('❌ AppProvider: Error fetching school data - $e');
      }
      _setError('Failed to fetch school data');
    } finally {
      _setLoading(false);
    }
  }

  // ==========================================================================
  // API INTEGRATION - CHILDREN/STUDENTS
  // ==========================================================================

  List<api.Student> _apiStudents = [];
  List<api.Student> get apiStudents => _apiStudents;

  // For UI compatibility - converts API students to model students
  List<Student> get studentsList => _apiStudents
      .map(
        (s) => Student(
          id: s.id,
          name: s.name,
          className: s.className,
          avatar: s.photo ?? 'https://i.pravatar.cc/150?img=1',
          status: StudentStatus.pending,
        ),
      )
      .toList();

  /// Fetch all students from API
  Future<void> fetchStudents() async {
    _setLoading(true);
    _clearError();

    try {
      _apiStudents = await _studentService.getAllStudents();
      notifyListeners();
    } on api.NotFoundException {
      // Endpoint not available - show empty list
      _apiStudents = [];
      notifyListeners();
    } on api.ApiException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError('Failed to fetch students');
    } finally {
      _setLoading(false);
    }
  }

  /// Fetch guardian's students
  Future<void> fetchGuardianStudents() async {
    _setLoading(true);
    _clearError();

    try {
      _apiStudents = await _studentService.getGuardianStudents();
      notifyListeners();
    } on api.NotFoundException {
      // Endpoint not available - show empty list
      _apiStudents = [];
      notifyListeners();
    } on api.ApiException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError('Failed to fetch students');
    } finally {
      _setLoading(false);
    }
  }

  /// Add a new child/student via guardian API
  /// Required: fullname, schoolname, pickupLocation (route)
  Future<api.Student?> addChildAPI({
    required String fullname,
    String? schoolname,
    String? classname,
    String? route,
    String? pickupLocation,
    String? photo,
    String? guardianPhoneNumber,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final created = await _studentService.createStudent(
        fullname: fullname,
        schoolname: schoolname,
        classname: classname,
        route: route,
        pickupLocation: pickupLocation,
        photo: photo,
        guardianPhoneNumber: guardianPhoneNumber,
      );
      // The create reply rarely carries the record, so the guardian's list
      // is the truth: show what the server has, and find the new child's id.
      _apiStudents = await _studentService.getGuardianStudents();
      notifyListeners();
      if (created.id.isNotEmpty) return created;
      final name = fullname.trim().toLowerCase();
      return _apiStudents
              .where((s) => s.name.trim().toLowerCase() == name)
              .lastOrNull ??
          created;
    } on api.ApiException catch (e) {
      _setError(e.message);
      return null;
    } catch (e) {
      _setError('Failed to add child');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Update child/student
  Future<api.Student?> updateChildAPI({
    required String studentId,
    String? name,
    String? className,
    String? schoolId,
    String? photo,
    String? pickupLocation,
    String? dropoffLocation,
    String? emergencyContact,
    String? emergencyPhone,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final updatedStudent = await _studentService.updateStudent(
        studentId: studentId,
        name: name,
        className: className,
        schoolId: schoolId,
        photo: photo,
        pickupLocation: pickupLocation,
        dropoffLocation: dropoffLocation,
        emergencyContact: emergencyContact,
        emergencyPhone: emergencyPhone,
      );

      final index = _apiStudents.indexWhere((s) => s.id == studentId);
      if (index != -1) {
        _apiStudents[index] = updatedStudent;
        notifyListeners();
      }
      return updatedStudent;
    } on api.ApiException catch (e) {
      _setError(e.message);
      return null;
    } catch (e) {
      _setError('Failed to update child');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Delete child/student
  Future<bool> deleteChildAPI(String studentId) async {
    _setLoading(true);
    _clearError();

    try {
      await _studentService.deleteStudent(studentId);
      _apiStudents.removeWhere((s) => s.id == studentId);
      notifyListeners();
      return true;
    } on api.ApiException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Failed to delete child');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Upload and update student image
  Future<String?> uploadStudentImage({
    required String studentId,
    required String imagePath,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final imageUrl = await _studentService.updateStudentImage(
        studentId: studentId,
        imagePath: imagePath,
      );

      // Update local student data
      final index = _apiStudents.indexWhere((s) => s.id == studentId);
      if (index != -1) {
        final updatedStudent = api.Student(
          id: _apiStudents[index].id,
          name: _apiStudents[index].name,
          className: _apiStudents[index].className,
          photo: imageUrl,
          schoolId: _apiStudents[index].schoolId,
          schoolName: _apiStudents[index].schoolName,
          guardianId: _apiStudents[index].guardianId,
          guardianName: _apiStudents[index].guardianName,
          guardianPhone: _apiStudents[index].guardianPhone,
          pickupLocation: _apiStudents[index].pickupLocation,
          dropoffLocation: _apiStudents[index].dropoffLocation,
          emergencyContact: _apiStudents[index].emergencyContact,
          emergencyPhone: _apiStudents[index].emergencyPhone,
          isActive: _apiStudents[index].isActive,
          createdAt: _apiStudents[index].createdAt,
        );
        _apiStudents[index] = updatedStudent;
        notifyListeners();
      }

      return imageUrl;
    } on api.ApiException catch (e) {
      _setError(e.message);
      return null;
    } catch (e) {
      _setError('Failed to upload image');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // ==========================================================================
  // HELPER METHODS
  // ==========================================================================

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

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

  // Notification badge counts
  int _unreadAlertCount = 0;
  int get unreadAlertCount => _unreadAlertCount;

  void setUnreadAlertCount(int count) {
    _unreadAlertCount = count;
    notifyListeners();
  }

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
  int get completedTrips =>
      trips.where((t) => t.status == TripStatus.completed).length;
  double get totalDistance => trips.fold(0, (sum, t) => sum + t.distance);
}
