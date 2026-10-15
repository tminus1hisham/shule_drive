import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/connectivity_provider.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme_extension.dart';
import 'ui/ui.dart';

/// Blocks the whole app with a reconnect prompt while there is no Wi-Fi or
/// mobile data. Lives in `MaterialApp.builder`, so it covers every route and
/// disappears by itself once the connection comes back.
class OfflineGate extends StatelessWidget {
  const OfflineGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final connectivity = context.watch<ConnectivityProvider>();

    return Stack(
      children: [
        child,
        if (connectivity.showOfflinePrompt) ...[
          const ModalBarrier(dismissible: false, color: Colors.black54),
          AlertDialog(
            title: Row(
              children: [
                Icon(Icons.wifi_off_rounded, color: context.colors.error),
                const SizedBox(width: AppSpacing.xs),
                const Expanded(child: Text('No internet connection')),
              ],
            ),
            content: const Text(
              'Transfa needs Wi-Fi or mobile data. '
              'Please turn one on and reconnect.',
            ),
            actionsPadding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.md,
            ),
            actions: [
              AppButton(
                label: 'Try again',
                icon: Icons.refresh_rounded,
                size: AppButtonSize.medium,
                onPressed: connectivity.checkConnectivity,
              ),
            ],
          ),
        ],
      ],
    );
  }
}
