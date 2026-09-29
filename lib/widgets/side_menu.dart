import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/trip_provider.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme_extension.dart';
import 'autoload_trips_toggle.dart';
import 'ui/ui.dart';

class SideMenu extends StatefulWidget {
  const SideMenu({super.key});

  @override
  State<SideMenu> createState() => _SideMenuState();
}

class _SideMenuState extends State<SideMenu> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: AppDuration.medium,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: AppCurves.easeOut,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(-0.05, 0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: AppCurves.easeOut,
          ),
        );
    _animationController.forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final authProvider = context.watch<AuthProvider>();
    final tripProvider = context.watch<TripProvider>();
    final isDriver = authProvider.isDriver;
    final hasActiveTrip = tripProvider.activeTrip != null;
    final currentRoute = ModalRoute.of(context)?.settings.name;

    return Drawer(
      backgroundColor: context.scheme.surface,
      elevation: 0,
      child: SafeArea(
        child: SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                _buildHeader(context),
                const SizedBox(height: AppSpacing.lg),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    children: [
                      if (isDriver && hasActiveTrip) ...[
                        _buildActiveTripMenuItem(
                          context,
                          tripProvider.activeTrip!.routeName,
                          () => _navigateTo(context, '/active-trip'),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                      ],
                      _buildMenuItem(
                        context,
                        Icons.person_rounded,
                        'Profile',
                        () => _navigateTo(context, '/profile'),
                        isActive: currentRoute == '/profile',
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      _buildMenuItem(
                        context,
                        Icons.directions_bus_outlined,
                        isDriver ? 'Trip History' : 'My Trips',
                        () => _navigateTo(context, '/trips'),
                        isActive: currentRoute == '/trips',
                      ),
                      if (isDriver) ...[
                        _buildMenuItem(
                          context,
                          Icons.event_available_outlined,
                          'Scheduled Trips',
                          () => _navigateTo(context, '/trip-selection'),
                          isActive: currentRoute == '/trip-selection',
                        ),
                        _buildMenuItem(
                          context,
                          Icons.edit_note_rounded,
                          'Manage Trips',
                          () => _navigateTo(context, '/manage-master-trips'),
                          isActive: currentRoute == '/manage-master-trips',
                        ),
                      ],
                      _buildMenuItem(
                        context,
                        Icons.description_outlined,
                        'About Us',
                        () => _navigateTo(context, '/about'),
                        isActive: currentRoute == '/about',
                      ),
                      _buildMenuItem(
                        context,
                        Icons.phone_in_talk_outlined,
                        'Contact',
                        () => _navigateTo(context, '/contact'),
                        isActive: currentRoute == '/contact',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (isDriver) const AutoloadTripsToggle(),
                      _buildThemeToggle(context, provider),
                      const SizedBox(height: AppSpacing.xxl),
                      _buildSocialMediaLinks(context),
                    ],
                  ),
                ),
                _buildLogoutButton(context),
                _buildAppVersion(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.colors.brandSoft,
              borderRadius: AppRadius.brSm,
            ),
            child: Icon(
              Icons.directions_bus_rounded,
              color: context.colors.brand,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'ShuleDrive',
            style: context.text.headlineSmall?.copyWith(
              color: context.colors.brand,
            ),
          ),
        ],
      ),
    );
  }

  /// Menu row. When [isActive] the row is highlighted to mark the current page.
  Widget _buildMenuItem(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap, {
    bool isActive = false,
  }) {
    final brand = context.colors.brand;
    return Material(
      color: isActive ? context.colors.brandSoft : Colors.transparent,
      borderRadius: AppRadius.brMd,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brMd,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              if (isActive)
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: brand.withValues(alpha: 0.18),
                    borderRadius: AppRadius.brSm,
                  ),
                  child: Icon(icon, color: brand, size: 20),
                )
              else
                Icon(icon, color: context.colors.textSecondary, size: 24),
              const SizedBox(width: AppSpacing.md),
              Text(
                title,
                style: isActive
                    ? context.text.titleMedium?.copyWith(color: brand)
                    : context.text.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeToggle(BuildContext context, AppProvider provider) {
    final isDarkMode = context.isDark;
    final isSystemDefault = provider.manualDarkMode == null;
    final brand = context.colors.brand;

    final themeLabel = isSystemDefault
        ? 'System (${isDarkMode ? 'Dark' : 'Light'})'
        : (isDarkMode ? 'Dark Mode' : 'Light Mode');
    final themeIcon = isDarkMode
        ? Icons.dark_mode_outlined
        : Icons.light_mode_outlined;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(themeIcon, color: context.colors.textSecondary, size: 24),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Theme', style: context.text.titleMedium),
                Text(
                  themeLabel,
                  style: context.text.bodySmall?.copyWith(
                    color: context.colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: provider.toggleTheme,
            onLongPress: provider.useSystemTheme,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: isSystemDefault
                    ? context.colors.surfaceSubtle
                    : brand.withValues(alpha: 0.15),
                borderRadius: AppRadius.brPill,
                border: Border.all(
                  color: isSystemDefault
                      ? Colors.transparent
                      : brand.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isDarkMode ? Icons.nights_stay : Icons.wb_sunny,
                    size: 16,
                    color: isSystemDefault ? context.colors.textSecondary : brand,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isDarkMode ? 'Dark' : 'Light',
                    style: context.text.labelMedium?.copyWith(
                      color: isSystemDefault
                          ? context.colors.textSecondary
                          : brand,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialMediaLinks(BuildContext context) {
    final icons = [
      Icons.facebook,
      Icons.close,
      Icons.camera_alt_outlined,
      Icons.business_center_outlined,
    ];
    final brand = context.colors.brand;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: icons.map((icon) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Material(
            color: brand.withValues(alpha: 0.1),
            borderRadius: AppRadius.brPill,
            child: InkWell(
              onTap: () {},
              borderRadius: AppRadius.brPill,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(icon, color: brand, size: 20),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    final error = context.colors.error;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      child: Material(
        color: error.withValues(alpha: 0.1),
        borderRadius: AppRadius.brMd,
        child: InkWell(
          onTap: () => _confirmLogout(context),
          borderRadius: AppRadius.brMd,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.power_settings_new_rounded, color: error, size: 22),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Logout',
                  style: context.text.titleMedium?.copyWith(color: error),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppVersion(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md, top: AppSpacing.xs),
      child: Text(
        'App Version 1.1.1',
        style: context.text.labelSmall?.copyWith(
          color: context.colors.textMuted,
        ),
      ),
    );
  }

  /// Active trip menu item with pulsing brand indicator.
  Widget _buildActiveTripMenuItem(
    BuildContext context,
    String routeName,
    VoidCallback onTap,
  ) {
    final brand = context.colors.brand;
    return Material(
      color: context.colors.brandSoft,
      borderRadius: AppRadius.brMd,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brMd,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: AppRadius.brMd,
            border: Border.all(color: brand.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: brand.withValues(alpha: _pulseAnimation.value),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: brand.withValues(
                            alpha: _pulseAnimation.value * 0.4,
                          ),
                          blurRadius: 6,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.navigation_rounded, color: brand, size: 22),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Active Trip',
                      style: context.text.titleSmall?.copyWith(color: brand),
                    ),
                    Text(
                      routeName,
                      style: context.text.bodySmall?.copyWith(
                        color: brand.withValues(alpha: 0.8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: brand, size: 14),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateTo(BuildContext context, String route) {
    final currentRoute = ModalRoute.of(context)?.settings.name;
    Navigator.pop(context);
    if (currentRoute == route) return; // already here, just close the drawer
    Navigator.pushNamed(context, route);
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Logout',
      message: 'Are you sure you want to logout?',
      confirmLabel: 'Logout',
      icon: Icons.power_settings_new_rounded,
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    Navigator.pop(context); // close drawer
    await context.read<AuthProvider>().logout();
    // Navigation handled by AuthWrapper automatically.
  }
}
