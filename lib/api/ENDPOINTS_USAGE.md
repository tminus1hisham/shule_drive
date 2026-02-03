# API Endpoints Usage Guide

## Quick Start

```dart
import 'api/api.dart';

// Using endpoints
final url = Endpoints.baseUrl + Endpoints.trips;

// With path parameters
final tripUrl = Endpoints.tripDetails('123'); // /trips/123

// With query parameters
final pagedUrl = Endpoints.buildUrl(
  Endpoints.trips,
  queryParams: QueryParams.pagination(page: 1, limit: 10),
);
// Result: /trips?page=1&limit=10
```

## Available Endpoint Categories

### Auth
```dart
Endpoints.login                    // POST /auth/login
Endpoints.verifyOtp               // POST /auth/verify-otp
Endpoints.refreshToken            // POST /auth/refresh
Endpoints.logout                  // POST /auth/logout
Endpoints.changePassword          // POST /auth/change-password
```

### Trips
```dart
Endpoints.trips                          // GET /trips
Endpoints.tripDetails('123')             // GET /trips/123
Endpoints.startTrip                      // POST /trips/start
Endpoints.endTrip('123')                 // POST /trips/123/end
Endpoints.activeTrip                     // GET /trips/active
Endpoints.tripStudents('123')            // GET /trips/123/students
Endpoints.updateStudentStatus(tripId: '123', studentId: '456')  // PATCH /trips/123/students/456/status
```

### Users
```dart
Endpoints.userProfile              // GET /user/profile
Endpoints.updateProfile            // PUT /user/profile
Endpoints.uploadAvatar             // POST /user/avatar
```

### Buses
```dart
Endpoints.buses                    // GET /buses
Endpoints.busDetails('123')        // GET /buses/123
Endpoints.busLocation('123')       // GET /buses/123/location
```

### Routes
```dart
Endpoints.routes                   // GET /routes
Endpoints.routeDetails('123')      // GET /routes/123
Endpoints.routeStops('123')        // GET /routes/123/stops
```

### Schools
```dart
Endpoints.schools                  // GET /schools
Endpoints.schoolDetails('123')     // GET /schools/123
Endpoints.schoolStudents('123')    // GET /schools/123/students
```

### Students
```dart
Endpoints.students                 // GET /students
Endpoints.studentDetails('123')    // GET /students/123
Endpoints.studentTrips('123')      // GET /students/123/trips
```

### Guardians
```dart
Endpoints.guardians                // GET /guardians
Endpoints.guardianChildren('123')  // GET /guardians/123/children
```

### Notifications
```dart
Endpoints.notifications                     // GET /notifications
Endpoints.markNotificationRead('123')       // PATCH /notifications/123/read
Endpoints.markAllNotificationsRead          // PATCH /notifications/read-all
```

### Chats
```dart
Endpoints.conversations            // GET /chats/conversations
Endpoints.messages                 // GET /chats/messages
Endpoints.sendMessage              // POST /chats/send
```

### Payments
```dart
Endpoints.payments                 // GET /payments
Endpoints.makePayment              // POST /payments/make
Endpoints.paymentPlans             // GET /payment-plans
```

### Reports
```dart
Endpoints.reports                  // GET /reports
Endpoints.tripReports              // GET /reports/trips
Endpoints.paymentReports           // GET /reports/payments
```

## Query Parameter Helpers

```dart
// Pagination
QueryParams.pagination(page: 2, limit: 20)
// {'page': '2', 'limit': '20'}

// Date range
QueryParams.dateRange(
  startDate: DateTime.now().subtract(Duration(days: 7)),
  endDate: DateTime.now(),
)

// Search
QueryParams.search('john', filter: 'students')
// {'q': 'john', 'filter': 'students'}

// Sorting
QueryParams.sort(by: 'created_at', ascending: false)
// {'sort_by': 'created_at', 'sort_order': 'desc'}

// Status filter
QueryParams.status('active')
// {'status': 'active'}

// Combine multiple params
final params = {
  ...QueryParams.pagination(page: 1, limit: 10),
  ...QueryParams.sort(by: 'date', ascending: false),
  ...QueryParams.status('active'),
};
// {'page': '1', 'limit': '10', 'sort_by': 'date', 'sort_order': 'desc', 'status': 'active'}
```

## Using with ApiClient

```dart
import 'api/api.dart';

class TripService {
  final ApiClient _client = ApiClient();
  
  Future<List<Trip>> getTrips({int page = 1}) async {
    final response = await _client.get(
      Endpoints.trips,
      queryParams: QueryParams.pagination(page: page),
    );
    return (response['data'] as List)
        .map((t) => Trip.fromJson(t))
        .toList();
  }
  
  Future<Trip> getTripDetails(String tripId) async {
    final response = await _client.get(
      Endpoints.tripDetails(tripId),
    );
    return Trip.fromJson(response['data']);
  }
  
  Future<void> updateStudentStatus({
    required String tripId,
    required String studentId,
    required String status,
  }) async {
    await _client.patch(
      Endpoints.updateStudentStatus(
        tripId: tripId,
        studentId: studentId,
      ),
      body: {'status': status},
    );
  }
}
```

## Adding New Endpoints

When adding new endpoints:

1. Add the endpoint constant to `Endpoints` class
2. Use path parameters for IDs: `'/resource/{id}'`
3. Add helper methods for dynamic paths when needed
4. Group related endpoints together with comments

Example:
```dart
// NEW FEATURE: Tracking
static const String tracking = '/tracking';
static String trackBus(String busId) => '/tracking/buses/$busId';
static String trackTrip(String tripId) => '/tracking/trips/$tripId';
```
