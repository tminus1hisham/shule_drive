# ShuleDrive - Agent Development Guide

> **ShuleDrive** is a Flutter-based school transportation management application for tracking school buses, managing student pickups/dropoffs, and facilitating communication between drivers and guardians.

---

## Project Overview

**ShuleDrive** is a cross-platform mobile application built with Flutter that connects school bus drivers with parents/guardians. The app provides real-time bus tracking, student management, trip coordination, and in-app chat functionality.

### Key Features
- **Role-based Access**: Separate interfaces for Drivers and Guardians (Parents)
- **Real-time Bus Tracking**: Live location tracking with geofencing alerts
- **Trip Management**: Start/end trips, track student pickup/dropoff status
- **Student Management**: Manage children/students, view pickup status
- **In-app Chat**: Communication between drivers and guardians
- **Push Notifications**: Trip updates, geofence alerts, chat messages
- **Offline Support**: Local database caching for offline functionality

### Target Platforms
- Android (minSdk: 20)
- iOS (minimum 14.0)

---

## Technology Stack

### Core Framework
| Component | Technology |
|-----------|------------|
| Framework | Flutter 3.x (SDK ^3.10.3) |
| Language | Dart |
| State Management | Provider |
| Architecture | Layered Architecture with Repository Pattern |

### Key Dependencies
```yaml
# State Management
provider: ^6.1.2

# Networking
http: ^1.6.0
mqtt_client: ^10.11.9  # For real-time tracking

# Storage
shared_preferences: ^2.5.4
flutter_secure_storage: ^9.2.2
sqflite: ^2.3.3+1      # Local database

# Maps & Location
flutter_map: ^7.0.2     # OpenStreetMap (free)
flutter_polyline_points: ^2.1.0
geolocator: ^13.0.2
geocoding: ^3.0.0

# Notifications
flutter_local_notifications: ^17.1.2
# firebase_core & firebase_messaging (optional)
# onesignal_flutter (optional)

# UI/UX
animated_splash_screen: ^1.3.0
page_transition: ^2.2.1
intl: ^0.20.2          # Internationalization
intl_phone_field: ^3.2.0

# Utilities
uuid: ^4.5.2
path_provider: ^2.1.5
image_picker: ^1.1.2
permission_handler: ^11.3.0
connectivity_plus: ^6.0.3
workmanager: ^0.9.0    # Background tasks
flutter_dotenv: ^5.2.1 # Environment config
```

---

## Project Structure

