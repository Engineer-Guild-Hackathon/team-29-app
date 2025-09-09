import 'package:flutter/material.dart';
import 'solve_screen.dart';
import 'leaderboard_screen.dart';
import 'create_problem_screen.dart';
import 'create_explanation_screen.dart';
import 'review_screen.dart';
import 'user_screen.dart';
import '../services/api.dart';
import 'login_register.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext c) {
    final items = [
      ('ユーザー設定', Icons.person,
          () => Navigator.push(c, MaterialPageRoute(builder: (_) => const UserScreen()))),
      ('問題を解く', Icons.quiz,
          () => Navigator.push(c, MaterialPageRoute(builder: (_) => const SolveScreen()))),
      ('問題を投稿', Icons.add_box,
          () => Navigator.push(c, MaterialPageRoute(builder: (_) => const CreateProblemScreen()))),
      ('解説を作る', Icons.edit,
          () => Navigator.push(c, MaterialPageRoute(builder: (_) => const CreateExplanationScreen()))),
      ('振り返る', Icons.refresh,
          () => Navigator.push(c, MaterialPageRoute(builder: (_) => const ReviewScreen()))),
      ('ランキング', Icons.emoji_events,
          () => Navigator.push(c, MaterialPageRoute(builder: (_) => const LeaderboardScreen()))),
    ];
    return Scaffold(
        appBar: AppBar(title: const Text('ホーム'), actions: [
          IconButton(
            tooltip: 'ログアウト',
            icon: const Icon(Icons.logout),
            onPressed: () {
              Api.clearToken();
              Navigator.pushAndRemoveUntil(
                  c,
                  MaterialPageRoute(
                      builder: (_) => const LoginRegisterScreen()),
                  (_) => false);
            },
          )
        ]),
        body: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemBuilder: (_, i) {
            final e = items[i];
            return SizedBox(
              height: 64,
              child: ElevatedButton.icon(
                onPressed: e.$3,
                icon: Icon(e.$2, size: 24),
                style: ElevatedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 16)),
                label: Text(e.$1, style: const TextStyle(fontSize: 16)),
              ),
            );
          },
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemCount: items.length,
        ));
  }
}

