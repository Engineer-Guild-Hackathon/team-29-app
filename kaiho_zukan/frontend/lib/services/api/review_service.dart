import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_client.dart';

class ReviewService {
  const ReviewService();

  Future<Map<String, dynamic>> stats(int categoryId, {int? grandId}) async {
    final grand = grandId != null ? '&grand_id=$grandId' : '';
    final response = await http.get(
      Uri.parse(
        '${ApiClient.base}/review/stats?category_id=$categoryId$grand',
      ),
      headers: ApiClient.authHeader,
    );
    return ApiClient.decode(response);
  }

  Future<Map<String, dynamic>> history({
    required int categoryId,
    int? grandId,
  }) async {
    final grand = grandId != null ? '&grand_id=$grandId' : '';
    final response = await http.get(
      Uri.parse(
        '${ApiClient.base}/review/history?category_id=$categoryId$grand',
      ),
      headers: ApiClient.authHeader,
    );
    return ApiClient.decode(response);
  }

  Future<Map<String, dynamic>> item(int problemId) async {
    final response = await http.get(
      Uri.parse('${ApiClient.base}/review/item?pid=$problemId'),
      headers: ApiClient.authHeader,
    );
    return ApiClient.decode(response);
  }

  Future<bool> mark(int problemId, bool isCorrect) async {
    final token = ApiClient.token;
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiClient.base}/review/mark'),
    );
    request.fields['pid'] = problemId.toString();
    request.fields['is_correct'] = isCorrect.toString();
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    final response = await request.send();
    return response.statusCode == 200;
  }
}
