import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/api.dart';
import '../widgets/app_icon.dart';
import 'home.dart';
import 'subject_select.dart';

class LoginRegisterScreen extends StatefulWidget {
  const LoginRegisterScreen({super.key});

  @override
  State<LoginRegisterScreen> createState() => _LoginRegisterScreenState();
}

class _LoginRegisterScreenState extends State<LoginRegisterScreen> {
  final u = TextEditingController();
  final p = TextEditingController();
  final n = TextEditingController();
  bool isLogin = true;
  String msg = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('ログイン / 新規登録'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(
                  alignment: Alignment.topCenter,
                  child: AppIcon(
                    size: 350,
                    backgroundColor: AppColors.background,
                  ),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: u,
                  decoration: const InputDecoration(labelText: 'ユーザーID'),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: p,
                  decoration: const InputDecoration(labelText: 'パスワード'),
                  obscureText: true,
                  textInputAction: isLogin ? TextInputAction.done : TextInputAction.next,
                ),
                if (!isLogin) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: n,
                    decoration: const InputDecoration(labelText: 'ニックネーム（未入力の場合はIDを使用）'),
                    textInputAction: TextInputAction.done,
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      setState(() => msg = '');
                      if (isLogin) {
                        final r = await Api.auth.login(u.text.trim(), p.text);
                        if (r['access_token'] != null && mounted) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const HomeScreen()),
                          );
                        } else {
                          final detail = (r['detail'] ?? '').toString();
                          setState(() => msg = detail.isNotEmpty
                              ? detail
                              : 'ユーザーIDまたはパスワードが間違っています。');
                        }
                      } else {
                        final r = await Api.auth.register(
                          u.text.trim(),
                          p.text,
                          n.text.trim().isEmpty ? u.text.trim() : n.text.trim(),
                        );
                        if (r['access_token'] != null && mounted) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SubjectSelectScreen(isOnboarding: true),
                            ),
                          );
                        } else {
                          final detail = (r['detail'] ?? '').toString();
                          if (detail.contains('already exists') || detail.contains('already registered')) {
                            setState(() => msg = 'そのユーザーIDは使用されています。');
                          } else {
                            setState(() => msg = detail.isNotEmpty
                                ? detail
                                : '新規登録に失敗しました');
                          }
                        }
                      }
                    },
                    child: Text(isLogin ? 'ログイン' : '新規登録'),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => setState(() => isLogin = !isLogin),
                  child: Text(isLogin ? '新規登録はこちら' : 'ログインはこちら'),
                ),
                const SizedBox(height: 12),
                if (msg.isNotEmpty)
                  Text(
                    msg,
                    style: const TextStyle(color: AppColors.danger),
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}



