import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/home_section_theme.dart';
import 'app_header.dart';
import 'app_sidebar.dart';
import '../screens/home.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.backgroundColor,
    this.selectedIndex = 0,
    this.onNavigateIndex,
    this.appBar,
    this.subHeader,
  });

  final String title;
  final Widget body;
  final Color? backgroundColor;
  final int selectedIndex;
  final ValueChanged<int>? onNavigateIndex;
  final PreferredSizeWidget? appBar; // ignored for compatibility
  final Widget? subHeader; // shown under header

  List<AppNavItem> _navItems() => [
        AppNavItem(
          index: 0,
          title: 'ホーム',
          icon: Icons.home,
          color: HomeSectionThemes.profile.accent,
          illustrationHeight: 56,
        ),
        AppNavItem(
          index: 1,
          title: '問題を解く',
          icon: Icons.psychology_alt,
          color: HomeSectionThemes.solve.accent,
          illustrationHeight: 56,
        ),
        AppNavItem(
          index: 2,
          title: '投稿する',
          icon: Icons.upload_file,
          color: HomeSectionThemes.post.accent,
          illustrationHeight: 56,
        ),
        AppNavItem(
          index: 3,
          title: '振り返り',
          icon: Icons.history_toggle_off,
          color: HomeSectionThemes.review.accent,
          illustrationHeight: 56,
        ),
        AppNavItem(
          index: 4,
          title: 'ランキング',
          icon: Icons.emoji_events,
          color: HomeSectionThemes.ranking.accent,
          illustrationHeight: 56,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final navItems = _navItems();
    final bg = backgroundColor ?? AppColors.background;
    void defaultNavigate(int i) {
      try {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => HomeScreen(initialSelected: i)),
        );
      } catch (_) {}
    }
    final navigate = onNavigateIndex ?? defaultNavigate;
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 960;
        return Scaffold(
          backgroundColor: bg,
          drawer: isCompact
              ? Drawer(
                  child: AppDrawerMenu(
                    items: navItems,
                    selectedIndex: selectedIndex,
                    onSelect: (i) => navigate(i),
                  ),
                )
              : null,
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!isCompact)
                AppSidebar(
                  items: navItems,
                  selectedIndex: selectedIndex,
                  onSelect: (i) => navigate(i),
                  mediaPadding: MediaQuery.of(context).padding,
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Builder(
                      builder: (inner) => AppHeader(
                        title: title,
                        isCompact: isCompact,
                        onOpenMenu: () => Scaffold.of(inner).openDrawer(),
                      ),
                    ),
                    if (subHeader != null)
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        decoration: BoxDecoration(
                          color: bg,
                          border: const Border(
                            bottom: BorderSide(color: AppColors.border),
                          ),
                        ),
                        child: subHeader,
                      ),
                    Expanded(child: body),
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
