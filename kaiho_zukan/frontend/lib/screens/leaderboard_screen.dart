import 'package:flutter/material.dart';
import '../services/api.dart';

class LeaderboardScreen extends StatefulWidget { const LeaderboardScreen({super.key}); @override State<LeaderboardScreen> createState()=>_S(); }
class _S extends State<LeaderboardScreen>{
  String metric='points'; List<dynamic> items=[]; bool loading=true;
  @override void initState(){ super.initState(); _load(); }
  Future<void> _load() async {
    final r = await Api.leaderboard(metric);
    setState(() => items = r['items'] ?? []);
    setState(() => loading = false);
  }
  @override Widget build(BuildContext c){
    return Scaffold(appBar: AppBar(title: const Text('ランキング')), body:
      Column(children:[
        Row(children:[
          const SizedBox(width: 16),
          const Text('指標: '),
          DropdownButton<String>(value: metric, items: const [
            DropdownMenuItem(value:'points', child: Text('ポイント')),
            DropdownMenuItem(value:'likes', child: Text('いいね合計')),
            DropdownMenuItem(value:'created', child: Text('投稿数')),
          ], onChanged:(v){ if(v!=null){ setState(()=>metric=v); loading=true; items=[]; _load(); }}),
        ]),
        const Divider(),
        Expanded(child: loading? const Center(child: CircularProgressIndicator())
          : ListView.builder(itemCount: items.length, itemBuilder: (_, i){
              final it = items[i];
              return ListTile(leading: Text('${i+1}'), title: Text(it['nickname']??'-'), trailing: Text('${it['score']??0}'));
            }))
      ])
    );
  }
}
