import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../widgets/main_scaffold.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _currentIndex = 3;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final userData = provider.userData;
    final isDarkMode = provider.isDarkMode;

    return MainScaffold(
      title: 'Profile',
      showBackButton: true,
      showBottomNav: true,
      bottomNavIndex: 3,
      onBottomNavTap: (index) {
        if (index == 0) {
          Navigator.pushReplacementNamed(context, '/landing');
        } else if (index == 1) {
          Navigator.pushNamed(context, '/chat');
        }
      },
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            
            // Profile Header with Avatar
            _buildProfileHeader(userData, isDarkMode),
            
            const SizedBox(height: 24),
            
            // Stats Row
            _buildStatsCard(provider, isDarkMode),
            
            const SizedBox(height: 24),
            
            // Menu Section
            _buildMenuSection(context, isDarkMode),
            
            const SizedBox(height: 24),
            
            // Logout Button
            _buildLogoutButton(context, isDarkMode),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(Map<String, dynamic> userData, bool isDarkMode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6B9B5B), Color(0xFF5A8A4A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6B9B5B).withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar with border
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.5),
                width: 3,
              ),
            ),
            child: CircleAvatar(
              radius: 45,
              backgroundImage: NetworkImage(userData['avatar']),
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          
          // Name
          Text(
            userData['name'],
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          
          // Role Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              userData['role'],
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Contact Info
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.phone_outlined, size: 14, color: Colors.white.withValues(alpha: 0.8)),
              const SizedBox(width: 6),
              Text(
                userData['phone'],
                style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.9)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.email_outlined, size: 14, color: Colors.white.withValues(alpha: 0.8)),
              const SizedBox(width: 6),
              Text(
                userData['email'],
                style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.9)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(AppProvider provider, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              value: provider.totalTrips.toString(),
              label: 'Trips',
              icon: Icons.route_outlined,
              color: const Color(0xFF6B9B5B),
              isDarkMode: isDarkMode,
            ),
          ),
          Container(height: 40, width: 1, color: isDarkMode ? Colors.white24 : Colors.black12),
          Expanded(
            child: _buildStatItem(
              value: provider.completedTrips.toString(),
              label: 'Completed',
              icon: Icons.check_circle_outline,
              color: const Color(0xFF2196F3),
              isDarkMode: isDarkMode,
            ),
          ),
          Container(height: 40, width: 1, color: isDarkMode ? Colors.white24 : Colors.black12),
          Expanded(
            child: _buildStatItem(
              value: '${provider.totalDistance.toStringAsFixed(0)}km',
              label: 'Distance',
              icon: Icons.straighten,
              color: const Color(0xFFFF9800),
              isDarkMode: isDarkMode,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String value,
    required String label,
    required IconData icon,
    required Color color,
    required bool isDarkMode,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDarkMode ? Colors.white60 : const Color(0xFF666666),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuSection(BuildContext context, bool isDarkMode) {
    final menuItems = [
      {
        'icon': Icons.person_outline,
        'title': 'Edit Profile',
        'subtitle': 'Update your information',
        'route': '/edit-profile',
        'color': const Color(0xFF6B9B5B),
      },
      {
        'icon': Icons.lock_outline,
        'title': 'Change Password',
        'subtitle': 'Update your security',
        'route': '/change-password',
        'color': const Color(0xFF2196F3),
      },
      {
        'icon': Icons.notifications_outlined,
        'title': 'Notifications',
        'subtitle': 'Manage alerts',
        'route': null,
        'color': const Color(0xFFFF9800),
      },
      {
        'icon': Icons.description_outlined,
        'title': 'Terms of Service',
        'subtitle': 'Legal information',
        'route': '/terms',
        'color': const Color(0xFF9C27B0),
      },
      {
        'icon': Icons.privacy_tip_outlined,
        'title': 'Privacy Policy',
        'subtitle': 'Data protection',
        'route': '/privacy',
        'color': const Color(0xFF607D8B),
      },
      {
        'icon': Icons.delete_outline,
        'title': 'Delete Account',
        'subtitle': 'Remove your data',
        'route': null,
        'color': const Color(0xFFDC143C),
        'isDestructive': true,
      },
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: menuItems.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return Column(
            children: [
              _buildMenuTile(
                icon: item['icon'] as IconData,
                title: item['title'] as String,
                subtitle: item['subtitle'] as String,
                color: item['color'] as Color,
                isDestructive: item['isDestructive'] as bool? ?? false,
                isDarkMode: isDarkMode,
                onTap: item['route'] != null
                    ? () => Navigator.pushNamed(context, item['route'] as String)
                    : () {},
              ),
              if (index < menuItems.length - 1)
                Divider(
                  height: 1,
                  indent: 72,
                  endIndent: 20,
                  color: isDarkMode ? Colors.white12 : Colors.black.withValues(alpha: 0.05),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool isDestructive,
    required bool isDarkMode,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDestructive ? 0.1 : 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDestructive
              ? color
              : isDarkMode
                  ? Colors.white
                  : const Color(0xFF1A1A1A),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: isDarkMode ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF999999),
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: isDarkMode ? Colors.white.withValues(alpha: 0.4) : const Color(0xFFCCCCCC),
        size: 20,
      ),
      onTap: onTap,
    );
  }

  Widget _buildLogoutButton(BuildContext context, bool isDarkMode) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
        icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 20),
        label: const Text(
          'Logout',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFDC143C),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}
