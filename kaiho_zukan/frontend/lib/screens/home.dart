import 'package:flutter/material.dart';
import '../services/api.dart';
import 'login_register.dart';
import 'subject_select.dart';
import 'post_problem_hub.dart';
import 'explain_create.dart';
import 'solve_screen.dart';
import 'ranking.dart';
import 'solve_picker_screen.dart';
import 'review_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Widget menuTile(BuildContext context, String title, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
          onTap: onTap,
          child: Container(
            height: 56,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
                color: Colors.teal.shade50,
                border: Border.all(color: Colors.teal.shade200),
                borderRadius: BorderRadius.circular(12)),
            child: Text(title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ホーム'),
        actions: [
          IconButton(
            tooltip: 'ログアウト',
            icon: const Icon(Icons.logout),
            onPressed: () {
              Api.clearToken();
              Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const LoginRegisterScreen()),
                  (_) => false);
            },
          ),
        ],
      ),
      body: Center(
          child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            menuTile(context, '問題をランダムに解く', () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SolveScreen()))),
            menuTile(context, '問題を選んで解く', () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SolvePickerScreen()))),
            menuTile(context, '問題を投稿する', () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PostProblemHubScreen()))),
            menuTile(context, '解説を作る', () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ExplainCreateScreen()))),
            menuTile(context, '振り返る', () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReviewScreen()))),
            menuTile(context, 'ランキングを見る', () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RankingScreen()))),
            const SizedBox(height: 8),
            menuTile(context, '教科を選択しなおす', () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const SubjectSelectScreen(
                          isOnboarding: false,
                        )))),
          ]),
        ),
      )),
    );
  }
}
