import 'dart:math' show cos, sin;
import 'package:flutter/material.dart';

class BusIllustration extends StatefulWidget {
  final double height;

  const BusIllustration({super.key, this.height = 200});

  @override
  State<BusIllustration> createState() => _BusIllustrationState();
}

class _BusIllustrationState extends State<BusIllustration>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _busPosition;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );

    _busPosition = Tween<double>(
      begin: -0.2,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.linear,
    ));

    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            size: Size(double.infinity, widget.height),
            painter: BusIllustrationPainter(
              busPosition: _busPosition.value,
            ),
          );
        },
      ),
    );
  }
}

class BusIllustrationPainter extends CustomPainter {
  final double busPosition;

  BusIllustrationPainter({this.busPosition = 0.35});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    // Draw sky gradient
    final skyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFE8F5E9).withValues(alpha: 0.5),
          const Color(0xFFF5F5F0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      skyPaint,
    );

    // Draw sun
    final sunPaint = Paint()..color = const Color(0xFFFFB800).withValues(alpha: 0.2);
    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.25),
      30,
      sunPaint,
    );

    // Draw clouds
    _drawCloud(canvas, size.width * 0.2, size.height * 0.2, 25);
    _drawCloud(canvas, size.width * 0.6, size.height * 0.15, 20);
    _drawCloud(canvas, size.width * 0.9, size.height * 0.25, 22);

    // Draw ground/hills
    _drawHills(canvas, size);

    // Draw ground line
    paint.color = const Color(0xFFD0D0D0);
    paint.strokeWidth = 2;
    canvas.drawLine(
      Offset(0, size.height - 25),
      Offset(size.width, size.height - 25),
      paint,
    );

    // Draw trees (background)
    _drawTree(canvas, size.width * 0.08, size.height - 45, 25, const Color(0xFF8BC48A));
    _drawTree(canvas, size.width * 0.18, size.height - 55, 30, const Color(0xFF6B9B5B));
    _drawTree(canvas, size.width * 0.88, size.height - 50, 28, const Color(0xFF8BC48A));
    _drawTree(canvas, size.width * 0.95, size.height - 60, 35, const Color(0xFF6B9B5B));

    // Draw animated bus at current position
    final busX = size.width * busPosition;
    _drawBus(canvas, busX, size.height - 90, 130, 65);

    // Draw road markings
    _drawRoadMarkings(canvas, size);
  }

  void _drawCloud(Canvas canvas, double x, double y, double size) {
    final cloudPaint = Paint()..color = Colors.white.withValues(alpha: 0.8);
    
    canvas.drawCircle(Offset(x, y), size * 0.5, cloudPaint);
    canvas.drawCircle(Offset(x + size * 0.4, y), size * 0.4, cloudPaint);
    canvas.drawCircle(Offset(x - size * 0.4, y), size * 0.35, cloudPaint);
    canvas.drawCircle(Offset(x, y - size * 0.3), size * 0.35, cloudPaint);
  }

  void _drawHills(Canvas canvas, Size size) {
    final hillsPaint = Paint()
      ..color = const Color(0xFFE8F5E9)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, size.height - 40)
      ..quadraticBezierTo(
        size.width * 0.25,
        size.height - 80,
        size.width * 0.5,
        size.height - 50,
      )
      ..quadraticBezierTo(
        size.width * 0.75,
        size.height - 20,
        size.width,
        size.height - 45,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, hillsPaint);
  }

  void _drawRoadMarkings(Canvas canvas, Size size) {
    final markingPaint = Paint()
      ..color = const Color(0xFFFFB800).withValues(alpha: 0.6)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final dashWidth = 20.0;
    final dashSpace = 30.0;
    final y = size.height - 25;

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

  void _drawTree(Canvas canvas, double x, double y, double size, Color color) {
    final paint = Paint()..color = color;

    // Tree trunk
    final trunkPaint = Paint()..color = const Color(0xFF8B7355);
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(x, y),
        width: size * 0.12,
        height: size * 0.5,
      ),
      trunkPaint,
    );

    // Tree foliage (3 circles)
    canvas.drawCircle(Offset(x, y - size * 0.45), size * 0.45, paint);
    canvas.drawCircle(Offset(x - size * 0.25, y - size * 0.25), size * 0.3, paint);
    canvas.drawCircle(Offset(x + size * 0.25, y - size * 0.25), size * 0.3, paint);
  }

  void _drawBus(Canvas canvas, double x, double y, double width, double height) {
    final busBodyPaint = Paint()..color = const Color(0xFFFFB800);
    final windowPaint = Paint()..color = const Color(0xFF87CEEB);
    final wheelPaint = Paint()..color = const Color(0xFF333333);
    final rimPaint = Paint()..color = const Color(0xFF888888);
    final stripePaint = Paint()..color = const Color(0xFFDC143C);
    final doorPaint = Paint()..color = const Color(0xFF444444);

    // Bus shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(x, y + height * 0.45),
        width: width * 0.9,
        height: 15,
      ),
      shadowPaint,
    );

    // Bus body
    final busRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(x, y), width: width, height: height),
      const Radius.circular(14),
    );
    canvas.drawRRect(busRect, busBodyPaint);

    // Red stripe on bus
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(x, y + 3),
        width: width - 6,
        height: 10,
      ),
      stripePaint,
    );

    // Door
    final doorRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x + width * 0.25, y - height * 0.15, 22, height * 0.55),
      const Radius.circular(4),
    );
    canvas.drawRRect(doorRect, doorPaint);

    // Windows
    final windowWidth = (width - 50) / 4;
    for (int i = 0; i < 4; i++) {
      final windowX = x - width / 2 + 15 + i * (windowWidth + 5);
      // Skip window where door is
      if (i == 2) continue;
      
      final windowRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          windowX,
          y - height / 2 + 12,
          windowWidth,
          height * 0.32,
        ),
        const Radius.circular(5),
      );
      canvas.drawRRect(windowRect, windowPaint);
      
      // Window reflection
      final reflectionPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawLine(
        Offset(windowX + 3, y - height / 2 + 16),
        Offset(windowX + windowWidth - 3, y - height / 2 + 16),
        reflectionPaint,
      );
    }

    // Front window
    final frontWindowRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        x + width / 2 - 16,
        y - height / 2 + 12,
        12,
        height * 0.32,
      ),
      const Radius.circular(4),
    );
    canvas.drawRRect(frontWindowRect, windowPaint);

    // Wheels
    final wheelRadius = height * 0.2;
    // Front wheel
    _drawWheel(canvas, x + width * 0.28, y + height * 0.42, wheelRadius);
    // Back wheel
    _drawWheel(canvas, x - width * 0.28, y + height * 0.42, wheelRadius);

    // Headlight
    final headlightPaint = Paint()
      ..color = const Color(0xFFFFEEAA)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(
      Offset(x + width / 2 - 5, y + 6),
      6,
      headlightPaint,
    );
    canvas.drawCircle(
      Offset(x + width / 2 - 5, y + 6),
      4,
      Paint()..color = const Color(0xFFFFF8E1),
    );

    // Taillight
    canvas.drawCircle(
      Offset(x - width / 2 + 5, y + 6),
      4,
      Paint()..color = const Color(0xFFFF4444),
    );

    // School bus sign
    final signPaint = Paint()..color = const Color(0xFFFF4444);
    final signRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(x - width * 0.15, y - height / 2 - 8),
        width: 40,
        height: 14,
      ),
      const Radius.circular(3),
    );
    canvas.drawRRect(signRect, signPaint);
  }

  void _drawWheel(Canvas canvas, double x, double y, double radius) {
    // Tire
    canvas.drawCircle(
      Offset(x, y),
      radius,
      Paint()..color = const Color(0xFF333333),
    );
    
    // Rim
    canvas.drawCircle(
      Offset(x, y),
      radius * 0.6,
      Paint()..color = const Color(0xFF888888),
    );
    
    // Hubcap
    canvas.drawCircle(
      Offset(x, y),
      radius * 0.3,
      Paint()..color = const Color(0xFFCCCCCC),
    );
    
    // Spokes
    final spokePaint = Paint()
      ..color = const Color(0xFF666666)
      ..strokeWidth = 2;
    
    for (int i = 0; i < 4; i++) {
      final angle = i * 3.14159 / 2;
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
  bool shouldRepaint(covariant BusIllustrationPainter oldDelegate) {
    return oldDelegate.busPosition != busPosition;
  }
}
