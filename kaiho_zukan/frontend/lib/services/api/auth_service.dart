import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_client.dart';

class AuthService {
  const AuthService();

  Future<Map<String, dynamic>> register(
    String username,
    String password,
    String nickname,
  ) async {
    final response = await http.post(
      Uri.parse('${ApiClient.base}/auth/register'),
      headers: ApiClient.jsonHeaders,
      body: jsonEncode({
        'username': username,
        'password': password,
        'nickname': nickname,
      }),
    );
    final data = await ApiClient.decode(response);
    final token = data['access_token'];
    if (response.statusCode == 200 && token is String) {
      ApiClient.setToken(token);
    }
    return data;
  }

  Future<Map<String, dynamic>> login(
    String username,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('${ApiClient.base}/auth/login'),
      headers: ApiClient.jsonHeaders,
      body: jsonEncode({'username': username, 'password': password}),
    );
    final data = await ApiClient.decode(response);
    final token = data['access_token'];
    if (response.statusCode == 200 && token is String) {
      ApiClient.setToken(token);
    }
    return data;
  }
}
