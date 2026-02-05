import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/main_scaffold.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final TextEditingController _currentController = TextEditingController();
  final TextEditingController _newController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    // Validate fields
    if (_currentController.text.isEmpty) {
      _showError('Please enter your current password');
      return;
    }

    if (_newController.text.isEmpty) {
      _showError('Please enter a new password');
      return;
    }

    if (_newController.text.length < 4) {
      _showError('New password must be at least 4 characters');
      return;
    }

    if (_newController.text != _confirmController.text) {
      _showError('New password and confirm password do not match');
      return;
    }

    if (_currentController.text == _newController.text) {
      _showError('New password must be different from current password');
      return;
    }

    final authProvider = context.read<AuthProvider>();

    final success = await authProvider.changePassword(
      currentPassword: _currentController.text,
      newPassword: _newController.text,
    );

    if (!mounted) return;

    if (success) {
      _showSuccess('Password changed successfully');
      // Clear fields
      _currentController.clear();
      _newController.clear();
      _confirmController.clear();
      // Navigate back after a short delay
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) Navigator.pop(context);
      });
    } else {
      _showError(authProvider.errorMessage ?? 'Failed to change password');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFF6B9B5B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final authProvider = context.watch<AuthProvider>();

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
                    'Current Password',
                    _currentController,
                    _obscureCurrent,
                    () => setState(() => _obscureCurrent = !_obscureCurrent),
                    provider,
                  ),
                  const SizedBox(height: 16),
                  _buildPasswordField(
                    'New Password',
                    _newController,
                    _obscureNew,
                    () => setState(() => _obscureNew = !_obscureNew),
                    provider,
                  ),
                  const SizedBox(height: 16),
                  _buildPasswordField(
                    'Confirm New Password',
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
                onPressed: authProvider.isLoading ? null : _changePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B9B5B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                  disabledBackgroundColor: const Color(
                    0xFF6B9B5B,
                  ).withAlpha(128),
                ),
                child: authProvider.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text(
                        'Change Password',
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
            fillColor: provider.isDarkMode
                ? const Color(0xFF2C2C2C)
                : const Color(0xFFF5F5F5),
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
    paint.color = isDarkMode
        ? const Color(0xFF3A3A3A)
        : const Color(0xFFE0E0E0);
    paint.strokeWidth = 2;
    canvas.drawLine(
      Offset(size.width * 0.2, size.height - 20),
      Offset(size.width * 0.8, size.height - 20),
      paint,
    );

    // Draw trees
    _drawTree(
      canvas,
      size.width * 0.25,
      size.height - 40,
      25,
      const Color(0xFF6B9B5B),
    );
    _drawTree(
      canvas,
      size.width * 0.75,
      size.height - 45,
      30,
      const Color(0xFF8BC48A),
    );

    // Draw bus
    _drawBus(canvas, size.width * 0.5, size.height - 65, 100, 50);
  }

  void _drawTree(Canvas canvas, double x, double y, double size, Color color) {
    final paint = Paint()..color = color;
    final trunkPaint = Paint()..color = const Color(0xFF8B7355);
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(x, y),
        width: size * 0.15,
        height: size * 0.6,
      ),
      trunkPaint,
    );
    canvas.drawCircle(Offset(x, y - size * 0.5), size * 0.5, paint);
    canvas.drawCircle(
      Offset(x - size * 0.3, y - size * 0.3),
      size * 0.35,
      paint,
    );
    canvas.drawCircle(
      Offset(x + size * 0.3, y - size * 0.3),
      size * 0.35,
      paint,
    );
  }

  void _drawBus(
    Canvas canvas,
    double x,
    double y,
    double width,
    double height,
  ) {
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
    canvas.drawCircle(
      Offset(x + width * 0.25, y + height * 0.4),
      wheelRadius,
      wheelPaint,
    );
    canvas.drawCircle(
      Offset(x + width * 0.25, y + height * 0.4),
      wheelRadius * 0.5,
      rimPaint,
    );
    canvas.drawCircle(
      Offset(x - width * 0.25, y + height * 0.4),
      wheelRadius,
      wheelPaint,
    );
    canvas.drawCircle(
      Offset(x - width * 0.25, y + height * 0.4),
      wheelRadius * 0.5,
      rimPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
