import 'package:flutter/material.dart';
import '../services/api.dart';
import 'post_problem_form.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_breadcrumbs.dart';
import 'home.dart';
import 'post_problem_hub.dart';
import 'explain_hub.dart';

class ExplainCreateNewScreen extends StatefulWidget {
  const ExplainCreateNewScreen({super.key});
  @override
  State<ExplainCreateNewScreen> createState() => _ExplainCreateNewScreenState();
}

class _ExplainCreateNewScreenState extends State<ExplainCreateNewScreen> {
  List<dynamic> parents = [], children = [], grands = [];
  int? parentId, childId, grandId; // grandId=null で「全単元（すべて）」
  String sort = 'likes';
  List<dynamic> problems = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadCats();
  }

  Future<void> _loadCats() async {
    final t = await Api.categories.tree(mineOnly: true);
    setState(() {
      parents = t;
      if (t.isNotEmpty) {
        parentId = t.first['id'] as int;
        children = t.first['children'] ?? [];
        if (children.isNotEmpty) {
          childId = children.first['id'] as int;
          grands = children.first['children'] ?? [];
          grandId = null; // 全単元（すべて）
        }
      }
    });
    await _search();
  }

  Future<void> _search() async {
    if (childId == null) return;
    setState(() => loading = true);
    final list = await Api.problems
        .problemsForExplain(childId: childId!, grandId: grandId, sort: sort);
    final mine = await Api.explanations.myProblems();
    final mineIds = mine.map<int>((e) => e['id'] as int).toSet();
    setState(() {
      problems = list.where((p) => !mineIds.contains(p['id'] as int)).toList();
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
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
              MaterialPageRoute(builder: (_) => const PostProblemHubScreen()),
            ),
          ),
          BreadcrumbItem(
            label: '解説の投稿/編集',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ExplainHubScreen()),
            ),
          ),
          const BreadcrumbItem(label: '解説未作成の問題一覧'),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '新規で解説を作成',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 24),
          // フィルタ列
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              DropdownButton<int>(
                value: parentId,
                items: parents
                    .map<DropdownMenuItem<int>>(
                      (p) => DropdownMenuItem(
                        value: p['id'] as int,
                        child: Text(p['name']),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  final p = parents.firstWhere((e) => e['id'] == v);
                  setState(() {
                    parentId = v;
                    children = p['children'] ?? [];
                    childId = children.isNotEmpty ? children.first['id'] : null;
                    grands = childId != null
                        ? (children.firstWhere(
                                (c) => c['id'] == childId)['children'] ??
                            [])
                        : [];
                    grandId = null;
                  });
                  _search();
                },
              ),
              const SizedBox(width: 12),
              DropdownButton<int>(
                value: childId,
                items: children
                    .map<DropdownMenuItem<int>>(
                      (c) => DropdownMenuItem(
                        value: c['id'] as int,
                        child: Text(c['name']),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  final c = children.firstWhere((e) => e['id'] == v);
                  setState(() {
                    childId = v;
                    grands = c['children'] ?? [];
                    grandId = null;
                  });
                  _search();
                },
              ),
              const SizedBox(width: 12),
              DropdownButton<int?>(
                value: grandId,
                items: <DropdownMenuItem<int?>>[
                  const DropdownMenuItem<int?>(
                      value: null, child: Text('全単元（すべて）')),
                  ...grands.map<DropdownMenuItem<int?>>((g) =>
                      DropdownMenuItem<int?>(
                          value: g['id'] as int, child: Text(g['name'])))
                ],
                onChanged: (v) {
                  setState(() => grandId = v);
                  _search();
                },
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: sort,
                items: const [
                  DropdownMenuItem(value: 'likes', child: Text('いいね順')),
                  DropdownMenuItem(value: 'explanations', child: Text('解説数')),
                  DropdownMenuItem(value: 'new', child: Text('新着')),
                ],
                onChanged: (v) {
                  setState(() => sort = v ?? 'likes');
                  _search();
                },
              ),
            ]),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: problems.length,
                    itemBuilder: (_, i) {
                      final p = problems[i];
                      return Card(
                        child: ListTile(
                          title: Text(p['title'] ?? ''),
                          subtitle: Text(
                              'いいね ${p['like_count']} / 解説数: ${p['ex_cnt']}'),
                          trailing: const Icon(Icons.edit),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PostProblemForm(
                                editId: p['id'] as int,
                                explainOnly: true,
                                explanationContext:
                                    ExplanationBreadcrumbContext.createNew,
                              ),
                            ),
                          ),
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
