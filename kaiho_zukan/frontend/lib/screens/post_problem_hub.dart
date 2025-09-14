import 'package:flutter/material.dart';
import 'post_problem_form.dart';
import 'explain_create.dart';

class PostProblemHubScreen extends StatelessWidget {
  const PostProblemHubScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('投稿する')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PostProblemForm())),
                  child: const Text('問題を投稿する'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ExplainCreateScreen())),
                  child: const Text('解答・解説を投稿する'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
