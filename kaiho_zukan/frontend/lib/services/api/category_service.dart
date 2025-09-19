import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_client.dart';
import 'user_service.dart';

class CategoryService {
  const CategoryService();

  Future<List<dynamic>> tree({bool mineOnly = false}) async {
    final response = await http.get(
      Uri.parse('${ApiClient.base}/categories/tree'),
      headers: ApiClient.authHeader,
    );
    if (response.statusCode != 200) return [];
    final obj = jsonDecode(utf8.decode(response.bodyBytes));
    final t = (obj is List) ? obj : [];
    if (!mineOnly) return t;

    try {
      // Fetch my categories and filter the tree to only those child categories
      final me = await const UserService().fetchMe();
      final mineIds = (me['categories'] is List)
          ? Set<int>.from((me['categories'] as List)
              .map((e) => (e is Map && e['id'] is int) ? e['id'] as int : null)
              .whereType<int>())
          : <int>{};
      if (mineIds.isEmpty) return [];

      List<dynamic> filteredParents = [];
      for (final p in t) {
        if (p is! Map) continue;
        final children = (p['children'] as List?) ?? [];
        final filteredChildren = children
            .where((c) => c is Map && mineIds.contains(c['id'] as int? ?? -1))
            .toList();
        if (filteredChildren.isEmpty) continue;
        filteredParents.add({
          'id': p['id'],
          'name': p['name'],
          'children': filteredChildren,
        });
      }
      return filteredParents;
    } catch (_) {
      // If anything goes wrong during filtering, fall back to full tree
      return t;
    }
  }
}
