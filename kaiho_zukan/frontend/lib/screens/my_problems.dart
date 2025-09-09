import 'package:flutter/material.dart';
import '../services/api.dart';
import 'post_problem_form.dart';

class MyProblemsScreen extends StatefulWidget {
  const MyProblemsScreen({super.key});
  @override
  State<MyProblemsScreen> createState() => _MyProblemsScreenState();
}

class _MyProblemsScreenState extends State<MyProblemsScreen> {
  String sort = 'new';
  List<dynamic> items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await Api.myProblems(sort);
    final list = (r['items'] is List) ? List.from(r['items']) : <dynamic>[];
    setState(() => items = list);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('自分が作った問題')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            const Text('並び替え: '),
            DropdownButton<String>(
              value: sort,
              items: const [
                DropdownMenuItem(value: 'new', child: Text('新着')),
                DropdownMenuItem(value: 'likes', child: Text('いいね')),
                DropdownMenuItem(value: 'ex_cnt', child: Text('解説数')),
              ],
              onChanged: (v) {
                setState(() => sort = v ?? 'new');
                _load();
              },
            ),
          ]),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (_, i) {
              final it = items[i];
              final qtypeJp = (it['qtype'] == 'mcq') ? '選択式' : '記述式';
              return Card(
                child: ListTile(
                  title: Text(it['title'] ?? ''),
                  subtitle: Text('解説: ${it['ex_cnt']}  いいね: ${it['like_count']}  種別: $qtypeJp'),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PostProblemForm(editId: it['id'] as int),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

