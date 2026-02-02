import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class SideMenu extends StatelessWidget {
  const SideMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final userData = provider.userData;

    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6B9B5B),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.directions_bus,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'ShuleDrive',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B9B5B),
                    ),
                  ),
                ],
              ),
            ),

            // User Info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundImage: NetworkImage(userData['avatar']),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userData['name'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          userData['role'],
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B9B5B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Menu Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _buildMenuItem(
                    Icons.person_outline,
                    'Profile',
                    () => Navigator.pushNamed(context, '/profile'),
                  ),
                  _buildMenuItem(
                    Icons.route_outlined,
                    'Trips',
                    () => Navigator.pushNamed(context, '/trips'),
                  ),
                  _buildMenuItem(
                    Icons.info_outline,
                    'About Us',
                    () => Navigator.pushNamed(context, '/about'),
                  ),
                  _buildMenuItem(
                    Icons.contact_support_outlined,
                    'Contact',
                    () => Navigator.pushNamed(context, '/contact'),
                  ),
                  const Divider(height: 32),
                  _buildMenuItem(
                    Icons.palette_outlined,
                    'Theme',
                    () {},
                    trailing: Switch(
                      value: provider.isDarkMode,
                      onChanged: (value) => provider.toggleTheme(),
                      activeThumbColor: const Color(0xFF6B9B5B),
                    ),
                  ),
                ],
              ),
            ),

            // Logout
            Padding(
              padding: const EdgeInsets.all(20),
              child: GestureDetector(
                onTap: () => Navigator.pushReplacementNamed(context, '/login'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout, color: Color(0xFFDC143C), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Logout',
                        style: TextStyle(
                          color: Color(0xFFDC143C),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    IconData icon,
    String title,
    VoidCallback onTap, {
    Widget? trailing,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF666666), size: 22),
      title: Text(
        title,
        style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A1A)),
      ),
      trailing:
          trailing ?? const Icon(Icons.chevron_right, color: Color(0xFF999999)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
