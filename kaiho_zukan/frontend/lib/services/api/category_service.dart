import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_client.dart';

class CategoryService {
  const CategoryService();

  Future<List<dynamic>> tree() async {
    final response = await http.get(
      Uri.parse('${ApiClient.base}/categories/tree'),
      headers: ApiClient.authHeader,
    );
    if (response.statusCode != 200) return [];
    final obj = jsonDecode(utf8.decode(response.bodyBytes));
    return (obj is List) ? obj : [];
  }
}
