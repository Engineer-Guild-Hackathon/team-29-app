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
      appBar: AppBar(title: const IconAppBarTitle(title: '解法図鑑 - ログイン / 新規登録')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(controller: u, decoration: const InputDecoration(labelText: 'ユーザーID')),
                const SizedBox(height: 8),
                TextField(controller: p, decoration: const InputDecoration(labelText: 'パスワード'), obscureText: true),
                if(!isLogin)...[
                  const SizedBox(height: 8),
                  TextField(controller: n, decoration: const InputDecoration(labelText: 'ニックネーム（空ならID）')),
                ],
                const SizedBox(height: 16),
                ElevatedButton(onPressed: () async {
                  setState(()=> msg='');
                  if(isLogin){
                    final r = await Api.auth.login(u.text.trim(), p.text);
                    if(r['access_token']!=null && mounted){
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_)=> const HomeScreen()));
                    } else { setState(()=> msg='ログイン失敗'); }
                  } else {
                    final r = await Api.auth.register(u.text.trim(), p.text, n.text.trim().isEmpty? u.text.trim() : n.text.trim());
                    if(r['access_token']!=null && mounted){
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_)=> const SubjectSelectScreen(isOnboarding: true)));
                    } else { setState(()=> msg='登録失敗'); }
                  }
                }, child: Text(isLogin? 'ログイン' : '新規登録')),
                const SizedBox(height: 8),
                TextButton(onPressed: ()=> setState(()=> isLogin=!isLogin), child: Text(isLogin? '新規登録はこちら' : 'ログインはこちら')),
                const SizedBox(height: 8),
                Text(msg, style: const TextStyle(color: AppColors.danger)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
