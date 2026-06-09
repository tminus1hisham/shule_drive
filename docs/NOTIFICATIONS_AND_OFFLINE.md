# Push Notifications & Offline Support

This document describes the push notification and offline support implementation for ShuleDrive.

## Table of Contents

1. [Overview](#overview)
2. [Push Notifications](#push-notifications)
3. [Offline Support](#offline-support)
4. [Setup Instructions](#setup-instructions)
5. [Usage Examples](#usage-examples)

---

## Overview

The app now supports:
- **Push Notifications**: FCM (Firebase Cloud Messaging) for geofence alerts
- **Local Notifications**: In-app notifications when bus is approaching
- **Offline Database**: SQLite for storing trips, students, and pending operations
- **Background Sync**: Automatic sync when connectivity is restored

---

## Push Notifications

### Geofence Alerts

Three alert types are triggered based on bus distance from pickup stop:

| Alert Type | Distance | ETA | Message |
|------------|----------|-----|---------|
| Approaching | 2km | ~5 min | "Bus is approximately 5 minutes away" |
| Arriving | 500m | ~1 min | "Bus will arrive in about 1 minute" |
| Arrived | 100m | At stop | "Bus has arrived at your stop" |

### Architecture

```
┌─────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Bus GPS    │────▶│ Geofence Handler │────▶│ Local Database  │
└─────────────┘     └──────────────────┘     └─────────────────┘
                             │
                             ▼
                    ┌──────────────────┐
                    │  FCM / Local     │
                    │  Notifications   │
                    └──────────────────┘
```

### Files

- `lib/services/notification_service.dart` - FCM & local notifications
- `lib/services/geofence_notification_handler.dart` - Distance-based alerts
- `lib/services/local_database_service.dart` - Alert storage

---

## Offline Support

### Local Database (SQLite)

Stores the following entities locally:

- **Trips**: Trip details, stops, students
- **Students**: Child/student information
- **Routes**: Route details and schedules
- **Pending Operations**: Queue for offline actions
- **Geofence Alerts**: Historical alert data

### Pending Operations Queue

When offline, the following operations are queued for later sync:

| Operation | Entity | Priority |
|-----------|--------|----------|
| create | student | 1 |
| update | student | 2 |
| update_student_status | trip | 1 |
| start | trip | 3 |
| end | trip | 3 |

### Background Sync

- Runs every 15 minutes when app is backgrounded
- Triggers immediately when connection restored
- Retries failed operations up to 5 times

### Files

- `lib/services/local_database_service.dart` - SQLite database
- `lib/services/offline_sync_manager.dart` - Sync logic
- `lib/providers/connectivity_provider.dart` - Network monitoring

---

## Setup Instructions

### 1. Firebase Setup

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project (or use existing)
3. Add Android app with package name `com.example.shuledrive`
4. Download `google-services.json`
5. Replace `android/app/google-services.json` with your file

### 2. Google Maps API Key (Optional)

For Google Maps support, update `android/app/src/main/AndroidManifest.xml`:

```xml
<meta-data 
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_ACTUAL_API_KEY"/>
```

Note: OpenStreetMap is used by default (free, no API key required).

### 3. iOS Setup

For iOS push notifications:

1. Add iOS app in Firebase Console
2. Download `GoogleService-Info.plist`
3. Add to `ios/Runner/`
4. Enable Push Notifications in Xcode capabilities

---

## Usage Examples

### Geofence Monitoring

```dart
import 'package:shule_drive/services/geofence_notification_handler.dart';
import 'package:shule_drive/api/services/trip_service.dart';

// Start monitoring when trip begins
final trip = await tripService.startTrip(
  routeId: 'route-123',
  vehicleId: 'bus-456',
);

await GeofenceNotificationHandler().startMonitoring(trip);

// Process location updates (from GPS/MQTT)
GeofenceNotificationHandler().processLocationUpdate(
  LatLng(-6.8, 39.28),
  speedKmh: 25.0,
);

// Stop monitoring when trip ends
await GeofenceNotificationHandler().stopMonitoring();
```

### Local Database Operations

```dart
import 'package:shule_drive/services/local_database_service.dart';

final db = LocalDatabaseService();

// Save trip locally
await db.saveTrip(trip);

// Get cached trips
final trips = await db.getAllTrips(status: 'active');

// Get students for a guardian
final students = await db.getStudentsByGuardian('guardian-id');
```

### Queue Operation for Offline Sync

```dart
import 'package:shule_drive/services/offline_sync_manager.dart';

final syncManager = OfflineSyncManager();

// Queue an operation that needs to sync when online
await syncManager.queueOperation(
  operationType: 'update_student_status',
  entityType: 'trip',
  entityId: 'trip-123',
  payload: {
    'trip_id': 'trip-123',
    'student_id': 'student-456',
    'status': 'picked',
  },
  priority: 1, // Higher priority = synced first
);

// Force sync
final result = await syncManager.forceSync();
print('Synced: ${result.syncedCount}, Failed: ${result.failedCount}');
```

### Show Local Notification

```dart
import 'package:shule_drive/services/notification_service.dart';

final notifications = NotificationService();

// Show notification
await notifications.showLocalNotification(
  title: '🚌 Bus Alert',
  body: 'Bus is approaching your stop',
  channelId: 'geofence_alerts',
);

// Subscribe to trip updates
await notifications.subscribeToTrip('trip-123');
```

### Monitor Connectivity

```dart
import 'package:shule_drive/providers/connectivity_provider.dart';

// In your widget
final connectivity = context.watch<ConnectivityProvider>();

if (connectivity.isOffline) {
  return Banner(
    message: 'Offline Mode',
    location: BannerLocation.topEnd,
    child: YourWidget(),
  );
}

// Get pending operations count
final pendingCount = await connectivity.getPendingCount();
```

---

## Testing

### Test Push Notifications

Use Firebase Console:
1. Go to Firebase Console > Cloud Messaging
2. Send test message with data payload:

```json
{
  "type": "geofence_alert",
  "trip_id": "test-trip",
  "alert_type": "approaching",
  "distance_meters": "1500",
  "eta_minutes": "4"
}
```

### Test Offline Mode

1. Enable airplane mode
2. Perform actions (update student status)
3. Disable airplane mode
4. Verify sync completes automatically

### Test Geofence

Use mock location in Android Developer Options or simulator:
1. Start a trip
2. Simulate bus location near a stop (within 2km)
3. Verify notification appears

---

## Troubleshooting

### Notifications not appearing

- Check notification permissions in app settings
- Verify FCM token is registered with backend
- Check `google-services.json` is correctly placed

### Offline sync not working

- Check internet connectivity
- Verify pending operations exist
- Check sync status: `SyncManager().getSyncStatus()`

### Database issues

- Clear app data to reset database
- Check logcat for SQLite errors

---

## Next Steps

1. **Backend Integration**: Implement API endpoints for FCM token registration
2. **iOS Support**: Add iOS configuration for push notifications  
3. **Web Support**: Add web push notification support
4. **Background Location**: Enable background location for accurate tracking
