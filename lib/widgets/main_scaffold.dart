import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import 'side_menu.dart';
import 'bottom_navigation.dart';

/// A scaffold wrapper that provides the side menu drawer to all screens
/// Use this for all screens after login
class MainScaffold extends StatelessWidget {
  final Widget body;
  final String? title;
  final bool showBottomNav;
  final int bottomNavIndex;
  final Function(int)? onBottomNavTap;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final List<Widget>? actions;
  final bool centerTitle;
  final Widget? leading;
  final bool showBackButton;

  const MainScaffold({
    super.key,
    required this.body,
    this.title,
    this.showBottomNav = false,
    this.bottomNavIndex = 0,
    this.onBottomNavTap,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.actions,
    this.centerTitle = true,
    this.leading,
    this.showBackButton = false,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isDarkMode = provider.isDarkMode;

    return Scaffold(
      backgroundColor: provider.backgroundColor,
      drawer: const SideMenu(),
      appBar: title != null || showBackButton
          ? AppBar(
              backgroundColor: provider.backgroundColor,
              elevation: 0,
              centerTitle: centerTitle,
              leading: leading ?? (showBackButton 
                  ? IconButton(
                      icon: Icon(
                        Icons.arrow_back_ios,
                        color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
                      ),
                      onPressed: () => Navigator.pop(context),
                    )
                  : null),
              title: title != null
                  ? Text(
                      title!,
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : null,
              actions: actions,
            )
          : null,
      body: GestureDetector(
        // Enable swipe from left edge to open drawer
        onHorizontalDragStart: (details) {
          if (details.globalPosition.dx < 20) {
            Scaffold.of(context).openDrawer();
          }
        },
        child: body,
      ),
      bottomNavigationBar: showBottomNav
          ? BottomNavigation(
              currentIndex: bottomNavIndex,
              onTap: onBottomNavTap ?? (index) {},
            )
          : null,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
    );
  }
}
