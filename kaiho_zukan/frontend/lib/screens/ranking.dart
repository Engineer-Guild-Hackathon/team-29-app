import 'package:flutter/material.dart';
import '../services/api.dart';

class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});
  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  String metric = 'points';
  List<dynamic> items = [];
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final r = await Api.leaderboardNamed(metric: metric);
    final list = (r['items'] is List) ? List.from(r['items']) : <dynamic>[];
    setState(()=> items = list);
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ランキング')),
      body: Column(children: [
        Row(children: [
          const SizedBox(width: 12), const Text('指標:'),
          DropdownButton<String>(value: metric, items: const [
            DropdownMenuItem(value: 'points', child: Text('ポイント')),
            DropdownMenuItem(value: 'likes', child: Text('いいね')),
          ], onChanged: (v){ setState(()=> metric=v??'points'); _load(); }),
        ]),
        Expanded(child: ListView.builder(
          itemCount: items.length,
          itemBuilder: (_, i){
            final it = items[i];
            return ListTile(leading: Text('${i+1}位'), title: Text(it['nickname'] ?? it['username'] ?? 'user'),
              trailing: Text((it['value'] ?? 0).toString()));
          },
        )),
      ]),
    );
  }
}
