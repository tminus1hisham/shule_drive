import 'package:flutter/material.dart';

class BusIllustration extends StatelessWidget {
  final double height;

  const BusIllustration({super.key, this.height = 200});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(
        size: Size(double.infinity, height),
        painter: BusIllustrationPainter(),
      ),
    );
  }
}

class BusIllustrationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    
    // Draw ground line
    paint.color = const Color(0xFFE0E0E0);
    paint.strokeWidth = 2;
    canvas.drawLine(
      Offset(0, size.height - 20),
      Offset(size.width, size.height - 20),
      paint,
    );

    // Draw trees
    _drawTree(canvas, size.width * 0.15, size.height - 50, 35, const Color(0xFF6B9B5B));
    _drawTree(canvas, size.width * 0.25, size.height - 35, 25, const Color(0xFF8BC48A));
    _drawTree(canvas, size.width * 0.82, size.height - 55, 40, const Color(0xFF6B9B5B));
    _drawTree(canvas, size.width * 0.92, size.height - 40, 28, const Color(0xFF8BC48A));

    // Draw bus
    _drawBus(canvas, size.width * 0.35, size.height - 85, 140, 70);
  }

  void _drawTree(Canvas canvas, double x, double y, double size, Color color) {
    final paint = Paint()..color = color;
    
    // Tree trunk
    final trunkPaint = Paint()..color = const Color(0xFF8B7355);
    canvas.drawRect(
      Rect.fromCenter(center: Offset(x, y), width: size * 0.15, height: size * 0.6),
      trunkPaint,
    );
    
    // Tree foliage (3 circles)
    canvas.drawCircle(Offset(x, y - size * 0.5), size * 0.5, paint);
    canvas.drawCircle(Offset(x - size * 0.3, y - size * 0.3), size * 0.35, paint);
    canvas.drawCircle(Offset(x + size * 0.3, y - size * 0.3), size * 0.35, paint);
  }

  void _drawBus(Canvas canvas, double x, double y, double width, double height) {
    final busPaint = Paint()..color = const Color(0xFFFFB800);
    final windowPaint = Paint()..color = const Color(0xFF87CEEB);
    final wheelPaint = Paint()..color = const Color(0xFF333333);
    final rimPaint = Paint()..color = const Color(0xFF888888);
    final stripePaint = Paint()..color = const Color(0xFFDC143C);
    
    // Bus body
    final busRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(x, y), width: width, height: height),
      const Radius.circular(12),
    );
    canvas.drawRRect(busRect, busPaint);
    
    // Red stripe on bus
    canvas.drawRect(
      Rect.fromCenter(center: Offset(x, y + 5), width: width - 4, height: 8),
      stripePaint,
    );
    
    // Windows
    final windowWidth = (width - 30) / 5;
    for (int i = 0; i < 5; i++) {
      final windowX = x - width / 2 + 18 + i * (windowWidth + 4);
      final windowRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(windowX, y - height / 2 + 10, windowWidth, height * 0.35),
        const Radius.circular(4),
      );
      canvas.drawRRect(windowRect, windowPaint);
    }
    
    // Front window
    final frontWindowRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x + width / 2 - 18, y - height / 2 + 10, 14, height * 0.35),
      const Radius.circular(4),
    );
    canvas.drawRRect(frontWindowRect, windowPaint);
    
    // Wheels
    final wheelRadius = height * 0.22;
    // Front wheel
    canvas.drawCircle(Offset(x + width * 0.25, y + height * 0.4), wheelRadius, wheelPaint);
    canvas.drawCircle(Offset(x + width * 0.25, y + height * 0.4), wheelRadius * 0.5, rimPaint);
    
    // Back wheel
    canvas.drawCircle(Offset(x - width * 0.25, y + height * 0.4), wheelRadius, wheelPaint);
    canvas.drawCircle(Offset(x - width * 0.25, y + height * 0.4), wheelRadius * 0.5, rimPaint);
    
    // Headlight
    final headlightPaint = Paint()..color = const Color(0xFFFFEEAA);
    canvas.drawCircle(Offset(x + width / 2 - 6, y + 8), 5, headlightPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
