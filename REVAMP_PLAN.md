# ShuleDrive UI Revamp: motion, rich widgets, colour

## Context
ShuleDrive is a Flutter app (Provider, Navigator 1.0 with `_buildPageRoute` in `lib/main.dart`, custom Material 3 theme). Drivers use it all day on phones while running bus routes; guardians check it quickly to see where the bus is.

A design system already exists: `lib/theme/*` provides `context.colors`, `AppSpacing`, `AppRadius`, `AppDuration` and `AppCurves`, and `lib/widgets/ui/*` provides AppButton, AppCard, StatusPill, StatTile, EmptyState, GradientHeroCard, AppSkeleton, PressScale and StaggeredEntrance. Only the auth screens, the dashboard, the shell, `osm_tracking` and `add_trip_student_sheet` use it. The other ~25 screens (~30k lines) still use `isDarkMode` ternaries, hand-rolled cards, pills and empty states, and have almost no motion.

In those screens, state changes happen with no animation:
- student picked or dropped
- counters and progress bars
- chat messages arriving
- badges
- tab switches, which use a `Duration.zero` route

The goal is for every section to feel alive and cohesive: animated entrances, reactive micro-interactions, richer widgets and bolder brand colour. **Behaviour stays the same**: routes, API calls, providers, validation and copy meaning.

**Decisions made:** delete unreachable code; add `flutter_animate`; keep the emerald and amber brand, applied more boldly (no per-section hues).

Skills in use: `ui-revamp` (workflow and checkpoint), `flutter-ui` (Flutter animation and performance rules), `emil-design-eng` and `improve-animations` (motion taste, already encoded in `AppCurves`), `ui-ux-pro-max` (hierarchy and states), and the `dart-flutter` MCP (analyze, format, launch, hot reload, widget tree).

## Phase 0: Setup
- Create branch `ui-revamp` from the clean `main`.
- Copy this plan to `REVAMP_PLAN.md` at the repo root as the rollout tracker.
- `pub add flutter_animate`. This is the only new dependency; it justifies itself by giving one chainable effects API across ~30 screens.
- Delete the dead code:
  - `screens/main/home_screen.dart` and `landing_screen.dart`
  - `screens/auth/otp_screen.dart`
  - `screens/tracking/guardian_map_screen.dart`, `live_tracking_screen.dart` and `driver_map_screen.dart`
  - `screens/routes/routes_list_screen.dart`, which is only pushed from `landing`
  - `widgets/main_scaffold_with_tabs.dart`, `custom_button.dart` and `student_card.dart`
  - `utils/page_transitions.dart`
  - their `main.dart` imports and routes (`/live-tracking`, `/driver-map`, `/routes`). `/home` and `/landing` already point to `DashboardScreen`, so they stay.
  - Run `flutter analyze` to confirm nothing breaks.

## Phase 1: Foundations (these ripple to every screen)

### Motion tokens: new `lib/theme/app_motion.dart`
- Presets are built on `flutter_animate` and share `AppCurves` and `AppDuration`, so every screen moves the same way:
  - `enter` (fade + 8px rise), `enterList(i)` (stagger 50ms, capped at 8, as `StaggeredEntrance` does today)
  - `pop` (scale 0.9→1, easeOutBack), `shake` (errors), `shimmer` (the "live" and success highlight)
- A tiny `Motion` wrapper widget reads `MediaQuery.disableAnimationsOf` and returns the child unanimated when reduced motion is on. flutter_animate does not honour that setting itself.
- Add `AppDuration.page = 300ms`.
- Once all four call sites have migrated, `StaggeredEntrance` is deleted.

### Colour: `lib/theme/app_theme_extension.dart` (`AppColors`)
- Add `accentGradient` (the amber pair) for bus, ETA and live moments.
- Add `glassSurface` and `glassBorder` for translucent map and hero panels, in both light and dark.
- Promote dashboard's `_DashboardBackdrop` (`dashboard_screen.dart:2153`) and `_DashboardGlassPanel` (`:2215`) to `ui/app_backdrop.dart` and `ui/glass_panel.dart`. Every top-level screen gets the same tinted-gradient backdrop.

### Primitive upgrades (existing files)
- `StatusPill`: `AnimatedContainer` and `AnimatedSwitcher` on colour and label, so status flips cross-fade.
- `StatTile`: numeric values tick through `AnimatedCount`.
- `AppButton`: confirm or add a `loading` state (spinner swaps with the label).
- `EmptyState`: entrance `pop` on the icon.
- `AppSkeleton`: unchanged.

### New shared widgets in `lib/widgets/ui/` (each export added to `ui.dart`)
These replace the duplicates the survey found.

