import 'package:flutter/material.dart';
import '../services/api.dart';
import 'login_register.dart';
import 'subject_select.dart';
import 'post_problem_hub.dart';
import 'solve_hub.dart';
import 'ranking.dart';
import 'review_screen.dart';
import 'user_info.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<NavigatorState> _contentNavKey = GlobalKey<NavigatorState>();

  void _showInRight(Widget page) {
    final nav = _contentNavKey.currentState;
    if (nav == null) return;
    nav.pushReplacement(MaterialPageRoute(builder: (_) => page));
  }

  Widget _navButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: Colors.white,
        elevation: 1,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(icon, color: Colors.teal),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.black54),
              ],
            ),
          ),
        ),
      ),
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
                  if (!mounted) return;
                  Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const LoginRegisterScreen()),
                      (_) => false);
                  break;
              }
            },
            itemBuilder: (c) => const [
              PopupMenuItem(value: 'user', child: Text('ユーザー情報')),
              PopupMenuItem(value: 'subjects', child: Text('教材を選びなおす')),
              PopupMenuItem(value: 'logout', child: Text('ログアウト')),
            ],
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          const leftWidth = 250.0; // 固定幅
          return Row(
            children: [
              // 左側: プロフィールアイコン + ボタン
              ConstrainedBox(
                constraints: const BoxConstraints.tightFor(width: leftWidth),
                child: Container(
                  color: Colors.grey.shade50,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // プロフィールアイコン
                      GestureDetector(
                        onTap: () => _showInRight(const _ProfilePanel()),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: const [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: Colors.teal,
                                child: Icon(Icons.person, color: Colors.white),
                              ),
                              SizedBox(height: 8),
                              Text('プロフィール',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600, fontSize: 14)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _navButton(
                        icon: Icons.task_alt,
                        label: '問題を解く',
                        onTap: () => _showInRight(const SolveHubScreen()),
                      ),
                      _navButton(
                        icon: Icons.post_add,
                        label: '問題・解答・解説を投稿する',
                        onTap: () => _showInRight(const PostProblemHubScreen()),
                      ),
                      _navButton(
                        icon: Icons.refresh,
                        label: '振り返り',
                        onTap: () => _showInRight(const ReviewScreen()),
                      ),
                      _navButton(
                        icon: Icons.leaderboard,
                        label: 'ランキングを見る',
                        onTap: () => _showInRight(const RankingScreen()),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
              // 右側: コンテンツ表示エリア（Navigator を右側だけに配置）
              Expanded(
                child: Container(
                  color: Colors.white,
                  child: Navigator(
                    key: _contentNavKey,
                    onGenerateRoute: (settings) => MaterialPageRoute(
                      builder: (_) => const _ProfilePanel(),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// 右側プロフィールパネル（画像 + 各種統計 + ランク）
class _ProfilePanel extends StatefulWidget {
  const _ProfilePanel();
  @override
  State<_ProfilePanel> createState() => _ProfilePanelState();
}

class _ProfilePanelState extends State<_ProfilePanel> {
  Future<Map<String, dynamic>>? _future;

  @override
  void initState() {
    super.initState();
    _future = Api.userProfile();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FutureBuilder<Map<String, dynamic>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData) {
                  return const Text('プロフィール情報の取得に失敗しました');
                }
                final p = snapshot.data!;
                Widget statRow(String label, String value) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          SizedBox(width: 160, child: Text(label, style: const TextStyle(color: Colors.black54))),
                          Expanded(
                            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    );
                return Material(
                  color: Colors.white,
                  elevation: 1,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(
                          child: CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.teal,
                            child: Icon(Icons.person, color: Colors.white, size: 40),
                          ),
                        ),
                        const SizedBox(height: 16),
                        statRow('解答数', (p['answers_count'] ?? 0).toString()),
                        statRow('正解数', (p['correct_answers_count'] ?? 0).toString()),
                        statRow('正答率', '${(p['accuracy_rate'] ?? 0).toString()}%'),
                        statRow('作問数', (p['problems_created'] ?? 0).toString()),
                        statRow('解答作成数', (p['solutions_created'] ?? 0).toString()),
                        statRow('問題いいね数', (p['problem_likes'] ?? 0).toString()),
                        statRow('解説いいね数', (p['solution_likes'] ?? 0).toString()),
                        const Divider(height: 24),
                        Row(
                          children: [
                            const Text('ランク', style: TextStyle(color: Colors.black54)),
                            const SizedBox(width: 20),
                            Chip(
                              label: Text((p['rank'] ?? 'Bronze').toString()),
                              backgroundColor: Colors.teal.shade50,
                              side: BorderSide(color: Colors.teal.shade200),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

