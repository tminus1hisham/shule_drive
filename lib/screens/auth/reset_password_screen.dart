import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/bus_illustration.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  String? _phoneNumber;

  // Password strength
  double _passwordStrength = 0;
  String _strengthLabel = '';
  Color _strengthColor = Colors.grey;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );
    _animationController.forward();
    _passwordController.addListener(_updatePasswordStrength);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _phoneNumber = args?['phone'] as String?;
  }

  @override
  void dispose() {
    _passwordController.removeListener(_updatePasswordStrength);
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _updatePasswordStrength() {
    final password = _passwordController.text;
    double strength = 0;
    String label = '';
    Color color = Colors.grey;

    if (password.isEmpty) {
      strength = 0;
      label = '';
      color = Colors.grey;
    } else if (password.length < 4) {
      strength = 0.15;
      label = 'Too short';
      color = Colors.red;
    } else if (password.length < 6) {
      strength = 0.3;
      label = 'Weak';
      color = Colors.red;
    } else {
      int score = 0;
      if (password.length >= 8) score++;
      if (RegExp(r'[A-Z]').hasMatch(password)) score++;
      if (RegExp(r'[a-z]').hasMatch(password)) score++;
      if (RegExp(r'[0-9]').hasMatch(password)) score++;
      if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) score++;

      if (score <= 2) {
        strength = 0.5;
        label = 'Fair';
        color = Colors.orange;
      } else if (score <= 3) {
        strength = 0.75;
        label = 'Good';
        color = const Color(0xFF6B9B5B);
      } else {
        strength = 1.0;
        label = 'Strong';
        color = const Color(0xFF4CAF50);
      }
    }

    setState(() {
      _passwordStrength = strength;
      _strengthLabel = label;
      _strengthColor = color;
    });
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    HapticFeedback.lightImpact();

    if (_phoneNumber == null) {
      _showError('Invalid session. Please go back and try again.');
      return;
    }

    final authProvider = context.read<AuthProvider>();

    // Pass the OTP the user entered as the resetToken
    final success = await authProvider.resetPassword(
      phoneNumber: _phoneNumber!,
      resetToken: _otpController.text.trim(),
      newPassword: _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      _showSuccessDialog();
    } else {
      _showError(
        authProvider.errorMessage ??
            'Failed to reset password. Please try again.',
      );
    }
  }

  void _showSuccessDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF6B9B5B).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF6B9B5B),
                  size: 56,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Password Reset\nSuccessful! 🎉',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your password has been updated.\nYou can now log in with your new password.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white60 : const Color(0xFF666666),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/login',
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B9B5B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Back to Login',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF121212)
          : const Color(0xFFF5F5F0),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : const Color(0xFF1A1A1A),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(isDark),
              const SizedBox(height: 20),
              const BusIllustration(height: 130),
              const SizedBox(height: 28),
              FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: _buildForm(authProvider, isDark),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reset Password 🔐',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter the OTP sent to your phone and create a new password.',
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.white70 : const Color(0xFF666666),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(AuthProvider authProvider, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // OTP Field
            Text(
              'OTP Code',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
                color: isDark ? Colors.white : const Color(0xFF1A1A1A),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: InputDecoration(
                hintText: '• • • • • •',
                hintStyle: TextStyle(
                  color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                  letterSpacing: 8,
                  fontSize: 22,
                ),
                filled: true,
                fillColor: isDark
                    ? const Color(0xFF2C2C2C)
                    : const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF6B9B5B),
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
                prefixIcon: Icon(
                  Icons.sms_outlined,
                  color: isDark ? Colors.white38 : Colors.grey.shade500,
                  size: 20,
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter the OTP';
                }
                if (value.length < 4) {
                  return 'OTP must be at least 4 digits';
                }
                return null;
              },
            ),

            const SizedBox(height: 20),

            // New Password Field
            _buildPasswordField(
              'New Password',
              _passwordController,
              _obscurePassword,
              () => setState(() => _obscurePassword = !_obscurePassword),
              isDark: isDark,
              hintText: 'Enter new password',
            ),

            // Password strength indicator
            if (_passwordController.text.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildPasswordStrengthIndicator(isDark),
            ],

            const SizedBox(height: 20),

            // Confirm Password Field
            _buildPasswordField(
              'Confirm Password',
              _confirmPasswordController,
              _obscureConfirmPassword,
              () => setState(
                () => _obscureConfirmPassword = !_obscureConfirmPassword,
              ),
              isDark: isDark,
              hintText: 'Re-enter new password',
              validator: (value) {
                if (value == null || value.isEmpty)
                  return 'Please confirm your password';
                if (value != _passwordController.text)
                  return 'Passwords do not match';
                return null;
              },
            ),

            const SizedBox(height: 28),

            // Reset Password Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: authProvider.isLoading ? null : _resetPassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B9B5B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                  disabledBackgroundColor: const Color(
                    0xFF6B9B5B,
                  ).withValues(alpha: 0.5),
                ),
                child: authProvider.isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_reset_rounded, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Reset Password',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 16),

            // Security notice
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(
                  0xFF6B9B5B,
                ).withValues(alpha: isDark ? 0.08 : 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.shield_outlined,
                    size: 18,
                    color: const Color(0xFF6B9B5B),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'The OTP will expire in 5 minutes. If you didn\'t receive it, go back and request again.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? Colors.white54
                            : const Color(0xFF888888),
                        height: 1.4,
                      ),
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

  Widget _buildPasswordStrengthIndicator(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _passwordStrength,
            backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(_strengthColor),
            minHeight: 4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _strengthLabel,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: _strengthColor,
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField(
    String label,
    TextEditingController controller,
    bool obscureText,
    VoidCallback onToggle, {
    required bool isDark,
    String hintText = 'Enter your password',
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          style: TextStyle(
            fontSize: 16,
            color: isDark ? Colors.white : const Color(0xFF1A1A1A),
          ),
          validator:
              validator ??
              (value) {
                if (value == null || value.isEmpty)
                  return 'Please enter your password';
                if (value.length < 4)
                  return 'Password must be at least 4 characters';
                return null;
              },
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
            ),
            filled: true,
            fillColor: isDark
                ? const Color(0xFF2C2C2C)
                : const Color(0xFFF5F5F5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF6B9B5B),
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            prefixIcon: Icon(
              Icons.lock_outline_rounded,
              color: isDark ? Colors.white38 : Colors.grey.shade500,
              size: 20,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                obscureText
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: isDark ? Colors.white38 : Colors.grey.shade600,
              ),
              onPressed: onToggle,
            ),
          ),
        ),
      ],
    );
  }
}
