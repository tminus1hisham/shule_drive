import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import 'side_menu.dart';
import 'bottom_navigation.dart';

/// A scaffold wrapper that provides the side menu drawer to all screens
/// Use this for all screens after login
class MainScaffold extends StatefulWidget {
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
  final bool showMenuButton;

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
    this.showMenuButton = false,
  });

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isDarkMode = provider.isDarkMode;

    // Determine if we should show an app bar
    final bool showAppBar = widget.title != null || widget.showBackButton || widget.showMenuButton;

    return Scaffold(
      backgroundColor: provider.backgroundColor,
      drawer: const SideMenu(),
      appBar: showAppBar
          ? AppBar(
              backgroundColor: provider.backgroundColor,
              elevation: 0,
              centerTitle: widget.centerTitle,
              leading: widget.leading ?? _buildLeadingButton(isDarkMode),
              title: widget.title != null
                  ? Text(
                      widget.title!,
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : null,
              actions: widget.actions,
            )
          : null,
      body: widget.body,
      bottomNavigationBar: widget.showBottomNav
          ? BottomNavigation(
              currentIndex: widget.bottomNavIndex,
              onTap: (index) {
                if (index == 4) {
                  // Center action button - navigate to start trip
                  Navigator.pushNamed(context, '/start-trip');
                } else {
                  widget.onBottomNavTap?.call(index);
                }
              },
            )
          : null,
      floatingActionButton: widget.floatingActionButton,
      floatingActionButtonLocation: widget.floatingActionButtonLocation,
    );
  }

  /// Build the leading button (back button or menu button)
  Widget? _buildLeadingButton(bool isDarkMode) {
    if (widget.showBackButton) {
      return IconButton(
        icon: Icon(
          Icons.arrow_back_ios,
          color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
        ),
        onPressed: () => Navigator.pop(context),
      );
    }
    
    if (widget.showMenuButton) {
      return Builder(
        builder: (context) => IconButton(
          icon: Icon(
            Icons.menu,
            color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
          ),
          onPressed: () {
            Scaffold.of(context).openDrawer();
          },
        ),
      );
    }
    
    return null;
  }
}
