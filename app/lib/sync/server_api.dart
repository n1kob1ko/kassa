// Typisierter Zugang zum Server: Koppeln und Abholen der Änderungen.
// Jeder Fehler kommt als `ServerException` mit einem `ServerFailure` heraus.
// Der Geräte-Schlüssel steht nie in einer Ausnahme oder einem Text.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'push_wire.dart';
import 'wire.dart';

enum ServerFailure {
  offline,
  timeout,
  invalidCode,
  tooManyAttempts,
  otherBusiness,
  unauthorized,
  blocked,

  /// Der Server nimmt die ganze Anfrage nicht an (400, 413, 422).
  rejected,
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

  /// Schickt [entries] an den Server. Die Antwort nennt je Eintrag, was
  /// daraus wurde. Nimmt der Server die ganze Anfrage nicht an (400, 413,
  /// 422), kommt [ServerFailure.rejected].
  Future<List<PushResult>> push({
    required String token,
    required String deviceId,
    required List<Map<String, Object?>> entries,
  }) async {
    final body = await _send(
      (headers) => _client.post(
        Uri.parse('$_base/api/device/sync/push'),
        headers: {
          ...headers,
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'deviceId': deviceId, 'entries': entries}),
      ),
      rejectedStatuses: const {400, 413, 422},
    );
    return _parse(body, (json) {
      final results = json['results'];
      if (results is! List) throw const FormatException('Feld fehlt: results');
      return [for (final r in results) PushResult.fromJson(r)];
    });
  }

  Future<Object?> _send(
    Future<http.Response> Function(Map<String, String> headers) request, {
    Set<int> rejectedStatuses = const {},
  }) async {
    final http.Response response;
    try {
      response = await request({'X-Kassa-App-Version': _appVersion})
          .timeout(_timeout);
    } on TimeoutException {
      throw const ServerException(ServerFailure.timeout);
    } on IOException {
      // Auch SocketException, HandshakeException, TlsException, HttpException.
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
      throw ServerException(
        _failureOf(
          body,
          rejected: rejectedStatuses.contains(response.statusCode),
        ),
      );
    }
    return body;
  }

  static ServerFailure _failureOf(Object? body, {bool rejected = false}) {
    if (body is Map<String, dynamic>) {
      final error = body['error'];
      if (error is Map<String, dynamic>) {
        final failure = _codes[error['code']];
        if (failure != null) return failure;
      }
    }
    return rejected ? ServerFailure.rejected : ServerFailure.server;
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
