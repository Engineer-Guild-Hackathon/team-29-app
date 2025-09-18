import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_client.dart';

class ExplanationService {
  const ExplanationService();

  Future<bool> createWithImages({
    required int problemId,
    required String content,
    List<({List<int> bytes, String name})>? images,
  }) async {
    final token = ApiClient.token;
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiClient.base}/problems/$problemId/explanations'),
    );
    request.fields['content'] = content;
    if (images != null && images.isNotEmpty) {
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
    return response.statusCode == 200;
  }

  Future<List<dynamic>> list(int problemId, String sort) async {
    final response = await http.get(
      Uri.parse(
        '${ApiClient.base}/problems/$problemId/explanations?sort=$sort',
      ),
      headers: ApiClient.authHeader,
    );
    if (response.statusCode != 200) return [];
    final obj = jsonDecode(utf8.decode(response.bodyBytes));
    return (obj is Map && obj['items'] is List)
        ? List<dynamic>.from(obj['items'] as List)
        : <dynamic>[];
  }

  Future<bool> create(int problemId, String content) async {
    final token = ApiClient.token;
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiClient.base}/problems/$problemId/explanations'),
    );
    request.fields['content'] = content;
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    final response = await request.send();
    return response.statusCode == 200;
  }

  Future<bool> like(int id) async {
    final response = await http.post(
      Uri.parse('${ApiClient.base}/explanations/$id/like'),
      headers: ApiClient.authHeader,
    );
    return response.statusCode == 200;
  }

  Future<Map<String, dynamic>> update({
    required int id,
    String? content,
    bool clearImages = false,
    List<({List<int> bytes, String name})>? images,
  }) async {
    final token = ApiClient.token;
    final request = http.MultipartRequest(
      'PUT',
      Uri.parse('${ApiClient.base}/explanations/$id'),
    );
    if (content != null) {
      request.fields['content'] = content;
    }
    if (clearImages) {
      request.fields['clear_images'] = 'true';
    }
    if (images != null && images.isNotEmpty) {
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

  Future<bool> updateText(int id, String content) async {
    final result = await update(id: id, content: content);
    return (result['ok'] ?? false) == true;
  }

  Future<bool> unlike(int id) async {
    final response = await http.delete(
      Uri.parse('${ApiClient.base}/explanations/$id/like'),
      headers: ApiClient.authHeader,
    );
    return response.statusCode == 200;
  }

  Future<bool> flagWrong(int id) async {
    final response = await http.post(
      Uri.parse('${ApiClient.base}/explanations/$id/wrong-flags'),
      headers: ApiClient.authHeader,
    );
    return response.statusCode == 200;
  }

  Future<bool> unflagWrong(int id) async {
    final response = await http.delete(
      Uri.parse('${ApiClient.base}/explanations/$id/wrong-flags'),
      headers: ApiClient.authHeader,
    );
    return response.statusCode == 200;
  }

  Future<List<dynamic>> myProblems() async {
    final response = await http.get(
      Uri.parse('${ApiClient.base}/my/explanations/problems'),
      headers: ApiClient.authHeader,
    );
    if (response.statusCode != 200) return [];
    final obj = jsonDecode(utf8.decode(response.bodyBytes));
    return (obj is Map && obj['items'] is List)
        ? List<dynamic>.from(obj['items'] as List)
        : <dynamic>[];
  }

  Future<Map<String, dynamic>> mine(int problemId) async {
    final response = await http.get(
      Uri.parse('${ApiClient.base}/problems/$problemId/my-explanations'),
      headers: ApiClient.authHeader,
    );
    return ApiClient.decode(response);
  }

  Future<bool> deleteMine(int problemId) async {
    final response = await http.delete(
      Uri.parse('${ApiClient.base}/problems/$problemId/my-explanations'),
      headers: ApiClient.authHeader,
    );
    return response.statusCode == 200;
  }
}
