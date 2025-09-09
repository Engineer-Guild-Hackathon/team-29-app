import 'package:flutter/material.dart';
import '../services/api.dart';

class CategorySelectionScreen extends StatefulWidget { const CategorySelectionScreen({super.key}); @override State<CategorySelectionScreen> createState()=>_S(); }
class _S extends State<CategorySelectionScreen>{
  List<dynamic> tree=[];
  Set<int> selected = {};
  bool loading=true, saving=false;

  @override void initState(){ super.initState(); _load(); }
  Future<void> _load() async {
    final t = await Api.categoryTree();
    setState(()=>tree=t); loading=false;
  }

  @override Widget build(BuildContext c){
    return Scaffold(
      appBar: AppBar(title: const Text('学びたい分野を選択')),
      body: loading? const Center(child:CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('カテゴリ → 教科 → 単元 から、いくつでも選べます', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              Expanded(child: _buildTree()),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: saving? null : () async {
                  setState(()=>saving=true);
                  final ok = await Api.setMyCategories(selected.toList());
                  setState(()=>saving=false);
                  if(ok && mounted) Navigator.pushReplacementNamed(context, '/home');
                },
                icon: const Icon(Icons.check),
                label: Text('この内容で始める（'+selected.length.toString()+'件）'),
              )
            ]),
          ),
    );
  }

  Widget _buildTree(){
    if(tree.isEmpty) return const Center(child: Text('カテゴリが未設定です'));
    final roots = tree;
    return ListView(
      children: roots.map<Widget>((root) => ExpansionTile(
        initiallyExpanded: true,
        title: Text('カテゴリ: '+(root['name']??''), style: const TextStyle(fontWeight: FontWeight.bold)),
        children: [
          ...(root['children'] as List<dynamic>).map<Widget>((child) => ExpansionTile(
            title: Row(children:[
              Expanded(child: Text('教科: '+(child['name']??''))),
              Checkbox(value: selected.contains(child['id']), onChanged: (v){
                setState(()=> v==true ? selected.add(child['id']) : selected.remove(child['id']));
              }),
            ]),
            children: [
              ...((child['children'] as List<dynamic>)).map((grand) => CheckboxListTile(
                title: Text('単元: '+(grand['name']??'')),
                value: selected.contains(grand['id']),
                onChanged: (v){ setState(()=> v==true ? selected.add(grand['id']) : selected.remove(grand['id'])); },
              ))
            ],
          ))
        ],
      )).toList(),
    );
  }
}
