import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme_extension.dart';
import 'app_button.dart';

/// Themed snackbars with a leading icon and semantic accent stripe.
class AppSnackbar {
  AppSnackbar._();

  static void success(BuildContext context, String message) =>
      _show(context, message, Icons.check_circle_outline, AppPalette.success);

  static void error(BuildContext context, String message) =>
      _show(context, message, Icons.error_outline, AppPalette.error);

  static void info(BuildContext context, String message) =>
      _show(context, message, Icons.info_outline, AppPalette.info);

  static void _show(
    BuildContext context,
    String message,
    IconData icon,
    Color accent,
  ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: accent),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 4),
        ),
      );
  }
}

/// Themed confirmation dialog. Returns true when confirmed.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  IconData? icon,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final accent = destructive ? ctx.colors.error : ctx.colors.brand;
      return AlertDialog(
        title: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: accent),
              const SizedBox(width: AppSpacing.xs),
            ],
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(message),
        actionsPadding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: cancelLabel,
                  variant: AppButtonVariant.outline,
                  size: AppButtonSize.medium,
                  onPressed: () => Navigator.pop(ctx, false),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  label: confirmLabel,
                  variant: destructive
                      ? AppButtonVariant.danger
                      : AppButtonVariant.primary,
                  size: AppButtonSize.medium,
                  onPressed: () => Navigator.pop(ctx, true),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
  return result ?? false;
}

/// Opens a rounded, theme-styled modal bottom sheet with a drag handle. Wraps
/// the boilerplate shared by the app's bespoke sheets.
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool haptic = true,
}) {
  if (haptic) HapticFeedback.mediumImpact();
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(ctx).viewInsets.bottom,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xs,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        child: builder(ctx),
      ),
    ),
  );
}
