import 'package:flutter/material.dart';
import 'legal_page.dart';

class TermsServiceScreen extends StatelessWidget {
  const TermsServiceScreen({super.key});

  // TODO(content): this page currently shows the privacy text; replace with
  // the real Terms of Service copy when legal provides it.
  @override
  Widget build(BuildContext context) => const LegalPage(
    title: 'Terms of Service',
    icon: Icons.description_outlined,
    effectiveDate: 'December 18, 2024',
    intro: legalIntro,
    sections: legalCommonSections,
  );
}
