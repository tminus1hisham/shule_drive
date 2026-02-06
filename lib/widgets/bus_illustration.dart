import 'dart:math' show cos, sin, pi;
import 'package:flutter/material.dart';

class BusIllustration extends StatefulWidget {
  final double height;

  const BusIllustration({super.key, this.height = 200});

  @override
  State<BusIllustration> createState() => _BusIllustrationState();
}

class _BusIllustrationState extends State<BusIllustration>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _wheelController;

  // Bus animation
  late Animation<double> _busPosition;
  late Animation<double> _busBounce;

  // Child animation
  late Animation<double> _childOpacity;
  late Animation<double> _childPosition;

  // Door animation
  late Animation<double> _doorOpen;

  // Wheel rotation
  late Animation<double> _wheelRotation;

  @override
  void initState() {
    super.initState();
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );

    _wheelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _setupAnimations();
    _mainController.repeat();
    _wheelController.repeat();
  }

  void _setupAnimations() {
    // Bus animation: enters, stops, exits
    _busPosition = TweenSequence<double>([
      // Drive in from left
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.35, end: 0.5)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 22,
      ),
      // Stop and wait for child
      TweenSequenceItem(
        tween: ConstantTween<double>(0.5),
        weight: 28,
      ),
      // Drive off to right
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.5, end: 1.35)
            .chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 50,
      ),
    ]).animate(_mainController);

    // Bus bounce animation (engine idle + movement)
    _busBounce = TweenSequence<double>([
      // Drive in - gentle bounce
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: 0)
            .chain(CurveTween(curve: Curves.linear)),
        weight: 20,
      ),
      // Idle - subtle vibration
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: 2 * pi)
            .chain(CurveTween(curve: Curves.linear)),
        weight: 30,
      ),
      // Drive off
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: 0)
            .chain(CurveTween(curve: Curves.linear)),
        weight: 30,
      ),
      // Reset
      TweenSequenceItem(
        tween: ConstantTween<double>(0),
        weight: 20,
      ),
    ]).animate(_mainController);

    // Child appears and walks to bus (day) or exits bus (night)
    _childOpacity = TweenSequence<double>([
      // Hidden while bus drives in
      TweenSequenceItem(
        tween: ConstantTween<double>(0),
        weight: 20,
      ),
      // Child appears
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: 1)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 5,
      ),
      // Child visible while walking
      TweenSequenceItem(
        tween: ConstantTween<double>(1),
        weight: 20,
      ),
      // Child enters bus (fades)
      TweenSequenceItem(
        tween: Tween<double>(begin: 1, end: 0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 5,
      ),
      // Hidden
      TweenSequenceItem(
        tween: ConstantTween<double>(0),
        weight: 50,
      ),
    ]).animate(_mainController);

    // Child walks to bus door
    _childPosition = TweenSequence<double>([
      // Hidden
      TweenSequenceItem(
        tween: ConstantTween<double>(0.2),
        weight: 20,
      ),
      // Walk to door
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.2, end: 0.45)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
      // At door (enters)
      TweenSequenceItem(
        tween: ConstantTween<double>(0.45),
        weight: 5,
      ),
      // Reset
      TweenSequenceItem(
        tween: ConstantTween<double>(0.2),
        weight: 50,
      ),
    ]).animate(_mainController);

    // Door opens and closes
    _doorOpen = TweenSequence<double>([
      // Closed while driving
      TweenSequenceItem(
        tween: ConstantTween<double>(0),
        weight: 22,
      ),
      // Door opens
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: 1)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 3,
      ),
      // Door stays open while child enters
      TweenSequenceItem(
        tween: ConstantTween<double>(1),
        weight: 20,
      ),
      // Door closes
      TweenSequenceItem(
        tween: Tween<double>(begin: 1, end: 0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 3,
      ),
      // Closed while driving off and reset
      TweenSequenceItem(
        tween: ConstantTween<double>(0),
        weight: 52,
      ),
    ]).animate(_mainController);

    // Wheel rotation
    _wheelRotation = Tween<double>(
      begin: 0,
      end: 2 * pi,
    ).animate(_wheelController);
  }

  @override
  void dispose() {
    _mainController.dispose();
    _wheelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: Listenable.merge([_mainController, _wheelController]),
        builder: (context, child) {
          return CustomPaint(
            size: Size(double.infinity, widget.height),
            painter: ModernBusIllustrationPainter(
              busPosition: _busPosition.value,
              busBounce: _busBounce.value,
              childOpacity: _childOpacity.value,
              childPosition: _childPosition.value,
              doorOpen: _doorOpen.value,
              wheelRotation: _wheelRotation.value,
              isDark: isDark,
            ),
          );
        },
      ),
    );
  }
}

