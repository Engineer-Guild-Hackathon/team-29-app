import 'package:flutter/material.dart';
import '../services/api.dart';
import '../constants/app_colors.dart';
import 'my_problems.dart';
import 'explain_my_list.dart';
import 'explain_fix_wrong.dart';
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
  // 0: プロフィール詳細, 1: 問題を解く, 2: 投稿, 3: 振り返り, 4: ランキング
  int _selected = 0;
  Map<String, dynamic>? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final data = await Api.profile.fetch();
      if (!mounted) return;
      setState(() {
        _profile = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _profile = null;
        _loading = false;
      });
    }
  }

  Widget _menuButton(String title, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.light,
            border: Border.all(color: AppColors.primary_dark),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _leftPane(BuildContext context) {
    final p = _profile;
    final iconUrl = p?['icon_url'] as String?;
    final username = p?['username'] ?? '';
    return Container(
      width: 320,
      color: AppColors.warning,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            // 上部画像
            Container(
              height: 100,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 12),
            // プロフィールアイコン（押すと右側にプロフィール表示）
            InkWell(
              onTap: () => setState(() => _selected = 0),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: AppColors.border,
                    backgroundImage: iconUrl != null ? NetworkImage(iconUrl) : null,
                    child: iconUrl == null ? const Icon(Icons.person, size: 36) : null,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    username.toString(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _menuButton('問題を解く', () => setState(() => _selected = 1)),
            _menuButton('問題・解答・解説を投稿する', () => setState(() => _selected = 2)),
            _menuButton('振り返り', () => setState(() => _selected = 3)),
            _menuButton('ランキングを見る', () => setState(() => _selected = 4)),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _rightPane() {
    return Expanded(
      child: IndexedStack(
        index: _selected,
        children: [
          _ProfileDetailView(
            profile: _profile,
            loading: _loading,
            onRefresh: _loadProfile,
          ),
          const SolveHubScreen(),
          const PostProblemHubScreen(),
          const ReviewScreen(),
          const RankingScreen(showAppBar: false),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ホーム'),
        actions: [
          const _NotificationBell(),
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu),
            onSelected: (v) async {
              switch (v) {
                case 'user':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const UserInfoScreen()),
                  );
                  break;
                case 'subjects':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SubjectSelectScreen(
                        isOnboarding: false,
                      ),
                    ),
                  );
                  break;
                case 'logout':
                  Api.clearToken();
                  if (!mounted) return;
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LoginRegisterScreen(),
                    ),
                    (_) => false,
                  );
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
      body: Row(
        children: [
          _leftPane(context),
          _rightPane(),
        ],
      ),
    );
  }
}

class _ProfileDetailView extends StatelessWidget {
  const _ProfileDetailView({
    this.profile,
    this.loading = false,
    this.onRefresh,
    super.key,
  });

  final Map<String, dynamic>? profile;
  final bool loading;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final p = profile;
    if (p == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('プロフィールを取得できませんでした'),
            const SizedBox(height: 8),
            if (onRefresh != null)
              ElevatedButton(onPressed: onRefresh, child: const Text('再読み込み')),
          ],
        ),
      );
    }

    final items = <MapEntry<String, String>>[
      MapEntry('ユーザー名', p['username'].toString()),
      MapEntry('解答数', p['answer_count'].toString()),
      MapEntry('正解数', p['correct_count'].toString()),
      MapEntry('正答率', p['accuracy'].toString() + '%'),
      MapEntry('作問数', p['question_count'].toString()),
      MapEntry('解説作成数', p['answer_creation_count'].toString()),
      MapEntry('問題いいね数', p['question_likes'].toString()),
      MapEntry('解説いいね数', p['explanation_likes'].toString()),
      MapEntry('ランク', p['rank'].toString()),
    ];

    return RefreshIndicator(
      onRefresh: onRefresh ?? () async {},
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: AppColors.border,
                backgroundImage:
                    p['icon_url'] != null ? NetworkImage(p['icon_url']) : null,
                child: p['icon_url'] == null
                    ? const Icon(Icons.person, size: 36)
                    : null,
              ),
              const SizedBox(width: 16),
              Text(
                p['username'].toString(),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.light,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('ランク: ' + p['rank'].toString(),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: items
                    .map((e) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(e.key),
                              Text(e.value,
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationBell extends StatefulWidget {
  const _NotificationBell();
  @override
  State<_NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<_NotificationBell> {
  int _count = 0;
  List<dynamic> _items = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final list = await Api.notifications(unseenOnly: false, limit: 200);
      if (!mounted) return;
      setState(() {
        _items = list;
        _count = list.where((e) => (e['seen'] == false)).length;
      });
    } catch (_) {}
  }

  Future<void> _openMenu() async {
    final snapshot = List<Map<String, dynamic>>.from(
      _items.map((e) => Map<String, dynamic>.from(e)),
    );

    try {
      final unseenIds = snapshot
          .where((e) => (e['seen'] == false))
          .map<int>((e) => e['id'] as int)
          .toList();
      if (unseenIds.isNotEmpty) {
        await Api.notificationsMarkSeen(unseenIds);
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() => _count = 0);

    final unseen = snapshot.where((e) => (e['seen'] == false)).toList();
    final seen = snapshot.where((e) => (e['seen'] == true)).toList();

    final unseenLikes = <String, List<dynamic>>{}; // key: type:pid
    final unseenWrongs = <int, List<dynamic>>{}; // pid -> items
    for (final it in unseen) {
      final type = (it['type'] ?? '').toString();
      if (type == 'problem_like' || type == 'explanation_like') {
        final key = '$type:${it['problem_id']}';
        unseenLikes.putIfAbsent(key, () => []).add(it);
      } else if (type == 'explanation_wrong') {
        final pid = it['problem_id'] as int?;
        if (pid != null) unseenWrongs.putIfAbsent(pid, () => []).add(it);
      }
    }

    final entries = <Widget>[];
    if (unseen.isNotEmpty) {
      entries.add(const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Text('未読', style: TextStyle(fontWeight: FontWeight.bold)),
      ));
    }

    unseenLikes.forEach((key, arr) {
      if (arr.isEmpty) return;
      final first = arr.first;
      final type = (first['type'] ?? '').toString();
      final title = (first['problem_title'] ?? '').toString();
      final actor = (first['actor_name'] ?? '誰か').toString();
      final extra = arr.length > 1 ? ' さんと他${arr.length - 1}人' : '';
      final text = type == 'problem_like'
          ? '$actor$extra さんが「$title」にいいねしました'
          : '$actor$extra さんが「$title」の解説にいいねしました';
      entries.add(Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.light,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          dense: true,
          title: Text(text),
          onTap: () {
            if (type == 'problem_like') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyProblemsScreen()),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ExplainMyListScreen()),
              );
            }
          },
        ),
      ));
    });

    unseenWrongs.forEach((pid, arr) {
      if (arr.isEmpty) return;
      final first = arr.first;
      final title = (first['problem_title'] ?? '').toString();
      final text = '「$title」に投稿した解説が間違っているかもしれません';
      entries.add(Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.light,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          dense: true,
          title: Text(text),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ExplainFixWrongScreen()),
            );
          },
        ),
      ));
    });

    if (seen.isNotEmpty) {
      entries.add(const Padding(
        padding: EdgeInsets.only(top: 8, bottom: 4),
        child: Text('既読', style: TextStyle(fontWeight: FontWeight.bold)),
      ));
    }

    for (final it in seen) {
      final type = (it['type'] ?? '').toString();
      final title = (it['problem_title'] ?? '').toString();
      String text;
      if (type == 'problem_like') {
        final actor = (it['actor_name'] ?? '誰か').toString();
        text = '$actor さんが「$title」にいいねしました';
      } else if (type == 'explanation_like') {
        final actor = (it['actor_name'] ?? '誰か').toString();
        text = '$actor さんが「$title」の解説にいいねしました';
      } else {
        text = '「$title」に投稿した解説が間違っているかもしれません';
      }
      entries.add(Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.background,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          dense: true,
          title: Text(text),
          onTap: () {
            if (type == 'problem_like') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyProblemsScreen()),
              );
            } else if (type == 'explanation_like') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ExplainMyListScreen()),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ExplainFixWrongScreen()),
              );
            }
          },
        ),
      ));
    }

    if (entries.isEmpty) {
      entries.add(const ListTile(dense: true, title: Text('通知はありません')));
    }

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('通知'),
        content: SizedBox(
          width: 360,
          height: 320,
          child: Scrollbar(
            child: ListView(
              children: entries,
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('閉じる')),
        ],
      ),
    ).then((_) => _refresh());
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          tooltip: '通知',
          icon: const Icon(Icons.notifications),
          onPressed: _openMenu,
        ),
        if (_count > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$_count',
                  style: const TextStyle(color: AppColors.background, fontSize: 11)),
            ),
          ),
      ],
    );
  }
}
