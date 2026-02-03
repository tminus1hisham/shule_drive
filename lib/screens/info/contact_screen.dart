import 'package:flutter/material.dart';
import '../../widgets/bottom_navigation.dart';
import '../../widgets/main_scaffold.dart';
import 'package:url_launcher/url_launcher.dart';

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

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      title: 'Contact Us',
      showBackButton: true,
      showBottomNav: true,
      bottomNavIndex: _currentIndex,
      onBottomNavTap: (index) {
        setState(() => _currentIndex = index);
        if (index == 0) {
          Navigator.pushReplacementNamed(context, '/landing');
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Get in Touch',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'We\'d love to hear from you',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF666666),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Phone Numbers
                  _buildContactItem(
                    Icons.phone,
                    '+254 750 003304',
                    'Nairobi Office',
                    () => _launchPhone('+254750003304'),
                  ),
                  const Divider(height: 32),
                  _buildContactItem(
                    Icons.phone,
                    '+254 712 345 678',
                    'Customer Support - Always Active',
                    () => _launchPhone('+254712345678'),
                  ),
                  const Divider(height: 32),
                  _buildContactItem(
                    Icons.phone,
                    '+255 622 711 508',
                    'Dar es Salaam, Tanzania',
                    () => _launchPhone('+255622711508'),
                  ),

                  const SizedBox(height: 24),

                  // Address
                  _buildContactItem(
                    Icons.location_on,
                    'Westlands Heights, Kiambu Road',
                    'Nairobi, Kenya',
                    () {},
                  ),
                  const Padding(
                    padding: EdgeInsets.only(left: 40, top: 8),
                    child: Text(
                      'Nairobi, Kenya',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF999999),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Email
                  _buildContactItem(
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
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF6B9B5B),
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF999999),
                    ),
                  ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right,
            color: Color(0xFF999999),
          ),
        ],
      ),
    );
  }
}
