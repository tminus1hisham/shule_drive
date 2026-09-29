import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme_extension.dart';
import '../../widgets/main_scaffold.dart';
import '../../widgets/ui/ui.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final body = context.text.bodyMedium?.copyWith(
      color: c.textSecondary,
      height: 1.6,
    );

    return MainScaffold(
      title: 'About Us',
      showBackButton: true,
      showBottomNav: true,
      bottomNavIndex: 3,
      body: Stack(
        children: [
          const Positioned.fill(child: AppBackdrop()),
          ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              // Illustrated hero: the bus drives in from the left.
              GradientHeroCard(
                padding: EdgeInsets.zero,
                child: SizedBox(
                  height: 190,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: -1, end: 0),
                        duration: const Duration(milliseconds: 900),
                        curve: AppCurves.easeOut,
                        builder: (context, v, child) => Transform.translate(
                          offset: Offset(v * 260, 0),
                          child: child,
                        ),
                        child: CustomPaint(
                          size: const Size(220, 110),
                          painter: AboutBusPainter(),
                        ),
                      ),
                    ],
                  ),
                ),
              ).enter(),
              AppSpacing.vLg,
              Text(
                'Bringing Peace of Mind to School Transportation',
                style: context.text.headlineSmall,
              ).enterList(1),
              AppSpacing.vMd,
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        style: body,
                        children: [
                          TextSpan(
                            text: 'ShuleDrive ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: c.brand,
                            ),
                          ),
                          const TextSpan(
                            text:
                                'is committed to revolutionizing school transportation in Kenya by making it safer, smarter, and more reliable.',
                          ),
                        ],
                      ),
                    ),
                    AppSpacing.vMd,
                    Text(
                      'Our comprehensive app connects parents, schools, and transport providers, ensuring that every journey is tracked, monitored, and optimized for safety. With real-time tracking, automated notifications, and detailed reporting, we give parents peace of mind while helping schools and transport providers deliver exceptional service.',
                      style: body,
                    ),
                    AppSpacing.vMd,
                    Text(
                      'With a focus on safety, transparency, and communication, ShuleDrive transforms the daily school commute into a seamless experience for everyone involved.',
                      style: body,
                    ),
                  ],
                ),
              ).enterList(2),
            ],
          ),
        ],
      ),
    );
  }
}

/// Decorative school bus; deliberately keeps its own illustration colours.
class AboutBusPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..strokeWidth = 2;
    // Ground line
    canvas.drawLine(
      Offset(20, size.height - 10),
      Offset(size.width - 20, size.height - 10),
      paint,
    );
    _drawBus(canvas, size.width * 0.5, size.height - 45, 120, 55);
  }

  void _drawBus(
    Canvas canvas,
    double x,
    double y,
    double width,
    double height,
  ) {
    final busPaint = Paint()..color = AppPalette.amber;
    final windowPaint = Paint()..color = const Color(0xFF87CEEB);
    final wheelPaint = Paint()..color = const Color(0xFF333333);
    final rimPaint = Paint()..color = const Color(0xFF888888);
    final stripePaint = Paint()..color = AppPalette.error;

    final busRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(x, y), width: width, height: height),
      const Radius.circular(10),
    );
    canvas.drawRRect(busRect, busPaint);

    canvas.drawRect(
      Rect.fromCenter(center: Offset(x, y + 3), width: width - 4, height: 6),
      stripePaint,
    );

    final windowWidth = (width - 24) / 4;
    for (int i = 0; i < 4; i++) {
      final windowX = x - width / 2 + 14 + i * (windowWidth + 3);
      final windowRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(windowX, y - height / 2 + 8, windowWidth, height * 0.35),
        const Radius.circular(3),
      );
      canvas.drawRRect(windowRect, windowPaint);
    }

    final wheelRadius = height * 0.22;
    for (final dx in [width * 0.25, -width * 0.25]) {
      final c = Offset(x + dx, y + height * 0.4);
      canvas.drawCircle(c, wheelRadius, wheelPaint);
      canvas.drawCircle(c, wheelRadius * 0.5, rimPaint);
    }

    final headlightPaint = Paint()..color = const Color(0xFFFFEEAA);
    canvas.drawCircle(Offset(x + width / 2 - 5, y + 6), 4, headlightPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
