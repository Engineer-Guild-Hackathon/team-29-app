import 'package:flutter/material.dart';
import '../services/api.dart';
import 'post_problem_form.dart';

class ExplainFixWrongScreen extends StatefulWidget {
  const ExplainFixWrongScreen({super.key});
  @override
  State<ExplainFixWrongScreen> createState() => _ExplainFixWrongScreenState();
}

class _ExplainFixWrongScreenState extends State<ExplainFixWrongScreen> {
  bool loading = true;
  int loaded = 0;
  int total = 0;
  List<_WrongItem> items = [];
  int? myUserId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      items = [];
      loaded = 0;
      total = 0;
    });
    final me = await Api.me();
    final uid = me['id'] as int?;
    final mine = await Api.myExplanationProblems();
    setState(() {
      myUserId = uid;
      total = mine.length;
    });
    final tmp = <_WrongItem>[];
    for (final p in mine) {
      final pid = p['id'] as int;
      final title = (p['title'] ?? '').toString();
      final list = await Api.explanations(pid, 'likes');
      for (final e in list) {
        final euid = e['user_id'];
        final aiWrong = e['ai_is_wrong'] == true;
        final crowdWrong = e['crowd_maybe_wrong'] == true;
        if (uid != null && euid == uid && (aiWrong || crowdWrong)) {
          tmp.add(_WrongItem(
            problemId: pid,
            problemTitle: title,
            explanationId: e['id'] as int,
            content: (e['content'] ?? '').toString(),
            aiReason: (e['ai_judge_reason'] ?? '').toString(),
            crowdFlag: crowdWrong,
          ));
        }
      }
      setState(() => loaded += 1);
    }
    setState(() {
      items = tmp;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('「間違っている」判定の解説一覧')),
      body: loading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(total > 0 ? '読み込み中... ($loaded/$total)' : '読み込み中...'),
                ],
              ),
            )
          : (items.isEmpty
              ? const Center(child: Text('該当する解説はありません'))
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final it = items[i];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(it.problemTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text(
                              it.content,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            if (it.aiReason.trim().isNotEmpty)
                              Text('AIによる説明: ${it.aiReason}'),
                            if (it.crowdFlag)
                              const Text('多くのユーザが間違っていると判定'),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                FilledButton(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PostProblemForm(
                                        editId: it.problemId,
                                        explainOnly: true,
                                      ),
                                    ),
                                  ),
                                  child: const Text('編集する'),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
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
                                      final success = await Api.deleteMyExplanations(it.problemId);
                                      if (!mounted) return;
                                      if (success) {
                                        setState(() {
                                          items.removeAt(i);
                                        });
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('削除しました')));
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('削除に失敗しました'), backgroundColor: Colors.red));
                                      }
                                    }
                                  },
                                  child: const Text('削除'),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    );
                  },
                )),
    );
  }
}

class _WrongItem {
  final int problemId;
  final String problemTitle;
  final int explanationId;
  final String content;
  final String aiReason;
  final bool crowdFlag;
  _WrongItem({
    required this.problemId,
    required this.problemTitle,
    required this.explanationId,
    required this.content,
    required this.aiReason,
    required this.crowdFlag,
  });
}

