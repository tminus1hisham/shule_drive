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
  late AnimationController _loopController;

  // Bus animation
  late Animation<double> _busPosition;
  late Animation<double> _busBounce;
  late Animation<double> _busTilt;

  // Child animation
  late Animation<double> _childOpacity;
  late Animation<double> _childPosition;

  // Door animation
  late Animation<double> _doorOpen;

  @override
  void initState() {
    super.initState();
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );

    _loopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _setupAnimations();
    // Play the scene twice, then park the bus at the stop: endless loops
    // repainted this ~1,300-line painter every frame and kept idle login /
    // dashboard screens at 60-140% CPU.
    _loopController.repeat();
    _mainController.repeat(count: 2).whenComplete(() {
      if (!mounted) return;
      _loopController.stop();
      _mainController.value = 0.4; // inside the "stopped at the kerb" span
    });
  }

  void _setupAnimations() {
    // Bus animation: enters, stops, exits
    _busPosition = TweenSequence<double>([
      // Drive in from left
      TweenSequenceItem(
        tween: Tween<double>(
          begin: -0.35,
          end: 0.5,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 22,
      ),
      // Stop and wait for child
      TweenSequenceItem(tween: ConstantTween<double>(0.5), weight: 28),
      // Drive off to right
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.5,
          end: 1.35,
        ).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 50,
      ),
    ]).animate(_mainController);

    // Bus bounce animation (engine idle + movement)
    _busBounce = TweenSequence<double>([
      // Drive in - gentle bounce
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0,
          end: 0,
        ).chain(CurveTween(curve: Curves.linear)),
        weight: 20,
      ),
      // Idle - subtle vibration
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0,
          end: 2 * pi,
        ).chain(CurveTween(curve: Curves.linear)),
        weight: 30,
      ),
      // Drive off
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0,
          end: 0,
        ).chain(CurveTween(curve: Curves.linear)),
        weight: 30,
      ),
      // Reset
      TweenSequenceItem(tween: ConstantTween<double>(0), weight: 20),
    ]).animate(_mainController);

    // Child appears and walks to bus (day) or exits bus (night)
    _childOpacity = TweenSequence<double>([
      // Hidden while bus drives in
      TweenSequenceItem(tween: ConstantTween<double>(0), weight: 20),
      // Child appears
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 5,
      ),
      // Child visible while walking
      TweenSequenceItem(tween: ConstantTween<double>(1), weight: 20),
      // Child enters bus (fades)
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1,
          end: 0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 5,
      ),
      // Hidden
      TweenSequenceItem(tween: ConstantTween<double>(0), weight: 50),
    ]).animate(_mainController);

    // Child walks to bus door
    _childPosition = TweenSequence<double>([
      // Hidden
      TweenSequenceItem(tween: ConstantTween<double>(0.2), weight: 20),
      // Walk to door
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.2,
          end: 0.45,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
      // At door (enters)
      TweenSequenceItem(tween: ConstantTween<double>(0.45), weight: 5),
      // Reset
      TweenSequenceItem(tween: ConstantTween<double>(0.2), weight: 50),
    ]).animate(_mainController);

    // Door opens and closes
    _doorOpen = TweenSequence<double>([
      // Closed while driving
      TweenSequenceItem(tween: ConstantTween<double>(0), weight: 22),
      // Door opens
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 3,
      ),
      // Door stays open while child enters
      TweenSequenceItem(tween: ConstantTween<double>(1), weight: 20),
      // Door closes
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1,
          end: 0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 3,
      ),
      // Closed while driving off and reset
      TweenSequenceItem(tween: ConstantTween<double>(0), weight: 52),
    ]).animate(_mainController);

    // Bus tilt animation (acceleration/braking inertia)
    _busTilt = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(0), weight: 10),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0,
          end: 0.05,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 12,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.05,
          end: 0,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 15,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(0), weight: 13),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0,
          end: -0.06,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: -0.06,
          end: 0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 35,
      ),
    ]).animate(_mainController);
  }

  @override
  void dispose() {
    _mainController.dispose();
    _loopController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: Listenable.merge([_mainController, _loopController]),
        builder: (context, child) {
          return CustomPaint(
            size: Size(double.infinity, widget.height),
            painter: ModernBusIllustrationPainter(
              busPosition: _busPosition.value,
              busBounce: _busBounce.value,
              busTilt: _busTilt.value,
              childOpacity: _childOpacity.value,
              childPosition: _childPosition.value,
              doorOpen: _doorOpen.value,
              loopAnimation: _loopController.value,
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
  final double busTilt;
  final double childOpacity;
  final double childPosition;
  final double doorOpen;
  final double loopAnimation;
  final bool isDark;

  ModernBusIllustrationPainter({
    required this.busPosition,
    required this.busBounce,
    required this.busTilt,
    required this.childOpacity,
    required this.childPosition,
    required this.doorOpen,
    required this.loopAnimation,
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
        final exitPosition =
            0.58 + walkProgress * 0.25; // 0.58 (door) to 0.83 (away)

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

    // Physics-based wheel rotation (based on distance traveled)
    final distanceTraveled = adjustedBusPosition * size.width;
    final wheelRotation = distanceTraveled / 16.0;

    // Calculate tilt (inertia based on acceleration/deceleration)
    final tiltAngle = isDark ? -busTilt : busTilt;

    // Draw bus with wheels touching the road
    // Bus sits at size.height - 60 (road level) + bounce
    final busY = size.height - 60 + bounceY;
    final busX = size.width * adjustedBusPosition;

    canvas.save();
    canvas.translate(busX, busY);
    canvas.rotate(tiltAngle);
    canvas.translate(-busX, -busY);

    _drawModernBus(
      canvas,
      busX,
      busY,
      140,
      72,
      doorOpen,
      wheelRotation,
      busOpacity,
      loopAnimation,
    );

    canvas.restore();
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
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), skyPaint);
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
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), skyPaint);
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
    canvas.drawCircle(sunCenter, 20, Paint()..color = const Color(0xFFFFD54F));
  }

  void _drawMoon(Canvas canvas, Size size) {
    final moonCenter = Offset(size.width * 0.85, size.height * 0.18);

    // Moon glow
    final glowPaint = Paint()
      ..color = const Color(0xFFF5F5F5).withValues(alpha: 0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawCircle(moonCenter, 40, glowPaint);

    // Moon body
    canvas.drawCircle(moonCenter, 22, Paint()..color = const Color(0xFFF5F5F5));

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
      Offset(x + size * 0.5, y + size * 0.1),
      size * 0.25,
      cloudPaint,
    );
    canvas.drawCircle(
      Offset(x - size * 0.5, y + size * 0.1),
      size * 0.25,
      cloudPaint,
    );
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

  void _drawChild(
    Canvas canvas,
    double x,
    double y,
    double opacity, {
    required bool isExiting,
    required double exitProgress,
  }) {
    if (opacity <= 0) return;

    final walkOffset = isExiting ? exitProgress * 30 : 0;
    final finalX = isExiting ? x - walkOffset : x;

    Color withOpacity(Color color) => color.withValues(alpha: opacity);

    // Realistic child proportions
    final double headY = y - 35;
    final double bodyY = y - 20;
    final double legY = y - 5;

    // Animation for walking (legs and arms swinging) based on position
    final double walkCycle = (finalX / 15.0) * pi * 2;
    final double legSwing = sin(walkCycle) * 8; // Max swing 8px
    final double armSwing = cos(walkCycle) * 6;
    final double bounce = cos(walkCycle).abs() * 2;

    // Shadow
    canvas.drawOval(
      Rect.fromCenter(center: Offset(finalX, y + 10), width: 16, height: 4),
      Paint()
        ..color = withOpacity(Colors.black38)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    // Draw Backpack (behind body)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(finalX - 10, bodyY - 5, 8, 16),
        const Radius.circular(3),
      ),
      Paint()..color = withOpacity(const Color(0xFFE53935)), // Red backpack
    );
    canvas.drawRRect(
      // Backpack pocket
      RRect.fromRectAndRadius(
        Rect.fromLTWH(finalX - 12, bodyY, 4, 10),
        const Radius.circular(2),
      ),
      Paint()..color = withOpacity(const Color(0xFFC62828)),
    );

    // Left arm (back)
    final armPaint = Paint()
      ..color =
          withOpacity(const Color(0xFFFDD835)) // Yellow jacket sleeve
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(finalX, bodyY - 2 - bounce),
      Offset(finalX + armSwing, bodyY + 10 - bounce),
      armPaint,
    );
    // Hand
    canvas.drawCircle(
      Offset(finalX + armSwing, bodyY + 12 - bounce),
      2.5,
      Paint()..color = withOpacity(const Color(0xFFFFBCAA)),
    );

    // Left leg (back)
    final legPaint = Paint()
      ..color =
          withOpacity(const Color(0xFF1565C0)) // Blue jeans
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(finalX, legY - bounce),
      Offset(finalX + legSwing, legY + 12 - bounce),
      legPaint,
    );
    // Left shoe
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(finalX + legSwing - 2, legY + 12 - bounce, 8, 4),
        const Radius.circular(2),
      ),
      Paint()..color = withOpacity(const Color(0xFF424242)),
    );

    // Body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(finalX - 5, bodyY - 6 - bounce, 10, 18),
        const Radius.circular(4),
      ),
      Paint()
        ..color = withOpacity(const Color(0xFFFEE000)), // Yellow jacket core
    );
    // Jacket details
    canvas.drawLine(
      Offset(finalX + 2, bodyY - 6 - bounce),
      Offset(finalX + 2, bodyY + 12 - bounce),
      Paint()
        ..color = withOpacity(const Color(0xFFF57F17))
        ..strokeWidth = 1.5,
    );

    // Right leg (front)
    canvas.drawLine(
      Offset(finalX, legY - bounce),
      Offset(finalX - legSwing, legY + 12 - bounce),
      legPaint,
    );
    // Right shoe
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(finalX - legSwing - 2, legY + 12 - bounce, 8, 4),
        const Radius.circular(2),
      ),
      Paint()..color = withOpacity(const Color(0xFF212121)),
    );

    // Right arm (front)
    canvas.drawLine(
      Offset(finalX, bodyY - 2 - bounce),
      Offset(finalX - armSwing, bodyY + 10 - bounce),
      armPaint,
    );
    // Hand
    canvas.drawCircle(
      Offset(finalX - armSwing, bodyY + 12 - bounce),
      2.5,
      Paint()..color = withOpacity(const Color(0xFFFFBCAA)),
    );

    // Head
    canvas.drawCircle(
      Offset(finalX, headY - bounce),
      7,
      Paint()..color = withOpacity(const Color(0xFFFFBCAA)),
    );
    // Hair
    final hairPath = Path()
      ..moveTo(finalX - 7, headY - bounce)
      ..quadraticBezierTo(
        finalX,
        headY - 12 - bounce,
        finalX + 7,
        headY - bounce,
      )
      ..quadraticBezierTo(
        finalX + 8,
        headY - 5 - bounce,
        finalX + 5,
        headY - 2 - bounce,
      )
      ..lineTo(finalX - 5, headY - 2 - bounce)
      ..close();
    canvas.drawPath(
      hairPath,
      Paint()..color = withOpacity(const Color(0xFF3E2723)),
    ); // Dark brown hair
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
    double loopAnimation,
  ) {
    Color withOpacity(Color color) =>
        color.withValues(alpha: color.a * opacity);

    final bool facingLeft = isDark;

    // Scale up the bus for realistic Type C proportions
    final bw = width * 1.5; // Made slightly longer for proper hood proportion
    final bh = height * 1.2;

    final hw = bw / 2;
    final hh = bh / 2;

    final primaryColor = withOpacity(
      const Color(0xFFFFCC00),
    ); // School bus yellow
    final bumperColor = withOpacity(const Color(0xFF212121));
    final windowColor = withOpacity(
      isDark ? const Color(0xFF34495E) : const Color(0xFF81D4FA),
    );
    final rubRailColor = withOpacity(const Color(0xFF151515));

    final double wheelY = hh * 0.75;
    final double backWheelX = -hw * 0.6;
    final double frontWheelX = hw * 0.72;

    // Shadow (drawn under where the bus will be)
    final shadowPaint = Paint()
      ..color = withOpacity(Colors.black.withValues(alpha: isDark ? 0.4 : 0.2))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(x, y + wheelY + 8),
        width: bw * 0.95,
        height: 16,
      ),
      shadowPaint,
    );

    canvas.save();
    canvas.translate(x, y);
    if (facingLeft) {
      canvas.scale(-1, 1);
    }

    // Main body path (Realistic Type C Conventional)
    final bodyPath = Path()
      ..moveTo(-hw + 8, -hh)
      ..lineTo(hw * 0.35, -hh) // Roof flat
      ..quadraticBezierTo(
        hw * 0.45,
        -hh,
        hw * 0.48,
        -hh * 0.8,
      ) // Front roof cap
      ..lineTo(hw * 0.56, hh * 0.05) // Windshield slope downward (A-Pillar)
      ..quadraticBezierTo(
        hw * 0.58,
        hh * 0.1,
        hw * 0.62,
        hh * 0.12,
      ) // Cowl curve
      ..lineTo(hw - 10, hh * 0.16) // Hood sloping down a bit
      ..quadraticBezierTo(hw - 2, hh * 0.18, hw, hh * 0.35) // Front nose curve
      ..lineTo(hw, hh * 0.75 - 8) // Grille/Nose drop
      ..quadraticBezierTo(
        hw,
        hh * 0.75,
        hw - 8,
        hh * 0.75,
      ) // Front bumper bottom
      ..lineTo(-hw + 8, hh * 0.75)
      ..quadraticBezierTo(-hw, hh * 0.75, -hw, hh * 0.75 - 8)
      ..lineTo(-hw, -hh + 10)
      ..quadraticBezierTo(-hw, -hh, -hw + 10, -hh)
      ..close();

    final bodyPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(bodyPath, bodyPaint);

    // Front grille lines (black prominent grille)
    final grilleRect = Rect.fromLTWH(hw - 10, hh * 0.25, 12, hh * 0.4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(grilleRect, const Radius.circular(2)),
      Paint()..color = bumperColor,
    );
    final slatPaint = Paint()
      ..color = primaryColor
      ..strokeWidth = 1.0;
    for (int i = 1; i < 6; i++) {
      canvas.drawLine(
        Offset(hw - 10, hh * 0.25 + i * (hh * 0.4) / 6),
        Offset(hw, hh * 0.25 + i * (hh * 0.4) / 6),
        slatPaint,
      );
    }

    // Bumpers
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(hw - 4, hh * 0.6, 8, hh * 0.2),
        const Radius.circular(2),
      ),
      Paint()..color = bumperColor,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-hw - 4, hh * 0.6, 8, hh * 0.2),
        const Radius.circular(2),
      ),
      Paint()..color = bumperColor,
    );

    // Fenders/Wheel wells
    final wheelWellPaint = Paint()..color = bumperColor;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(backWheelX, wheelY), radius: 22),
      pi,
      pi,
      true,
      wheelWellPaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(frontWheelX, wheelY), radius: 22),
      pi,
      pi,
      true,
      wheelWellPaint,
    );

    // Fender arch outers
    final fenderPaint = Paint()
      ..color = rubRailColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(backWheelX, wheelY), radius: 24),
      pi,
      pi,
      false,
      fenderPaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(frontWheelX, wheelY), radius: 24),
      pi,
      pi,
      false,
      fenderPaint,
    );

    // Rub rails
    final rubRailPaint = Paint()
      ..color = rubRailColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawLine(
      Offset(-hw, -hh * 0.05),
      Offset(hw * 0.58, -hh * 0.05),
      rubRailPaint,
    );
    canvas.drawLine(
      Offset(-hw, hh * 0.25),
      Offset(hw * 0.61, hh * 0.25),
      rubRailPaint,
    );
    canvas.drawLine(
      Offset(-hw, hh * 0.55),
      Offset(hw * 0.64, hh * 0.55),
      rubRailPaint,
    );

    // Door positioning
    double doorX = hw * 0.16;
    double doorW = hw * 0.24;
    double doorH = hh * 1.5;
    double doorY = -hh * 0.75;

    // Side Windows
    int numWindows = 5;
    double windowsStartX = -hw + 4;
    double windowsEndX = doorX - 6;
    double windowZoneWidth = windowsEndX - windowsStartX;
    double windowWidth = windowZoneWidth / numWindows;
    // Window background strip
    canvas.drawRect(
      Rect.fromLTWH(
        windowsStartX - 2,
        -hh * 0.78,
        windowZoneWidth + 4,
        hh * 0.68,
      ),
      Paint()..color = bumperColor,
    );

    for (int i = 0; i < numWindows; i++) {
      double wx = windowsStartX + i * windowWidth;
      // Window glass
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(wx + 2, -hh * 0.75, windowWidth - 4, hh * 0.60),
          const Radius.circular(2),
        ),
        Paint()..color = windowColor,
      );
      // Window reflections
      canvas.drawLine(
        Offset(wx + 4, -hh * 0.65),
        Offset(wx + windowWidth - 4, -hh * 0.65),
        Paint()
          ..color = withOpacity(
            Colors.white.withValues(alpha: isDark ? 0.2 : 0.4),
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    // Driver's side window / Side glass before windshield
    final driverWindowPath = Path()
      ..moveTo(doorX + doorW + 2, -hh * 0.78) // Top left
      ..lineTo(hw * 0.47, -hh * 0.78) // Top right
      ..lineTo(hw * 0.55, -hh * 0.1) // Bottom right (along cowl)
      ..lineTo(doorX + doorW + 2, -hh * 0.1) // Bottom left
      ..close();
    canvas.drawPath(driverWindowPath, Paint()..color = bumperColor);

    // Glass portion
    final innerGlassPath = Path()
      ..moveTo(doorX + doorW + 4, -hh * 0.75)
      ..lineTo(hw * 0.45, -hh * 0.75)
      ..lineTo(hw * 0.52, -hh * 0.15)
      ..lineTo(doorX + doorW + 4, -hh * 0.15)
      ..close();
    canvas.drawPath(innerGlassPath, Paint()..color = windowColor);

    // Back of door opening
    canvas.drawRect(
      Rect.fromLTWH(doorX, doorY, doorW, doorH),
      Paint()..color = withOpacity(const Color(0xFF111111)),
    );

    // Bi-fold door panels
    double panelPhase = 1.0 - doorOpen * 0.75; // 1.0 closed, 0.25 open
    double panelW = (doorW / 2) * panelPhase;
    double p1X = doorX + doorW - panelW; // Front panel
    double p2X = doorX; // Back panel

    // Panel function
    void drawDoorPanel(double px) {
      canvas.drawRect(
        Rect.fromLTWH(px, doorY, panelW, doorH),
        Paint()..color = primaryColor,
      );
      canvas.drawRect(
        Rect.fromLTWH(px, doorY, panelW, doorH),
        Paint()
          ..color = bumperColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      // Panel windows (top and bottom)
      canvas.drawRect(
        Rect.fromLTWH(px + 2, doorY + 2, panelW - 4, doorH * 0.42),
        Paint()..color = windowColor,
      );
      canvas.drawRect(
        Rect.fromLTWH(px + 2, doorY + doorH * 0.48, panelW - 4, doorH * 0.42),
        Paint()..color = windowColor,
      );
    }

    if (doorOpen < 0.95) {
      // Hide completely if extremely open to simulate folding in
      drawDoorPanel(p2X);
      drawDoorPanel(p1X);
    }

    // Stop Sign (Extended when door open)
    if (doorOpen > 0.05) {
      canvas.save();
      canvas.translate(doorX - 5, hh * 0.1);
      canvas.scale(doorOpen, 1.0); // Animate extending

      final stopSignPaint = Paint()..color = withOpacity(Colors.red);
      final r = 11.0;
      final octPath = Path()
        ..moveTo(-r / 2, -r)
        ..lineTo(r / 2, -r)
        ..lineTo(r, -r / 2)
        ..lineTo(r, r / 2)
        ..lineTo(r / 2, r)
        ..lineTo(-r / 2, r)
        ..lineTo(-r, r / 2)
        ..lineTo(-r, -r / 2)
        ..close();

      canvas.drawPath(octPath, stopSignPaint);
      canvas.drawPath(
        octPath,
        Paint()
          ..color = withOpacity(Colors.white)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      // Flashing lights on stop sign
      final bool signFlash = (loopAnimation * 6).floor() % 2 == 0;
      canvas.drawCircle(
        Offset(0, -r + 3.5),
        2.5,
        Paint()
          ..color = withOpacity(signFlash ? Colors.white : Colors.red[900]!),
      );
      canvas.drawCircle(
        Offset(0, r - 3.5),
        2.5,
        Paint()
          ..color = withOpacity(!signFlash ? Colors.white : Colors.red[900]!),
      );
      canvas.restore();
    }

    // Wheels
    _drawSpinningWheel(
      canvas,
      backWheelX,
      wheelY,
      19,
      wheelRotation,
      opacity,
      bumperColor,
    );
    _drawSpinningWheel(
      canvas,
      frontWheelX,
      wheelY,
      19,
      wheelRotation,
      opacity,
      bumperColor,
    );

    // Warning Lights (flashing)
    final bool flashPhase1 = (loopAnimation * 4).floor() % 2 == 0;
    final bool showWarningLights =
        doorOpen > 0 || (busPosition > 0.35 && busPosition < 0.65);

    final Paint redPaint1 = Paint()
      ..color = withOpacity(flashPhase1 ? Colors.redAccent : Colors.red[900]!)
      ..maskFilter = (showWarningLights && flashPhase1)
          ? const MaskFilter.blur(BlurStyle.normal, 5)
          : null;
    final Paint redPaint2 = Paint()
      ..color = withOpacity(!flashPhase1 ? Colors.redAccent : Colors.red[900]!)
      ..maskFilter = (showWarningLights && !flashPhase1)
          ? const MaskFilter.blur(BlurStyle.normal, 5)
          : null;

    canvas.drawCircle(
      Offset(hw * 0.40, -hh + 5),
      3.5,
      showWarningLights ? redPaint1 : Paint()
        ..color = withOpacity(Colors.red[900]!),
    );
    canvas.drawCircle(
      Offset(hw * 0.28, -hh + 5),
      3.5,
      showWarningLights ? redPaint2 : Paint()
        ..color = withOpacity(Colors.red[900]!),
    );
    canvas.drawCircle(
      Offset(-hw + 8, -hh + 5),
      3.5,
      showWarningLights ? redPaint1 : Paint()
        ..color = withOpacity(Colors.red[900]!),
    );
    canvas.drawCircle(
      Offset(-hw + 20, -hh + 5),
      3.5,
      showWarningLights ? redPaint2 : Paint()
        ..color = withOpacity(Colors.red[900]!),
    );

    // Sign details
    Paint signPaint = Paint()
      ..color = bumperColor
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(hw * 0.22, -hh * 0.95, 24, 7), signPaint);
    canvas.drawRect(Rect.fromLTWH(-hw + 4, -hh * 0.95, 24, 7), signPaint);

    // Headlights
    final headlightPaint = Paint()
      ..color = withOpacity(const Color(0xFFFFF59D))
      ..maskFilter = isDark ? const MaskFilter.blur(BlurStyle.normal, 8) : null;
    canvas.drawRect(
      Rect.fromLTWH(hw - 4, hh * 0.28, 4, 10),
      Paint()..color = withOpacity(Colors.grey[300]!),
    );
    canvas.drawCircle(Offset(hw - 2, hh * 0.33), 3, headlightPaint);

    if (isDark) {
      final beamPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            withOpacity(const Color(0xFFFFF59D).withValues(alpha: 0.6)),
            withOpacity(const Color(0xFFFFF59D).withValues(alpha: 0)),
          ],
        ).createShader(Rect.fromLTWH(hw, hh * 0.1, 90, 60));

      final beamPath = Path()
        ..moveTo(hw, hh * 0.33)
        ..lineTo(hw + 80, hh * 0.1)
        ..lineTo(hw + 80, hh * 0.8)
        ..close();
      canvas.drawPath(beamPath, beamPaint);
    }

    // Taillight
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-hw - 1, hh * 0.35, 4, 12),
        const Radius.circular(2),
      ),
      Paint()..color = withOpacity(Colors.red),
    );

    canvas.restore(); // Restore facing right/left scale

    // Exhaust smoke handling (adjust exhaust position)
    final isAccelerating = busTilt < -0.01;
    final isIdle = busPosition > 0.4 && busPosition < 0.6;
    if ((isAccelerating || isIdle) && opacity > 0.3) {
      double exhaustX = facingLeft ? x + hw - 5 : x - hw + 5;
      double exhaustY = y + hh * 0.7;
      _drawExhaustSmoke(
        canvas,
        exhaustX,
        exhaustY,
        loopAnimation,
        isAccelerating,
        facingLeft,
      );
    }
  }

  void _drawSpinningWheel(
    Canvas canvas,
    double x,
    double y,
    double radius,
    double rotation,
    double opacity,
    Color bumperColor,
  ) {
    Color withOpacity(Color color) =>
        color.withValues(alpha: color.a * opacity);

    // Tire
    canvas.drawCircle(
      Offset(x, y),
      radius,
      Paint()..color = withOpacity(const Color(0xFF151515)),
    );

    // Rim (steel wheel typical of school buses)
    canvas.drawCircle(
      Offset(x, y),
      radius * 0.6,
      Paint()..color = withOpacity(const Color(0xFF90A4AE)),
    );
    canvas.drawCircle(
      Offset(x, y),
      radius * 0.6,
      Paint()
        ..color = bumperColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Hubcap center
    canvas.drawCircle(
      Offset(x, y),
      radius * 0.2,
      Paint()..color = withOpacity(const Color(0xFF455A64)),
    );

    // Holes in the steel rim
    final holePaint = Paint()..color = withOpacity(const Color(0xFF263238));
    for (int i = 0; i < 6; i++) {
      final angle = rotation + i * 2 * pi / 6;
      canvas.drawCircle(
        Offset(x + radius * 0.4 * cos(angle), y + radius * 0.4 * sin(angle)),
        2.5,
        holePaint,
      );
    }
  }

  void _drawExhaustSmoke(
    Canvas canvas,
    double exhaustX,
    double exhaustY,
    double loopAnimation,
    bool overSpeed,
    bool facingLeft,
  ) {
    for (int i = 0; i < 3; i++) {
      double progress = (loopAnimation + i * 0.33) % 1.0;

      double spreadX = progress * (overSpeed ? 40 : 15) * (facingLeft ? 1 : -1);
      final spreadY = -(progress * 15) - sin(progress * pi) * 5;

      final currentX = exhaustX + spreadX;
      final currentY = exhaustY + spreadY;

      final radius = 3.0 + progress * (overSpeed ? 12.0 : 6.0);
      final alpha = 1.0 - progress;

      if (alpha > 0.01) {
        final smokePaint = Paint()
          ..color = (isDark ? const Color(0xFF6A7A8A) : const Color(0xFF909090))
              .withValues(alpha: alpha * 0.5)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.5);
        canvas.drawCircle(Offset(currentX, currentY), radius, smokePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant ModernBusIllustrationPainter oldDelegate) {
    return oldDelegate.busPosition != busPosition ||
        oldDelegate.busBounce != busBounce ||
        oldDelegate.busTilt != busTilt ||
        oldDelegate.childOpacity != childOpacity ||
        oldDelegate.childPosition != childPosition ||
        oldDelegate.doorOpen != doorOpen ||
        oldDelegate.loopAnimation != loopAnimation ||
        oldDelegate.isDark != isDark;
  }
}
