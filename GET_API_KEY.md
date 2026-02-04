# 🔑 Get Your FREE Google Maps API Key

## Step 1: Create Google Cloud Account
1. Go to https://console.cloud.google.com/
2. Sign in with your Google account
3. Accept terms and create a project (or use existing)

## Step 2: Enable Maps API
1. In the console, go to **"APIs & Services"** → **"Library"**
2. Search for **"Maps SDK for Android"**
3. Click **"Enable"**

## Step 3: Create API Key
1. Go to **"APIs & Services"** → **"Credentials"**
2. Click **"Create Credentials"** → **"API Key"**
3. Copy the key (looks like: `AIzaSyB...`)

## Step 4: Add Key to App

### For Android:
Edit `android/app/src/main/AndroidManifest.xml`:

Replace:
```xml
<meta-data 
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_GOOGLE_MAPS_API_KEY_HERE"/>
```

With:
```xml
<meta-data 
    android:name="com.google.android.geo.API_KEY"
    android:value="AIzaSyB...YOUR_KEY_HERE"/>
```

## Step 5: Run the App
```bash
flutter clean
flutter pub get
flutter run
```

## ⚠️ Security Note

**DO NOT commit your API key to Git!** 

Add to `.gitignore`:
```
android/app/src/main/AndroidManifest.xml
```

Or use environment variables for production.

## Free Tier Limits
- **28,500 map loads per month** = FREE
- $7 per 1,000 after that
- For 500 users, this is MORE than enough

## Troubleshooting

If you see "API key not found":
1. Make sure you replaced the placeholder text
2. Make sure the key is inside `<application>` tag
3. Run `flutter clean` then `flutter run`

If you see "This API project is not authorized":
1. Make sure "Maps SDK for Android" is enabled
2. Check that your key has no restrictions (or add your app correctly)
