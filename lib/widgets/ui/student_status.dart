import 'package:flutter/material.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme_extension.dart';
import 'app_card.dart';
import 'status_pill.dart';

/// The one colour / icon / label for each student trip status, so "Picked Up"
/// looks the same on every screen. Takes the API's status strings
/// (`pending`, `picked`, `dropped`, `absent`, plus `picked_up`/`dropped_off`).
/// For the `StudentStatus` enum pass `status.name`.
@immutable
class StudentStatusStyle {
  const StudentStatusStyle._(this.color, this.icon, this.label);

  final Color color;
  final IconData icon;
  final String label;

  static StudentStatusStyle of(BuildContext context, String? status) {
    final c = context.colors;
    return switch (status) {
      'picked' || 'picked_up' => StudentStatusStyle._(
        c.brand,
        Icons.check_circle_rounded,
        'Picked Up',
      ),
      'dropped' || 'dropped_off' => StudentStatusStyle._(
        c.info,
        Icons.home_rounded,
        'Dropped Off',
      ),
      'absent' => StudentStatusStyle._(
        c.warning,
        Icons.cancel_rounded,
        'Absent',
      ),
      _ => StudentStatusStyle._(c.textMuted, Icons.schedule_rounded, 'Pending'),
    };
  }
}

/// A student card: avatar ringed in the status colour, name, optional
/// subtitle, status pill and [trailing] actions. When [status] changes the
/// ring recolours, the pill cross-fades and [trailing] swaps with a fade, so
/// a pick/drop reads as a moment rather than a jump.
class StudentStatusRow extends StatelessWidget {
  const StudentStatusRow({
    super.key,
    required this.name,
    required this.status,
    this.photoUrl,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.highlighted = false,
  });

  final String name;
  final String? status;
  final String? photoUrl;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Emphasise this row (e.g. "next student") with a brand edge.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final style = StudentStatusStyle.of(context, status);
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : AppDuration.medium;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.sm),
      border: Border.all(
        color: highlighted ? context.colors.brand : context.colors.outline,
        width: highlighted ? 1.5 : 1,
      ),
      child: Row(
        children: [
          StatusAvatar(name: name, photoUrl: photoUrl, color: style.color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall?.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xxs + 2),
                StatusPill(
                  label: style.label,
                  color: style.color,
                  icon: style.icon,
                  dense: true,
                ),
              ],
            ),
          ),
          if (trailing != null)
            AnimatedSwitcher(
              duration: duration,
              switchInCurve: AppCurves.easeOut,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: ScaleTransition(scale: anim, child: child),
              ),
              child: KeyedSubtree(key: ValueKey(status), child: trailing!),
            ),
        ],
      ),
    );
  }
}

/// Circular avatar (photo or initials) with a ring and corner dot in [color];
/// both recolour smoothly when [color] changes.
class StatusAvatar extends StatelessWidget {
  const StatusAvatar({
    super.key,
    required this.name,
    required this.color,
    this.photoUrl,
    this.size = 48,
  });

  final String name;
  final Color color;
  final String? photoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : AppDuration.slow;
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;

    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: color),
      duration: duration,
      curve: AppCurves.easeOut,
      builder: (context, c, _) {
        final ring = c ?? color;
        return SizedBox.square(
          dimension: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: size,
                height: size,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: ring, width: 2),
                ),
                child: ClipOval(
                  child: ColoredBox(
                    color: ring.withValues(alpha: 0.14),
                    child: hasPhoto
                        ? Image.network(
                            photoUrl!,
                            fit: BoxFit.cover,
                            width: size,
                            height: size,
                            errorBuilder: (_, _, _) => _initials(context, ring),
                          )
                        : _initials(context, ring),
                  ),
                ),
              ),
              Positioned(
                right: -1,
                bottom: -1,
                child: Container(
                  width: size * 0.3,
                  height: size * 0.3,
                  decoration: BoxDecoration(
                    color: ring,
                    shape: BoxShape.circle,
                    border: Border.all(color: context.scheme.surface, width: 2),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _initials(BuildContext context, Color c) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final text = parts.length >= 2 && parts[1].isNotEmpty
        ? '${parts[0][0]}${parts[1][0]}'
        : (name.trim().isNotEmpty ? name.trim()[0] : '?');
    return Center(
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: c,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.34,
        ),
      ),
    );
  }
}
