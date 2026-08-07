// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

class ApiClient {
  static const _storage = FlutterSecureStorage();

  static String _normalizeImageFilename(String? rawName) {
    const fallback = 'upload.jpg';
    final name = (rawName ?? '').trim();
    if (name.isEmpty) return fallback;

    final lower = name.toLowerCase();
    const allowed = ['.jpg', '.jpeg', '.png', '.webp'];
    for (final ext in allowed) {
      if (lower.endsWith(ext)) return name;
    }

    // Jika extension tidak didukung/absen, pakai jpg agar konsisten dengan BE.
    final dot = name.lastIndexOf('.');
    final base = dot > 0 ? name.substring(0, dot) : name;
    return '$base.jpg';
  }

  static Future<String?> getToken() => _storage.read(key: StorageKeys.token);

  static Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = {'Content-Type': 'application/json'};
    if (auth) {
      final token = await getToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
    bool auth = true,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path').replace(
      queryParameters: query?.map((key, value) => MapEntry(key, '$value')),
    );
    final res = await http.get(uri, headers: await _headers(auth: auth));
    return _parse(res);
  }

  static Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    bool auth = true,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    final res = await http.post(
      uri,
      headers: await _headers(auth: auth),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> put(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    final res = await http.put(
      uri,
      headers: await _headers(),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> patch(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    final res = await http.patch(
      uri,
      headers: await _headers(),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> delete(String path) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    final res = await http.delete(uri, headers: await _headers());
    return _parse(res);
  }

  static Future<Map<String, dynamic>> upload(
    String path, {
    String? filePath,
    List<int>? bytes,
    String? filename,
    String fieldName = 'foto',
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    final request = http.MultipartRequest('POST', uri);

    final token = await getToken();
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    if (bytes != null && filename != null) {
      final normalizedFilename = _normalizeImageFilename(filename);
      request.files.add(
        http.MultipartFile.fromBytes(
          fieldName,
          bytes,
          filename: normalizedFilename,
        ),
      );
    } else if (filePath != null) {
      request.files.add(
        await http.MultipartFile.fromPath(fieldName, filePath),
      );
    } else {
      throw ArgumentError(
          'Either filePath or bytes with filename must be provided');
    }

    final streamedResponse = await request.send();
    final res = await http.Response.fromStream(streamedResponse);
    return _parse(res);
  }

  static Map<String, dynamic> _parse(http.Response res) {
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (kDebugMode)
      debugPrint('[API] ${res.statusCode} ${res.request?.url} => $body');
    if (!body['success']) {
      throw ApiException(
        body['message'] ?? 'Terjadi kesalahan',
        res.statusCode,
      );
    }
    return body;
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);

  @override
  String toString() => message;
}
