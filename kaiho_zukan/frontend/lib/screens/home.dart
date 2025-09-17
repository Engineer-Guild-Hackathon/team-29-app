import 'package:flutter/material.dart';
import '../services/api.dart';
import '../widgets/app_icon.dart';
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
        title: const IconAppBarTitle(title: 'ホーム'),
        actions: [
          const _NotificationBell(),
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
            const SizedBox(height: 16),
            const AppIcon(size: 120),
            const SizedBox(height: 24),
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
      // fetch all, compute unseen count locally
      final list = await Api.notifications(unseenOnly: false, limit: 200);
      if (!mounted) return;
      setState(() {
        _items = list;
        _count = list.where((e) => (e['seen'] == false)).length;
      });
    } catch (_) {}
  }

  void _openMenu() async {
    // Take a snapshot for display
    final snapshot = List<Map<String, dynamic>>.from(_items.map((e) => Map<String, dynamic>.from(e)));

    // Immediately mark current unseen as seen (server-side)
    try {
      final unseenIds = snapshot.where((e) => (e['seen'] == false)).map<int>((e) => e['id'] as int).toList();
      if (unseenIds.isNotEmpty) {
        await Api.notificationsMarkSeen(unseenIds);
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() => _count = 0);

    // Separate unseen and seen
    final unseen = snapshot.where((e) => (e['seen'] == false)).toList();
    final seen = snapshot.where((e) => (e['seen'] == true)).toList();

    // Group unseen likes and wrongs
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

    // Unseen header (optional)
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
          ? '$actor$extra さんが「$title」にいいねしました。'
          : '$actor$extra さんが「$title」の解説にいいねしました。';
      entries.add(Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Colors.lightBlue.shade50,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          dense: true,
          title: Text(text),
          onTap: () {
            if (type == 'problem_like') {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const MyProblemsScreen()));
            } else {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ExplainMyListScreen()));
            }
          },
        ),
      ));
    });
    unseenWrongs.forEach((pid, arr) {
      if (arr.isEmpty) return;
      final first = arr.first;
      final title = (first['problem_title'] ?? '').toString();
      final text = '「$title」に投稿した解説が間違っているかもしれません。';
      entries.add(Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Colors.lightBlue.shade50,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          dense: true,
          title: Text(text),
          onTap: () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ExplainFixWrongScreen()));
          },
        ),
      ));
    });

    // Seen header
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
        text = '$actor さんが「$title」にいいねしました。';
      } else if (type == 'explanation_like') {
        final actor = (it['actor_name'] ?? '誰か').toString();
        text = '$actor さんが「$title」の解説にいいねしました。';
      } else {
        text = '「$title」に投稿した解説が間違っているかもしれません。';
      }
      entries.add(Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          dense: true,
          title: Text(text),
          onTap: () {
            if (type == 'problem_like') {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const MyProblemsScreen()));
            } else if (type == 'explanation_like') {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ExplainMyListScreen()));
            } else {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ExplainFixWrongScreen()));
            }
          },
        ),
      ));
    }

    if (entries.isEmpty) {
      entries.add(const ListTile(dense: true, title: Text('通知はありません')));
    }

    // Show as dialog-like popup
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
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$_count',
                  style: const TextStyle(color: Colors.white, fontSize: 11)),
            ),
          ),
      ],
    );
  }
}
