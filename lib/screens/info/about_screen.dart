import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../widgets/main_scaffold.dart';

import '../../theme/app_colors.dart';
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  int _currentIndex = 3;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    
    return MainScaffold(
      title: 'About Us',
      showBackButton: true,
      showBottomNav: true,
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
                    'Bringing Peace of Mind to School Transportation',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: provider.textColor,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ShuleDrive description
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 14,
                        color: provider.textMutedColor,
                        height: 1.6,
                      ),
                      children: [
                        TextSpan(
                          text: 'ShuleDrive ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppProvider.primaryGreen,
                          ),
                        ),
                        const TextSpan(
                          text: 'is committed to revolutionizing school transportation in Kenya by making it safer, smarter, and more reliable.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    'Our comprehensive app connects parents, schools, and transport providers, ensuring that every journey is tracked, monitored, and optimized for safety. With real-time tracking, automated notifications, and detailed reporting, we give parents peace of mind while helping schools and transport providers deliver exceptional service.',
                    style: TextStyle(
                      fontSize: 14,
                      color: provider.textMutedColor,
                      height: 1.6,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Image placeholder
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 180,
                      width: double.infinity,
                      color: provider.isDarkMode ? AppPalette.surfaceSubtleDark : AppPalette.surfaceSubtleLight,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Background gradient
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: provider.isDarkMode
                                    ? [
                                        const Color(0xFF1E3A1E),
                                        const Color(0xFF2C4A2C),
                                      ]
                                    : [
                                        AppPalette.emeraldSoftLight,
                                        const Color(0xFFC8E6C9),
                                      ],
                              ),
                            ),
                          ),
                          // Bus illustration
                          Center(
                            child: CustomPaint(
                              size: const Size(200, 100),
                              painter: AboutBusPainter(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    'With a focus on safety, transparency, and communication, ShuleDrive transforms the daily school commute into a seamless experience for everyone involved.',
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
}

class AboutBusPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    
    // Draw ground line
    paint.color = AppPalette.emerald;
    paint.strokeWidth = 2;
    canvas.drawLine(
      Offset(20, size.height - 10),
      Offset(size.width - 20, size.height - 10),
      paint,
    );

    // Draw bus
    _drawBus(canvas, size.width * 0.5, size.height - 45, 120, 55);
  }

  void _drawBus(Canvas canvas, double x, double y, double width, double height) {
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
    canvas.drawCircle(Offset(x + width * 0.25, y + height * 0.4), wheelRadius, wheelPaint);
    canvas.drawCircle(Offset(x + width * 0.25, y + height * 0.4), wheelRadius * 0.5, rimPaint);
    canvas.drawCircle(Offset(x - width * 0.25, y + height * 0.4), wheelRadius, wheelPaint);
    canvas.drawCircle(Offset(x - width * 0.25, y + height * 0.4), wheelRadius * 0.5, rimPaint);
    
    final headlightPaint = Paint()..color = const Color(0xFFFFEEAA);
    canvas.drawCircle(Offset(x + width / 2 - 5, y + 6), 4, headlightPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
