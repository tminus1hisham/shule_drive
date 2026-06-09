import 'package:flutter/material.dart';
import '../../theme/app_theme_extension.dart';

/// Circular avatar with a branded gradient fallback and an initial. Shows a
/// network image when [imageUrl] is provided, gracefully falling back to the
/// initial of [name] on error. Used in the dashboard header, chat, profile.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    this.imageUrl,
    this.name,
    this.size = 44,
    this.onTap,
    this.borderColor,
    this.heroTag,
  });

  final String? imageUrl;
  final String? name;
  final double size;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    Widget avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: context.colors.brandGradient,
        shape: BoxShape.circle,
        border: borderColor != null
            ? Border.all(color: borderColor!, width: 2)
            : null,
        boxShadow: context.colors.shadowSm,
      ),
      clipBehavior: Clip.antiAlias,
      child: (imageUrl != null && imageUrl!.isNotEmpty)
          ? Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, stack) => _fallback(context),
            )
          : _fallback(context),
    );

    if (heroTag != null) avatar = Hero(tag: heroTag!, child: avatar);

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: avatar);
    }
    return avatar;
  }

  Widget _fallback(BuildContext context) {
    final initial = (name != null && name!.trim().isNotEmpty)
        ? name!.trim()[0].toUpperCase()
        : 'U';
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.4,
        ),
      ),
    );
  }
}
