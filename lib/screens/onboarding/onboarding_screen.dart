import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme_extension.dart';
import '../../widgets/ui/ui.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/login_screen.dart';

import '../../theme/app_colors.dart';

/// Advanced Onboarding Screen with animations, glassmorphism, and parallax effects
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  double _currentPage = 0;
  int _currentIndex = 0;

  late AnimationController _floatController;
  late AnimationController _particleController;
  late AnimationController _scaleController;

  final List<OnboardingData> _pages = [
    OnboardingData(
      title: 'Safe School Transport',
      description:
          "Track your child's school bus in real-time. Know exactly when they board, travel, and arrive safely.",
      primaryColor: AppPalette.emerald,
      secondaryColor: const Color(0xFF34C98B),
      illustration: const BusIllustration(),
    ),
    OnboardingData(
      title: 'Live GPS Tracking',
      description:
          'Watch the bus move on the map in real-time. Get instant notifications at every stop.',
      primaryColor: const Color(0xFF5B8B9B),
      secondaryColor: const Color(0xFF7AB8C4),
      illustration: const MapIllustration(),
    ),
    OnboardingData(
      title: 'Stay Connected',
      description:
          'Chat directly with drivers and school staff. Get instant updates about delays and changes.',
      primaryColor: const Color(0xFF9B5B8B),
      secondaryColor: const Color(0xFFC47A9B),
      illustration: const ChatIllustration(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pageController.addListener(_onPageChanged);

    // Floating animation for illustrations
    _floatController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    // Particle animation
    _particleController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();

    // Scale animation for cards
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleController.forward();
  }

  void _onPageChanged() {
    setState(() {
      _currentPage = _pageController.page ?? 0;
      _currentIndex = _pageController.page?.round() ?? 0;
    });
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageChanged);
    _pageController.dispose();
    _floatController.dispose();
    _particleController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const LoginScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    }
  }

  void _nextPage() {
    HapticFeedback.lightImpact();
    if (_currentIndex < _pages.length - 1) {
      _pageController.animateToPage(
        _currentIndex + 1,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _skipToLogin() {
    HapticFeedback.lightImpact();
    _completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // Animated background particles
          AnimatedBuilder(
            animation: _particleController,
            builder: (context, child) {
              return CustomPaint(
                size: size,
                painter: ParticlePainter(
                  animation: _particleController.value,
                  color: _pages[_currentIndex].primaryColor.withValues(
                    alpha: 0.1,
                  ),
                ),
              );
            },
          ),

          // Gradient orbs
          Positioned(
            top: -100,
            right: -100,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _pages[_currentIndex].primaryColor.withValues(alpha: 0.3),
                    _pages[_currentIndex].primaryColor.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            bottom: -150,
            left: -100,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _pages[_currentIndex].secondaryColor.withValues(alpha: 0.2),
                    _pages[_currentIndex].secondaryColor.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // Top bar with skip
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Page counter
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: c.surfaceSubtle,
                          borderRadius: AppRadius.brPill,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '0${_currentIndex + 1}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _pages[_currentIndex].primaryColor,
                              ),
                            ),
                            Text(
                              ' / 03',
                              style: TextStyle(
                                fontSize: 14,
                                color: c.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Skip button
                      if (_currentIndex < _pages.length - 1)
                        TextButton.icon(
                          onPressed: _skipToLogin,
                          icon: Text(
                            'Skip',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: c.textSecondary,
                            ),
                          ),
                          label: Icon(
                            Icons.arrow_forward,
                            size: 16,
                            color: c.textSecondary,
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // PageView with parallax
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _pages.length,
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (context, index) {
                      final page = _pages[index];
                      final progress = _currentPage - index;
                      final scale = 1 - (progress.abs() * 0.15).clamp(0.0, 0.3);
                      final opacity = 1 - progress.abs().clamp(0.0, 1.0);

                      return Opacity(
                        opacity: opacity,
                        child: Transform.scale(
                          scale: scale,
                          child: _buildPage(page, index),
                        ),
                      );
                    },
                  ),
                ),

                // Bottom controls
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Animated page indicator
                      _buildPageIndicator(),

                      const SizedBox(height: 32),

                      // Next/Get Started button with glassmorphism
                      PressScale(
                        child: GestureDetector(
                          onTap: _nextPage,
                          child: Container(
                            width: double.infinity,
                            height: 64,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              gradient: LinearGradient(
                                colors: [
                                  _pages[_currentIndex].primaryColor,
                                  _pages[_currentIndex].secondaryColor,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _pages[_currentIndex].primaryColor
                                      .withValues(alpha: 0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _currentIndex == _pages.length - 1
                                      ? 'Get Started'
                                      : 'Continue',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Arrow spins into a check on the last page.
                                AnimatedSwitcher(
                                  duration: AppDuration.slow,
                                  transitionBuilder: (child, anim) =>
                                      RotationTransition(
                                        turns: Tween(
                                          begin: -0.25,
                                          end: 0.0,
                                        ).animate(anim),
                                        child: ScaleTransition(
                                          scale: anim,
                                          child: child,
                                        ),
                                      ),
                                  child: Icon(
                                    _currentIndex == _pages.length - 1
                                        ? Icons.check_rounded
                                        : Icons.arrow_forward_rounded,
                                    key: ValueKey(
                                      _currentIndex == _pages.length - 1,
                                    ),
                                    color: Colors.white,
                                    size: 24,
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(OnboardingData page, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 40),

          // Glassmorphism card with illustration
          Expanded(
            flex: 5,
            child: AnimatedBuilder(
              animation: _floatController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _floatController.value * 10 - 5),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(40),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          page.primaryColor.withValues(alpha: 0.15),
                          page.secondaryColor.withValues(alpha: 0.05),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: page.primaryColor.withValues(alpha: 0.1),
                          blurRadius: 40,
                          offset: const Offset(0, 20),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(40),
                      child: Stack(
                        children: [
                          // Background pattern
                          Positioned.fill(
                            child: CustomPaint(
                              painter: GridPatternPainter(
                                color: page.primaryColor.withValues(alpha: 0.1),
                              ),
                            ),
                          ),

                          // Illustration
                          Center(
                            child: AnimatedBuilder(
                              animation: _scaleController,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _scaleController.value,
                                  child: page.illustration,
                                );
                              },
                            ),
                          ),

                          // Decorative circles
                          Positioned(
                            top: 20,
                            right: 20,
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: page.primaryColor.withValues(alpha: 0.2),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 30,
                            left: 30,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: page.secondaryColor.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 40),

          // Title and description
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Text(
                  page.title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  page.description,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.7,
                    color: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pages.length, (index) {
        final isActive = index == _currentIndex;
        final distance = (index - _currentIndex).abs();
        final scale = math.max(0.5, 1 - (distance * 0.3));

        return AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          width: isActive ? 32 : 8,
          height: 8,
          transform: Matrix4.identity()..scale(scale, 1.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: isActive
                ? _pages[_currentIndex].primaryColor
                : (_pages[_currentIndex].primaryColor.withValues(alpha: 0.2)),
          ),
        );
      }),
    );
  }
}

class OnboardingData {
  final String title;
  final String description;
  final Color primaryColor;
  final Color secondaryColor;
  final Widget illustration;

  OnboardingData({
    required this.title,
    required this.description,
    required this.primaryColor,
    required this.secondaryColor,
    required this.illustration,
  });
}

// Custom Illustrations using CustomPainter
class BusIllustration extends StatelessWidget {
  const BusIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: CustomPaint(painter: BusPainter()),
    );
  }
}

class MapIllustration extends StatelessWidget {
  const MapIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: CustomPaint(painter: MapPainter()),
    );
  }
}

class ChatIllustration extends StatelessWidget {
  const ChatIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: CustomPaint(painter: ChatPainter()),
    );
  }
}

// Bus Custom Painter
class BusPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppPalette.emerald
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = AppPalette.emerald.withValues(alpha: 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);

    // Shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.width / 2, size.height / 2 + 10),
          width: 140,
          height: 100,
        ),
        const Radius.circular(20),
      ),
      shadowPaint,
    );

    // Bus body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.width / 2, size.height / 2),
          width: 140,
          height: 90,
        ),
        const Radius.circular(20),
      ),
      paint,
    );

    // Windows
    final windowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    // Front window
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width / 2 - 55, size.height / 2 - 25, 35, 30),
        const Radius.circular(8),
      ),
      windowPaint,
    );

    // Side windows
    for (int i = 0; i < 3; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            size.width / 2 - 15 + (i * 25),
            size.height / 2 - 25,
            20,
            30,
          ),
          const Radius.circular(6),
        ),
        windowPaint,
      );
    }

    // Wheels
    final wheelPaint = Paint()
      ..color = const Color(0xFF3D5A3F)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width / 2 - 40, size.height / 2 + 35),
      18,
      wheelPaint,
    );
    canvas.drawCircle(
      Offset(size.width / 2 + 40, size.height / 2 + 35),
      18,
      wheelPaint,
    );

    // Headlight
    canvas.drawCircle(
      Offset(size.width / 2 - 60, size.height / 2 + 10),
      6,
      Paint()..color = const Color(0xFFFFD54F),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Map Custom Painter
class MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF5B8B9B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final fillPaint = Paint()
      ..color = const Color(0xFF5B8B9B).withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    // Map grid lines
    final path = Path()
      ..moveTo(40, 60)
      ..lineTo(80, 40)
      ..lineTo(120, 70)
      ..lineTo(160, 50)
      ..lineTo(160, 140)
      ..lineTo(120, 160)
      ..lineTo(80, 130)
      ..lineTo(40, 150)
      ..close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, paint);

    // Vertical lines
    canvas.drawLine(const Offset(80, 40), const Offset(80, 150), paint);
    canvas.drawLine(const Offset(120, 70), const Offset(120, 160), paint);

    // Location pin
    final pinPaint = Paint()
      ..color = AppPalette.error
      ..style = PaintingStyle.fill;

    final pinShadow = Paint()
      ..color = AppPalette.error.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    // Pin shadow
    canvas.drawCircle(const Offset(100, 100), 20, pinShadow);

    // Pin body
    final pinPath = Path()
      ..moveTo(100, 75)
      ..quadraticBezierTo(125, 75, 125, 100)
      ..quadraticBezierTo(125, 120, 100, 145)
      ..quadraticBezierTo(75, 120, 75, 100)
      ..quadraticBezierTo(75, 75, 100, 75)
      ..close();

    canvas.drawPath(pinPath, pinPaint);

    // Pin center
    canvas.drawCircle(
      const Offset(100, 100),
      10,
      Paint()..color = Colors.white,
    );

    // Pulse rings
    canvas.drawCircle(
      const Offset(100, 100),
      35,
      Paint()
        ..color = AppPalette.error.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter) => false;
}

