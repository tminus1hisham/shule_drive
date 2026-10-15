import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/services/trip_service.dart' show Trip;
import '../providers/trip_provider.dart';
import '../theme/app_theme_extension.dart';
import 'ui/ui.dart' show AppSnackbar;
import 'side_menu.dart';
import 'bottom_navigation.dart';

/// Mirrors the navigator stack so a non-tab page can find the tab it was
/// opened from.
class TabTracker extends NavigatorObserver {
  final _stack = <Route<dynamic>>[];

  static const _tabOf = {
    '/': 0,
    '/dashboard': 0,
    '/home': 0,
    '/landing': 0,
    '/chat': 1,
    '/notifications': 2,
    '/profile': 3,
  };

  /// Tab of the nearest tab route below [route]; Home when there is none.
  int originTab(Route<dynamic>? route) {
    final at = route == null ? -1 : _stack.indexOf(route);
    for (var i = at - 1; i >= 0; i--) {
      final tab = _tabOf[_stack[i].settings.name];
      if (tab != null) return tab;
    }
    return 0;
  }

  @override
  void didPush(Route route, Route? previousRoute) => _stack.add(route);

  @override
  void didPop(Route route, Route? previousRoute) => _stack.remove(route);

  @override
  void didRemove(Route route, Route? previousRoute) => _stack.remove(route);

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    final i = oldRoute == null ? -1 : _stack.indexOf(oldRoute);
    if (i >= 0 && newRoute != null) {
      _stack[i] = newRoute;
    } else if (newRoute != null) {
      _stack.add(newRoute);
    }
  }
}

final tabTracker = TabTracker();

/// The driver's trip entry point: the live trip map when a trip is running,
/// otherwise the start-trip flow. Navbar, dashboard and side menu all route
/// here so they land on the same trip view.
void openDriverTrip(BuildContext context) {
  final active = context.read<TripProvider>().activeTrip;
  if (active == null) {
    Navigator.pushNamed(context, '/start-trip');
    return;
  }
  Navigator.pushNamed(
    context,
    '/osm-tracking',
    arguments: {'tripId': active.id, 'preloadedData': null},
  );
}

/// Guardians chat with the trip's driver directly; the driver's trip group
/// messages land in this same thread. Dashboard and live map both use it.
void openDriverChat(BuildContext context, Trip trip) {
  final driverPhone = trip.driverPhone;
  if (driverPhone == null) {
    AppSnackbar.info(context, "The driver's contact isn't available yet");
    return;
  }
  Navigator.pushNamed(
    context,
    '/chat-detail',
    arguments: {
      'tripId': trip.id,
      'receiverPhone': driverPhone,
      'receiverName': trip.driverName ?? 'Driver - ${trip.routeName}',
      'receiverRole': 'Driver',
      'isTripChat': true,
    },
  );
}

/// A scaffold wrapper that provides the side menu drawer to all screens
/// Use this for all screens after login
class MainScaffold extends StatefulWidget {
  final Widget body;
  final String? title;
  final Widget? titleWidget;
  final bool showBottomNav;

  /// Tab to highlight. Leave null on non-tab pages (About, Trips, ...) so
  /// they highlight the tab they were opened from.
  final int? bottomNavIndex;

  /// Overrides the default tab navigation (index 4 always opens start-trip).
  final Function(int)? onBottomNavTap;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final List<Widget>? actions;
  final bool centerTitle;
  final Widget? leading;
  final bool showBackButton;
  final bool showMenuButton;

  /// Sticky footer (e.g. a [BottomActionBar]); takes the place of the tab bar.
  final Widget? bottomBar;

  const MainScaffold({
    super.key,
    required this.body,
    this.title,
    this.titleWidget,
    this.showBottomNav = false,
    this.bottomNavIndex,
    this.onBottomNavTap,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.actions,
    this.centerTitle = true,
    this.leading,
    this.showBackButton = false,
    this.showMenuButton = false,
    this.bottomBar,
  });

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  @override
  Widget build(BuildContext context) {
    // Determine if we should show an app bar
    final bool showAppBar =
        widget.title != null || widget.showBackButton || widget.showMenuButton;

    return Scaffold(
      drawer: const SideMenu(),
      appBar: showAppBar
          ? AppBar(
              centerTitle: widget.centerTitle,
              leading: widget.leading ?? _buildLeadingButton(context),
              title:
                  widget.titleWidget ??
                  (widget.title != null ? Text(widget.title!) : null),
              actions: widget.actions,
            )
          : null,
      body: widget.body,
      bottomNavigationBar:
          widget.bottomBar ??
          (widget.showBottomNav
              ? BottomNavigation(
                  currentIndex:
                      widget.bottomNavIndex ??
                      tabTracker.originTab(ModalRoute.of(context)),
                  onTap: (index) {
                    if (index == 4) {
                      openDriverTrip(context);
                    } else if (widget.onBottomNavTap != null) {
                      widget.onBottomNavTap!(index);
                    } else {
                      _goToTab(index);
                    }
                  },
                )
              : null),
      floatingActionButton: widget.floatingActionButton,
      floatingActionButtonLocation: widget.floatingActionButtonLocation,
    );
  }

  static const _tabRoutes = [
    '/dashboard',
    '/chat',
    '/notifications',
    '/profile',
  ];

  /// Default tab navigation, so screens don't each re-implement the switch.
  /// Does nothing when that tab is already the current route.
  void _goToTab(int index) {
    if (index < 0 || index >= _tabRoutes.length) return;
    final target = _tabRoutes[index];
    final current = ModalRoute.of(context)?.settings.name;
    final onHome = const {
      '/',
      '/dashboard',
      '/home',
      '/landing',
    }.contains(current);
    if (current == target || (index == 0 && onHome)) return;
    if (index == 0) {
      Navigator.pushReplacementNamed(context, target);
    } else {
      Navigator.pushNamed(context, target);
    }
  }

  /// Build the leading button (back button or menu button)
  Widget? _buildLeadingButton(BuildContext context) {
    if (widget.showBackButton) {
      return IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
        color: context.scheme.onSurface,
        tooltip: 'Back',
        onPressed: () => Navigator.pop(context),
      );
    }

    if (widget.showMenuButton) {
      return Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu_rounded),
          color: context.scheme.onSurface,
          tooltip: 'Menu',
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      );
    }

    return null;
  }
}
