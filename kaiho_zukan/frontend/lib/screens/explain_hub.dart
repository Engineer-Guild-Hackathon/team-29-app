import 'package:flutter/material.dart';
import '../widgets/illustrated_action_button.dart';
import 'explain_create_new.dart';
import 'explain_my_list.dart';
import 'explain_fix_wrong.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_breadcrumbs.dart';
import 'home.dart';
import 'post_problem_hub.dart';
import '../constants/app_colors.dart';

class ExplainHubScreen extends StatelessWidget {
  const ExplainHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: '解説の投稿/編集',
      subHeader: AppBreadcrumbs(
        items: [
          BreadcrumbItem(
            label: 'ホーム',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            ),
          ),
          BreadcrumbItem(
            label: '投稿する',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PostProblemHubScreen()),
            ),
          ),
          const BreadcrumbItem(label: '解説の投稿/編集'),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IllustratedActionButton(
                  label: '新規で解説を投稿する',
                  icon: Icons.lightbulb,
                  backgroundColor: AppColors.accent1_light,
                  color: AppColors.accent1,
                  illustrationHeight: 120,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ExplainCreateNewScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                IllustratedActionButton(
                  label: '自分が作った解説を編集する',
                  icon: Icons.edit_note,
                  backgroundColor: AppColors.secondary_light,
                  color: AppColors.secondary,
                  illustrationHeight: 120,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ExplainMyListScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                IllustratedActionButton(
                  label: '「間違っている」と判定された解説を修正',
                  icon: Icons.build,
                  backgroundColor: AppColors.accent2_light,
                  color: AppColors.accent2,
                  illustrationHeight: 120,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ExplainFixWrongScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

