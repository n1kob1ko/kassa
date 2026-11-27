// Zusammenspiel mit dem echten Server für Stufe 2: am Tablet über die echten
// Repositories verkaufen, stornieren, Geld bewegen und den Tag abschließen,
// abgleichen und in der Verwaltung nachsehen. Dazu Preise in beide
// Richtungen (auch zwei Änderungen in einer Sekunde und eine Uhr, die
// nachgeht), ein Foto, 250 Bons auf einmal, ein zweiter Lauf ohne Wirkung
// und die Probe-Signatur samt Protokoll-Datei. Echtes Netzwerk, Datenbank im
// Speicher.
//
// Läuft nur mit den Angaben von `tool/e2e.sh` (E2E_SERVER, E2E_COOKIE,
// E2E_BUSINESS). Ohne sie überspringt sich der Test, ein gewöhnliches
// `flutter test` schließt diesen Ordner ohnehin aus.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show OrderingTerm, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kassa/core/clock.dart';
import 'package:kassa/data/catalog_repository.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/day_repository.dart';
import 'package:kassa/data/outbox_repository.dart';
import 'package:kassa/data/receipt_repository.dart';
import 'package:kassa/data/staff_repository.dart';
import 'package:kassa/data/sync_state_repository.dart';
import 'package:kassa/domain/cart.dart';
import 'package:kassa/domain/day.dart';
import 'package:kassa/rksv/rksv_journal.dart';
import 'package:kassa/rksv/rksv_secrets.dart';
import 'package:kassa/rksv/rksv_service.dart';
import 'package:kassa/sync/file_sync.dart';
import 'package:kassa/sync/pairing_service.dart';
import 'package:kassa/sync/push_wire.dart';
import 'package:kassa/sync/server_api.dart';
import 'package:kassa/sync/server_changes.dart';
import 'package:kassa/sync/sync_service.dart';
import 'package:kassa/sync/token_store.dart';

import '../test/support/sales.dart';
import '../test/support/webp_samples.dart';

const _server = String.fromEnvironment('E2E_SERVER');
const _cookie = String.fromEnvironment('E2E_COOKIE');
const _business = String.fromEnvironment('E2E_BUSINESS');

final _skip = _server.isEmpty || _cookie.isEmpty || _business.isEmpty
    ? 'Ohne E2E_SERVER, E2E_COOKIE und E2E_BUSINESS (tool/e2e.sh) läuft '
          'dieser Test nicht.'
    : null;

/// Die Verwaltung im Browser, als HTTP-Anfragen: Sitzungs-Cookie und die
/// Kopfzeile, die der Server bei jeder ändernden Anfrage verlangt.
class _Admin {
  final _client = http.Client();

  static const _base = '/api/admin/businesses/$_business';

  Future<Map<String, dynamic>> call(
    String method,
    String path, {
    Map<String, Object?>? json,
    Uint8List? image,
  }) async {
    final request = http.Request(method, Uri.parse('$_server$_base$path'))
      ..headers['cookie'] = _cookie
      ..headers['x-kassa-request'] = '1';
    if (json != null) {
      request.headers['content-type'] = 'application/json';
      request.body = jsonEncode(json);
    }
    if (image != null) {
      request.headers['content-type'] = 'image/webp';
      request.bodyBytes = image;
    }
    final res = await http.Response.fromStream(await _client.send(request));
    if (res.statusCode >= 300) {
      throw StateError('$method $path: ${res.statusCode} ${res.body}');
    }
    return res.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Alle Bons der Kassa [registerName], neueste zuerst, über alle Seiten.
  Future<List<Map<String, dynamic>>> receipts(String registerName) async {
    final all = <Map<String, dynamic>>[];
    String? before;
    do {
      final page = await call(
        'GET',
        '/receipts${before == null ? '' : '?before=$before'}',
      );
      all.addAll((page['receipts'] as List).cast<Map<String, dynamic>>());
      before = page['next'] as String?;
    } while (before != null);
    return [
      for (final r in all)
        if (r['registerName'] == registerName) r,
    ];
  }

  /// Die Tage der Kassa [registerName], neueste zuerst.
  Future<List<Map<String, dynamic>>> days(String registerName) async {
    final r = await call('GET', '/days');
    return [
      for (final d in (r['days'] as List).cast<Map<String, dynamic>>())
        if (d['registerName'] == registerName) d,
    ];
  }

  /// Der Artikel [id] mit Preis und Foto, wie die Speisekarte im Browser.
  Future<Map<String, dynamic>> item(String id) async {
    final r = await call('GET', '/items');
    return [
      for (final c in (r['categories'] as List).cast<Map<String, dynamic>>())
        ...(c['items'] as List).cast<Map<String, dynamic>>(),
    ].firstWhere((i) => i['id'] == id);
  }

  void close() => _client.close();
}

/// Eine Uhr, die immer [at] zeigt.
class _FixedClock implements Clock {
  const _FixedClock(this.at);

