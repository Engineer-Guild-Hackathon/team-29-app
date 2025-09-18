import 'api_client.dart';
import 'package:http/http.dart' as http;

class LeaderboardService {
  const LeaderboardService();

  Future<Map<String, dynamic>> fetch(String metric) async {
    final response = await http.get(
      Uri.parse('${ApiClient.base}/leaderboard?metric=$metric'),
      headers: ApiClient.authHeader,
    );
    return ApiClient.decode(response);
  }

  Future<Map<String, dynamic>> fetchNamed({required String metric}) {
    return fetch(metric);
  }

  Future<Map<String, dynamic>> fetchDefault() {
    return fetch('points');
  }
}
