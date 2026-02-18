import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/permission_helper.dart';
import '../../widgets/main_scaffold.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final authProvider = context.watch<AuthProvider>();
    final userData = authProvider.userData;
    final isDarkMode = provider.isDarkMode;
    final userRole = authProvider.userRole;

    return MainScaffold(
      title: 'Profile',
      showBackButton: true,
      showBottomNav: true,
      bottomNavIndex: 3,
      onBottomNavTap: (index) {
        switch (index) {
          case 0:
            Navigator.pushReplacementNamed(context, '/dashboard');
            break;
          case 1:
            Navigator.pushNamed(context, '/chat');
            break;
          case 2:
            Navigator.pushNamed(context, '/notifications');
            break;
          case 3:
            // Already on profile/settings
            break;
          case 4:
            // Center + button
            Navigator.pushNamed(context, '/start-trip');
            break;
        }
      },
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            
            // Profile Header with Avatar
            _buildProfileHeader(userData, isDarkMode, userRole, authProvider),
            
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

  void _showImagePickerOptions(BuildContext parentContext, AuthProvider authProvider) {
    final isDarkMode = parentContext.read<AppProvider>().isDarkMode;

    showModalBottomSheet(
      context: parentContext,
      backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Update Profile Photo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6B9B5B).withValues(alpha: 30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Color(0xFF6B9B5B),
                  ),
                ),
                title: Text(
                  'Take Photo',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                ),
                subtitle: Text(
                  'Use camera to take a photo',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white54 : Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
                onTap: () async {
                  // Close bottom sheet first
                  Navigator.pop(bottomSheetContext);
                  // Small delay to ensure bottom sheet is fully closed
                  await Future.delayed(const Duration(milliseconds: 200));
                  // Check permission and open camera using parent context
                  if (parentContext.mounted) {
                    final hasPermission = await PermissionHelper.requestCameraPermission(parentContext);
                    if (hasPermission && parentContext.mounted) {
                      await _pickAndUploadImage(parentContext, authProvider, ImageSource.camera);
                    }
                  }
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3).withValues(alpha: 30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.photo_library,
                    color: Color(0xFF2196F3),
                  ),
                ),
                title: Text(
                  'Choose from Gallery',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                ),
                subtitle: Text(
                  'Select a photo from your gallery',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white54 : Colors.grey.shade600,
                  ),
                ),
                onTap: () async {
                  // Close bottom sheet first
                  Navigator.pop(bottomSheetContext);
                  // Small delay to ensure bottom sheet is fully closed
                  await Future.delayed(const Duration(milliseconds: 200));
                  // Check permission and open gallery using parent context
                  if (parentContext.mounted) {
                    final hasPermission = await PermissionHelper.requestPhotoLibraryPermission(parentContext);
                    if (hasPermission && parentContext.mounted) {
                      await _pickAndUploadImage(parentContext, authProvider, ImageSource.gallery);
                    }
                  }
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndUploadImage(
    BuildContext context,
    AuthProvider authProvider,
    ImageSource source,
  ) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      if (!context.mounted) return;

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xFF6B9B5B)),
        ),
      );

      final avatarUrl = await authProvider.updateUserAvatar(pickedFile.path);

      if (!context.mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (avatarUrl != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile photo updated successfully'),
            backgroundColor: const Color(0xFF6B9B5B),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to upload photo. Please try again.'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog if open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  Widget _buildProfileHeader(Map<String, dynamic> userData, bool isDarkMode, UserRole userRole, AuthProvider authProvider) {
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
          // Avatar with border and edit button
          GestureDetector(
            onTap: () => _showImagePickerOptions(context, authProvider),
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.5),
                      width: 3,
                    ),
                  ),
                  child: _buildAvatar(userData['avatar']),
                ),
                // Edit icon overlay
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF6B9B5B),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Color(0xFF6B9B5B),
                      size: 18,
                    ),
                  ),
                ),
              ],
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
        'icon': Icons.phone_outlined,
        'title': 'Contact',
        'subtitle': 'Get in touch with us',
        'route': '/contact',
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
        onPressed: () async {
          // Perform logout - AuthWrapper will handle navigation
          final authProvider = context.read<AuthProvider>();
          await authProvider.logout();
        },
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

  Widget _buildAvatar(dynamic avatarUrl) {
    // Check if it's a valid network URL
    if (avatarUrl != null &&
        avatarUrl is String &&
        avatarUrl.isNotEmpty &&
        (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://'))) {
      return CircleAvatar(
        radius: 45,
        backgroundImage: NetworkImage(avatarUrl),
        backgroundColor: Colors.white,
        onBackgroundImageError: (e, s) {
          if (kDebugMode) print('⚠️ Failed to load avatar: $e');
        },
      );
    }

    // Fallback to default avatar
    return const CircleAvatar(
      radius: 45,
      backgroundColor: Colors.white,
      child: Icon(
        Icons.person,
        size: 45,
        color: Color(0xFF6B9B5B),
      ),
    );
  }
}
