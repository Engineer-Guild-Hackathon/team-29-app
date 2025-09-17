import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_client.dart';

class OcrService {
  const OcrService();

  Future<String?> scanBytes(
    List<int> bytes, {
    String lang = 'jpn+eng',
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiClient.base}/ocr'),
    );
    request.fields['lang'] = lang;
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: 'image.png',
      ),
    );
    final token = ApiClient.token;
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    final response = await request.send();
    final body = await response.stream.bytesToString();
    try {
      final obj = jsonDecode(body);
      if (obj is Map && (obj['ok'] ?? false) == true) {
        final text = obj['text'];
        return text?.toString();
      }
    } catch (_) {}
    return null;
  }
}
