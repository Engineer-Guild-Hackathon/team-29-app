import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class BreadcrumbItem {
  const BreadcrumbItem({required this.label, this.onTap});
  final String label;
  final VoidCallback? onTap;
}

class AppBreadcrumbs extends StatelessWidget {
  const AppBreadcrumbs({super.key, required this.items});

  final List<BreadcrumbItem> items;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodyMedium;
    final linkStyle = (textStyle ?? const TextStyle()).copyWith(
      color: AppColors.textSecondary,
      fontWeight: FontWeight.w600,
    );
    final currentStyle = (textStyle ?? const TextStyle()).copyWith(
      color: AppColors.textPrimary_dark,
      fontWeight: FontWeight.w700,
    );

    final crumbWidgets = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      final it = items[i];
      final isLast = i == items.length - 1;
      final labelWidget = isLast || it.onTap == null
          ? Text(it.label, style: currentStyle, overflow: TextOverflow.ellipsis)
          : InkWell(
              onTap: it.onTap,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                child: Text(it.label, style: linkStyle, overflow: TextOverflow.ellipsis),
              ),
            );

      if (isLast) {
        crumbWidgets.add(labelWidget);
      } else {
        crumbWidgets.add(Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            labelWidget,
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
            ),
          ],
        ));
      }
    }

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: crumbWidgets,
    );
  }
}

