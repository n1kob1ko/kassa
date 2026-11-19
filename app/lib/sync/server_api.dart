// Typisierter Zugang zum Server: Koppeln und Abholen der Änderungen.
// Jeder Fehler kommt als `ServerException` mit einem `ServerFailure` heraus.
// Der Geräte-Schlüssel steht nie in einer Ausnahme oder einem Text.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
    this._pushTimeout = const Duration(seconds: 30),
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

  /// Ein Paket mit bis zu 100 Einträgen braucht auf einer langsamen Leitung
  /// länger als eine Seite beim Holen.
  final Duration _pushTimeout;

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
  /// 422), kommt [ServerFailure.rejected]. Die Antwort darf 30 Sekunden auf
  /// sich warten lassen.
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
      timeout: _pushTimeout,
    );
    return _parse(body, (json) {
      final results = json['results'];
      if (results is! List) throw const FormatException('Feld fehlt: results');
      return [for (final r in results) PushResult.fromJson(r)];
    });
  }

  /// Mehr als so viele Bytes nimmt das Tablet für eine Datei nicht an. Der
  /// Server liefert höchstens 800 Pixel Breite als WebP, das bleibt weit
  /// darunter.
  static const maxFileBytes = 2 * 1024 * 1024;

  /// Lädt die Datei [id] (ein Bild im Format WebP). Mehr als [maxFileBytes]
  /// oder eine andere Art als `image/webp` ergibt [ServerFailure.server].
  /// Gelesen wird Stück für Stück und beim ersten Byte zu viel abgebrochen:
  /// nichts davon liegt je ganz im Speicher. Reißt die Verbindung oder bleibt
  /// sie stehen, kommt `offline` oder `timeout` und es gibt keine Teilantwort.
  Future<Uint8List> downloadFile({
    required String token,
    required String id,
  }) async {
    try {
      final request =
          http.Request('GET', Uri.parse('$_base/api/device/files/$id'))
            ..headers.addAll({
              'X-Kassa-App-Version': _appVersion,
              'Authorization': 'Bearer $token',
            });
      final response = await _client.send(request).timeout(_timeout);
      // Jedes Stück darf nur so lange auf sich warten lassen wie eine Anfrage.
      final stream = response.stream.timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await _readLimited(stream, 64 * 1024);
        Object? json;
        try {
          json = body == null ? null : jsonDecode(utf8.decode(body));
        } on FormatException {
          json = null;
        }
        throw ServerException(_failureOf(json));
      }
      final type = response.headers['content-type'] ?? '';
      final length = response.contentLength;
      if (!type.toLowerCase().startsWith('image/webp') ||
          (length != null && length > maxFileBytes)) {
        throw const ServerException(ServerFailure.server);
      }
      final bytes = await _readLimited(stream, maxFileBytes);
      if (bytes == null) throw const ServerException(ServerFailure.server);
      return bytes;
    } on TimeoutException {
      throw const ServerException(ServerFailure.timeout);
    } on IOException {
      throw const ServerException(ServerFailure.offline);
    } on http.ClientException {
      throw const ServerException(ServerFailure.offline);
    }
  }

  /// Liest [stream] bis zum Ende, aber höchstens [limit] Bytes. `null`, wenn
  /// mehr kommt: dann ist das Lesen schon beendet.
  static Future<Uint8List?> _readLimited(
    Stream<List<int>> stream,
    int limit,
  ) async {
    final out = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      if (out.length + chunk.length > limit) return null;
      out.add(chunk);
    }
    return out.takeBytes();
  }

  Future<Object?> _send(
    Future<http.Response> Function(Map<String, String> headers) request, {
    Set<int> rejectedStatuses = const {},
    Duration? timeout,
  }) async {
    final http.Response response;
    try {
      response = await request({'X-Kassa-App-Version': _appVersion})
          .timeout(timeout ?? _timeout);
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
