import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../widgets/main_scaffold.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return MainScaffold(
      title: 'Privacy Policy',
      showBackButton: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Effective Date: December 18, 2024',
              style: TextStyle(
                fontSize: 12,
                color: provider.textMutedColor,
              ),
            ),
            const SizedBox(height: 16),
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
                    'Welcome to ShuleDrive! We value your trust and are committed to protecting your privacy. This Privacy Policy explains how ShuleDrive ("we," "us," or "our") collects, uses, shares, and protects your information when you use our website, mobile application, and related services (collectively, the "Services"). By using our Services, you agree to the collection and use of information in accordance with this policy.',
                    style: TextStyle(
                      fontSize: 14,
                      color: provider.textMutedColor,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSection('1. Who We Are', provider),
                  Text(
                    'ShuleDrive is a platform designed to revolutionize school transportation in Kenya, making it safer, smarter, and more reliable. We operate within the jurisdiction of Kenya and comply with applicable data protection laws, including the Data Protection Act, 2019.',
                    style: TextStyle(
                      fontSize: 14,
                      color: provider.textMutedColor,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Our Contact Details:\n• Address: Westlands Heights, Nairobi\n• Phone: +254 750 003304\n• Email: info@shuledrive.com',
                    style: TextStyle(
                      fontSize: 14,
                      color: provider.textMutedColor,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSection('2. Information We Collect', provider),
                  Text(
                    'We collect various types of information to provide and improve our Services:\n\n• Personal Information: Name, email address, phone number, and address.\n• Student Information: Name, school, class, pickup/drop-off locations.\n• Location Data: Real-time GPS location during trips.\n• Usage Data: How you interact with our app and services.',
                    style: TextStyle(
                      fontSize: 14,
                      color: provider.textMutedColor,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSection('3. How We Use Your Information', provider),
                  Text(
                    'We use the collected information for various purposes:\n\n• To provide and maintain our Services\n• To notify you about changes to our Services\n• To provide customer support\n• To gather analysis to improve our Services\n• To monitor usage of our Services\n• To detect, prevent and address technical issues',
                    style: TextStyle(
                      fontSize: 14,
                      color: provider.textMutedColor,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSection('4. Data Security', provider),
                  Text(
                    'We implement appropriate technical and organizational measures to protect your personal information against unauthorized access, alteration, disclosure, or destruction. However, no method of transmission over the internet is 100% secure.',
                    style: TextStyle(
                      fontSize: 14,
                      color: provider.textMutedColor,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, AppProvider provider) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: provider.textColor,
        ),
      ),
    );
  }
}
