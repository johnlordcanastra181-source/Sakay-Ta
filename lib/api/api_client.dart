import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_exception.dart';

class ApiClient {
  ApiClient({
    String? baseUrl,
    http.Client? client,
  })  : _baseUrl = baseUrl ?? 'https://api.example.com',
        _client = client ?? http.Client();

  final String _baseUrl;
  final http.Client _client;

  Uri _uri(String path, [Map<String, dynamic>? queryParameters]) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse(_baseUrl + normalizedPath);

    if (queryParameters == null || queryParameters.isEmpty) {
      return uri;
    }

    return uri.replace(queryParameters: {
      ...uri.queryParameters,
      ...queryParameters.map((key, value) => MapEntry(key, value.toString())),
    });
  }

  Map<String, String> jsonHeaders({Map<String, String>? additionalHeaders}) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      ...?additionalHeaders,
    };
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    final response = await _client.get(
      _uri(path, queryParameters),
      headers: jsonHeaders(additionalHeaders: headers),
    );

    return _decodeJsonResponse(response);
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    final response = await _client.post(
      _uri(path, queryParameters),
      headers: jsonHeaders(additionalHeaders: headers),
      body: body == null ? null : jsonEncode(body),
    );

    return _decodeJsonResponse(response);
  }

  Future<Map<String, dynamic>> putJson(
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    final response = await _client.put(
      _uri(path, queryParameters),
      headers: jsonHeaders(additionalHeaders: headers),
      body: body == null ? null : jsonEncode(body),
    );

    return _decodeJsonResponse(response);
  }

  Future<Map<String, dynamic>> deleteJson(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    final response = await _client.delete(
      _uri(path, queryParameters),
      headers: jsonHeaders(additionalHeaders: headers),
    );

    return _decodeJsonResponse(response);
  }

  Map<String, dynamic> _decodeJsonResponse(http.Response response) {
    final body =
        response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (body is Map<String, dynamic>) {
        return body;
      }

      if (body is Map) {
        return Map<String, dynamic>.from(body);
      }

      throw ApiException(
        statusCode: response.statusCode,
        message: 'Unexpected response format.',
        body: body,
      );
    }

    throw ApiException(
      statusCode: response.statusCode,
      message: body is Map
          ? (body['message'] as String? ?? 'Request failed.')
          : 'Request failed.',
      body: body,
    );
  }
}
