import 'package:flutter/material.dart';
import '../services/api.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});
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
    final t = await Api.categoryTree();
    setState(() {
      parents = t;
      parentId = t.isNotEmpty ? t.first['id'] as int : null;
      children = t.isNotEmpty ? (t.first['children'] ?? []) : [];
      childId = children.isNotEmpty ? children.first['id'] as int : null;
      grands = children.isNotEmpty ? (children.first['children'] ?? []) : [];
      grandId = null; // 全単元
    });
    await _load();
  }

  Future<void> _load() async {
    if (childId == null) return;
    setState(() => loading = true);
    final s = await Api.reviewStats(childId!, grandId: grandId);
    final h = await Api.reviewHistory(categoryId: childId!, grandId: grandId);
    setState(() {
      stats = s;
      history = (h['items'] as List<dynamic>? ?? []).toList();
      loading = false;
    });
  }

  List<DropdownMenuItem<int>> _parentItems() => parents
      .map<DropdownMenuItem<int>>(
          (p) => DropdownMenuItem(value: p['id'] as int, child: Text(p['name'])))
      .toList();
  List<DropdownMenuItem<int>> _childItems() => children
      .map<DropdownMenuItem<int>>(
          (c) => DropdownMenuItem(value: c['id'] as int, child: Text(c['name'])))
      .toList();
  List<DropdownMenuItem<int?>> _grandItems() {
    final items = <DropdownMenuItem<int?>>[
      const DropdownMenuItem<int?>(value: null, child: Text('全単元（すべて）'))
    ];
    items.addAll(grands.map<DropdownMenuItem<int?>>(
        (g) => DropdownMenuItem(value: g['id'] as int, child: Text(g['name']))));
    return items;
  }

  Widget _metric(String label, String value, Color color) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
    ]);
  }

  Widget _dashboard() {
    final solved = stats?['solved'] ?? 0;
    final correct = stats?['correct'] ?? 0;
    final rate = stats?['rate'] ?? 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Expanded(child: _metric('解答数', solved.toString(), Colors.blue)),
          Expanded(child: _metric('正解数', correct.toString(), Colors.green)),
          Expanded(child: _metric('正答率', '$rate%', Colors.deepPurple)),
        ]),
      ),
    );
  }

  String _kanaOf(int i) {
    const k = ['ア', 'イ', 'ウ', 'エ', 'オ', 'カ', 'キ', 'ク', 'ケ', 'コ'];
    return (i >= 0 && i < k.length) ? k[i] : '選択肢${i + 1}';
  }

  Future<void> _openDetail(int pid) async {
    final detail = await Api.reviewItem(pid);
    final Map<String, dynamic>? problem = detail['problem'] as Map<String, dynamic>?;
    final Map<String, dynamic>? latest = detail['latest_answer'] as Map<String, dynamic>?;
    final pd = await Api.problemDetail(pid);
    final List<dynamic> opts = (pd['options'] as List<dynamic>? ?? []);
    final List<dynamic> exAll = await Api.explanations(pid, 'likes');

    // Group explanations by author (user or AI). For MCQ, keep per-option lists.
    final Map<String, Map<String, dynamic>> groups = {};
    for (final e in exAll) {
      final bool isAi = e['is_ai'] == true;
      final String key = isAi ? 'ai' : 'u${e['user_id']}';
      final String by = isAi ? 'AI' : (e['by'] ?? 'ユーザー').toString();
      final g = groups.putIfAbsent(key, () => {
            'by': by,
            'perOpt': <int, List<String>>{},
            'overall': <String>[],
            'repId': null,
            'likeSum': 0,
            'repLiked': false,
          });
      final txt = (e['content'] ?? '').toString();
      final oi = e['option_index'];
      if (oi is int) {
        (g['perOpt'] as Map<int, List<String>>).putIfAbsent(oi, () => []).add(txt);
      } else {
        (g['overall'] as List<String>).add(txt);
      }
      final eid = (e['id'] is int) ? e['id'] as int : null;
      if (eid != null) {
        if (g['repId'] == null || oi == null) { g['repId'] = eid; g['repLiked'] = (e['liked'] == true); }
      }
      final lc = (e['likes'] is int) ? e['likes'] as int : 0;
      g['likeSum'] = (g['likeSum'] as int) + lc;
    }
    final List<Map<String, dynamic>> groupList = groups.values.toList();

    // Group by author (user or AI), and split per-option / overall
    // order by likes not provided per group; we keep incoming order

    if (!mounted) return;
    int explLikes = (pd['expl_like_count'] is int) ? (pd['expl_like_count'] as int) : 0;
    bool explLiked = (pd['expl_liked'] == true);

    await showDialog(
      context: context,
      builder: (c) {
        return StatefulBuilder(builder: (c, setStateDlg) {
          return AlertDialog(
            title: Text(problem?['title'] ?? '問題詳細'),
            content: SizedBox(
              width: 700,
              child: SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if ((problem?['body'] ?? '').toString().isNotEmpty)
                    Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(problem!['body'])),
                  if ((pd['images'] as List?)?.isNotEmpty == true) ...[
                    const SizedBox(height: 8),
                    _ImagesPager(urls: List<String>.from((pd['images'] as List).map((e) => e.toString()))),
                  ],
                  const Divider(),
                  // 正解/模範解答の表示
                  if ((problem?['qtype']) == 'mcq') ...[
                    Builder(builder: (_) {
                      final cor = opts.indexWhere((o) => (o['is_correct'] ?? false) == true);
                      return cor >= 0
                          ? Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('問題の解答：${_kanaOf(cor)}'))
                          : const SizedBox.shrink();
                    }),
                  ] else ...[
                    if ((pd['model_answer'] is String) && (pd['model_answer'] as String).trim().isNotEmpty)
                      Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('模範解答：${(pd['model_answer'] as String).trim()}')),
                  ],
                  const Text('あなたの解答', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text((problem?['qtype']) == 'mcq'
                      ? (() {
                          final selId = latest?['selected_option_id'];
                          if (selId == null) return '(未入力)';
                          final idx = opts.indexWhere((o) => o['id'] == selId);
                          return idx >= 0 ? _kanaOf(idx) : '選択肢?';
                        })()
                      : ((latest?['free_text'] ?? '').toString().isEmpty ? '(未入力)' : latest!['free_text'].toString())),
                  const Divider(),
                  const Text('解説（まとめ）', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Row(children: [
                    GestureDetector(
                      onTap: () async {
                        if (explLiked) {
                          final ok = await Api.unlikeProblemExplanations(pid);
                          if (ok) setStateDlg(() {
                            explLiked = false;
                            if (explLikes > 0) explLikes -= 1;
                          });
                        } else {
                          final ok = await Api.likeProblemExplanations(pid);
                          if (ok) setStateDlg(() {
                            explLiked = true;
                            explLikes += 1;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: explLiked ? Colors.green : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.green, width: 1.5),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text('いいね', style: TextStyle(color: explLiked ? Colors.white : Colors.green, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 6),
                          Text('$explLikes', style: TextStyle(color: explLiked ? Colors.white : Colors.green, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  ...groups.values.map((g) {
                    final by = (g['by'] ?? 'ユーザー').toString();
                    final perOpt = (g['perOpt'] as Map<int, List<String>>);
                    final overall = (g['overall'] as List<String>);
                    final kids = <Widget>[];
                    if ((problem?['qtype']) == 'mcq') {
                      final keys = perOpt.keys.toList()..sort();
                      for (final k in keys) {
                        kids.add(Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('${_kanaOf(k)}：${perOpt[k]!.join('\n')}'),
                        ));
                      }
                    }
                    if (overall.isNotEmpty) {
                      if ((problem?['qtype']) == 'mcq') {
                        kids.add(const SizedBox(height: 6));
                        kids.add(const Text('全体の解説')); // 通常テキスト
                        kids.add(const SizedBox(height: 2));
                      }
                      kids.add(Text(overall.join('\n')));
                    }
                    if (kids.isEmpty) return const SizedBox.shrink();
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(by == 'AI' ? 'AIの解答' : '$by さんの解答', style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          ...kids,
                        ]),
                      ),
                    );
                  }),
                ]),
              ),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('閉じる'))],
          );
        });
      },
    );
  }

  Future<void> _openDetail2(int pid) async {
    final detail = await Api.reviewItem(pid);
    final Map<String, dynamic>? problem = detail['problem'] as Map<String, dynamic>?;
    final Map<String, dynamic>? latest = detail['latest_answer'] as Map<String, dynamic>?;
    final pd = await Api.problemDetail(pid);
    final List<dynamic> opts = (pd['options'] as List<dynamic>? ?? []);
    final List<dynamic> exAll = await Api.explanations(pid, 'likes');

    // Group explanations by author (user or AI). For MCQ, keep per-option lists.
    final Map<String, Map<String, dynamic>> groups = {};
    for (final e in exAll) {
      final bool isAi = e['is_ai'] == true;
      final String key = isAi ? 'ai' : 'u${e['user_id']}';
      final String by = isAi ? 'AI' : (e['by'] ?? 'ユーザー').toString();
      final g = groups.putIfAbsent(key, () => {
            'by': by,
            'perOpt': <int, List<String>>{},
            'overall': <String>[],
            'repId': null,
            'likeSum': 0,
            'repLiked': false,
          });
      final txt = (e['content'] ?? '').toString();
      final oi = e['option_index'];
      if (oi is int) {
        (g['perOpt'] as Map<int, List<String>>).putIfAbsent(oi, () => []).add(txt);
      } else {
        (g['overall'] as List<String>).add(txt);
      }
      final eid = (e['id'] is int) ? e['id'] as int : null;
      if (eid != null) {
        if (g['repId'] == null || oi == null) { g['repId'] = eid; g['repLiked'] = (e['liked'] == true); }
      }
      final lc = (e['likes'] is int) ? e['likes'] as int : 0;
      g['likeSum'] = (g['likeSum'] as int) + lc;
    }
    final List<Map<String, dynamic>> groupList = groups.values.toList();

    if (!mounted) return;
    int problemLikes = (pd['like_count'] is int)
        ? (pd['like_count'] as int)
        : ((problem?['like_count'] ?? 0) as int);
    bool problemLiked = (pd['liked'] == true) || (problem?['liked'] == true);
    final Set<int> likedOnce = {};

    await showDialog(
      context: context,
      builder: (c) {
        return StatefulBuilder(builder: (c, setStateDlg) {
          return AlertDialog(
            title: Row(
              children: [
                Expanded(child: Text(problem?['title'] ?? '問題詳細')),
                GestureDetector(
                  onTap: () async {
                    if (problemLiked) {
                      final ok = await Api.unlikeProblem(pid);
                      if (ok) {
                        setStateDlg(() {
                          problemLiked = false;
                          problemLikes = (problemLikes > 0) ? (problemLikes - 1) : 0;
                        });
                      }
                    } else {
                      final ok = await Api.likeProblem(pid);
                      if (ok) {
                        setStateDlg(() {
                          problemLiked = true;
                          problemLikes += 1;
                        });
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: problemLiked ? Colors.green : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.green, width: 1.5),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('いいね', style: TextStyle(color: problemLiked ? Colors.white : Colors.green, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 6),
                      Text('$problemLikes', style: TextStyle(color: problemLiked ? Colors.white : Colors.green, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 700,
              child: SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if ((problem?['body'] ?? '').toString().isNotEmpty)
                    Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(problem!['body'])),
                  if ((pd['images'] as List?)?.isNotEmpty == true) ...[
                    const SizedBox(height: 8),
                    _ImagesPager(urls: List<String>.from((pd['images'] as List).map((e) => e.toString()))),
                  ],
                  const Divider(),
                  if ((problem?['qtype']) == 'mcq') ...[
                    Builder(builder: (_) {
                      final cor = opts.indexWhere((o) => (o['is_correct'] ?? false) == true);
                      if (cor < 0) return const SizedBox.shrink();
                      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('問題の解答', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(_kanaOf(cor)),
                        const Divider(),
                      ]);
                    }),
                  ] else ...[
                    if ((pd['model_answer'] is String) && (pd['model_answer'] as String).trim().isNotEmpty)
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('模範解答', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text((pd['model_answer'] as String).trim()),
                        const Divider(),
                      ]),
                  ],
                  const Text('あなたの解答', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text((problem?['qtype']) == 'mcq'
                      ? (() {
                          final selId = latest?['selected_option_id'];
                          if (selId == null) return '(未入力)';
                          final idx = opts.indexWhere((o) => o['id'] == selId);
                          return idx >= 0 ? _kanaOf(idx) : '選択肢?';
                        })()
                      : ((latest?['free_text'] ?? '').toString().isEmpty ? '(未入力)' : latest!['free_text'].toString())),
                  const Divider(),
                  const Text('解説', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  ...(const <dynamic>[]).map((e) {
                    final isAi = e['is_ai'] == true;
                    final by = isAi ? 'AI' : (e['by'] ?? 'ユーザー');
                    final content = (e['content'] ?? '').toString();
                    final eid = (e['id'] is int) ? e['id'] as int : null;
                    int likeCount = (e['likes'] is int) ? (e['likes'] as int) : 0;
                    final oi = e['option_index'];
                    return StatefulBuilder(builder: (context2, setCard) {
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(by == 'AI' ? 'AIの解説' : '$by さんの解説', style: const TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            if ((problem?['qtype']) == 'mcq' && oi is int) ...[
                              Text('${_kanaOf(oi)} の解説', style: const TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                            ],
                            Text(content),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.bottomRight,
                              child: GestureDetector(
                                onTap: () async {
                                  if (eid == null) return;
                                  if (likedOnce.contains(eid)) return;
                                  final ok = await Api.likeExplanation(eid);
                                  if (ok) {
                                    setStateDlg(() {});
                                    setCard(() {
                                      likedOnce.add(eid);
                                      likeCount += 1;
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: (eid != null && likedOnce.contains(eid)) ? Colors.green : Colors.white,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: Colors.green, width: 1.5),
                                  ),
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    Text('いいね', style: TextStyle(color: (eid != null && likedOnce.contains(eid)) ? Colors.white : Colors.green, fontWeight: FontWeight.w600)),
                                    const SizedBox(width: 6),
                                    Text('$likeCount', style: TextStyle(color: (eid != null && likedOnce.contains(eid)) ? Colors.white : Colors.green, fontWeight: FontWeight.w600)),
                                  ]),
                                ),
                              ),
                            ),
                          ]),
                        ),
                      );
                    });
                  }).toList(),
                  ...groupList.map((g) {
                    final by = (g['by'] ?? 'ユーザー').toString();
                    final Map<int, List<String>> perOpt = (g['perOpt'] as Map<int, List<String>>);
                    final List<String> overall = (g['overall'] as List<String>);
                    int likeSum = (g['likeSum'] as int);
                    final int? repId = (g['repId'] as int?);
                    bool groupLiked = (g['repLiked'] == true);
                    return StatefulBuilder(builder: (context2, setCard) {
                      final kids = <Widget>[];
                      if ((problem?['qtype']) == 'mcq') {
                        final keys = perOpt.keys.toList()..sort();
                        for (final k in keys) {
                          final merged = perOpt[k]!.join('\n');
                          kids.add(Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text('${_kanaOf(k)}:\n$merged'),
                          ));
                        }
                        if (overall.isNotEmpty) {
                          kids.add(const SizedBox(height: 8));
                          kids.add(const Text('全体の解説', style: TextStyle(fontWeight: FontWeight.w600)));
                          kids.add(const SizedBox(height: 4));
                          kids.add(Text(overall.join('\n')));
                        }
                      } else {
                        if (overall.isNotEmpty) kids.add(Text(overall.join('\n')));
                      }
                      if (kids.isEmpty) return const SizedBox.shrink();
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(by == 'AI' ? 'AIの解説' : '$by さんの解説', style: const TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            ...kids,
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.bottomRight,
                              child: GestureDetector(
                                onTap: () async {
                                  if (repId == null) return;
                                  if (groupLiked) {
                                    final ok = await Api.unlikeExplanation(repId);
                                    if (ok) setCard(() { groupLiked = false; if (likeSum > 0) likeSum -= 1; });
                                  } else {
                                    final ok = await Api.likeExplanation(repId);
                                    if (ok) setCard(() { groupLiked = true; likeSum += 1; });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: groupLiked ? Colors.green : Colors.white,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: Colors.green, width: 1.5),
                                  ),
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    Text('いいね', style: TextStyle(color: groupLiked ? Colors.white : Colors.green, fontWeight: FontWeight.w600)),
                                    const SizedBox(width: 6),
                                    Text('$likeSum', style: TextStyle(color: groupLiked ? Colors.white : Colors.green, fontWeight: FontWeight.w600)),
                                  ]),
                                ),
                              ),
                            ),
                          ]),
                        ),
                      );
                    });
                  }).toList(),
                ]),
              ),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('閉じる'))],
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('振り返り')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            DropdownButton<int>(value: parentId, items: _parentItems(), onChanged: (v) {
              final p = parents.firstWhere((e) => e['id'] == v);
              setState(() {
                parentId = v;
                children = p['children'] ?? [];
                childId = children.isNotEmpty ? children.first['id'] as int : null;
                grands = childId != null ? (children.firstWhere((c) => c['id'] == childId)['children'] ?? []) : [];
                grandId = null;
              });
              _load();
            }),
            const SizedBox(width: 8),
            DropdownButton<int>(value: childId, items: _childItems(), onChanged: (v) {
              final c = children.firstWhere((e) => e['id'] == v);
              setState(() {
                childId = v;
                grands = c['children'] ?? [];
                grandId = null;
              });
              _load();
            }),
            const SizedBox(width: 8),
            DropdownButton<int?>(value: grandId, items: _grandItems(), onChanged: (v) {
              setState(() => grandId = v);
              _load();
            }),
            const Spacer(),
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh))
          ]),
          const SizedBox(height: 12),
          if (loading) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
          if (!loading && stats != null) _dashboard(),
          const SizedBox(height: 8),
          Expanded(
            child: loading
                ? const SizedBox.shrink()
                : (history.isEmpty
                    ? const Center(child: Text('この条件での解答履歴はありません'))
                    : ListView.separated(
                        itemCount: history.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final it = history[i];
                          final bool ok = (it['is_correct'] == true);
                          return ListTile(
                            title: Text(it['title'] ?? ''),
                            subtitle: Text((it['answered_at'] ?? '').toString()),
                            trailing: Icon(ok ? Icons.circle_outlined : Icons.close, color: ok ? Colors.green : Colors.red),
                            onTap: () => _openDetail2(it['id'] as int),
                          );
                        },
                      )),
          ),
        ]),
      ),
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
              color: Colors.black12,
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
            onTap: () => _pc.animateToPage(i, duration: const Duration(milliseconds: 200), curve: Curves.easeOut),
            child: Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(shape: BoxShape.circle, color: sel ? Colors.teal : Colors.grey.shade400),
            ),
          );
        }),
      ),
    ]);
  }
}