  final DateTime at;

  @override
  DateTime now() => at;
}

void main() {
  setUpAll(() {
    // flutter_test sperrt sonst jede Anfrage ins Netz.
    HttpOverrides.global = null;
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  test(
    'Bons, Tag, Bewegung, Preise, Foto, 250 Bons und die Signatur '
    'kommen beim Server an',
    () async {
      const registerName = 'Kassa Zusammenspiel';
      final db = KassaDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final client = http.Client();
      addTearDown(client.close);
      final admin = _Admin();
      addTearDown(admin.close);
      final fileDir = await Directory.systemTemp.createTemp('kassa-e2e-files');
      addTearDown(() => fileDir.delete(recursive: true));

      final tokens = MemoryTokenStore();
      final syncState = SyncStateRepository(db);
      final changes = ServerChanges(db);
      final outbox = OutboxRepository(db);
      const clock = SystemClock();
      final api = ServerApi(
        baseUrl: _server,
        client: client,
        appVersion: '1.6.0',
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
        outbox: outbox,
        payloads: PushPayloads(db),
        clock: clock,
        files: FileSync(db, api, () async => fileDir),
      );
      addTearDown(sync.dispose);
      final secrets = MemoryRksvSecrets();
      final days = DayRepository(db, clock);
      final receipts = ReceiptRepository(
        db,
        clock,
        days,
        journal: RksvJournal(
          db,
          secrets,
          probeSignatureUnitOf(db, secrets),
          clock,
        ),
      );
      final rksv = RksvService(db, secrets, receipts, clock);
      final catalogs = CatalogRepository(db, clock: clock);

      Future<int> outboxCount() async =>
          (await db
                  .customSelect('SELECT COUNT(*) AS c FROM outbox')
                  .getSingle())
              .read<int>('c');

      Future<void> syncAndExpectNoError() async {
        await sync.syncNow();
        expect((await syncState.current()).lastError, isNull);
        expect(await outboxCount(), 0);
      }

      // Koppeln und alles holen.
      final code =
          (await admin.call(
                'POST',
                '/pairing-codes',
                json: {'name': registerName},
              ))['code']
              as String;
      final paired = await pairing.pair(code);
      await pairing.loadInitial();
      final chef = (await StaffRepository(db).findByPin('1234'))!;
      final catalog = (await catalogs.current())!;
      final item = catalog.items.firstWhere((i) => i.templateId == null);
      final cart = const Cart.empty().add(item);

      // Ein Tag an der Kassa: Wechselgeld, Barverkauf, Storno, Entnahme,
      // Abschluss. Die Kassa wartet dabei nie auf den Server.
      await days.setOpeningFloat(10000);
      final sale = await receipts.finalizeCashSale(
        saleId: 'aaaaaaaa-0000-4000-8000-000000000001',
        cart: cart,
        givenCents: cart.totalCents,
        staff: chef,
      );
      await receipts.voidReceipt(sale.id, staff: chef);
      await days.addMovement(
        kind: CashMovementKind.withdrawal,
        amountCents: 2000,
        reason: CashReason.bank,
        staff: chef,
      );
      final closed = await days.close(
        countedCents: 8000,
        leftInDrawerCents: 5000,
        staff: chef,
      );
      await syncAndExpectNoError();

      final serverReceipts = await admin.receipts(registerName);
      expect(serverReceipts, hasLength(2));
      expect({for (final r in serverReceipts) r['kind']}, {'sale', 'voided'});
      final serverSale = serverReceipts.firstWhere((r) => r['kind'] == 'sale');
      expect(serverSale['id'], sale.id);
      expect(serverSale['voided'], isTrue);
      final serverDays = await admin.days(registerName);
      expect(serverDays, hasLength(1));
      expect(serverDays.single['id'], closed.id);
      expect(serverDays.single['closedAt'], isNotNull);
      expect(serverDays.single['revenueCents'], 0);
      final day = await admin.call('GET', '/days/${closed.id}');
      expect(day['expectedCents'], 8000);
      expect(day['differenceCents'], 0);
      expect(day['receiptCount'], 0);
      expect(day['revenueCents'], 0);
      expect(day['movements'], [containsPair('amountCents', 2000)]);

      // Preis im Browser: nach dem Abgleich am Tablet.
      final browserPrice = item.priceCents + 100;
      await admin.call(
        'PATCH',
        '/items/${item.id}',
        json: {'priceCents': browserPrice},
      );
      await syncAndExpectNoError();
      expect(
        (await catalogs.current())!.item(item.id).priceCents,
        browserPrice,
      );

      // Preis am Tablet: nach dem Abgleich im Browser.
      final tabletPrice = item.priceCents + 200;
      // Das Tablet speichert Zeitpunkte auf die ganze Sekunde, der Browser auf
      // die Millisekunde. Eine Änderung am Tablet in derselben Sekunde wie die
      // im Browser wäre abgerundet früher und damit älter: der Server behielte
      // den Wert aus dem Browser und brächte ihn im selben Abgleich zurück ans
      // Tablet (siehe unten). An der Theke liegt mehr als eine Sekunde
      // dazwischen, darum hier auch.
      await Future<void>.delayed(
        Duration(milliseconds: 1010 - DateTime.now().millisecond),
      );
      await catalogs.updateItem(item.id, priceCents: tabletPrice);
      await syncAndExpectNoError();
      expect((await admin.item(item.id))['priceCents'], tabletPrice);

      // Zwei Änderungen am Tablet in derselben Sekunde, dazwischen ein
      // Abgleich: die zweite gewinnt auch am Server.
      await Future<void>.delayed(
        Duration(milliseconds: 1010 - DateTime.now().millisecond),
      );
      final second = DateTime.now().millisecondsSinceEpoch ~/ 1000 * 1000;
      final sameSecond = CatalogRepository(
        db,
        clock: _FixedClock(DateTime.fromMillisecondsSinceEpoch(second)),
      );
      await sameSecond.updateItem(item.id, priceCents: tabletPrice + 1);
      await syncAndExpectNoError();
      expect((await admin.item(item.id))['priceCents'], tabletPrice + 1);
      await sameSecond.updateItem(item.id, priceCents: tabletPrice + 2);
      await syncAndExpectNoError();
      expect((await admin.item(item.id))['priceCents'], tabletPrice + 2);
      expect(
        (await catalogs.current())!.item(item.id).priceCents,
        tabletPrice + 2,
      );

      // Eine Änderung am Tablet, die älter ist als die im Browser (die Uhr
      // des Tablets geht nach): nach demselben Abgleich steht am Tablet
      // wieder der Wert des Servers.
      final browserAgain = tabletPrice + 3;
      await admin.call(
        'PATCH',
        '/items/${item.id}',
        json: {'priceCents': browserAgain},
      );
      await syncAndExpectNoError();
      expect(
        (await catalogs.current())!.item(item.id).priceCents,
        browserAgain,
      );
      final behind = CatalogRepository(
        db,
        clock: _FixedClock(DateTime.now().subtract(const Duration(hours: 1))),
      );
      await behind.updateItem(item.id, priceCents: tabletPrice + 4);
      await syncAndExpectNoError();
      expect((await admin.item(item.id))['priceCents'], browserAgain);
      expect(
        (await catalogs.current())!.item(item.id).priceCents,
        browserAgain,
      );

      // Foto im Browser: nach dem Abgleich liegt die Datei am Tablet.
      final photo = await admin.call(
        'PUT',
        '/items/${item.id}/photo',
        image: photoWebp,
      );
      final photoId = (photo['file'] as Map)['id'] as String;
      await syncAndExpectNoError();
      final photoPath = (await catalogs.current())!.item(item.id).photoPath;
      expect(photoPath, '${fileDir.path}/$photoId.webp');
      expect(File(photoPath!).lengthSync(), greaterThan(0));

      // 250 Bons auf einmal (ein neuer Tag beginnt mit dem ersten): alles
      // kommt in mehreren Paketen an, die Liste ist danach leer.
      for (var n = 0; n < 250; n++) {
        await receipts.finalizeCashSale(
          saleId: 'bbbbbbbb-0000-4000-8000-${n.toString().padLeft(12, '0')}',
          cart: cart,
          givenCents: cart.totalCents,
          staff: chef,
        );
      }
      expect(await outboxCount(), 251);
      await syncAndExpectNoError();
      expect(await admin.receipts(registerName), hasLength(252));
      expect(await admin.days(registerName), hasLength(2));

      // Noch ein Lauf: nichts ist doppelt, nichts ändert sich.
      Future<String> serverState() async => jsonEncode([
        await admin.receipts(registerName),
        await admin.days(registerName),
        await admin.item(item.id),
      ]);
      Future<String> tabletState() async {
        final i = (await catalogs.current())!.item(item.id);
        return jsonEncode([i.priceCents, i.photoPath]);
      }

      final serverBefore = await serverState();
      final tabletBefore = await tabletState();
      await syncAndExpectNoError();
      expect(await serverState(), serverBefore);
      expect(await tabletState(), tabletBefore);

      // Probe-Signatur: Startbeleg und ein Verkauf. Die Einträge der Kette
      // kommen an, die Protokoll-Datei im Browser enthält sie in Reihenfolge.
      await rksv.enableProbe(staff: chef);
      await receipts.finalizeCashSale(
        saleId: 'cccccccc-0000-4000-8000-000000000001',
        cart: cart,
        givenCents: cart.totalCents,
        staff: chef,
      );
      await syncAndExpectNoError();
      final local = await (db.select(
        db.rksvEntryRows,
      )..orderBy([(t) => OrderingTerm.asc(t.position)])).get();
      expect(local, hasLength(greaterThanOrEqualTo(2)));
      final dep = await admin.call(
        'GET',
        '/registers/${paired.registerId}/dep?chain=1',
      );
      final groups = (dep['Belege-Gruppe'] as List)
          .cast<Map<String, dynamic>>();
      expect(
        [for (final g in groups) ...(g['Belege-kompakt'] as List)],
        [for (final e in local) e.jws],
      );
      expect(await admin.receipts(registerName), hasLength(252 + local.length));
    },
    skip: _skip,
    timeout: const Timeout(Duration(minutes: 3)),
  );
  test(
    'gemischter Bon mit Rabatt und Trinkgeld kommt am Server an',
    () async {
      const registerName = 'Kassa Rabatt und Trinkgeld';
      final db = KassaDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final client = http.Client();
      addTearDown(client.close);
      final admin = _Admin();
      addTearDown(admin.close);
      final fileDir = await Directory.systemTemp.createTemp('kassa-e2e-files');
      addTearDown(() => fileDir.delete(recursive: true));

      final tokens = MemoryTokenStore();
      final syncState = SyncStateRepository(db);
      final changes = ServerChanges(db);
      const clock = SystemClock();
      final api = ServerApi(
        baseUrl: _server,
        client: client,
        appVersion: '1.11.0',
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
        files: FileSync(db, api, () async => fileDir),
      );
      addTearDown(sync.dispose);
      final days = DayRepository(db, clock);
      final receipts = ReceiptRepository(db, clock, days);

      final code =
          (await admin.call(
                'POST',
                '/pairing-codes',
                json: {'name': registerName},
              ))['code']
              as String;
      await pairing.pair(code);
      await pairing.loadInitial();
      final chef = (await StaffRepository(db).findByPin('1234'))!;

      // 15,36 € nach 2,84 € Rabatt: 10,00 € bar, 5,36 € mit Karte und
      // 0,64 € Trinkgeld auf der Karte.
      expect(discounted.totalCents, 1536);
      final sale = await receipts.finalizeCardSale(
        saleId: 'dddddddd-0000-4000-8000-000000000001',
        cart: discounted,
        staff: chef,
        provider: 'sumup',
        txCode: 'TX-e2e-gemischt',
        cardScheme: 'VISA',
        cardLast4: '4242',
        cashPartCents: 1000,
        tipCents: 64,
      );
      await sync.syncNow();
      expect((await syncState.current()).lastError, isNull);
      expect(
        (await db.customSelect('SELECT COUNT(*) AS c FROM outbox').getSingle())
            .read<int>('c'),
        0,
      );

      final bon = await admin.call('GET', '/receipts/${sale.id}');
      expect(bon['payments'], hasLength(2));
      expect(bon['tipCents'], 64);
      expect(bon['discountCents'], 284);

      final serverDays = await admin.days(registerName);
      expect(serverDays, hasLength(1));
      final day = await admin.call('GET', '/days/${serverDays.single['id']}');
      expect(day['cashCents'], 1000);
      expect(day['cardCents'], 536);
      expect(day['cardTipCents'], 64);
      expect(day['discountCount'], 1);
    },
    skip: _skip,
    timeout: const Timeout(Duration(minutes: 1)),
  );
}
