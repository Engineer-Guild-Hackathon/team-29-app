import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/api.dart';
import '../screens/login_register.dart';
import '../screens/subject_select.dart';
import '../screens/user_info.dart';
import '../screens/home.dart';
import '../screens/my_problems.dart';
import '../screens/explain_my_list.dart';
import '../screens/explain_fix_wrong.dart';

class AppHeader extends StatefulWidget {
  const AppHeader({
    super.key,
    required this.title,
    required this.isCompact,
    this.onOpenMenu,
    this.username,
    this.iconUrl,
    this.onTapProfile,
  });

  final String title;
  final bool isCompact;
  final VoidCallback? onOpenMenu;
  final String? username;
  final String? iconUrl;
  final VoidCallback? onTapProfile;

  @override
  State<AppHeader> createState() => _AppHeaderState();
}

class _AppHeaderState extends State<AppHeader> {
  String? _username;
  String? _iconUrl;

  @override
  void initState() {
    super.initState();
    _username = widget.username?.trim();
    _iconUrl = widget.iconUrl?.trim();
    if ((_username == null || _username!.isEmpty) || (_iconUrl == null)) {
      _loadProfile();
    }
  }

  Future<void> _loadProfile() async {
    try {
      final p = await Api.profile.fetch();
      if (!mounted) return;
      setState(() {
        _username = p['username']?.toString();
        _iconUrl = p['icon_url']?.toString();
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = (_username ?? widget.username ?? '').trim();
    final iconUrl = _iconUrl ?? widget.iconUrl;
    final isCompact = widget.isCompact;
    final onProfileTap = widget.onTapProfile ?? () async {
      try {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen(initialSelected: 0)),
        );
      } catch (_) {}
    };

    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        MediaQuery.of(context).padding.top + 12,
        24,
        12,
      ),
      decoration: const BoxDecoration(
        color: AppColors.primary_dark,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: IconTheme(
        data: const IconThemeData(color: Colors.white),
        child: Row(
          children: [
            if (isCompact)
              _HeaderIconButton(
                icon: Icons.menu,
                tooltip: 'メニューを開く',
                onPressed: widget.onOpenMenu,
              ),
            if (isCompact) const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ) ??
                    const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
              ),
            ),
            const SizedBox(width: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const NotificationBell(
                  focusColor: Colors.white24,
                  hoverColor: Colors.white12,
                ),
                const SizedBox(width: 12),
                _ProfileAction(
                  username: name,
                  iconUrl: iconUrl,
                  compact: isCompact,
                  onTap: onProfileTap,
                ),
                const SizedBox(width: 12),
                const _OverflowMenu(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon),
        onPressed: onPressed,
        splashRadius: 24,
        hoverColor: Colors.white12,
        focusColor: Colors.white24,
      ),
    );
  }
}

class _ProfileAction extends StatelessWidget {
  const _ProfileAction({
    required this.username,
    required this.iconUrl,
    required this.compact,
    this.onTap,
  });

  final String username;
  final String? iconUrl;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final avatar = CircleAvatar(
      radius: 18,
      backgroundColor: AppColors.background,
      backgroundImage: iconUrl != null ? NetworkImage(iconUrl!) : null,
      child: iconUrl == null
          ? const Icon(Icons.person, size: 20, color: Colors.white)
          : null,
    );

    return Tooltip(
      message: 'プロフィールを開く',
      child: Semantics(
        button: true,
        label: 'プロフィールを開く',
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          focusColor: Colors.white24,
          hoverColor: Colors.white12,
          highlightColor: Colors.white10,
          mouseCursor: SystemMouseCursors.click,
          child: Ink(
            padding: EdgeInsets.symmetric(
              horizontal: compact || username.isEmpty ? 4 : 12,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                avatar,
                if (!compact && username.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Text(
                      username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OverflowMenu extends StatelessWidget {
  const _OverflowMenu();

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.settings),
      onSelected: (value) async {
        switch (value) {
          case 'user':
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UserInfoScreen()),
            );
            break;
          case 'subjects':
            await Navigator.push(
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
            if (!context.mounted) return;
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
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'user', child: Text('ユーザー情報')),
        const PopupMenuItem(value: 'subjects', child: Text('科目の選択')),
        PopupMenuItem(
          value: 'logout',
          child: const Text(
            'ログアウト',
            style: TextStyle(color: AppColors.danger),
          ),
        ),
      ],
    );
  }
}

class NotificationBell extends StatefulWidget {
  const NotificationBell({
    super.key,
    this.hoverColor,
    this.focusColor,
  });

  final Color? hoverColor;
  final Color? focusColor;
  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
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
        child: Text('新着', style: TextStyle(fontWeight: FontWeight.bold)),
      ));
    }

    unseenLikes.forEach((key, arr) {
      if (arr.isEmpty) return;
      final first = arr.first;
      final type = (first['type'] ?? '').toString();
      final title = (first['problem_title'] ?? '').toString();
      final actor = (first['actor_name'] ?? 'だれか').toString();
      final extra = arr.length > 1 ? ' ほか${arr.length - 1}名' : '';
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
      final text = '「$title」に投稿した解説が誤っている可能性があります';
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
        final actor = (it['actor_name'] ?? 'だれか').toString();
        text = '$actor さんが「$title」にいいねしました';
      } else if (type == 'explanation_like') {
        final actor = (it['actor_name'] ?? 'だれか').toString();
        text = '$actor さんが「$title」の解説にいいねしました';
      } else {
        text = '「$title」に投稿した解説が誤っている可能性があります';
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
                MaterialPageRoute(
                    builder: (_) => const ExplainFixWrongScreen()),
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
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('とじる')),
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
          splashRadius: 24,
          hoverColor: widget.hoverColor,
          focusColor: widget.focusColor,
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
              child: Text(
                '$_count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
