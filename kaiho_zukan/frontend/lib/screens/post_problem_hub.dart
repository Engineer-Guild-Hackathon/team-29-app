import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/home_section_theme.dart';
import '../widgets/home_section_surface.dart';
import '../widgets/app_breadcrumbs.dart';
import '../widgets/illustrated_action_button.dart';
import 'post_problem_subhub.dart';
import 'explain_hub.dart';
import 'home.dart';
import '../widgets/app_scaffold.dart';

class PostProblemHubScreen extends StatelessWidget {
  const PostProblemHubScreen({
    super.key,
    this.embedded = false,
    HomeSectionTheme? theme,
  }) : theme = theme ?? HomeSectionThemes.post;

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
          HomeSectionCard(
            theme: theme,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                IllustratedActionButton(
                  label: '問題を投稿する',
                  icon: Icons.post_add,
                  backgroundColor: AppColors.accent1_light,
                  color: AppColors.accent1,
                  illustrationHeight: 120,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PostProblemSubHubScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                IllustratedActionButton(
                  label: '解答・解説を投稿する',
                  icon: Icons.menu_book,
                  backgroundColor: AppColors.secondary_light,
                  color: AppColors.secondary,
                  illustrationHeight: 120,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ExplainHubScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (embedded) {
      return section;
    }

    return AppScaffold(
      title: '投稿する',
      backgroundColor: AppColors.background,
      subHeader: AppBreadcrumbs(
        items: [
          BreadcrumbItem(
            label: 'ホーム',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            ),
          ),
          const BreadcrumbItem(label: '投稿する'),
        ],
      ),
      body: section,
    );
  }
}
