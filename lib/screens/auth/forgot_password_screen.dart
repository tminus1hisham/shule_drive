import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme_extension.dart';
import '../../widgets/bus_illustration.dart';
import '../../widgets/ui/ui.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _phoneController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  String _completePhoneNumber = '';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

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
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _sendOTP() async {
    if (!_formKey.currentState!.validate()) return;

    HapticFeedback.lightImpact();

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.requestPasswordReset(
      _completePhoneNumber,
    );

    if (!mounted) return;

    if (success) {
      Navigator.pushNamed(
        context,
        '/reset-password',
        arguments: {'phone': _completePhoneNumber},
      );
    } else {
      AppSnackbar.error(
        context,
        authProvider.errorMessage ?? 'Failed to send OTP. Please try again.',
      );
    }
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
              const BusIllustration(height: 160),
              const SizedBox(height: AppSpacing.xxl),
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
          Text('Forgot Password? 🔐', style: context.text.displaySmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Enter your phone number and we\'ll send you an OTP to reset '
            'your password.',
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
              Text('Phone Number', style: context.text.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              IntlPhoneField(
                controller: _phoneController,
                decoration: const InputDecoration(hintText: '712 345 678'),
                initialCountryCode: 'KE',
                disableLengthCheck: true,
                flagsButtonPadding: const EdgeInsets.only(left: AppSpacing.sm),
                dropdownIcon: Icon(
                  Icons.arrow_drop_down,
                  color: context.colors.textSecondary,
                ),
                dropdownTextStyle: context.text.bodyLarge,
                style: context.text.bodyLarge,
                onChanged: (phone) =>
                    _completePhoneNumber = phone.completeNumber,
                validator: (phone) {
                  if (phone == null || phone.number.isEmpty) {
                    return 'Please enter your phone number';
                  }
                  if (phone.number.length < 9) {
                    return 'Please enter a valid phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Send OTP',
                icon: Icons.send_rounded,
                loading: authProvider.isLoading,
                onPressed: _sendOTP,
              ),
              const SizedBox(height: AppSpacing.md),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Back to Login'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
