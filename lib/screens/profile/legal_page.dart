import 'package:flutter/material.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme_extension.dart';
import '../../widgets/main_scaffold.dart';
import '../../widgets/ui/ui.dart';

/// One heading + body block of a [LegalPage].
typedef LegalSection = ({String heading, String body});

/// Shared layout for Terms of Service and Privacy Policy: effective date,
/// intro, then numbered sections that stagger in.
class LegalPage extends StatelessWidget {
  const LegalPage({
    super.key,
    required this.title,
    required this.icon,
    required this.effectiveDate,
    required this.intro,
    required this.sections,
  });

  final String title;
  final IconData icon;
  final String effectiveDate;
  final String intro;
  final List<LegalSection> sections;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final body = context.text.bodyMedium?.copyWith(
      color: c.textSecondary,
      height: 1.6,
    );

    return MainScaffold(
      title: title,
      showBackButton: true,
      body: Stack(
        children: [
          const Positioned.fill(child: AppBackdrop()),
          ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      gradient: c.brandGradient,
                      borderRadius: AppRadius.brMd,
                    ),
                    child: Icon(icon, color: Colors.white),
                  ).pop(),
                  AppSpacing.hSm,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: context.text.titleLarge),
                        Text(
                          'Effective Date: $effectiveDate',
                          style: context.text.labelMedium?.copyWith(
                            color: c.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ).enter(),
              AppSpacing.vLg,
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(intro, style: body),
              ).enterList(1),
              for (final (i, s) in sections.indexed) ...[
                AppSpacing.vSm,
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.heading,
                        style: context.text.titleMedium?.copyWith(
                          color: c.brand,
                        ),
                      ),
                      AppSpacing.vSm,
                      Text(s.body, style: body),
                    ],
                  ),
                ).enterList(i + 2),
              ],
              AppSpacing.vXl,
            ],
          ),
        ],
      ),
    );
  }
}

/// Text shared by both legal pages.
const legalIntro =
    'Welcome to ShuleDrive! We value your trust and are committed to protecting your privacy. This Privacy Policy explains how ShuleDrive ("we," "us," or "our") collects, uses, shares, and protects your information when you use our website, mobile application, and related services (collectively, the "Services"). By using our Services, you agree to the collection and use of information in accordance with this policy.';

const List<LegalSection> legalCommonSections = [
  (
    heading: '1. Who We Are',
    body:
        'ShuleDrive is a platform designed to revolutionize school transportation in Kenya, making it safer, smarter, and more reliable. We operate within the jurisdiction of Kenya and comply with applicable data protection laws, including the Data Protection Act, 2019.\n\n'
        'Our Contact Details:\n• Address: Westlands Heights, Nairobi\n• Phone: +254 750 003304\n• Email: info@shuledrive.com',
  ),
  (
    heading: '2. Information We Collect',
    body:
        'We collect various types of information to provide and improve our Services:\n\n'
        '• Personal Information: Name, email address, phone number, and address.\n'
        '• Student Information: Name, school, class, pickup/drop-off locations.\n'
        '• Location Data: Real-time GPS location during trips.\n'
        '• Usage Data: How you interact with our app and services.',
  ),
  (
    heading: '3. How We Use Your Information',
    body:
        'We use the collected information for various purposes:\n\n'
        '• To provide and maintain our Services\n'
        '• To notify you about changes to our Services\n'
        '• To provide customer support\n'
        '• To gather analysis to improve our Services\n'
        '• To monitor usage of our Services\n'
        '• To detect, prevent and address technical issues',
  ),
];
