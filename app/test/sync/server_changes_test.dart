import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/catalog_repository.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/data/settings_repository.dart';
import 'package:kassa/data/staff_repository.dart';
import 'package:kassa/data/sync_state_repository.dart';
import 'package:kassa/domain/receipt.dart';
import 'package:kassa/features/login/session.dart';
import 'package:kassa/sync/server_changes.dart';
import 'package:kassa/sync/wire.dart';

import '../support/fake_server.dart';
import '../support/sales.dart';

final at = DateTime(2026, 11, 18, 10);

/// Meldet über den Weg der Anmeldung am Tablet an, wie der PIN-Bildschirm.
Future<String?> loginName(KassaDatabase db, String pin) async {
  final container = ProviderContainer(
    overrides: [databaseProvider.overrideWithValue(db)],
  );
  addTearDown(container.dispose);
  final ok = await container.read(sessionProvider.notifier).login(pin);
  return ok ? container.read(sessionProvider)!.name : null;
}

/// Alle Zeilen, die das Einspielen berühren darf, zum Vergleichen vorher und
/// nachher.
Future<List<Object>> snapshot(KassaDatabase db) async => [
  await db.select(db.businessRows).get(),
  await db.select(db.categoryRows).get(),
  await db.select(db.itemRows).get(),
  await db.select(db.modifierTemplateRows).get(),
  await db.select(db.modifierGroupRows).get(),
  await db.select(db.modifierOptionRows).get(),
  await db.select(db.staffRows).get(),
  await db.select(db.settingsRows).get(),
  await db.select(db.syncStateRows).get(),
];

