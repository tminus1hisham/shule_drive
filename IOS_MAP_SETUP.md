# iOS Google Maps Setup

## Step 1: Get API Key
Same as Android - use the same key or create iOS-specific key in Google Cloud Console.

## Step 2: Add API Key to iOS App

Edit `ios/Runner/AppDelegate.swift`:

```swift
import UIKit
import Flutter
import GoogleMaps  // Add this import

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("YOUR_API_KEY_HERE")  // Add this line
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

## Step 3: Update Podfile

Edit `ios/Podfile` and ensure platform is set:

```ruby
platform :ios, '14.0'  # Minimum for Google Maps
```

## Step 4: Add Location Permissions

Edit `ios/Runner/Info.plist` and add:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs your location to show nearby buses</string>

<key>NSLocationAlwaysUsageDescription</key>
<string>This app needs your location to track bus arrivals even when in background</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>This app needs your location to show nearby buses and send arrival alerts</string>
```

## Step 5: Install Pods

```bash
cd ios
pod install
cd ..
flutter run
```

## Troubleshooting

If you see a blank map:
1. Check API key is correct
2. Ensure Maps SDK for iOS is enabled in Google Cloud Console
3. Check that API key restrictions don't block iOS
