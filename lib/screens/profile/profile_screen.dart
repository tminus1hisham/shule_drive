import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../widgets/bottom_navigation.dart';

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

    return Scaffold(
      backgroundColor: provider.backgroundColor,
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F0),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF6B9B5B).withValues(alpha: 0.3),
                      isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F0),
                    ],
                  ),
                ),
              ),
            ),
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDarkMode 
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.white.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
                  size: 20,
                ),
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          
          // Profile Content
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -80),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    // Profile Card
                    _buildProfileCard(userData, isDarkMode),
                    
                    const SizedBox(height: 20),
                    
                    // Stats Row
                    _buildStatsRow(provider, isDarkMode),
                    
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
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigation(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          if (index == 0) {
            Navigator.pushReplacementNamed(context, '/landing');
          } else if (index == 1) {
            Navigator.pushNamed(context, '/chat');
          }
        },
      ),
    );
  }

  Widget _buildProfileCard(Map<String, dynamic> userData, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.3 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar with border
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF6B9B5B),
                    width: 3,
                  ),
                ),
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage: NetworkImage(userData['avatar']),
                ),
              ),
              Positioned(
                bottom: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6B9B5B), Color(0xFF5A8A4A)],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white, width: 3),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Name
          Text(
            userData['name'],
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          
          // Role Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF6B9B5B).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              userData['role'],
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B9B5B),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Contact Info
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.phone_outlined,
                size: 16,
                color: isDarkMode ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF666666),
              ),
              const SizedBox(width: 8),
              Text(
                userData['phone'],
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode ? Colors.white70 : const Color(0xFF666666),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.email_outlined,
                size: 16,
                color: isDarkMode ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF666666),
              ),
              const SizedBox(width: 8),
              Text(
                userData['email'],
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode ? Colors.white70 : const Color(0xFF666666),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Edit Profile Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/edit-profile'),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text(
                'Edit Profile',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B9B5B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(AppProvider provider, bool isDarkMode) {
    return Row(
      children: [
        Expanded(
          child: _buildStatItem(
            value: provider.totalTrips.toString(),
            label: 'Trips',
            isDarkMode: isDarkMode,
          ),
        ),
        Container(
          height: 40,
          width: 1,
          color: isDarkMode ? Colors.white24 : Colors.black12,
        ),
        Expanded(
          child: _buildStatItem(
            value: provider.completedTrips.toString(),
            label: 'Completed',
            isDarkMode: isDarkMode,
          ),
        ),
        Container(
          height: 40,
          width: 1,
          color: isDarkMode ? Colors.white24 : Colors.black12,
        ),
        Expanded(
          child: _buildStatItem(
            value: '${provider.totalDistance.toStringAsFixed(0)}km',
            label: 'Distance',
            isDarkMode: isDarkMode,
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem({
    required String value,
    required String label,
    required bool isDarkMode,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDarkMode ? Colors.white60 : const Color(0xFF666666),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuSection(BuildContext context, bool isDarkMode) {
    final menuItems = [
      {
        'icon': Icons.lock_outline,
        'title': 'Change Password',
        'subtitle': 'Update your security',
        'route': '/change-password',
        'color': const Color(0xFF6B9B5B),
      },
      {
        'icon': Icons.notifications_outlined,
        'title': 'Notifications',
        'subtitle': 'Manage alerts',
        'route': null,
        'color': const Color(0xFF2196F3),
      },
      {
        'icon': Icons.description_outlined,
        'title': 'Terms of Service',
        'subtitle': 'Legal information',
        'route': '/terms',
        'color': const Color(0xFFFF9800),
      },
      {
        'icon': Icons.privacy_tip_outlined,
        'title': 'Privacy Policy',
        'subtitle': 'Data protection',
        'route': '/privacy',
        'color': const Color(0xFF9C27B0),
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
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: menuItems.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          indent: 72,
          color: isDarkMode ? Colors.white12 : Colors.black.withValues(alpha: 0.05),
        ),
        itemBuilder: (context, index) {
          final item = menuItems[index];
          return _buildMenuTile(
            icon: item['icon'] as IconData,
            title: item['title'] as String,
            subtitle: item['subtitle'] as String,
            color: item['color'] as Color,
            isDestructive: item['isDestructive'] as bool? ?? false,
            isDarkMode: isDarkMode,
            onTap: item['route'] != null
                ? () => Navigator.pushNamed(context, item['route'] as String)
                : () {},
          );
        },
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDestructive
              ? color.withValues(alpha: 0.1)
              : color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: isDestructive ? color : color,
          size: 20,
        ),
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
      trailing: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade100,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.chevron_right,
          color: isDarkMode ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF999999),
          size: 18,
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _buildLogoutButton(BuildContext context, bool isDarkMode) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: ElevatedButton.icon(
        onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
        icon: const Icon(Icons.logout_rounded, color: Colors.white),
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
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}
