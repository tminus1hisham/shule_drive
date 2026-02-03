import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../widgets/main_scaffold.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final TextEditingController _previousController = TextEditingController();
  final TextEditingController _newController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool _obscurePrevious = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _previousController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return MainScaffold(
      title: 'Change Password',
      showBackButton: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Bus Illustration
            Container(
              height: 150,
              decoration: BoxDecoration(
                color: provider.cardColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: CustomPaint(
                size: const Size(double.infinity, 150),
                painter: MiniBusPainter(isDarkMode: provider.isDarkMode),
              ),
            ),

            const SizedBox(height: 16),

            // Form Fields
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: provider.cardColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPasswordField(
                    'Previous Passcode',
                    _previousController,
                    _obscurePrevious,
                    () => setState(() => _obscurePrevious = !_obscurePrevious),
                    provider,
                  ),
                  const SizedBox(height: 16),
                  _buildPasswordField(
                    'New Passcode',
                    _newController,
                    _obscureNew,
                    () => setState(() => _obscureNew = !_obscureNew),
                    provider,
                  ),
                  const SizedBox(height: 16),
                  _buildPasswordField(
                    'Confirm Passcode',
                    _confirmController,
                    _obscureConfirm,
                    () => setState(() => _obscureConfirm = !_obscureConfirm),
                    provider,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Save Changes Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B9B5B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Save Changes',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordField(
    String label,
    TextEditingController controller,
    bool obscureText,
    VoidCallback onToggle,
    AppProvider provider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: provider.textMutedColor,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          style: TextStyle(color: provider.textColor),
          decoration: InputDecoration(
            filled: true,
            fillColor: provider.isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            suffixIcon: TextButton(
              onPressed: onToggle,
              child: Text(
                obscureText ? 'Show' : 'Hide',
                style: const TextStyle(
                  color: Color(0xFF6B9B5B),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class MiniBusPainter extends CustomPainter {
  final bool isDarkMode;

  MiniBusPainter({required this.isDarkMode});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    
    // Draw ground line - adapt to dark mode
    paint.color = isDarkMode ? const Color(0xFF3A3A3A) : const Color(0xFFE0E0E0);
    paint.strokeWidth = 2;
    canvas.drawLine(
      Offset(size.width * 0.2, size.height - 20),
      Offset(size.width * 0.8, size.height - 20),
      paint,
    );

    // Draw trees
    _drawTree(canvas, size.width * 0.25, size.height - 40, 25, const Color(0xFF6B9B5B));
    _drawTree(canvas, size.width * 0.75, size.height - 45, 30, const Color(0xFF8BC48A));

    // Draw bus
    _drawBus(canvas, size.width * 0.5, size.height - 65, 100, 50);
  }

  void _drawTree(Canvas canvas, double x, double y, double size, Color color) {
    final paint = Paint()..color = color;
    final trunkPaint = Paint()..color = const Color(0xFF8B7355);
    canvas.drawRect(
      Rect.fromCenter(center: Offset(x, y), width: size * 0.15, height: size * 0.6),
      trunkPaint,
    );
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
    
    final busRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(x, y), width: width, height: height),
      const Radius.circular(8),
    );
    canvas.drawRRect(busRect, busPaint);
    
    canvas.drawRect(
      Rect.fromCenter(center: Offset(x, y + 3), width: width - 4, height: 6),
      stripePaint,
    );
    
    final windowWidth = (width - 20) / 4;
    for (int i = 0; i < 4; i++) {
      final windowX = x - width / 2 + 12 + i * (windowWidth + 3);
      final windowRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(windowX, y - height / 2 + 6, windowWidth, height * 0.35),
        const Radius.circular(3),
      );
      canvas.drawRRect(windowRect, windowPaint);
    }
    
    final wheelRadius = height * 0.22;
    canvas.drawCircle(Offset(x + width * 0.25, y + height * 0.4), wheelRadius, wheelPaint);
    canvas.drawCircle(Offset(x + width * 0.25, y + height * 0.4), wheelRadius * 0.5, rimPaint);
    canvas.drawCircle(Offset(x - width * 0.25, y + height * 0.4), wheelRadius, wheelPaint);
    canvas.drawCircle(Offset(x - width * 0.25, y + height * 0.4), wheelRadius * 0.5, rimPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