| Widget | Replaces (examples) |
|---|---|
| `student_status.dart`: `StudentStatusStyle` extension (colour, icon, label from `context.colors`) + `StudentStatusRow` (avatar with animated status ring, name, subtitle, animated pill, trailing actions) | 7 copies with different colours: `active_trip_screen.dart:2571,3041`, `students_list_screen.dart:1031`, `trip_details_screen.dart:553`, `guardian_trips_screen.dart:688`, `next_student_trip_action_card.dart:868` |
| `TripProgress` (bar + ring, `TweenAnimationBuilder`, animated "x of y") | `active_trip:2421,2119,3628`, `guardian_trips:835`, `next_student_card:243`, `students_list:~600` |
| `AnimatedCount` (tabular digits that roll on change) | the counters in the headers and StatTile |
| `CountBadge` (pops on change) | `chat_list:454`, `notifications:292`, the bottom-nav dot at `:123`, dashboard `_CircleIconButton` |
| `SelectableCard` (animated border, radio and elevation) | `trip_selection:496`, `vehicle_selection:519`, `start_trip:1843`, `manage_master_trips:662` |
| `BottomActionBar` (safe-area sticky CTA + secondary) | `trip_selection:690`, `vehicle_selection:709`, `start_trip:1362,2019`, `active_trip:1440` |
| `AsyncBody` (loading skeleton / error / empty / content via `AnimatedSwitcher`; always scrollable so pull-to-refresh works) | hand-rolled state switches in 8 screens; fixes the non-scrollable empty and error states in `trips`, `guardian_trips`, `manage_children` and `notifications` |
| `AppListTile` (icon tile + title/subtitle + chevron, PressScale) | profile `_buildMenuTile:706`, contact `_buildContactItem:170`, side menu items |
| `SwipeAction` (themed Dismissible + confirm) | `active_trip:2690`, `students_list:1164`, `manage_children:302`, `notifications:450` |

### App shell
- `MainScaffold`: own the bottom-nav `switch(index)` once. This removes 5 copies and fixes the dead handlers in `child_profile:242`.
- `bottom_navigation.dart`: use `CountBadge`, and slide the selected indicator between tabs.
- `lib/main.dart` `_buildPageRoute`:
  - Tab routes: 180ms fade-through instead of `Duration.zero`.
  - Push routes: 300ms shared-axis rise + fade on `AppCurves.easeOut`.
  - Add `Hero` pairs: splash logo → login logo; child card avatar → child profile; trip card → trip details header.
- Haptics: `HapticFeedback.selectionClick` on pick, drop and absent, and on tab change (`services.dart`, built in).

## Phase 2: Pilot, then the checkpoint
**Pilot: `screens/main/students_list_screen.dart`**. It uses nearly every pattern: gradient header, progress, search, segmented filter, a list whose statuses flip, bulk actions, FAB, action sheet, empty state and confirm dialog.
- The header becomes `GradientHeroCard` + `TripProgress` ring + `AnimatedCount` stats.
- The segment indicator slides.
- Rows become `StudentStatusRow` in a `SwipeAction`. A status flip cross-fades the pill, the ring colour animates, and a row leaving the filtered tab animates out (`AnimatedList` or AnimatedSize + fade).
- Delete the dead `_animationController` (`:43`).

Verify, then stop and show the direction, screenshots in light and dark mode, and the list of foundation changes. Ask **approve with commits / approve uncommitted / adjust / stop**. No other screen is touched until the user approves.

## Phase 3: Rollout (in order, one commit per area if chosen)

Pattern for every screen:
1. Delete the `isDarkMode` ternaries and local colour and size literals.
2. Swap hand-rolled pieces for `ui/` widgets.
3. Wrap the body in `AsyncBody`.
4. Add the `enter` / `enterList` entrances.
5. Animate every state change the survey flagged.

Order:

1. **Driver core**
   - `active_trip_screen.dart` (4k lines): animated top bar and bottom panel, `TripProgress`, `StudentStatusRow` sheet, glass panels, and the complete-trip dialog with a `pop` + `shimmer` success moment.
   - `widgets/next_student_trip_action_card.dart`: the "next" highlight slides, the chip cross-fades and the progress animates. Also fix the deprecated `surfaceVariant`.
   - `osm_tracking_screen.dart`: `GlassPanel` gives it dark mode; the proximity banner slides in; stats use `AnimatedCount`.
2. **Driver setup:** `start_trip_screen.dart`, `trip_selection_screen.dart`, `vehicle_selection_screen.dart` (`SelectableCard`, `BottomActionBar`, crossfade between loading, active and select states).
3. **Guardian:**
   - `dashboard_screen.dart`: add `enterList` and the idle↑active crossfade, and put `_ActionTile` and `_CircleIconButton` on PressScale.
   - `guardian_trips_screen.dart`, `manage_children_screen.dart` (the `AddChildForm` uses `AppTextField`), `child_profile_screen.dart`.
4. **Trips:** `trips_screen.dart`, `trip_details_screen.dart` (timeline draws in), `manage_master_trips_screen.dart`.
5. **Chat:**
   - `chat_list_screen.dart`: polling arrivals animate in and badges pop.
   - `chat_screen.dart`: a shared `ChatBubble` with a slide-in entrance; open at the newest message; the scroll-to-bottom FAB scales in.
   - `user_list_screen.dart`: filtering animates.
