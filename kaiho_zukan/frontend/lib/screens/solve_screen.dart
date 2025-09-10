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

  // 解説 + まとめいいね（問題単位）
  List<dynamic> explanations = [];
  bool explLiked = false;
  int explLikes = 0;

  // 解答（模範解答）表示用
  final Map<int, String> _modelAnswersByUser = {}; // user_id -> model answer
  String? _aiModelAnswer;

  // 選択式補助
  int? _mcqSelectedIndex; // 直近にユーザーが選んだ選択肢の index

  @override
  void initState() {
    super.initState();
    _loadTree();
  }

  // ===== Helpers =====

  // options 配列を複数の候補キーから安全に取得（なければ空配列）
  List<dynamic> _optionsOf(Map<String, dynamic>? p) {
    if (p == null) return const [];
    final candidates = [
      p['options'],
      p['choices'],
      p['option_items'],
      (p['problem'] is Map) ? (p['problem'] as Map)['options'] : null,
    ];
    for (final cand in candidates) {
      if (cand is List) return cand;
    }
    return const [];
  }

  // 画像URLを安全に抽出（String / Map 混在可）
  List<String> _extractImageUrls(dynamic images, {String base = ''}) {
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
      urls.add(u.startsWith('http') ? u : (base.isNotEmpty ? base + u : u));
    }
    return urls;
  }

  String _kanaOf(int i) {
    const k = ['ア', 'イ', 'ウ', 'エ', 'オ', 'カ', 'キ', 'ク', 'ケ', 'コ'];
    return (i >= 0 && i < k.length) ? k[i] : '選択肢${i + 1}';
  }

  // 「あなたの解答」セクション（MCQ 選択後/記述式送信後に表示）
  Widget _yourAnswerSection({required bool isMcq}) {
    if (prob == null) return const SizedBox.shrink();

    if (isMcq && _mcqSelectedIndex != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('あなたの解答', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(_kanaOf(_mcqSelectedIndex!)),
          const SizedBox(height: 12),
          const Divider(),
        ],
      );
    }

    if (!isMcq && _freeSubmitted) {
      final mine = (_freeUserAnswer ?? freeCtrl.text).trim();
      if (mine.isNotEmpty) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('あなたの解答', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(mine),
              ),
            ),
            const SizedBox(height: 12),
            const Divider(),
          ],
        );
      }
    }
    return const SizedBox.shrink();
  }

  // ===== Data Loaders =====

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
      _aiModelAnswer = null;
      _modelAnswersByUser.clear();
      _mcqSelectedIndex = null;
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
      _aiModelAnswer = null;
      _modelAnswersByUser.clear();
      _mcqSelectedIndex = null;
    });
    final p = await Api.problemDetail(pid);
    setState(() {
      prob = p;
      explLikes = (p['expl_like_count'] is int) ? (p['expl_like_count'] as int) : 0;
      explLiked = (p['expl_liked'] == true);
      loading = false;
    });
  }

  // ===== Actions =====

  Future<void> _answerMcq(int optionId) async {
    if (prob == null) return;
    final pid = prob!['id'] as int;

    // 選択だけ記録（正誤は自分でボタンで）
    await Api.answer(pid, optionId: optionId);

    final opts = _optionsOf(prob);
    final idx = opts.indexWhere((o) {
      try {
        final id = (o is Map) ? o['id'] : null;
        return id is int && id == optionId;
      } catch (_) {
        return false;
      }
    });

    // 解説・模範解答を更新
    final e = await Api.explanations(pid, 'likes');
    List<dynamic> mas = [];
    try {
      mas = await Api.listModelAnswers(pid);
    } catch (_) {}

    setState(() {
      _mcqSelectedIndex = idx >= 0 ? idx : null;
      explanations = e;
      _modelAnswersByUser.clear();
      _aiModelAnswer = null;
      for (final it in mas) {
        final uid = it is Map ? it['user_id'] : null;
        final c = it is Map ? it['content'] : null;
        if (uid is int && c is String && c.trim().isNotEmpty) {
          _modelAnswersByUser[uid] = c.trim();
        }
        if ((uid == null || (it is Map && it['is_ai'] == true)) &&
            c is String && c.trim().isNotEmpty) {
          _aiModelAnswer = c.trim();
        }
      }
    });
  }

  // ===== UI =====

  @override
  Widget build(BuildContext c) {
    final opts = _optionsOf(prob);
    final bool isMcq = opts.isNotEmpty; // ← qtype に依存せず options の有無で判定
    final bool isFree = !isMcq;

    return Scaffold(
      appBar: AppBar(title: const Text('問題をランダムに解く')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            // フィルタ列
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Text('教科: '),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: childId,
                    items: () {
                      if (tree.isEmpty) return <DropdownMenuItem<int>>[];
                      final cs = (tree.first['children'] as List?) ?? [];
                      return cs
                          .map<DropdownMenuItem<int>>(
                            (c) => DropdownMenuItem(value: c['id'] as int, child: Text('${c['name']}')),
                          )
                          .toList();
                    }(),
                    onChanged: (v) {
                      setState(() => childId = v);
                      _loadProblem();
                    },
                  ),
                  const SizedBox(width: 24),
                  const Text('単元: '),
                  const SizedBox(width: 8),
                  DropdownButton<int?>(
                    value: grandId,
                    items: () {
                      final items = <DropdownMenuItem<int?>>[
                        const DropdownMenuItem(value: null, child: Text('全単元（すべて）')),
                      ];
                      if (tree.isEmpty || childId == null) return items;
                      final cs = (tree.first['children'] as List?) ?? [];
                      final ch = cs.firstWhere((e) => e['id'] == childId, orElse: () => null);
                      if (ch == null) return items;
                      final gs = (ch['children'] as List?) ?? [];
                      items.addAll(
                        gs.map<DropdownMenuItem<int?>>(
                          (g) => DropdownMenuItem(value: g['id'] as int, child: Text('${g['name']}')),
                        ),
                      );
                      return items;
                    }(),
                    onChanged: (v) {
                      setState(() => grandId = v);
                      _loadProblem();
                    },
                  ),
                  const SizedBox(width: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: includeAnswered,
                        onChanged: (v) {
                          setState(() => includeAnswered = v ?? false);
                          _loadProblem();
                        },
                      ),
                      const Text('回答済みも含める'),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(),

            // 本体
            if (loading)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),

            if (!loading && prob == null) const Text('この条件の問題はありません'),

            if (!loading && prob != null) ...[
              // タイトル + 問題いいね
              Row(
                children: [
                  Expanded(
                    child: Text(
                      (prob!['title'] ?? '').toString(),
                      style: Theme.of(c).textTheme.titleLarge,
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      if (prob == null) return;
                      final liked = (prob!['liked'] ?? false) == true;
                      if (liked) {
                        final ok = await Api.unlikeProblem(prob!['id'] as int);
                        if (ok) {
                          setState(() {
                            prob!['liked'] = false;
                            prob!['like_count'] = ((prob!['like_count'] ?? 0) as int) - 1;
                            if (prob!['like_count'] < 0) prob!['like_count'] = 0;
                          });
                        }
                      } else {
                        final ok = await Api.likeProblem(prob!['id'] as int);
                        if (ok) {
                          setState(() {
                            prob!['liked'] = true;
                            prob!['like_count'] = (prob!['like_count'] ?? 0) + 1;
                          });
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: (prob!['liked'] ?? false) == true ? Colors.green : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.green, width: 1.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'いいね',
                            style: TextStyle(
                              color: (prob!['liked'] ?? false) == true ? Colors.white : Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${prob!['like_count'] ?? 0}',
                            style: TextStyle(
                              color: (prob!['liked'] ?? false) == true ? Colors.white : Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // 本文
              if ((prob!['body'] ?? '').toString().isNotEmpty)
                Text((prob!['body'] ?? '').toString()),

              const SizedBox(height: 8),

              // 画像（安全抽出）— あっても以降のフォームは必ず表示される
              Builder(builder: (_) {
                final imageUrls = _extractImageUrls(prob!['images'], base: Api.base);
                if (imageUrls.isEmpty) return const SizedBox.shrink();
                return _ImagesPager(urls: imageUrls);
              }),

              const Divider(),

              // --- 問題タイプ別フォーム（options の有無で判定） ---
              if (isMcq) ...[
                // 選択肢
                Column(
                  children: List.generate(opts.length, (i) {
                    final o = opts[i];
                    final text = (() {
                      if (o is Map) {
                        return (o['content'] ?? o['text'] ?? '').toString();
                      }
                      return o?.toString() ?? '';
                    })();
                    final optionId = (o is Map && o['id'] is int) ? (o['id'] as int) : null;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 56,
                            child: OutlinedButton(
                              onPressed: optionId == null ? null : () => _answerMcq(optionId),
                              child: Text(_kanaOf(i), style: const TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(text)),
                        ],
                      ),
                    );
                  }),
                ),

                // 選択済みなら「あなたの解答」を解説の前に表示
                if (_mcqSelectedIndex != null) ...[
                  const SizedBox(height: 12),
                  _yourAnswerSection(isMcq: true),
                  const Text('解説'),
                  const SizedBox(height: 8),
                  ..._groupedByUserExplanationCards(isMcq: true),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // 正解として記録
                      ElevatedButton(
                        onPressed: () async {
                          if (prob == null || _mcqSelectedIndex == null) return;
                          final pid = prob!['id'] as int;
                          final selId = (() {
                            final o = opts[_mcqSelectedIndex!];
                            return (o is Map && o['id'] is int) ? (o['id'] as int) : null;
                          })();
                          if (selId == null) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('選択肢IDの取得に失敗しました'), backgroundColor: Colors.red),
                            );
                            return;
                          }
                          await Api.answer(pid, selectedOptionId: selId, isCorrect: true);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('正解として記録しました')));
                        },
                        child: const Text('正解として記録'),
                      ),
                      const SizedBox(width: 8),
                      // 不正解として記録
                      ElevatedButton(
                        onPressed: () async {
                          if (prob == null || _mcqSelectedIndex == null) return;
                          final pid = prob!['id'] as int;
                          final selId = (() {
                            final o = opts[_mcqSelectedIndex!];
                            return (o is Map && o['id'] is int) ? (o['id'] as int) : null;
                          })();
                          if (selId == null) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('選択肢IDの取得に失敗しました'), backgroundColor: Colors.red),
                            );
                            return;
                          }
                          await Api.answer(pid, selectedOptionId: selId, isCorrect: false);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('不正解として記録しました')));
                        },
                        child: const Text('不正解として記録'),
                      ),
                    ],
                  ),
                ],
              ] else if (isFree) ...[
                // 記述式フォーム（画像があっても必ず表示）
                TextField(
                  controller: freeCtrl,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'あなたの解答（自由記述）',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () async {
                    if (prob == null) return;
                    final pid = prob!['id'] as int;

                    final e = await Api.explanations(pid, 'likes');

                    // 模範解答（AI/ユーザー）一覧
                    List<dynamic> mas = [];
                    try {
                      mas = await Api.listModelAnswers(pid);
                    } catch (_) {}

                    setState(() {
                      _freeUserAnswer = freeCtrl.text;
                      explanations = e;
                      _freeSubmitted = true;
                      _modelAnswersByUser.clear();
                      _aiModelAnswer = null;
                      for (final it in mas) {
                        final uid = it is Map ? it['user_id'] : null;
                        final c = it is Map ? it['content'] : null;
                        if (uid is int && c is String && c.trim().isNotEmpty) {
                          _modelAnswersByUser[uid] = c.trim();
                        }
                        if ((uid == null || (it is Map && it['is_ai'] == true)) &&
                            c is String && c.trim().isNotEmpty) {
                          _aiModelAnswer = c.trim();
                        }
                      }
                    });
                  },
                  child: const Text('解答する'),
                ),

                // 送信後：「あなたの解答」→ 解説
                if (_freeSubmitted) ...[
                  const SizedBox(height: 12),
                  _yourAnswerSection(isMcq: false),
                  const Text('解説'),
                  const SizedBox(height: 8),
                  ..._groupedByUserExplanationCards(isMcq: false),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: () async {
                          if (prob == null) return;
                          final pid = prob!['id'] as int;
                          await Api.answer(pid, freeText: _freeUserAnswer ?? freeCtrl.text, isCorrect: true);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('正解として記録しました')));
                        },
                        child: const Text('正解として記録'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          if (prob == null) return;
                          final pid = prob!['id'] as int;
                          await Api.answer(pid, freeText: _freeUserAnswer ?? freeCtrl.text, isCorrect: false);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('不正解として記録しました')));
                        },
                        child: const Text('不正解として記録'),
                      ),
                    ],
                  ),
                ],
              ],

              const SizedBox(height: 24),

              // 次へ / 戻る
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
          ],
        ),
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
        },
      );
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

    final opts = _optionsOf(prob);
    final cards = <Widget>[];
    for (final g in groups.values) {
      final by = (g['by'] ?? 'ユーザー').toString();
      final perOpt = (g['perOpt'] as Map<int, List<String>>);
      final overall = (g['overall'] as List<String>);
      final section = <Widget>[];

      // 「〇〇の解答」
      section.add(Text(by == 'AI' ? 'AIの解答' : '$by さんの解答', style: const TextStyle(fontWeight: FontWeight.w600)));
      if (by == 'AI' && _aiModelAnswer != null && _aiModelAnswer!.isNotEmpty) {
        section.add(const SizedBox(height: 4));
        section.add(Text(_aiModelAnswer!));
      }
      if (g['uid'] != null && _modelAnswersByUser.containsKey(g['uid'])) {
        section.add(const SizedBox(height: 4));
        section.add(Text(_modelAnswersByUser[g['uid']]!));
      }

      section.add(const SizedBox(height: 8));
      section.add(Text(by == 'AI' ? 'AIの解説' : '$by さんの解説', style: const TextStyle(fontWeight: FontWeight.w600)));

      if (isMcq) {
        // MCQ: 選択肢ごと
        final bool isAiGroup = by == 'AI';
        final List<int> indices =
            (isAiGroup && opts.isNotEmpty) ? List<int>.generate(opts.length, (i) => i) : (perOpt.keys.toList()..sort());
        for (final k in indices) {
          final merged = (perOpt[k] == null || perOpt[k]!.isEmpty) ? '' : perOpt[k]!.join('\n');
          section.add(Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('${_kanaOf(k)}：$merged'),
          ));
        }
      }

      if (overall.isNotEmpty) {
        if (isMcq) {
          section.add(const SizedBox(height: 8));
          section.add(const Text('全体の解説', style: TextStyle(fontWeight: FontWeight.w600)));
          section.add(const SizedBox(height: 4));
        }
        section.add(Text(overall.join('\n')));
      }

      cards.add(
        StatefulBuilder(
          builder: (context2, setCard) {
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...section,
                    const SizedBox(height: 8),
                    Align(
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
                            if (ok) setCard(() {
                              g['repLiked'] = false;
                              if (likeSum > 0) g['likeSum'] = likeSum - 1;
                            });
                          } else {
                            ok = await Api.likeExplanation(repId);
                            if (ok) setCard(() {
                              g['repLiked'] = true;
                              g['likeSum'] = likeSum + 1;
                            });
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
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
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
    return Column(
      children: [
        SizedBox(
          height: 280,
          width: double.infinity,
          child: PageView.builder(
            controller: _pc,
            onPageChanged: (i) => setState(() => _index = i),
            itemCount: widget.urls.length,
            itemBuilder: (_, i) {
              final url = widget.urls[i];
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
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: sel ? Colors.teal : Colors.grey.shade400,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
