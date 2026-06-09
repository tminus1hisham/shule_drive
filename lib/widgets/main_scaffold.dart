import 'package:flutter/material.dart';
import '../theme/app_theme_extension.dart';
import 'side_menu.dart';
import 'bottom_navigation.dart';

/// A scaffold wrapper that provides the side menu drawer to all screens
/// Use this for all screens after login
class MainScaffold extends StatefulWidget {
  final Widget body;
  final String? title;
  final Widget? titleWidget;
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
    this.titleWidget,
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
    // Determine if we should show an app bar
    final bool showAppBar = widget.title != null || widget.showBackButton || widget.showMenuButton;

    return Scaffold(
      drawer: const SideMenu(),
      appBar: showAppBar
          ? AppBar(
              centerTitle: widget.centerTitle,
              leading: widget.leading ?? _buildLeadingButton(context),
              title: widget.titleWidget ??
                  (widget.title != null ? Text(widget.title!) : null),
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
