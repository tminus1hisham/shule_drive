import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme_extension.dart';
import 'ui/ui.dart';

enum PasswordChangeFailure { wrongPassword, savedDespiteServerError, other }

/// Classify a failed change-password call. The backend saves the password
/// and can then 500 (post-save email), so those count as saved.
PasswordChangeFailure classifyPasswordChangeError(String? error) {
  final e = (error ?? '').toLowerCase();
  if (e.contains('incorrect') || e.contains('invalid credential')) {
    return PasswordChangeFailure.wrongPassword;
  }
  if (e.contains('invalid server response format') ||
      e.contains('nullreferenceexception') ||
      e.contains('server error') ||
      e.contains('json parse error') ||
      e.contains('500')) {
    return PasswordChangeFailure.savedDespiteServerError;
  }
  return PasswordChangeFailure.other;
}

/// First-login password change the user cannot skip. [currentPassword] is
/// the one just typed at login; when null (app restarted mid-flow) the user
/// is asked for it.
Future<void> showMandatoryPasswordChange(
  BuildContext context, {
  String? currentPassword,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _MandatoryPasswordDialog(currentPassword: currentPassword),
  );
}

class _MandatoryPasswordDialog extends StatefulWidget {
  const _MandatoryPasswordDialog({this.currentPassword});

  final String? currentPassword;

  @override
  State<_MandatoryPasswordDialog> createState() =>
      _MandatoryPasswordDialogState();
}

class _MandatoryPasswordDialogState extends State<_MandatoryPasswordDialog> {
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;
  bool _saving = false;
  bool _done = false;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? _validate(String current) {
    if (current.isEmpty) return 'Enter your current password';
    if (_new.text.length < 4)
      return 'New password must be at least 4 characters';
    if (_new.text != _confirm.text) return 'Passwords do not match';
    if (_new.text == current) return 'Choose a different password';
    return null;
  }

  Future<void> _submit() async {
    final current = widget.currentPassword ?? _current.text;
    final invalid = _validate(current);
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    final auth = context.read<AuthProvider>();
    final ok = await auth.changePassword(
      currentPassword: current,
      newPassword: _new.text,
    );
    if (!mounted) return;

    final failure = ok ? null : classifyPasswordChangeError(auth.errorMessage);
    if (ok || failure == PasswordChangeFailure.savedDespiteServerError) {
      await auth.clearMustChangePassword();
      if (mounted) setState(() => _done = true);
      return;
    }
    setState(() {
      _saving = false;
      _error = failure == PasswordChangeFailure.wrongPassword
          ? 'Current password is incorrect'
          : auth.errorMessage ?? 'Could not change password, try again';
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _done,
      child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text(_done ? 'Password changed' : 'Set a new password'),
        content: _done ? _buildDone(context) : _buildForm(context),
        actions: [
          AppButton(
            label: _done ? 'Continue' : 'Save password',
            loading: _saving && !_done,
            expand: true,
            onPressed: _done ? () => Navigator.pop(context) : _submit,
          ),
        ],
      ),
    );
  }

  Widget _buildDone(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.check_circle_rounded,
          size: AppIconSize.xl * 2,
          color: context.colors.brand,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Use your new password the next time you log in.',
          textAlign: TextAlign.center,
          style: context.text.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildForm(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'For your security, replace the password you were given before '
            'using the app.',
            style: context.text.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          if (widget.currentPassword == null) ...[
            AppTextField(
              label: 'Current password',
              controller: _current,
              obscure: true,
              prefixIcon: Icons.lock_outline_rounded,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          AppTextField(
            label: 'New password',
            controller: _new,
            obscure: true,
            prefixIcon: Icons.lock_reset_rounded,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            label: 'Confirm new password',
            controller: _confirm,
            obscure: true,
            prefixIcon: Icons.lock_reset_rounded,
            textInputAction: TextInputAction.done,
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _error!,
              style: context.text.bodySmall?.copyWith(
                color: context.scheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
