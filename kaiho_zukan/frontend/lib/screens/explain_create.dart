import 'package:flutter/material.dart';
import '../services/api.dart';
import 'post_problem_form.dart';

class ExplainCreateScreen extends StatefulWidget {
  const ExplainCreateScreen({super.key});
  @override
  State<ExplainCreateScreen> createState() => _ExplainCreateScreenState();
}

class _ExplainCreateScreenState extends State<ExplainCreateScreen> {
  List<dynamic> parents = [], children = [], grands = [];
  int? parentId, childId, grandId;
  String sort = 'likes';
  List<dynamic> problems = [];
  List<dynamic> myProblems = [];
  int tab = 0; // 0: 新規で作る, 1: 作成済みを見る

  @override
  void initState() { super.initState(); _loadCats(); }

  Future<void> _loadCats() async {
    final t = await Api.categoryTree();
    setState((){
      parents = t;
      if (t.isNotEmpty) {
        parentId = t.first['id'];
        children = t.first['children'] ?? [];
        if (children.isNotEmpty) {
          childId = children.first['id'];
          grands = children.first['children'] ?? [];
          if (grands.isNotEmpty) grandId = grands.first['id'];
        }
      }
    });
    await _search();
  }

  Future<void> _search() async {
    if (childId == null) return;
    final list = await Api.problemsForExplain(childId: childId!, grandId: grandId, sort: sort);
    final mine = await Api.myExplanationProblems();
    final mineIds = mine.map<int>((e) => e['id'] as int).toSet();
    setState(() => problems = list.where((p) => !mineIds.contains(p['id'] as int)).toList());
  }

  Future<void> _loadMine() async {
    final list = await Api.myExplanationProblems();
    setState(() => myProblems = list);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('解説を作る')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            ChoiceChip(label: const Text('新規で作る'), selected: tab == 0, onSelected: (_) { setState(() => tab = 0); }),
            const SizedBox(width: 8),
            ChoiceChip(label: const Text('作成済みを見る'), selected: tab == 1, onSelected: (_) { setState(() { tab = 1; }); _loadMine(); }),
          ]),
          const SizedBox(height: 8),
          Row(children: [
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
                  grandId = grands.isNotEmpty ? grands.first['id'] : null;
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
                  grandId = grands.isNotEmpty ? grands.first['id'] : null;
                });
                _search();
              },
            ),
            const SizedBox(width: 12),
            DropdownButton<int>(
              value: grandId,
              items: grands.map<DropdownMenuItem<int>>((g) => DropdownMenuItem(value: g['id'] as int, child: Text(g['name']))).toList(),
              onChanged: (v) { setState(() => grandId = v); _search(); },
            ),
            const Spacer(),
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
                          subtitle: Text('種別: $kind / 自分のいいね: ${p['my_like_count'] ?? 0}'),
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
                  ),
          ),
        ]),
      ),
    );
  }
}

