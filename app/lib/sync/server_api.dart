// Typisierter Zugang zum Server: Koppeln und Abholen der Änderungen.
// Jeder Fehler kommt als `ServerException` mit einem `ServerFailure` heraus.
// Der Geräte-Schlüssel steht nie in einer Ausnahme oder einem Text.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'wire.dart';

enum ServerFailure {
  offline,
  timeout,
  invalidCode,
  tooManyAttempts,
  otherBusiness,
  unauthorized,
  blocked,
  server,
}

class ServerException implements Exception {
  const ServerException(this.failure);

  final ServerFailure failure;

  @override
  String toString() => 'ServerException(${failure.name})';
}

class ServerApi {
  ServerApi({
    required String baseUrl,
    required this._client,
    required this._appVersion,
    this._timeout = const Duration(seconds: 10),
  }) : _base = baseUrl.endsWith('/')
           ? baseUrl.substring(0, baseUrl.length - 1)
           : baseUrl;

  static const _codes = {
    'invalid_code': ServerFailure.invalidCode,
    'too_many_attempts': ServerFailure.tooManyAttempts,
    'other_business': ServerFailure.otherBusiness,
    'unauthorized': ServerFailure.unauthorized,
    'register_blocked': ServerFailure.blocked,
  };

  final String _base;
  final http.Client _client;
  final String _appVersion;
  final Duration _timeout;

  Future<PairResponse> pair({
    required String code,
    String? previousBusinessId,
    String? deviceModel,
  }) async {
    final body = await _send(
      (headers) => _client.post(
        Uri.parse('$_base/api/device/pair'),
        headers: {...headers, 'Content-Type': 'application/json'},
        body: jsonEncode({
          'code': code,
          'previousBusinessId': previousBusinessId,
          'appVersion': _appVersion,
          'deviceModel': deviceModel,
        }),
      ),
    );
    return _parse(body, PairResponse.fromJson);
  }

  Future<PullResponse> pull({required String token, required int since}) async {
    final body = await _send(
      (headers) => _client.get(
        Uri.parse('$_base/api/device/sync/pull?since=$since'),
        headers: {...headers, 'Authorization': 'Bearer $token'},
      ),
    );
    return _parse(body, PullResponse.fromJson);
  }

  Future<Object?> _send(
    Future<http.Response> Function(Map<String, String> headers) request,
  ) async {
    final http.Response response;
    try {
      response = await request({'X-Kassa-App-Version': _appVersion})
          .timeout(_timeout);
    } on TimeoutException {
      throw const ServerException(ServerFailure.timeout);
    } on SocketException {
      throw const ServerException(ServerFailure.offline);
    } on HandshakeException {
      throw const ServerException(ServerFailure.offline);
    } on http.ClientException {
      throw const ServerException(ServerFailure.offline);
    }
    final Object? body;
    try {
      body = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const ServerException(ServerFailure.server);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ServerException(_failureOf(body));
    }
    return body;
  }

  static ServerFailure _failureOf(Object? body) {
    if (body is Map<String, dynamic>) {
      final error = body['error'];
      if (error is Map<String, dynamic>) {
        final failure = _codes[error['code']];
        if (failure != null) return failure;
      }
    }
    return ServerFailure.server;
  }

  static T _parse<T>(Object? body, T Function(Map<String, dynamic>) read) {
    if (body is! Map<String, dynamic>) {
      throw const ServerException(ServerFailure.server);
    }
    try {
      return read(body);
    } on FormatException {
      throw const ServerException(ServerFailure.server);
    }
  }
}
