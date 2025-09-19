import 'package:flutter/material.dart';
import '../services/api.dart';

const _iconPath = '/icon';

class AppIcon extends StatelessWidget {
  final double size;
  final BorderRadiusGeometry? borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final String? imageUrl;

  const AppIcon({
    super.key,
    this.size = 32,
    this.borderRadius,
    this.padding,
    this.backgroundColor,
    this.imageUrl,
  });

  static String? resolveImageUrl(String? url) {
    if (url == null) return null;
    final trimmed = url.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('/')) {
      return '${Api.base}$trimmed';
    }
    return '${Api.base}/$trimmed';
  }

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(size * 0.2);
    final bg = backgroundColor ?? Theme.of(context).colorScheme.surface;
    final resolvedUrl = resolveImageUrl(imageUrl) ?? '${Api.base}${_iconPath}';

    Widget image;
    try {
      final dpr = MediaQuery.of(context).devicePixelRatio;
      image = Image.network(
        resolvedUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: (size * dpr).round(),
        cacheHeight: (size * dpr).round(),
        filterQuality: FilterQuality.medium,
        isAntiAlias: true,
        errorBuilder: (context, error, stack) => _fallbackIcon(context),
      );
    } catch (_) {
      image = _fallbackIcon(context);
    }

    return Container(
      width: size,
      height: size,
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: radius,
      ),
      child: ClipRRect(
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: image,
      ),
    );
  }

  Widget _fallbackIcon(BuildContext context) {
    return Icon(
      Icons.person,
      size: size,
      color: Theme.of(context).colorScheme.secondary,
    );
  }
}

class IconAppBarTitle extends StatelessWidget {
  final String title;
  final double iconSize;
  final Color? color;

  const IconAppBarTitle({
    super.key,
    required this.title,
    this.iconSize = 30,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final baseStyle = textTheme.titleLarge ?? const TextStyle(fontSize: 20);
    final textStyle = color != null ? baseStyle.copyWith(color: color) : baseStyle;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIcon(size: iconSize, borderRadius: BorderRadius.circular(iconSize * 0.25)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: textStyle,
          ),
        ),
      ],
    );
  }
}
