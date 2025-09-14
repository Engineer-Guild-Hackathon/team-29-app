import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api.dart';
import 'my_problems.dart';
// import 'problem_posted.dart';

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
  // 自分の解答（記述式用）
  final myAnswerCtrl = TextEditingController();

  String qtype = 'mcq';
  int? correctIndex;
  int optionCount = 4;
  final List<TextEditingController> optionCtrls = [];
  final List<TextEditingController> optionExplainCtrls = [];
  // 選択肢のIDを保持（取得時）
  final List<int?> optionIds = [];
  // 自分の解答（選択肢）: 0-based index（explainOnly時のユーザ別模範解答として使用）
  int? myModelAnswerIndex;

  List<dynamic> parents = [], children = [], grands = [];
  int? parentId, childId, grandId;

  bool loading = true;
  int likeCount = 0;
  int explLikeCount = 0;

  // 問題画像（既存）
  final List<PlatformFile> newImages = [];
  List<String> existingImageUrls = [];

  // 解説画像（新規追加：問題画像と全く同じ扱い）
  final List<PlatformFile> newExplainImages = [];
  // 既存の解説画像URLはAPIが返していないため、ここでは新規選択分のみプレビューします
  // List<String> existingExplainImageUrls = []; // （必要になれば拡張）

  // ガイドライン同意
  bool agreeGeneral = false;
  bool agreeImage = false;

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
    // Initial defaults
    List<dynamic> parentsTmp = t;
    List<dynamic> childrenTmp =
        t.isNotEmpty ? (t.first['children'] ?? []) as List<dynamic> : [];
    List<dynamic> grandsTmp = childrenTmp.isNotEmpty
        ? (childrenTmp.first['children'] ?? []) as List<dynamic>
        : [];
    int? parentIdTmp = t.isNotEmpty ? t.first['id'] as int? : null;
    int? childIdTmp =
        childrenTmp.isNotEmpty ? childrenTmp.first['id'] as int? : null;
    int? grandIdTmp = grandsTmp.isNotEmpty ? grandsTmp.first['id'] as int? : null;

    if (widget.editId != null) {
      final d = await Api.getProblem(widget.editId!);
      title.text = (d['title'] ?? '').toString();
      body.text = (d['body'] ?? '').toString();
      qtype = (d['qtype'] ?? 'mcq').toString();
      likeCount = (d['like_count'] ?? 0) as int;
      explLikeCount = (d['expl_like_count'] ?? 0) as int;

      // ----- Restore previously selected category -----
      final cid = d['child_id'] is int
          ? d['child_id'] as int
          : int.tryParse('${d['child_id']}');
      final gid = d['grand_id'] is int
          ? d['grand_id'] as int
          : int.tryParse('${d['grand_id']}');
      if (cid != null) {
        for (final p in parentsTmp) {
          final ch = (p['children'] as List?) ?? [];
          final match = ch.firstWhere(
              (e) => e is Map && e['id'] == cid,
              orElse: () => null);
          if (match != null) {
            parentIdTmp = p['id'] as int?;
            childrenTmp = ch;
            childIdTmp = cid;
            grandsTmp = (match['children'] as List?) ?? [];
            if (gid != null &&
                grandsTmp.any((g) => g is Map && g['id'] == gid)) {
              grandIdTmp = gid;
            } else {
              grandIdTmp =
                  grandsTmp.isNotEmpty ? grandsTmp.first['id'] as int? : null;
            }
            break;
          }
        }
      }

      if (d['images'] is List) {
        existingImageUrls =
            List<String>.from((d['images'] as List).map((e) => e.toString()));
      }
      if (d['options'] is List) {
        final list = (d['options'] as List);
        optionCount = list.length.clamp(2, 10);
        _ensureOptionControllers(optionCount);
        // 選択肢IDの配列長を調整
        while (optionIds.length < optionCount) {
          optionIds.add(null);
        }
        while (optionIds.length > optionCount) {
          optionIds.removeLast();
        }
        for (int i = 0; i < list.length && i < optionCtrls.length; i++) {
          optionCtrls[i].text =
              (list[i]['text'] ?? list[i]['content'] ?? '').toString();
          try {
            optionIds[i] = (list[i]['id'] as int);
          } catch (_) {}
        }
        final idx = list.indexWhere((e) => (e['is_correct'] ?? false) == true);
        correctIndex = idx >= 0 ? idx : null;
      } else {
        _ensureOptionControllers(optionCount);
      }
      // 自分の解説をロード（本文のみ。画像の既存プレビューはAPI未対応のため省略）
      final me = await Api.myExplanations(widget.editId!);
      if (me['overall'] is String) {
        initialExplain.text = (me['overall'] as String);
      }
      if (me['options'] is List) {
        final optEx = List.from(me['options']);
        _ensureOptionControllers(optionCount);
        for (int i = 0; i < optEx.length && i < optionExplainCtrls.length; i++) {
          final v = optEx[i];
          if (v is String && v.trim().isNotEmpty) {
            optionExplainCtrls[i].text = v;
          }
        }
      }
      if (d['model_answer'] is String) {
        modelAnswerCtrl.text = (d['model_answer'] as String);
      }

      // 自分の model_answer（文字列）を選択肢にマッピング（mcqのみ）
      if (qtype == 'mcq' && d['model_answer'] is String) {
        final mine = (d['model_answer'] as String).trim();
        if (mine.isNotEmpty && optionCtrls.isNotEmpty) {
          // 1) 選択肢テキスト一致でのマッピング
          final idxByText = optionCtrls.indexWhere((c) => c.text.trim() == mine);
          if (idxByText >= 0) {
            myModelAnswerIndex = idxByText;
          } else {
            // 2) 数字（1始まり）で保存されている場合のマッピング
            final num = int.tryParse(mine);
            if (num != null && num >= 1 && num <= optionCtrls.length) {
              myModelAnswerIndex = num - 1;
            }
          }
        }
      }

      // 自分の最新の解答（選択/記述）を取得してUIに反映（任意）
      try {
        final ri = await Api.reviewItem(widget.editId!);
        if (ri['latest_answer'] is Map) {
          final la = Map<String, dynamic>.from(ri['latest_answer']);
          final selId = la['selected_option_id'];
          if (selId is int) {
            final idx = optionIds.indexOf(selId);
            if (idx >= 0 && myModelAnswerIndex == null) {
              myModelAnswerIndex = idx;
            }
          }
          final ft = la['free_text'];
          if (ft is String && ft.trim().isNotEmpty) {
            myAnswerCtrl.text = ft;
          }
        }
      } catch (_) {}
    } else {
      _ensureOptionControllers(optionCount);
    }

    setState(() {
      parents = parentsTmp;
      children = childrenTmp;
      grands = grandsTmp;
      parentId = parentIdTmp;
      childId = childIdTmp;
      grandId = grandIdTmp;
      loading = false;
    });
  }

  Future<void> _submit() async {
    // 共通: ガイドライン同意チェック
    if (!agreeGeneral) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ガイドラインに同意してください'), backgroundColor: Colors.red),
      );
      return;
    }

    // 画像同意は、新規で画像をアップロードする場合のみ必須
    final bool hasProblemImageUploads = !widget.explainOnly && newImages.isNotEmpty;
    final bool hasExplainImageUploads = newExplainImages.any((f) => f.bytes != null);
    final bool needsImageConsent = hasProblemImageUploads || hasExplainImageUploads;
    if (needsImageConsent && !agreeImage) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('画像のガイドラインに同意してください'), backgroundColor: Colors.red),
      );
      return;
    }
    // explainOnly: 解説投稿/編集モード
    if (widget.explainOnly) {
      if (widget.editId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('問題IDが不正です'), backgroundColor: Colors.red),
        );
        return;
      }
      List<String>? optionExplanationsJson;

      // 先に解答を任意送信（選択式/記述式）
      try {
        if (qtype == 'mcq' && myModelAnswerIndex != null) {
          // 取得済みの選択肢IDに変換
          int? selId;
          final idx = myModelAnswerIndex!;
          if (idx >= 0 && idx < optionIds.length) selId = optionIds[idx];
          if (selId != null && widget.editId != null) {
            await Api.answer(widget.editId!, selectedOptionId: selId);
          }
        } else if (qtype != 'mcq' &&
            myAnswerCtrl.text.trim().isNotEmpty &&
            widget.editId != null) {
          await Api.answer(widget.editId!, freeText: myAnswerCtrl.text.trim());
        }
      } catch (_) {}

      // 自分の model answer を保存（multipartの不安定回避策としてApi側は x-www-form-urlencoded 推奨）
      try {
        if (qtype == 'mcq') {
          final idx = myModelAnswerIndex;
          if (idx != null) {
            final txt = (idx + 1).toString(); // 1-based
            await Api.upsertMyModelAnswer(widget.editId!, txt);
          } else {
            await Api.deleteMyModelAnswer(widget.editId!);
          }
        } else {
          final txt = modelAnswerCtrl.text.trim();
          if (txt.isNotEmpty) {
            await Api.upsertMyModelAnswer(widget.editId!, txt);
          } else {
            await Api.deleteMyModelAnswer(widget.editId!);
          }
        }
      } catch (_) {}

      if (qtype == 'mcq') {
        _ensureOptionControllers(optionCount);
        optionExplanationsJson =
            optionExplainCtrls.take(optionCount).map((c) => c.text.trimRight()).toList();
      }

      // ★画像付きで投稿する場合は、updateProblemWithImages では initial_explanation を送らない
      final hasExplainImages = newExplainImages.any((f) => f.bytes != null);
      final initialTxt = initialExplain.text.trim();

      // 1) まずテキストの更新（※画像がある場合は initial_explanation は null にして重複を防ぐ）
      final r = await Api.updateProblemWithImages(
        id: widget.editId!,
        initialExplanation: hasExplainImages
            ? null
            : (initialTxt.isEmpty ? null : initialTxt),
        optionExplanationsJson: optionExplanationsJson,
      );

      if (!mounted) return;
      if ((r['ok'] ?? false) != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存に失敗しました'), backgroundColor: Colors.red),
        );
        return;
      }

      // 2) 画像付き解説の投稿（必要な場合のみ）
      if (hasExplainImages) {
        if (initialTxt.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('画像を送る場合は、解説本文も入力してください'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
        final imgs = newExplainImages
            .where((f) => f.bytes != null)
            .map((f) => (bytes: f.bytes!, name: f.name))
            .toList();
        final ok = await Api.postExplanationWithImagesData(
          problemId: widget.editId!,
          content: initialTxt,
          images: imgs,
        );
        if (!ok) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('解説画像の投稿に失敗しました'), backgroundColor: Colors.red),
          );
          return;
        }
      }

      // 完了
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存しました')),
      );
      Navigator.pop(context);
      return;
    }

    // ========= ここから通常の作成/編集 =========
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

    final problemImgs = newImages
        .where((f) => f.bytes != null)
        .map((f) => (bytes: f.bytes!, name: f.name))
        .toList();

    final explainImgs = newExplainImages
        .where((f) => f.bytes != null)
        .map((f) => (bytes: f.bytes!, name: f.name))
        .toList();

    final initialTxt = initialExplain.text.trim();
    final hasExplainImages = explainImgs.isNotEmpty;

    if (widget.editId == null) {
      // 新規作成：画像付き解説を投げる場合は initial_explanation を作成時に送らず、後で images 付きで投稿
      final r = await Api.createProblemWithImages(
        title: title.text.trim(),
        body: body.text.trim().isEmpty ? null : body.text.trim(),
        qtype: qtype,
        childId: childId!,
        grandId: grandId!,
        optionsText: optionsText,
        correctIndex: qtype == 'mcq' ? correctIndex : null,
        initialExplanation: hasExplainImages
            ? null
            : (initialTxt.isEmpty ? null : initialTxt),
        modelAnswer: qtype == 'free' && modelAnswerCtrl.text.trim().isNotEmpty
            ? modelAnswerCtrl.text.trim()
            : null,
        optionExplanationsJson: optionExplanationsJson,
        images: problemImgs.isEmpty ? null : problemImgs,
      );
      if (!mounted) return;
      if ((r['ok'] ?? false) == true) {
        // 新規作成後の付随処理（回答や模範解答の保存）
        try {
          final newId = (r['id'] is int) ? (r['id'] as int) : null;
          if (newId != null) {
            if (qtype == 'mcq' && myModelAnswerIndex != null) {
              final d = await Api.getProblem(newId);
              if (d['options'] is List) {
                final list = List.from(d['options']);
                final idx = myModelAnswerIndex!.clamp(0, list.length - 1);
                try {
                  await Api.answer(newId, selectedOptionId: (list[idx]['id'] as int));
                } catch (_) {}
              }
              final idx = myModelAnswerIndex!;
              await Api.upsertMyModelAnswer(newId, (idx + 1).toString());
            } else if (qtype != 'mcq') {
              final mine = myAnswerCtrl.text.trim();
              final alt = modelAnswerCtrl.text.trim();
              if (mine.isNotEmpty) {
                await Api.answer(newId, freeText: mine);
              }
              if (alt.isNotEmpty) {
                await Api.upsertMyModelAnswer(newId, alt);
              }
            }

            // ★ 画像付き解説の投稿（必要な場合のみ）
            if (hasExplainImages) {
              if (initialTxt.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('画像を送る場合は、解説本文も入力してください'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              final ok = await Api.postExplanationWithImagesData(
                problemId: newId,
                content: initialTxt,
                images: explainImgs,
              );
              if (!ok) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('解説画像の投稿に失敗しました'), backgroundColor: Colors.red),
                );
                return;
              }
            }
          }
        } catch (_) {}
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MyProblemsScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('作成に失敗しました'), backgroundColor: Colors.red),
        );
      }
    } else {
      // 既存編集：画像付き解説を投げる場合は initial_explanation はPUTで送らず、別APIで投稿
      final r = await Api.updateProblemWithImages(
        id: widget.editId!,
        title: title.text.trim(),
        body: body.text.trim().isEmpty ? null : body.text.trim(),
        qtype: qtype,
        childId: childId!,
        grandId: grandId!,
        optionsText: optionsText,
        correctIndex: qtype == 'mcq' ? correctIndex : null,
        modelAnswer: qtype == 'free' && modelAnswerCtrl.text.trim().isNotEmpty
            ? modelAnswerCtrl.text.trim()
            : null,
        initialExplanation: hasExplainImages
            ? null
            : (initialTxt.isNotEmpty ? initialTxt : null),
        optionExplanationsJson: optionExplanationsJson,
        images: problemImgs.isEmpty ? null : problemImgs,
      );
      if (!mounted) return;
      if ((r['ok'] ?? false) == true) {
        // 回答や模範解答の保存
        try {
          if (qtype == 'mcq' && myModelAnswerIndex != null) {
            int? selId;
            final idx = myModelAnswerIndex!;
            if (idx >= 0 && idx < optionIds.length) selId = optionIds[idx];
            if (selId != null) {
              await Api.answer(widget.editId!, selectedOptionId: selId);
            }
            await Api.upsertMyModelAnswer(widget.editId!, (idx + 1).toString());
          } else if (qtype != 'mcq') {
            final mine = myAnswerCtrl.text.trim();
            final alt = modelAnswerCtrl.text.trim();
            if (mine.isNotEmpty) {
              await Api.answer(widget.editId!, freeText: mine);
            }
            if (alt.isNotEmpty) {
              await Api.upsertMyModelAnswer(widget.editId!, alt);
            } else {
              await Api.deleteMyModelAnswer(widget.editId!);
            }
          }

          // ★ 画像付き解説の投稿（必要な場合のみ）
          if (hasExplainImages) {
            if (initialTxt.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('画像を送る場合は、解説本文も入力してください'),
                  backgroundColor: Colors.orange,
                ),
              );
              return;
            }
            final ok = await Api.postExplanationWithImagesData(
              problemId: widget.editId!,
              content: initialTxt,
              images: explainImgs,
            );
            if (!ok) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('解説画像の投稿に失敗しました'), backgroundColor: Colors.red),
              );
              return;
            }
          }
        } catch (_) {}
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MyProblemsScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('更新に失敗しました'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.explainOnly
              ? '解説を編集'
              : (widget.editId == null ? '新規で問題を作る' : '問題を編集'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.editId != null) ...[
                  Row(children: [
                    Chip(label: Text('問題いいね: $likeCount')),
                    const SizedBox(width: 8),
                    Chip(label: Text('解説いいね: $explLikeCount')),
                  ]),
                  const SizedBox(height: 8),
                ],
                TextField(
                  controller: title,
                  enabled: !widget.explainOnly,
                  decoration: const InputDecoration(labelText: 'タイトル'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: body,
                  enabled: !widget.explainOnly,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(labelText: '問題文'),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  const Text('種別: '),
                  DropdownButton<String>(
                    value: qtype,
                    items: const [
                      DropdownMenuItem(value: 'mcq', child: Text('選択式')),
                      DropdownMenuItem(value: 'free', child: Text('記述式')),
                    ],
                    onChanged: widget.explainOnly
                        ? null
                        : (v) => setState(() => qtype = v ?? 'mcq'),
                  ),
                  const Spacer(),
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
                    onChanged: widget.explainOnly
                        ? null
                        : (v) {
                            final p = parents.firstWhere((e) => e['id'] == v);
                            setState(() {
                              parentId = v;
                              children = p['children'] ?? [];
                              childId = children.isNotEmpty
                                  ? children.first['id']
                                  : null;
                              grands = childId != null
                                  ? (children.firstWhere((c) => c['id'] == childId)['children'] ?? [])
                                  : [];
                              grandId = grands.isNotEmpty ? grands.first['id'] : null;
                            });
                          },
                  ),
                  const SizedBox(width: 8),
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
                    onChanged: widget.explainOnly
                        ? null
                        : (v) {
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
                    items: grands
                        .map<DropdownMenuItem<int>>(
                          (g) => DropdownMenuItem(
                            value: g['id'] as int,
                            child: Text(g['name']),
                          ),
                        )
                        .toList(),
                    onChanged: widget.explainOnly ? null : (v) => setState(() => grandId = v),
                  ),
                ]),
                const SizedBox(height: 8),

                // ===== 問題画像（既存UI） =====
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Text('画像'),
                      const SizedBox(width: 8),
                      if (!widget.explainOnly)
                        OutlinedButton.icon(
                          onPressed: () async {
                            final res = await FilePicker.platform.pickFiles(
                              allowMultiple: true,
                              withData: true,
                              type: FileType.image,
                            );
                            if (res != null) {
                              setState(() => newImages.addAll(res.files));
                            }
                          },
                          icon: const Icon(Icons.add_photo_alternate),
                          label: const Text('画像を追加'),
                        ),
                    ]),
                    const SizedBox(height: 8),
                    _ImagesPager(
                      widgets: [
                        ...existingImageUrls.map(
                          (u) => ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              u.startsWith('http') ? u : Api.base + u,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        ...newImages
                            .where((f) => f.bytes != null)
                            .map(
                              (f) => Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.memory(
                                      f.bytes!,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  if (!widget.explainOnly)
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: InkWell(
                                        onTap: () => setState(() => newImages.remove(f)),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.black45,
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          padding: const EdgeInsets.all(4),
                                          child: const Icon(Icons.close, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                      ],
                    ),
                  ],
                ),

                // ===== 選択肢・解説 =====
                if (qtype == 'mcq') ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    const Text('選択肢数: '),
                    DropdownButton<int>(
                      value: optionCount,
                      items: [2, 3, 4, 5, 6]
                          .map((n) => DropdownMenuItem<int>(value: n, child: Text('$n')))
                          .toList(),
                      onChanged: widget.explainOnly
                          ? null
                          : (v) {
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
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.explainOnly
                          ? '自分の模範解答にしたい選択肢にチェックしてください'
                          : '正解が分かる場合は選択肢にチェックしてください',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Column(
                    children: List.generate(optionCount, (i) {
                      _ensureOptionControllers(optionCount);
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Checkbox(
                                  value: widget.explainOnly ? (myModelAnswerIndex == i) : (correctIndex == i),
                                  onChanged: (v) {
                                    setState(() {
                                      if (widget.explainOnly) {
                                        myModelAnswerIndex = (v == true) ? i : null;
                                      } else {
                                        correctIndex = (v == true) ? i : null;
                                      }
                                    });
                                  },
                                ),
                                const SizedBox(width: 4),
                                Text('選択肢 ${i + 1}'),
                              ]),
                              TextField(
                                controller: optionCtrls[i],
                                enabled: !widget.explainOnly,
                                decoration: const InputDecoration(labelText: '選択肢文'),
                                maxLines: 2,
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: optionExplainCtrls[i],
                                decoration: const InputDecoration(labelText: '解説'),
                                maxLines: 3,
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                ] else ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: modelAnswerCtrl,
                    enabled: !widget.explainOnly,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: '解答'),
                  ),
                  const SizedBox(height: 8),
                  // 自分の解答（任意）
                  TextField(
                    controller: myAnswerCtrl,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: '自分の解答（任意）'),
                  ),
                ],

                const SizedBox(height: 8),
                // 全体の解説
                TextField(
                  controller: initialExplain,
                  minLines: 3,
                  maxLines: 6,
                  decoration: InputDecoration(labelText: qtype == 'mcq' ? '全体の解説' : '解説'),
                ),

                // ===== 解説画像（新規追加） =====
                const SizedBox(height: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Text('解説画像'),
                      const SizedBox(width: 8),
                      // ★ 解説投稿モードでも使えるように、explainOnly でもボタン有効にする
                      OutlinedButton.icon(
                        onPressed: () async {
                          final res = await FilePicker.platform.pickFiles(
                            allowMultiple: true,
                            withData: true,
                            type: FileType.image,
                          );
                          if (res != null) {
                            setState(() => newExplainImages.addAll(res.files));
                          }
                        },
                        icon: const Icon(Icons.add_photo_alternate),
                        label: const Text('解説画像を追加'),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    _ImagesPager(
                      widgets: [
                        // 既存の解説画像プレビューはAPI未提供のため新規選択分のみ表示
                        ...newExplainImages
                            .where((f) => f.bytes != null)
                            .map(
                              (f) => Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.memory(
                                      f.bytes!,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  // 解説投稿は常に有効にしたいので、explainOnly でも削除可
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: InkWell(
                                      onTap: () => setState(() => newExplainImages.remove(f)),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black45,
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        padding: const EdgeInsets.all(4),
                                        child: const Icon(Icons.close, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                // ===== ガイドライン同意（常時表示） =====
                Builder(builder: (_) {
                  final head = widget.explainOnly
                      ? '私は投稿する解説において以下に同意します。'
                      : '私は投稿する問題及び解説において以下に同意します。';
                  final body = '1. 本・書籍・問題集・Webサイト・大学の過去問等の著作物を、許諾を得ず原文のまま転載していません。\n'
                      '2. 必要に応じて自分の言葉で再構成・要約しており、著作権者の権利を侵害しません。\n'
                      '3. 引用がある場合は公正な範囲で、出典を明記します。\n'
                      '4. 第三者の個人情報や機密情報を含みません。\n'
                      '5. 本サービスのガイドラインに反する投稿は非公開・削除されることに同意します。';
                  return CheckboxListTile(
                    value: agreeGeneral,
                    onChanged: (v) => setState(() => agreeGeneral = (v ?? false)),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(head),
                    subtitle: Text(body),
                  );
                }),

                // ===== 画像ガイドライン同意（新規アップロード時のみ表示） =====
                Builder(builder: (_) {
                  final hasProblemImageUploads = !widget.explainOnly && newImages.isNotEmpty;
                  final hasExplainImageUploads = newExplainImages.any((f) => f.bytes != null);
                  final needsImageConsent = hasProblemImageUploads || hasExplainImageUploads;
                  if (!needsImageConsent) return const SizedBox.shrink();
                  const head = '私は投稿する画像に関して以下に同意します。';
                  const body = '1. 画像・図表は自作、許諾済み、またはライセンス条件を遵守しています（クレジット表記・リンク等が必要な場合は記載）。\n'
                      '2. 教科書・問題集・過去問の紙面を撮影/スキャン/OCRした画像は掲載していません（必要なら自作図に描き直し、要点のみ記載）。\n'
                      '3. 写真に人物・氏名・連絡先などの個人情報が写り込んでいません。';
                  return CheckboxListTile(
                    value: agreeImage,
                    onChanged: (v) => setState(() => agreeImage = (v ?? false)),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(head),
                    subtitle: Text(body),
                  );
                }),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submit,
                    child: Text(widget.editId == null ? '作成して一覧へ' : '更新する'),
                  ),
                ),
              ],
            ),
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
          itemBuilder: (_, i) => Container(
            color: Colors.black12,
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: widget.widgets[i],
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(widget.widgets.length, (i) {
          final sel = i == _index;
          return GestureDetector(
            onTap: () => _pc.animateToPage(
              i,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            ),
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
    ]);
  }
}
