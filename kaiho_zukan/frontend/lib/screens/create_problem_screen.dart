import 'package:flutter/material.dart';
import '../services/api.dart';

class CreateProblemScreen extends StatefulWidget {
  const CreateProblemScreen({super.key});
  @override
  State<CreateProblemScreen> createState() => _S();
}

class _S extends State<CreateProblemScreen> {
  final title = TextEditingController(), body = TextEditingController();
  String qtype = 'mcq';
  int optionCount = 4;
  List<String> options = ['', '', '', ''];
  List<String> explains = ['', '', '', ''];
  int correctIndex = 0;
  final modelAnswer = TextEditingController();
  List<dynamic> tree = [];
  int? childId;
  int? grandId;

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
      if (root['children'] != null && root['children'].isNotEmpty) {
        childId = root['children'][0]['id'];
        if (root['children'][0]['children'] != null &&
            root['children'][0]['children'].isNotEmpty) {
          grandId = root['children'][0]['children'][0]['id'];
        }
      }
    }
  }

  List<DropdownMenuItem<int>> _childItems() {
    if (tree.isEmpty) return [];
    final root = tree.first;
    return (root['children'] as List<dynamic>)
        .map((c) =>
            DropdownMenuItem<int>(value: c['id'], child: Text(c['name'])))
        .toList();
  }

  List<DropdownMenuItem<int>> _grandItems() {
    if (tree.isEmpty || childId == null) return [];
    final root = tree.first;
    final ch = (root['children'] as List<dynamic>)
        .firstWhere((c) => c['id'] == childId, orElse: () => null);
    if (ch == null) return [];
    return (ch['children'] as List<dynamic>)
        .map((g) =>
            DropdownMenuItem<int>(value: g['id'], child: Text(g['name'])))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text('問題を投稿')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Row(children: [
            const Text('教科: '),
            const SizedBox(width: 8),
            DropdownButton<int>(
                value: childId,
                items: _childItems(),
                onChanged: (v) => setState(() => childId = v)),
            const SizedBox(width: 24),
            const Text('単元: '),
            const SizedBox(width: 8),
            DropdownButton<int>(
                value: grandId,
                items: _grandItems(),
                onChanged: (v) => setState(() => grandId = v)),
          ]),
          const SizedBox(height: 8),
          TextField(
              controller: title,
              decoration: const InputDecoration(
                  labelText: 'タイトル', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(
              controller: body,
              maxLines: 6,
              decoration: const InputDecoration(
                  labelText: '問題文', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          Row(children: [
            const Text('形式: '),
            DropdownButton<String>(
                value: qtype,
                items: const [
                  DropdownMenuItem(value: 'mcq', child: Text('選択式')),
                  DropdownMenuItem(value: 'free', child: Text('記述式')),
                ],
                onChanged: (v) => setState(() => qtype = v ?? 'mcq')),
          ]),
          if (qtype == 'mcq') ...[
            const SizedBox(height: 8),
            Row(children: [
              const Text('選択肢数: '),
              DropdownButton<int>(
                  value: optionCount,
                  items: const [2, 3, 4, 5, 6]
                      .map((n) =>
                          DropdownMenuItem<int>(value: n, child: Text('$n')))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      optionCount = v;
                      if (options.length < optionCount) {
                        options.addAll(
                            List.filled(optionCount - options.length, ''));
                        explains.addAll(
                            List.filled(optionCount - explains.length, ''));
                      }
                      if (options.length > optionCount) {
                        options = options.sublist(0, optionCount);
                        explains = explains.sublist(0, optionCount);
                      }
                      if (correctIndex >= optionCount) correctIndex = 0;
                    });
                  }),
            ]),
            const SizedBox(height: 8),
            LayoutBuilder(builder: (c, cons) {
              final maxW = cons.maxWidth;
              final cols = maxW > 900 ? 3 : (maxW > 600 ? 2 : 1);
              final itemW = (maxW - (cols - 1) * 12) / cols;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: List.generate(optionCount, (i) {
                  return SizedBox(
                      width: itemW,
                      child: Card(
                          child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Radio<int>(
                                    value: i,
                                    groupValue: correctIndex,
                                    onChanged: (v) =>
                                        setState(() => correctIndex = v ?? 0)),
                                const SizedBox(width: 4),
                                Text('選択肢 ${i + 1}')
                              ]),
                              TextField(
                                  onChanged: (t) => options[i] = t,
                                  decoration:
                                      const InputDecoration(labelText: '問題文'),
                                  maxLines: 2),
                              const SizedBox(height: 8),
                              TextField(
                                  onChanged: (t) => explains[i] = t,
                                  decoration: const InputDecoration(
                                      labelText: '解説（任意）'),
                                  maxLines: 3),
                            ]),
                      )));
                }),
              );
            }),
          ] else ...[
            const SizedBox(height: 8),
            const Text('記述式では選択肢はありません。'),
            const SizedBox(height: 8),
            TextField(
                controller: modelAnswer,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                    labelText: '模範解答（任意）', border: OutlineInputBorder())),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
              onPressed: () async {
                if (childId == null || grandId == null) return;
                final initialExp = explains
                    .take(optionCount)
                    .toList()
                    .asMap()
                    .entries
                    .where((e) => e.value.trim().isNotEmpty)
                    .map((e) => '選択肢${e.key + 1}の解説: ${e.value.trim()}')
                    .join('\n');
                final ok = await Api.createProblemMultipart(
                      title: title.text,
                      body: body.text,
                      qtype: qtype,
                      childId: childId!,
                      grandId: grandId!,
                      options: qtype == 'mcq'
                          ? options.take(optionCount).join(',')
                          : null,
                      correctIndex: qtype == 'mcq' ? correctIndex : null,
                      initialExplanation:
                          initialExp.isEmpty ? null : initialExp,
                      modelAnswer:
                          qtype == 'free' && modelAnswer.text.trim().isNotEmpty
                              ? modelAnswer.text.trim()
                              : null,
                    ) ==
                    true;
                if (ok && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('投稿しました。AI解説は自動生成されます！')));
                  title.clear();
                  body.clear();
                } else {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('投稿に失敗しました')));
                }
              },
              icon: const Icon(Icons.send),
              label: const Text('投稿する'))
        ]));
  }
}
