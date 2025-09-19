import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/api.dart';
import '../widgets/app_icon.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_breadcrumbs.dart';
import 'home.dart';

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
    return AppScaffold(
      title: 'ユーザ情報',
      subHeader: AppBreadcrumbs(
        items: [
          BreadcrumbItem(
            label: 'ホーム',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            ),
          ),
          const BreadcrumbItem(label: 'ユーザ情報'),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ユーザID: ${username ?? ''}'),
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
                            backgroundColor: ok ? null : AppColors.danger));
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
