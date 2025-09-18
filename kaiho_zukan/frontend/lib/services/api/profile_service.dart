import 'package:http/http.dart' as http;

import 'api_client.dart';

class ProfileService {
  const ProfileService();

  Future<Map<String, dynamic>> fetch() async {
    final res = await http.get(
      Uri.parse('${ApiClient.base}/profile'),
      headers: ApiClient.authHeader,
    );
    return ApiClient.decode(res);
  }
}