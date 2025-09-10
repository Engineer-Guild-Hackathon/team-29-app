import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api.dart';
import 'my_problems.dart';

class PostProblemForm extends StatefulWidget {
  final int? editId;
  final bool explainOnly; // 解説のみ編集モード
  const PostProblemForm({super.key, this.editId, this.explainOnly = false});
  @override
  State<PostProblemForm> createState() => _PostProblemFormState();
}

class _PostProblemFormState extends State<PostProblemForm> {
  final title = TextEditingController();
  final body = TextEditingController();
  final initialExplain = TextEditingController();
  final modelAnswerCtrl = TextEditingController();

  String qtype = 'mcq';
  int? correctIndex;
  int optionCount = 4;
  final List<TextEditingController> optionCtrls = [];
  final List<TextEditingController> optionExplainCtrls = [];

  List<dynamic> parents = [], children = [], grands = [];
  int? parentId, childId, grandId;

  bool loading = true;
  int likeCount = 0;
  int explLikeCount = 0;

  final List<PlatformFile> newImages = [];
  List<String> existingImageUrls = [];

  @override
  void initState() {
    super.initState();
    _loadCats();
  }

  void _ensureOptionControllers(int count) {
    while (optionCtrls.length < count) {
      optionCtrls.add(TextEditingController());
    }
    while (optionCtrls.length > count) {
      optionCtrls.removeLast();
    }
    while (optionExplainCtrls.length < count) {
      optionExplainCtrls.add(TextEditingController());
    }
    while (optionExplainCtrls.length > count) {
      optionExplainCtrls.removeLast();
    }
  }

  Future<void> _loadCats() async {
    final t = await Api.categoryTree();
    setState(() {
      parents = t;
      parentId = t.isNotEmpty ? t.first['id'] : null;
      children = t.isNotEmpty ? t.first['children'] ?? [] : [];
      childId = children.isNotEmpty ? children.first['id'] : null;
      grands = children.isNotEmpty ? (children.first['children'] ?? []) : [];
      grandId = grands.isNotEmpty ? grands.first['id'] : null;
    });
    if (widget.editId != null) {
      final d = await Api.getProblem(widget.editId!);
      title.text = (d['title'] ?? '').toString();
      body.text = (d['body'] ?? '').toString();
      qtype = (d['qtype'] ?? 'mcq').toString();
      likeCount = (d['like_count'] ?? 0) as int;
      explLikeCount = (d['expl_like_count'] ?? 0) as int;
      if (d['images'] is List) {
        existingImageUrls = List<String>.from((d['images'] as List).map((e) => e.toString()));
      }
      if (d['options'] is List) {
        final list = (d['options'] as List);
        optionCount = list.length.clamp(2, 10);
        _ensureOptionControllers(optionCount);
        for (int i = 0; i < list.length && i < optionCtrls.length; i++) {
          optionCtrls[i].text = (list[i]['text'] ?? list[i]['content'] ?? '').toString();
        }
        final idx = list.indexWhere((e) => (e['is_correct'] ?? false) == true);
        correctIndex = idx >= 0 ? idx : null;
      } else {
        _ensureOptionControllers(optionCount);
      }
      // 自分の解説をロード
      final me = await Api.myExplanations(widget.editId!);
      if (me['overall'] is String) initialExplain.text = (me['overall'] as String);
      if (me['options'] is List) {
        final optEx = List.from(me['options']);
        _ensureOptionControllers(optionCount);
        for (int i = 0; i < optEx.length && i < optionExplainCtrls.length; i++) {
          final v = optEx[i];
          if (v is String && v.trim().isNotEmpty) optionExplainCtrls[i].text = v;
        }
      }
      if (d['model_answer'] is String) modelAnswerCtrl.text = (d['model_answer'] as String);
    } else {
      _ensureOptionControllers(optionCount);
    }
    setState(() => loading = false);
  }