class ModernBusIllustrationPainter extends CustomPainter {
  final double busPosition;
  final double busBounce;
  final double childOpacity;
  final double childPosition;
  final double doorOpen;
  final double wheelRotation;
  final bool isDark;

  ModernBusIllustrationPainter({
    required this.busPosition,
    required this.busBounce,
    required this.childOpacity,
    required this.childPosition,
    required this.doorOpen,
    required this.wheelRotation,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw sky/background
    _drawSky(canvas, size);

    if (!isDark) {
      // Day mode elements
      _drawSun(canvas, size);
      _drawCloud(canvas, size.width * 0.15, size.height * 0.18, 30);
      _drawCloud(canvas, size.width * 0.55, size.height * 0.12, 25);
      _drawCloud(canvas, size.width * 0.85, size.height * 0.22, 28);
    } else {
      // Night mode elements
      _drawMoon(canvas, size);
      _drawStars(canvas, size);
    }

    // Draw hills/background
    _drawHills(canvas, size);

    // Draw road
    _drawRoad(canvas, size);

    // Draw trees
    _drawModernTree(canvas, size.width * 0.08, size.height - 50, 30);
    _drawModernTree(canvas, size.width * 0.92, size.height - 55, 35);

    // Calculate adjusted position based on day/night mode
    // Day: left to right (0 -> 1), Night: right to left (1 -> 0)
    final adjustedBusPosition = isDark ? (1 - busPosition) : busPosition;
    final adjustedChildPosition = isDark ? (1 - childPosition) : childPosition;
    
    // Calculate bus opacity - fade in at start, fade out at end
    double busOpacity = 1.0;
    if (adjustedBusPosition < 0) {
      // Entering from left
      busOpacity = ((adjustedBusPosition + 0.35) / 0.15).clamp(0.0, 1.0);
    } else if (adjustedBusPosition > 1.0) {
      // Exiting to right
      busOpacity = ((1.35 - adjustedBusPosition) / 0.15).clamp(0.0, 1.0);
    }

    // Draw child
    if (childOpacity > 0) {
      if (isDark) {
        // Night mode: Child exits bus and walks away to the right
        // Bus stops at center (0.5), facing left (door on right side at ~0.58)
        // Child exits door and walks right (away from bus)
        // childPosition goes 0.2 -> 0.45 during the walk
        // We want child to go from door (0.58) to away (0.78)
        final walkProgress = (childPosition - 0.2) / 0.25; // 0.0 to 1.0
        final exitPosition = 0.58 + walkProgress * 0.25; // 0.58 (door) to 0.83 (away)
        
        _drawChild(
          canvas,
          size.width * exitPosition,
          size.height - 70,
          childOpacity,
          isExiting: true,
          exitProgress: walkProgress,
        );
      } else {
        // Day: child walks to bus
        _drawChild(
          canvas,
          size.width * adjustedChildPosition,
          size.height - 70,
          childOpacity,
          isExiting: false,
          exitProgress: 0,
        );
      }
    }

    // Calculate bus bounce offset (idle vibration when stopped)
    double bounceY = 0;
    if (busPosition > 0.4 && busPosition < 0.6) {
      bounceY = sin(busBounce * 3) * 1.5;
    }

    // Draw bus with wheels touching the road
    // Bus sits at size.height - 60 (road level) + bounce
    final busY = size.height - 60 + bounceY;
    final busX = size.width * adjustedBusPosition;

    _drawModernBus(
      canvas,
      busX,
      busY,
      140,
      72,
      doorOpen,
      wheelRotation,
      busOpacity,
    );
  }

  void _drawSky(Canvas canvas, Size size) {
    if (isDark) {
      // Night sky gradient
      final skyPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF0D1B2A),
            const Color(0xFF1B263B),
            const Color(0xFF415A77).withValues(alpha: 0.5),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        skyPaint,
      );
    } else {
      // Day sky gradient
      final skyPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFE3F2FD),
            const Color(0xFFF5F5F0).withValues(alpha: 0.8),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        skyPaint,
      );
    }
  }

  void _drawSun(Canvas canvas, Size size) {
    final sunCenter = Offset(size.width * 0.88, size.height * 0.22);

    // Sun glow
    final glowPaint = Paint()
      ..color = const Color(0xFFFFB800).withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25);
    canvas.drawCircle(sunCenter, 50, glowPaint);

    // Sun body
    final sunPaint = Paint()
      ..color = const Color(0xFFFFB800)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(sunCenter, 28, sunPaint);

    // Sun core
    canvas.drawCircle(
      sunCenter,
      20,
      Paint()..color = const Color(0xFFFFD54F),
    );
  }

  void _drawMoon(Canvas canvas, Size size) {
    final moonCenter = Offset(size.width * 0.85, size.height * 0.18);

    // Moon glow
    final glowPaint = Paint()
      ..color = const Color(0xFFF5F5F5).withValues(alpha: 0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawCircle(moonCenter, 40, glowPaint);

    // Moon body
    canvas.drawCircle(
      moonCenter,
      22,
      Paint()..color = const Color(0xFFF5F5F5),
    );

    // Moon craters
    canvas.drawCircle(
      Offset(moonCenter.dx - 6, moonCenter.dy - 4),
      4,
      Paint()..color = const Color(0xFFE0E0E0),
    );
    canvas.drawCircle(
      Offset(moonCenter.dx + 5, moonCenter.dy + 6),
      3,
      Paint()..color = const Color(0xFFE0E0E0),
    );
    canvas.drawCircle(
      Offset(moonCenter.dx + 3, moonCenter.dy - 8),
      2,
      Paint()..color = const Color(0xFFE0E0E0),
    );
  }

  void _drawStars(Canvas canvas, Size size) {
    final starPaint = Paint()..color = Colors.white;
    final random = [0.1, 0.25, 0.35, 0.45, 0.6, 0.7, 0.8, 0.92];

    for (int i = 0; i < random.length; i++) {
      final x = size.width * random[i];
      final y = size.height * (0.08 + (i % 3) * 0.08);
      final radius = 1.0 + (i % 2);
      canvas.drawCircle(Offset(x, y), radius, starPaint);
    }
  }

  void _drawCloud(Canvas canvas, double x, double y, double size) {
    final cloudPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    // Main cloud body
    canvas.drawCircle(Offset(x, y), size * 0.5, cloudPaint);
    canvas.drawCircle(Offset(x + size * 0.35, y), size * 0.4, cloudPaint);
    canvas.drawCircle(Offset(x - size * 0.35, y), size * 0.35, cloudPaint);
    canvas.drawCircle(Offset(x, y - size * 0.25), size * 0.35, cloudPaint);

    // Additional puffs
    canvas.drawCircle(
        Offset(x + size * 0.5, y + size * 0.1), size * 0.25, cloudPaint);
    canvas.drawCircle(
        Offset(x - size * 0.5, y + size * 0.1), size * 0.25, cloudPaint);
  }

  void _drawHills(Canvas canvas, Size size) {
    // Back hills - lighter
    final backHillsPaint = Paint()
      ..color = isDark ? const Color(0xFF1B263B) : const Color(0xFFC8E6C9)
      ..style = PaintingStyle.fill;

    final backPath = Path()
      ..moveTo(0, size.height - 35)
      ..quadraticBezierTo(
        size.width * 0.3,
        size.height - 75,
        size.width * 0.5,
        size.height - 45,
      )
      ..quadraticBezierTo(
        size.width * 0.7,
        size.height - 25,
        size.width,
        size.height - 50,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(backPath, backHillsPaint);

    // Front hills - darker
    final frontHillsPaint = Paint()
      ..color = isDark ? const Color(0xFF0D1B2A) : const Color(0xFFA5D6A7)
      ..style = PaintingStyle.fill;

    final frontPath = Path()
      ..moveTo(0, size.height - 25)
      ..quadraticBezierTo(
        size.width * 0.25,
        size.height - 55,
        size.width * 0.5,
        size.height - 30,
      )
      ..quadraticBezierTo(
        size.width * 0.75,
        size.height - 10,
        size.width,
        size.height - 35,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(frontPath, frontHillsPaint);
  }

  void _drawRoad(Canvas canvas, Size size) {
    // Road surface
    final roadPaint = Paint()
      ..color = isDark ? const Color(0xFF2C3E50) : const Color(0xFFE0E0E0)
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 28, size.width, 28),
      roadPaint,
    );

    // Road border top
    canvas.drawLine(
      Offset(0, size.height - 28),
      Offset(size.width, size.height - 28),
      Paint()
        ..color = isDark ? const Color(0xFF34495E) : const Color(0xFFBDBDBD)
        ..strokeWidth = 1,
    );

    // Road markings (dashed line)
    final markingPaint = Paint()
      ..color = isDark ? const Color(0xFF7F8C8D) : const Color(0xFFFFB800)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    const dashWidth = 25.0;
    const dashSpace = 35.0;
    final y = size.height - 14;

    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, y),
        Offset(startX + dashWidth, y),
        markingPaint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  void _drawModernTree(Canvas canvas, double x, double y, double size) {
    // Tree trunk (rounded rectangle)
    final trunkPaint = Paint()
      ..color = const Color(0xFF795548)
      ..style = PaintingStyle.fill;

    final trunkRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(x, y - size * 0.1),
        width: size * 0.15,
        height: size * 0.5,
      ),
      Radius.circular(size * 0.05),
    );
    canvas.drawRRect(trunkRect, trunkPaint);

    // Tree foliage (modern triangle shape)
    final foliagePaint = Paint()
      ..color = isDark ? const Color(0xFF1E3A2F) : const Color(0xFF66BB6A)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(x, y - size * 0.7)
      ..lineTo(x + size * 0.35, y - size * 0.1)
      ..lineTo(x - size * 0.35, y - size * 0.1)
      ..close();
    canvas.drawPath(path, foliagePaint);

    // Highlight
    final highlightPaint = Paint()
      ..color = isDark ? const Color(0xFF2D5A45) : const Color(0xFF81C784)
      ..style = PaintingStyle.fill;

    final highlightPath = Path()
      ..moveTo(x, y - size * 0.7)
      ..lineTo(x + size * 0.15, y - size * 0.35)
      ..lineTo(x - size * 0.05, y - size * 0.35)
      ..close();
    canvas.drawPath(highlightPath, highlightPaint);
  }

  void _drawChild(Canvas canvas, double x, double y, double opacity,
      {required bool isExiting, required double exitProgress}) {
    if (opacity <= 0) return;

    // For night mode exit animation
    final walkOffset = isExiting ? exitProgress * 30 : 0;
    final finalX = isExiting ? x - walkOffset : x;

    // Helper to create color with opacity
    Color withOpacity(Color color) => color.withValues(alpha: opacity);

    // Head
    canvas.drawCircle(
      Offset(finalX, y - 25),
      8,
      Paint()..color = withOpacity(const Color(0xFFC89696)), // Skin tone
    );

    // Body
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(finalX, y - 12),
        width: 14,
        height: 18,
      ),
      Paint()..color = withOpacity(const Color(0xFF6496FF)), // Blue shirt
    );

    // Backpack
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(finalX - 10, y - 12),
        width: 8,
        height: 14,
      ),
      Paint()..color = withOpacity(const Color(0xFFFF6464)), // Red backpack
    );

    // Legs
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(finalX - 4, y + 5),
        width: 5,
        height: 16,
      ),
      Paint()..color = withOpacity(const Color(0xFF505064)), // Dark pants
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(finalX + 4, y + 5),
        width: 5,
        height: 16,
      ),
      Paint()..color = withOpacity(const Color(0xFF505064)),
    );

    // Arms (waving)
    final armPaint = Paint()
      ..color = withOpacity(const Color(0xFFC89696)) // Skin tone
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    // Right arm waving
    canvas.drawLine(
      Offset(finalX + 7, y - 18),
      Offset(finalX + 15, y - 28),
      armPaint,
    );

    // Left arm
    canvas.drawLine(
      Offset(finalX - 7, y - 18),
      Offset(finalX - 12, y - 8),
      armPaint,
    );
  }

  void _drawModernBus(
    Canvas canvas,
    double x,
    double y,
    double width,
    double height,
    double doorOpen,
    double wheelRotation,
    double opacity,
  ) {
    // Helper to apply opacity to colors
    Color withOpacity(Color color) => color.withValues(alpha: color.a * opacity);
    
    // Modern color scheme
    final primaryColor = withOpacity(isDark ? const Color(0xFFF4D03F) : const Color(0xFFFFB300));
    final secondaryColor = withOpacity(const Color(0xFF212121));
    final accentColor = withOpacity(const Color(0xFF4CAF50));
    final windowColor = withOpacity(isDark ? const Color(0xFF5DADE2) : const Color(0xFF81D4FA));

    // Calculate wheel positions - wheels touch the road (y + height * 0.42 sits on road)
    final wheelY = y + height * 0.42;
    final backWheelX = x + width * 0.25;
    final frontWheelX = x - width * 0.25;

    // Bus shadow (on the road)
    final shadowPaint = Paint()
      ..color = withOpacity(Colors.black.withValues(alpha: isDark ? 0.4 : 0.2))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(x, wheelY + 5),
        width: width * 0.95,
        height: 12,
      ),
      shadowPaint,
    );

    // Main bus body (sleek rounded rectangle)
    final bodyPath = Path()
      ..moveTo(x - width / 2 + 20, y - height / 2)
      ..lineTo(x + width / 2 - 15, y - height / 2)
      ..quadraticBezierTo(
        x + width / 2,
        y - height / 2,
        x + width / 2,
        y - height / 2 + 15,
      )
      ..lineTo(x + width / 2, y + height / 2 - 15)
      ..quadraticBezierTo(
        x + width / 2,
        y + height / 2,
        x + width / 2 - 15,
        y + height / 2,
      )
      ..lineTo(x - width / 2 + 20, y + height / 2)
      ..quadraticBezierTo(
        x - width / 2,
        y + height / 2,
        x - width / 2,
        y + height / 2 - 15,
      )
      ..lineTo(x - width / 2, y - height / 2 + 15)
      ..quadraticBezierTo(
        x - width / 2,
        y - height / 2,
        x - width / 2 + 20,
        y - height / 2,
      )
      ..close();

    final bodyPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(bodyPath, bodyPaint);

    // Black stripe along the side
    canvas.drawRect(
      Rect.fromLTWH(
        x - width / 2 + 5,
        y - 5,
        width - 10,
        14,
      ),
      Paint()..color = secondaryColor,
    );

    // Green accent stripe
    canvas.drawRect(
      Rect.fromLTWH(
        x - width / 2 + 5,
        y + 12,
        width - 10,
        4,
      ),
      Paint()..color = accentColor,
    );

    // Modern windows (large, curved)
    final windowPaint = Paint()
      ..color = windowColor
      ..style = PaintingStyle.fill;

    // Side windows
    final windowWidth = (width - 50) / 3;
    for (int i = 0; i < 3; i++) {
      final windowX = x - width / 2 + 20 + i * (windowWidth + 8);

      // Skip where door is (middle position)
      if (i == 1) continue;

      final windowPath = Path()
        ..moveTo(windowX, y - height / 2 + 18)
        ..lineTo(windowX + windowWidth - 5, y - height / 2 + 18)
        ..quadraticBezierTo(
          windowX + windowWidth,
          y - height / 2 + 18,
          windowX + windowWidth,
          y - height / 2 + 25,
        )
        ..lineTo(windowX + windowWidth, y - 12)
        ..quadraticBezierTo(
          windowX + windowWidth,
          y - 5,
          windowX + windowWidth - 5,
          y - 5,
        )
        ..lineTo(windowX + 5, y - 5)
        ..quadraticBezierTo(
          windowX,
          y - 5,
          windowX,
          y - 12,
        )
        ..lineTo(windowX, y - height / 2 + 25)
        ..quadraticBezierTo(
          windowX,
          y - height / 2 + 18,
          windowX + 5,
          y - height / 2 + 18,
        )
        ..close();

      canvas.drawPath(windowPath, windowPaint);

      // Window frame
      final framePaint = Paint()
        ..color = secondaryColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawPath(windowPath, framePaint);

      // Window reflection
      final reflectionPaint = Paint()
        ..color = withOpacity(Colors.white.withValues(alpha: isDark ? 0.2 : 0.4))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawLine(
        Offset(windowX + 5, y - height / 2 + 22),
        Offset(windowX + windowWidth - 5, y - height / 2 + 22),
        reflectionPaint,
      );
    }

    // Front windshield (direction depends on day/night)
    final windshieldPath = Path();
    if (!isDark) {
      // Day: facing right
      windshieldPath
        ..moveTo(x + width / 2 - 12, y - height / 2 + 15)
        ..lineTo(x + width / 2 - 5, y - height / 2 + 20)
        ..quadraticBezierTo(
          x + width / 2 - 2,
          y - height / 2 + 25,
          x + width / 2 - 2,
          y - height / 2 + 35,
        )
        ..lineTo(x + width / 2 - 2, y - 8)
        ..quadraticBezierTo(
          x + width / 2 - 2,
          y - 3,
          x + width / 2 - 8,
          y - 3,
        )
        ..lineTo(x + width / 2 - 15, y - 3)
        ..quadraticBezierTo(
          x + width / 2 - 20,
          y - 3,
          x + width / 2 - 20,
          y - 10,
        )
        ..lineTo(x + width / 2 - 15, y - height / 2 + 15)
        ..quadraticBezierTo(
          x + width / 2 - 15,
          y - height / 2 + 12,
          x + width / 2 - 12,
          y - height / 2 + 15,
        )
        ..close();
    } else {
      // Night: facing left
      windshieldPath
        ..moveTo(x - width / 2 + 12, y - height / 2 + 15)
        ..lineTo(x - width / 2 + 5, y - height / 2 + 20)
        ..quadraticBezierTo(
          x - width / 2 + 2,
          y - height / 2 + 25,
          x - width / 2 + 2,
          y - height / 2 + 35,
        )
        ..lineTo(x - width / 2 + 2, y - 8)
        ..quadraticBezierTo(
          x - width / 2 + 2,
          y - 3,
          x - width / 2 + 8,
          y - 3,
        )
        ..lineTo(x - width / 2 + 15, y - 3)
        ..quadraticBezierTo(
          x - width / 2 + 20,
          y - 3,
          x - width / 2 + 20,
          y - 10,
        )
        ..lineTo(x - width / 2 + 15, y - height / 2 + 15)
        ..quadraticBezierTo(
          x - width / 2 + 15,
          y - height / 2 + 12,
          x - width / 2 + 12,
          y - height / 2 + 15,
        )
        ..close();
    }

    canvas.drawPath(windshieldPath, windowPaint);
    canvas.drawPath(
      windshieldPath,
      Paint()
        ..color = secondaryColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Door (sliding)
    final doorX = x + width * 0.05;
    final doorWidth = 26.0;
    final doorHeight = height * 0.65;
    final doorOffset = doorOpen * (doorWidth * 0.6);

    // Door frame
    final doorFrameRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(doorX, y - height * 0.05),
        width: doorWidth + 4,
        height: doorHeight + 4,
      ),
      const Radius.circular(6),
    );
    canvas.drawRRect(
      doorFrameRect,
      Paint()..color = secondaryColor,
    );

    // Door panel (slides)
    final doorRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(doorX - doorOffset, y - height * 0.05),
        width: doorWidth,
        height: doorHeight,
      ),
      const Radius.circular(4),
    );
    canvas.drawRRect(
      doorRect,
      Paint()..color = withOpacity(const Color(0xFF424242)),
    );

    // Door window
    final doorWindowRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(doorX - doorOffset, y - height * 0.15),
        width: doorWidth - 6,
        height: doorHeight * 0.35,
      ),
      const Radius.circular(3),
    );
    canvas.drawRRect(doorWindowRect, windowPaint);

    // Draw wheels with rotation - touching the road
    _drawSpinningWheel(canvas, backWheelX, wheelY, 16, wheelRotation, opacity);
    _drawSpinningWheel(canvas, frontWheelX, wheelY, 16, wheelRotation, opacity);

    // LED Headlights - direction based on day/night
    if (!isDark) {
      // Day: headlights on right (facing right)
      final headlightPaint = Paint()
        ..color = withOpacity(const Color(0xFFFFF59D))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x + width / 2 - 8, y + 5, 6, 10),
          const Radius.circular(3),
        ),
        headlightPaint,
      );

      // Headlight beam
      final beamGradient = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          withOpacity(const Color(0xFFFFF59D).withValues(alpha: isDark ? 0.5 : 0.3)),
          withOpacity(const Color(0xFFFFF59D).withValues(alpha: 0)),
        ],
      );
      final beamPaint = Paint()
        ..shader = beamGradient.createShader(Rect.fromLTWH(x + width / 2, y, 60, 20));

      final beamPath = Path()
        ..moveTo(x + width / 2 - 2, y + 5)
        ..lineTo(x + width / 2 + 50, y - 5)
        ..lineTo(x + width / 2 + 50, y + 25)
        ..lineTo(x + width / 2 - 2, y + 15)
        ..close();
      canvas.drawPath(beamPath, beamPaint);

      // Taillights on left
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - width / 2 + 2, y + 5, 6, 10),
          const Radius.circular(3),
        ),
        Paint()..color = withOpacity(const Color(0xFFFF5252)),
      );
    } else {
      // Night: headlights on left (facing left)
      final headlightPaint = Paint()
        ..color = withOpacity(const Color(0xFFFFF59D))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - width / 2 + 2, y + 5, 6, 10),
          const Radius.circular(3),
        ),
        headlightPaint,
      );

      // Headlight beam (pointing left)
      final beamGradient = LinearGradient(
        begin: Alignment.centerRight,
        end: Alignment.centerLeft,
        colors: [
          withOpacity(const Color(0xFFFFF59D).withValues(alpha: 0.6)),
          withOpacity(const Color(0xFFFFF59D).withValues(alpha: 0)),
        ],
      );
      final beamPaint = Paint()
        ..shader = beamGradient.createShader(Rect.fromLTWH(x - width / 2 - 50, y, 60, 20));

      final beamPath = Path()
        ..moveTo(x - width / 2 + 2, y + 5)
        ..lineTo(x - width / 2 - 50, y - 5)
        ..lineTo(x - width / 2 - 50, y + 25)
        ..lineTo(x - width / 2 + 2, y + 15)
        ..close();
      canvas.drawPath(beamPath, beamPaint);

      // Taillights on right
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x + width / 2 - 8, y + 5, 6, 10),
          const Radius.circular(3),
        ),
        Paint()..color = withOpacity(const Color(0xFFFF5252)),
      );
    }

    // "SCHOOL BUS" sign on top
    final signRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(x, y - height / 2 - 10),
        width: 50,
        height: 16,
      ),
      const Radius.circular(4),
    );
    canvas.drawRRect(signRect, Paint()..color = secondaryColor);

    // Sign border
    canvas.drawRRect(
      signRect,
      Paint()
        ..color = accentColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Side mirror
    final mirrorX = isDark ? x - width / 2 + 3 : x + width / 2 - 3;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(mirrorX - 4, y - 15, 8, 12),
        const Radius.circular(2),
      ),
      Paint()..color = secondaryColor,
    );
  }

  void _drawSpinningWheel(Canvas canvas, double x, double y, double radius,
      double rotation, double opacity) {
    // Helper for opacity
    Color withOpacity(Color color) => color.withValues(alpha: color.a * opacity);
    
    // Tire (black rubber)
    canvas.drawCircle(
      Offset(x, y),
      radius,
      Paint()..color = withOpacity(const Color(0xFF212121)),
    );

    // Tire sidewall
    canvas.drawCircle(
      Offset(x, y),
      radius * 0.85,
      Paint()..color = withOpacity(const Color(0xFF424242)),
    );

    // Rim (silver)
    canvas.drawCircle(
      Offset(x, y),
      radius * 0.6,
      Paint()..color = withOpacity(const Color(0xFFBDBDBD)),
    );

    // Inner rim
    canvas.drawCircle(
      Offset(x, y),
      radius * 0.45,
      Paint()..color = withOpacity(const Color(0xFFE0E0E0)),
    );

    // Hubcap center
    canvas.drawCircle(
      Offset(x, y),
      radius * 0.2,
      Paint()..color = withOpacity(const Color(0xFF757575)),
    );

    // Spokes (5-spoke modern design) - ROTATED
    final spokePaint = Paint()
      ..color = withOpacity(const Color(0xFF9E9E9E))
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 5; i++) {
      final angle = rotation + i * 2 * pi / 5 - pi / 2;
      canvas.drawLine(
        Offset(x, y),
        Offset(
          x + radius * 0.5 * cos(angle),
          y + radius * 0.5 * sin(angle),
        ),
        spokePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ModernBusIllustrationPainter oldDelegate) {
    return oldDelegate.busPosition != busPosition ||
        oldDelegate.busBounce != busBounce ||
        oldDelegate.childOpacity != childOpacity ||
        oldDelegate.childPosition != childPosition ||
        oldDelegate.doorOpen != doorOpen ||
        oldDelegate.wheelRotation != wheelRotation ||
        oldDelegate.isDark != isDark;
  }
}
