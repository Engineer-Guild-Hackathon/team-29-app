import 'package:flutter/material.dart';
import 'post_problem_form.dart';
import 'my_problems.dart';
import '../widgets/app_icon.dart';

/// 問題投稿のサブハブ
/// - 新規で問題を投稿する
/// - 自分が作った問題を編集する
class PostProblemSubHubScreen extends StatelessWidget {
  const PostProblemSubHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const IconAppBarTitle(title: '問題の投稿/編集')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PostProblemForm(),
                        ),
                      );
                    },
                    child: const Text('新規で問題を投稿する'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MyProblemsScreen(),
                        ),
                      );
                    },
                    child: const Text('自分が作った問題を編集する'),
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
