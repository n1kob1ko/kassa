// Zusammenspiel mit dem echten Server: koppeln, holen, in der Verwaltung etwas
// ändern, abgleichen, sperren. Echtes Netzwerk, Datenbank im Speicher.
//
// Läuft nur mit den Angaben von `tool/e2e.sh` (E2E_SERVER, E2E_CODE,
// E2E_COOKIE, E2E_BUSINESS). Ohne sie überspringt sich jeder Test, ein
// gewöhnliches `flutter test` schließt diesen Ordner ohnehin aus.

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kassa/app.dart';
import 'package:kassa/app_sync_providers.dart';
import 'package:kassa/core/clock.dart';
import 'package:kassa/data/catalog_repository.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/data/outbox_repository.dart';
import 'package:kassa/data/staff_repository.dart';
import 'package:kassa/data/sync_state_repository.dart';
import 'package:kassa/sync/pairing_service.dart';
import 'package:kassa/sync/push_wire.dart';
import 'package:kassa/sync/server_api.dart';
import 'package:kassa/sync/server_changes.dart';
import 'package:kassa/sync/sync_service.dart';
import 'package:kassa/sync/token_store.dart';

import '../test/support/kassa_pump.dart' show containerOf;
import '../test/support/pump.dart';

const _server = String.fromEnvironment('E2E_SERVER');
const _code = String.fromEnvironment('E2E_CODE');
const _cookie = String.fromEnvironment('E2E_COOKIE');
const _business = String.fromEnvironment('E2E_BUSINESS');

final _skip = _server.isEmpty || _code.isEmpty || _cookie.isEmpty
    ? 'Ohne E2E_SERVER, E2E_CODE und E2E_COOKIE (tool/e2e.sh) läuft dieser Test nicht.'
    : null;

/// Die Verwaltung im Browser, als HTTP-Anfragen: Sitzungs-Cookie und die
/// Kopfzeile, die der Server bei jeder ändernden Anfrage verlangt.
class _Admin {
  final _client = http.Client();

