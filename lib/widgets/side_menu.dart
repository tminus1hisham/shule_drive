import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../providers/auth_provider.dart';

class SideMenu extends StatefulWidget {
  const SideMenu({super.key});

  @override
  State<SideMenu> createState() => _SideMenuState();
}

class _SideMenuState extends State<SideMenu> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(-0.3, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final authProvider = context.watch<AuthProvider>();
    final isDarkMode = provider.isDarkMode;
    final isDriver = authProvider.isDriver;

    return Drawer(
      backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      elevation: 0,
      child: SafeArea(
        child: SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                // Header with Logo
                _buildHeader(isDarkMode),

                const SizedBox(height: 24),

                // Menu Items
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      // Profile - Highlighted
                      _buildHighlightedMenuItem(
                        Icons.person,
                        'Profile',
                        () => _navigateTo(context, '/profile'),
                      ),

                      const SizedBox(height: 8),

                      // Trips - Different views for drivers vs guardians
                      _buildMenuItem(
                        Icons.directions_bus_outlined,
                        isDriver ? 'Trip History' : 'My Trips',
                        () => _navigateTo(context, '/trips'),
                        isDarkMode: isDarkMode,
                      ),

                      // About Us
                      _buildMenuItem(
                        Icons.description_outlined,
                        'About Us',
                        () => _navigateTo(context, '/about'),
                        isDarkMode: isDarkMode,
                      ),

                      // Contact
                      _buildMenuItem(
                        Icons.phone_in_talk_outlined,
                        'Contact',
                        () => _navigateTo(context, '/contact'),
                        isDarkMode: isDarkMode,
                      ),

                      const SizedBox(height: 16),

                      // Theme Toggle
                      _buildThemeToggle(provider, isDarkMode),

                      const SizedBox(height: 32),

                      // Social Media Icons
                      _buildSocialMediaLinks(isDarkMode),
                    ],
                  ),
                ),

                // Logout Button
                _buildLogoutButton(isDarkMode),

                // App Version
                _buildAppVersion(isDarkMode),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Logo Icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF6B9B5B).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.directions_bus,
                  color: Color(0xFF6B9B5B),
                  size: 24,
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF6B9B5B),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // App Name
          Text(
            'ShuleDrive',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : const Color(0xFF6B9B5B),
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightedMenuItem(
    IconData icon,
    String title,
    VoidCallback onTap,
  ) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.95 + (0.05 * value),
          child: child,
        );
      },
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF6B9B5B).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF6B9B5B).withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF6B9B5B).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFF6B9B5B),
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B9B5B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    IconData icon,
    String title,
    VoidCallback onTap, {
    required bool isDarkMode,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isDarkMode ? Colors.white70 : const Color(0xFF666666),
                  size: 24,
                ),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? Colors.white : const Color(0xFF333333),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeToggle(AppProvider provider, bool isDarkMode) {
    final isSystemDefault = provider.manualDarkMode == null;
    
    // Determine display label and icon
    final String themeLabel;
    final IconData themeIcon;
    if (isSystemDefault) {
      themeLabel = 'System (${isDarkMode ? 'Dark' : 'Light'})';
      themeIcon = isDarkMode ? Icons.dark_mode_outlined : Icons.light_mode_outlined;
    } else {
      themeLabel = isDarkMode ? 'Dark Mode' : 'Light Mode';
      themeIcon = isDarkMode ? Icons.dark_mode_outlined : Icons.light_mode_outlined;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(
            themeIcon,
            color: isDarkMode ? Colors.white70 : const Color(0xFF666666),
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Theme',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? Colors.white : const Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  themeLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.white54 : const Color(0xFF999999),
                  ),
                ),
              ],
            ),
          ),
          // Theme toggle button
          GestureDetector(
            onTap: () {
              if (isSystemDefault) {
                // Switch to manual override (opposite of current system)
                provider.toggleTheme();
              } else {
                // Toggle between light and dark manually
                provider.toggleTheme();
              }
            },
            onLongPress: () {
              // Long press to reset to system default
              provider.useSystemTheme();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSystemDefault
                    ? (isDarkMode ? Colors.white24 : Colors.grey.shade200)
                    : const Color(0xFF6B9B5B).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSystemDefault
                      ? Colors.transparent
                      : const Color(0xFF6B9B5B).withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isDarkMode ? Icons.nights_stay : Icons.wb_sunny,
                    size: 16,
                    color: isDarkMode 
                        ? (isSystemDefault ? Colors.white70 : const Color(0xFF6B9B5B))
                        : (isSystemDefault ? const Color(0xFF666666) : const Color(0xFF6B9B5B)),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isDarkMode ? 'Dark' : 'Light',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode 
                          ? (isSystemDefault ? Colors.white70 : const Color(0xFF6B9B5B))
                          : (isSystemDefault ? const Color(0xFF666666) : const Color(0xFF6B9B5B)),
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

  Widget _buildSocialMediaLinks(bool isDarkMode) {
    final socialLinks = [
      _SocialLink(
        icon: Icons.facebook,
        color: const Color(0xFF6B9B5B),
        url: 'https://facebook.com/shuledrive',
      ),
      _SocialLink(
        icon: Icons.close, // Using close as X icon
        color: const Color(0xFF6B9B5B),
        url: 'https://twitter.com/shuledrive',
      ),
      _SocialLink(
        icon: Icons.camera_alt_outlined, // Using camera for Instagram
        color: const Color(0xFF6B9B5B),
        url: 'https://instagram.com/shuledrive',
      ),
      _SocialLink(
        icon: Icons.business_center_outlined, // Using for LinkedIn
        color: const Color(0xFF6B9B5B),
        url: 'https://linkedin.com/company/shuledrive',
      ),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: socialLinks.asMap().entries.map((entry) {
        final index = entry.key;
        final link = entry.value;
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 400 + (index * 100)),
          curve: Curves.easeOutBack,
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: child,
            );
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            child: Material(
              color: const Color(0xFF6B9B5B).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(50),
              child: InkWell(
                onTap: () {},
                borderRadius: BorderRadius.circular(50),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Icon(
                    link.icon,
                    color: link.color,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLogoutButton(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.9, end: 1),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: child,
          );
        },
        child: GestureDetector(
          onTap: () => _showLogoutConfirmation(context),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFFFCDD2),
                width: 1,
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.power_settings_new,
                  color: Color(0xFFE53935),
                  size: 22,
                ),
                SizedBox(width: 10),
                Text(
                  'Logout',
                  style: TextStyle(
                    color: Color(0xFFE53935),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppVersion(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: Text(
        'App Version 1.1.1',
        style: TextStyle(
          fontSize: 12,
          color: isDarkMode ? Colors.white38 : const Color(0xFFAAAAAA),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _navigateTo(BuildContext context, String route) {
    Navigator.pop(context);
    Navigator.pushNamed(context, route);
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Logout',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF666666)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // Perform logout
              final authProvider = context.read<AuthProvider>();
              await authProvider.logout();
              // Navigation will be handled by AuthWrapper automatically
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

class _SocialLink {
  final IconData icon;
  final Color color;
  final String url;

  _SocialLink({
    required this.icon,
    required this.color,
    required this.url,
  });
}
