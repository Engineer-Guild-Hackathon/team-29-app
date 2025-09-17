import 'package:flutter/material.dart';
import 'explain_create_new.dart';
import 'explain_my_list.dart';

class ExplainHubScreen extends StatelessWidget {
  const ExplainHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('解説の投稿/編集')),
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
                      builder: (_) => const ExplainCreateNewScreen(),
                    ),
                  ),
                  child: const Text('新規で解説を投稿する'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ExplainMyListScreen(),
                    ),
                  ),
                  child: const Text('自分が作った解説を編集する'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

