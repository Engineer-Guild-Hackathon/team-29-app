import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

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

  Future<String?> uploadIcon({required Uint8List bytes, required String filename, required String contentType}) async {
    final token = ApiClient.token;
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiClient.base}/profile/icon'),
    );
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: filename,
      contentType: MediaType.parse(contentType),
    ));
    if (token != null) {
      request.headers['Authorization'] = 'Bearer ' + token;
    }
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final data = await ApiClient.decode(response);
    if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
      return data['icon_url']?.toString();
    }
    throw Exception(data['detail'] ?? 'Failed to upload profile icon');
  }
}
