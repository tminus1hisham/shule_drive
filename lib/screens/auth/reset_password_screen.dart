import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme_extension.dart';
import '../../widgets/bus_illustration.dart';
import '../../widgets/ui/ui.dart';

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

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  String? _phoneNumber;

  // Password strength
  double _passwordStrength = 0;
  String _strengthLabel = '';
  Color _strengthColor = AppPalette.textMutedLight;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: AppDuration.medium,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: AppCurves.easeOut,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: AppCurves.easeOut,
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
    Color color = AppPalette.textMutedLight;

    if (password.isEmpty) {
      strength = 0;
      label = '';
    } else if (password.length < 4) {
      strength = 0.15;
      label = 'Too short';
      color = AppPalette.error;
    } else if (password.length < 6) {
      strength = 0.3;
      label = 'Weak';
      color = AppPalette.error;
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
        color = AppPalette.warning;
      } else if (score <= 3) {
        strength = 0.75;
        label = 'Good';
        color = AppPalette.emerald;
      } else {
        strength = 1.0;
        label = 'Strong';
        color = AppPalette.success;
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
      AppSnackbar.error(context, 'Invalid session. Please go back and try again.');
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.resetPassword(
      phoneNumber: _phoneNumber!,
      resetToken: _otpController.text.trim(),
      newPassword: _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      _showSuccessDialog();
    } else {
      AppSnackbar.error(
        context,
        authProvider.errorMessage ??
            'Failed to reset password. Please try again.',
      );
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: ctx.colors.brand.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_rounded,
                  color: ctx.colors.brand,
                  size: 56,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Password Reset\nSuccessful! 🎉',
                textAlign: TextAlign.center,
                style: ctx.text.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Your password has been updated. You can now log in with '
                'your new password.',
                textAlign: TextAlign.center,
                style: ctx.text.bodyMedium?.copyWith(
                  color: ctx.colors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Back to Login',
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/login',
                    (route) => false,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          child: Column(
            children: [
              _buildHeader(context),
              const SizedBox(height: AppSpacing.lg),
              const BusIllustration(height: 130),
              const SizedBox(height: AppSpacing.xl),
              FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: _buildForm(context, authProvider),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reset Password 🔐', style: context.text.displaySmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Enter the OTP sent to your phone and create a new password.',
            style: context.text.bodyLarge?.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context, AuthProvider authProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.xl),
        shadow: context.colors.shadowMd,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('OTP Code', style: context.text.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              TextFormField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: context.text.headlineSmall?.copyWith(letterSpacing: 8),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: InputDecoration(
                  hintText: '• • • • • •',
                  hintStyle: TextStyle(
                    color: context.colors.textMuted,
                    letterSpacing: 8,
                    fontSize: 20,
                  ),
                  prefixIcon: Icon(
                    Icons.sms_outlined,
                    color: context.colors.textSecondary,
                    size: 20,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the OTP';
                  }
                  if (value.length < 4) return 'OTP must be at least 4 digits';
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: 'New Password',
                hint: 'Enter new password',
                controller: _passwordController,
                obscure: true,
                prefixIcon: Icons.lock_outline_rounded,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  if (value.length < 4) {
                    return 'Password must be at least 4 characters';
                  }
                  return null;
                },
              ),
              if (_passwordController.text.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                _buildPasswordStrengthIndicator(context),
              ],
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: 'Confirm Password',
                hint: 'Re-enter new password',
                controller: _confirmPasswordController,
                obscure: true,
                prefixIcon: Icons.lock_outline_rounded,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please confirm your password';
                  }
                  if (value != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Reset Password',
                icon: Icons.lock_reset_rounded,
                loading: authProvider.isLoading,
                onPressed: _resetPassword,
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: context.colors.brandSoft,
                  borderRadius: AppRadius.brSm,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 18,
                      color: context.colors.onBrandSoft,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        'The OTP will expire in 5 minutes. If you didn\'t '
                        'receive it, go back and request again.',
                        style: context.text.labelMedium?.copyWith(
                          color: context.colors.onBrandSoft,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordStrengthIndicator(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _passwordStrength,
            backgroundColor: context.colors.surfaceSubtle,
            valueColor: AlwaysStoppedAnimation<Color>(_strengthColor),
            minHeight: 4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _strengthLabel,
          style: context.text.labelMedium?.copyWith(color: _strengthColor),
        ),
      ],
    );
  }
}
