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
import 'package:kassa/data/customer_repository.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/day_repository.dart';
import 'package:kassa/data/delivery_repository.dart';
import 'package:kassa/data/outbox_repository.dart';
import 'package:kassa/data/receipt_repository.dart';
import 'package:kassa/data/staff_repository.dart';
import 'package:kassa/data/sync_state_repository.dart';
import 'package:kassa/data/voucher_repository.dart';
import 'package:kassa/domain/cart.dart';
import 'package:kassa/domain/catalog.dart';
import 'package:kassa/domain/day.dart';
import 'package:kassa/domain/staff.dart';
import 'package:kassa/rksv/core/rksv_code.dart' show formatCodeAmount;
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

/// Der zweite Kopplungscode aus `server/src/dev/seed.ts` (SEED_CODE2=1): eine
/// zweite Kassa desselben Betriebs.
const _code2 = String.fromEnvironment('E2E_CODE2');

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

/// Eine Kassa für die Tests ab Stufe 1b: Datenbank im Speicher, gekoppelt
/// mit einem Kopplungscode und mit allem vom Server, ohne Signatur (ihre Bons
/// sind Übungs-Bons, ihre Gutscheine Übungs-Gutscheine). Räumt am Ende des
/// Tests selbst auf.
class _Register {
  _Register._(
    this.db,
    this.tokens,
    this.syncState,
    this.api,
    this.sync,
    this.receipts,
    this.chef,
    this.catalog,
  );

  final KassaDatabase db;
  final MemoryTokenStore tokens;
  final SyncStateRepository syncState;
  final ServerApi api;
  final SyncService sync;
  final ReceiptRepository receipts;
  final Staff chef;
  final Catalog catalog;

  late final VoucherRepository vouchers = VoucherRepository(db);

  static const clock = SystemClock();

  static Future<_Register> pair(String code) async {
    final db = KassaDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final client = http.Client();
    addTearDown(client.close);
    final fileDir = await Directory.systemTemp.createTemp('kassa-e2e-files');
    addTearDown(() => fileDir.delete(recursive: true));
    final tokens = MemoryTokenStore();
    final syncState = SyncStateRepository(db);
    final changes = ServerChanges(db);
    final api = ServerApi(
      baseUrl: _server,
      client: client,
      appVersion: '1.12.0',
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
    await pairing.pair(code);
    await pairing.loadInitial();
    return _Register._(
      db,
      tokens,
      syncState,
      api,
      sync,
      ReceiptRepository(db, clock, DayRepository(db, clock)),
      (await StaffRepository(db).findByPin('1234'))!,
      (await CatalogRepository(db, clock: clock).current())!,
    );
  }

  /// Gleicht ab und liefert den Fehler des Laufs (null ohne).
  Future<String?> syncNow() async {
    await sync.syncNow();
    return (await syncState.current()).lastError;
  }

  /// So viele Einträge warten noch in "noch zu senden".
  Future<int> outboxCount() async =>
      (await db.customSelect('SELECT COUNT(*) AS c FROM outbox').getSingle())
          .read<int>('c');
}

/// Die öffentliche Seite des Bons mit dem Schlüssel [token], ohne Anmeldung.
Future<http.Response> _receiptPage(String token) =>
    http.get(Uri.parse('$_server/beleg/$token'));

/// Eine Reihe der Seite des Bons, wie der Server sie schreibt.
String _pageRow(String label, int cents, {bool sub = false}) =>
    '<tr${sub ? ' class="sub"' : ''}><th scope="row">$label</th>'
    '<td>${formatCodeAmount(cents)}</td></tr>';

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

