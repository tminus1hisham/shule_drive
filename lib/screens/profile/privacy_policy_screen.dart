import 'package:flutter/material.dart';
import 'legal_page.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) => const LegalPage(
    title: 'Privacy Policy',
    icon: Icons.privacy_tip_outlined,
    effectiveDate: 'December 18, 2024',
    intro: legalIntro,
    sections: [
      ...legalCommonSections,
      (
        heading: '4. Data Security',
        body:
            'We implement appropriate technical and organizational measures to protect your personal information against unauthorized access, alteration, disclosure, or destruction. However, no method of transmission over the internet is 100% secure.',
      ),
    ],
  );
}
