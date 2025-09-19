import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

import '../services/api.dart';
import 'login_register.dart';
import 'subject_select.dart';
import 'user_info.dart';
import '../widgets/app_icon.dart';

class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key, this.myName, this.showAppBar = true});

  final String? myName;
  final bool showAppBar;

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen>
    with SingleTickerProviderStateMixin {
  static const Color _accentColor = AppColors.primary;
  static const List<_RankingMetric> _metrics = [
    _RankingMetric(
      key: 'created_problems',
      label: '作問数',
      tooltip: '作成した問題の数',
    ),
    _RankingMetric(
      key: 'created_expl',
      label: '解説作成数',
      tooltip: '投稿した解説の数',
    ),
    _RankingMetric(
      key: 'likes_problems',
      label: '問題いいね',
      tooltip: 'あなたの問題についたいいね数',
    ),
    _RankingMetric(
      key: 'likes_expl',
      label: '解説いいね',
      tooltip: 'あなたの解説についたいいね数',
    ),
  ];

  late final TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _itemKeys = {};

  String _selectedMetric = _metrics.first.key;
  bool _isLoading = true;
  String? _errorMessage;
  List<_RankingEntry> _entries = const [];
  String? _pendingScrollId;
  bool _hasScrolledToSelf = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _metrics.length, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _load();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) return;
    final metric = _metrics[_tabController.index];
    if (metric.key == _selectedMetric) return;
    setState(() {
      _selectedMetric = metric.key;
      _isLoading = true;
      _errorMessage = null;
    });
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await Api.leaderboardNamed(metric: _selectedMetric);
      final rawItems = response['items'];
      if (rawItems is! List) {
        throw Exception('invalid data');
      }
      final parsed = _parseEntries(rawItems);
      if (!mounted) return;
      setState(() {
        _entries = parsed.entries;
        _pendingScrollId = parsed.scrollId;
        _isLoading = false;
        _errorMessage = null;
        final validIds = _entries.map((e) => e.scrollId).toSet();
        _itemKeys.removeWhere((key, value) => !validIds.contains(key));
      });
      _scheduleScrollToSelf();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '読み込みに失敗しました。再試行してください';
        _isLoading = false;
        _entries = const [];
        _pendingScrollId = null;
      });
    }
  }

  ({List<_RankingEntry> entries, String? scrollId}) _parseEntries(List rawItems) {
    final normalizedMyName = widget.myName?.trim().toLowerCase();
    final parsedItems = <_ParsedItem>[];
    var unnamedCount = 1;

    for (final item in rawItems) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item as Map);
      final nickname = _stringValue(map['nickname']);
      final username = _stringValue(map['username']);
      final rawName = _stringValue(map['name']);
      final value = map['value'];
      double score = 0;
      if (value is num) {
        score = value.toDouble();
      } else if (value is String) {
        score = double.tryParse(value) ?? 0;
      }
      var displayName = nickname ?? rawName ?? username ?? 'ユーザー$unnamedCount';
      if (displayName.trim().isEmpty) {
        displayName = 'ユーザー$unnamedCount';
      }
      final matchKeys = <String>{};
      for (final candidate in [nickname, username, rawName, displayName]) {
        final normalized = candidate?.trim().toLowerCase();
        if (normalized != null && normalized.isNotEmpty) {
          matchKeys.add(normalized);
        }
      }
      final tooltipParts = <String>{};
      if (nickname != null && nickname != displayName) {
        tooltipParts.add(nickname);
      }
      if (username != null) {
        tooltipParts.add('@$username');
      }
      if (rawName != null && rawName != displayName && rawName != nickname) {
        tooltipParts.add(rawName);
      }
      parsedItems.add(
        _ParsedItem(
          displayName: displayName,
          score: score,
          matchKeys: matchKeys,
          tooltip: tooltipParts.isEmpty ? null : tooltipParts.join('\n'),
        ),
      );
      unnamedCount++;
    }

    parsedItems.sort((a, b) {
      final scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) return scoreCompare;
      return a.displayNameLower.compareTo(b.displayNameLower);
    });

    final entries = <_RankingEntry>[];
    double? lastScore;
    var currentRank = 0;
    String? scrollId;

    for (var index = 0; index < parsedItems.length; index++) {
      final item = parsedItems[index];
      final normalizedScore = double.parse(item.score.toStringAsFixed(2));
      if (lastScore == null || (normalizedScore - lastScore).abs() > 1e-9) {
        currentRank = index + 1;
        lastScore = normalizedScore;
      }
      final entryScrollId = 'entry-$index-${item.displayNameLower}';
      final isSelf = normalizedMyName != null &&
          item.matchKeys.contains(normalizedMyName);
      entries.add(
        _RankingEntry(
          rank: currentRank,
          displayName: item.displayName,
          score: normalizedScore,
          isSelf: isSelf,
          tooltip: item.tooltip,
          scrollId: entryScrollId,
        ),
      );
      if (isSelf && scrollId == null) {
        scrollId = entryScrollId;
      }
    }

    return (entries: entries, scrollId: scrollId);
  }

  void _scheduleScrollToSelf() {
    if (_hasScrolledToSelf) return;
    final targetId = _pendingScrollId;
    if (targetId == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _itemKeys[targetId];
      final context = key?.currentContext;
      if (context != null) {
        _hasScrolledToSelf = true;
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _retry() {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    _load();
  }

  String _formatScore(double value) {
    final normalized = double.parse(value.toStringAsFixed(2));
    final sign = normalized < 0 ? '-' : '';
    final absValue = normalized.abs();
    final fixed = absValue.toStringAsFixed(2);
    final parts = fixed.split('.');
    final formattedInteger = _formatWithThousands(parts[0]);
    var decimalPart = parts.length > 1 ? parts[1] : '';
    decimalPart = decimalPart.replaceFirst(RegExp(r'0+$'), '');
    if (decimalPart.isEmpty) {
      return '$sign$formattedInteger';
    }
    return '$sign$formattedInteger.$decimalPart';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: widget.showAppBar ? _buildAppBar(context) : null,
      body: SafeArea(
        top: !widget.showAppBar,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: const IconAppBarTitle(title: 'ランキング'),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.menu),
          onSelected: (value) async {
            switch (value) {
              case 'user':
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const UserInfoScreen(),
                  ),
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
                // Remove all routes so the user cannot navigate back after logout.
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
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'user', child: Text('ユーザ情報')),
            PopupMenuItem(value: 'subjects', child: Text('教材を選びなおす')),
            PopupMenuItem(value: 'logout', child: Text('ログアウト')),
          ],
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.showAppBar) ...[
            Text(
              'ランキング',
              style: GoogleFonts.notoSans(
                color: AppColors.textPrimary,
                fontSize: 30,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Semantics(
            label: '指標セレクタ',
            child: _buildMetricTabs(),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTabs() {
    return Material(
      color: AppColors.light,
      borderRadius: BorderRadius.circular(16),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(width: 3, color: _accentColor),
          insets: EdgeInsets.symmetric(horizontal: 16),
        ),
        dividerColor: AppColors.background,
        splashBorderRadius: BorderRadius.circular(16),
        labelPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        overlayColor: MaterialStateProperty.resolveWith(
          (states) => states.contains(MaterialState.pressed)
              ? AppColors.surface
              : Colors.transparent,
        ),
        labelStyle: GoogleFonts.notoSans(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: GoogleFonts.notoSans(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        labelColor: AppColors.textPrimary,
        unselectedLabelColor: AppColors.textSecondary,
        tabs: _metrics
            .map(
              (metric) => Tab(
                child: Tooltip(
                  message: metric.tooltip,
                  waitDuration: const Duration(milliseconds: 400),
                  child: Text(metric.label),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingState();
    }
    if (_errorMessage != null) {
      return _buildErrorState();
    }
    if (_entries.isEmpty) {
      return _buildEmptyState();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;
        final topEntries = _entries.take(3).toList();
        final otherEntries = _entries.skip(3).toList();
        return CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                child: _buildTopThree(topEntries, isMobile),
              ),
            ),
            if (otherEntries.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final entry = otherEntries[index];
                      final key =
                          _itemKeys.putIfAbsent(entry.scrollId, () => GlobalKey());
                      return KeyedSubtree(
                        key: key,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _RankRow(
                            entry: entry,
                            accentColor: _accentColor,
                            scoreText: _formatScore(entry.score),
                            index: index,
                          ),
                        ),
                      );
                    },
                    childCount: otherEntries.length,
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 24),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTopThree(List<_RankingEntry> entries, bool isMobile) {
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }
    if (isMobile) {
      return Column(
        children: [
          for (var i = 0; i < entries.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == entries.length - 1 ? 0 : 16),
              child: Center(
                child: FractionallySizedBox(
                  widthFactor: 0.92,
                  child: _buildPodiumCard(entries[i], 190 + (i == 0 ? 20 : 0)),
                ),
              ),
            ),
        ],
      );
    }
    final first = entries.isNotEmpty ? entries[0] : null;
    final second = entries.length > 1 ? entries[1] : null;
    final third = entries.length > 2 ? entries[2] : null;
    return SizedBox(
      height: 260,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: second != null
                  ? _buildPodiumCard(second, 210)
                  : const SizedBox.shrink(),
            ),
          ),
          Expanded(
            flex: 4,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: first != null
                  ? _buildPodiumCard(first, 240)
                  : const SizedBox.shrink(),
            ),
          ),
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: third != null
                  ? _buildPodiumCard(third, 200)
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumCard(_RankingEntry entry, double height) {
    final key = _itemKeys.putIfAbsent(entry.scrollId, () => GlobalKey());
    return KeyedSubtree(
      key: key,
      child: _PodiumCard(
        entry: entry,
        height: height,
        scoreText: _formatScore(entry.score),
        accentColor: _accentColor,
      ),
    );
  }

  Widget _buildLoadingState() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;
        return CustomScrollView(
          controller: _scrollController,
          physics: const NeverScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                child: _LoadingTopSection(isMobile: isMobile),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: _LoadingRow(),
                  ),
                  childCount: 6,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.inbox_outlined,
            size: 48,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'データがありません',
            style: GoogleFonts.notoSans(
              color: AppColors.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 48,
            color: AppColors.danger,
          ),
          const SizedBox(height: 16),
          Text(
            '読み込みに失敗しました。再試行してください',
            style: GoogleFonts.notoSans(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _accentColor,
              foregroundColor: AppColors.background,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _retry,
            child: const Text('再試行'),
          ),
        ],
      ),
    );
  }
}

class _PodiumCard extends StatefulWidget {
  const _PodiumCard({
    required this.entry,
    required this.height,
    required this.scoreText,
    required this.accentColor,
  });

  final _RankingEntry entry;
  final double height;
  final String scoreText;
  final Color accentColor;

  @override
  State<_PodiumCard> createState() => _PodiumCardState();
}

class _PodiumCardState extends State<_PodiumCard> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final rank = widget.entry.rank;
    final gradient = _gradientForRank(rank);
    final borderColor = widget.entry.isSelf || _focused ? AppColors.primary : AppColors.border;
    final boxShadowColor = AppColors.shadow;

    return FocusableActionDetector(
      onShowFocusHighlight: (focused) {
        setState(() => _focused = focused);
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: widget.height,
          transform: Matrix4.identity()
            ..translate(0.0, _hovered ? -4.0 : 0.0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradient,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: borderColor,
              width: widget.entry.isSelf || _focused ? 2.2 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: boxShadowColor,
                offset: const Offset(0, 12),
                blurRadius: _hovered ? 26 : 20,
                spreadRadius: 0,
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Semantics(
            container: true,
            label: '${widget.entry.rank}位 ${widget.entry.displayName}',
            value: 'スコア ${widget.scoreText}',
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: Text(
                    _medalEmoji(rank),
                    semanticsLabel: '${rank}位',
                    style: const TextStyle(fontSize: 36),
                  ),
                ),
                Tooltip(
                  message: widget.entry.tooltip ?? widget.entry.displayName,
                  waitDuration: const Duration(milliseconds: 400),
                  child: Text(
                    widget.entry.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                      style: GoogleFonts.notoSans(
                        color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                Text(
                  widget.scoreText,
                  style: GoogleFonts.robotoMono(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
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

class _RankRow extends StatefulWidget {
  const _RankRow({
    required this.entry,
    required this.accentColor,
    required this.scoreText,
    required this.index,
  });

  final _RankingEntry entry;
  final Color accentColor;
  final String scoreText;
  final int index;

  @override
  State<_RankRow> createState() => _RankRowState();
}

class _RankRowState extends State<_RankRow> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final isEvenRow = widget.index.isEven;
    final neutralBase = isEvenRow ? AppColors.light : AppColors.light;
    final baseColor = widget.entry.isSelf ? AppColors.surface : neutralBase;
    final hoverColor = widget.entry.isSelf ? AppColors.surface : AppColors.border;
    final backgroundColor = _hovered ? hoverColor : baseColor;
    final borderColor = widget.entry.isSelf || _focused
        ? AppColors.primary
        : (_hovered ? AppColors.border : AppColors.border);
    final shadowColor = AppColors.shadow;

    return FocusableActionDetector(
      onShowFocusHighlight: (focused) {
        setState(() => _focused = focused);
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          transform: Matrix4.identity()
            ..translate(0.0, _hovered ? -2.0 : 0.0),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 1.4),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                offset: Offset(0, _hovered ? 6 : 10),
                blurRadius: _hovered ? 18 : 16,
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          child: Semantics(
            container: true,
            label: '${widget.entry.rank}位 ${widget.entry.displayName}',
            value: 'スコア ${widget.scoreText}',
            child: Row(
              children: [
                SizedBox(
                  width: 64,
                  child: Text(
                    '${widget.entry.rank}.',
                    style: GoogleFonts.notoSans(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: Tooltip(
                    message:
                        widget.entry.tooltip ?? widget.entry.displayName,
                    waitDuration: const Duration(milliseconds: 400),
                    child: Text(
                      widget.entry.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.notoSans(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 110,
                  child: Text(
                    widget.scoreText,
                    textAlign: TextAlign.right,
                    style: GoogleFonts.robotoMono(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
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

class _LoadingTopSection extends StatelessWidget {
  const _LoadingTopSection({required this.isMobile});

  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    if (isMobile) {
      return Column(
        children: const [
          _SkeletonCard(height: 210),
          SizedBox(height: 16),
          _SkeletonCard(height: 190),
          SizedBox(height: 16),
          _SkeletonCard(height: 190),
        ],
      );
    }
    return SizedBox(
      height: 260,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: const [
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: _SkeletonCard(height: 210),
            ),
          ),
          Expanded(
            flex: 4,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: _SkeletonCard(height: 240),
            ),
          ),
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: _SkeletonCard(height: 200),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            AppColors.border,
            AppColors.light,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.border,
                shape: BoxShape.circle,
              ),
            ),
            Container(
              height: 18,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            Container(
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingRow extends StatelessWidget {
  const _LoadingRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.light,
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 16,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              height: 16,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 110,
            height: 16,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ],
      ),
    );
  }
}

class _RankingMetric {
  const _RankingMetric({
    required this.key,
    required this.label,
    required this.tooltip,
  });

  final String key;
  final String label;
  final String tooltip;
}

class _RankingEntry {
  const _RankingEntry({
    required this.rank,
    required this.displayName,
    required this.score,
    required this.isSelf,
    required this.tooltip,
    required this.scrollId,
  });

  final int rank;
  final String displayName;
  final double score;
  final bool isSelf;
  final String? tooltip;
  final String scrollId;
}

class _ParsedItem {
  _ParsedItem({
    required this.displayName,
    required this.score,
    required this.matchKeys,
    required this.tooltip,
  });

  final String displayName;
  final double score;
  final Set<String> matchKeys;
  final String? tooltip;

  String get displayNameLower => displayName.toLowerCase();
}

String? _stringValue(Object? value) {
  if (value == null) return null;
  if (value is String) return value;
  return value.toString();
}

String _formatWithThousands(String digits) {
  if (digits.isEmpty) return '0';
  var start = 0;
  while (start < digits.length - 1 && digits[start] == '0') {
    start++;
  }
  final value = digits.substring(start);
  final segments = <String>[];
  for (var i = value.length; i > 0; i -= 3) {
    final startIndex = max(0, i - 3);
    segments.add(value.substring(startIndex, i));
  }
  return segments.reversed.join(',');
}

List<Color> _gradientForRank(int rank) {
  switch (rank) {
    case 1:
      return const [
        AppColors.highlight,
        AppColors.highlight,
      ];
    case 2:
      return const [
        AppColors.border,
        AppColors.textSecondary,
      ];
    case 3:
      return const [
        AppColors.warning,
        AppColors.warning,
      ];
    default:
      return const [
        AppColors.primary,
        AppColors.primary,
      ];
  }
}

String _medalEmoji(int rank) {
  switch (rank) {
    case 1:
      return '🥇';
    case 2:
      return '🥈';
    case 3:
      return '🥉';
    default:
      return '⭐';
  }
}
