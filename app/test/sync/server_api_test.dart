import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kassa/sync/push_wire.dart';
import 'package:kassa/sync/server_api.dart';

Map<String, dynamic> fixture(String name) =>
    jsonDecode(File('../shared/fixtures/sync/$name.json').readAsStringSync())
        as Map<String, dynamic>;

const base = 'https://kassa.example';

ServerApi apiWith(
  MockClientHandler handler, {
  Duration timeout = const Duration(seconds: 10),
}) => ServerApi(
  baseUrl: base,
  client: MockClient(handler),
  appVersion: '1.2.0',
  timeout: timeout,
);

http.Response json(int status, Object body) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Future<ServerFailure> failureOf(Future<Object?> call) async {
  try {
    await call;
  } on ServerException catch (e) {
    return e.failure;
  }
  fail('Es wurde keine ServerException geworfen.');
}

void main() {
  test(
    'pair sendet code, previousBusinessId, appVersion wie pair_request.json',
    () async {
      final sample = fixture('pair_request');
      late http.Request seen;
      final api = apiWith((req) async {
        seen = req;
        return json(200, fixture('pair_response'));
      });
      final r = await api.pair(
        code: sample['code'] as String,
        previousBusinessId: 'b-alt',
        deviceModel: sample['deviceModel'] as String,
      );
      expect(seen.method, 'POST');
      expect(seen.url.toString(), '$base/api/device/pair');
      expect(seen.headers['X-Kassa-App-Version'], '1.2.0');
      expect(seen.headers['content-type'], contains('application/json'));
      final body = jsonDecode(seen.body) as Map<String, dynamic>;
      expect(body.keys.toSet(), sample.keys.toSet());
      expect(body['code'], sample['code']);
      expect(body['previousBusinessId'], 'b-alt');
      expect(body['appVersion'], '1.2.0');
      expect(body['deviceModel'], sample['deviceModel']);
      expect(r.registerName, 'Kassa 1');

      // Ohne frühere Kopplung geht previousBusinessId als null hinaus, wie im Beispiel.
      await api.pair(code: '48201937');
      expect(jsonDecode(seen.body)['previousBusinessId'], isNull);
    },
  );

  test(
    'jedes Beispiel aus errors.json ergibt das passende ServerFailure',
    () async {
      final errors = fixture('errors');
      const expected = {
        'invalid_code': ServerFailure.invalidCode,
        'too_many_attempts': ServerFailure.tooManyAttempts,
        'other_business': ServerFailure.otherBusiness,
        'unauthorized': ServerFailure.unauthorized,
        'register_blocked': ServerFailure.blocked,
        'since_invalid': ServerFailure.server,
        'limit_invalid': ServerFailure.server,
      };
      expect(errors.keys.toSet(), expected.keys.toSet());
      for (final entry in errors.entries) {
        final e = entry.value as Map<String, dynamic>;
        final api = apiWith((_) async => json(e['status'] as int, e['body']!));
        expect(
          await failureOf(api.pair(code: '12345678')),
          expected[entry.key],
          reason: 'pair: ${entry.key}',
        );
        expect(
          await failureOf(api.pull(token: 't', since: 0)),
          expected[entry.key],
          reason: 'pull: ${entry.key}',
        );
      }
    },
  );

  test(
    'SocketException ergibt offline, zu späte Antwort ergibt timeout',
    () async {
      final offline = apiWith((_) async => throw const SocketException('weg'));
      expect(await failureOf(offline.pair(code: '1')), ServerFailure.offline);
      expect(
        await failureOf(offline.pull(token: 't', since: 0)),
        ServerFailure.offline,
      );
      final clientError = apiWith(
        (_) async => throw http.ClientException('weg'),
      );
      expect(
        await failureOf(clientError.pull(token: 't', since: 0)),
        ServerFailure.offline,
      );

      final slow = apiWith(
        (_) => Completer<http.Response>().future,
        timeout: const Duration(milliseconds: 20),
      );
      expect(await failureOf(slow.pair(code: '1')), ServerFailure.timeout);
      expect(
        await failureOf(slow.pull(token: 't', since: 0)),
        ServerFailure.timeout,
      );
    },
  );

  test(
    'jeder andere Fehler der Verbindung (IOException) ergibt offline',
    () async {
      for (final error in <IOException>[
        const TlsException('Zertifikat'),
        const HttpException('Verbindung zu'),
        const FileSystemException('weg'),
      ]) {
        final api = apiWith((_) async => throw error);
        expect(
          await failureOf(api.pair(code: '1')),
          ServerFailure.offline,
          reason: '$error',
        );
        expect(
          await failureOf(api.pull(token: 't', since: 0)),
          ServerFailure.offline,
          reason: '$error',
        );
      }
    },
  );

  test('Antwort 200 mit Unsinn ergibt server', () async {
    for (final response in [
      http.Response('<html>', 200),
      http.Response('[]', 200),
      json(200, {'foo': 1}),
      json(500, {'x': 1}),
      http.Response('', 502),
    ]) {
      final api = apiWith((_) async => response);
      expect(await failureOf(api.pair(code: '1')), ServerFailure.server);
      expect(
        await failureOf(api.pull(token: 't', since: 0)),
        ServerFailure.server,
      );
    }
  });

  test('Fehlermeldung und Ausnahme enthalten den Schlüssel nicht', () async {
    final api = apiWith(
      (_) async => json(401, {
        'error': {'code': 'unauthorized'},
      }),
    );
    try {
      await api.pull(token: 'geheim-123', since: 0);
      fail('erwartet');
    } on ServerException catch (e) {
      expect(e.toString(), isNot(contains('geheim-123')));
    }
  });

  test('pull sendet Authorization: Bearer und since', () async {
    late http.Request seen;
    final api = apiWith((req) async {
      seen = req;
      return json(200, fixture('pull_delta'));
    });
    final r = await api.pull(token: 'tok-1', since: 7);
    expect(seen.method, 'GET');
    expect(seen.url.path, '/api/device/sync/pull');
    expect(seen.url.queryParameters['since'], '7');
    expect(seen.headers['Authorization'], 'Bearer tok-1');
    expect(seen.headers['X-Kassa-App-Version'], '1.2.0');
    expect(r.next, 11);
  });

  group('push', () {
    final request = fixture('push_request');
    final entries = (request['entries'] as List).cast<Map<String, Object?>>();

    test(
      'push sendet Schlüssel und Körper, liest push_response.json',
      () async {
        late http.Request seen;
        final api = apiWith((req) async {
          seen = req;
          return json(200, fixture('push_response'));
        });
        final results = await api.push(
          token: 'tok-1',
          deviceId: request['deviceId'] as String,
          entries: entries,
        );
        expect(seen.method, 'POST');
        expect(seen.url.toString(), '$base/api/device/sync/push');
        expect(seen.headers['Authorization'], 'Bearer tok-1');
        expect(seen.headers['X-Kassa-App-Version'], '1.2.0');
        expect(seen.headers['content-type'], contains('application/json'));
        expect(jsonDecode(seen.body), request);
        expect(results.map((r) => (r.seq, r.status, r.reason)), [
          for (var i = 1; i <= 7; i++) (i, PushStatus.accepted, null),
        ]);
      },
    );

    test('alle Zustände und der Grund werden gelesen', () async {
      final api = apiWith(
        (_) async => json(200, {
          'results': [
            {'seq': 1, 'status': 'accepted'},
            {'seq': 5, 'status': 'duplicate'},
            {'seq': 6, 'status': 'rejected', 'reason': 'unknown_item'},
            {'seq': 7, 'status': 'error'},
          ],
        }),
      );
      final results = await api.push(token: 't', deviceId: 'd', entries: []);
      expect(results.map((r) => (r.seq, r.status, r.reason)), [
        (1, PushStatus.accepted, null),
        (5, PushStatus.duplicate, null),
        (6, PushStatus.rejected, 'unknown_item'),
        (7, PushStatus.error, null),
      ]);
    });

    test('422, 413 und 400 der ganzen Anfrage ergeben rejected', () async {
      for (final (status, code) in [
        (422, 'push_invalid'),
        (413, 'payload_too_large'),
        (400, 'bad_request'),
      ]) {
        final api = apiWith(
          (_) async => json(status, {
            'error': {'code': code, 'message': 'x'},
          }),
        );
        expect(
          await failureOf(api.push(token: 't', deviceId: 'd', entries: [])),
          ServerFailure.rejected,
          reason: '$status',
        );
      }
    });

    test('401 ergibt unauthorized, 403 blocked, 500 server', () async {
      final errors = fixture('errors');
      for (final (key, failure) in [
        ('unauthorized', ServerFailure.unauthorized),
        ('register_blocked', ServerFailure.blocked),
      ]) {
        final e = errors[key] as Map<String, dynamic>;
        final api = apiWith((_) async => json(e['status'] as int, e['body']!));
        expect(
          await failureOf(api.push(token: 't', deviceId: 'd', entries: [])),
          failure,
          reason: key,
        );
      }
      final broken = apiWith((_) async => json(500, {'x': 1}));
      expect(
        await failureOf(broken.push(token: 't', deviceId: 'd', entries: [])),
        ServerFailure.server,
      );
    });

    test('Zeitgrenze ergibt timeout, fehlende Verbindung offline', () async {
      final slow = apiWith(
        (_) => Completer<http.Response>().future,
        timeout: const Duration(milliseconds: 20),
      );
      expect(
        await failureOf(slow.push(token: 't', deviceId: 'd', entries: [])),
        ServerFailure.timeout,
      );
      final offline = apiWith((_) async => throw const SocketException('weg'));
      expect(
        await failureOf(offline.push(token: 't', deviceId: 'd', entries: [])),
        ServerFailure.offline,
      );
    });

    test('Antwort 200 ohne results ergibt server', () async {
      final api = apiWith((_) async => json(200, {'foo': 1}));
      expect(
        await failureOf(api.push(token: 't', deviceId: 'd', entries: [])),
        ServerFailure.server,
      );
    });
  });
}
