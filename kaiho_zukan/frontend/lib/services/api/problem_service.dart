import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_client.dart';

class ProblemService {
  const ProblemService();

  Future<Map<String, dynamic>> detail(int id) async {
    final response = await http.get(
      Uri.parse('${ApiClient.base}/problems/$id'),
      headers: ApiClient.authHeader,
    );
    return ApiClient.decode(response);
  }

  Future<Map<String, dynamic>> get(int id) => detail(id);

  Future<Map<String, dynamic>> next(
    int childId,
    int? grandId, {
    bool includeAnswered = false,
  }) async {
    final grand = grandId != null ? '&grand_id=$grandId' : '';
    final extra = includeAnswered ? '&include_answered=true' : '';
    final response = await http.get(
      Uri.parse(
        '${ApiClient.base}/problems/next?child_id=$childId$grand$extra',
      ),
      headers: ApiClient.authHeader,
    );
    return ApiClient.decode(response);
  }

  Future<Map<String, dynamic>> createWithImages({
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
    final token = ApiClient.token;
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiClient.base}/problems'),
    );
    request.fields['title'] = title;
    if (body != null) request.fields['body'] = body;
    request.fields['qtype'] = qtype;
    request.fields['category_child_id'] = childId.toString();
    request.fields['category_grand_id'] = grandId.toString();
    if (qtype == 'mcq' && optionsText != null) {
      request.fields['options_text'] = optionsText;
      request.fields['correct_index'] = (correctIndex ?? 0).toString();
    }
    if (modelAnswer != null && modelAnswer.trim().isNotEmpty) {
      request.fields['model_answer'] = modelAnswer.trim();
    }
    if (initialExplanation != null && initialExplanation.trim().isNotEmpty) {
      request.fields['initial_explanation'] = initialExplanation.trim();
    }
    if (optionExplanationsJson != null) {
      request.fields['option_explanations_json'] =
          jsonEncode(optionExplanationsJson);
    } else if (optionExplanationsText != null) {
      request.fields['option_explanations_text'] = optionExplanationsText;
    }
    if (images != null) {
      for (final image in images) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'images',
            image.bytes,
            filename: image.name,
          ),
        );
      }
    }
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    final response = await request.send();
    final bodyStr = await response.stream.bytesToString();
    try {
      return jsonDecode(bodyStr);
    } catch (_) {
      return {'status': response.statusCode};
    }
  }

  Future<Map<String, dynamic>> updateWithImages({
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
    final token = ApiClient.token;
    final request = http.MultipartRequest(
      'PUT',
      Uri.parse('${ApiClient.base}/problems/$id'),
    );
    if (title != null) request.fields['title'] = title;
    if (body != null) request.fields['body'] = body;
    if (qtype != null) request.fields['qtype'] = qtype;
    if (childId != null) {
      request.fields['category_child_id'] = childId.toString();
    }
    if (grandId != null) {
      request.fields['category_grand_id'] = grandId.toString();
    }
    if (optionsText != null) {
      request.fields['options_text'] = optionsText;
      request.fields['correct_index'] = (correctIndex ?? 0).toString();
    }
    if (modelAnswer != null && modelAnswer.trim().isNotEmpty) {
      request.fields['model_answer'] = modelAnswer.trim();
    }
    if (initialExplanation != null && initialExplanation.trim().isNotEmpty) {
      request.fields['initial_explanation'] = initialExplanation.trim();
    }
    if (optionExplanationsJson != null) {
      request.fields['option_explanations_json'] =
          jsonEncode(optionExplanationsJson);
    } else if (optionExplanationsText != null) {
      request.fields['option_explanations_text'] = optionExplanationsText;
    }
    if (images != null) {
      for (final image in images) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'images',
            image.bytes,
            filename: image.name,
          ),
        );
      }
    }
    if (request.fields.isEmpty && request.files.isEmpty) {
      return {'ok': true, 'skipped': true};
    }
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    final response = await request.send();
    final bodyStr = await response.stream.bytesToString();
    try {
      return jsonDecode(bodyStr);
    } catch (_) {
      return {'status': response.statusCode};
    }
  }

  Future<Map<String, dynamic>> create({
    required String title,
    String? body,
    required String qtype,
    required int childId,
    required int grandId,
    String? optionsText,
    int? correctIndex,
    String? initialExplanation,
  }) async {
    final token = ApiClient.token;
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiClient.base}/problems'),
    );
    request.fields['title'] = title;
    if (body != null) request.fields['body'] = body;
    request.fields['qtype'] = qtype;
    request.fields['category_child_id'] = childId.toString();
    request.fields['category_grand_id'] = grandId.toString();
    if (qtype == 'mcq' && optionsText != null) {
      request.fields['options_text'] = optionsText;
      request.fields['correct_index'] = (correctIndex ?? 0).toString();
    }
    if (initialExplanation != null && initialExplanation.trim().isNotEmpty) {
      request.fields['initial_explanation'] = initialExplanation.trim();
    }
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    final response = await request.send();
    final bodyStr = await response.stream.bytesToString();
    try {
      return jsonDecode(bodyStr);
    } catch (_) {
      return {'status': response.statusCode};
    }
  }

  Future<Map<String, dynamic>> createMultipart({
    required String title,
    String? body,
    required String qtype,
    required int childId,
    required int grandId,
    String? optionsText,
    String? options,
    int? correctIndex,
    String? initialExplanation,
    String? modelAnswer,
    String? optionExplanationsText,
    List<String>? optionExplanationsJson,
  }) async {
    final token = ApiClient.token;
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiClient.base}/problems'),
    );
    request.fields['title'] = title;
    if (body != null) request.fields['body'] = body;
    request.fields['qtype'] = qtype;
    request.fields['category_child_id'] = childId.toString();
    request.fields['category_grand_id'] = grandId.toString();
    final opt = optionsText ?? options;
    if (qtype == 'mcq' && opt != null) {
      request.fields['options_text'] = opt;
      request.fields['correct_index'] = (correctIndex ?? 0).toString();
    }
    if (initialExplanation != null && initialExplanation.trim().isNotEmpty) {
      request.fields['initial_explanation'] = initialExplanation.trim();
    }
    if (modelAnswer != null && modelAnswer.trim().isNotEmpty) {
      request.fields['model_answer'] = modelAnswer.trim();
    }
    if (optionExplanationsJson != null) {
      request.fields['option_explanations_json'] =
          jsonEncode(optionExplanationsJson);
    } else if (optionExplanationsText != null) {
      request.fields['option_explanations_text'] = optionExplanationsText;
    }
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    final response = await request.send();
    final bodyStr = await response.stream.bytesToString();
    try {
      return jsonDecode(bodyStr);
    } catch (_) {
      return {'status': response.statusCode};
    }
  }

  Future<bool> createMultipartOk({
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
    final response = await createMultipart(
      title: title,
      body: body,
      qtype: qtype,
      childId: childId,
      grandId: grandId,
      optionsText: optionsText,
      options: options,
      correctIndex: correctIndex,
      initialExplanation: initialExplanation,
    );
    return (response['ok'] ?? false) == true;
  }

  Future<Map<String, dynamic>> update({
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
    final token = ApiClient.token;
    final request = http.MultipartRequest(
      'PUT',
      Uri.parse('${ApiClient.base}/problems/$id'),
    );
    if (title != null) request.fields['title'] = title;
    if (body != null) request.fields['body'] = body;
    if (qtype != null) request.fields['qtype'] = qtype;
    if (childId != null) {
      request.fields['category_child_id'] = childId.toString();
    }
    if (grandId != null) {
      request.fields['category_grand_id'] = grandId.toString();
    }
    final opt = optionsText ?? options;
    if (opt != null) {
      request.fields['options_text'] = opt;
      request.fields['correct_index'] = (correctIndex ?? 0).toString();
    }
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    final response = await request.send();
    final bodyStr = await response.stream.bytesToString();
    try {
      return jsonDecode(bodyStr);
    } catch (_) {
      return {'status': response.statusCode};
    }
  }

  Future<Map<String, dynamic>> updateV2({
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
    final token = ApiClient.token;
    final request = http.MultipartRequest(
      'PUT',
      Uri.parse('${ApiClient.base}/problems/$id'),
    );
    if (title != null) request.fields['title'] = title;
    if (body != null) request.fields['body'] = body;
    if (qtype != null) request.fields['qtype'] = qtype;
    if (childId != null) {
      request.fields['category_child_id'] = childId.toString();
    }
    if (grandId != null) {
      request.fields['category_grand_id'] = grandId.toString();
    }
    final opt = optionsText ?? options;
    if (opt != null) {
      request.fields['options_text'] = opt;
      request.fields['correct_index'] = (correctIndex ?? 0).toString();
    }
    if (modelAnswer != null && modelAnswer.trim().isNotEmpty) {
      request.fields['model_answer'] = modelAnswer.trim();
    }
    if (initialExplanation != null && initialExplanation.trim().isNotEmpty) {
      request.fields['initial_explanation'] = initialExplanation.trim();
    }
    if (optionExplanationsJson != null) {
      request.fields['option_explanations_json'] =
          jsonEncode(optionExplanationsJson);
    } else if (optionExplanationsText != null) {
      request.fields['option_explanations_text'] = optionExplanationsText;
    }
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    final response = await request.send();
    final bodyStr = await response.stream.bytesToString();
    try {
      return jsonDecode(bodyStr);
    } catch (_) {
      return {'status': response.statusCode};
    }
  }

  Future<bool> updateOk({
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
    final response = await update(
      id: id,
      title: title,
      body: body,
      qtype: qtype,
      childId: childId,
      grandId: grandId,
      optionsText: optionsText,
      options: options,
      correctIndex: correctIndex,
    );
    return (response['ok'] ?? false) == true;
  }

  Future<Map<String, dynamic>> myProblems(String sort) async {
    final response = await http.get(
      Uri.parse('${ApiClient.base}/my/problems?sort=$sort'),
      headers: ApiClient.authHeader,
    );
    return ApiClient.decode(response);
  }

  Future<bool> like(int id) async {
    final response = await http.post(
      Uri.parse('${ApiClient.base}/problems/$id/like'),
      headers: ApiClient.authHeader,
    );
    return response.statusCode == 200;
  }

  Future<bool> unlike(int id) async {
    final response = await http.delete(
      Uri.parse('${ApiClient.base}/problems/$id/like'),
      headers: ApiClient.authHeader,
    );
    return response.statusCode == 200;
  }

  Future<bool> likeExplanations(int id) async {
    final response = await http.post(
      Uri.parse('${ApiClient.base}/problems/$id/explanations/like'),
      headers: ApiClient.authHeader,
    );
    return response.statusCode == 200;
  }

  Future<bool> unlikeExplanations(int id) async {
    final response = await http.delete(
      Uri.parse('${ApiClient.base}/problems/$id/explanations/like'),
      headers: ApiClient.authHeader,
    );
    return response.statusCode == 200;
  }

  Future<Map<String, dynamic>> answer(
    int id, {
    int? selectedOptionId,
    int? optionId,
    String? freeText,
    bool? isCorrect,
  }) async {
    final selected = optionId ?? selectedOptionId;
    final token = ApiClient.token;
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiClient.base}/problems/$id/answer'),
    );
    if (selected != null) {
      request.fields['selected_option_id'] = selected.toString();
    }
    if (freeText != null) {
      request.fields['free_text'] = freeText;
    }
    if (isCorrect != null) {
      request.fields['is_correct'] = isCorrect.toString();
    }
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    final response = await request.send();
    final body = await response.stream.bytesToString();
    try {
      return jsonDecode(body);
    } catch (_) {
      return {'status': response.statusCode};
    }
  }

  Future<List<dynamic>> problemsForExplain({
    required int childId,
    int? grandId,
    String sort = 'likes',
  }) async {
    final grand = grandId != null ? '&grand_id=$grandId' : '';
    final response = await http.get(
      Uri.parse(
        '${ApiClient.base}/problems/for-explain?child_id=$childId$grand&sort=$sort',
      ),
      headers: ApiClient.authHeader,
    );
    if (response.statusCode != 200) return [];
    final obj = jsonDecode(utf8.decode(response.bodyBytes));
    return (obj is Map && obj['items'] is List)
        ? List<dynamic>.from(obj['items'] as List)
        : <dynamic>[];
  }

  Future<bool> delete(int id) async {
    final response = await http.delete(
      Uri.parse('${ApiClient.base}/problems/$id'),
      headers: ApiClient.authHeader,
    );
    return response.statusCode == 200;
  }
}
