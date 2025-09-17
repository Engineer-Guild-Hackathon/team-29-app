import 'package:flutter/material.dart';
import '../services/api.dart';

const _iconPath = '/icon';

class AppIcon extends StatelessWidget {
  final double size;
  final BorderRadiusGeometry? borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;

  const AppIcon({
    super.key,
    this.size = 32,
    this.borderRadius,
    this.padding,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(size * 0.2);
    final bg = backgroundColor ?? Theme.of(context).colorScheme.surface;

    Widget image;
    try {
      image = Image.network(
        '${Api.base}${_iconPath}',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => Icon(
          Icons.school,
          size: size,
          color: Theme.of(context).colorScheme.secondary,
        ),
      );
    } catch (_) {
      image = Icon(
        Icons.school,
        size: size,
        color: Theme.of(context).colorScheme.secondary,
      );
    }

    return Container(
      width: size,
      height: size,
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: radius,
      ),
      clipBehavior: Clip.antiAlias,
      child: image,
    );
  }
}

class IconAppBarTitle extends StatelessWidget {
  final String title;
  final double iconSize;

  const IconAppBarTitle({
    super.key,
    required this.title,
    this.iconSize = 30,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIcon(size: iconSize, borderRadius: BorderRadius.circular(iconSize * 0.25)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleLarge,
          ),
        ),
      ],
    );
  }
}
