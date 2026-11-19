// Ein Server im Speicher für Tests rund um Koppeln und Abgleich. Er ist ein
// `http.Client` und beantwortet `POST /api/device/pair` und
// `GET /api/device/sync/pull` wie der echte Server: jede Zeile trägt die
// Änderungs-Nummer ihrer letzten Änderung, eine Seite sind die nächsten
// [FakeServer.pageSize] Zeilen nach `since`, nach Nummer aufsteigend.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:kassa/sync/wire.dart';

/// Wie der Server auf die nächste Anfrage antwortet.
enum FakeMode {
  online,

  /// Keine Verbindung (SocketException).
  offline,

  /// 403 `register_blocked`.
  blocked,

  /// 401 `unauthorized`.
  unauthorized,

  /// 200 mit einem Körper, der kein JSON ist.
  garbage,
}

typedef _Row = ({int seq, String kind, Map<String, Object?> row});

class FakeServer extends http.BaseClient {
  FakeServer({this.pageSize = 3});

  /// Der Beispiel-Imbiss aus `shared/fixtures/sync/pull_full.json`, in der
  /// Reihenfolge Betrieb, Kategorien, Vorlagen, Artikel, Mitarbeiter
  /// eingetragen (8 Änderungen).
  factory FakeServer.beispiel({int pageSize = 3}) {
    final full = jsonDecode(
      File('../shared/fixtures/sync/pull_full.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final s = FakeServer(pageSize: pageSize)
      ..putBusiness(full['business'] as Map<String, dynamic>);
    for (final kind in const ['categories', 'templates', 'items', 'staff']) {
      for (final row in full[kind] as List<dynamic>) {
        s.upsert(kind, row as Map<String, dynamic>);
      }
    }
    return s;
  }

  static const code = '48201937';
  static const token = 'Geraete-Schluessel-0123456789-abcdefghijklm';
  static const businessId = '11111111-1111-4111-8111-111111111111';
  static const registerId = '22222222-2222-4222-8222-222222222222';

  int pageSize;

  /// Gilt für jede folgende Anfrage, bis es jemand ändert.
  FakeMode mode = FakeMode.online;

  /// Ist es gesetzt, antwortet `pair` mit diesem Fehlercode des Servers
  /// (zum Beispiel `too_many_attempts`).
  String? pairErrorCode;

  /// Ist es gesetzt, nennt die Antwort von `pair` diesen Betrieb statt des
  /// Beispiel-Imbisses.
  String? pairBusinessId;

  /// Nach so vielen beantworteten Seiten ist das Internet weg (offline).
  int? breakAfterPages;

  /// Läuft einmal, nachdem die nächste Seite gebildet ist und bevor sie
  /// hinausgeht. So lässt sich etwas zwischen `pull` und dem Einspielen tun.
  Future<void> Function()? beforeNextPage;

  /// Jede Anfrage an `pair`, als gelesener Körper.
  final pairRequests = <Map<String, dynamic>>[];

  /// `since` jeder Anfrage an `pull`, auch der gescheiterten.
  final pullRequests = <int>[];

  /// Die Einträge jeder Anfrage an `push`, auch der gescheiterten.
  final pushRequests = <List<Map<String, Object?>>>[];

  /// Was der Server angenommen hat: Inhalt ohne `seq`, je Inhalt einmal.
  final received = <String, Map<String, Object?>>{};

  /// Antwort für einzelne `seq`: `rejected` (Grund `invalid`) oder `error`.
  /// Solche Einträge nimmt der Server nicht an.
  final pushStatuses = <int, String>{};

  /// Antwortet die ganze Anfrage mit 422, wenn ein Eintrag dazu passt.
  bool Function(Map<String, Object?> entry)? rejectWholeIf;

  /// Der Server nimmt die nächste Anfrage an, aber die Antwort geht verloren.
  bool loseNextPushAnswer = false;

  /// Läuft einmal, nachdem die nächste Anfrage angenommen ist und bevor die
  /// Antwort hinausgeht.
  Future<void> Function()? beforePushAnswer;

  int _pagesServed = 0;
  int _seq = 0;
  final _rows = <String, _Row>{};

  /// Die höchste vergebene Änderungs-Nummer.
  int get seq => _seq;

  /// Trägt [row] mit einer neuen Nummer ein oder ersetzt die Zeile gleicher
  /// Art und Kennung.
  void upsert(String kind, Map<String, Object?> row) {
    final key = '$kind/${row['id']}';
    _rows.remove(key);
    _rows[key] = (seq: ++_seq, kind: kind, row: Map.of(row));
  }

  void putBusiness(Map<String, Object?> row) {
    _rows.remove('business');
    _rows['business'] = (seq: ++_seq, kind: 'business', row: Map.of(row));
  }

  /// Ändert einzelne Felder einer Zeile, sie bekommt eine neue Nummer.
  void change(String kind, String id, Map<String, Object?> fields) =>
      upsert(kind, {...rowOf(kind, id), ...fields});

  void archive(String kind, String id) => change(kind, id, {'archived': true});

  Map<String, Object?> rowOf(String kind, String id) => _rows['$kind/$id']!.row;

  /// Eine Mitarbeiterin mit PIN, gerechnet wie am Server.
  static Map<String, Object?> staffRow({
    required String id,
    required String name,
    required String pin,
    String role = 'staff',
  }) {
    final salt = sha256.convert(utf8.encode(id)).toString().substring(0, 32);
    return {
      'id': id,
      'name': name,
      'role': role,
      'pinSalt': salt,
      'pinHash': sha256.convert(utf8.encode('$salt$pin')).toString(),
      'archived': false,
    };
  }

  /// Die Seite ab [since] in der Form der Antwort.
  Map<String, Object?> pageJson(int since) {
    final after = _rows.values.where((r) => r.seq > since).toList()
      ..sort((a, b) => a.seq.compareTo(b.seq));
    final page = after.take(pageSize).toList();
    final lists = <String, List<Object?>>{
      'categories': [],
      'items': [],
      'templates': [],
      'staff': [],
    };
    Map<String, Object?>? business;
    for (final r in page) {
      if (r.kind == 'business') {
        business = r.row;
      } else {
        lists[r.kind]!.add(r.row);
      }
    }
    return {
      'next': page.isEmpty ? since : page.last.seq,
      'more': after.length > page.length,
      'business': ?business,
      ...lists,
    };
  }

  PullResponse page(int since) => PullResponse.fromJson(
    jsonDecode(jsonEncode(pageJson(since))) as Map<String, dynamic>,
  );

  /// Alle Seiten ab [since], wie `loadInitial` sie holt.
  List<PullResponse> pages([int since = 0]) {
    final out = <PullResponse>[];
    var cursor = since;
    while (true) {
      final p = page(cursor);
      out.add(p);
      if (!p.more) return out;
      cursor = p.next;
    }
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    if (path == '/api/device/sync/pull') {
      pullRequests.add(int.parse(request.url.queryParameters['since']!));
    } else if (path == '/api/device/sync/push') {
      pushRequests.add([
        for (final e
            in (jsonDecode((request as http.Request).body)
                    as Map<String, dynamic>)['entries']
                as List<dynamic>)
          e as Map<String, Object?>,
      ]);
    } else if (path == '/api/device/pair') {
      pairRequests.add(
        jsonDecode((request as http.Request).body) as Map<String, dynamic>,
      );
    }
    switch (mode) {
      case FakeMode.offline:
        throw const SocketException('Kein Netz');
      case FakeMode.blocked:
        return _error(403, 'register_blocked');
      case FakeMode.unauthorized:
        return _error(401, 'unauthorized');
      case FakeMode.garbage:
        return _respond(200, '<html>');
      case FakeMode.online:
    }
    if (path == '/api/device/pair') return _pair();
    if (path == '/api/device/sync/push') return _push(request);
    if (path == '/api/device/sync/pull') {
      if (request.headers['Authorization'] != 'Bearer $token') {
        return _error(401, 'unauthorized');
      }
      if (breakAfterPages != null && _pagesServed >= breakAfterPages!) {
        throw const SocketException('Verbindung abgebrochen');
      }
      _pagesServed++;
      final since = pullRequests.last;
      final body = jsonEncode(pageJson(since));
      final hook = beforeNextPage;
      beforeNextPage = null;
      if (hook != null) await hook();
      return _respond(200, body);
    }
    return _error(404, 'not_found');
  }

  Future<http.StreamedResponse> _push(http.BaseRequest request) async {
    if (request.headers['Authorization'] != 'Bearer $token') {
      return _error(401, 'unauthorized');
    }
    final entries = pushRequests.last;
    if (entries.any((e) => rejectWholeIf?.call(e) ?? false)) {
      return _error(422, 'push_invalid');
    }
    final results = <Map<String, Object?>>[];
    for (final e in entries) {
      final seq = e['seq']! as int;
      final forced = pushStatuses[seq];
      if (forced == 'rejected') {
        results.add({'seq': seq, 'status': 'rejected', 'reason': 'invalid'});
      } else if (forced == 'error') {
        results.add({'seq': seq, 'status': 'error'});
      } else {
        final body = {...e}..remove('seq');
        final key = jsonEncode(body);
        final known = received.containsKey(key);
        received[key] = body;
        results.add({'seq': seq, 'status': known ? 'duplicate' : 'accepted'});
      }
    }
    final hook = beforePushAnswer;
    beforePushAnswer = null;
    if (hook != null) await hook();
    if (loseNextPushAnswer) {
      loseNextPushAnswer = false;
      throw const SocketException('Antwort verloren');
    }
    return _respond(200, jsonEncode({'results': results}));
  }

  http.StreamedResponse _pair() {
    final forced = pairErrorCode;
    if (forced != null) return _error(422, forced);
    if (pairRequests.last['code'] != code) return _error(422, 'invalid_code');
    return _respond(
      200,
      jsonEncode({
        'registerId': registerId,
        'registerName': 'Kassa 1',
        'businessId': pairBusinessId ?? businessId,
        'businessName': 'Beispiel-Imbiss',
        'token': token,
      }),
    );
  }

  static http.StreamedResponse _error(int status, String code) => _respond(
    status,
    jsonEncode({
      'error': {'code': code, 'message': 'Das hat nicht geklappt.'},
    }),
  );

  static http.StreamedResponse _respond(int status, String body) =>
      http.StreamedResponse(
        Stream.value(utf8.encode(body)),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
}
