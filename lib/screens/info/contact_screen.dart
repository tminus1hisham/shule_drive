import 'package:flutter/material.dart';
import '../../widgets/main_scaffold.dart';
import '../../providers/app_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_colors.dart';
class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  int _currentIndex = 3;

  Future<void> _launchPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchMaps(String address) async {
    // Try to launch using geo URI scheme for better map app support
    final query = Uri.encodeComponent(address);
    final geoUri = Uri.parse('geo:0,0?q=$query');

    if (await canLaunchUrl(geoUri)) {
      await launchUrl(geoUri);
    } else {
      // Fallback to Google Maps web URL
      final mapsUri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$query',
      );
      if (await canLaunchUrl(mapsUri)) {
        await launchUrl(mapsUri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return MainScaffold(
      title: 'Contact Us',
      showBackButton: true,
      showBottomNav: false,
      bottomNavIndex: _currentIndex,
      onBottomNavTap: (index) {
        setState(() => _currentIndex = index);
        if (index == 0) {
          Navigator.pushReplacementNamed(context, '/dashboard');
        }
      },
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: provider.cardColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Get in Touch',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: provider.textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'We\'d love to hear from you',
                    style: TextStyle(
                      fontSize: 14,
                      color: provider.textMutedColor,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Phone Numbers
                  _buildContactItem(
                    provider,
                    Icons.phone,
                    '+254 750 003304',
                    'Nairobi Office',
                    () => _launchPhone('+254750003304'),
                  ),
                  Divider(
                    height: 32,
                    color: provider.textMutedColor.withValues(alpha: 0.2),
                  ),
                  _buildContactItem(
                    provider,
                    Icons.phone,
                    '+254 712 345 678',
                    'Customer Support - Always Active',
                    () => _launchPhone('+254712345678'),
                  ),
                  Divider(
                    height: 32,
                    color: provider.textMutedColor.withValues(alpha: 0.2),
                  ),
                  _buildContactItem(
                    provider,
                    Icons.phone,
                    '+255 622 711 508',
                    'Dar es Salaam, Tanzania',
                    () => _launchPhone('+255622711508'),
                  ),

                  const SizedBox(height: 24),

                  // Address
                  _buildContactItem(
                    provider,
                    Icons.location_on,
                    'Westlands Heights, Kiambu Road',
                    'Nairobi, Kenya',
                    () => _launchMaps(
                      'Westlands Heights, Kiambu Road, Nairobi, Kenya',
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 40, top: 8),
                    child: Text(
                      'Nairobi, Kenya',
                      style: TextStyle(
                        fontSize: 12,
                        color: provider.textMutedColor,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Email
                  _buildContactItem(
                    provider,
                    Icons.email,
                    'info@shuledrive.com',
                    '',
                    () => _launchEmail('info@shuledrive.com'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactItem(
    AppProvider provider,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: provider.isDarkMode
                  ? const Color(0xFF2C4A2C)
                  : AppPalette.emeraldSoftLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppPalette.emerald, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: provider.textColor,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: provider.textMutedColor,
                    ),
                  ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: provider.textMutedColor),
        ],
      ),
    );
  }
}
