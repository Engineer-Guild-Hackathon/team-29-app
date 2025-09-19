import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/api.dart';
import 'post_problem_form.dart';
import '../widgets/app_icon.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_breadcrumbs.dart';
import 'home.dart';

class ExplainCreateScreen extends StatefulWidget {
  const ExplainCreateScreen({super.key});
  @override
  State<ExplainCreateScreen> createState() => _ExplainCreateScreenState();
}

class _ExplainCreateScreenState extends State<ExplainCreateScreen> {
  List<dynamic> parents = [], children = [], grands = [];
  int? parentId, childId, grandId; // grandId=null で「すべて」
  String sort = 'likes';
  List<dynamic> problems = [];
  List<dynamic> myProblems = [];
  int tab = 0; // 0: 新規で作る, 1: 作成済みを見る

  @override
  void initState() { super.initState(); _loadCats(); }

  Future<void> _loadCats() async {
    final t = await Api.categories.tree(mineOnly: true);
    setState((){
      parents = t;
      if (t.isNotEmpty) {
        parentId = t.first['id'];
        children = t.first['children'] ?? [];
        if (children.isNotEmpty) {
          childId = children.first['id'];
          grands = children.first['children'] ?? [];
          // 既定は「すべて」
          grandId = null;
        }
      }
    });
    await _search();
  }

  Future<void> _search() async {
    if (childId == null) return;
    final list = await Api.problems.problemsForExplain(childId: childId!, grandId: grandId, sort: sort);
    final mine = await Api.explanations.myProblems();
    final mineIds = mine.map<int>((e) => e['id'] as int).toSet();
    setState(() => problems = list.where((p) => !mineIds.contains(p['id'] as int)).toList());
  }

  Future<void> _loadMine() async {
    final list = await Api.explanations.myProblems();
    setState(() => myProblems = list);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: '解説を作る',
      subHeader: AppBreadcrumbs(
        items: [
          BreadcrumbItem(
            label: 'ホーム',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            ),
          ),
          BreadcrumbItem(
            label: '投稿する',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen(initialSelected: 2)),
            ),
          ),
          const BreadcrumbItem(label: '解説を作る'),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
            ChoiceChip(label: const Text('新規で作る'), selected: tab == 0, onSelected: (_) { setState(() => tab = 0); }),
            const SizedBox(width: 8),
            ChoiceChip(label: const Text('作成済みを見る'), selected: tab == 1, onSelected: (_) { setState(() { tab = 1; }); _loadMine(); }),
            ]),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
            DropdownButton<int>(
              value: parentId,
              items: parents.map<DropdownMenuItem<int>>((p) => DropdownMenuItem(value: p['id'] as int, child: Text(p['name']))).toList(),
              onChanged: (v) {
                final p = parents.firstWhere((e) => e['id'] == v);
                setState(() {
                  parentId = v;
                  children = p['children'] ?? [];
                  childId = children.isNotEmpty ? children.first['id'] : null;
                  grands = childId != null ? (children.firstWhere((c) => c['id'] == childId)['children'] ?? []) : [];
                  // 親変更時は「すべて」に戻す
                  grandId = null;
                });
                _search();
              },
            ),
            const SizedBox(width: 12),
            DropdownButton<int>(
              value: childId,
              items: children.map<DropdownMenuItem<int>>((c) => DropdownMenuItem(value: c['id'] as int, child: Text(c['name']))).toList(),
              onChanged: (v) {
                final c = children.firstWhere((e) => e['id'] == v);
                setState(() {
                  childId = v;
                  grands = c['children'] ?? [];
                  // 子変更時も「すべて」に戻す
                  grandId = null;
                });
                _search();
              },
            ),
            const SizedBox(width: 12),
            DropdownButton<int?>(
              value: grandId,
              items: <DropdownMenuItem<int?>>[
                const DropdownMenuItem<int?>(value: null, child: Text('全単元（すべて）')),
                ...grands.map<DropdownMenuItem<int?>>((g) => DropdownMenuItem<int?>(value: g['id'] as int, child: Text(g['name'])))
              ],
              onChanged: (v) { setState(() => grandId = v); _search(); },
            ),
            // Spacer() は SingleChildScrollView(scrollDirection: Axis.horizontal) 配下だと
            // 無限幅コンストレイントで例外になるため使用しない
            const SizedBox(width: 12),
            DropdownButton<String>(
              value: sort,
              items: const [
                DropdownMenuItem(value: 'likes', child: Text('いいね順')),
                DropdownMenuItem(value: 'explanations', child: Text('解説数順')),
                DropdownMenuItem(value: 'new', child: Text('新着順')),
              ],
              onChanged: (v) { setState(() => sort = v ?? 'likes'); _search(); },
            ),
            ]),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: tab == 0
                ? ListView.builder(
                    itemCount: problems.length,
                    itemBuilder: (_, i) {
                      final p = problems[i];
                      return Card(
                        child: ListTile(
                          title: Text(p['title'] ?? ''),
                          subtitle: Text('いいね ${p['like_count']} / 解説数: ${p['ex_cnt']}'),
                          trailing: const Icon(Icons.edit),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => PostProblemForm(editId: p['id'] as int, explainOnly: true)),
                            );
                          },
                        ),
                      );
                    },
                  )
                : ListView.builder(
                    itemCount: myProblems.length,
                    itemBuilder: (_, i) {
                      final p = myProblems[i];
                      final kind = ((p['qtype'] ?? '') == 'mcq') ? '選択式' : '記述式';
                      return Card(
                        child: ListTile(
                          title: Text(p['title'] ?? ''),
                          subtitle: Text('解説のいいね: ${p['my_like_count'] ?? 0}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: '編集',
                                icon: const Icon(Icons.edit),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => PostProblemForm(editId: p['id'] as int, explainOnly: true)),
                                  );
                                },
                              ),
                              IconButton(
                                tooltip: '削除',
                                icon: const Icon(Icons.delete, color: AppColors.danger),
                                onPressed: () async {
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (c) => AlertDialog(
                                      title: const Text('自分の解説を削除しますか？'),
                                      content: const Text('この操作は元に戻せません。'),
                                      actions: [
                                        TextButton(onPressed: ()=>Navigator.pop(c,false), child: const Text('キャンセル')),
                                        FilledButton(onPressed: ()=>Navigator.pop(c,true), child: const Text('削除')),
                                      ],
                                    ),
                                  );
                                  if (ok == true) {
                                    final success = await Api.explanations.deleteMine(p['id'] as int);
                                    if (success) {
                                      if (!mounted) return;
                                      await _loadMine();
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('削除しました')));
                                    } else {
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('削除に失敗しました'), backgroundColor: AppColors.danger));
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => PostProblemForm(editId: p['id'] as int, explainOnly: true)),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}
