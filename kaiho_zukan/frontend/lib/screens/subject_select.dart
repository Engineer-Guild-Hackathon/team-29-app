import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/api.dart';
import 'home.dart';
import '../widgets/app_icon.dart';

class SubjectSelectScreen extends StatefulWidget {
  final bool isOnboarding;
  const SubjectSelectScreen({super.key, required this.isOnboarding});
  @override
  State<SubjectSelectScreen> createState() => _SubjectSelectScreenState();
}

class _SubjectSelectScreenState extends State<SubjectSelectScreen> {
  List<dynamic> tree = [];
  int? selectedParentId;
  List<int> selectedChildIds = [];
  String q = '';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final t = await Api.categories.tree();
    final me = await Api.users.fetchMe();
    final mine = (me['categories'] is List)
        ? List<int>.from((me['categories'] as List).map((e)=> e['id'] as int))
        : <int>[];
    setState((){
      tree = t;
      selectedChildIds = mine;
      selectedParentId = t.isNotEmpty ? t.first['id'] as int : null;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final parentList = tree;
    final parent = parentList.firstWhere(
      (e) => e['id'] == selectedParentId,
      orElse: () => parentList.isNotEmpty ? parentList.first : null,
    );
    final allChildren = parent!=null ? (parent['children'] as List? ?? []) : [];
    final filtered = allChildren.where((c){
      final name = (c['name'] ?? '').toString();
      return q.isEmpty || name.contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: IconAppBarTitle(
          title: widget.isOnboarding ? '教科を選んで登録' : '教科をえらび直す',
        ),
      ),
      body: loading ? const Center(child: CircularProgressIndicator()) :
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 8, runSpacing: 8, children: [
                const Text('選択した教科：', style: TextStyle(fontWeight: FontWeight.bold)),
                ...selectedChildIds.map((id){
                  final c = parentList.expand((p)=> (p['children'] as List)).firstWhere((x)=> x['id']==id, orElse: ()=> null);
                  final name = c!=null ? c['name'] : 'ID:$id';
                  return Chip(label: Text(name), deleteIcon: const Icon(Icons.close, color: AppColors.danger), onDeleted: (){
                    setState(()=> selectedChildIds.remove(id));
                  });
                }),
              ]),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: '教科名で検索'),
                onChanged: (v)=> setState(()=> q=v.trim()),
              ),
              const SizedBox(height: 12),
              // 親カテゴリ一覧
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: parentList.length,
                  separatorBuilder: (_, __)=> const SizedBox(width: 8),
                  itemBuilder: (_, i){
                    final p = parentList[i];
                    final bool sel = p['id']==selectedParentId;
                    return ChoiceChip(
                      selected: sel,
                      label: Text(p['name']??''),
                      onSelected: (_)=> setState(()=> selectedParentId=p['id'] as int),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              // 教科一覧
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 5),
                  itemCount: filtered.length,
                  itemBuilder: (_, i){
                    final c = filtered[i];
                    final id = c['id'] as int;
                    final bool sel = selectedChildIds.contains(id);
                    return Card(
                      color: sel ? AppColors.light : null,
                      child: ListTile(
                        title: Text(c['name'] ?? ''),
                        trailing: IconButton(
                          icon: Icon(sel ? Icons.close : Icons.add, color: sel ? AppColors.danger : AppColors.info),
                          onPressed: (){
                            setState((){
                              if(sel) { selectedChildIds.remove(id); }
                              else { selectedChildIds.add(id); }
                            });
                          },
                        ),
                        onTap: (){
                          setState((){
                            if(sel) { selectedChildIds.remove(id); }
                            else { selectedChildIds.add(id); }
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final ok = await Api.users.setMyCategories(selectedChildIds);
                    if(!context.mounted) return;
                    if(ok){
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('登録しました')));
                      if (widget.isOnboarding) {
                        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_)=> const HomeScreen()));
                      } else {
                        Navigator.pop(context);
                      }
                    }else{
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('登録に失敗しました'), backgroundColor: AppColors.danger));
                    }
                  },
                  child: const Text('登録する'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
