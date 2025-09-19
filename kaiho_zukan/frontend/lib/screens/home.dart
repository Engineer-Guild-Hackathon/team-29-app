import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/home_section_theme.dart';
import '../services/api.dart';
import '../widgets/app_icon.dart';
import '../widgets/illustrated_action_button.dart';
import '../widgets/home_section_surface.dart';
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

class _NavigationItem {
  const _NavigationItem({
    required this.index,
    required this.title,
    required this.icon,
    required this.color,
    this.illustrationHeight = 108,
  });

  final int index;
  final String title;
  final IconData icon;
  final Color color;
  final double illustrationHeight;
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  int _selected = 0;
  Map<String, dynamic>? _profile;
  bool _loading = true;

  static final List<_NavigationItem> _navigationItems = [
    _NavigationItem(
      index: 0,
      title: 'ホーム',
      icon: Icons.home,
      color: HomeSectionThemes.profile.accent,
      illustrationHeight: 56,
    ),
    _NavigationItem(
      index: 1,
      title: '問題を解く',
      icon: Icons.psychology_alt,
      color: HomeSectionThemes.solve.accent,
      illustrationHeight: 56,
    ),
    _NavigationItem(
      index: 2,
      title: '問題・解答・解説を投稿する',
      icon: Icons.upload_file,
      color: HomeSectionThemes.post.accent,
      illustrationHeight: 56,
    ),
    _NavigationItem(
      index: 3,
      title: '振り返り',
      icon: Icons.history_toggle_off,
      color: HomeSectionThemes.review.accent,
      illustrationHeight: 56,
    ),
    _NavigationItem(
      index: 4,
      title: 'ランキングを見る',
      icon: Icons.emoji_events,
      color: HomeSectionThemes.ranking.accent,
      illustrationHeight: 56,
    ),
  ];

  static const Map<int, HomeSectionTheme> _sectionThemes = {
    0: HomeSectionThemes.profile,
    1: HomeSectionThemes.solve,
    2: HomeSectionThemes.post,
    3: HomeSectionThemes.review,
    4: HomeSectionThemes.ranking,
  };

  String get _pageTitle {
    switch (_selected) {
      case 1:
        return '問題を解く';
      case 2:
        return '投稿する';
      case 3:
        return '振り返り';
      case 4:
        return 'ランキング';
      default:
        return 'ホーム';
    }
  }

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

  void _handleNavigation(int index, {bool fromDrawer = false}) {
    if (_selected != index) {
      setState(() => _selected = index);
    }
    if (fromDrawer) {
      _scaffoldKey.currentState?.closeDrawer();
    }
  }

  Future<void> _handleOverflowAction(String value) async {
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
  }

