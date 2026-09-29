import 'package:flutter/material.dart';
import '../../theme/app_spacing.dart';
import 'app_skeleton.dart';
import 'empty_state.dart';

/// Picks the right body for a data-backed screen: skeleton while [loading],
/// an error with retry, an empty state, or [child]. Switching between them
/// cross-fades. With [onRefresh], every state (not just the content) can be
/// pulled to refresh, since the placeholders are laid out in a scrollable.
///
/// [child] should itself be scrollable when [onRefresh] is set.
class AsyncBody extends StatelessWidget {
  const AsyncBody({
    super.key,
    required this.loading,
    required this.child,
    this.error,
    this.onRetry,
    this.isEmpty = false,
    this.empty,
    this.skeleton,
    this.onRefresh,
  });

  final bool loading;
  final Widget child;

  /// Error message to show; null means no error.
  final String? error;
  final VoidCallback? onRetry;
  final bool isEmpty;

  /// Shown when [isEmpty]; usually an [EmptyState].
  final Widget? empty;

  /// Loading placeholder. Defaults to a list of [SkeletonListTile]s.
  final Widget? skeleton;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final (String key, Widget body) = loading
        ? ('loading', skeleton ?? const _SkeletonList())
        : error != null
        ? (
            'error',
            _fill(
              EmptyState.error(message: error, onRetry: onRetry ?? onRefresh),
            ),
          )
        : isEmpty
        ? ('empty', _fill(empty ?? const SizedBox.shrink()))
        : ('content', child);

    Widget out = AnimatedSwitcher(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : AppDuration.medium,
      switchInCurve: AppCurves.easeOut,
      child: KeyedSubtree(key: ValueKey(key), child: body),
    );
    if (onRefresh != null && !loading) {
      out = RefreshIndicator(onRefresh: onRefresh!, child: out);
    }
    return out;
  }

  /// Placeholders centred in a viewport-tall scrollable, so a
  /// [RefreshIndicator] above them still receives the pull.
  Widget _fill(Widget w) => LayoutBuilder(
    builder: (context, constraints) => ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(child: w),
        ),
      ],
    ),
  );
}

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) => ListView.builder(
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.all(AppSpacing.md),
    itemCount: 6,
    itemBuilder: (_, _) => const SkeletonListTile(),
  );
}
