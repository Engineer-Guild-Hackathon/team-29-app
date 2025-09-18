import 'package:flutter/material.dart';
import '../widgets/illustrated_action_button.dart';
import 'explain_create_new.dart';
import 'explain_my_list.dart';
import 'explain_fix_wrong.dart';

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IllustratedActionButton(
                  label: '新規で解説を投稿する',
                  icon: Icons.lightbulb,
                  color: Colors.teal,
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
                  color: Colors.deepPurple,
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
                  color: Colors.orange,
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
