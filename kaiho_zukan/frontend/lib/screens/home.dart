import 'package:flutter/material.dart';
import '../services/api.dart';
import 'login_register.dart';
import 'subject_select.dart';
import 'post_problem_hub.dart';
import 'solve_hub.dart';
import 'ranking.dart';
import 'review_screen.dart';
import 'user_info.dart';

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
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu),
            onSelected: (v) async {
              switch (v) {
                case 'user':
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const UserInfoScreen()));
                  break;
                case 'subjects':
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SubjectSelectScreen(
                                isOnboarding: false,
                              )));
                  break;
                case 'logout':
                  Api.clearToken();
                  Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const LoginRegisterScreen()),
                      (_) => false);
                  break;
              }
            },
            itemBuilder: (c) => const [
              PopupMenuItem(value: 'user', child: Text('ユーザ情報')),
              PopupMenuItem(value: 'subjects', child: Text('教材を選びなおす')),
              PopupMenuItem(value: 'logout', child: Text('ログアウト')),
            ],
          ),
        ],
      ),
      body: Center(
          child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            menuTile(context, '問題を解く', () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SolveHubScreen()))),
            menuTile(context, '問題・解答・解説を投稿する', () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PostProblemHubScreen()))),
            menuTile(context, '振り返る', () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReviewScreen()))),
            menuTile(context, 'ランキングを見る', () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RankingScreen()))),
          ]),
        ),
      )),
    );
  }
}
