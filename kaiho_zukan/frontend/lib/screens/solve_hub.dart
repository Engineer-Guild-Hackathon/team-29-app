import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/home_section_theme.dart';
import '../widgets/home_section_surface.dart';
import '../widgets/illustrated_action_button.dart';
import 'solve_screen.dart';
import 'solve_picker_screen.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_breadcrumbs.dart';
import 'home.dart';

class SolveHubScreen extends StatelessWidget {
  const SolveHubScreen({
    super.key,
    this.embedded = false,
    HomeSectionTheme? theme,
  }) : theme = theme ?? HomeSectionThemes.solve;

  final bool embedded;
  final HomeSectionTheme theme;

  @override
  Widget build(BuildContext context) {
    final section = HomeSectionSurface(
      theme: theme,
      maxContentWidth: 720,
      scrollable: true,
      backgroundColor: AppColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [

          const SizedBox(height: 8),
          IllustratedActionButton(
            label: '問題をランダムに解く',
            icon: Icons.casino,
            backgroundColor: AppColors.accent1_light,
            color: AppColors.accent1,
            illustrationHeight: 120,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SolveScreen(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          IllustratedActionButton(
            label: '問題を選んで解く',
            icon: Icons.view_list,
            backgroundColor: AppColors.secondary_light,
            color: AppColors.secondary,
            illustrationHeight: 120,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SolvePickerScreen(),
              ),
            ),
          ),
        ],
      ),
    );

    if (embedded) {
      return section;
    }

    return AppScaffold(
      title: '問題を解く',
      subHeader: AppBreadcrumbs(
        items: [
          BreadcrumbItem(
            label: 'ホーム',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            ),
          ),
          const BreadcrumbItem(label: '問題を解く'),
        ],
      ),
      backgroundColor: AppColors.background,
      body: section,
    );
  }
}