```
lib/
├── main.dart                    # App entry point, themes, routing
├── api/                         # API layer
│   ├── api_client.dart          # HTTP client with auth
│   ├── api_constants.dart       # Base URLs, endpoints
│   ├── api_exceptions.dart      # Custom exceptions
│   ├── api.dart                 # Barrel file
│   ├── endpoints.dart           # API endpoint definitions
│   └── services/                # API service classes
│       ├── auth_service.dart
│       ├── bus_service.dart
│       ├── driver_service.dart
│       ├── guardian_service.dart
│       ├── route_service.dart
│       ├── student_service.dart
│       ├── trip_service.dart
│       └── user_service.dart
├── config/
│   └── map_config.dart          # Mapbox configuration
├── controllers/
│   └── student_action_controller.dart
├── models/                      # Data models
│   ├── chat_conversation.dart
│   ├── chat_message.dart
│   ├── child.dart
│   ├── guardian.dart
│   ├── map_models.dart
│   ├── master_trip.dart
│   ├── preloaded_trip_data.dart
│   ├── student.dart
│   └── trip.dart
├── mqtt_client.dart             # MQTT client for real-time tracking
├── providers/                   # State management (Provider pattern)
│   ├── app_provider.dart        # App-level settings (theme, etc.)
│   ├── auth_provider.dart       # Authentication state
│   ├── chat_provider.dart       # Chat state
│   ├── connectivity_provider.dart # Network state
│   ├── tracking_provider.dart   # Real-time tracking state
│   └── trip_provider.dart       # Trip management state
├── screens/                     # UI Screens
│   ├── auth/                    # Authentication flows
│   │   ├── forgot_password_screen.dart
│   │   ├── login_screen.dart
│   │   ├── otp_screen.dart
│   │   ├── reset_password_screen.dart
│   │   ├── splash.dart
│   │   └── verify_reset_otp_screen.dart
│   ├── chat/                    # Chat functionality
│   │   ├── chat_list_screen.dart
│   │   ├── chat_screen.dart
│   │   └── user_list_screen.dart
│   ├── children/                # Guardian children management
│   │   ├── child_profile_screen.dart
│   │   └── manage_children_screen.dart
│   ├── driver/                  # Driver-specific screens
│   │   ├── trip_selection_screen.dart
│   │   └── vehicle_selection_screen.dart
│   ├── info/                    # Information screens
│   │   ├── about_screen.dart
│   │   └── contact_screen.dart
│   ├── main/                    # Main app screens
│   │   ├── active_trip_screen.dart
│   │   ├── dashboard_screen.dart       # Unified dashboard
│   │   ├── home_screen.dart
│   │   ├── landing_screen.dart
│   │   ├── select_students_screen.dart
│   │   ├── start_trip_screen.dart
│   │   └── students_list_screen.dart
│   ├── notifications/
│   │   └── notifications_screen.dart
│   ├── onboarding/
│   │   └── onboarding_screen.dart
│   ├── profile/                 # User profile management
│   │   ├── change_password_screen.dart
│   │   ├── edit_profile_screen.dart
│   │   ├── privacy_policy_screen.dart
│   │   ├── profile_screen.dart
│   │   └── terms_service_screen.dart
│   ├── routes/
│   │   └── routes_list_screen.dart
│   ├── tracking/                # Map tracking screens
│   │   ├── driver_map_screen.dart
│   │   ├── guardian_map_screen.dart
│   │   ├── live_tracking_screen.dart
│   │   └── osm_tracking_screen.dart
│   └── trips/                   # Trip management
│       ├── guardian_trips_screen.dart
│       ├── manage/
│       │   └── manage_master_trips_screen.dart
│       ├── trip_details_screen.dart
│       └── trips_screen.dart
├── services/                    # Business logic services
│   ├── app_config.dart          # Environment configuration
│   ├── chat_service.dart
│   ├── geofence_notification_handler.dart
│   ├── guardian_notification_service.dart
│   ├── local_database_service.dart
│   ├── mapbox_service.dart
│   ├── notification_backends/   # Notification provider implementations
│   │   ├── firebase_backend.dart
│   │   ├── firebase_stub.dart
│   │   ├── mqtt_backend.dart
│   │   └── onesignal_backend.dart
│   ├── notification_service.dart
│   ├── offline_sync_manager.dart
│   ├── secure_token_storage.dart
│   ├── service_locator.dart
│   ├── student_location_service.dart
│   ├── token_storage.dart
│   ├── tracking_service.dart
│   └── trip_history_service.dart
├── utils/                       # Utility functions
│   ├── buffer_manager.dart
│   ├── error_handler.dart
│   ├── mock_tracking_data.dart
│   ├── notification_helper.dart
│   ├── offline_storage.dart
│   ├── page_transitions.dart
│   └── permission_helper.dart
└── widgets/                     # Reusable UI components
    ├── bottom_navigation.dart
    ├── bus_illustration.dart
    ├── custom_button.dart
    ├── main_scaffold.dart
    ├── main_scaffold_with_tabs.dart
    ├── map_selector.dart
    ├── role_guard.dart
    ├── route_guard.dart
    ├── side_menu.dart
    └── student_card.dart
```

---

## Build and Development Commands

### Prerequisites
- Flutter SDK ^3.10.3
- Dart SDK (bundled with Flutter)
- Android Studio / Xcode for mobile builds
- Mapbox access token (for maps)

### Setup

```bash
# Clone and install dependencies
flutter pub get

# Copy environment configuration
copy .env.example .env
# Edit .env and add your MAPBOX_ACCESS_TOKEN
```