// Chat Custom Painter
class ChatPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Chat bubbles
    final bubble1Paint = Paint()
      ..color = const Color(0xFF9B5B8B)
      ..style = PaintingStyle.fill;

    final bubble2Paint = Paint()
      ..color = const Color(0xFFE8D5E0)
      ..style = PaintingStyle.fill;

    // Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    // First bubble shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(50, 50, 100, 50),
        const Radius.circular(16),
      ),
      shadowPaint,
    );

    // First bubble (sender)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(45, 45, 100, 50),
        const Radius.circular(16),
      ),
      bubble1Paint,
    );

    // Bubble tail
    final tailPath = Path()
      ..moveTo(45, 85)
      ..lineTo(35, 95)
      ..lineTo(55, 90)
      ..close();
    canvas.drawPath(tailPath, bubble1Paint);

    // Second bubble shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(60, 110, 90, 45),
        const Radius.circular(16),
      ),
      shadowPaint,
    );

    // Second bubble (receiver)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(55, 105, 90, 45),
        const Radius.circular(16),
      ),
      bubble2Paint,
    );

    // Second bubble tail
    final tail2Path = Path()
      ..moveTo(145, 140)
      ..lineTo(155, 150)
      ..lineTo(135, 145)
      ..close();
    canvas.drawPath(tail2Path, bubble2Paint);

    // Notification dot
    canvas.drawCircle(
      const Offset(155, 55),
      12,
      Paint()..color = AppPalette.emerald,
    );

    // Typing indicator dots
    for (int i = 0; i < 3; i++) {
      canvas.drawCircle(
        Offset(75 + (i * 12), 127),
        4,
        Paint()..color = const Color(0xFF9B5B8B).withValues(alpha: 0.5),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Background Particle Painter
class ParticlePainter extends CustomPainter {
  final double animation;
  final Color color;

  ParticlePainter({required this.animation, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final random = math.Random(42); // Fixed seed for consistency

    for (int i = 0; i < 20; i++) {
      final x = (random.nextDouble() * size.width);
      final y =
          ((random.nextDouble() * size.height) + (animation * 100)) %
          size.height;
      final radius = random.nextDouble() * 4 + 2;
      final opacity = (1 - (y / size.height)) * 0.5;

      canvas.drawCircle(
        Offset(x, y),
        radius,
        paint..color = color.withValues(alpha: opacity),
      );
    }
  }

  @override
  bool shouldRepaint(covariant ParticlePainter oldDelegate) =>
      oldDelegate.animation != animation;
}

// Grid Pattern Painter
class GridPatternPainter extends CustomPainter {
  final Color color;

  GridPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    const spacing = 30.0;

    // Diagonal lines
    for (double i = -size.height; i < size.width + size.height; i += spacing) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
