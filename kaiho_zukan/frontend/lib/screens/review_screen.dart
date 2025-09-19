import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/home_section_theme.dart';
import '../services/api.dart';
import '../widgets/app_icon.dart';
import '../widgets/home_section_surface.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_breadcrumbs.dart';
import 'home.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({
    super.key,
    this.embedded = false,
    HomeSectionTheme? theme,
  }) : theme = theme ?? HomeSectionThemes.review;

  final bool embedded;
  final HomeSectionTheme theme;
  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  // Category tree
  List<dynamic> parents = [], children = [], grands = [];
  int? parentId, childId;
  int? grandId; // null = 全単元

  // Dashboard + history
  Map<String, dynamic>? stats; // {solved, correct, rate}
  List<dynamic> history = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadTree();
  }

  Future<void> _loadTree() async {
    final t = await Api.categories.tree(mineOnly: true);
    setState(() {
      parents = t;
      parentId = t.isNotEmpty ? t.first['id'] as int : null;
      children = t.isNotEmpty ? (t.first['children'] ?? []) : [];
      childId = children.isNotEmpty ? children.first['id'] as int : null;
      grands = children.isNotEmpty ? (children.first['children'] ?? []) : [];
      grandId = null; // 全単元
    });
    if (childId == null) {
      setState(() => loading = false);
      return;
    }
    await _load();
  }

  Future<void> _load() async {
    if (childId == null) return;
    setState(() => loading = true);
    final s = await Api.review.stats(childId!, grandId: grandId);
    final h = await Api.review.history(categoryId: childId!, grandId: grandId);
    setState(() {
      stats = s;
      history = (h['items'] as List<dynamic>? ?? []).toList();
      loading = false;
    });
  }

  Widget _parentDropdown({bool expanded = false}) {
    final dropdown = DropdownButton<int>(
      value: parentId,
      isExpanded: true,
      items: _parentItems(),
      onChanged: (v) {
        if (v == null) return;
        final p = parents.firstWhere((e) => e['id'] == v, orElse: () => null);
        setState(() {
          parentId = v;
          if (p != null) {
            children = p['children'] ?? [];
          }
          childId = children.isNotEmpty ? children.first['id'] as int : null;
          grands = childId != null
              ? (children.firstWhere((c) => c['id'] == childId)['children'] ??
                  [])
              : [];
          grandId = null;
        });
        _load();
      },
    );
    if (expanded) {
      return Expanded(child: dropdown);
    }
    return SizedBox(width: double.infinity, child: dropdown);
  }

  Widget _childDropdown({bool expanded = false}) {
    final dropdown = DropdownButton<int>(
      value: childId,
      isExpanded: true,
      items: _childItems(),
      onChanged: (v) {
        if (v == null) return;
        final c = children.firstWhere((e) => e['id'] == v, orElse: () => null);
        setState(() {
          childId = v;
          grands = c != null ? (c['children'] ?? []) : [];
          grandId = null;
        });
        _load();
      },
    );
    if (expanded) {
      return Expanded(child: dropdown);
    }
    return SizedBox(width: double.infinity, child: dropdown);
  }

  Widget _grandDropdown({bool expanded = false}) {
    final dropdown = DropdownButton<int?>(
      value: grandId,
      isExpanded: true,
      items: _grandItems(),
      onChanged: (v) {
        setState(() => grandId = v);
        _load();
      },
    );
    if (expanded) {
      return Expanded(child: dropdown);
    }
    return SizedBox(width: double.infinity, child: dropdown);
  }

  Widget _buildHistoryList() {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    Widget listView;
    if (history.isEmpty) {
      listView = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 32),
        children: const [
          Center(child: Text('現在の条件での履歴はありません')),
        ],
      );
    } else {
      listView = ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: history.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: AppColors.dashboard_border),
        itemBuilder: (_, i) {
          final it = history[i];
          final bool ok = (it['is_correct'] == true);
          return ListTile(
            title: Text(it['title'] ?? ''),
            subtitle: Text((it['answered_at'] ?? '').toString()),
            trailing: Icon(
              ok ? Icons.circle_outlined : Icons.close,
              color: ok ? AppColors.success : AppColors.danger,
            ),
            onTap: () => _openDetail2(it['id'] as int),
          );
        },
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: listView,
    );
  }

  List<String> _extractImageUrls(dynamic images) {
    if (images is! List) return const [];
    final urls = <String>[];
    for (final e in images) {
      String? u;
      if (e is String) {
        u = e;
      } else if (e is Map) {
        final cands = [e['url'], e['path'], e['src'], e['image']]
            .whereType<String>()
            .toList();
        if (cands.isNotEmpty) u = cands.first;
      } else {
        u = e?.toString();
      }
      if (u == null || u.isEmpty) continue;
      urls.add(u);
    }
    return urls;
  }

  List<DropdownMenuItem<int>> _parentItems() => parents
      .map<DropdownMenuItem<int>>((p) =>
          DropdownMenuItem(value: p['id'] as int, child: Text(p['name'])))
      .toList();
  List<DropdownMenuItem<int>> _childItems() => children
      .map<DropdownMenuItem<int>>((c) =>
          DropdownMenuItem(value: c['id'] as int, child: Text(c['name'])))
      .toList();
  List<DropdownMenuItem<int?>> _grandItems() {
    final items = <DropdownMenuItem<int?>>[
      const DropdownMenuItem<int?>(value: null, child: Text('全単元（すべて）'))
    ];
    items.addAll(grands.map<DropdownMenuItem<int?>>((g) =>
        DropdownMenuItem(value: g['id'] as int, child: Text(g['name']))));
    return items;
  }

  Widget _metric(String label, String value, Color color) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Text(value,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
    ]);
  }

  Widget _dashboard(HomeSectionTheme palette) {
    final solved = stats?['solved'] ?? 0;
    final correct = stats?['correct'] ?? 0;
    final rate = stats?['rate'] ?? 0;
    return HomeSectionCard(
      theme: palette,
      padding: const EdgeInsets.all(24),
      child: Row(children: [
        Expanded(child: _metric('解いた数', solved.toString(), AppColors.info)),
        Expanded(child: _metric('正解数', correct.toString(), AppColors.success)),
        Expanded(child: _metric('正答率', '$rate%', AppColors.secondary)),
      ]),
    );
  }

  String _kanaOf(int i) {
    const k = ['ア', 'イ', 'ウ', 'エ', 'オ', 'カ', 'キ', 'ク', 'ケ', 'コ'];
    return (i >= 0 && i < k.length) ? k[i] : '選択肢${i + 1}';
  }

  String _modelAnswerToKana(String text) {
    return text.replaceAllMapped(RegExp(r'\b([1-9]|10)\b'), (m) {
      final idx = int.parse(m.group(1)!) - 1;
      return _kanaOf(idx);
    });
  }

  Future<void> _openDetail2(int pid) async {
    final detail = await Api.review.item(pid);
    final Map<String, dynamic>? problem =
        detail['problem'] as Map<String, dynamic>?;
    final Map<String, dynamic>? latest =
        detail['latest_answer'] as Map<String, dynamic>?;
    final pd = await Api.problems.detail(pid);
    final List<dynamic> opts = (pd['options'] as List<dynamic>? ?? []);
    final List<dynamic> exAll = await Api.explanations.list(pid, 'likes');

    // 模範解答（AI/ユーザー）一覧を取得
    List<dynamic> mas = [];
    try {
      mas = await Api.modelAnswers.list(pid);
    } catch (_) {}
    final Map<int, String> maByUser = {
      for (final it in mas)
        if ((it is Map) && (it['user_id'] is int) && (it['content'] is String))
          it['user_id'] as int:
              _modelAnswerToKana((it['content'] as String).toString())
    };
    final String? aiModelAnswer = (() {
      for (final it in mas) {
        final uid = it is Map ? it['user_id'] : null;
        final c = it is Map ? it['content'] : null;
        final isAi = (it is Map && (it['is_ai'] == true)) || uid == null;
        if (isAi && c is String && c.trim().isNotEmpty) {
          return _modelAnswerToKana(c.trim());
        }
      }
      return null;
    })();

    // 解説を著者ごとにまとめる（MCQ は選択肢ごと + 全体）
    final Map<String, Map<String, dynamic>> groups = {};
    for (final e in exAll) {
      final bool isAi = e['is_ai'] == true;
      final String key = isAi ? 'ai' : 'u${e['user_id']}';
      final String by = isAi ? 'AI' : (e['by'] ?? 'ユーザー').toString();
      final g = groups.putIfAbsent(
          key,
          () => {
                'by': by,
                'uid': isAi ? null : (e['user_id'] as int?),
                'perOpt': <int, List<String>>{},
                'overall': <String>[],
                'repId': null,
                'likeSum': 0,
                'repLiked': false,
                'images': <String>{},
                'aiWrong': false,
                'repWrongFlagged': false,
              });
      final txt = (e['content'] ?? '').toString();
      final oi = e['option_index'];
      if (oi is int) {
        (g['perOpt'] as Map<int, List<String>>)
            .putIfAbsent(oi, () => [])
            .add(txt);
      } else {
        (g['overall'] as List<String>).add(txt);
      }
      if (e['ai_is_wrong'] == true ||
          (e is Map && e['crowd_maybe_wrong'] == true)) {
        g['aiWrong'] = true;
      }
      final eid = (e['id'] is int) ? e['id'] as int : null;
      if (eid != null) {
        if (g['repId'] == null || oi == null) {
          g['repId'] = eid;
          g['repLiked'] = (e['liked'] == true);
          g['repWrongFlagged'] = (e['flagged_wrong'] == true);
        }
      }
      final urls = _extractImageUrls(e['images']);
      (g['images'] as Set<String>).addAll(urls);
      final lc = (e['likes'] is int) ? e['likes'] as int : 0;
      g['likeSum'] = (g['likeSum'] as int) + lc;
    }
    final List<Map<String, dynamic>> groupList = groups.values.toList();
    // フィルタ済み（著者単位で「間違っているかも」のグループを除外）
    final List<Map<String, dynamic>> groupListAll = groupList;
    final List<Map<String, dynamic>> groupListFiltered =
        groupList.where((g) => (g['aiWrong'] == true) == false).toList();

    if (!mounted) return;
    int problemLikes = (pd['like_count'] is int)
        ? (pd['like_count'] as int)
        : ((problem?['like_count'] ?? 0) as int);
    bool problemLiked = (pd['liked'] == true) || (problem?['liked'] == true);

    await showDialog(
      context: context,
      builder: (c) {
        bool showMaybeWrong = false; // keep state across setStateDlg rebuilds
        return StatefulBuilder(builder: (c, setStateDlg) {
          return AlertDialog(
            title: Row(
              children: [
                Expanded(child: Text(problem?['title'] ?? '問題詳細')),
                GestureDetector(
                  onTap: () async {
                    if (problemLiked) {
                      final ok = await Api.problems.unlike(pid);
                      if (ok) {
                        setStateDlg(() {
                          problemLiked = false;
                          problemLikes =
                              (problemLikes > 0) ? (problemLikes - 1) : 0;
                        });
                      }
                    } else {
                      final ok = await Api.problems.like(pid);
                      if (ok) {
                        setStateDlg(() {
                          problemLiked = true;
                          problemLikes += 1;
                        });
                      }
                    }
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: problemLiked
                          ? AppColors.success
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.success, width: 1.5),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('いいね',
                          style: TextStyle(
                              color: problemLiked
                                  ? AppColors.background
                                  : AppColors.success,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 6),
                      Text('$problemLikes',
                          style: TextStyle(
                              color: problemLiked
                                  ? AppColors.background
                                  : AppColors.success,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 700,
              child: SingleChildScrollView(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if ((problem?['body'] ?? '').toString().isNotEmpty)
                        Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(problem!['body'])),
                      if ((pd['images'] as List?)?.isNotEmpty == true) ...[
                        const SizedBox(height: 8),
                        _ImagesPager(
                            urls: List<String>.from((pd['images'] as List)
                                .map((e) => e.toString()))),
                      ],
                      const Divider(),

                      Builder(builder: (_) {
                        final widgets = <Widget>[];

                        if ((problem?['qtype']) == 'mcq') {
                          int? selIdx;
                          final selId = latest?['selected_option_id'];
                          if (selId is int) {
                            final idx =
                                opts.indexWhere((o) => (o['id'] == selId));
                            if (idx >= 0) selIdx = idx;
                          }

                          widgets.add(const Text('あなたの解答',
                              style: TextStyle(fontWeight: FontWeight.w600)));
                          widgets.add(const SizedBox(height: 6));

                          if (selIdx != null) {
                            // ★ ここを widgets に追加する
                            widgets.add(Text(_kanaOf(selIdx)));
                          } else {
                            widgets.add(const Text('（未回答）',
                                style:
                                    TextStyle(color: AppColors.textSecondary)));
                          }
                        } else {
                          // 記述式
                          final mine =
                              (latest?['free_text'] ?? '').toString().trim();

                          widgets.add(const Text('あなたの解答',
                              style: TextStyle(fontWeight: FontWeight.w600)));
                          widgets.add(const SizedBox(height: 6));

                          if (mine.isNotEmpty) {
                            // ★ ここを widgets に追加する
                            widgets.add(
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text(mine),
                                ),
                              ),
                            );
                          } else {
                            widgets.add(const Text('（未回答）',
                                style:
                                    TextStyle(color: AppColors.textSecondary)));
                          }
                        }

                        if (widgets.isEmpty) return const SizedBox.shrink();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ...widgets,
                            const SizedBox(height: 12),
                            const Divider(),
                          ],
                        );
                      }),

                      // 見出し
                      const Text('解説'),
                      // トグル（全幅で押しやすく）
                      CheckboxListTile(
                        value: showMaybeWrong,
                        onChanged: (v) =>
                            setStateDlg(() => showMaybeWrong = (v ?? false)),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text('間違っているかもしれない解説も表示'),
                      ),

                      // ★ 解説カード（各著者ごと）：上に「〇〇の解答 → 解答」→ その下に「〇〇の解説」
                      ...((showMaybeWrong ? groupListAll : groupListFiltered))
                          .map((g) {
                        final by = (g['by'] ?? 'ユーザー').toString();
                        final int? uid = g['uid'] as int?;
                        final Map<int, List<String>> perOpt =
                            (g['perOpt'] as Map<int, List<String>>);
                        final List<String> overall =
                            (g['overall'] as List<String>);

                        // その著者の解答テキスト
                        String answerText = '';
                        if (by == 'AI') {
                          answerText = (aiModelAnswer ?? '').trim();
                        } else {
                          if (uid != null && maByUser.containsKey(uid)) {
                            answerText = (maByUser[uid] ?? '').trim();
                          }
                        }
                        if (answerText.isNotEmpty) {
                          answerText = _modelAnswerToKana(answerText);
                        }

                        // 解説本文
                        final explanationWidgets = <Widget>[];
                        if ((problem?['qtype']) == 'mcq') {
                          final keys = perOpt.keys.toList()..sort();
                          for (final k in keys) {
                            explanationWidgets.add(
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                    '${_kanaOf(k)}：${perOpt[k]!.join('\n')}'),
                              ),
                            );
                          }
                          if (overall.isNotEmpty) {
                            explanationWidgets.add(const SizedBox(height: 8));
                            explanationWidgets.add(const Text('全体の解説',
                                style: TextStyle(fontWeight: FontWeight.w600)));
                            explanationWidgets.add(const SizedBox(height: 4));
                            explanationWidgets.add(Text(overall.join('\n')));
                          }
                        } else {
                          if (overall.isNotEmpty) {
                            explanationWidgets.add(Text(overall.join('\n')));
                          }
                        }

                        // いいね系
                        int likeSum = (g['likeSum'] as int);
                        final int? repId = (g['repId'] as int?);
                        bool groupLiked = (g['repLiked'] == true);

                        if (explanationWidgets.isEmpty) {
                          // 解説が空ならカードを出さない
                          return const SizedBox.shrink();
                        }

                        return StatefulBuilder(builder: (context2, setCard) {
                          final children = <Widget>[];

                          if (answerText.isNotEmpty) {
                            children.add(Text(
                                by == 'AI' ? 'AIの解答' : '$by さんの解答',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)));
                            children.add(const SizedBox(height: 4));
                            children.add(Text(answerText));
                            children.add(const SizedBox(height: 8));
                          }

                          children.add(Text(by == 'AI' ? 'AIの解説' : '$by さんの解説',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)));
                          children.add(const SizedBox(height: 6));
                          children.addAll(explanationWidgets);
                          final imgs = (g['images'] as Set<String>).toList();
                          if (imgs.isNotEmpty) {
                            children.add(const SizedBox(height: 8));
                            children.add(_ImagesPager(
                                urls: imgs)); // _ImagesPager は既存のものを再利用
                          }
                          children.add(const SizedBox(height: 8));

                          children.add(
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // ▼ 左：AI 警告チップ（g['aiWrong'] が true のときだけ表示）
                                if (g['aiWrong'] == true)
                                  Tooltip(
                                    message: 'この解説はAIによって間違っていると判定されました',
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(24),
                                        border: Border.all(
                                            color: AppColors.secondary,
                                            width: 1.2),
                                        color: AppColors.background,
                                      ),
                                      child: const Text(
                                        'この解説は間違っているかもしれません',
                                        style: TextStyle(
                                          color: AppColors.secondary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  const SizedBox.shrink(),

                                // ▼ 右：？（wrong-flag）トグル + いいね
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // ？ wrong-flag トグル
                                    Tooltip(
                                      message: 'この解説が間違っていると思ったらこのボタンを押して下さい',
                                      child: GestureDetector(
                                        onTap: () async {
                                          final int? repId =
                                              (g['repId'] as int?);
                                          if (repId == null) return;
                                          final bool flagged =
                                              (g['repWrongFlagged'] == true);
                                          bool ok = false;
                                          if (flagged) {
                                            ok = await Api.explanations.unflagWrong(
                                                repId); // DELETE /explanations/{id}/wrong-flags
                                            if (ok)
                                              setCard(() =>
                                                  g['repWrongFlagged'] = false);
                                          } else {
                                            ok = await Api.explanations.flagWrong(
                                                repId); // POST   /explanations/{id}/wrong-flags
                                            if (ok)
                                              setCard(() =>
                                                  g['repWrongFlagged'] = true);
                                          }
                                        },
                                        child: Builder(builder: (_) {
                                          final bool flagged =
                                              (g['repWrongFlagged'] == true);
                                          return Container(
                                            width: 32,
                                            height: 32,
                                            margin:
                                                const EdgeInsets.only(right: 8),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: flagged
                                                  ? AppColors.textSecondary
                                                  : AppColors.background,
                                              border: Border.all(
                                                  color:
                                                      AppColors.textSecondary,
                                                  width: 1.5),
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              '?',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w800,
                                                color: flagged
                                                    ? AppColors.background
                                                    : AppColors.textSecondary,
                                              ),
                                            ),
                                          );
                                        }),
                                      ),
                                    ),

                                    // いいね（既存処理そのまま）
                                    GestureDetector(
                                      onTap: () async {
                                        if (repId == null) return;
                                        if (groupLiked) {
                                          final ok = await Api.explanations
                                              .unlike(repId);
                                          if (ok) {
                                            setCard(() {
                                              groupLiked = false;
                                              if (likeSum > 0) likeSum -= 1;
                                            });
                                          }
                                        } else {
                                          final ok = await Api.explanations
                                              .like(repId);
                                          if (ok) {
                                            setCard(() {
                                              groupLiked = true;
                                              likeSum += 1;
                                            });
                                          }
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: groupLiked
                                              ? AppColors.success
                                              : AppColors.background,
                                          borderRadius:
                                              BorderRadius.circular(24),
                                          border: Border.all(
                                              color: AppColors.success,
                                              width: 1.5),
                                        ),
                                        child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text('いいね',
                                                  style: TextStyle(
                                                      color: groupLiked
                                                          ? AppColors.background
                                                          : AppColors.success,
                                                      fontWeight:
                                                          FontWeight.w600)),
                                              const SizedBox(width: 6),
                                              Text('$likeSum',
                                                  style: TextStyle(
                                                      color: groupLiked
                                                          ? AppColors.background
                                                          : AppColors.success,
                                                      fontWeight:
                                                          FontWeight.w600)),
                                            ]),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );

                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: children),
                            ),
                          );
                        });
                      }).toList(),
                    ]),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(c), child: const Text('閉じる'))
            ],
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.theme;

    final filtersCard = HomeSectionCard(
      theme: palette,
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 720;

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _parentDropdown(),
                const SizedBox(height: 12),
                _childDropdown(),
                const SizedBox(height: 12),
                _grandDropdown(),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: '最新のデータを取得',
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                  ),
                ),
              ],
            );
          }

          return Row(
            children: [
              _parentDropdown(expanded: true),
              const SizedBox(width: 12),
              _childDropdown(expanded: true),
              const SizedBox(width: 12),
              _grandDropdown(expanded: true),
              const Spacer(),
              IconButton(
                tooltip: '最新のデータを取得',
                onPressed: _load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          );
        },
      ),
    );

    final children = <Widget>[
      filtersCard,
      const SizedBox(height: 16),
      if (!loading && stats != null) ...[
        _dashboard(palette),
        const SizedBox(height: 16),
      ],
      Expanded(
        child: HomeSectionCard(
          theme: palette,
          padding: EdgeInsets.zero,
          child: _buildHistoryList(),
        ),
      ),
    ];

    final section = HomeSectionSurface(
      theme: palette,
      maxContentWidth: 960,
      expandChild: true,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );

    if (widget.embedded) {
      return section;
    }

    return AppScaffold(
      title: '振り返り',
      subHeader: AppBreadcrumbs(
        items: [
          BreadcrumbItem(
            label: 'ホーム',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            ),
          ),
          const BreadcrumbItem(label: '振り返り'),
        ],
      ),
      backgroundColor: palette.background,
      body: section,
    );
  }
}

class _ImagesPager extends StatefulWidget {
  final List<String> urls;
  const _ImagesPager({super.key, required this.urls});
  @override
  State<_ImagesPager> createState() => _ImagesPagerState();
}

class _ImagesPagerState extends State<_ImagesPager> {
  final PageController _pc = PageController();
  int _index = 0;
  @override
  Widget build(BuildContext context) {
    if (widget.urls.isEmpty) return const SizedBox.shrink();
    return Column(children: [
      SizedBox(
        height: 260,
        width: double.infinity,
        child: PageView.builder(
          controller: _pc,
          onPageChanged: (i) => setState(() => _index = i),
          itemCount: widget.urls.length,
          itemBuilder: (_, i) {
            final u = widget.urls[i];
            final url = u.startsWith('http') ? u : Api.base + u;
            return Container(
              color: AppColors.surface,
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(url, fit: BoxFit.contain),
                ),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(widget.urls.length, (i) {
          final sel = i == _index;
          return GestureDetector(
            onTap: () => _pc.animateToPage(i,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut),
            child: Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: sel ? AppColors.info : AppColors.border),
            ),
          );
        }),
      ),
    ]);
  }
}
