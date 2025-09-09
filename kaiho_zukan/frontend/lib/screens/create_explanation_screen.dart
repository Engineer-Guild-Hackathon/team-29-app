import 'package:flutter/material.dart';
import '../services/api.dart';

class CreateExplanationScreen extends StatefulWidget {
  const CreateExplanationScreen({super.key});
  @override State<CreateExplanationScreen> createState()=>_S();
}

class _S extends State<CreateExplanationScreen>{
  List<dynamic> tree=[];
  int? parentId=1; // カテゴリ: IT資格
  int? childId;    // 教科
  int? grandId;    // 単元
  String sort='likes';
  List<dynamic> problems=[];
  bool loading=false;

  @override
  void initState(){
    super.initState();
    _loadTree();
  }

  Future<void> _loadTree() async {
    final t = await Api.categoryTree();
    setState(()=>tree=t);
    if(t.isNotEmpty){
      final it = t.firstWhere((n)=>n['name']=='IT資格', orElse: ()=>t.first);
      parentId = it['id'];
      if(it['children']!=null && it['children'].isNotEmpty){
        childId = it['children'][0]['id'];
        if(it['children'][0]['children']!=null && it['children'][0]['children'].isNotEmpty){
          grandId = it['children'][0]['children'][0]['id'];
        }
      }
      await _loadProblems();
    }
  }

  Future<void> _loadProblems() async {
    if(childId==null){ setState(()=>problems=[]); return; }
    setState(()=>loading=true);
    final items = await Api.problemsForExplain(childId: childId!, grandId: grandId, sort: sort);
    setState(()=>problems=items);
    setState(()=>loading=false);
  }

  List<DropdownMenuItem<int>> _childItems(){
    final p = tree.firstWhere((e)=>e['id']==parentId, orElse: ()=>null);
    if(p==null) return [];
    return (p['children'] as List<dynamic>).map((c)=>DropdownMenuItem<int>(value: c['id'], child: Text(c['name']))).toList();
  }

  List<DropdownMenuItem<int>> _grandItems(){
    final p = tree.firstWhere((e)=>e['id']==parentId, orElse: ()=>null);
    if(p==null) return [];
    final ch = (p['children'] as List<dynamic>).firstWhere((c)=>c['id']==childId, orElse: ()=>null);
    if(ch==null) return [];
    return (ch['children'] as List<dynamic>).map((g)=>DropdownMenuItem<int>(value: g['id'], child: Text(g['name']))).toList();
  }

  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(title: const Text('解説を作る')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(spacing: 12, runSpacing: 8, children: [
              DropdownButton<int>(
                value: childId,
                items: _childItems(),
                hint: const Text('教科'),
                onChanged: (v){ setState(()=>childId=v); _loadProblems(); },
              ),
              DropdownButton<int>(
                value: grandId,
                items: _grandItems(),
                hint: const Text('単元'),
                onChanged: (v){ setState(()=>grandId=v); _loadProblems(); },
              ),
              DropdownButton<String>(
                value: sort,
                items: const [
                  DropdownMenuItem(value:'likes', child: Text('いいね順')),
                  DropdownMenuItem(value:'explanations', child: Text('解説数順')),
                  DropdownMenuItem(value:'new', child: Text('新着順')),
                ],
                onChanged: (v){ if(v!=null){ setState(()=>sort=v); _loadProblems(); } },
              ),
              IconButton(onPressed: _loadProblems, icon: const Icon(Icons.refresh), tooltip: '更新')
            ]),
            const SizedBox(height: 12),
            Expanded(
              child: loading
                ? const Center(child: CircularProgressIndicator())
                : problems.isEmpty
                  ? const Center(child: Text('問題がありません'))
                  : ListView.separated(
                      itemCount: problems.length,
                      separatorBuilder: (_, __)=>const Divider(height: 1),
                      itemBuilder: (c, i){
                        final p = problems[i];
                        return ListTile(
                          title: Text(p['title'] ?? ''),
                          subtitle: Text('👍 ${p['likes_count']}  /  解説 ${p['explanation_count']}  /  作成 ${p['created_at']}'),
                          trailing: FilledButton(
                            onPressed: ()=>_openCreateDialog(p['id'], p['title'] ?? ''),
                            child: const Text('解説を書く'),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCreateDialog(int problemId, String title) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (c){
      return AlertDialog(
        title: Text('解説を書く'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(c).textTheme.bodyMedium),
              const SizedBox(height: 8),
              TextField(
                controller: ctrl,
                maxLines: 8,
                decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'つまずきポイント → 根拠 → 具体例 → ひとことコツ'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(c,false), child: const Text('キャンセル')),
          FilledButton(onPressed: () async {
            final content = ctrl.text.trim();
            if(content.isEmpty) return;
            final res = await Api.createExplanation(problemId, content);
            Navigator.pop(c, res);
          }, child: const Text('投稿')),
        ],
      );
    });
    if(ok==true){
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('解説を投稿しました')));
        _loadProblems();
      }
    }
  }
}