  Future<void> _submit() async {
    if (widget.explainOnly) {
      if (widget.editId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('問題IDが不正です'), backgroundColor: Colors.red),
        );
        return;
      }
      List<String>? optionExplanationsJson;
      if (qtype == 'mcq') {
        _ensureOptionControllers(optionCount);
        optionExplanationsJson = optionExplainCtrls.take(optionCount).map((c) => c.text.trimRight()).toList();
      }
      final r = await Api.updateProblemWithImages(
        id: widget.editId!,
        initialExplanation: initialExplain.text.trim().isEmpty ? null : initialExplain.text.trim(),
        optionExplanationsJson: optionExplanationsJson,
      );
      if (!mounted) return;
      if ((r['ok'] ?? false) == true) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('保存しました')));
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('保存に失敗しました'), backgroundColor: Colors.red));
      }
      return;
    }

    if (childId == null || grandId == null) return;

    String? optionsText;
    List<String>? optionExplanationsJson;
    if (qtype == 'mcq') {
      _ensureOptionControllers(optionCount);
      final lines = optionCtrls.take(optionCount).map((c) => c.text.trim()).toList();
      optionsText = lines.join('\n');
      final exList = <String>[];
      for (int i = 0; i < optionExplainCtrls.length && i < optionCount; i++) {
        exList.add(optionExplainCtrls[i].text.trimRight());
      }
      optionExplanationsJson = exList;
    }

    if (qtype == 'free' && modelAnswerCtrl.text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('記述式は模範解答が必須です'), backgroundColor: Colors.red),
      );
      return;
    }

    final imgs = newImages.where((f) => f.bytes != null).map((f) => (bytes: f.bytes!, name: f.name)).toList();

    if (widget.editId == null) {
      final r = await Api.createProblemWithImages(
        title: title.text.trim(),
        body: body.text.trim().isEmpty ? null : body.text.trim(),
        qtype: qtype,
        childId: childId!,
        grandId: grandId!,
        optionsText: optionsText,
        correctIndex: qtype == 'mcq' ? correctIndex : null,
        initialExplanation: initialExplain.text.trim().isEmpty ? null : initialExplain.text.trim(),
        modelAnswer: qtype == 'free' && modelAnswerCtrl.text.trim().isNotEmpty ? modelAnswerCtrl.text.trim() : null,
        optionExplanationsJson: optionExplanationsJson,
        images: imgs.isEmpty ? null : imgs,
      );
      if (!mounted) return;
      if ((r['ok'] ?? false) == true) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MyProblemsScreen()));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('作成に失敗しました'), backgroundColor: Colors.red));
      }
    } else {
      final r = await Api.updateProblemWithImages(
        id: widget.editId!,
        title: title.text.trim(),
        body: body.text.trim().isEmpty ? null : body.text.trim(),
        qtype: qtype,
        childId: childId!,
        grandId: grandId!,
        optionsText: optionsText,
        correctIndex: qtype == 'mcq' ? correctIndex : null,
        modelAnswer: qtype == 'free' && modelAnswerCtrl.text.trim().isNotEmpty ? modelAnswerCtrl.text.trim() : null,
        initialExplanation: initialExplain.text.trim().isNotEmpty ? initialExplain.text.trim() : null,
        optionExplanationsJson: optionExplanationsJson,
        images: imgs.isEmpty ? null : imgs,
      );
      if (!mounted) return;
      if ((r['ok'] ?? false) == true) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MyProblemsScreen()));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('更新に失敗しました'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.explainOnly ? '解説を編集' : (widget.editId == null ? '新規で問題を作る' : '問題を編集')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (widget.editId != null) ...[
                Row(children: [
                  Chip(label: Text('問題いいね: $likeCount')),
                  const SizedBox(width: 8),
                  Chip(label: Text('解説いいね: $explLikeCount')),
                ]),
                const SizedBox(height: 8),
              ],
              TextField(controller: title, enabled: !widget.explainOnly, decoration: const InputDecoration(labelText: 'タイトル')),
              const SizedBox(height: 8),
              TextField(controller: body, enabled: !widget.explainOnly, minLines: 3, maxLines: 6, decoration: const InputDecoration(labelText: '問題文')),
              const SizedBox(height: 8),
              Row(children: [
                const Text('種別: '),
                DropdownButton<String>(
                  value: qtype,
                  items: const [
                    DropdownMenuItem(value: 'mcq', child: Text('選択式')),
                    DropdownMenuItem(value: 'free', child: Text('記述式')),
                  ],
                  onChanged: widget.explainOnly ? null : (v) => setState(() => qtype = v ?? 'mcq'),
                ),
                const Spacer(),
                DropdownButton<int>(
                  value: parentId,
                  items: parents.map<DropdownMenuItem<int>>((p) => DropdownMenuItem(value: p['id'] as int, child: Text(p['name']))).toList(),
                  onChanged: widget.explainOnly ? null : (v) {
                    final p = parents.firstWhere((e) => e['id'] == v);
                    setState(() {
                      parentId = v;
                      children = p['children'] ?? [];
                      childId = children.isNotEmpty ? children.first['id'] : null;
                      grands = childId != null ? (children.firstWhere((c) => c['id'] == childId)['children'] ?? []) : [];
                      grandId = grands.isNotEmpty ? grands.first['id'] : null;
                    });
                  },
                ),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: childId,
                  items: children.map<DropdownMenuItem<int>>((c) => DropdownMenuItem(value: c['id'] as int, child: Text(c['name']))).toList(),
                  onChanged: widget.explainOnly ? null : (v) {
                    final c = children.firstWhere((e) => e['id'] == v);
                    setState(() {
                      childId = v;
                      grands = c['children'] ?? [];
                      grandId = grands.isNotEmpty ? grands.first['id'] : null;
                    });
                  },
                ),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: grandId,
                  items: grands.map<DropdownMenuItem<int>>((g) => DropdownMenuItem(value: g['id'] as int, child: Text(g['name']))).toList(),
                  onChanged: widget.explainOnly ? null : (v) => setState(() => grandId = v),
                ),
              ]),
              const SizedBox(height: 8),
              // 画像: 全幅スライダー + ドット
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Text('画像'),
                  const SizedBox(width: 8),
                  if (!widget.explainOnly)
                    OutlinedButton.icon(
                      onPressed: () async {
                        final res = await FilePicker.platform.pickFiles(allowMultiple: true, withData: true, type: FileType.image);
                        if (res != null) setState(() => newImages.addAll(res.files));
                      },
                      icon: const Icon(Icons.add_photo_alternate),
                      label: const Text('画像を追加'),
                    ),
                ]),
                const SizedBox(height: 8),
                _ImagesPager(
                  widgets: [
                    ...existingImageUrls.map((u) => ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(u.startsWith('http') ? u : Api.base + u, fit: BoxFit.contain))),
                    ...newImages.where((f) => f.bytes != null).map((f) => Stack(children: [
                          ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(f.bytes!, fit: BoxFit.contain)),
                          if (!widget.explainOnly)
                            Positioned(top: 8, right: 8, child: InkWell(onTap: () => setState(() => newImages.remove(f)), child: Container(decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(16)), padding: const EdgeInsets.all(4), child: const Icon(Icons.close, color: Colors.white))))
                        ])),
                  ],
                ),
              ]),
              if (qtype == 'mcq') ...[
                const SizedBox(height: 8),
                Row(children: [
                  const Text('選択肢数: '),
                  DropdownButton<int>(
                    value: optionCount,
                    items: [2, 3, 4, 5, 6].map((n) => DropdownMenuItem<int>(value: n, child: Text('$n'))).toList(),
                    onChanged: widget.explainOnly ? null : (v) {
                      if (v == null) return;
                      setState(() {
                        optionCount = v;
                        _ensureOptionControllers(optionCount);
                        if ((correctIndex ?? -1) >= optionCount) correctIndex = null;
                      });
                    },
                  ),
                ]),
                const SizedBox(height: 8),
                const Align(alignment: Alignment.centerLeft, child: Text('正解の選択肢にチェックしてください')),
                const SizedBox(height: 8),
                Column(children: List.generate(optionCount, (i) {
                  _ensureOptionControllers(optionCount);
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Checkbox(value: correctIndex == i, onChanged: widget.explainOnly ? null : (v) => setState(() => correctIndex = (v == true) ? i : null)),
                          const SizedBox(width: 4),
                          Text('選択肢 ${i + 1}')
                        ]),
                        TextField(controller: optionCtrls[i], enabled: !widget.explainOnly, decoration: const InputDecoration(labelText: '選択肢文'), maxLines: 2),
                        const SizedBox(height: 8),
                        TextField(controller: optionExplainCtrls[i], decoration: const InputDecoration(labelText: '解説'), maxLines: 3),
                      ]),
                    ),
                  );
                })),
              ] else ...[
                const SizedBox(height: 8),
                TextField(controller: modelAnswerCtrl, enabled: !widget.explainOnly, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: '解答')),
              ],
              const SizedBox(height: 8),
              TextField(controller: initialExplain, minLines: 3, maxLines: 6, decoration: InputDecoration(labelText: qtype == 'mcq' ? '全体の解説' : '解説')),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submit,
                  child: Text(widget.editId == null ? '作成して一覧へ' : '更新する'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _ImagesPager extends StatefulWidget {
  final List<Widget> widgets;
  const _ImagesPager({super.key, required this.widgets});
  @override
  State<_ImagesPager> createState() => _ImagesPagerState();
}

class _ImagesPagerState extends State<_ImagesPager> {
  final PageController _pc = PageController();
  int _index = 0;
  @override
  Widget build(BuildContext context) {
    if (widget.widgets.isEmpty) return const SizedBox.shrink();
    return Column(children: [
      SizedBox(
        height: 280,
        width: double.infinity,
        child: PageView.builder(
          controller: _pc,
          onPageChanged: (i) => setState(() => _index = i),
          itemCount: widget.widgets.length,
          itemBuilder: (_, i) => Container(color: Colors.black12, alignment: Alignment.center, child: Padding(padding: const EdgeInsets.all(4), child: widget.widgets[i])),
        ),
      ),
      const SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(widget.widgets.length, (i) {
          final sel = i == _index;
          return GestureDetector(
            onTap: () => _pc.animateToPage(i, duration: const Duration(milliseconds: 200), curve: Curves.easeOut),
            child: Container(width: 10, height: 10, margin: const EdgeInsets.symmetric(horizontal: 4), decoration: BoxDecoration(shape: BoxShape.circle, color: sel ? Colors.teal : Colors.grey.shade400)),
          );
        }),
      ),
    ]);
  }
}

