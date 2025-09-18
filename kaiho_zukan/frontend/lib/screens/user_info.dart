import 'package:flutter/material.dart';
import '../services/api.dart';
import '../widgets/app_icon.dart';

class UserInfoScreen extends StatefulWidget {
  const UserInfoScreen({super.key});
  @override
  State<UserInfoScreen> createState() => _UserInfoScreenState();
}

class _UserInfoScreenState extends State<UserInfoScreen> {
  bool loading = true;
  String? username;
  final nicknameCtrl = TextEditingController();
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final me = await Api.users.fetchMe();
      username = me['username']?.toString();
      nicknameCtrl.text = (me['nickname'] ?? '').toString();
    } catch (_) {}
    if (!mounted) return;
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const IconAppBarTitle(title: 'ユーザ情報')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ユーザ名: ${username ?? ''}'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nicknameCtrl,
                    decoration: const InputDecoration(labelText: 'ニックネーム'),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        final ok = await Api.users.updateNickname(nicknameCtrl.text.trim());
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content:
                                Text(ok ? '更新しました' : '更新に失敗しました'),
                            backgroundColor: ok ? null : Colors.red));
                      },
                      child: const Text('保存'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
