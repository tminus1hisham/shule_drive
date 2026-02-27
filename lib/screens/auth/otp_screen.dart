import 'dart:async';
import 'dart:math' show pi, sin;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/bus_illustration.dart';

class OTPScreen extends StatefulWidget {
  const OTPScreen({super.key});

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> with SingleTickerProviderStateMixin {
  final List<TextEditingController> _otpControllers = 
      List.generate(4, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = 
      List.generate(4, (index) => FocusNode());
  
  late AnimationController _shakeController;
  
  // Rate limiting and security
  int _failedAttempts = 0;
  static const int _maxAttempts = 5;
  DateTime? _lastAttemptTime;
  
  // Resend cooldown
  Timer? _resendTimer;
  int _resendCooldownSeconds = 30;
  bool _canResend = false;
  
  String? _phoneNumber;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    
    // Start resend cooldown
    _startResendCooldown();
    
    // Delay auto-focus to ensure screen is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get phone number from route arguments
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _phoneNumber = args?['phone'] as String?;
  }

  @override
  void dispose() {
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    _shakeController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendCooldown() {
    setState(() {
      _canResend = false;
      _resendCooldownSeconds = 30;
    });
    
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_resendCooldownSeconds > 0) {
          _resendCooldownSeconds--;
        } else {
          _canResend = true;
          timer.cancel();
        }
      });
    });
  }

  /// Check if user is locked out due to too many failed attempts
  bool get _isLockedOut {
    if (_failedAttempts < _maxAttempts) return false;
    if (_lastAttemptTime == null) return false;
    
    final timeSinceLastAttempt = DateTime.now().difference(_lastAttemptTime!);
    return timeSinceLastAttempt < const Duration(minutes: 5);
  }

  void _onOTPChanged(int index, String value) {
    // Validate input - only allow digits
    if (value.isNotEmpty && !RegExp(r'^\d$').hasMatch(value)) {
      _otpControllers[index].clear();
      return;
    }
    
    if (value.length == 1 && index < 3) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    
    // Auto-verify when all digits are entered
    if (index == 3 && value.isNotEmpty) {
      final otp = _otpText;
      if (otp.length == 4) {
        _verifyOTP();
      }
    }
  }

  Future<void> _verifyOTP() async {
    // Check rate limiting
    if (_isLockedOut) {
      _showError('Too many failed attempts. Please try again later.');
      _triggerShake();
      return;
    }

    final otp = _otpText;
    
    // Validate OTP format
    if (otp.length != 4 || !RegExp(r'^\d{4}$').hasMatch(otp)) {
      _showError('Please enter a valid 4-digit OTP');
      _triggerShake();
      return;
    }

    if (_phoneNumber == null) {
      _showError('Phone number not found. Please go back and try again.');
      return;
    }

    final authProvider = context.read<AuthProvider>();
    
    final success = await authProvider.verifyOtp(_phoneNumber!, otp);
    
    if (!mounted) return;

    if (success) {
      // Clear controllers for security
      for (var controller in _otpControllers) {
        controller.clear();
      }
      
      // Navigate to landing screen
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/dashboard',
        (route) => false,
      );
    } else {
      // Record failed attempt
      _failedAttempts++;
      _lastAttemptTime = DateTime.now();
      
      _triggerShake();
      _showError(authProvider.errorMessage ?? 'Invalid OTP. Please try again.');
      
      // Clear OTP fields
      for (var controller in _otpControllers) {
        controller.clear();
      }
      _focusNodes[0].requestFocus();
    }
  }

  Future<void> _resendOTP() async {
    if (!_canResend) return;
    
    if (_phoneNumber == null) {
      _showError('Phone number not found');
      return;
    }

    final authProvider = context.read<AuthProvider>();
    
    // Request new OTP via API
    final success = await authProvider.requestPasswordReset(_phoneNumber!);
    
    if (!mounted) return;

    if (success) {
      _startResendCooldown();
      _showSuccess('OTP resent successfully');
    } else {
      _showError(authProvider.errorMessage ?? 'Failed to resend OTP');
    }
  }

  void _triggerShake() {
    _shakeController.forward(from: 0);
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
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String get _otpText => _otpControllers.map((c) => c.text).join();


  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header Section
              _buildHeader(),
              
              const SizedBox(height: 20),
              
              // Bus Illustration
              const BusIllustration(height: 160),
              
              const SizedBox(height: 32),
              
              // OTP Form
              _buildOTPForm(authProvider),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(left: 24, top: 20, right: 24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6B9B5B), Color(0xFF5A8A4A)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6B9B5B).withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.directions_bus,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Verification',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOTPForm(AuthProvider authProvider) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Title
          const Text(
            'Enter OTP',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          
          // Subtitle with phone number
          Text(
            'We sent a 4-digit code to ${_phoneNumber ?? 'your phone'}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF666666),
            ),
          ),
          const SizedBox(height: 32),
          
          // OTP Input Fields with shake animation
          AnimatedBuilder(
            animation: _shakeController,
            builder: (context, child) {
              final shakeOffset = sin(_shakeController.value * pi * 8) * 10;
              return Transform.translate(
                offset: Offset(shakeOffset, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(4, (index) => _buildOTPField(index)),
                ),
              );
            },
          ),
          
          const SizedBox(height: 32),
          
          // Verify Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: authProvider.isLoading ? null : _verifyOTP,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B9B5B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
                disabledBackgroundColor: const Color(0xFF6B9B5B).withValues(alpha: 0.5),
              ),
              child: authProvider.isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Verify',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Resend OTP
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Didn\'t receive the code? ',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              TextButton(
                onPressed: _canResend ? _resendOTP : null,
                child: Text(
                  _canResend
                      ? 'Resend'
                      : 'Resend in ${_resendCooldownSeconds}s',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _canResend
                        ? const Color(0xFF6B9B5B)
                        : Colors.grey.shade400,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Security notice
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF6B9B5B).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.security,
                  size: 16,
                  color: const Color(0xFF6B9B5B),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'For your security, the code will expire in 5 minutes.',
                    style: TextStyle(
                      fontSize: 12,
                      color: const Color(0xFF6B9B5B),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOTPField(int index) {
    return Container(
      width: 64,
      height: 72,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _focusNodes[index].hasFocus
              ? const Color(0xFF6B9B5B)
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: Center(
        child: TextField(
          controller: _otpControllers[index],
          focusNode: _focusNodes[index],
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: 1,
          obscureText: false,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
          decoration: const InputDecoration(
            counterText: '',
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          onChanged: (value) => _onOTPChanged(index, value),

        ),
      ),
    );
  }
}