### Development

```bash
# Run in debug mode
flutter run

# Run with environment variables
flutter run --dart-define=MAPBOX_ACCESS_TOKEN=pk.your_token

# Run on specific device
flutter run -d <device_id>

# Hot reload (press 'r' in terminal)
# Hot restart (press 'R' in terminal)
```

### Building

```bash
# Android APK (debug)
flutter build apk

# Android APK (release) with token
flutter build apk --release --dart-define=MAPBOX_ACCESS_TOKEN=pk.your_token

# Android App Bundle
flutter build appbundle --release --dart-define=MAPBOX_ACCESS_TOKEN=pk.your_token

# iOS
flutter build ios --release

# Web (limited support due to mobile features)
flutter build web
```

### Code Quality

```bash
# Analyze code
flutter analyze

# Format code
flutter format lib/

# Run tests
flutter test
```

---

## Configuration

### Environment Variables

Configuration priority (highest to lowest):
1. `--dart-define` (compile-time)
2. `.env` file (runtime, development only)
3. Default values

| Variable | Required | Description |
|----------|----------|-------------|
| `MAPBOX_ACCESS_TOKEN` | Yes | Mapbox public token (starts with `pk.`) |
| `API_BASE_URL` | No | Backend API URL (defaults to staging) |
| `ENVIRONMENT` | No | `development`, `staging`, or `production` |

### API Configuration

- **Staging**: `https://staging-api.shuledrive.com`
- **Production**: `https://api.shuledrive.com`

See `lib/api/api_constants.dart` for endpoint definitions.

### Map Configuration

The app uses Mapbox for map tiles. Configuration is in `lib/config/map_config.dart`:
- Supports multiple map styles (streets, satellite, dark, navigation)
- Time-based tile switching (dawn/day/dusk/night)
- Default location: Nairobi, Kenya

---

## Architecture Patterns

### State Management
- **Provider Pattern** for reactive state management
- `ChangeNotifier` classes in `lib/providers/`
- `MultiProvider` at root level in `main.dart`

### Authentication Flow
1. Login with phone/password
2. Token stored securely (flutter_secure_storage + SharedPreferences)
3. `RouteGuard` widget protects authenticated routes
4. `AuthProvider` manages authentication state
5. Automatic token refresh on 401 responses

### API Layer
- `ApiClient`: Singleton HTTP client with automatic auth headers
- Service classes per domain (AuthService, TripService, etc.)
- Custom exceptions for different error types
- Automatic error handling and logging

### Data Flow
```
UI Screen → Provider → Service → ApiClient → Backend API
              ↓           ↓
         notifyListeners  Response
              ↓           ↓
         UI Updates    Local Storage (cache)
```

### Role-Based Access
```dart
enum UserRole { driver, guardian, unknown }

// Role guard usage
RouteGuard(
  allowedRoles: [UserRole.driver],
  child: DriverOnlyScreen(),
)
```

---

## Testing

### Current Test Setup
- Basic widget test in `test/widget_test.dart`
- Uses `flutter_test` package

### Running Tests
```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/widget_test.dart

# Run with coverage
flutter test --coverage
```

### Testing Guidelines
- Widget tests for UI components
- Unit tests for providers and services (to be added)
- Mock external dependencies (API, location, notifications)
- Use `Mockito` or `mocktail` for mocking

---

## Development Conventions

### Code Style
- Follow official Dart style guide
- Use `flutter_lints` package for linting
- Line length: 80-100 characters recommended
- Use trailing commas for better diffs

### Naming Conventions
- **Files**: `snake_case.dart`
- **Classes**: `PascalCase`
- **Variables/Functions**: `camelCase`
- **Constants**: `UPPER_SNAKE_CASE` or `kCamelCase`
- **Private members**: `_leadingUnderscore`

### File Organization
- One class per file (generally)
- Barrel files for clean imports (`api/api.dart`)
- Group related screens in feature folders
- Keep widgets small and focused

