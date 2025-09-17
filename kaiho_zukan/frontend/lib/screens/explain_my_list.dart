import 'package:flutter/material.dart';
import '../services/api.dart';
import 'post_problem_form.dart';
import '../widgets/app_icon.dart';

class ExplainMyListScreen extends StatefulWidget {
  const ExplainMyListScreen({super.key});
  @override
  State<ExplainMyListScreen> createState() => _ExplainMyListScreenState();
}

class _ExplainMyListScreenState extends State<ExplainMyListScreen> {
  List<dynamic> myProblems = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadMine();
  }

  Future<void> _loadMine() async {
    setState(() => loading = true);
    final list = await Api.myExplanationProblems();
    setState(() {
      myProblems = list;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const IconAppBarTitle(title: '自分の作った解説一覧')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: myProblems.length,
              itemBuilder: (_, i) {
                final p = myProblems[i];
                final kind = ((p['qtype'] ?? '') == 'mcq') ? '選択式' : '記述式';
                return Card(
                  child: ListTile(
                    title: Text(p['title'] ?? ''),
                    subtitle: Text('形式: $kind'),
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
                                builder: (_) => PostProblemForm(
                                  editId: p['id'] as int,
                                  explainOnly: true,
                                ),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          tooltip: '削除',
                          icon: const Icon(Icons.delete, color: Colors.redAccent),
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (c) => AlertDialog(
                                title: const Text('この問題の自分の解説を削除しますか？'),
                                content: const Text('この操作は元に戻せません。'),
                                actions: [
                                  TextButton(onPressed: ()=>Navigator.pop(c,false), child: const Text('キャンセル')),
                                  FilledButton(onPressed: ()=>Navigator.pop(c,true), child: const Text('削除')),
                                ],
                              ),
                            );
                            if (ok == true) {
                              final success = await Api.deleteMyExplanations(p['id'] as int);
                              if (!mounted) return;
                              if (success) {
                                await _loadMine();
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('削除しました')));
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('削除に失敗しました'), backgroundColor: Colors.red));
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
                          builder: (_) => PostProblemForm(
                            editId: p['id'] as int,
                            explainOnly: true,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
