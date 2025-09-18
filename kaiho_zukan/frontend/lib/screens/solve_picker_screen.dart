import 'package:flutter/material.dart';
import '../services/api.dart';
import 'solve_screen.dart';
import '../widgets/app_icon.dart';

class SolvePickerScreen extends StatefulWidget {
  const SolvePickerScreen({super.key});
  @override
  State<SolvePickerScreen> createState() => _S();
}

class _S extends State<SolvePickerScreen> {
  List<dynamic> parents = [], children = [], grands = [];
  int? parentId, childId;
  int? grandId; // null = 全単元
  String sort = 'likes';
  List<dynamic> items = [];
  final q = TextEditingController();
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadCats();
  }

  Future<void> _loadCats() async {
    final t = await Api.categories.tree();
    setState(() {
      parents = t;
      if (t.isNotEmpty) {
        parentId = t.first['id'] as int;
        children = t.first['children'] ?? [];
        if (children.isNotEmpty) {
          childId = children.first['id'] as int;
          grands = children.first['children'] ?? [];
          grandId = null; // 全単元
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
    setState(() { items = list; loading = false; });
  }

  List<dynamic> _filtered() {
    final kw = q.text.trim().toLowerCase();
    if (kw.isEmpty) return items;
    return items.where((p) {
      final t = (p['title'] ?? '').toString().toLowerCase();
      final b = (p['body'] ?? '').toString().toLowerCase();
      return t.contains(kw) || b.contains(kw);
    }).toList();
  }

  @override
  Widget build(BuildContext c) {
    return Scaffold(
      appBar: AppBar(title: const IconAppBarTitle(title: '問題を選んで解く')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            DropdownButton<int>(
              value: parentId,
              items: parents.map<DropdownMenuItem<int>>((p) => DropdownMenuItem(value: p['id'] as int, child: Text(p['name']))).toList(),
              onChanged: (v) {
                final p = parents.firstWhere((e) => e['id'] == v);
                setState(() {
                  parentId = v;
                  children = p['children'] ?? [];
                  childId = children.isNotEmpty ? children.first['id'] as int : null;
                  grands = childId != null ? (children.firstWhere((c) => c['id'] == childId)['children'] ?? []) : [];
                  grandId = null; // 全単元
                });
                _search();
              },
            ),
            const SizedBox(width: 8),
            DropdownButton<int>(
              value: childId,
              items: children.map<DropdownMenuItem<int>>((c) => DropdownMenuItem(value: c['id'] as int, child: Text(c['name']))).toList(),
              onChanged: (v) {
                final ch = children.firstWhere((e) => e['id'] == v);
                setState(() {
                  childId = v;
                  grands = ch['children'] ?? [];
                  grandId = null; // 全単元
                });
                _search();
              },
            ),
            const SizedBox(width: 8),
            DropdownButton<int?>(
              value: grandId,
              items: <DropdownMenuItem<int?>>[
                const DropdownMenuItem(value: null, child: Text('全単元（すべて）')),
                ...grands.map<DropdownMenuItem<int?>>((g) => DropdownMenuItem(value: g['id'] as int, child: Text(g['name']))),
              ],
              onChanged: (v) { setState(() => grandId = v); _search(); },
            ),
            const Spacer(),
            IconButton(onPressed: _search, icon: const Icon(Icons.refresh), tooltip: '更新'),
          ]),
          const SizedBox(height: 8),
          TextField(
            controller: q,
            decoration: const InputDecoration(
              hintText: 'タイトル・問題文で検索',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : (_filtered().isEmpty
                    ? const Center(child: Text('該当する問題がありません'))
                    : ListView.separated(
                        itemCount: _filtered().length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final p = _filtered()[i];
                          return ListTile(
                            title: Text(p['title'] ?? ''),
                            subtitle: Text('いいね ${p['like_count']} / 解説数: ${p['ex_cnt']}'),
                            trailing: FilledButton(
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SolveScreen(initialProblemId: p['id'] as int))),
                              child: const Text('解く'),
                            ),
                          );
                        },
                      )),
          ),
        ]),
      ),
    );
  }
}
