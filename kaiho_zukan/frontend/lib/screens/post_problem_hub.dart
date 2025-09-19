import 'package:flutter/material.dart';
import '../widgets/illustrated_action_button.dart';
import 'post_problem_subhub.dart';
import 'explain_hub.dart';
import '../widgets/app_icon.dart';

class PostProblemHubScreen extends StatelessWidget {
  const PostProblemHubScreen({super.key, this.embedded = false});

  final bool embedded;
  @override
  Widget build(BuildContext context) {
    final content = Center(
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
                color: Colors.indigo,
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
                color: Colors.teal,
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
    );

    if (embedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(title: const IconAppBarTitle(title: '投稿する')),
      body: content,
    );
  }
}
