# 🗺️ Free OpenStreetMap Tracking Guide

## What's New?

**100% FREE map tracking** using OpenStreetMap + OSRM - no API key required!

### Features
- ✅ **Free OpenStreetMap tiles** - No API key needed
- ✅ **Free OSRM routing** - Get real routes between stops
- ✅ **Live bus tracking** - Real-time location updates
- ✅ **Geofencing alerts** - 5min/1min/Arrived notifications
- ✅ **Route visualization** - See the full route on map
- ✅ **Speed & ETA** - Real-time calculations

## How to Use

### 1. Tap "Live Track" on Home Screen

### 2. Choose Map Provider
```
┌─────────────────────────────────┐
│  Select Map Provider            │
├─────────────────────────────────┤
│  🗺️ Google Maps                 │
│     Best quality, requires key  │
├─────────────────────────────────┤
│  🌍 OpenStreetMap (FREE)  ✅    │
│     100% Free, no key needed!   │
└─────────────────────────────────┘
```

### 3. Enjoy Free Tracking!

## Technical Details

### Map Tiles
- **Standard**: `tile.openstreetmap.org` (free)
- **Dark Mode**: `cartocdn.com/dark_all` (free)

### Routing (OSRM)
- **API**: `router.project-osrm.org`
- **Cost**: 100% FREE
- **Limits**: Generous free tier for demo/testing
- **Response**: GeoJSON format

### No Signup Required!
Just run the app and it works immediately.

## Screenshots

The OSM tracking screen includes:
- 🗺️ Full-screen OpenStreetMap
- 🚌 Animated bus marker
- 📍 Stop markers with numbers
- 🛣️ Route polyline (from OSRM)
- 📊 Speed, ETA, passenger count
- 🔔 Geofence alert banners
- 🎮 Zoom, center, follow controls
- © OSM attribution (required)

## File Structure

```
lib/
├── screens/
│   └── tracking/
│       ├── live_tracking_screen.dart    # Google Maps
│       └── osm_tracking_screen.dart     # OpenStreetMap ⭐ NEW
├── widgets/
│   └── map_selector.dart                # Provider selector
└── utils/
    └── mock_tracking_data.dart          # Mock GPS data
```

## For Production

If deploying to production with high traffic:

### Option 1: Self-Host OSRM
```bash
# Run your own OSRM server (free, open source)
docker run -p 5000:5000 osrm/osrm-backend
```

### Option 2: Use Mapbox (Free Tier)
- 50,000 map loads/month free
- Better performance than OSRM public API

### Option 3: Keep Using Free OSRM
- Fine for demos, small apps
- Public API has rate limits

## Comparison

| Feature | Google Maps | OpenStreetMap |
|---------|-------------|---------------|
| Cost | $7/1000 loads | FREE |
| API Key | Required | Not needed |
| Quality | Excellent | Good |
| Offline | No | Yes (self-host) |
| Setup | Complex | Instant |

## Troubleshooting

### Map not loading?
- Check internet connection
- OSM tiles load from internet

### Routes not showing?
- OSRM API requires internet
- Falls back to straight lines if offline

### Slow performance?
- OSRM public API is shared
- Consider self-hosting for production

## Legal Attribution

Required by OpenStreetMap license:
> © OpenStreetMap contributors

The app automatically shows this in the bottom-left corner.

## Ready to Test!

```bash
flutter clean
flutter pub get
flutter run
```

Tap **"Live Track"** → Select **"OpenStreetMap (Free)"** → Enjoy! 🎉
