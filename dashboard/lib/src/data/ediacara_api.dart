import 'dart:convert';

import 'package:http/http.dart' as http;

import 'composition.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Talks to the same-origin Worker. The app is served by the same Worker that
/// answers `/api/composition`, so there is no base URL to configure.
class EdiacaraApi {
  EdiacaraApi({http.Client? client, this.origin})
    : _client = client ?? http.Client();

  final http.Client _client;
  final String? origin;

  /// Absolute (or root-relative) URL for a Worker route.
  Uri endpoint(String path, [Map<String, String>? query]) {
    final params = (query == null || query.isEmpty) ? null : query;
    final base = origin;
    if (base == null || base.isEmpty) {
      return Uri(path: path, queryParameters: params);
    }
    return Uri.parse(base).replace(path: path, queryParameters: params);
  }

  /// Ask the orchestrator for the musical parameters behind [ticker].
  Future<Composition> composition(String ticker) async {
    final http.Response response;
    try {
      response = await _client
          .get(endpoint('/api/composition', {'ticker': ticker}))
          .timeout(const Duration(seconds: 20));
    } catch (error) {
      throw ApiException('Could not reach the orchestrator: $error');
    }

    if (response.statusCode != 200) {
      throw ApiException(
        'Orchestrator returned ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw ApiException('Orchestrator returned a non-JSON response');
    }
    if (decoded is! Map<String, dynamic>) {
      throw ApiException('Orchestrator returned an unexpected payload');
    }
    return Composition.fromJson(decoded);
  }

  void close() => _client.close();
}
