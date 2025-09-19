import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_client.dart';

class UserService {
  const UserService();

  Future<Map<String, dynamic>> fetchMe() async {
    final response = await http.get(
      Uri.parse('${ApiClient.base}/me'),
      headers: ApiClient.authHeader,
    );
    return ApiClient.decode(response);
  }

  Future<bool> updateNickname(String nickname) async {
    final token = ApiClient.token;
    final request = http.MultipartRequest(
      'PUT',
      Uri.parse('${ApiClient.base}/me'),
    );
    request.fields['nickname'] = nickname;
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    final response = await request.send();
    return response.statusCode == 200;
  }

  Future<bool> setMyCategories(List<int> ids) async {
    final response = await http.post(
      Uri.parse('${ApiClient.base}/me/categories'),
      headers: ApiClient.jsonHeaders,
      body: jsonEncode(ids),
    );
    return response.statusCode == 200;
  }
  Future<Map<String, dynamic>> fetchProfile({required int userId}) async {
    final response = await http.get(
      Uri.parse('${ApiClient.base}/profile/$userId'),
      headers: ApiClient.authHeader,
    );
    final data = await ApiClient.decode(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }
    throw Exception(data['detail'] ?? 'Failed to fetch user profile');
  }
}
