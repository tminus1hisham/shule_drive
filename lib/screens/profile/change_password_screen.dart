import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../theme/app_spacing.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/main_scaffold.dart';
import '../../widgets/mandatory_password_dialog.dart';

import '../../theme/app_colors.dart';
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _currentController = TextEditingController();
  final TextEditingController _newController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  // Animation controller
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Store navigator state before async operation
  NavigatorState? _navigator;

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
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.03),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: AppCurves.easeOut,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    // Validate fields
    if (_currentController.text.isEmpty) {
      _showError('Please enter your current password');
      HapticFeedback.mediumImpact();
      return;
    }

    if (_newController.text.isEmpty) {
      _showError('Please enter a new password');
      HapticFeedback.mediumImpact();
      return;
    }

    if (_newController.text.length < 4) {
      _showError('New password must be at least 4 characters');
      HapticFeedback.mediumImpact();
      return;
    }

    if (_newController.text != _confirmController.text) {
      _showError('New password and confirm password do not match');
      HapticFeedback.mediumImpact();
      return;
    }

    if (_currentController.text == _newController.text) {
      _showError('New password must be different from current password');
      HapticFeedback.mediumImpact();
      return;
    }

    final authProvider = context.read<AuthProvider>();

    // Store context and navigator reference BEFORE async operation
    final currentContext = context;
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

    // Hide loading overlay - don't use setState if we might show dialog immediately
    // to avoid "setState called during build" errors
    if (mounted) {
      setState(() => _isLoading = false);
    }

    if (kDebugMode) {
      print('🔐 changePassword completed');
      print('🔐 success: $success');
      print('🔐 errorMsg: $errorMsg');
      print('🔐 mounted: $mounted');
    }

    // Wait for next frame to ensure setState is complete before showing dialog
    await Future.delayed(Duration.zero);

    // Check if we can use the current context or need stored navigator
    if (!mounted || !currentContext.mounted) {
      if (kDebugMode) {
        print('⚠️ Widget not mounted, using stored navigator...');
      }
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
      print('🔄 errorMsg: $errorMsg');
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
      final isWrongPassword = classifyPasswordChangeError(errorMsg) ==
          PasswordChangeFailure.wrongPassword;
      // Check for server error (password likely saved despite error)
      final isServerError = classifyPasswordChangeError(errorMsg) ==
          PasswordChangeFailure.savedDespiteServerError;

      if (kDebugMode) {
        print('🔄 isWrongPassword: $isWrongPassword');
        print('🔄 isServerError: $isServerError');
      }

      if (isWrongPassword) {
        _navigator!.push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (context) => _buildInvalidCredentialsDialogPage(),
          ),
        );
      } else if (isServerError) {
        // Password saved but email failed - show success
        if (kDebugMode) print('🔄 Server error detected - showing SUCCESS dialog');
        _navigator!.push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (context) => _buildSuccessDialogPage(),
          ),
        );
      } else {
        // Unknown error - can't show snackbar without context, log for debugging
        if (kDebugMode) print('🔄 Unknown error - cannot show dialog (no context): $error');
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

      // Show success alert dialog - the dialog's OK button handles navigation
      await _showSuccessAlert();

      // Note: Fields are cleared and navigation happens in the dialog's OK button
      // We don't clear fields here because the dialog handles returning to profile
    } else {
      // FAILED - check what type of error
      final error = errorMsg ?? '';

      if (kDebugMode) {
        print('❌ FAILED: error = "$error"');
      }

      // Check for wrong password error
      final isWrongPassword = classifyPasswordChangeError(errorMsg) ==
          PasswordChangeFailure.wrongPassword;

      // Check for server error (password likely saved)
      // When password change succeeds but server returns 500 (e.g., email notification failed)
      final isServerError = classifyPasswordChangeError(errorMsg) ==
          PasswordChangeFailure.savedDespiteServerError;

      if (kDebugMode) {
        print('❌ isWrongPassword: $isWrongPassword');
        print('❌ isServerError: $isServerError');
      }

      // Wait for next frame to avoid setState during build issues
      await Future.delayed(Duration.zero);

      if (!mounted) {
        if (kDebugMode) print('❌ Widget became unmounted during error check');
        return;
      }

      HapticFeedback.mediumImpact();

      if (isWrongPassword) {
        if (kDebugMode) print('🔴 Showing INVALID CREDENTIALS alert');
        _showInvalidCredentialsAlert();
      } else if (isServerError) {
        if (kDebugMode) {
          print('🟡 Server error but password likely saved - showing SUCCESS');
        }
        // Show success alert - the dialog's OK button handles navigation
        await _showSuccessAlert();
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
            borderRadius: BorderRadius.circular(24),
          ),
          contentPadding: const EdgeInsets.all(28),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated success icon
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppPalette.emerald, AppPalette.emeraldBright],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppPalette.emerald.withAlpha(60),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Success!',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppPalette.emerald,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your password has been changed successfully.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: AppPalette.textMutedLight,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    // Close the dialog first
                    Navigator.of(ctx).pop();
                    // Then navigate back to profile page using stored navigator
                    // Use a small delay to ensure dialog is fully closed
                    Future.delayed(const Duration(milliseconds: 50), () {
                      if (_navigator != null && _navigator!.canPop()) {
                        _navigator!.pop();
                      }
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppPalette.emerald,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
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
            borderRadius: BorderRadius.circular(24),
          ),
          contentPadding: const EdgeInsets.all(28),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Error icon with gradient
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red.shade400, Colors.red.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppPalette.error.withAlpha(60),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.lock_outline,
                  color: Colors.white,
                  size: 44,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Invalid Credentials',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppPalette.error,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'The current password you entered is incorrect. Please try again.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: AppPalette.textMutedLight,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    // Close the dialog
                    Navigator.of(ctx).pop();
                    // Clear the current password field so user can re-enter
                    _currentController.clear();
                    // Request focus on current password field if mounted
                    if (mounted) {
                      FocusScope.of(context).requestFocus(FocusNode());
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppPalette.emerald,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
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
    return Scaffold(
      backgroundColor: Colors.black87,
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(100),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated success icon with confetti effect simulation
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppPalette.emerald, AppPalette.emeraldBright],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppPalette.emerald.withAlpha(80),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 56,
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Success!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppPalette.emerald,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your password has been changed successfully.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: AppPalette.textMutedLight,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    // Use stored navigator to pop back to change password screen
                    // The dialog page is pushed on top, so we need to pop twice
                    if (_navigator != null) {
                      // Pop the dialog page
                      _navigator!.pop();
                      // Then pop the change password screen to return to profile
                      Future.delayed(const Duration(milliseconds: 50), () {
                        if (_navigator!.canPop()) {
                          _navigator!.pop();
                        }
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppPalette.emerald,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'OK',
                    style: TextStyle(
                      fontSize: 17,
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
  }

  /// Build invalid credentials dialog as a full page (for use with Navigator)
  Widget _buildInvalidCredentialsDialogPage() {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(100),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red.shade400, Colors.red.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppPalette.error.withAlpha(80),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.lock_outline,
                  color: Colors.white,
                  size: 50,
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Invalid Credentials',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppPalette.error,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'The current password you entered is incorrect. Please try again.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: AppPalette.textMutedLight,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    // Use stored navigator to pop back to change password screen
                    if (_navigator != null) {
                      _navigator!.pop();
                    }
                    // Clear the current password field
                    _currentController.clear();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppPalette.emerald,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Try Again',
                    style: TextStyle(
                      fontSize: 17,
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
  }

  /// Show alert for invalid credentials (wrong current password)
  void _showInvalidCredentialsAlert() {
    if (kDebugMode) {
      print('🚨 _showInvalidCredentialsAlert() called');
    }

    if (!mounted) {
      if (kDebugMode) print('❌ Cannot show dialog: widget not mounted');
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        if (kDebugMode) {
          print('🚨 Building invalid credentials dialog...');
        }
        return _buildInvalidCredentialsDialog();
      },
    );
  }

  /// Show success alert dialog
  Future<void> _showSuccessAlert() async {
    if (kDebugMode) {
      print('✅ _showSuccessAlert() called');
    }

    if (!mounted) {
      if (kDebugMode) print('❌ Cannot show dialog: widget not mounted');
      return;
    }

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        if (kDebugMode) {
          print('✅ Building success dialog widget...');
        }
        return _buildSuccessDialog();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final authProvider = context.watch<AuthProvider>();

    return MainScaffold(
      title: 'Change Password',
      showBackButton: !_isLoading && !authProvider.isLoading,
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: provider.isDarkMode
                    ? [const Color(0xFF1A1A2E), const Color(0xFF16213E)]
                    : [const Color(0xFFF8FAF8), const Color(0xFFEEF4EE)],
              ),
            ),
          ),
          // Main content
          FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    // Security icon header
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppPalette.emerald, AppPalette.emeraldBright],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppPalette.emerald.withAlpha(50),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        color: Colors.white,
                        size: 56,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Secure Your Account',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: provider.textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create a strong password to protect your account',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: provider.textMutedColor,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Form Fields Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: provider.cardColor,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(10),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
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
                            Icons.lock_outline,
                          ),
                          const SizedBox(height: 20),
                          _buildPasswordField(
                            'New Password',
                            _newController,
                            _obscureNew,
                            () => setState(() => _obscureNew = !_obscureNew),
                            provider,
                            Icons.key_outlined,
                          ),
                          const SizedBox(height: 20),
                          _buildPasswordField(
                            'Confirm New Password',
                            _confirmController,
                            _obscureConfirm,
                            () => setState(() => _obscureConfirm = !_obscureConfirm),
                            provider,
                            Icons.check_circle_outline,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Change Password Button
                    Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          colors: [AppPalette.emerald, AppPalette.emeraldPressed],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppPalette.emerald.withAlpha(60),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: authProvider.isLoading || _isLoading ? null : _changePassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: authProvider.isLoading || _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.lock_reset, size: 22),
                                  SizedBox(width: 10),
                                  Text(
                                    'Change Password',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Password tips
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppPalette.emerald.withAlpha(15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppPalette.emerald.withAlpha(30),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: AppPalette.emerald,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Password must be at least 4 characters and different from your current password.',
                              style: TextStyle(
                                fontSize: 13,
                                color: provider.textMutedColor,
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
            ),
          ),
          // Loading overlay - show when either local or provider loading is active
          if (_isLoading || authProvider.isLoading)
            Container(
              color: Colors.black.withAlpha(128),
              child: const Center(
                child: CircularProgressIndicator(
                  color: AppPalette.emerald,
                  strokeWidth: 3,
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
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: AppPalette.emerald,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: provider.textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: provider.isDarkMode ? AppPalette.surfaceSubtleDark : AppPalette.surfaceSubtleLight,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppPalette.emerald.withAlpha(30),
              width: 1.5,
            ),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            style: TextStyle(
              color: provider.textColor,
              fontSize: 16,
            ),
            decoration: InputDecoration(
              filled: false,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 18,
              ),
              suffixIcon: IconButton(
                onPressed: onToggle,
                icon: Icon(
                  obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: AppPalette.emerald,
                  size: 22,
                ),
                splashRadius: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
