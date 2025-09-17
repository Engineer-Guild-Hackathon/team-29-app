import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_client.dart';

class NotificationService {
  const NotificationService();

  Future<List<dynamic>> list({bool unseenOnly = false, int limit = 50}) async {
    final unseen = unseenOnly ? 'true' : 'false';
    final uri = Uri.parse('${ApiClient.base}/notifications?unseen_only=$unseen&limit=$limit');
    final response = await http.get(uri, headers: ApiClient.authHeader);
    final data = await ApiClient.decode(response);
    final items = data['items'];
    if (items is List) return items;
    return const [];
  }

  Future<bool> markSeen(List<int> ids) async {
    final response = await http.post(
      Uri.parse('${ApiClient.base}/notifications/seen'),
      headers: ApiClient.jsonHeaders,
      body: jsonEncode(ids),
    );
    return response.statusCode == 200;
  }
}