  Future<Map<String, dynamic>> call(
    String method,
    String path, [
    Map<String, Object?>? body,
  ]) async {
    final request = http.Request(method, Uri.parse('$_server$path'))
      ..headers['cookie'] = _cookie
      ..headers['x-kassa-request'] = '1';
    if (body != null) {
      request.headers['content-type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final res = await http.Response.fromStream(await _client.send(request));
    if (res.statusCode >= 300) {
      throw StateError('$method $path: ${res.statusCode}');
    }
    return res.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<String> chefId() async {
    final r = await call('GET', '/api/admin/businesses/$_business/staff');
    final staff = (r['staff'] as List).cast<Map<String, dynamic>>();
    return staff.firstWhere((s) => s['role'] == 'chef')['id'] as String;
  }

  Future<void> rename(String id, String name) => call(
    'PATCH',
    '/api/admin/businesses/$_business/staff/$id',
    {'name': name},
  );

  Future<void> createStaff(String name, String pin) => call(
    'POST',
    '/api/admin/businesses/$_business/staff',
    {'name': name, 'role': 'staff', 'pin': pin},
  );

  Future<void> setBlocked(String registerId, bool blocked) => call(
    'POST',
    '/api/admin/businesses/$_business/registers/$registerId/'
        '${blocked ? 'block' : 'unblock'}',
  );

  Future<String> newCode(String name) async {
    final r = await call(
      'POST',
      '/api/admin/businesses/$_business/pairing-codes',
      {'name': name},
    );
    return r['code'] as String;
  }

  void close() => _client.close();
}

/// Lässt [f] in einem Widget-Test echtes Netzwerk benutzen. Die Zeit des Tests
/// steht still, darum wechseln sich echtes Warten und `pump` ab, bis [f] fertig
/// ist (Datenbank und Netzwerk antworten nur so).
Future<T> real<T>(WidgetTester t, Future<T> Function() f) async {
  var done = false;
  late T value;
  Object? error;
  StackTrace? trace;
  f().then(
    (v) {
      value = v;
      done = true;
    },
    onError: (Object e, StackTrace s) {
      error = e;
      trace = s;
      done = true;
    },
  );
  for (var i = 0; i < 400 && !done; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await t.pump();
  }
  if (!done) throw StateError('Der Aufruf ist nicht fertig geworden.');
  if (error != null) Error.throwWithStackTrace(error!, trace!);
  return value;
}

void main() {
  setUpAll(() {
    // flutter_test sperrt sonst jede Anfrage ins Netz.
    HttpOverrides.global = null;
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  test('koppeln, holen, ändern, sperren', () async {
    final db = KassaDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final client = http.Client();
    addTearDown(client.close);
    final admin = _Admin();
    addTearDown(admin.close);

    final tokens = MemoryTokenStore();
    final syncState = SyncStateRepository(db);
    final changes = ServerChanges(db);
    const clock = SystemClock();
    final api = ServerApi(
      baseUrl: _server,
      client: client,
      appVersion: '1.2.0',
    );
    final pairing = PairingService(
      api: api,
      tokens: tokens,
      syncState: syncState,
      changes: changes,
      clock: clock,
      onCatalogReplaced: () {},
    );
    final sync = SyncService(
      api: api,
      tokens: tokens,
      syncState: syncState,
      changes: changes,
      outbox: OutboxRepository(db),
      payloads: PushPayloads(db),
      clock: clock,
    );
    addTearDown(sync.dispose);
    final staff = StaffRepository(db);

    // Koppeln und alles holen: Speisekarte und Chefin sind da.
    final paired = await pairing.pair(_code);
    expect(paired.businessId, _business);
    await pairing.loadInitial();
    final catalog = await CatalogRepository(db).current();
    expect(catalog, isNotNull);
    expect(catalog!.categories, isNotEmpty);
    expect((await staff.findByPin('1234'))?.name, 'Chefin');
    var state = await syncState.current();
    expect(state.paired, isTrue);
    expect(state.blocked, isFalse);

    // Die Verwaltung ändert etwas, der Abgleich bringt es.
    await admin.rename(await admin.chefId(), 'Chefin Erika');
    await admin.createStaff('Max', '2468');
    await sync.syncNow();
    expect((await staff.findByPin('1234'))?.name, 'Chefin Erika');
    expect((await staff.findByPin('2468'))?.name, 'Max');
    state = await syncState.current();
    expect(state.lastError, isNull);
    final lastPull = state.lastPullAt;
    expect(lastPull, isNotNull);

    // Gesperrt: der Abgleich meldet es, "Zuletzt abgeglichen" rückt nicht.
    await admin.setBlocked(paired.registerId, true);
    await sync.syncNow();
    state = await syncState.current();
    expect(state.blocked, isTrue);
    expect(state.lastError, 'blocked');
    expect(state.lastPullAt, lastPull);

    // Sperre aufgehoben: wieder frei.
    await admin.setBlocked(paired.registerId, false);
    await sync.syncNow();
    state = await syncState.current();
    expect(state.blocked, isFalse);
    expect(state.lastError, isNull);
    expect(state.lastPullAt!.isBefore(lastPull!), isFalse);

    // Derselbe Code ein zweites Mal gilt nicht mehr.
    await expectLater(
      pairing.pair(_code),
      throwsA(
        isA<ServerException>().having(
          (e) => e.failure,
          'failure',
          ServerFailure.invalidCode,
        ),
      ),
    );
  }, skip: _skip);

  testWidgets('KassaApp gleicht nach dem Koppeln von selbst ab', (t) async {
    final admin = _Admin();
    addTearDown(admin.close);
    final client = http.Client();
    addTearDown(client.close);
    final code = await t.runAsync(() => admin.newCode('Kassa 2'));

    final internet = InternetSwitch();
    final overrides = [
      ...await memoryOverrides(seeded: false, internet: internet.stream),
      hasServerProvider.overrideWithValue(true),
      tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
      serverApiProvider.overrideWithValue(
        ServerApi(baseUrl: _server, client: client, appVersion: '1.2.0'),
      ),
    ];
    await pumpApp(t, const KassaApp(), overrides: overrides);
    await t.pumpAndSettle();

    final container = containerOf(t);
    final service = container.read(pairingServiceProvider);
    await real(t, () => service.pair(code!));
    await real(t, service.loadInitial);
    // Die App hat den Abgleich im Hintergrund gestartet (KassaApp, ohne dass
    // dieser Test etwas dafür tut) und ihren ersten Lauf gemacht.
    for (var i = 0; i < 20; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await t.pump();
    }
    // Die Verwaltung ändert etwas. Kommt das Internet zurück, gleicht der
    // Abgleich im Hintergrund von selbst ab; `syncNow` ruft dieser Test nie.
    // Ohne gestarteten Abgleich bliebe es beim alten Namen.
    await real(
      t,
      () async => admin.rename(await admin.chefId(), 'Chefin Hintergrund'),
    );
    internet.set(false);
    await t.pump();
    internet.set(true);

    final staff = container.read(staffRepositoryProvider);
    String? name;
    for (var i = 0; i < 100 && name != 'Chefin Hintergrund'; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await t.pump();
      name = (await staff.all())
          .where((s) => s.isChef)
          .map((s) => s.name)
          .firstOrNull;
    }
    expect(name, 'Chefin Hintergrund');
  }, skip: _skip != null);
}
