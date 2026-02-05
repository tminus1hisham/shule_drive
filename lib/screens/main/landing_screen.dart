import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/bus_illustration.dart';
import '../../widgets/main_scaffold.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  @override
  void initState() {
    super.initState();
    // Redirect to DashboardScreen immediately
    // This screen is deprecated, use DashboardScreen instead
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacementNamed(context, '/dashboard');
    });
  }

  void _handleNavigation(int index) {
    switch (index) {
      case 0:
        // Navigate to Dashboard (consistent home)
        Navigator.pushReplacementNamed(context, '/dashboard');
        break;
      case 1:
        Navigator.pushNamed(context, '/chat');
        break;
      case 2:
        Navigator.pushNamed(context, '/notifications');
        break;
      case 3:
        Navigator.pushNamed(context, '/profile');
        break;
      case 4:
        // Center + button - only for drivers
        Navigator.pushNamed(context, '/start-trip');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final authProvider = context.watch<AuthProvider>();
    final isDarkMode = provider.isDarkMode;
    final userData = authProvider.userData;
    final cardColor = provider.cardColor;
    final textColor = provider.textColor;
    final textMutedColor = provider.textMutedColor;
    final isDriver = authProvider.isDriver;
    final isGuardian = authProvider.isGuardian;

    return MainScaffold(
      showBottomNav: true,
      bottomNavIndex: 0,
      onBottomNavTap: _handleNavigation,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _buildHeader(userData, isDarkMode, textColor),
            ),
            SliverToBoxAdapter(
              child: _buildGreeting(userData, isDriver, isDarkMode, textColor, textMutedColor),
            ),
            SliverToBoxAdapter(
              child: isDriver 
                ? _buildDriverTripCard(context, isDarkMode, cardColor, textColor, textMutedColor)
                : _buildGuardianDashboard(context, isDarkMode, cardColor, textColor, textMutedColor),
            ),
            SliverToBoxAdapter(
              child: _buildFeaturesSection(context, isDriver, isGuardian, isDarkMode, cardColor, textColor, textMutedColor),
            ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic> userData, bool isDarkMode, Color textColor) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6B9B5B), Color(0xFF5A8A4A)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6B9B5B).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.directions_bus,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'ShuleDrive',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/profile'),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF6B9B5B).withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  userData['avatar'],
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGreeting(Map<String, dynamic> userData, bool isDriver, bool isDarkMode, Color textColor, Color textMutedColor) {
    final subtitle = isDriver 
      ? 'Ready to start your driving day?'
      : 'Track your children\'s journey safely.';
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isDarkMode 
                  ? Colors.white.withValues(alpha: 0.1)
                  : const Color(0xFF6B9B5B).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isDriver ? Icons.local_shipping_outlined : Icons.family_restroom,
                  size: 14,
                  color: isDarkMode ? Colors.white70 : const Color(0xFF6B9B5B),
                ),
                const SizedBox(width: 6),
                Text(
                  isDriver ? 'Driver' : 'Guardian',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white70 : const Color(0xFF6B9B5B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            userData['name'].split(' ').first,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: textColor,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 16,
              color: textMutedColor,
            ),
          ),
        ],
      ),
    );
  }

  // Driver Widget - Shows trip card
  Widget _buildDriverTripCard(BuildContext context, bool isDarkMode, Color cardColor, Color textColor, Color textMutedColor) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF6B9B5B).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const BusIllustration(height: 120),
          ),
          const SizedBox(height: 24),
          Text(
            'No Active Trip',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Let\'s get today\'s trip started! Tap the button below to begin.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: textMutedColor,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/start-trip'),
              icon: const Icon(Icons.add_circle_outline, size: 22),
              label: const Text(
                'Start New Trip',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B9B5B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Guardian Widget - Shows children overview
  Widget _buildGuardianDashboard(BuildContext context, bool isDarkMode, Color cardColor, Color textColor, Color textMutedColor) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF2196F3).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.family_restroom,
              size: 60,
              color: const Color(0xFF2196F3),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Your Children',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Monitor your children\'s school transportation in real-time.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: textMutedColor,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/manage-children'),
                    icon: const Icon(Icons.child_care, size: 22),
                    label: const Text(
                      'My Children',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesSection(BuildContext context, bool isDriver, bool isGuardian, bool isDarkMode, Color cardColor, Color textColor, Color textMutedColor) {
    // Different features based on user role
    final driverFeatures = [
      {
        'icon': Icons.route_outlined,
        'title': 'Routes',
        'subtitle': 'View assigned routes',
        'color': const Color(0xFF6B9B5B),
        'route': '/routes',
      },
      {
        'icon': Icons.people_outline,
        'title': 'Students',
        'subtitle': 'View student list',
        'color': const Color(0xFF2196F3),
        'route': '/students-list',
      },
      {
        'icon': Icons.history,
        'title': 'History',
        'subtitle': 'Trip history',
        'color': const Color(0xFFFF9800),
        'route': '/trips',
      },
      {
        'icon': Icons.chat_bubble_outline,
        'title': 'Messages',
        'subtitle': 'Chat with guardians',
        'color': const Color(0xFFE91E63),
        'route': '/chat',
      },
    ];

    final guardianFeatures = [
      {
        'icon': Icons.child_care,
        'title': 'My Children',
        'subtitle': 'Manage children',
        'color': const Color(0xFF2196F3),
        'route': '/manage-children',
      },
      {
        'icon': Icons.route_outlined,
        'title': 'Routes',
        'subtitle': 'View bus routes',
        'color': const Color(0xFF6B9B5B),
        'route': '/routes',
      },
      {
        'icon': Icons.history,
        'title': 'History',
        'subtitle': 'Trip history',
        'color': const Color(0xFFFF9800),
        'route': '/trips',
      },
      {
        'icon': Icons.chat_bubble_outline,
        'title': 'Messages',
        'subtitle': 'Chat with driver',
        'color': const Color(0xFFE91E63),
        'route': '/chat',
      },
    ];

    final features = isDriver ? driverFeatures : guardianFeatures;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Access',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.5,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: features.length,
            itemBuilder: (context, index) {
              final feature = features[index];
              return _buildFeatureCard(
                icon: feature['icon'] as IconData,
                title: feature['title'] as String,
                subtitle: feature['subtitle'] as String,
                color: feature['color'] as Color,
                cardColor: cardColor,
                textColor: textColor,
                textMutedColor: textMutedColor,
                isDarkMode: isDarkMode,
                onTap: () => Navigator.pushNamed(context, feature['route'] as String),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Color cardColor,
    required Color textColor,
    required Color textMutedColor,
    required bool isDarkMode,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const Spacer(),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: textMutedColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
