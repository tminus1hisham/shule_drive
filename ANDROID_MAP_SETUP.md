# Android Google Maps Setup

## Step 1: Get Google Maps API Key

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing one
3. Enable the **Maps SDK for Android** API
4. Go to **Credentials** → **Create Credentials** → **API Key**
5. Restrict the key for security (optional but recommended)

## Step 2: Add API Key to Android Manifest

Edit `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest ...>
    <application
        ...
        android:label="ShuleDrive"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        
        <!-- Add this meta-data tag inside application tag -->
        <meta-data 
            android:name="com.google.android.geo.API_KEY"
            android:value="YOUR_API_KEY_HERE"/>
            
        <activity ...>
            ...
        </activity>
    </application>
</manifest>
```

## Step 3: Enable Location Permissions

Add to `android/app/src/main/AndroidManifest.xml` inside `<manifest>` tag:

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION"/>
```

## Step 4: Configure minSdkVersion

Ensure `android/app/build.gradle` has:

```gradle
android {
    defaultConfig {
        minSdkVersion 20  // Required for Google Maps
        ...
    }
}
```

## Step 5: Run the app

```bash
flutter clean
flutter pub get
flutter run
```

## Free Tier Limits (Generous!)

- **28,500 map loads per month** - FREE
- $7 per 1,000 loads after that
- For a school app with ~500 users, this is more than enough

## Testing Without API Key

The app will still compile and run, but the map will show a blank grid with "Google" logo.
