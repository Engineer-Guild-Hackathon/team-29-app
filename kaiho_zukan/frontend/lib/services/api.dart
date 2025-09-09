
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Api {
  // ===== Base =====
  static String get base => dotenv.env['API_BASE_URL'] ?? 'http://localhost:8000';

  static String? _token;
  static String? get token => _token;
  static void setToken(String t){ _token = t; }
  static void clearToken(){ _token = null; }

  static Map<String,String> get _jsonHeaders {
    final h = {'Content-Type': 'application/json'};
    if(_token!=null) h['Authorization'] = 'Bearer $_token';
    return h;
  }
  static Map<String,String> get _authHeader {
    final h = <String,String>{};
    if(_token!=null) h['Authorization'] = 'Bearer $_token';
    return h;
  }

  static Future<Map<String,dynamic>> _decode(http.Response r) async {
    try {
      final body = utf8.decode(r.bodyBytes);
      final obj = jsonDecode(body);
      if(obj is Map<String,dynamic>) return obj;
      return {'data': obj};
    } catch (_) {
      return {'status': r.statusCode};
    }
  }

  // ===== Auth =====
  static Future<Map<String,dynamic>> register(String username, String password, String nickname) async {
    final r = await http.post(Uri.parse('$base/auth/register'),
      headers: _jsonHeaders, body: jsonEncode({'username':username,'password':password,'nickname':nickname}));
    final data = await _decode(r);
    if(r.statusCode==200 && data['access_token']!=null) setToken(data['access_token']);
    return data;
  }
  static Future<Map<String,dynamic>> login(String username, String password) async {
    final r = await http.post(Uri.parse('$base/auth/login'),
      headers: _jsonHeaders, body: jsonEncode({'username':username,'password':password}));
    final data = await _decode(r);
    if(r.statusCode==200 && data['access_token']!=null) setToken(data['access_token']);
    return data;
  }
  static Future<Map<String,dynamic>> me() async {
    final r = await http.get(Uri.parse('$base/me'), headers: _authHeader);
    return _decode(r);
  }
  static Future<bool> updateNickname(String nickname) async {
    final t = token;
    final req = http.MultipartRequest('PUT', Uri.parse('$base/me'));
    req.fields['nickname'] = nickname;
    if(t!=null) req.headers['Authorization'] = 'Bearer $t';
    final res = await req.send();
    return res.statusCode==200;
  }

  // ===== Categories =====
  static Future<List<dynamic>> categoryTree() async {
    final r = await http.get(Uri.parse('$base/categories/tree'), headers: _authHeader);
    if(r.statusCode!=200) return [];
    final obj = jsonDecode(utf8.decode(r.bodyBytes));
    return (obj is List) ? obj : [];
  }
  static Future<bool> setMyCategories(List<int> ids) async {
    final r = await http.post(Uri.parse('$base/me/categories'),
      headers: _jsonHeaders, body: jsonEncode(ids));
    return r.statusCode==200;
  }

  // ===== Problems =====
  static Future<Map<String,dynamic>> problemDetail(int pid) async {
    final r = await http.get(Uri.parse('$base/problems/$pid'), headers: _authHeader);
    return _decode(r);
  }
  static Future<Map<String,dynamic>> getProblem(int pid) => problemDetail(pid);

  static Future<Map<String,dynamic>> nextProblem(int childId, int? grandId, {bool includeAnswered=false}) async {
    final ga = (grandId!=null) ? '&grand_id=$grandId' : '';
    final extra = includeAnswered ? '&include_answered=true' : '';
    final r = await http.get(Uri.parse('$base/problems/next?child_id=$childId$ga$extra'), headers: _authHeader);
    return _decode(r);
  }

  // Create problem with images (new helper to support multi-image upload)
  static Future<Map<String,dynamic>> createProblemWithImages({
    required String title,
    String? body,
    required String qtype,
    required int childId,
    required int grandId,
    String? optionsText,
    int? correctIndex,
    String? initialExplanation,
    String? modelAnswer,
    List<({List<int> bytes, String name})>? images,
    String? optionExplanationsText,
    List<String>? optionExplanationsJson,
  }) async {
    final t = token;
    final req = http.MultipartRequest('POST', Uri.parse('$base/problems'));
    req.fields['title'] = title;
    if(body!=null) req.fields['body']=body;
    req.fields['qtype']=qtype;
    req.fields['category_child_id']=childId.toString();
    req.fields['category_grand_id']=grandId.toString();
    if(qtype=='mcq' && optionsText!=null){
      req.fields['options_text']=optionsText;
      req.fields['correct_index']=(correctIndex??0).toString();
    }
    if(modelAnswer!=null && modelAnswer.trim().isNotEmpty){ req.fields['model_answer']=modelAnswer.trim(); }
    if(initialExplanation!=null && initialExplanation.trim().isNotEmpty){ req.fields['initial_explanation']=initialExplanation.trim(); }
    if(optionExplanationsJson!=null){ req.fields['option_explanations_json']=jsonEncode(optionExplanationsJson); }
    else if(optionExplanationsText!=null){ req.fields['option_explanations_text']=optionExplanationsText; }
    if(images!=null){
      for(final f in images){ req.files.add(http.MultipartFile.fromBytes('images', f.bytes, filename: f.name)); }
    }
    if(t!=null) req.headers['Authorization']='Bearer $t';
    final res = await req.send();
    final bodyStr = await res.stream.bytesToString();
    try { return jsonDecode(bodyStr); } catch(_){ return {'status': res.statusCode}; }
  }

  static Future<Map<String,dynamic>> updateProblemWithImages({
    required int id,
    String? title,
    String? body,
    String? qtype,
    int? childId,
    int? grandId,
    String? optionsText,
    int? correctIndex,
    String? modelAnswer,
    String? initialExplanation,
    String? optionExplanationsText,
    List<String>? optionExplanationsJson,
    List<({List<int> bytes, String name})>? images,
  }) async {
    final t = token;
    final req = http.MultipartRequest('PUT', Uri.parse('$base/problems/$id'));
    if(title!=null) req.fields['title']=title;
    if(body!=null) req.fields['body']=body;
    if(qtype!=null) req.fields['qtype']=qtype;
    if(childId!=null) req.fields['category_child_id']=childId.toString();
    if(grandId!=null) req.fields['category_grand_id']=grandId.toString();
    if(optionsText!=null){ req.fields['options_text']=optionsText; req.fields['correct_index']=(correctIndex??0).toString(); }
    if(modelAnswer!=null && modelAnswer.trim().isNotEmpty){ req.fields['model_answer']=modelAnswer.trim(); }
    if(initialExplanation!=null && initialExplanation.trim().isNotEmpty){ req.fields['initial_explanation']=initialExplanation.trim(); }
    if(optionExplanationsJson!=null){ req.fields['option_explanations_json']=jsonEncode(optionExplanationsJson); }
    else if(optionExplanationsText!=null){ req.fields['option_explanations_text']=optionExplanationsText; }
    if(images!=null){ for(final f in images){ req.files.add(http.MultipartFile.fromBytes('images', f.bytes, filename: f.name)); } }
    if(t!=null) req.headers['Authorization']='Bearer $t';
    final res = await req.send();
    final bodyStr = await res.stream.bytesToString();
    try { return jsonDecode(bodyStr);} catch(_){ return {'status': res.statusCode};}
  }

  static Future<Map<String,dynamic>> createProblem({
    required String title,
    String? body,
    required String qtype, // 'mcq' | 'free'
    required int childId,
    required int grandId,
    String? optionsText, // ← 正式
    int? correctIndex,
    String? initialExplanation,
  }) async {
    final t = token;
    final req = http.MultipartRequest('POST', Uri.parse('$base/problems'));
    req.fields['title'] = title;
    if(body!=null) req.fields['body'] = body;
    req.fields['qtype'] = qtype;
    req.fields['category_child_id'] = childId.toString();
    req.fields['category_grand_id'] = grandId.toString();
    if(qtype=='mcq' && optionsText!=null){
      req.fields['options_text'] = optionsText;
      req.fields['correct_index'] = (correctIndex??0).toString();
    }
    if(initialExplanation!=null && initialExplanation.trim().isNotEmpty){
      req.fields['initial_explanation'] = initialExplanation.trim();
    }
    if(t!=null) req.headers['Authorization'] = 'Bearer $t';
    final res = await req.send();
    final bodyStr = await res.stream.bytesToString();
    try { return jsonDecode(bodyStr); } catch(_) { return {'status': res.statusCode}; }
  }
  // 互換: options (旧名) を受けるラッパ
  static Future<Map<String,dynamic>> createProblemMultipart({
    required String title,
    String? body,
    required String qtype,
    required int childId,
    required int grandId,
    String? optionsText,
    String? options, // 旧呼び出し互換
    int? correctIndex,
    String? initialExplanation,
    String? modelAnswer,
    String? optionExplanationsText,
    List<String>? optionExplanationsJson,
  }) async {
    final t = token;
    final req = http.MultipartRequest('POST', Uri.parse('$base/problems'));
    req.fields['title'] = title;
    if(body!=null) req.fields['body'] = body;
    req.fields['qtype'] = qtype;
    req.fields['category_child_id'] = childId.toString();
    req.fields['category_grand_id'] = grandId.toString();
    final opt = optionsText ?? options;
    if(qtype=='mcq' && opt!=null){
      req.fields['options_text'] = opt;
      req.fields['correct_index'] = (correctIndex??0).toString();
    }
    if(initialExplanation!=null && initialExplanation.trim().isNotEmpty){
      req.fields['initial_explanation'] = initialExplanation.trim();
    }
    if(modelAnswer!=null && modelAnswer.trim().isNotEmpty){
      req.fields['model_answer'] = modelAnswer.trim();
    }
    if(optionExplanationsJson!=null){ req.fields['option_explanations_json'] = jsonEncode(optionExplanationsJson); }
    else if(optionExplanationsText!=null){ req.fields['option_explanations_text'] = optionExplanationsText; }
    if(t!=null) req.headers['Authorization'] = 'Bearer $t';
    final res = await req.send();
    final bodyStr = await res.stream.bytesToString();
    try { return jsonDecode(bodyStr); } catch(_) { return {'status': res.statusCode}; }
  }
  // bool を期待する旧コード互換
  static Future<bool> createProblemMultipartOk({
    required String title,
    String? body,
    required String qtype,
    required int childId,
    required int grandId,
    String? optionsText,
    String? options,
    int? correctIndex,
    String? initialExplanation,
  }) async {
    final r = await createProblemMultipart(
      title:title, body:body, qtype:qtype, childId:childId, grandId:grandId,
      optionsText:optionsText, options:options, correctIndex:correctIndex, initialExplanation:initialExplanation);
    return (r['ok']??false)==true;
  }

  static Future<Map<String,dynamic>> updateProblem({
    required int id,
    String? title,
    String? body,
    String? qtype,
    int? childId,
    int? grandId,
    String? optionsText,
    String? options, // 旧名
    int? correctIndex,
  }) async {
    final t = token;
    final req = http.MultipartRequest('PUT', Uri.parse('$base/problems/$id'));
    if(title!=null) req.fields['title']=title;
    if(body!=null) req.fields['body']=body;
    if(qtype!=null) req.fields['qtype']=qtype;
    if(childId!=null) req.fields['category_child_id']=childId.toString();
    if(grandId!=null) req.fields['category_grand_id']=grandId.toString();
    final opt = optionsText ?? options;
    if(opt!=null){ req.fields['options_text']=opt; req.fields['correct_index']=(correctIndex??0).toString(); }
    if(t!=null) req.headers['Authorization']='Bearer $t';
    final res = await req.send();
    final bodyStr = await res.stream.bytesToString();
    try { return jsonDecode(bodyStr);} catch(_){ return {'status': res.statusCode};}
  }

  // V2: with modelAnswer support (non-breaking alongside existing one)
  static Future<Map<String,dynamic>> updateProblemV2({
    required int id,
    String? title,
    String? body,
    String? qtype,
    int? childId,
    int? grandId,
    String? optionsText,
    String? options,
    int? correctIndex,
    String? modelAnswer,
    String? initialExplanation,
    String? optionExplanationsText,
    List<String>? optionExplanationsJson,
  }) async {
    final t = token;
    final req = http.MultipartRequest('PUT', Uri.parse('$base/problems/$id'));
    if(title!=null) req.fields['title']=title;
    if(body!=null) req.fields['body']=body;
    if(qtype!=null) req.fields['qtype']=qtype;
    if(childId!=null) req.fields['category_child_id']=childId.toString();
    if(grandId!=null) req.fields['category_grand_id']=grandId.toString();
    final opt = optionsText ?? options;
    if(opt!=null){ req.fields['options_text']=opt; req.fields['correct_index']=(correctIndex??0).toString(); }
    if(modelAnswer!=null && modelAnswer.trim().isNotEmpty){ req.fields['model_answer']=modelAnswer.trim(); }
    if(initialExplanation!=null && initialExplanation.trim().isNotEmpty){ req.fields['initial_explanation']=initialExplanation.trim(); }
    if(optionExplanationsJson!=null){ req.fields['option_explanations_json']=jsonEncode(optionExplanationsJson); }
    else if(optionExplanationsText!=null){ req.fields['option_explanations_text']=optionExplanationsText; }
    if(t!=null) req.headers['Authorization']='Bearer $t';
    final res = await req.send();
    final bodyStr = await res.stream.bytesToString();
    try { return jsonDecode(bodyStr);} catch(_){ return {'status': res.statusCode};}
  }
  static Future<bool> updateProblemOk({
    required int id,
    String? title,
    String? body,
    String? qtype,
    int? childId,
    int? grandId,
    String? optionsText,
    String? options,
    int? correctIndex,
  }) async {
    final r = await updateProblem(
      id:id, title:title, body:body, qtype:qtype, childId:childId, grandId:grandId,
      optionsText:optionsText, options:options, correctIndex:correctIndex);
    return (r['ok']??false)==true;
  }

  static Future<Map<String,dynamic>> myProblems(String sort) async {
    final r = await http.get(Uri.parse('$base/my/problems?sort=$sort'), headers: _authHeader);
    return _decode(r);
  }

  static Future<bool> likeProblem(int pid) async {
    final r = await http.post(Uri.parse('$base/problems/$pid/like'), headers: _authHeader);
    return r.statusCode==200;
  }
  static Future<bool> unlikeProblem(int pid) async {
    final r = await http.delete(Uri.parse('$base/problems/$pid/like'), headers: _authHeader);
    return r.statusCode==200;
  }
  static Future<bool> likeProblemExplanations(int pid) async {
    final r = await http.post(Uri.parse('$base/problems/$pid/explanations/like'), headers: _authHeader);
    return r.statusCode==200;
  }
  static Future<bool> unlikeProblemExplanations(int pid) async {
    final r = await http.delete(Uri.parse('$base/problems/$pid/explanations/like'), headers: _authHeader);
    return r.statusCode==200;
  }

  // ===== Answers =====
  static Future<Map<String,dynamic>> answer(int pid, {int? selectedOptionId, int? optionId, String? freeText, bool? isCorrect}) async {
    final sel = optionId ?? selectedOptionId;
    final t = token;
    final req = http.MultipartRequest('POST', Uri.parse('$base/problems/$pid/answer'));
    if(sel!=null) req.fields['selected_option_id'] = sel.toString();
    if(freeText!=null) req.fields['free_text'] = freeText;
    if(isCorrect!=null) req.fields['is_correct'] = isCorrect.toString();
    if(t!=null) req.headers['Authorization'] = 'Bearer $t';
    final res = await req.send();
    final body = await res.stream.bytesToString();
    try { return jsonDecode(body); } catch(_) { return {'status': res.statusCode}; }
  }

  // ===== Explanations =====
  static Future<List<dynamic>> explanations(int pid, String sort) async {
    final r = await http.get(Uri.parse('$base/problems/$pid/explanations?sort=$sort'), headers: _authHeader);
    if(r.statusCode!=200) return [];
    final obj = jsonDecode(utf8.decode(r.bodyBytes));
    return (obj is Map && obj['items'] is List) ? List.from(obj['items']) : <dynamic>[];
  }
  static Future<bool> postExplanation(int pid, String content) async {
    final t = token;
    final req = http.MultipartRequest('POST', Uri.parse('$base/problems/$pid/explanations'));
    req.fields['content'] = content;
    if(t!=null) req.headers['Authorization'] = 'Bearer $t';
    final res = await req.send();
    return res.statusCode==200;
  }
  static Future<bool> createExplanation(int pid, String content) => postExplanation(pid, content);
  static Future<bool> likeExplanation(int eid) async {
    final r = await http.post(Uri.parse('$base/explanations/$eid/like'), headers: _authHeader);
    return r.statusCode==200;
  }
  static Future<bool> unlikeExplanation(int eid) async {
    final r = await http.delete(Uri.parse('$base/explanations/$eid/like'), headers: _authHeader);
    return r.statusCode==200;
  }
  static Future<List<dynamic>> problemsForExplain({required int childId, int? grandId, String sort='likes'}) async {
    final q = 'child_id=$childId${grandId!=null ? '&grand_id=$grandId' : ''}&sort=$sort';
    final r = await http.get(Uri.parse('$base/problems/for-explain?$q'), headers: _authHeader);
    if(r.statusCode!=200) return [];
    final obj = jsonDecode(utf8.decode(r.bodyBytes));
    return (obj is Map && obj['items'] is List) ? List.from(obj['items']) : <dynamic>[];
  }
  static Future<List<dynamic>> myExplanationProblems() async {
    final r = await http.get(Uri.parse('$base/my/explanations/problems'), headers: _authHeader);
    if(r.statusCode!=200) return [];
    final obj = jsonDecode(utf8.decode(r.bodyBytes));
    return (obj is Map && obj['items'] is List) ? List.from(obj['items']) : <dynamic>[];
  }
  static Future<Map<String,dynamic>> myExplanations(int pid) async {
    final r = await http.get(Uri.parse('$base/problems/$pid/my-explanations'), headers: _authHeader);
    return _decode(r);
  }

  // ===== Leaderboard / Review =====
  // 旧: leaderboard(metric:'points') → 下の named 用に誘導
  static Future<Map<String,dynamic>> leaderboard(String metric) async {
    final r = await http.get(Uri.parse('$base/leaderboard?metric=$metric'), headers: _authHeader);
    return _decode(r);
  }
  // named パラメータ互換
  static Future<Map<String,dynamic>> leaderboardNamed({required String metric}) => leaderboard(metric);
  // 引数なしで呼ばれても動く互換
  static Future<Map<String,dynamic>> leaderboard0() => leaderboard('points');

  static Future<Map<String,dynamic>> reviewStats(int categoryId, {int? grandId}) async {
    final q = 'category_id=$categoryId${grandId!=null ? '&grand_id=$grandId' : ''}';
    final r = await http.get(Uri.parse('$base/review/stats?$q'), headers: _authHeader);
    return _decode(r);
  }
  // 旧名互換
  static Future<Map<String,dynamic>> stats(int categoryId) => reviewStats(categoryId);

  static Future<Map<String,dynamic>> reviewHistory({required int categoryId, int? grandId}) async {
    final q = 'category_id=$categoryId${grandId!=null ? '&grand_id=$grandId' : ''}';
    final r = await http.get(Uri.parse('$base/review/history?$q'), headers: _authHeader);
    return _decode(r);
  }
  static Future<Map<String,dynamic>> reviewItem(int pid) async {
    final r = await http.get(Uri.parse('$base/review/item?pid=$pid'), headers: _authHeader);
    return _decode(r);
  }
  static Future<bool> reviewMark(int pid, bool isCorrect) async {
    final req = http.MultipartRequest('POST', Uri.parse('$base/review/mark'));
    req.fields['pid'] = pid.toString();
    req.fields['is_correct'] = isCorrect.toString();
    final t = token; if(t!=null) req.headers['Authorization'] = 'Bearer $t';
    final res = await req.send();
    return res.statusCode==200;
  }
}