  test(
    'Gutschein-Verkauf und Einlösung kommen am Server an; die Seite des Bons '
    'zeigt dieselben Zahlen',
    () async {
      final admin = _Admin();
      addTearDown(admin.close);
      final reg = await _Register.pair(
        (await admin.call(
              'POST',
              '/pairing-codes',
              json: {'name': 'Kassa Gutschein'},
            ))['code']
            as String,
      );

      // Ein Gutschein über 25,00 €, bar verkauft.
      final sale = await reg.receipts.finalizeCashSale(
        saleId: 'ffffffff-0000-4000-8000-000000000001',
        cart: const Cart.empty().addVoucherSale(valueCents: 2500),
        givenCents: 2500,
        staff: reg.chef,
      );
      final voucher = (await reg.vouchers.byId(
        sale.soldVouchers.single.voucherId,
      ))!;
      expect(await reg.syncNow(), isNull);
      expect(await reg.outboxCount(), 0);
      Future<Map<String, dynamic>> onServer() async =>
          ((await admin.call('GET', '/vouchers'))['vouchers'] as List)
              .cast<Map<String, dynamic>>()
              .singleWhere((v) => v['id'] == voucher.id);
      final before = await onServer();
      expect(
        (
          before['code'],
          before['valueCents'],
          before['balanceCents'],
          before['state'],
        ),
        (voucher.code, 2500, 2500, 'active'),
      );

      // Eingelöst auf 4 × Teigtaschen (über 25,00 €), der Rest bar.
      final teigtaschen = reg.catalog.item('teigtaschen');
      final four = const Cart.empty().add(teigtaschen);
      final cart = four
          .setQuantity(four.lines.single.lineId, 4)
          .applyVoucher(applied(voucher));
      expect(cart.totalCents, greaterThan(2500));
      final rest = cart.totalCents - 2500;
      expect(cart.pricing.dueCents, rest);
      final paid = await reg.receipts.finalizeCashSale(
        saleId: 'ffffffff-0000-4000-8000-000000000002',
        cart: cart,
        givenCents: rest,
        staff: reg.chef,
      );
      expect(
        [
          for (final p in paid.payments)
            (p.kind.name, p.amountCents, p.voucherBalanceAfterCents),
        ],
        [('voucher', 2500, 0), ('cash', rest, null)],
      );
      expect(await reg.syncNow(), isNull);
      expect(await reg.outboxCount(), 0);

      // Am Server dasselbe Guthaben wie am Tablet, mit beiden Bewegungen.
      final tabletBalance = (await reg.vouchers.byId(voucher.id))!.balanceCents;
      expect(tabletBalance, 0);
      final after = await onServer();
      expect(
        (after['valueCents'], after['balanceCents'], after['state']),
        (2500, tabletBalance, 'empty'),
      );
      final detail = await admin.call('GET', '/vouchers/${voucher.id}');
      expect(
        [
          for (final m in (detail['movements'] as List).cast<Map>())
            (m['receiptId'], m['amountCents']),
        ],
        [(sale.id, 2500), (paid.id, -2500)],
      );
      final bon = await admin.call('GET', '/receipts/${paid.id}');
      expect(bon['totalCents'], paid.totalCents);
      expect(bon['pageUrl'], '/beleg/${paid.publicToken}');

      // Die Seite des Bons: Summe, Gutschein, Restguthaben und Bar wie am
      // Tablet.
      final page = await _receiptPage(paid.publicToken!);
      expect(page.statusCode, 200);
      final last4 = voucher.code.substring(voucher.code.length - 4);
      for (final row in [
        _pageRow(
          'SUMME EUR',
          paid.totalCents,
        ).replaceFirst('<tr>', '<tr class="strong">'),
        _pageRow('Gutschein •••• $last4', paid.payments[0].amountCents),
        _pageRow(
          'Restguthaben',
          paid.payments[0].voucherBalanceAfterCents!,
          sub: true,
        ),
        _pageRow('Bar', paid.payments[1].amountCents),
      ]) {
        expect(page.body, contains(row));
      }

      // Ein falscher Schlüssel: 404 (nur einer, der Server bremst Fehlversuche).
      final token = paid.publicToken!;
      final wrong =
          '${token.substring(0, token.length - 1)}'
          '${token.endsWith('A') ? 'B' : 'A'}';
      expect((await _receiptPage(wrong)).statusCode, 404);
    },
    skip: _skip,
    timeout: const Timeout(Duration(minutes: 1)),
  );

