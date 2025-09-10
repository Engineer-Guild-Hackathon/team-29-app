import 'package:flutter/material.dart';
import '../services/api.dart';
import 'solve_picker_screen.dart';

class SolveScreen extends StatefulWidget {
  final int? initialProblemId; // 指定された問題を解く場合に使用
  const SolveScreen({super.key, this.initialProblemId});
  @override
  State<SolveScreen> createState() => _SolveScreenState();
}

class _SolveScreenState extends State<SolveScreen> {
  // カテゴリ選択
  List<dynamic> tree = [];
  int? childId;
  int? grandId; // null = 全単元

  // 問題状態
  Map<String, dynamic>? prob;
  bool loading = false;
  bool includeAnswered = false;

  // 記述式
  final TextEditingController freeCtrl = TextEditingController();
  String? _freeUserAnswer;
  bool _freeSubmitted = false; // 「解答する」押下後
  String? _modelAnswer; // 取得できる場合のみ

  // 解説 + まとめいいね（問題単位）
  List<dynamic> explanations = [];
  bool explLiked = false;
  int explLikes = 0;

  // 選択式補助
  int? _mcqSelectedIndex;
  int? _mcqCorrectIndex;
  bool? _mcqResult;

  @override
  void initState() {
    super.initState();
    _loadTree();
  }

  Future<void> _loadTree() async {
    final t = await Api.categoryTree();
    setState(() => tree = t);
    if (t.isNotEmpty) {
      final root = t.first;
      if ((root['children'] as List?)?.isNotEmpty == true) {
        childId = root['children'][0]['id'] as int;
        grandId = null; // デフォルトは全単元
      }
    }
    if (widget.initialProblemId != null) {
      await _loadProblemById(widget.initialProblemId!);
    } else {
      await _loadProblem();
    }
  }

  Future<void> _loadProblem() async {
    if (childId == null) return;
    setState(() {
      loading = true;
      prob = null;
      explanations = [];
      freeCtrl.clear();
      _freeUserAnswer = null;
      _freeSubmitted = false;
      _modelAnswer = null;
      _mcqSelectedIndex = null;
      _mcqCorrectIndex = null;
      _mcqResult = null;
    });
    final r = await Api.nextProblem(childId!, grandId, includeAnswered: includeAnswered);
    Map<String, dynamic>? p;
    if (r['id'] != null) {
      p = r;
    } else if (r['problem'] is Map) {
      p = Map<String, dynamic>.from(r['problem']);
    }
    setState(() {
      prob = p;
      explLikes = (p != null && p['expl_like_count'] is int) ? (p!['expl_like_count'] as int) : 0;
      explLiked = (p != null && p['expl_liked'] == true);
      loading = false;
    });
  }

  Future<void> _loadProblemById(int pid) async {
    setState(() {
      loading = true;
      prob = null;
      explanations = [];
      freeCtrl.clear();
      _freeUserAnswer = null;
      _freeSubmitted = false;
      _modelAnswer = null;
      _mcqSelectedIndex = null;
      _mcqCorrectIndex = null;
      _mcqResult = null;
    });
    final p = await Api.problemDetail(pid);
    setState(() {
      prob = p;
      explLikes = (p['expl_like_count'] is int) ? (p['expl_like_count'] as int) : 0;
      explLiked = (p['expl_liked'] == true);
      loading = false;
    });
  }

  List<DropdownMenuItem<int>> _childItems() {
    if (tree.isEmpty) return [];
    final cs = (tree.first['children'] as List?) ?? [];
    return cs
        .map<DropdownMenuItem<int>>((c) => DropdownMenuItem(value: c['id'] as int, child: Text('${c['name']}')))
        .toList();
  }

  List<DropdownMenuItem<int?>> _grandItems() {
    final items = <DropdownMenuItem<int?>>[const DropdownMenuItem(value: null, child: Text('全単元（すべて）'))];
    if (tree.isEmpty || childId == null) return items;
    final cs = (tree.first['children'] as List?) ?? [];
    final ch = cs.firstWhere((e) => e['id'] == childId, orElse: () => null);
    if (ch == null) return items;
    final gs = (ch['children'] as List?) ?? [];
    items.addAll(gs.map<DropdownMenuItem<int?>>((g) => DropdownMenuItem(value: g['id'] as int, child: Text('${g['name']}'))));
    return items;
  }

