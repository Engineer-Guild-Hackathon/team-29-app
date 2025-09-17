import 'dart:convert';

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient._();

  static String? _token;

  static String get base {
    final fromEnv = dotenv.env['API_BASE_URL'];
    if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
    if (kReleaseMode) {
      return 'https://es4.eedept.kobe-u.ac.jp/kaihou-back';
    }
    return 'http://localhost:8000';
  }

  static String? get token => _token;

  static void setToken(String value) {
    _token = value;
  }

  static void clearToken() {
    _token = null;
  }

  static Map<String, String> get jsonHeaders {
    final headers = {'Content-Type': 'application/json'};
    final t = _token;
    if (t != null) {
      headers['Authorization'] = 'Bearer $t';
    }
    return headers;
  }

  static Map<String, String> get authHeader {
    final headers = <String, String>{};
    final t = _token;
    if (t != null) {
      headers['Authorization'] = 'Bearer $t';
    }
    return headers;
  }

  static Future<Map<String, dynamic>> decode(http.Response response) async {
    try {
      final body = utf8.decode(response.bodyBytes);
      final obj = jsonDecode(body);
      if (obj is Map<String, dynamic>) return obj;
      return {'data': obj};
    } catch (_) {
      return {'status': response.statusCode};
    }
  }
}