String describe(Receipt r) => [
  for (final l in r.lines)
    '${l.name} ${l.info} ${l.unitPriceCents} x${l.quantity} '
        '${l.unitDepositCents} '
        '${[for (final o in l.options) '${o.groupName}:${o.optionName}:${o.surchargeCents}']}',
].join('\n');

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('replaceAll', () {
    test('replaceAll auf leerem Tablet: Speisekarte, Chefin, Betriebsdaten sind da, Cursor = next', () async {
      final db = KassaDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final server = FakeServer.beispiel();
      // Die Kategorie ändert sich nach den Artikeln: sie kommt erst auf der
      // letzten Seite, die Artikel davor.
      server.change('categories', 'bowls', {'name': 'Schüsseln'});
      final pages = server.pages();
      expect(pages.length, greaterThan(2));

      await ServerChanges(db).replaceAll(pages, at: at);

      final c = (await CatalogRepository(db).current())!;
      expect(c.business.name, 'Beispiel-Imbiss');
      expect(c.business.addressLines, ['Musterstraße 1', '1010 Wien']);
      expect(c.business.vatId, 'ATU12345678');
      expect(c.business.receiptFooter, 'Danke und bis bald!');
      expect([for (final k in c.categories) k.name], ['Schüsseln', 'Getränke']);
      expect(
        [for (final i in c.items) i.id],
        ['huhn-bowl', 'teigtaschen', 'cola'],
      );
      final cola = c.item('cola');
      expect(cola.priceCents, 290);
      expect(cola.depositCents, 25);
      expect(cola.taxRate.percent, 20);
      expect(c.item('teigtaschen').info, '5 Stück');
      expect(c.item('huhn-bowl').tags.map((t) => t.name), ['spicy']);
      final bowl = c.templateOf(c.item('huhn-bowl'))!;
      expect([for (final g in bowl.groups) g.name], ['Größe', 'Extra-Sauce']);
      expect(bowl.groups[0].options.map((o) => o.name), ['Normal', 'XXL']);
      expect(bowl.groups[0].options[1].surchargeCents, 200);
      expect(bowl.groups[1].max, isNull);

      final staff = await StaffRepository(db).all();
      expect([for (final s in staff) (s.name, s.isChef)], [('Chefin', true)]);

      final state = await SyncStateRepository(db).current();
      expect(state.pullCursor, pages.last.next);
      expect(state.pullCursor, server.seq);
      expect(state.initialPullDone, isTrue);
      expect(state.lastPullAt, at);
      expect(state.lastError, isNull);
    });

    test('replaceAll auf eingerichtetem Tablet: Artikel, die der Server nicht hat, sind stillgelegt, nicht gelöscht', () async {
      final shop = await TestShop.open();
      addTearDown(shop.close);
      final db = shop.db;
      final before = await db.select(db.itemRows).get();
      expect(before.map((r) => r.id), contains('leitungswasser'));

      await ServerChanges(db).replaceAll(FakeServer.beispiel().pages(), at: at);

      final rows = {
        for (final r in await db.select(db.itemRows).get()) r.id: r,
      };
      expect(rows.keys.toSet(), containsAll(before.map((r) => r.id)));
      for (final id in rows.keys) {
        final known = const {'huhn-bowl', 'teigtaschen', 'cola'}.contains(id);
        expect(rows[id]!.archived, !known, reason: id);
      }
      final categories = await db.select(db.categoryRows).get();
      for (final k in categories) {
        expect(k.archived, !const {'bowls', 'getraenke'}.contains(k.id));
      }
      final c = (await CatalogRepository(db).current())!;
      expect(c.items.map((i) => i.id).toSet(), {
        'huhn-bowl',
        'teigtaschen',
        'cola',
      });
    });

    test('replaceAll: ein alter Bon bleibt lesbar und zeigt seine Namen und Preise', () async {
      final shop = await TestShop.open();
      addTearDown(shop.close);
      final sold = await shop.sell('s1');
      final before = describe(await shop.receipts.byId('s1'));
      expect(before, contains('XXL'));

      final server = FakeServer.beispiel()
        ..change('items', 'huhn-bowl', {
          'name': 'Hühner-Bowl',
          'priceCents': 1490,
        })
        ..archive('items', 'cola');
      await ServerChanges(shop.db).replaceAll(server.pages(), at: at);

      final after = await shop.receipts.byId('s1');
      expect(describe(after), before);
      expect(after.totalCents, sold.totalCents);
      expect(after.staffName, 'Anna');
      expect(describe(after), isNot(contains('Hühner-Bowl')));
    });

    test('replaceAll: Mitarbeiter vom Tablet sind weg, die vom Server melden mit ihrer PIN an', () async {
      final shop = await TestShop.open();
      addTearDown(shop.close);
      expect(await loginName(shop.db, '1111'), 'Anna');

      final server = FakeServer.beispiel()
        ..upsert(
          'staff',
          FakeServer.staffRow(id: 's-ben', name: 'Ben', pin: '4321'),
        );
      await ServerChanges(shop.db).replaceAll(server.pages(), at: at);

      expect(await loginName(shop.db, '1111'), isNull);
      expect(await loginName(shop.db, '2222'), isNull);
      expect(await loginName(shop.db, '1234'), 'Chefin');
      expect(await loginName(shop.db, '4321'), 'Ben');
      final staff = await StaffRepository(shop.db).all();
      expect(
        {for (final s in staff) s.name: s.isChef},
        {'Chefin': true, 'Ben': false},
      );
    });

    test('replaceAll: der offene Bon ist geleert', () async {
      final shop = await TestShop.open();
      addTearDown(shop.close);
      final settings = SettingsRepository(shop.db);
      await settings.writeDraft('{"lines":[{"itemId":"cola"}]}');

      await ServerChanges(shop.db)
          .replaceAll(FakeServer.beispiel().pages(), at: at);

      expect(await settings.readDraft(), isNull);
    });

    test('replaceAll scheitert mitten drin: Speisekarte, Mitarbeiter, Cursor und Entwurf sind unverändert', () async {
      final shop = await TestShop.open();
      addTearDown(shop.close);
      final db = shop.db;
      await SettingsRepository(db).writeDraft('{"lines":[]}');
      final sync = SyncStateRepository(db);
      await sync.saveRegister(
        registerId: 'r',
        registerName: 'Kassa 1',
        businessId: 'b',
      );
      await sync.setResult(at: DateTime(2026, 11, 17), error: 'offline');
      final before = await snapshot(db);

      // Seite 2 verweist auf eine Kategorie, die es nicht gibt.
      final server = FakeServer.beispiel()
        ..upsert('items', {
          ...FakeServer.beispiel().rowOf('items', 'cola'),
          'id': 'geist',
          'categoryId': 'gibt-es-nicht',
        });
      final pages = server.pages();
      expect(pages.length, greaterThan(1));

      await expectLater(
        ServerChanges(db).replaceAll(pages, at: at),
        throwsA(isA<SqliteException>()),
      );

      expect(await snapshot(db), before);
      expect(await loginName(db, '1111'), 'Anna');
    });
  });

  group('applyPage', () {
    late KassaDatabase db;
    late FakeServer server;
    late ServerChanges changes;
    late SyncStateRepository sync;

    setUp(() async {
      db = KassaDatabase(NativeDatabase.memory());
      server = FakeServer.beispiel();
      changes = ServerChanges(db);
      sync = SyncStateRepository(db);
      await sync.saveRegister(
        registerId: FakeServer.registerId,
        registerName: 'Kassa 1',
        businessId: FakeServer.businessId,
      );
      await changes.replaceAll(server.pages(), at: at);
    });

    Future<bool> apply(PullResponse page, DateTime when) async =>
        changes.applyPage(
          page,
          at: when,
          since: (await sync.current()).pullCursor,
          registerId: FakeServer.registerId,
        );
    tearDown(() => db.close());

    Future<void> pullAll(DateTime when) async {
      while (true) {
        final page = server.page((await sync.current()).pullCursor);
        expect(await apply(page, when), isTrue);
        if (!page.more) return;
      }
    }

    Future<ItemRow> item(String id) =>
        (db.select(db.itemRows)..where((t) => t.id.equals(id))).getSingle();

    test('applyPage: Preis ändert sich, photoPath bleibt', () async {
      await (db.update(db.itemRows)..where((t) => t.id.equals('huhn-bowl')))
          .write(const ItemRowsCompanion(photoPath: Value('fotos/bowl.jpg')));
      server.change('items', 'huhn-bowl', {'priceCents': 1090});
      final later = at.add(const Duration(minutes: 5));

      final page = server.page((await sync.current()).pullCursor);
      expect(await apply(page, later), isTrue);

      final row = await item('huhn-bowl');
      expect(row.priceCents, 1090);
      expect(row.photoPath, 'fotos/bowl.jpg');
      final state = await sync.current();
      expect(state.pullCursor, page.next);
      expect(state.pullCursor, server.seq);
      expect(state.lastPullAt, later);
    });

    test('applyPage: stillgelegter Artikel verschwindet aus dem Verkauf, taucht mit archived=false wieder auf', () async {
      server.archive('items', 'cola');
      await pullAll(at);
      var c = (await CatalogRepository(db).current())!;
      expect(c.items.map((i) => i.id), isNot(contains('cola')));
      expect((await item('cola')).archived, isTrue);

      server.change('items', 'cola', {'archived': false});
      await pullAll(at);
      c = (await CatalogRepository(db).current())!;
      expect(c.items.map((i) => i.id), contains('cola'));
      expect((await item('cola')).archived, isFalse);
    });

    test('applyPage: Vorlage mit einer Option weniger hat danach genau die neuen Optionen', () async {
      final groups = [
        for (final g in server.rowOf('templates', 'bowl')['groups']! as List)
          Map<String, Object?>.of(g as Map<String, dynamic>),
      ];
      groups[0]['options'] = [(groups[0]['options']! as List).first];
      server.change('templates', 'bowl', {'groups': groups});
      await pullAll(at);

      final options = await db.select(db.modifierOptionRows).get();
      expect(options.map((o) => o.id).toSet(), {'bowl/0/0', 'bowl/1/0'});
      final c = (await CatalogRepository(db).current())!;
      final bowl = c.templateOf(c.item('huhn-bowl'))!;
      expect(bowl.groups.map((g) => g.name), ['Größe', 'Extra-Sauce']);
      expect(bowl.groups[0].options.map((o) => o.name), ['Normal']);

      // Eine stillgelegte Vorlage ist samt Gruppen und Optionen weg.
      server.archive('templates', 'bowl');
      await pullAll(at);
      expect(await db.select(db.modifierTemplateRows).get(), isEmpty);
      expect(await db.select(db.modifierGroupRows).get(), isEmpty);
      expect(await db.select(db.modifierOptionRows).get(), isEmpty);
    });

    test(
      'applyPage: stillgelegte Mitarbeiterin kann sich nicht mehr anmelden',
      () async {
        server.upsert(
          'staff',
          FakeServer.staffRow(id: 's-anna', name: 'Anna', pin: '5555'),
        );
        await pullAll(at);
        expect(await loginName(db, '5555'), 'Anna');

        server.archive('staff', 's-anna');
        await pullAll(at);
        expect(await loginName(db, '5555'), isNull);
        expect(await loginName(db, '1234'), 'Chefin');
      },
    );

    test('applyPage: ein Artikel vor seiner neuen Kategorie (nächste Seite) bricht nicht ab', () async {
      server.upsert('categories', {
        'id': 'suppen',
        'name': 'Suppen',
        'position': 2,
        'archived': false,
      });
      server.upsert('items', {
        ...server.rowOf('items', 'cola'),
        'id': 'pho',
        'name': 'Pho',
        'categoryId': 'suppen',
      });
      // Die Kategorie ändert sich danach noch einmal und rückt hinter den
      // Artikel auf die nächste Seite.
      server.pageSize = 1;
      server.change('categories', 'suppen', {'name': 'Suppe'});

      await pullAll(at);

      final c = (await CatalogRepository(db).current())!;
      expect(c.item('pho').categoryId, 'suppen');
      expect(c.categories.firstWhere((k) => k.id == 'suppen').name, 'Suppe');
      expect((await sync.current()).pullCursor, server.seq);
    });

    test('applyPage scheitert: Cursor bleibt, nichts ist halb übernommen', () async {
      final before = await snapshot(db);
      server.change('categories', 'bowls', {'name': 'Schüsseln'});
      server.change('items', 'cola', {'priceCents': 310});
      // Zwei Gruppen mit derselben Kennung verletzen den Schlüssel der Tabelle.
      final groups = server.rowOf('templates', 'bowl')['groups']! as List;
      server.change('templates', 'bowl', {
        'groups': [groups[0], groups[0]],
      });
      server.pageSize = 10;
      final page = server.page((await sync.current()).pullCursor);

      await expectLater(
        apply(page, at.add(const Duration(hours: 1))),
        throwsA(isA<SqliteException>()),
      );

      expect(await snapshot(db), before);
    });

    test('applyPage mit altem Cursor, anderer Kassa oder vor dem ersten Laden schreibt nichts', () async {
      server.change('items', 'cola', {'priceCents': 310});
      final cursor = (await sync.current()).pullCursor;
      final page = server.page(cursor);
      final before = await snapshot(db);

      // Ein anderer Lauf ist schon weiter.
      expect(
        await changes.applyPage(
          page,
          at: at,
          since: cursor - 1,
          registerId: FakeServer.registerId,
        ),
        isFalse,
      );
      // Inzwischen neu gekoppelt: eine andere Kassa.
      expect(
        await changes.applyPage(
          page,
          at: at,
          since: cursor,
          registerId: 'alte-kassa',
        ),
        isFalse,
      );
      expect(await snapshot(db), before);

      // Neu gekoppelt, erstes Laden steht noch aus.
      await sync.saveRegister(
        registerId: FakeServer.registerId,
        registerName: 'Kassa 1',
        businessId: FakeServer.businessId,
      );
      final waiting = await snapshot(db);
      expect(
        await changes.applyPage(
          page,
          at: at,
          since: 0,
          registerId: FakeServer.registerId,
        ),
        isFalse,
      );
      expect(await snapshot(db), waiting);
    });
  });
}