  String _kanaOf(int i) {
    const k = ['ア', 'イ', 'ウ', 'エ', 'オ', 'カ', 'キ', 'ク', 'ケ', 'コ'];
    return (i >= 0 && i < k.length) ? k[i] : '選択肢${i + 1}';
  }

  Future<void> _answerMcq(int optionId) async {
    if (prob == null) return;
    final pid = prob!['id'] as int;
    final res = await Api.answer(pid, optionId: optionId);
    final opts = (prob!['options'] as List);
    setState(() {
      _mcqSelectedIndex = opts.indexWhere((o) => (o['id'] as int) == optionId);
      _mcqResult = (res['is_correct'] == true);
    });
    try {
      final pd = await Api.problemDetail(pid);
      final List pods = (pd['options'] as List? ?? []);
      final idx = pods.indexWhere((o) => (o['is_correct'] ?? false) == true);
      if (idx >= 0) setState(() => _mcqCorrectIndex = idx);
    } catch (_) {}
    final e = await Api.explanations(pid, 'likes');
    setState(() => explanations = e);
  }

  Widget _summaryLikeChip() {
    return GestureDetector(
      onTap: () async {
        if (prob == null) return;
        if (explLiked) {
          final ok = await Api.unlikeProblemExplanations(prob!['id'] as int);
          if (ok) setState(() { explLiked = false; if (explLikes > 0) explLikes -= 1; });
        } else {
          final ok = await Api.likeProblemExplanations(prob!['id'] as int);
          if (ok) setState(() { explLiked = true; explLikes += 1; });
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
    );
  }

  @override
  Widget build(BuildContext c) {
    return Scaffold(
      appBar: AppBar(title: const Text('問題をランダムに解く')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(children: [
          Row(children: [
            const Text('教科: '), const SizedBox(width: 8),
            DropdownButton<int>(value: childId, items: _childItems(), onChanged: (v) { setState(() => childId = v); _loadProblem(); }),
            const SizedBox(width: 24), const Text('単元: '), const SizedBox(width: 8),
            DropdownButton<int?>(value: grandId, items: _grandItems(), onChanged: (v) { setState(() => grandId = v); _loadProblem(); }),
            const SizedBox(width: 16),
            Row(children: [ Checkbox(value: includeAnswered, onChanged: (v) { setState(() => includeAnswered = v ?? false); _loadProblem(); }), const Text('回答済みも含める') ])
          ]),
          const Divider(),
          if (loading) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
          if (!loading && prob == null) const Text('この条件の問題はありません'),
          if (!loading && prob != null) ...[
            Row(children: [
              Expanded(child: Text(prob!['title'] ?? '', style: Theme.of(c).textTheme.titleLarge)),
              // 問題いいね
              GestureDetector(
                onTap: () async {
                  if (prob == null) return;
                  final liked = (prob!['liked'] ?? false) == true;
                  if (liked) {
                    final ok = await Api.unlikeProblem(prob!['id'] as int);
                    if (ok) setState(() { prob!['liked'] = false; prob!['like_count'] = ((prob!['like_count'] ?? 0) as int) - 1; if (prob!['like_count'] < 0) prob!['like_count'] = 0; });
                  } else {
                    final ok = await Api.likeProblem(prob!['id'] as int);
                    if (ok) setState(() { prob!['liked'] = true; prob!['like_count'] = (prob!['like_count'] ?? 0) + 1; });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: (prob!['liked'] ?? false) == true ? Colors.green : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.green, width: 1.5),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('いいね', style: TextStyle(color: (prob!['liked'] ?? false) == true ? Colors.white : Colors.green, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 6),
                    Text('${prob!['like_count'] ?? 0}', style: TextStyle(color: (prob!['liked'] ?? false) == true ? Colors.white : Colors.green, fontWeight: FontWeight.w600)),
                  ]),
                ),
              )
            ]),
            const SizedBox(height: 8),
            if ((prob!['body'] ?? '').toString().isNotEmpty) Text(prob!['body'] ?? ''),
            const SizedBox(height: 8),
            if ((prob!['images'] as List?)?.isNotEmpty == true)
              _ImagesPager(urls: List<String>.from((prob!['images'] as List).map((e) => e.toString()))),
            const Divider(),
            if (prob!['qtype'] == 'mcq') ...[
              Builder(builder: (_) {
                final List opts = (prob!['options'] as List);
                return Column(children: List.generate(opts.length, (i) {
                  final o = opts[i];
                  final text = (o['content'] ?? o['text'] ?? '').toString();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SizedBox(
                        width: 56,
                        child: OutlinedButton(
                          onPressed: () => _answerMcq(o['id'] as int),
                          child: Text(_kanaOf(i), style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(text)),
                    ]),
                  );
                }));
              }),
              if (_mcqResult != null) ...[
                const SizedBox(height: 12),
                Text(_mcqResult! ? '正解' : '不正解', style: TextStyle(color: _mcqResult! ? Colors.green : Colors.red, fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Builder(builder: (_) {
                  final sel = _mcqSelectedIndex;
                  final cor = _mcqCorrectIndex;
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (cor != null) Text('問題の解答：${_kanaOf(cor)}'),
                    if (sel != null) Text('あなたの解答：${_kanaOf(sel)}'),
                  ]);
                }),
                const SizedBox(height: 12),
                const Text('解説'),
                const SizedBox(height: 8),
                ..._groupedByUserExplanationCards(isMcq: true),
              ],
            ] else ...[
              TextField(controller: freeCtrl, minLines: 3, maxLines: 6, decoration: const InputDecoration(labelText: 'あなたの解答（自由記述）', border: OutlineInputBorder())),
            ],
            if (prob!['qtype'] == 'free') ...[
              const SizedBox(height: 8),
              FilledButton(onPressed: () async {
                if (prob == null) return; final pid = prob!['id'] as int;
                // 解説と模範解答（取得できる場合）を取得
                final e = await Api.explanations(pid, 'likes');
                String? model;
                try {
                  final pd = await Api.problemDetail(pid);
                  if (pd['model_answer'] is String && (pd['model_answer'] as String).trim().isNotEmpty) {
                    model = (pd['model_answer'] as String).trim();
                  }
                } catch (_) {}
                setState(() { _freeUserAnswer = freeCtrl.text; explanations = e; _freeSubmitted = true; _modelAnswer = model; });
              }, child: const Text('解答する')),
              if (_freeSubmitted && (_modelAnswer != null && _modelAnswer!.isNotEmpty)) ...[
                const SizedBox(height: 12),
                const Text('模範解答', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Card(child: Padding(padding: const EdgeInsets.all(12), child: Text(_modelAnswer!))),
              ],
              if (_freeSubmitted) ...[
                const SizedBox(height: 12), const Text('解説'), const SizedBox(height: 8),
                ..._groupedByUserExplanationCards(isMcq: false),
                const SizedBox(height: 12),
                Row(children: [
                  ElevatedButton(onPressed: () async {
                    if (prob == null) return; final pid = prob!['id'] as int;
                    await Api.answer(pid, freeText: _freeUserAnswer ?? freeCtrl.text, isCorrect: true);
                    if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('正解として記録しました')));
                  }, child: const Text('正解として記録')),
                  const SizedBox(width: 8),
                  ElevatedButton(onPressed: () async {
                    if (prob == null) return; final pid = prob!['id'] as int;
                    await Api.answer(pid, freeText: _freeUserAnswer ?? freeCtrl.text, isCorrect: false);
                    if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('不正解として記録しました')));
                  }, child: const Text('不正解として記録')),
                ]),
              ],
            ],
            const SizedBox(height: 24),
            if (widget.initialProblemId != null)
              OutlinedButton(
                onPressed: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SolvePickerScreen()));
                  }
                },
                child: const Text('戻る'),
              )
            else
              OutlinedButton(onPressed: _loadProblem, child: const Text('次の問題へ')),
          ],
        ]),
      ),
    );
  }

  // 解説をユーザ（by/user_id/AI）ごとにカードに分けて表示
  List<Widget> _groupedByUserExplanationCards({required bool isMcq}) {
    final Map<String, Map<String, dynamic>> groups = {};
    for (final e in explanations) {
      final isAi = e['is_ai'] == true;
      final key = isAi ? 'ai' : 'u${e['user_id']}';
      final by = isAi ? 'AI' : (e['by'] ?? 'ユーザー');
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
      if (isMcq && oi is int) {
        (g['perOpt'] as Map<int, List<String>>).putIfAbsent(oi, () => []).add(txt);
      } else {
        (g['overall'] as List<String>).add(txt);
      }
      final int likes = (e['likes'] is int) ? (e['likes'] as int) : 0;
      g['likeSum'] = (g['likeSum'] as int) + likes;
      final int? eid = (e['id'] is int) ? (e['id'] as int) : null;
      if (eid != null) {
        if (g['repId'] == null || oi == null) {
          g['repId'] = eid;
          g['repLiked'] = (e['liked'] == true);
        }
      }
    }
    final cards = <Widget>[];
    for (final g in groups.values) {
      final by = (g['by'] ?? 'ユーザー').toString();
      final perOpt = (g['perOpt'] as Map<int, List<String>>);
      final overall = (g['overall'] as List<String>);
      final children = <Widget>[];
      if (isMcq) {
        // For MCQ: show per-option lines in order. If AI group, list all options; otherwise list only those that exist.
        final List<dynamic>? opts = (prob?['options'] as List<dynamic>?);
        final bool isAiGroup = by == 'AI';
        final List<int> indices = (isAiGroup && opts != null)
            ? List<int>.generate(opts.length, (i) => i)
            : (perOpt.keys.toList()..sort());
        for (final k in indices) {
          final merged = (perOpt[k] == null || perOpt[k]!.isEmpty)
              ? ''
              : perOpt[k]!.join('\n');
          children.add(Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('${_kanaOf(k)}：$merged'),
          ));
        }
      }
      if (overall.isNotEmpty) {
        if (isMcq) {
          children.add(const SizedBox(height: 8));
          children.add(const Text('全体の解説', style: TextStyle(fontWeight: FontWeight.w600)));
          children.add(const SizedBox(height: 4));
        }
        children.add(Text(overall.join('\n')));
      }
      if (children.isEmpty) continue;
      cards.add(Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(by == 'AI' ? 'AIの解説' : '$by さんの解説', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            ...children,
            const SizedBox(height: 8),
            StatefulBuilder(builder: (context2, setCard) {
              return Align(
                alignment: Alignment.bottomRight,
                child: GestureDetector(
                  onTap: () async {
                    final int? repId = (g['repId'] as int?);
                    if (repId == null) return;
                    bool groupLiked = (g['repLiked'] == true);
                    int likeSum = (g['likeSum'] as int);
                    bool ok = false;
                    if (groupLiked) {
                      ok = await Api.unlikeExplanation(repId);
                      if (ok) setCard(() { g['repLiked'] = false; if (likeSum > 0) { g['likeSum'] = likeSum - 1; } });
                    } else {
                      ok = await Api.likeExplanation(repId);
                      if (ok) setCard(() { g['repLiked'] = true; g['likeSum'] = likeSum + 1; });
                    }
                  },
                  child: Builder(builder: (_) {
                    final bool liked = (g['repLiked'] == true);
                    final int count = (g['likeSum'] as int);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: liked ? Colors.green : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.green, width: 1.5),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text('いいね', style: TextStyle(color: liked ? Colors.white : Colors.green, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 6),
                        Text('$count', style: TextStyle(color: liked ? Colors.white : Colors.green, fontWeight: FontWeight.w600)),
                      ]),
                    );
                  }),
                ),
              );
            }),
          ]),
        ),
      ));
    }
    return cards;
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
        height: 280,
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
