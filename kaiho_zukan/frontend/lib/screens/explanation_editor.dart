import 'package:flutter/material.dart';
import '../services/api.dart';

class ExplanationEditorScreen extends StatefulWidget {
  final int problemId;
  const ExplanationEditorScreen({super.key, required this.problemId});
  @override State<ExplanationEditorScreen> createState()=>_S();
}

class _S extends State<ExplanationEditorScreen>{
  Map<String,dynamic>? problem;
  final overallCtrl = TextEditingController();
  List<TextEditingController> optionCtrls = [];
  bool loading=true; bool saving=false;
  String? correctAnswer;

  @override void initState(){ super.initState(); _load(); }
  Future<void> _load() async{
    setState(()=>loading=true);
    final p = await Api.problemDetail(widget.problemId);
    final me = await Api.myExplanations(widget.problemId);
    setState(()=>problem=p);
    final opts = (p['options'] as List<dynamic>? ?? []);
    optionCtrls = List.generate(opts.length, (_) => TextEditingController());
    if(me['overall'] is String){ overallCtrl.text = (me['overall'] as String); }
    if(me['options'] is List){
      final list = List.from(me['options']);
      for(int i=0;i<list.length && i<optionCtrls.length;i++){
        final v = list[i]; if(v is String){ optionCtrls[i].text = v; }
      }
    }
    // set correct answer (problem's answer)
    String kanaOf(int i){ const k=['ア','イ','ウ','エ','オ','カ','キ','ク','ケ','コ']; return (i>=0 && i<k.length)? k[i] : '選択肢${i+1}'; }
    if((p['qtype']??'')=='mcq'){
      final idx = opts.indexWhere((o)=> (o['is_correct']==true));
      if(idx>=0) correctAnswer = kanaOf(idx);
    } else {
      if(p['model_answer'] is String && (p['model_answer'] as String).trim().isNotEmpty){
        correctAnswer = p['model_answer'];
      } else {
        correctAnswer = null; // 非公開/未設定
      }
    }
    setState(()=>loading=false);
  }

  Future<void> _save() async{
    if(problem==null) return;
    setState(()=>saving=true);
    final list = optionCtrls.map((c)=> c.text.trimRight()).toList();
    final r = await Api.updateProblemV2(
      id: problem!['id'] as int,
      initialExplanation: overallCtrl.text.trim().isEmpty? null : overallCtrl.text.trim(),
      optionExplanationsJson: list,
    );
    setState(()=>saving=false);
    if(!mounted) return;
    if((r['ok']??false)==true){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('保存しました')));
      Navigator.pop(context);
    }else{
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('保存に失敗しました'), backgroundColor: Colors.red));
    }
  }

  @override Widget build(BuildContext c){
    return Scaffold(appBar: AppBar(title: const Text('解説を編集')), body:
      loading ? const Center(child: CircularProgressIndicator())
      : Padding(padding: const EdgeInsets.all(16), child: ListView(children:[
          Text(problem?['title'] ?? '', style: Theme.of(c).textTheme.titleLarge),
          const SizedBox(height: 6),
          if((problem?['body']??'').toString().isNotEmpty) Text(problem!['body']),
          const SizedBox(height: 8),
          if(correctAnswer!=null) ...[
            const Text('問題の答え', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(correctAnswer!),
            const SizedBox(height: 8),
          ],
          const Divider(),
          if(problem?['qtype']=='mcq') ...[
            const Text('選択肢', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            ...List.generate((problem?['options'] as List).length, (i){
              final o = (problem!['options'] as List)[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
                  Text('選択肢 ${i+1}: ${o['content'] ?? o['text'] ?? ''}', style: const TextStyle(color: Colors.black87)),
                  const SizedBox(height: 6),
                  TextField(controller: optionCtrls[i], minLines: 2, maxLines: 5, decoration: const InputDecoration(labelText: 'この選択肢の解説', border: OutlineInputBorder())),
                ]),
              );
            }),
          ],
          const SizedBox(height: 8),
          TextField(controller: overallCtrl, minLines: 3, maxLines: 8, decoration: const InputDecoration(labelText: '（全体の解説）', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: saving? null : _save, child: Text(saving? '保存中...' : '保存する')))
      ]))
    );
  }
}
