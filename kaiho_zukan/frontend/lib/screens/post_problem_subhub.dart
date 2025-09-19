import 'package:flutter/material.dart';
import '../widgets/illustrated_action_button.dart';
import 'post_problem_form.dart';
import 'my_problems.dart';
import '../widgets/app_icon.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_breadcrumbs.dart';
import 'home.dart';
import 'post_problem_hub.dart';
import '../constants/app_colors.dart';

/// 問題投稿のサブハブ
/// - 新規で問題を投稿する
/// - 自分が作った問題を編集する
class PostProblemSubHubScreen extends StatelessWidget {
  const PostProblemSubHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: '問題の投稿/編集',
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
          const BreadcrumbItem(label: '問題の投稿/編集'),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IllustratedActionButton(
                  label: '新規で問題を投稿する',
                  icon: Icons.add_task,
                  backgroundColor: AppColors.accent1_light,
                  color: AppColors.accent1,
                  illustrationHeight: 120,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PostProblemForm(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                IllustratedActionButton(
                  label: '自分が作った問題を編集する',
                  icon: Icons.edit_note,
                  backgroundColor: AppColors.secondary_light,
                  color: AppColors.secondary,
                  illustrationHeight: 120,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MyProblemsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

