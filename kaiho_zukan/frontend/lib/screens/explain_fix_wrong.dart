import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/api.dart';
import 'post_problem_form.dart';
import '../widgets/app_icon.dart';

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
    final me = await Api.users.fetchMe();
    final uid = me['id'] as int?;
    final mine = await Api.explanations.myProblems();
    setState(() {
      myUserId = uid;
      total = mine.length;
    });
    final tmp = <_WrongItem>[];
    for (final p in mine) {
      final pid = p['id'] as int;
      final title = (p['title'] ?? '').toString();

      // 問題詳細（本文・画像・選択肢・自分の模範解答）
      final detail = await Api.problems.get(pid);
      final body = (detail['body'] ?? '').toString();
      final qtype = (detail['qtype'] ?? '').toString();
      final List<String> images = List<String>.from(
        (detail['images'] as List?)?.map((e) => e.toString()) ?? const [],
      );
      final myModelAnswer = (detail['model_answer'] ?? '').toString();
      final List<Map<String, dynamic>> options = ((detail['options'] as List?)
                  ?.map((e) => {
                        'id': e['id'],
                        'text': e['text'],
                      })
                  .toList() ??
              const [])
          .cast<Map<String, dynamic>>();

      // 自分の最新解答
      final ritem = await Api.review.item(pid);
      int? selectedOptionId = (ritem['latest_answer'] is Map)
          ? (ritem['latest_answer']['selected_option_id'] as int?)
          : null;
      String? freeText = (ritem['latest_answer'] is Map)
          ? (ritem['latest_answer']['free_text'] as String?)
          : null;

      // 自分の解説一覧から「AI判定 or 群衆判定で間違いかも」のものを抽出
      final list = await Api.explanations.list(pid, 'likes');
      for (final e in list) {
        final euid = e['user_id'];
        final aiWrong = e['ai_is_wrong'] == true;
        final crowdWrong = e['crowd_maybe_wrong'] == true;
        if (uid != null && euid == uid && (aiWrong || crowdWrong)) {
          tmp.add(_WrongItem(
            problemId: pid,
            problemTitle: title,
            problemBody: body,
            problemImages: images,
            qtype: qtype,
            options: options,
            myModelAnswer: myModelAnswer,
            mySelectedOptionId: selectedOptionId,
            myFreeText: freeText,
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

  String _kanaOf(int i) {
    const k = ['ア', 'イ', 'ウ', 'エ', 'オ', 'カ', 'キ', 'ク', 'ケ', 'コ'];
    return (i >= 0 && i < k.length) ? k[i] : '選択肢${i + 1}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const IconAppBarTitle(title: '「間違っている」判定の解説一覧')),
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
              ? const Center(child: Text('対象の解説はありません'))
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final it = items[i];

                    // Compose "あなたの解答" テキスト
                    String myAnswerText = '';
                    if (it.myFreeText != null && it.myFreeText!.trim().isNotEmpty) {
                      myAnswerText = it.myFreeText!.trim();
                    } else if (it.mySelectedOptionId != null && it.options.isNotEmpty) {
                      final idx = it.options.indexWhere((o) => o['id'] == it.mySelectedOptionId);
                      if (idx >= 0) {
                        final label = _kanaOf(idx);
                        final txt = (it.options[idx]['text'] ?? '').toString();
                        myAnswerText = '$label: $txt';
                      }
                    }

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // タイトル
                            Text(it.problemTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),

                            // 問題文
                            if (it.problemBody.trim().isNotEmpty) ...[
                              const Text('問題文：', style: TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text(it.problemBody),
                              const SizedBox(height: 8),
                            ],

                            // 画像（問題を解くページと同じ表示方式）
                            Builder(builder: (_) {
                              final urls = it.problemImages
                                  .map((u) => u.startsWith('http') ? u : Api.base + u)
                                  .toList();
                              if (urls.isEmpty) return const SizedBox.shrink();
                              return _ImagesPager(urls: urls);
                            }),

                            // あなたの解答
                            if (myAnswerText.isNotEmpty) ...[
                              const Text('あなたの解答：', style: TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text(myAnswerText),
                              const SizedBox(height: 8),
                            ],

                            // あなたの解説
                            const Text('あなたの解説：', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(
                              it.content,
                              maxLines: 6,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),

                            // AIの説明
                            if (it.aiReason.trim().isNotEmpty) ...[
                              const Text('AIの説明：', style: TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text(it.aiReason),
                              const SizedBox(height: 8),
                            ],

                            // 自分の模範解答
                            if (it.myModelAnswer != null && it.myModelAnswer!.trim().isNotEmpty) ...[
                              const Text('あなたの模範解答：', style: TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text(it.myModelAnswer!.trim()),
                              const SizedBox(height: 8),
                            ],

                            if (it.crowdFlag)
                              const Text('多くのユーザーが間違っていると判断'),

                            // 右端に鉛筆・ゴミ箱アイコン（他の一覧と統一）
                            Row(
                              children: [
                                const Spacer(),
                                IconButton(
                                  tooltip: '編集',
                                  icon: const Icon(Icons.edit),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => PostProblemForm(
                                          editId: it.problemId,
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
                                      final success = await Api.explanations.deleteMine(it.problemId);
                                      if (!mounted) return;
                                      if (success) {
                                        setState(() {
                                          items.removeAt(i);
                                        });
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('削除しました')));
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('削除に失敗しました'), backgroundColor: AppColors.danger));
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
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
  final String problemBody;
  final List<String> problemImages;
  final String qtype;
  final List<Map<String, dynamic>> options; // id, text
  final String? myModelAnswer;
  final int? mySelectedOptionId;
  final String? myFreeText;
  final int explanationId;
  final String content;
  final String aiReason;
  final bool crowdFlag;
  _WrongItem({
    required this.problemId,
    required this.problemTitle,
    required this.problemBody,
    required this.problemImages,
    required this.qtype,
    required this.options,
    required this.myModelAnswer,
    required this.mySelectedOptionId,
    required this.myFreeText,
    required this.explanationId,
    required this.content,
    required this.aiReason,
    required this.crowdFlag,
  });
}
