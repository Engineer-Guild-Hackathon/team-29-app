import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_client.dart';

class ModelAnswerService {
  const ModelAnswerService();

  Future<bool> upsertMine(int problemId, String content) async {
    final token = ApiClient.token;
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiClient.base}/problems/$problemId/model-answer'),
    );
    request.fields['content'] = content;
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    final response = await request.send();
    return response.statusCode == 200;
  }

  Future<bool> deleteMine(int problemId) async {
    return upsertMine(problemId, '');
  }

  Future<String?> mine(int problemId) async {
    final response = await http.get(
      Uri.parse('${ApiClient.base}/problems/$problemId/model-answer'),
      headers: ApiClient.authHeader,
    );
    if (response.statusCode != 200) return null;
    try {
      final obj = jsonDecode(utf8.decode(response.bodyBytes));
      return (obj is Map && obj['content'] is String)
          ? obj['content'] as String
          : null;
    } catch (_) {
      return null;
    }
  }

  Future<List<dynamic>> list(int problemId) async {
    final response = await http.get(
      Uri.parse('${ApiClient.base}/problems/$problemId/model-answers'),
      headers: ApiClient.authHeader,
    );
    if (response.statusCode != 200) return [];
    try {
      final obj = jsonDecode(utf8.decode(response.bodyBytes));
      return (obj is Map && obj['items'] is List)
          ? List<dynamic>.from(obj['items'] as List)
          : <dynamic>[];
    } catch (_) {
      return <dynamic>[];
    }
  }
}
