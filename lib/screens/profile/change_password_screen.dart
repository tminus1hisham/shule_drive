import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../theme/app_spacing.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../widgets/main_scaffold.dart';
import '../../widgets/mandatory_password_dialog.dart';
import '../../theme/app_theme_extension.dart';
import '../../widgets/ui/ui.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final TextEditingController _currentController = TextEditingController();
  final TextEditingController _newController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool _isLoading = false;

  // Store navigator state before async operation
  NavigatorState? _navigator;

  @override
  void dispose() {
    _shakeKey.dispose();
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
      final isWrongPassword =
          classifyPasswordChangeError(errorMsg) ==
          PasswordChangeFailure.wrongPassword;
      // Check for server error (password likely saved despite error)
      final isServerError =
          classifyPasswordChangeError(errorMsg) ==
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
        if (kDebugMode) {
          print('🔄 Server error detected - showing SUCCESS dialog');
        }
        _navigator!.push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (context) => _buildSuccessDialogPage(),
          ),
        );
      } else {
        // Unknown error - can't show snackbar without context, log for debugging
        if (kDebugMode) {
          print('🔄 Unknown error - cannot show dialog (no context): $error');
        }
      }
    }
  }

  /// Handle the password change result (success or failure)
  Future<void> _handlePasswordChangeResult(
    bool success,
    String? errorMsg,
  ) async {
    if (!mounted) {
      if (kDebugMode) {
        print('❌ _handlePasswordChangeResult: widget not mounted');
      }
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
      final isWrongPassword =
          classifyPasswordChangeError(errorMsg) ==
          PasswordChangeFailure.wrongPassword;

      // Check for server error (password likely saved)
      // When password change succeeds but server returns 500 (e.g., email notification failed)
      final isServerError =
          classifyPasswordChangeError(errorMsg) ==
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
    AppSnackbar.error(context, message);
    _shakeKey.value++;
  }

  /// Bumped on every validation error so the form card shakes.
  final _shakeKey = ValueNotifier<int>(0);

  /// Shared body of the success / invalid-credentials result, used both as
  /// a dialog and as a full page (when the screen unmounted mid-request).
  Widget _resultCard({required bool success, required VoidCallback onPressed}) {
    return Builder(
      builder: (context) {
        final c = context.colors;
        final tone = success ? c.brand : c.error;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    tone,
                    Color.alphaBlend(Colors.black.withValues(alpha: 0.2), tone),
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: tone.withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(
                success ? Icons.check_rounded : Icons.lock_outline_rounded,
                color: Colors.white,
                size: 50,
              ),
            ).pop(),
            AppSpacing.vXl,
            Text(
              success ? 'Success!' : 'Invalid Credentials',
              style: context.text.headlineSmall?.copyWith(
                color: tone,
                fontWeight: FontWeight.w800,
              ),
            ),
            AppSpacing.vSm,
            Text(
              success
                  ? 'Your password has been changed successfully.'
                  : 'The current password you entered is incorrect. Please try again.',
              textAlign: TextAlign.center,
              style: context.text.bodyLarge?.copyWith(
                color: c.textSecondary,
                height: 1.4,
              ),
            ),
            AppSpacing.vXl,
            AppButton(
              label: success ? 'OK' : 'Try Again',
              onPressed: onPressed,
            ),
          ],
        );
      },
    );
  }

  Widget _asDialog(Widget child) => AlertDialog(
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.brXl),
    contentPadding: const EdgeInsets.all(28),
    content: child,
  );

  Widget _asPage(Widget child) => Scaffold(
    backgroundColor: Colors.black87,
    body: Center(
      child: Container(
        margin: const EdgeInsets.all(AppSpacing.xxl),
        padding: const EdgeInsets.all(AppSpacing.xxl),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: AppRadius.brXl,
        ),
        child: child,
      ),
    ),
  );

  /// Build success dialog widget
  Widget _buildSuccessDialog() => Builder(
    builder: (ctx) => _asDialog(
      _resultCard(
        success: true,
        onPressed: () {
          // Close the dialog first
          Navigator.of(ctx).pop();
          // Then navigate back to profile using the stored navigator, once the
          // dialog is fully closed.
          Future.delayed(const Duration(milliseconds: 50), () {
            if (_navigator != null && _navigator!.canPop()) {
              _navigator!.pop();
            }
          });
        },
      ).celebrate(),
    ),
  );

  /// Build invalid credentials dialog widget
  Widget _buildInvalidCredentialsDialog() => Builder(
    builder: (ctx) => _asDialog(
      _resultCard(
        success: false,
        onPressed: () {
          Navigator.of(ctx).pop();
          // Clear the current password field so user can re-enter
          _currentController.clear();
          if (mounted) FocusScope.of(context).requestFocus(FocusNode());
        },
      ),
    ),
  );

  /// Build success dialog as a full page (for use with Navigator)
  Widget _buildSuccessDialogPage() => _asPage(
    _resultCard(
      success: true,
      onPressed: () {
        // The dialog page is pushed on top, so pop it and then the change
        // password screen to return to profile.
        if (_navigator != null) {
          _navigator!.pop();
          Future.delayed(const Duration(milliseconds: 50), () {
            if (_navigator!.canPop()) _navigator!.pop();
          });
        }
      },
    ),
  );

  /// Build invalid credentials dialog as a full page (for use with Navigator)
  Widget _buildInvalidCredentialsDialogPage() => _asPage(
    _resultCard(
      success: false,
      onPressed: () {
        _navigator?.pop();
        _currentController.clear();
      },
    ),
  );

  /// Show alert for invalid credentials (wrong current password)
  void _showInvalidCredentialsAlert() {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _buildInvalidCredentialsDialog(),
    );
  }

  /// Show success alert dialog
  Future<void> _showSuccessAlert() async {
    if (!mounted) return;
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _buildSuccessDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final authProvider = context.watch<AuthProvider>();
    final busy = _isLoading || authProvider.isLoading;

    return MainScaffold(
      title: 'Change Password',
      showBackButton: !busy,
      body: Stack(
        children: [
          const Positioned.fill(child: AppBackdrop()),
          ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              AppSpacing.vLg,
              Center(
                child: Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    gradient: c.brandGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: c.brand.withValues(alpha: 0.35),
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
                ).pop(),
              ),
              AppSpacing.vXl,
              Text(
                'Secure Your Account',
                textAlign: TextAlign.center,
                style: context.text.headlineMedium,
              ).enter(delay: const Duration(milliseconds: 60)),
              AppSpacing.vXs,
              Text(
                'Create a strong password to protect your account',
                textAlign: TextAlign.center,
                style: context.text.bodyMedium?.copyWith(
                  color: c.textSecondary,
                ),
              ).enter(delay: const Duration(milliseconds: 100)),
              AppSpacing.vXxl,
              // Shakes on a validation error.
              ValueListenableBuilder<int>(
                valueListenable: _shakeKey,
                builder: (context, shake, child) => child!.shake(shake),
                child: AppCard(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppTextField(
                        label: 'Current Password',
                        controller: _currentController,
                        prefixIcon: Icons.lock_outline_rounded,
                        obscure: true,
                        textInputAction: TextInputAction.next,
                      ),
                      AppSpacing.vLg,
                      AppTextField(
                        label: 'New Password',
                        controller: _newController,
                        prefixIcon: Icons.key_outlined,
                        obscure: true,
                        textInputAction: TextInputAction.next,
                      ),
                      AppSpacing.vLg,
                      AppTextField(
                        label: 'Confirm New Password',
                        controller: _confirmController,
                        prefixIcon: Icons.check_circle_outline_rounded,
                        obscure: true,
                        textInputAction: TextInputAction.done,
                      ),
                    ],
                  ),
                ),
              ).enterList(3),
              AppSpacing.vXl,
              AppButton(
                label: 'Change Password',
                icon: Icons.lock_reset_rounded,
                loading: busy,
                onPressed: _changePassword,
              ).enterList(4),
              AppSpacing.vXl,
              AppCard(
                color: c.brandSoft,
                shadow: const [],
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: c.brand, size: 20),
                    AppSpacing.hSm,
                    Expanded(
                      child: Text(
                        'Password must be at least 4 characters and different from your current password.',
                        style: context.text.bodySmall?.copyWith(
                          color: c.onBrandSoft,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ).enterList(5),
            ],
          ),
          // Blocking overlay while the request is in flight.
          IgnorePointer(
            ignoring: !busy,
            child: AnimatedOpacity(
              opacity: busy ? 1 : 0,
              duration: AppDuration.medium,
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.4),
                child: Center(
                  child: GlassPanel(
                    child: CircularProgressIndicator(color: c.brand),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