  test(
    'eine zweite Kassa kennt den Gutschein nach dem Abgleich und kann ihn '
    'einlösen',
    () async {
      final admin = _Admin();
      addTearDown(admin.close);
      final first = await _Register.pair(
        (await admin.call(
              'POST',
              '/pairing-codes',
              json: {'name': 'Kassa Gutschein eins'},
            ))['code']
            as String,
      );
      final sale = await first.receipts.finalizeCashSale(
        saleId: 'ffffffff-0000-4000-8000-000000000011',
        cart: const Cart.empty().addVoucherSale(valueCents: 2500),
        givenCents: 2500,
        staff: first.chef,
      );
      final voucher = (await first.vouchers.byId(
        sale.soldVouchers.single.voucherId,
      ))!;
      expect(await first.syncNow(), isNull);
      expect(await first.outboxCount(), 0);

      // Die zweite Kassa koppelt mit dem zweiten Code aus seed.ts und holt.
      final second = await _Register.pair(_code2);
      final found = await second.vouchers.findByCode(voucher.code);
      expect(
        [for (final v in found) (v.id, v.balanceCents)],
        [(voucher.id, 2500)],
      );

      // Einlösen an der zweiten Kassa, ganz mit dem Gutschein.
      final cart = const Cart.empty()
          .add(second.catalog.item('teigtaschen'))
          .applyVoucher(applied(found.single));
      expect(cart.totalCents, lessThan(2500));
      final redeemed = await second.receipts.finalizeVoucherSale(
        saleId: 'ffffffff-0000-4000-8000-000000000012',
        cart: cart,
        staff: second.chef,
      );
      expect(
        redeemed.payments.single.voucherBalanceAfterCents,
        2500 - cart.totalCents,
      );
      expect(await second.syncNow(), isNull);
      expect(await second.outboxCount(), 0);

      // Die erste Kassa sieht nach ihrem Abgleich das neue Guthaben.
      expect((await first.vouchers.byId(voucher.id))!.balanceCents, 2500);
      expect(await first.syncNow(), isNull);
      expect(
        (await first.vouchers.byId(voucher.id))!.balanceCents,
        2500 - cart.totalCents,
      );
    },
    skip: _skip ?? (_code2.isEmpty ? 'Ohne E2E_CODE2 (tool/e2e.sh).' : null),
    timeout: const Timeout(Duration(minutes: 1)),
  );