6. **Notifications:** `notifications_screen.dart` (tab content crossfade, read-state fade, `CountBadge`, an error state).
7. **Profile and info:**
   - `profile_screen.dart`: hero header, `StatTile` skeletons while loading, and a logout confirm that reuses `confirmDialog`.
   - `edit_profile_screen.dart`.
   - `change_password_screen.dart`: collapse the 4 duplicate success and invalid UIs (~400 lines) into the feedback helpers.
   - Merge `terms_service_screen.dart` and `privacy_policy_screen.dart` into one shared legal-page widget.
   - `about_screen.dart`, `contact_screen.dart`.
8. **Auth and onboarding polish:** `onboarding_screen.dart` moves its 27 raw colours onto tokens; splash, login, forgot, reset and verify-OTP move their entrances onto the `app_motion` presets.
9. **Sweep:**
   - Grep `isDarkMode`, `Color(0x`, `Colors\.(grey|red|green|blue|orange)` and `withValues\(alpha: ?[1-9]`, and fix any leftovers.
   - Delete orphaned helpers and `StaggeredEntrance`.
   - Run `python ~/.claude/skills/flutter-ui/scripts/flutter_ui_audit.py lib`.

### Small, obvious bugs fixed along the way (UI layer only)
- The debug string `'T-minus1'` (`active_trip:1513`).
- The duplicate my-location button (`:1101/1130`).
- The wrong "pending" label (`:3684`).
- The stale student bottom sheet (`:2319`, which should listen to `TripProvider`).
- `StudentPickupBottomSheet` is hardcoded white.
- The `Future.delayed→setState` loop inside a builder (`manage_master_trips:1545`).
- Debug `print`s inside `build`.
- The `[info, info]` "gradients".
- The mock-vehicle long-press is put behind `kDebugMode` (`vehicle_selection:462`).

### Flagged only, not changed (behaviour or content)
- Fake attendant names (`start_trip:1950`).
- The terms page shows privacy text.
- Notification read state never updates `AppProvider.unreadAlertCount`.
- Notification delete is local only.
- Fake `'TRIP_001'` fallbacks (`guardian_trips:880`).

## Constraints
- Keep every handler, provider call, route name, argument and validation rule identical.
- Motion runs only on transform and opacity (the `flutter-ui` GPU-safe rule), with `RepaintBoundary` around map overlays.
- No animation runs longer than 500ms, and every animation respects reduced motion.
- Map performance must not regress: no rebuilds of the `MapWidget` subtree.

## Verification
- On each screen: `flutter analyze` via the dart MCP `analyze_files`, `dart_format`, and `flutter test`.
- Visual check: `launch_app` on an available device or emulator via the dart MCP, `hot_reload`, and screenshots in light and dark mode at phone width.
- If no device is available, fall back to the throwaway golden test from memory (FontLoader for Inter and PlusJakartaSans, `debugDisableShadows=false`), rendered in both themes, and tell the user what could not be checked live.
- With reduced motion (`disableAnimations`) switched on, the screens render statically.
- The driver flow is walked end to end: select trip → vehicle → active trip → pick, drop, absent → complete. Guardian: dashboard → track → trips → chat.

## Progress
- [x] Phase 0: branch `ui-revamp`, `flutter_animate` 4.5.2 added, 11 dead files removed (routes `/live-tracking`, `/driver-map`, `/routes` gone).
- [x] Phase 1: foundations
  - `theme/app_motion.dart`: `enter`, `enterList`, `pop`, `celebrate`. All of them honour reduced motion.
  - `AppDuration.page` and `AppDuration.count`; `AppColors.accentGradient`.
  - New ui/ widgets: `AppBackdrop`/`GlassGlow` and `GlassPanel` (both promoted from the dashboard), `AnimatedCount`, `CountBadge`, `TripProgress`, `StudentStatusStyle`/`StudentStatusRow`/`StatusAvatar`, `SelectableCard`, `BottomActionBar`, `AsyncBody`, `AppListTile`, `SwipeAction`, `SegmentedFilter`.
  - Upgraded: `StatusPill` (cross-fades on change), `StatTile` (whole numbers roll), `EmptyState` (icon pops).
  - Shell:
    - `MainScaffold` has default tab navigation (it skips navigating when you're already on that route).
    - The bottom nav shows unread counts, pops the selected icon, stays in place as a shared hero, and gives haptics.
    - Tab routes use a 180ms fade-through. Pushed routes use a 300ms rise, and the screen underneath recedes.
- [x] Phase 2: pilot `students_list_screen.dart`. Checked in goldens (light + dark, a mid-pick frame, the Picked filter, the action sheet).
  - Learned: `AppButton` already had `loading`. The sheet's Column centres its children, so full-width tiles need `SizedBox(width: infinity)`. The theme's FAB defaults to a pale container, so the main CTA sets primary explicitly.
  - Fixed: `'dropped'` was mapped to `picked`, so the Dropped tab was always empty on load.
  - ponytail: rows that leave a filtered tab after an action vanish rather than animating out. Add `SliverAnimatedList` diffing if that's missed.
- [ ] Checkpoint: waiting for approval.
- [ ] Phase 3 rollout (see order above).

Visual check harness: `test/_revamp_preview_test.dart` + `test/_preview/*.png` (throwaway, delete before merge).
