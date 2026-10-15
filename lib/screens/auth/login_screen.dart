import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme_extension.dart';
import '../../widgets/bus_illustration.dart';
import '../../widgets/mandatory_password_dialog.dart';
import '../../widgets/ui/ui.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  String _completePhoneNumber = '';
  String? _phoneEmptyError;

  /// Bumped on each failed sign-in so the form card shakes.
  int _failureShake = 0;

  // Rate limiting
  int _failedAttempts = 0;
  DateTime? _lastAttemptTime;
  static const int _maxAttempts = 5;
  static const Duration _lockoutDuration = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      final notice = auth.signInNotice;
      if (!mounted || notice == null) return;
      auth.signInNotice = null;
      AppSnackbar.info(context, notice);
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Check if user is currently locked out due to rate limiting
  bool get _isLockedOut {
    if (_failedAttempts < _maxAttempts) return false;
    if (_lastAttemptTime == null) return false;

    final timeSinceLastAttempt = DateTime.now().difference(_lastAttemptTime!);
    return timeSinceLastAttempt < _lockoutDuration;
  }

  /// Get remaining lockout time in seconds
  int get _remainingLockoutSeconds {
    if (_lastAttemptTime == null) return 0;
    final timeSinceLastAttempt = DateTime.now().difference(_lastAttemptTime!);
    final remaining = _lockoutDuration - timeSinceLastAttempt;
    return remaining.inSeconds.clamp(0, _lockoutDuration.inSeconds);
  }

  Future<void> _login() async {
    // IntlPhoneField only runs its validator on change, so an untouched
    // empty field passed form validation silently.
    final phoneEmpty = _phoneController.text.trim().isEmpty;
    setState(
      () => _phoneEmptyError = phoneEmpty
          ? 'Please enter your phone number'
          : null,
    );
    if (!_formKey.currentState!.validate() || phoneEmpty) return;

    if (_isLockedOut) {
      final remainingSeconds = _remainingLockoutSeconds;
      AppSnackbar.error(
        context,
        'Too many attempts. Please try again in '
        '${remainingSeconds ~/ 60}m ${remainingSeconds % 60}s.',
      );
      return;
    }

    HapticFeedback.lightImpact();

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(
      phoneNumber: _completePhoneNumber,
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      _failedAttempts = 0;
      if (authProvider.mustChangePassword) {
        await showMandatoryPasswordChange(
          context,
          currentPassword: _passwordController.text,
        );
        if (!mounted) return;
      }
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/dashboard',
        (route) => false,
      );
    } else {
      _failedAttempts++;
      _lastAttemptTime = DateTime.now();
      setState(() => _failureShake++);
      AppSnackbar.error(
        context,
        authProvider.errorMessage ?? 'Login failed. Please try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          child: Column(
            children: [
              _buildHeader(context).enter(offsetY: -12),
              _buildWelcomeText(context).enterList(1),
              const BusIllustration(
                height: 180,
              ).pop(delay: const Duration(milliseconds: 120)),
              _buildLoginForm(
                context,
                authProvider,
              ).shake(_failureShake).enterList(3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        0,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              gradient: context.colors.brandGradient,
              borderRadius: AppRadius.brSm,
              boxShadow: context.colors.shadowSm,
            ),
            child: const Icon(
              Icons.directions_bus_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text('Transfa', style: context.text.headlineSmall),
        ],
      ),
    );
  }

  Widget _buildWelcomeText(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Welcome Back! 👋', style: context.text.displaySmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Enter your credentials to continue',
            style: context.text.bodyLarge?.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm(BuildContext context, AuthProvider authProvider) {
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
              _buildPhoneField(context),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: 'Password',
                hint: 'Enter your password',
                controller: _passwordController,
                obscure: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
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
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Sign In',
                loading: authProvider.isLoading,
                onPressed: _login,
              ),
              const SizedBox(height: AppSpacing.md),
              Center(
                child: TextButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, '/forgot-password'),
                  child: const Text('Forgot Password?'),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              _buildSecurityNotice(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneField(BuildContext context) {
    return IntlPhoneField(
      controller: _phoneController,
      decoration: InputDecoration(
        hintText: '712 345 678',
        errorText: _phoneEmptyError,
      ),
      initialCountryCode: 'KE',
      disableLengthCheck: true,
      flagsButtonPadding: const EdgeInsets.only(left: AppSpacing.sm),
      dropdownIcon: Icon(
        Icons.arrow_drop_down,
        color: context.colors.textSecondary,
      ),
      dropdownTextStyle: context.text.bodyLarge,
      style: context.text.bodyLarge,
      onChanged: (phone) {
        _completePhoneNumber = phone.completeNumber;
        if (_phoneEmptyError != null) setState(() => _phoneEmptyError = null);
      },
      validator: (phone) {
        if (phone == null || phone.number.isEmpty) {
          return 'Please enter your phone number';
        }
        if (phone.number.startsWith('0')) {
          return 'Phone number should not start with 0';
        }
        if (phone.number.length < 9) {
          return 'Please enter a valid phone number';
        }
        if (phone.number.length > 9) {
          return 'Phone number should not be more than 9 digits';
        }
        return null;
      },
    );
  }

  Widget _buildSecurityNotice(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: context.colors.brandSoft,
        borderRadius: AppRadius.brSm,
      ),
      child: Row(
        children: [
          Icon(
            Icons.shield_outlined,
            size: 16,
            color: context.colors.onBrandSoft,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              'Your credentials are secure and encrypted.',
              style: context.text.labelMedium?.copyWith(
                color: context.colors.onBrandSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
