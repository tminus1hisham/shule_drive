import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme_extension.dart';
import '../../widgets/main_scaffold.dart';
import '../../widgets/ui/ui.dart';

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  // No canLaunchUrl pre-check: iOS answers false for tel:/mailto: unless
  // Info.plist lists them in LSApplicationQueriesSchemes.
  Future<void> _launchPhone(String phone) =>
      launchUrl(Uri.parse('tel:$phone')).catchError((_) => false);

  Future<void> _launchEmail(String email) =>
      launchUrl(Uri.parse('mailto:$email')).catchError((_) => false);

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
    final c = context.colors;
    final phones = [
      ('+254 750 003304', 'Nairobi Office', '+254750003304'),
      ('+254 712 345 678', 'Customer Support - Always Active', '+254712345678'),
      ('+255 622 711 508', 'Dar es Salaam, Tanzania', '+255622711508'),
    ];

    return MainScaffold(
      title: 'Contact Us',
      showBackButton: true,
      body: Stack(
        children: [
          const Positioned.fill(child: AppBackdrop()),
          ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              GradientHeroCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Get in Touch',
                            style: context.text.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          AppSpacing.vXxs,
                          Text(
                            'We\'d love to hear from you',
                            style: context.text.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.support_agent_rounded,
                      color: Colors.white,
                      size: 48,
                    ).pop(delay: const Duration(milliseconds: 200)),
                  ],
                ),
              ).enter(),
              AppSpacing.vMd,
              const SectionHeader(
                title: 'Call us',
                padding: EdgeInsets.only(left: AppSpacing.xs),
              ).enterList(1),
              AppSpacing.vXs,
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Column(
                  children: [
                    for (final (i, p) in phones.indexed) ...[
                      if (i > 0)
                        Divider(
                          height: 1,
                          indent: 68,
                          endIndent: AppSpacing.md,
                          color: c.outline,
                        ),
                      AppListTile(
                        icon: Icons.phone_rounded,
                        title: p.$1,
                        subtitle: p.$2,
                        onTap: () => _launchPhone(p.$3),
                      ),
                    ],
                  ],
                ),
              ).enterList(2),
              AppSpacing.vMd,
              const SectionHeader(
                title: 'Visit or write',
                padding: EdgeInsets.only(left: AppSpacing.xs),
              ).enterList(3),
              AppSpacing.vXs,
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Column(
                  children: [
                    AppListTile(
                      icon: Icons.location_on_rounded,
                      iconColor: c.accent,
                      title: 'Westlands Heights, Kiambu Road',
                      subtitle: 'Nairobi, Kenya',
                      onTap: () => _launchMaps(
                        'Westlands Heights, Kiambu Road, Nairobi, Kenya',
                      ),
                    ),
                    Divider(
                      height: 1,
                      indent: 68,
                      endIndent: AppSpacing.md,
                      color: c.outline,
                    ),
                    AppListTile(
                      icon: Icons.email_rounded,
                      iconColor: c.info,
                      title: 'info@shuledrive.com',
                      onTap: () => _launchEmail('info@shuledrive.com'),
                    ),
                  ],
                ),
              ).enterList(4),
            ],
          ),
        ],
      ),
    );
  }
}
