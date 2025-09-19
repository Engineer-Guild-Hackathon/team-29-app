import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../widgets/app_icon.dart';
import '../widgets/illustrated_action_button.dart';

class AppNavItem {
  const AppNavItem({
    required this.index,
    required this.title,
    required this.icon,
    required this.color,
    this.illustrationHeight = 108,
  });

  final int index;
  final String title;
  final IconData icon;
  final Color color;
  final double illustrationHeight;
}

class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
    required this.mediaPadding,
  });

  final List<AppNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final EdgeInsets mediaPadding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 288,
      height: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.light,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 12,
            offset: Offset(2, 0),
          ),
        ],
      ),
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          24,
          mediaPadding.top + 24,
          24,
          mediaPadding.bottom + 24,
        ),
        children: [
          Tooltip(
            message: 'ホーム',
            child: GestureDetector(
              onTap: () => onSelect(0),
              child: AppIcon(
                size: 200,
                borderRadius: BorderRadius.circular(28),
                backgroundColor: Colors.transparent,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(height: 16),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: IllustratedActionButton(
                label: item.title,
                icon: item.icon,
                color: item.color,
                isSelected: selectedIndex == item.index,
                illustrationHeight: item.illustrationHeight,
                onTap: () => onSelect(item.index),
              ),
            ),
        ],
      ),
    );
  }
}

class AppDrawerMenu extends StatelessWidget {
  const AppDrawerMenu({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<AppNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: AppIcon(
              size: 200,
              borderRadius: BorderRadius.circular(24),
              backgroundColor: Colors.transparent,
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 12),
          for (final item in items)
            ListTile(
              leading: Icon(item.icon, color: item.color),
              title: Text(item.title),
              selected: selectedIndex == item.index,
              selectedTileColor:
                  AppColors.primary_light.withValues(alpha: 0.25),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onTap: () {
                Navigator.pop(context);
                onSelect(item.index);
              },
            ),
        ],
      ),
    );
  }
}
