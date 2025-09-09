import 'package:flutter/material.dart';
import '../services/api.dart';
import 'category_screen.dart';
import 'subject_picker_screen.dart';

class LoginScreen extends StatefulWidget { const LoginScreen({super.key}); @override State<LoginScreen> createState()=>_S(); }
class _S extends State<LoginScreen>{
  final u=TextEditingController(), p=TextEditingController(), n=TextEditingController();
  bool isLogin=true, loading=false; String? err;
  @override Widget build(BuildContext c){
    return Scaffold(
      appBar: AppBar(title: Text(isLogin? 'ログイン':'新規登録')),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420),child: Padding(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: u, decoration: const InputDecoration(labelText: 'ID / ユーザー名')),
        if(!isLogin) TextField(controller: n, decoration: const InputDecoration(labelText: 'ニックネーム')),
        TextField(controller: p, decoration: const InputDecoration(labelText: 'パスワード'), obscureText: true),
        const SizedBox(height: 12),
        if(err!=null) Text(err!, style: const TextStyle(color: Colors.red)),
        FilledButton(onPressed: loading? null: () async{
          setState(()=>loading=true); bool ok=false;
          if(isLogin){ final res = await Api.login(u.text, p.text); ok = res['success'] == true; }
          else {
            final res = await Api.register(u.text, p.text, n.text);
            ok = res['success'] == true;
          }
          setState(()=>loading=false);
          if(ok && mounted){ if(isLogin) Navigator.pushReplacementNamed(context, '/home'); else Navigator.pushReplacement(context, MaterialPageRoute(builder:(_)=>const SubjectPickerScreen(fromRegistration:true))); }
          else setState(()=>err='失敗しました');
        }, child: Text(isLogin? 'ログイン' : '登録')),
        TextButton(onPressed: ()=>setState(()=>isLogin=!isLogin), child: Text(isLogin? '新規登録する' : 'ログインに切替'))
      ])))));
  }
}
