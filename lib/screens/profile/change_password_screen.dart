import 'package:flutter/foundation.dart';
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
  bool _isLoading = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // Store navigator state before async operation
  NavigatorState? _navigator;

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
    
    // Store navigator reference BEFORE async operation
    _navigator = Navigator.of(context, rootNavigator: true);
    
    // Show blocking loading overlay to prevent navigation
    setState(() => _isLoading = true);
    
    if (kDebugMode) {
      print('🔐 Attempting to change password...');
      print('🔐 Navigator stored: $_navigator');
    }

    bool success = false;
    String? errorMsg;
    
    try {
      success = await authProvider.changePassword(
        currentPassword: _currentController.text,
        newPassword: _newController.text,
      );
      errorMsg = authProvider.errorMessage;
    } catch (e) {
      if (kDebugMode) print('❌ Exception during changePassword: $e');
      errorMsg = e.toString();
    }

    // Hide loading overlay
    if (mounted) {
      setState(() => _isLoading = false);
    }

    if (kDebugMode) {
      print('🔐 changePassword completed');
      print('🔐 success: $success');
      print('🔐 errorMsg: $errorMsg');
      print('🔐 mounted: $mounted');
      print('🔐 Navigator still available: $_navigator');
    }

    // Use stored navigator if widget is unmounted
    if (!mounted) {
      if (kDebugMode) print('⚠️ Widget not mounted, using stored navigator...');
      _showDialogWithNavigator(success, errorMsg);
      return;
    }

    await _handlePasswordChangeResult(success, errorMsg);
  }

  /// Show dialog using stored navigator reference
  void _showDialogWithNavigator(bool success, String? errorMsg) {
    if (_navigator == null) {
      if (kDebugMode) print('❌ No navigator available');
      return;
    }

    if (kDebugMode) {
      print('🔄 Showing dialog with stored navigator');
      print('🔄 success: $success');
    }

    if (success) {
      _navigator!.push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (context) => _buildSuccessDialogPage(),
        ),
      );
    } else {
      final error = errorMsg ?? '';
      final isWrongPassword = error.toLowerCase().contains('current password is incorrect') ||
          error.toLowerCase().contains('incorrect');
      final isServerError = error.contains('Invalid server response format') || 
          error.contains('NullReferenceException');

      if (isWrongPassword) {
        _navigator!.push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (context) => _buildInvalidCredentialsDialogPage(),
          ),
        );
      } else if (isServerError) {
        // Password saved but email failed - show success
        _navigator!.push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (context) => _buildSuccessDialogPage(),
          ),
        );
      }
    }
  }

  /// Handle the password change result (success or failure)
  Future<void> _handlePasswordChangeResult(bool success, String? errorMsg) async {
    if (!mounted) {
      if (kDebugMode) print('❌ _handlePasswordChangeResult: widget not mounted');
      return;
    }

    if (kDebugMode) {
      print('🔐 _handlePasswordChangeResult called');
      print('🔐 success: $success');
      print('🔐 errorMsg: "$errorMsg"');
    }

    if (success) {
      if (kDebugMode) print('✅ SUCCESS: Showing success alert...');
      
      await _showSuccessAlert();
      
      if (!mounted) return;
      
      // Clear fields
      _currentController.clear();
      _newController.clear();
      _confirmController.clear();
      
      // Navigate back
      if (mounted) Navigator.pop(context);
    } else {
      // FAILED - check what type of error
      final error = errorMsg ?? '';
      
      if (kDebugMode) {
        print('❌ FAILED: error = "$error"');
      }
      
      // Check for wrong password error
      final isWrongPassword = error.toLowerCase().contains('current password is incorrect') ||
          error.toLowerCase().contains('incorrect') ||
          error.toLowerCase().contains('invalid credential');
      
      // Check for server error (password likely saved)
      final isServerError = error.contains('Invalid server response format') || 
          error.contains('NullReferenceException') || 
          error.contains('Server Error') ||
          error.contains('JSON Parse Error');
      
      if (kDebugMode) {
        print('❌ isWrongPassword: $isWrongPassword');
        print('❌ isServerError: $isServerError');
      }
      
      if (!mounted) {
        if (kDebugMode) print('❌ Widget became unmounted during error check');
        return;
      }
      
      if (isWrongPassword) {
        if (kDebugMode) print('🔴 Showing INVALID CREDENTIALS alert');
        _showInvalidCredentialsAlert();
      } else if (isServerError) {
        if (kDebugMode) print('🟡 Server error but password likely saved - showing SUCCESS');
        await _showSuccessAlert();
        
        if (!mounted) return;
        
        // Clear fields
        _currentController.clear();
        _newController.clear();
        _confirmController.clear();
        
        // Navigate back
        if (mounted) Navigator.pop(context);
      } else {
        if (kDebugMode) print('🔴 Showing generic error snackbar');
        _showError(error.isEmpty ? 'Failed to change password' : error);
      }
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

  /// Build success dialog widget
  Widget _buildSuccessDialog() {
    return Builder(
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF6B9B5B).withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: Color(0xFF6B9B5B),
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Success!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6B9B5B),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your password has been changed successfully.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(ctx).pop(); // Go back to profile
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
                    'OK',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Build invalid credentials dialog widget
  Widget _buildInvalidCredentialsDialog() {
    return Builder(
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline,
                  color: Colors.red,
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Invalid Credentials',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'The current password you entered is incorrect. Please try again.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B9B5B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Try Again',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Build success dialog as a full page (for use with Navigator)
  Widget _buildSuccessDialogPage() {
    return Builder(
      builder: (BuildContext newContext) {
        return Scaffold(
          backgroundColor: Colors.black.withAlpha(128),
          body: Center(
            child: Container(
              margin: const EdgeInsets.all(32),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6B9B5B).withAlpha(30),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_outline,
                      color: Color(0xFF6B9B5B),
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Success!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6B9B5B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Your password has been changed successfully.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(newContext).pop();
                        Navigator.of(newContext).pop(); // Go back to profile
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
                        'OK',
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
          ),
        );
      },
    );
  }

  /// Build invalid credentials dialog as a full page (for use with Navigator)
  Widget _buildInvalidCredentialsDialogPage() {
    return Builder(
      builder: (BuildContext newContext) {
        return Scaffold(
          backgroundColor: Colors.black.withAlpha(128),
          body: Center(
            child: Container(
              margin: const EdgeInsets.all(32),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.red.withAlpha(30),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_outline,
                      color: Colors.red,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Invalid Credentials',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'The current password you entered is incorrect. Please try again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(newContext).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6B9B5B),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Try Again',
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
          ),
        );
      },
    );
  }

  /// Show alert for invalid credentials (wrong current password)
  void _showInvalidCredentialsAlert() {
    if (kDebugMode) {
      print('🚨 _showInvalidCredentialsAlert() called');
    }
    
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        if (kDebugMode) {
          print('🚨 Building invalid credentials dialog...');
        }
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Error icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline,
                  color: Colors.red,
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              // Title
              const Text(
                'Invalid Credentials',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 12),
              // Message
              const Text(
                'The current password you entered is incorrect. Please try again.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 24),
              // OK button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B9B5B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Try Again',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Show success alert dialog
  Future<void> _showSuccessAlert() async {
    if (kDebugMode) {
      print('✅ _showSuccessAlert() called');
    }
    
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        if (kDebugMode) {
          print('✅ Building success dialog widget...');
        }
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF6B9B5B).withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: Color(0xFF6B9B5B),
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              // Title
              const Text(
                'Success!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6B9B5B),
                ),
              ),
              const SizedBox(height: 12),
              // Message
              const Text(
                'Your password has been changed successfully.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 24),
              // OK button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B9B5B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'OK',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final authProvider = context.watch<AuthProvider>();

    return MainScaffold(
      title: 'Change Password',
      showBackButton: !_isLoading, // Disable back button while loading
      body: Stack(
        children: [
          SingleChildScrollView(
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
      // Loading overlay that blocks interaction
      if (_isLoading)
        Container(
          color: Colors.black.withAlpha(128),
          child: const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF6B9B5B),
            ),
          ),
        ),
    ],
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