  test(
    'Auszahlung, Empfänger und Belegerteilung kommen an',
    () async {
      final admin = _Admin();
      addTearDown(admin.close);
      final reg = await _Register.pair(
        (await admin.call(
              'POST',
              '/pairing-codes',
              json: {'name': 'Kassa Auszahlung'},
            ))['code']
            as String,
      );

      // 3 × Pfand zurück zu 0,25 €: ein Bon unter 0, bar ausbezahlt.
      final payout = await reg.receipts.finalizePayout(
        saleId: 'ffffffff-0000-4000-8000-000000000021',
        cart: const Cart.empty().setDepositReturn(
          depositCents: 25,
          quantity: 3,
        ),
        staff: reg.chef,
      );
      expect(payout.totalCents, -75);
      await CustomerRepository(reg.db, _Register.clock).setRecipient(
        receiptId: payout.id,
        name: 'Muster GmbH',
        addressLine1: 'Musterweg 1',
        addressLine2: '1010 Wien',
        vatId: 'ATU00000000',
        staff: reg.chef,
      );
      final shownAt = DateTime.now();
      await DeliveryRepository(reg.db)
          .record(payout.id, DeliveryKind.digital, at: shownAt);
      expect(await reg.syncNow(), isNull);
      expect(await reg.outboxCount(), 0);

      final bon = await admin.call('GET', '/receipts/${payout.id}');
      expect(bon['totalCents'], -75);
      expect(
        [
          for (final p in (bon['payments'] as List).cast<Map>())
            (p['kind'], p['amountCents']),
        ],
        [('cash', -75)],
      );
      final recipient = bon['recipient'] as Map<String, dynamic>;
      expect(
        (
          recipient['name'],
          recipient['addressLine1'],
          recipient['addressLine2'],
          recipient['vatId'],
          recipient['version'],
          recipient['staffName'],
        ),
        ('Muster GmbH', 'Musterweg 1', '1010 Wien', 'ATU00000000', 0, 'Chefin'),
      );
      final deliveries = (bon['deliveries'] as List).cast<Map>();
      expect([for (final d in deliveries) d['kind']], ['digital']);
      expect(
        DateTime.parse(deliveries.single['at'] as String)
            .difference(shownAt)
            .inSeconds
            .abs(),
        lessThanOrEqualTo(1),
      );

      // Die Seite des Bons nennt die Auszahlung wie das Papier.
      final page = await _receiptPage(payout.publicToken!);
      expect(page.statusCode, 200);
      expect(page.body, contains(_pageRow('Bar ausbezahlt', 75)));
    },
    skip: _skip,
    timeout: const Timeout(Duration(minutes: 1)),
  );

  test(
    'ein Bon aus 1.11.0, der schon am Server ist, kommt nach dem Update als '
    'v: 3 noch einmal: duplicate',
    () async {
      const registerName = 'Kassa nach dem Update';
      final admin = _Admin();
      addTearDown(admin.close);
      final reg = await _Register.pair(
        (await admin.call(
              'POST',
              '/pairing-codes',
              json: {'name': registerName},
            ))['code']
            as String,
      );
      final token = (await reg.tokens.read())!;
      final deviceId = await reg.syncState.deviceId();

      // So hat 1.11.0 den Bon gesendet (v: 2).
      final old = jsonDecode(
        File('../shared/fixtures/sync/receipt_1_11_0_v2.json')
            .readAsStringSync(),
      ) as Map<String, dynamic>;
      final oldEntries = (old['entries'] as List).cast<Map<String, Object?>>();
      final accepted = await reg.api.push(
        token: token,
        deviceId: deviceId,
        entries: oldEntries,
      );
      expect(
        [for (final r in accepted) (r.seq, r.status)],
        [(8, PushStatus.accepted)],
      );

      // Dieselbe Datenbank von 1.11.0 nach dem Update (Migration 8 zu 9):
      // der Bon geht noch einmal hinaus, jetzt als v: 3.
      final dir = await Directory.systemTemp.createTemp('kassa-e2e-v8');
      addTearDown(() => dir.delete(recursive: true));
      final file = await File(
        'test/data/fixtures/kassa_v8_receipts_1_11_0.sqlite',
      ).copy('${dir.path}/kassa.sqlite');
      final updated = KassaDatabase(NativeDatabase(file));
      addTearDown(updated.close);
      final payloads = PushPayloads(updated);
      final again = <Map<String, Object?>>[
        for (final e in await OutboxRepository(updated).nextBatch())
          if (e.kind == 'receipt' &&
              e.ref == (oldEntries.single['receipt'] as Map)['id'])
            (await payloads.build(e))!,
      ];
      expect([for (final e in again) (e['receipt'] as Map)['v']], [3]);
      final duplicate = await reg.api.push(
        token: token,
        deviceId: deviceId,
        entries: again,
      );
      expect(
        [for (final r in duplicate) (r.seq, r.status)],
        [(8, PushStatus.duplicate)],
      );
      expect(
        [for (final r in await admin.receipts(registerName)) r['id']],
        ['eeeeeeee-1110-4000-8000-000000000001'],
      );
    },
    skip: _skip,
    timeout: const Timeout(Duration(minutes: 1)),
  );
}
