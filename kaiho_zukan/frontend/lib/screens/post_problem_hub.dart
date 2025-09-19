import 'package:flutter/material.dart';
import '../widgets/illustrated_action_button.dart';
import 'post_problem_subhub.dart';
import 'explain_hub.dart';
import '../widgets/app_icon.dart';
import '../constants/app_colors.dart';

class PostProblemHubScreen extends StatelessWidget {
  const PostProblemHubScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const IconAppBarTitle(title: '投稿する')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
        ),
      ),
    );
  }
}
