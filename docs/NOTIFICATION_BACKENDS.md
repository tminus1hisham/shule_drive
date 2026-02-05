# Notification Backends - No Firebase Required!

ShuleDrive now supports **multiple push notification backends**! You can choose the one that works best for your needs.

## Available Backends

| Backend | Free Tier | Setup Complexity | Best For |
|---------|-----------|------------------|----------|
| **Local Only** | Always free | None | Testing, single-user scenarios |
| **MQTT** | Always free | Low | Already using MQTT, self-hosted |
| **OneSignal** | 10K subscribers | Low | Drop-in Firebase alternative |
| **Firebase** | 10K messages/day | Medium | Google ecosystem |

## Quick Comparison

### Local Only Mode
- ✅ Zero setup
- ✅ Works offline
- ✅ No third-party dependencies
- ❌ No remote push notifications
- ❌ App must be running to receive notifications

### MQTT Mode
- ✅ Uses existing infrastructure
- ✅ Real-time delivery
- ✅ Self-hosted
- ❌ Requires MQTT broker
- ❌ Limited to active connections

### OneSignal
- ✅ Drop-in Firebase replacement
- ✅ Rich analytics
- ✅ SMS & Email fallback
- ⚠️ External service dependency
- ⚠️ Privacy considerations

### Firebase
- ✅ Most reliable delivery
- ✅ Rich targeting
- ✅ Free tier
- ⚠️ Google dependency
- ⚠️ Complex setup

## Usage

### Option 1: Local Only (Default, No Setup!)

```dart
await NotificationService().initialize(
  preferredBackend: NotificationBackend.localOnly,
);
```

Notifications work when app is in foreground. For background notifications, use a foreground service.

### Option 2: MQTT (If you have MQTT broker)

```dart
await NotificationService().initialize(
  preferredBackend: NotificationBackend.mqtt,
);

// Subscribe to trip updates
await NotificationService().subscribeToTrip('trip-123');
```

**Backend Setup:**
```javascript
// Your backend publishes to MQTT topic
mqttClient.publish('notifications/trip_123', JSON.stringify({
  type: 'notification',
  payload: {
    title: '🚌 Bus Alert',
    body: 'Bus is approaching',
    trip_id: 'trip-123',
  }
}));
```

### Option 3: OneSignal (Recommended Alternative)

```dart
await NotificationService().initialize(
  preferredBackend: NotificationBackend.onesignal,
);
```

**Setup:**
1. Create account at [onesignal.com](https://onesignal.com)
2. Get App ID and REST API Key
3. Add to your configuration

### Option 4: Firebase (Original)

```dart
await NotificationService().initialize(
  preferredBackend: NotificationBackend.firebase,
);
```

## Backend Selection Logic

The service automatically tries backends in order:

1. Try preferred backend
2. If fails, fall back to Local Only
3. Local Only always works

```dart
// This will use Firebase if available, otherwise Local Only
await NotificationService().initialize(
  preferredBackend: NotificationBackend.firebase,
);
```

## For Geofence Alerts (Without Firebase)

### Approach 1: Local Geofence + MQTT

```dart
// Driver app publishes location via MQTT
_mqttService.publish('bus/location', jsonEncode({
  'trip_id': 'trip-123',
  'lat': -6.8,
  'lng': 39.28,
}));

// Backend calculates distance and sends notification via MQTT
```

### Approach 2: Background Location + Local Notifications

```dart
// Use geolocator's background location
Geolocator.getPositionStream(
  locationSettings: AndroidSettings(
    foregroundNotificationConfig: ForegroundNotificationConfig(
      notificationTitle: 'Tracking Active',
      notificationBody: 'Monitoring bus location',
    ),
  ),
).listen((position) {
  // Calculate distance locally
  GeofenceNotificationHandler().processLocationUpdate(
    LatLng(position.latitude, position.longitude),
  );
});
```

### Approach 3: Server-Side Geofence (OneSignal/MQTT)

```dart
// Backend monitors bus locations
// When geofence triggered, send notification via OneSignal/MQTT
// App receives push notification
```

## Switching Backends at Runtime

```dart
final notifications = NotificationService();

// Start with Local Only
await notifications.initialize(preferredBackend: NotificationBackend.localOnly);

// Later, switch to MQTT when connected
await notifications.switchBackend(NotificationBackend.mqtt);
```

## Backend-Specific Features

### MQTT-Specific
- Topic-based subscription
- QoS levels for delivery guarantee
- Retained messages
- Last will and testament

### OneSignal-Specific
- Segments and filters
- A/B testing
- Scheduled notifications
- Rich media attachments

### Firebase-Specific
- Topic-based messaging
- Device group messaging
- Analytics integration
- A/B testing

## Testing

### Test Local Notifications
```dart
await NotificationService().showLocalNotification(
  title: 'Test',
  body: 'Local notification works!',
);
```

### Test MQTT Notifications
```bash
# Publish test message
mosquitto_pub -t "notifications/test" -m '{"title":"Test","body":"MQTT works!"}'
```

### Test OneSignal
Use OneSignal dashboard to send test push.

## Removing Firebase

To completely remove Firebase:

1. **Remove Firebase dependencies from `pubspec.yaml`:**
```yaml
# Remove these lines:
# firebase_core: ^3.1.0
# firebase_messaging: ^15.0.1
```

2. **Remove from `android/build.gradle`:**
```groovy
// Remove:
// classpath 'com.google.gms:google-services:4.4.2'
```

3. **Remove from `android/app/build.gradle`:**
```groovy
// Remove:
// apply plugin: 'com.google.gms.google-services'
```

4. **Delete `google-services.json`**

5. **Update `main.dart`:**
```dart
// Remove Firebase.initializeApp();
// Use local-only or MQTT instead
```

## Recommendation

For a **privacy-focused, self-hosted** solution:
- Use **MQTT** for real-time notifications
- Use **Local Only** + background location for geofence

For a **simple, managed** solution:
- Use **OneSignal** as Firebase alternative

For **testing/development**:
- Use **Local Only** mode