  Widget _buildMenuButton(_NavigationItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: IllustratedActionButton(
        label: item.title,
        icon: item.icon,
        color: item.color,
        isSelected: _selected == item.index,
        illustrationHeight: item.illustrationHeight,
        onTap: () => _handleNavigation(item.index),
      ),
    );
  }

  Widget _buildSidebar(EdgeInsets mediaPadding) {
    return Container(
      width: 288,
      height: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.light,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 12,
            offset: Offset(2, 0),
          ),
        ],
      ),
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          24,
          mediaPadding.top + 24,
          24,
          mediaPadding.bottom + 24,
        ),
        children: [
          Tooltip(
            message: 'ホーム',
            child: GestureDetector(
              onTap: () => _handleNavigation(0),
              child: AppIcon(
                size: 132,
                borderRadius: BorderRadius.circular(28),
                backgroundColor: Colors.transparent,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(height: 16),
          for (final item in _navigationItems) _buildMenuButton(item),
        ],
      ),
    );
  }

  Widget _buildDrawerContent() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: AppIcon(
              size: 96,
              borderRadius: BorderRadius.circular(24),
              backgroundColor: Colors.transparent,
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 12),
          for (final item in _navigationItems)
            ListTile(
              leading: Icon(item.icon, color: item.color),
              title: Text(item.title),
              selected: _selected == item.index,
              selectedTileColor:
                  AppColors.primary_light.withValues(alpha: 0.25),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onTap: () => _handleNavigation(item.index, fromDrawer: true),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    EdgeInsets mediaPadding,
    bool isCompact,
    String? iconUrl,
  ) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        mediaPadding.top + 12,
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
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
            if (isCompact) const SizedBox(width: 12),
            Expanded(
              child: Text(
                _pageTitle,
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
                Semantics(
                  button: true,
                  label: '通知を開く',
                  child: const _NotificationBell(
                    focusColor: Colors.white24,
                    hoverColor: Colors.white12,
                  ),
                ),
                const SizedBox(width: 12),
                _buildProfileAction(iconUrl, isCompact),
                const SizedBox(width: 12),
                _buildOverflowMenu(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileAction(String? iconUrl, bool isCompact) {
    final username = _profile?['username']?.toString() ?? '';

    final avatar = CircleAvatar(
      radius: 18,
      backgroundColor: AppColors.background,
      backgroundImage: iconUrl != null ? NetworkImage(iconUrl) : null,
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
          onTap: () => _handleNavigation(0),
          focusColor: Colors.white24,
          hoverColor: Colors.white12,
          highlightColor: Colors.white10,
          mouseCursor: SystemMouseCursors.click,
          child: Ink(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact || username.isEmpty ? 4 : 12,
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
                if (!isCompact && username.isNotEmpty) ...[
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

  Widget _buildOverflowMenu() {
    return PopupMenuButton<String>(
      tooltip: 'その他の操作',
      icon: const Icon(Icons.more_vert),
      onSelected: _handleOverflowAction,
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'user', child: Text('ユーザー情報')),
        PopupMenuItem(value: 'subjects', child: Text('教材を選びなおす')),
        PopupMenuItem(value: 'logout', child: Text('ログアウト')),
      ],
    );
  }

  Widget _buildContentStack() {
    return IndexedStack(
      index: _selected,
      children: [
        _ProfileDetailView(
          profile: _profile,
          loading: _loading,
          onRefresh: _loadProfile,
          theme: HomeSectionThemes.profile,
        ),
        SolveHubScreen(embedded: true, theme: HomeSectionThemes.solve),
        PostProblemHubScreen(embedded: true, theme: HomeSectionThemes.post),
        ReviewScreen(embedded: true, theme: HomeSectionThemes.review),
        RankingScreen(
          showAppBar: false,
          embedded: true,
          theme: HomeSectionThemes.ranking,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final iconUrl = _profile?['icon_url'] as String?;
    final mediaPadding = MediaQuery.of(context).padding;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 960;
        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: AppColors.background,
          drawer: isCompact ? Drawer(child: _buildDrawerContent()) : null,
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!isCompact) _buildSidebar(mediaPadding),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(mediaPadding, isCompact, iconUrl),
                    Expanded(
                      child: Container(
                        color: (_sectionThemes[_selected]?.background ??
                            AppColors.background),
                        padding: EdgeInsets.only(bottom: mediaPadding.bottom),
                        child: _buildContentStack(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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

class _ProfileDetailView extends StatelessWidget {
  const _ProfileDetailView({
    required this.theme,
    this.profile,
    this.loading = false,
    this.onRefresh,
  });

  final HomeSectionTheme theme;
  final Map<String, dynamic>? profile;
  final bool loading;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (loading) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HomeSectionCard(
            theme: theme,
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: const Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    } else if (profile == null) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HomeSectionCard(
            theme: theme,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('プロフィールを取得できませんでした'),
                const SizedBox(height: 8),
                const Text('通信環境を確認し、もう一度お試しください。'),
                if (onRefresh != null) ...[
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: onRefresh,
                      child: const Text('再読み込み'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    } else {
      final p = profile!;
      final badgeColor =
          (theme.secondaryAccent ?? theme.accent).withOpacity(0.18);
      final statsItems = <MapEntry<String, String>>[
        MapEntry('ユーザー名', p['username'].toString()),
        MapEntry('解いた数', p['answer_count'].toString()),
        MapEntry('正解数', p['correct_count'].toString()),
        MapEntry('正答率', '${p['accuracy']}%'),
        MapEntry('作問数', p['question_count'].toString()),
        MapEntry('解説作成数', p['answer_creation_count'].toString()),
        MapEntry('問題のいいね', p['question_likes'].toString()),
        MapEntry('解説のいいね', p['explanation_likes'].toString()),
        MapEntry('現在のランク', p['rank'].toString()),
      ];

      content = RefreshIndicator(
        onRefresh: onRefresh ?? () async {},
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            HomeSectionCard(
              theme: theme,
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: theme.border,
                    backgroundImage: p['icon_url'] != null
                        ? NetworkImage(p['icon_url'])
                        : null,
                    child: p['icon_url'] == null
                        ? const Icon(Icons.person, size: 36)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p['username'].toString(),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          p['mail_address']?.toString() ?? '',
                          style:
                              const TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'ランク: ${p['rank']}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            HomeSectionCard(
              theme: theme,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: statsItems
                    .map((e) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(e.key),
                              Text(
                                e.value,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      );
    }

    return HomeSectionSurface(
      theme: theme,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: content,
    );
  }
}

class _NotificationBell extends StatefulWidget {
  const _NotificationBell({
    this.hoverColor,
    this.focusColor,
  });

  final Color? hoverColor;
  final Color? focusColor;
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
              onPressed: () => Navigator.pop(c), child: const Text('閉じる')),
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
