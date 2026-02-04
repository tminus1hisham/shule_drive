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
  
  // Bus animation
  late Animation<double> _busPosition;
  late Animation<double> _busBounce;
  
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

    // Bus enters from left (0-20%)
    _busPosition = TweenSequence<double>([
      // Drive in from left
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.3, end: 0.5)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 20,
      ),
      // Stop and wait for child (20-50%)
      TweenSequenceItem(
        tween: ConstantTween<double>(0.5),
        weight: 30,
      ),
      // Drive off to right (50-80%)
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.5, end: 1.3)
            .chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 30,
      ),
      // Reset pause (80-100%)
      TweenSequenceItem(
        tween: ConstantTween<double>(1.3),
        weight: 20,
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

    // Child appears and walks to bus
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

    _mainController.repeat();
  }

  @override
  void dispose() {
    _mainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _mainController,
        builder: (context, child) {
          return CustomPaint(
            size: Size(double.infinity, widget.height),
            painter: ModernBusIllustrationPainter(
              busPosition: _busPosition.value,
              busBounce: _busBounce.value,
              childOpacity: _childOpacity.value,
              childPosition: _childPosition.value,
              doorOpen: _doorOpen.value,
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

  ModernBusIllustrationPainter({
    required this.busPosition,
    required this.busBounce,
    required this.childOpacity,
    required this.childPosition,
    required this.doorOpen,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw sky gradient
    _drawSky(canvas, size);

    // Draw sun with glow
    _drawSun(canvas, size);

    // Draw clouds
    _drawCloud(canvas, size.width * 0.15, size.height * 0.18, 30);
    _drawCloud(canvas, size.width * 0.55, size.height * 0.12, 25);
    _drawCloud(canvas, size.width * 0.85, size.height * 0.22, 28);

    // Draw hills/background
    _drawHills(canvas, size);

    // Draw road
    _drawRoad(canvas, size);

    // Draw trees
    _drawModernTree(canvas, size.width * 0.08, size.height - 50, 30);
    _drawModernTree(canvas, size.width * 0.92, size.height - 55, 35);

    // Draw child waiting
    if (childOpacity > 0) {
      _drawChild(
        canvas,
        size.width * childPosition,
        size.height - 70,
        childOpacity,
      );
    }

    // Calculate bus bounce offset (idle vibration when stopped)
    double bounceY = 0;
    if (busPosition > 0.4 && busPosition < 0.6) {
      bounceY = sin(busBounce * 3) * 1.5;
    }

    // Draw bus
    final busX = size.width * busPosition;
    _drawModernBus(
      canvas,
      busX,
      size.height - 95 + bounceY,
      140,
      72,
      doorOpen,
    );
  }

  void _drawSky(Canvas canvas, Size size) {
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
    canvas.drawCircle(Offset(x + size * 0.5, y + size * 0.1), size * 0.25, cloudPaint);
    canvas.drawCircle(Offset(x - size * 0.5, y + size * 0.1), size * 0.25, cloudPaint);
  }

  void _drawHills(Canvas canvas, Size size) {
    // Back hills - lighter
    final backHillsPaint = Paint()
      ..color = const Color(0xFFC8E6C9)
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
      ..color = const Color(0xFFA5D6A7)
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
      ..color = const Color(0xFFE0E0E0)
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
        ..color = const Color(0xFFBDBDBD)
        ..strokeWidth = 1,
    );

    // Road markings (dashed line)
    final markingPaint = Paint()
      ..color = const Color(0xFFFFB800)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final dashWidth = 25.0;
    final dashSpace = 35.0;
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
      ..color = const Color(0xFF66BB6A)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(x, y - size * 0.7)
      ..lineTo(x + size * 0.35, y - size * 0.1)
      ..lineTo(x - size * 0.35, y - size * 0.1)
      ..close();
    canvas.drawPath(path, foliagePaint);

    // Highlight
    final highlightPaint = Paint()
      ..color = const Color(0xFF81C784)
      ..style = PaintingStyle.fill;
    
    final highlightPath = Path()
      ..moveTo(x, y - size * 0.7)
      ..lineTo(x + size * 0.15, y - size * 0.35)
      ..lineTo(x - size * 0.05, y - size * 0.35)
      ..close();
    canvas.drawPath(highlightPath, highlightPaint);
  }

  void _drawChild(Canvas canvas, double x, double y, double opacity) {
    final childPaint = Paint()
      ..color = Colors.black.withValues(alpha: opacity);

    // Head
    canvas.drawCircle(
      Offset(x, y - 25),
      8,
      Paint()..color = Color.fromRGBO(255, 200, 150, opacity),
    );

    // Body
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(x, y - 12),
        width: 14,
        height: 18,
      ),
      Paint()..color = Color.fromRGBO(100, 150, 255, opacity),
    );

    // Backpack
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(x - 10, y - 12),
        width: 8,
        height: 14,
      ),
      Paint()..color = Color.fromRGBO(255, 100, 100, opacity),
    );

    // Legs
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(x - 4, y + 5),
        width: 5,
        height: 16,
      ),
      Paint()..color = Color.fromRGBO(80, 80, 100, opacity),
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(x + 4, y + 5),
        width: 5,
        height: 16,
      ),
      Paint()..color = Color.fromRGBO(80, 80, 100, opacity),
    );

    // Arms (waving)
    final armPaint = Paint()
      ..color = Color.fromRGBO(255, 200, 150, opacity)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    
    // Right arm waving
    canvas.drawLine(
      Offset(x + 7, y - 18),
      Offset(x + 15, y - 28),
      armPaint,
    );
    
    // Left arm
    canvas.drawLine(
      Offset(x - 7, y - 18),
      Offset(x - 12, y - 8),
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
  ) {
    // Modern color scheme
    const primaryColor = Color(0xFFFFB300);  // Amber yellow
    const secondaryColor = Color(0xFF212121); // Dark gray
    const accentColor = Color(0xFF4CAF50);   // Green
    const windowColor = Color(0xFF81D4FA);   // Light blue

    // Bus shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(x, y + height * 0.48),
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
        ..color = Colors.white.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawLine(
        Offset(windowX + 5, y - height / 2 + 22),
        Offset(windowX + windowWidth - 5, y - height / 2 + 22),
        reflectionPaint,
      );
    }

    // Front windshield
    final windshieldPath = Path()
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
    final doorOffset = doorOpen * (doorWidth * 0.6); // Slide open

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
      Paint()..color = const Color(0xFF424242),
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

    // Modern wheels (larger, stylized)
    _drawModernWheel(canvas, x + width * 0.25, y + height * 0.42, 16);
    _drawModernWheel(canvas, x - width * 0.25, y + height * 0.42, 16);

    // LED Headlights
    final headlightPaint = Paint()
      ..color = const Color(0xFFFFF59D)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x + width / 2 - 8, y + 5, 6, 10),
        const Radius.circular(3),
      ),
      headlightPaint,
    );
    
    // Headlight beam
    final beamPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          const Color(0xFFFFF59D).withValues(alpha: 0.3),
          const Color(0xFFFFF59D).withValues(alpha: 0),
        ],
      ).createShader(Rect.fromLTWH(x + width / 2, y, 60, 20));
    
    final beamPath = Path()
      ..moveTo(x + width / 2 - 2, y + 5)
      ..lineTo(x + width / 2 + 50, y - 5)
      ..lineTo(x + width / 2 + 50, y + 25)
      ..lineTo(x + width / 2 - 2, y + 15)
      ..close();
    canvas.drawPath(beamPath, beamPaint);

    // LED Taillights
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x - width / 2 + 2, y + 5, 6, 10),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFFFF5252),
    );

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
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x + width / 2 - 3, y - 15, 8, 12),
        const Radius.circular(2),
      ),
      Paint()..color = secondaryColor,
    );
  }

  void _drawModernWheel(Canvas canvas, double x, double y, double radius) {
    // Tire (black rubber)
    canvas.drawCircle(
      Offset(x, y),
      radius,
      Paint()..color = const Color(0xFF212121),
    );
    
    // Tire sidewall
    canvas.drawCircle(
      Offset(x, y),
      radius * 0.85,
      Paint()..color = const Color(0xFF424242),
    );
    
    // Rim (silver)
    canvas.drawCircle(
      Offset(x, y),
      radius * 0.6,
      Paint()..color = const Color(0xFFBDBDBD),
    );
    
    // Inner rim
    canvas.drawCircle(
      Offset(x, y),
      radius * 0.45,
      Paint()..color = const Color(0xFFE0E0E0),
    );
    
    // Hubcap center
    canvas.drawCircle(
      Offset(x, y),
      radius * 0.2,
      Paint()..color = const Color(0xFF757575),
    );
    
    // Spokes (5-spoke modern design)
    final spokePaint = Paint()
      ..color = const Color(0xFF9E9E9E)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    
    for (int i = 0; i < 5; i++) {
      final angle = i * 2 * pi / 5 - pi / 2;
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
        oldDelegate.doorOpen != doorOpen;
  }
}
