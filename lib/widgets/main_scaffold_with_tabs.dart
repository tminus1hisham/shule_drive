import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/main/landing_screen.dart';
import '../screens/main/home_screen.dart';
import '../screens/chat/chat_list_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/main/start_trip_screen.dart';
import 'bottom_navigation.dart';
import 'side_menu.dart';

/// MainScaffoldWithTabs - Persistent tab navigation without route pushing
/// Keeps all tabs in memory for instant switching
class MainScaffoldWithTabs extends StatefulWidget {
  const MainScaffoldWithTabs({super.key});

  @override
  State<MainScaffoldWithTabs> createState() => _MainScaffoldWithTabsState();
}

class _MainScaffoldWithTabsState extends State<MainScaffoldWithTabs> {
  int _currentIndex = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    // Initialize pages based on user role
    final authProvider = context.read<AuthProvider>();
    final isDriver = authProvider.isDriver;

    _pages = [
      isDriver ? const LandingScreen() : const HomeScreen(), // Main screen
      const ChatListScreen(), // Chat
      const NotificationsScreen(), // Notifications
      const ProfileScreen(), // Settings/Profile
      if (isDriver) const StartTripScreen(), // Start trip (driver only)
    ];
  }

  void _onTabTapped(int index) {
    if (index == _currentIndex) return;

    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isDriver = authProvider.isDriver;

    // Calculate actual tab index (excluding center button for guardians)
    int actualIndex = _currentIndex;
    if (!isDriver && _currentIndex >= 4) {
      actualIndex = _currentIndex - 1;
    }

    return Scaffold(
      drawer: const SideMenu(),
      body: IndexedStack(
        index: actualIndex < _pages.length ? actualIndex : 0,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigation(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
      ),
    );
  }
}

/// Extension to wrap screens that need the persistent tabs
/// Use this for screens that should have the bottom navigation
class TabAwareScreen extends StatelessWidget {
  final Widget child;
  final int tabIndex;
  final String? title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  const TabAwareScreen({
    super.key,
    required this.child,
    required this.tabIndex,
    this.title,
    this.actions,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: title != null
          ? AppBar(title: Text(title!), actions: actions)
          : null,
      body: child,
      floatingActionButton: floatingActionButton,
    );
  }
}
