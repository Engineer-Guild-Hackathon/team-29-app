
import 'package:flutter/material.dart';
import '../services/api.dart';

/// 教科（親カテゴリ配下の子カテゴリ）を選ぶ共通画面。
/// - 新規登録後にも使う
/// - ユーザ情報から「教科を選び直す」でも使う
class SubjectPickerScreen extends StatefulWidget {
  final bool fromRegistration;
  const SubjectPickerScreen({super.key, this.fromRegistration=false});

  @override
  State<SubjectPickerScreen> createState() => _S();
}

class _S extends State<SubjectPickerScreen>{
  final q = TextEditingController();
  List<dynamic> tree = []; // categories tree
  Map<int, String> parentMap = {}; // parent_id -> name
  List<dynamic> parents = []; // 親カテゴリ一覧
  int? currentParentId; // 選択中の親カテゴリ（カテゴリ）
  Set<int> selected = {}; // 選択済みの教科（子カテゴリID）
  bool loading = true;
  bool saving = false;

  @override
  void initState(){
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(()=>loading=true);
    final t = await Api.categoryTree();
    final me = await Api.me(); // 既存の選択（教科）を初期選択

    tree = t;
    // 親カテゴリ（parent_id == null）
    parents = t.map((e)=>{'id': e['id'], 'name': e['name']}).toList();
    // 既に登録されている教科（=親が親カテゴリのもの）を選択状態に
    if(me['categories']!=null){
      for(final c in (me['categories'] as List)){
        final pid = c['parent_id'];
        // 親が null のものは親カテゴリ、親があるものは教科 or 単元。
        // 教科は「親が親カテゴリ(null)の直下」なので、親の親が null。
        // しかし /me は親の親の情報までは持ってないため、tree から判定する:
        final isChild = _isChildCategory(c['id']);
        if(isChild) selected.add(c['id']);
      }
    }
    setState(()=>loading=false);
  }

  bool _isChildCategory(int id){
    // tree を走査して「親が root（parent_id==null）」の直下にいるかを調べる
    for(final root in tree){
      if(root['children'] is List){
        for(final child in (root['children'] as List)){
          if(child['id']==id) return true;
        }
      }
    }
    return false;
  }

  List<dynamic> _childrenOf(int parentId){
    final p = tree.firstWhere((e)=>e['id']==parentId, orElse: ()=>null);
    if(p==null) return [];
    return (p['children'] as List<dynamic>? ?? []);
  }

  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(title: const Text('教科を選ぶ')),
      body: loading ? const Center(child: CircularProgressIndicator()) : Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 選択した教科
            const Text('選択した教科：', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _selectedChips(),
            const SizedBox(height: 16),

            // 検索フォーム
            TextField(
              controller: q,
              onChanged: (_){ setState((){}); },
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: '教科名で検索',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // 親カテゴリ一覧 or 教科一覧
            if(currentParentId == null) ...[
              const Text('カテゴリ', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Expanded(child: ListView.separated(
                itemCount: parents.length,
                separatorBuilder: (_, __)=>const SizedBox(height: 8),
                itemBuilder: (_, i){
                  final c = parents[i];
                  return Card(
                    child: ListTile(
                      title: Text(c['name']),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: ()=>setState(()=>currentParentId = c['id']),
                    ),
                  );
                },
              ))
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('教科', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    onPressed: ()=>setState(()=>currentParentId = null),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('カテゴリ選択に戻る'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(child: _subjectList()),
            ],

            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: saving? null : () async {
                setState(()=>saving=true);
                final ok = await Api.setMyCategories(selected.toList());
                setState(()=>saving=false);
                if(!mounted) return;
                if(ok){
                  if(widget.fromRegistration){
                    Navigator.pushReplacementNamed(context, '/home');
                  }else{
                    Navigator.pop(context, true);
                  }
                }else{
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('登録に失敗しました')));
                }
              },
              icon: const Icon(Icons.check),
              label: const Text('登録する'),
            )
          ],
        ),
      ),
    );
  }

  Widget _selectedChips(){
    if(selected.isEmpty) return const Text('（未選択）');
    // id -> name 解決のため、tree を走査して名前を引く
    final selectedNames = <int, String>{};
    for(final root in tree){
      for(final child in (root['children'] as List<dynamic>? ?? [])){
        if(selected.contains(child['id'])){
          selectedNames[child['id']] = child['name'];
        }
      }
    }
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: selected.map((id){
        final name = selectedNames[id] ?? 'ID:$id';
        return Chip(
          label: Text(name),
          deleteIcon: const Icon(Icons.close, color: Colors.red),
          onDeleted: (){ setState(()=>selected.remove(id)); },
        );
      }).toList(),
    );
  }

  Widget _subjectList(){
    final children = _childrenOf(currentParentId!);
    final kw = q.text.trim().toLowerCase();
    final filtered = kw.isEmpty
      ? children
      : children.where((c)=> (c['name'] ?? '').toString().toLowerCase().contains(kw)).toList();
    if(filtered.isEmpty){
      return const Center(child: Text('対象の教科がありません'));
    }
    return ListView.separated(
      itemCount: filtered.length,
      separatorBuilder: (_, __)=>const SizedBox(height: 8),
      itemBuilder: (_, i){
        final c = filtered[i];
        final sel = selected.contains(c['id']);
        return Card(
          color: sel ? Colors.green.shade50 : null,
          child: ListTile(
            title: Text(c['name'] ?? ''),
            trailing: IconButton(
              icon: Icon(sel ? Icons.close : Icons.add, color: sel ? Colors.red : null),
              onPressed: (){
                setState(()=> sel ? selected.remove(c['id']) : selected.add(c['id']));
              },
            ),
            onTap: (){
              setState(()=> sel ? selected.remove(c['id']) : selected.add(c['id']));
            },
          ),
        );
      },
    );
  }
}