### Comments
- Use `///` for documentation comments
- Explain "why", not "what" (code should be self-documenting)
- Add section headers for long files:
```dart
// ============================================================================
// AUTHENTICATION
// ============================================================================
```

### Error Handling
- Use custom exceptions from `api_exceptions.dart`
- Show user-friendly error messages
- Log errors in debug mode with `debugPrint`
- Handle offline scenarios gracefully

---

## Security Considerations

### Authentication
- JWT tokens stored in secure storage
- Automatic token refresh before expiry
- Clear all tokens on logout
- HTTPS only for API calls

### Configuration Security
- `.env` file in `.gitignore` (NEVER commit)
- Use `--dart-define` for production builds
- No hardcoded API keys in source code

### Development Only Code
```dart
// HttpOverrides for staging SSL certificates
// TODO: Remove for production builds
HttpOverrides.global = _DevHttpOverrides();
```

### Permissions
- Location: Required for tracking
- Notifications: Required for alerts
- Camera/Photos: For profile pictures

---

## Key Features Implementation

### Real-time Tracking
- MQTT client for lightweight pub/sub
- Topics: `bus/{busId}/location`, `trip/{tripId}/events`
- Mock data generator for testing without backend
- Geofencing with 3 alert zones (5min, 1min, arrived)

### Offline Support
- `LocalDatabaseService` with SQLite (sqflite)
- `OfflineSyncManager` for queueing actions
- `ConnectivityProvider` for network state
- Automatic sync when connection restored

### Notifications
Multiple backend support:
- **Firebase**: Primary recommendation
- **OneSignal**: Alternative cloud solution
- **MQTT**: Uses existing connection
- **Local-only**: No push, local notifications only

Channels:
- `geofence_alerts`: High priority arrival alerts
- `trip_updates`: General trip notifications
- `chat_messages`: Chat message notifications

---

## Common Development Tasks

### Adding a New Screen
1. Create file in appropriate `screens/` subdirectory
2. Add route in `main.dart` `_buildPageRoute()`
3. Add to `RouteGuard` if authentication required
4. Update navigation from relevant screens

### Adding an API Endpoint
1. Add endpoint constant in `api/api_constants.dart`
2. Add method in appropriate service class
3. Handle response in provider
4. Update UI to call provider method

### Adding a New Provider
1. Create class extending `ChangeNotifier`
2. Add to `MultiProvider` in `main.dart`
3. Use `Consumer<YourProvider>` or `context.watch/read`

### Working with Maps
1. Ensure `MAPBOX_ACCESS_TOKEN` is set
2. Use `MapConfig.mapboxAccessToken` for tile URLs
3. Use `flutter_map` for free OpenStreetMap alternative

---

## Troubleshooting

### Common Issues

**"Mapbox token not found"**
- Check `.env` file exists with `MAPBOX_ACCESS_TOKEN`
- Verify token format (starts with `pk.`)
- Restart app (hot reload won't pick up `.env` changes)

**Blank map in release build**
- Use `--dart-define` instead of `.env` for release
- Verify token has no URL restrictions

**Build fails**
```bash
flutter clean
flutter pub get
cd android && ./gradlew clean && cd ..
flutter run
```

**iOS pod install issues**
```bash
cd ios
pod deintegrate
pod install
cd ..
```

---

## Documentation References

- `CONFIGURATION.md`: Environment setup guide
- `TRACKING_FEATURE_SUMMARY.md`: Real-time tracking implementation
- `UNIFIED_DASHBOARD.md`: Dashboard architecture
- `ANDROID_MAP_SETUP.md`: Android Google Maps setup
- `IOS_MAP_SETUP.md`: iOS Google Maps setup
- `GET_API_KEY.md`: API key acquisition guide

---

## Contact & Support

For configuration issues:
1. Check debug console for `[AppConfig]` log messages
2. Verify token at [Mapbox Token Debugger](https://docs.mapbox.com/help/troubleshooting/token-debugger/)
3. Run `appConfig.printConfig()` in debug mode

---

*This project is built with Flutter. For help getting started, see the [Flutter documentation](https://docs.flutter.dev/).*
