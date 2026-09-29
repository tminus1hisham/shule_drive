import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme_extension.dart';
import '../../widgets/bus_illustration.dart';
import '../../widgets/ui/ui.dart';

class VerifyResetOtpScreen extends StatefulWidget {
  const VerifyResetOtpScreen({super.key});

  @override
  State<VerifyResetOtpScreen> createState() => _VerifyResetOtpScreenState();
}

class _VerifyResetOtpScreenState extends State<VerifyResetOtpScreen> {
  final List<TextEditingController> _otpControllers = List.generate(
    4,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(4, (index) => FocusNode());

  /// Bumped on each rejected code so the digit row shakes.
  int _shakeCount = 0;

  // Resend cooldown
  Timer? _resendTimer;
  int _resendCooldownSeconds = 30;
  bool _canResend = false;

  String? _phoneNumber;

  @override
  void initState() {
    super.initState();

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
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
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
      if (!mounted) return;
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

    // Verify OTP for password reset
    final success = await authProvider.verifyPasswordResetOtp(
      phoneNumber: _phoneNumber!,
      otp: otp,
    );

    if (!mounted) return;

    if (success) {
      // Navigate to reset password screen
      Navigator.pushNamed(
        context,
        '/reset-password',
        arguments: {'phone': _phoneNumber!, 'otp': otp},
      );
    } else {
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

    final success = await authProvider.requestPasswordReset(_phoneNumber!);

    if (!mounted) return;

    if (success) {
      _startResendCooldown();
      _showSuccess('OTP resent successfully');
    } else {
      _showError(authProvider.errorMessage ?? 'Failed to resend OTP');
    }
  }

  void _triggerShake() => setState(() => _shakeCount++);

  void _showError(String message) => AppSnackbar.error(context, message);

  void _showSuccess(String message) => AppSnackbar.success(context, message);

  String get _otpText => _otpControllers.map((c) => c.text).join();

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader().enter(),
              AppSpacing.vLg,
              const BusIllustration(
                height: 140,
              ).pop(delay: const Duration(milliseconds: 100)),
              AppSpacing.vXxl,
              _buildOTPForm(authProvider).enterList(2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Verify OTP 🔐', style: context.text.displaySmall),
          AppSpacing.vXs,
          Text(
            'Enter the 4-digit code sent to ${_phoneNumber ?? 'your phone'}',
            style: context.text.bodyLarge?.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOTPForm(AuthProvider authProvider) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.xl),
        shadow: c.shadowMd,
        child: Column(
          children: [
            // Shakes on a wrong or incomplete code.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(4, _buildOTPField),
            ).shake(_shakeCount),
            AppSpacing.vXxl,
            AppButton(
              label: 'Verify',
              loading: authProvider.isLoading,
              onPressed: _verifyOTP,
            ),
            AppSpacing.vLg,
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Didn\'t receive the code? ',
                  style: context.text.bodyMedium?.copyWith(
                    color: c.textSecondary,
                  ),
                ),
                TextButton(
                  onPressed: _canResend ? _resendOTP : null,
                  child: _canResend
                      ? const Text('Resend')
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Resend in '),
                            AnimatedCount(_resendCooldownSeconds, suffix: 's'),
                          ],
                        ),
                ),
              ],
            ),
            AppSpacing.vMd,
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: c.brandSoft,
                borderRadius: AppRadius.brSm,
              ),
              child: Row(
                children: [
                  Icon(Icons.security_rounded, size: 16, color: c.onBrandSoft),
                  AppSpacing.hXs,
                  Expanded(
                    child: Text(
                      'For your security, the code will expire in 5 minutes.',
                      style: context.text.labelMedium?.copyWith(
                        color: c.onBrandSoft,
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

  Widget _buildOTPField(int index) {
    final c = context.colors;
    // Rebuilds on focus change so the active box lights up immediately.
    return ListenableBuilder(
      listenable: _focusNodes[index],
      builder: (context, _) {
        final focused = _focusNodes[index].hasFocus;
        return AnimatedScale(
          scale: focused ? 1.06 : 1,
          duration: AppDuration.medium,
          curve: Curves.easeOutBack,
          child: AnimatedContainer(
            duration: AppDuration.medium,
            curve: AppCurves.easeOut,
            width: 64,
            height: 72,
            decoration: BoxDecoration(
              color: focused ? c.brandSoft : c.surfaceSubtle,
              borderRadius: AppRadius.brMd,
              border: Border.all(
                color: focused ? c.brand : c.outline,
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
                style: context.text.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (value) => _onOTPChanged(index, value),
              ),
            ),
          ),
        );
      },
    );
  }
}
