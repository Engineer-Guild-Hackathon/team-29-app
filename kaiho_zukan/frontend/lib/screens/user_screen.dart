
import 'package:flutter/material.dart';
import '../services/api.dart';
import 'subject_picker_screen.dart';

class UserScreen extends StatefulWidget { const UserScreen({super.key}); @override State<UserScreen> createState()=>_S(); }
class _S extends State<UserScreen>{
  Map<String,dynamic>? me;
  final nicknameCtrl = TextEditingController();
  bool loading=true, saving=false;

  @override void initState(){ super.initState(); _load(); }

  Future<void> _load() async {
    setState(()=>loading=true);
    final m = await Api.me();
    me = m;
    nicknameCtrl.text = m['nickname'] ?? '';
    setState(()=>loading=false);
  }

  @override Widget build(BuildContext c){
    return Scaffold(
      appBar: AppBar(title: const Text('ユーザ情報')),
      body: loading ? const Center(child: CircularProgressIndicator()) : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('アカウント', style: Theme.of(c).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('ユーザー名: ${me?['username'] ?? '-'}'),
            const SizedBox(height: 8),
            TextField(controller: nicknameCtrl, decoration: const InputDecoration(labelText: 'ニックネーム', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            FilledButton.icon(onPressed: saving? null : () async {
              setState(()=>saving=true);
              final ok = await Api.updateNickname(nicknameCtrl.text.trim());
              setState(()=>saving=false);
              if(ok){ ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content: Text('ニックネームを更新しました'))); }
            }, icon: const Icon(Icons.save), label: const Text('保存')),
          ]))),
          const SizedBox(height: 12),
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('学ぶ教科', style: Theme.of(c).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text('現在選択中の教科は「教科を選び直す」から確認・変更できます。'),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_)=>const SubjectPickerScreen()));
                if(mounted) _load(); // 反映
              },
              icon: const Icon(Icons.menu_book),
              label: const Text('教科を選び直す'),
            ),
          ]))),
        ],
      ),
    );
  }
}
