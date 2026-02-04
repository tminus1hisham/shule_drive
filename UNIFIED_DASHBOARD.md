# 🏠 Unified Dashboard - Single Home Screen

## Overview
Combined Home and Landing screens into a single intelligent dashboard that adapts based on:
1. **User Role** (Driver vs Guardian)
2. **Trip Status** (No active trip vs Active trip)

## Screens Removed
- ❌ Home/Landing toggle navigation (pressing Home button no longer switches screens)

## New Flow
```
User logs in → Unified Dashboard (adapts to role & trip status)
```

## Dashboard Views

### 🚌 Driver View

#### No Active Trip
```
┌─────────────────────────────┐
│  Start New Trip             │
│                             │
│  [  +  ]                    │
│                             │
│  Begin your route and       │
│  ensure students get to     │
│  school safely              │
│                             │
│  [    Start Trip    ]       │
└─────────────────────────────┘
```
- Large green card with "Start Trip" CTA
- Quick action to begin route

#### Active Trip
```
┌─────────────────────────────┐
│  🚌 Route Name          LIVE│
│  Trip #123                  │
│                             │
│  ████████████░░░░  75%      │
│  6 of 8 students picked up  │
│                             │
│  [View Students] [End Trip] │
└─────────────────────────────┘
```
- Shows live trip progress
- Progress bar with pickup percentage
- View students list
- End trip button

### 👨‍👩‍👧 Guardian View

#### No Active Trip
```
┌─────────────────────────────┐
│     🚌 (illustration)       │
│                             │
│  No Active Trips            │
│                             │
│  When the school bus        │
│  starts its route, you'll   │
│  see live updates here      │
│                             │
│  [ Manage Children ]        │
└─────────────────────────────┘
```
- Friendly illustration
- Informational message
- Manage children button

#### Active Trip
```
┌─────────────────────────────┐
│  🚌 Bus KCA 123X        LIVE│
│                             │
│  ⏱ 15 min   🏎 32 km/h     │
│                             │
│  [ Track Live Location ]    │
└─────────────────────────────┘

Your Child's Status
┌─────────────────────────────┐
│  👤 John Doe                │
│  🟢 Picked Up       7:30 AM │
└─────────────────────────────┘
```
- Live tracking card with ETA, speed, distance
- Track location button (opens OSM map)
- Child pickup status card

## Quick Actions (All Users)
Always visible at bottom:
- **Start Trip** (Driver, no active trip)
- **Students** (Driver, active trip)
- **My Children** (Guardian)
- **Live Track** (opens free OSM map)
- **History** (trip history)

## Technical Changes

### Files Modified
1. **main.dart**
   - Added DashboardScreen import
   - Updated AuthWrapper to use DashboardScreen
   - Added `/dashboard` route

2. **landing_screen.dart**
   - Simplified navigation (removed toggle)

3. **home_screen.dart**
   - Simplified navigation (removed toggle)

### Files Created
1. **dashboard_screen.dart**
   - Unified dashboard implementation
   - Role-based view switching
   - Trip status detection

## Navigation
Bottom nav "Home" button:
- **Before**: Toggled between Home ↔ Landing
- **Now**: Stays on Dashboard (single screen)

## Testing
```bash
flutter clean
flutter pub get
flutter run
```

Login and you'll see the unified dashboard!
