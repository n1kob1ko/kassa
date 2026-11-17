import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/catalog_repository.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/domain/catalog.dart';
import 'package:kassa/domain/menu_import.dart';

/// Kennzeichen als sortierter Text, weil Mengen in Records nicht nach Inhalt
/// verglichen werden.
String _tags(Item i) => (i.tags.map((t) => t.name).toList()..sort()).join(',');

void main() {
  // Zwei Datenbanken im Speicher sind in einzelnen Tests gewollt.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  final demo = File('assets/demo/beispiel-imbiss.json').readAsStringSync();
  final demoOhneTeigtaschen = () {
    final json = jsonDecode(demo) as Map<String, dynamic>;
    (json['artikel'] as List).removeWhere(
      (a) => (a as Map)['id'] == 'teigtaschen',
    );
    return jsonEncode(json);
  }();

  late KassaDatabase db;
  late CatalogRepository repo;

  setUp(() async {
    db = KassaDatabase(NativeDatabase.memory());
    repo = CatalogRepository(db);
    await repo.importCatalog(parseMenuFile(demo));
  });
  tearDown(() => db.close());

  test('Einspielen und Lesen', () async {
    final c = (await repo.current())!;
    expect(c.items, hasLength(14));
    expect(c.templateOf(c.item('huhn-bowl'))!.groups, hasLength(4));
  });

  test('Katalog kommt unverändert wieder heraus', () async {
    final original = parseMenuFile(demo);
    final c = (await repo.current())!;
    expect(c.businessName, original.businessName);
    expect(c.staffSeeds, isEmpty);
    expect(
      c.categories.map((k) => (k.id, k.name, k.position)),
      original.categories.map((k) => (k.id, k.name, k.position)),
    );
    expect(
      c.items.map(
        (i) => (
          i.id,
          i.name,
          i.priceCents,
          i.categoryId,
          i.taxRate,
          i.depositCents,
          _tags(i),
          i.info,
          i.templateId,
          i.favorite,
          i.inSale,
          i.photoPath,
          i.position,
        ),
      ),
      original.items.map(
        (i) => (
          i.id,
          i.name,
          i.priceCents,
          i.categoryId,
          i.taxRate,
          i.depositCents,
          _tags(i),
          i.info,
          i.templateId,
          i.favorite,
          i.inSale,
          i.photoPath,
          i.position,
        ),
      ),
    );
    expect(c.templates.map((t) => t.id), original.templates.map((t) => t.id));
    for (var t = 0; t < original.templates.length; t++) {
      final a = c.templates[t], b = original.templates[t];
      expect(a.name, b.name);
      expect(
        a.groups.map((g) => (g.id, g.name, g.min, g.max)),
        b.groups.map((g) => (g.id, g.name, g.min, g.max)),
      );
      for (var g = 0; g < b.groups.length; g++) {
        expect(
          a.groups[g].options.map(
            (o) => (
              o.id,
              o.name,
              o.surchargeCents,
              o.isDefault,
              o.taxRate,
              o.depositCents,
            ),
          ),
          b.groups[g].options.map(
            (o) => (
              o.id,
              o.name,
              o.surchargeCents,
              o.isDefault,
              o.taxRate,
              o.depositCents,
            ),
          ),
        );
      }
    }
  });

  test('Optionen mit eigenem Steuersatz und Pfand bleiben erhalten', () async {
    final catalog = Catalog(
      business: BusinessInfo(name: 'X'),
      categories: const [Category(id: 'k', name: 'K', position: 0)],
      items: const [
        Item(
          id: 'a',
          name: 'A',
          priceCents: 100,
          categoryId: 'k',
          taxRate: TaxRate.special,
          depositCents: 50,
          tags: {ItemTag.vegan, ItemTag.spicy},
          info: 'Info',
          templateId: 't',
          position: 0,
        ),
      ],
      templates: const [
        ModifierTemplate(
          id: 't',
          name: 't',
          groups: [
            ModifierGroup(
              id: 't/g',
              name: 'g',
              min: 0,
              max: null,
              options: [
                ModifierOption(
                  id: 't/g/o',
                  name: 'o',
                  surchargeCents: 30,
                  isDefault: true,
                  taxRate: TaxRate.reduced2,
                  depositCents: 25,
                ),
              ],
            ),
          ],
        ),
      ],
    );
    await repo.importCatalog(catalog);
    final c = (await repo.current())!;
    final i = c.item('a');
    expect(
      (i.taxRate, i.depositCents, _tags(i), i.info),
      (TaxRate.special, 50, 'spicy,vegan', 'Info'),
    );
    final g = c.templateOf(i)!.groups.single;
    expect(g.max, isNull);
    final o = g.options.single;
    expect(
      (o.taxRate, o.depositCents, o.isDefault, o.surchargeCents),
      (TaxRate.reduced2, 25, true, 30),
    );
  });

  test('nichts eingespielt: current und watch geben null', () async {
    final leer = KassaDatabase(NativeDatabase.memory());
    addTearDown(leer.close);
    final r = CatalogRepository(leer);
    expect(await r.current(), isNull);
    expect(await r.watch().first, isNull);
  });

  test('watch meldet das Einspielen', () async {
    final leer = KassaDatabase(NativeDatabase.memory());
    addTearDown(leer.close);
    final r = CatalogRepository(leer);
    final emitted = expectLater(
      r.watch(),
      emitsInOrder([isNull, isA<Catalog>()]),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await r.importCatalog(parseMenuFile(demo));
    await emitted;
  });

  test('erneutes Einspielen behält Favorit und Im-Verkauf, nimmt den Preis aus der Datei, legt fehlende Artikel still', () async {
    await repo.updateItem(
      'cola',
      favorite: true,
      inSale: false,
      priceCents: 310,
    );
    await repo.importCatalog(parseMenuFile(demoOhneTeigtaschen));
    final c = (await repo.current())!;
    expect(
      (
        c.item('cola').favorite,
        c.item('cola').inSale,
        c.item('cola').priceCents,
      ),
      (true, false, 290),
    );
    expect(c.items.any((i) => i.id == 'teigtaschen'), isFalse);
    final rows = await db
        .customSelect("SELECT archived FROM items WHERE id = 'teigtaschen'")
        .get();
    expect(rows.single.read<bool>('archived'), isTrue);
  });

  test(
    'ein stillgelegter Artikel ist nach erneutem Auftauchen wieder aktiv',
    () async {
      await repo.importCatalog(parseMenuFile(demoOhneTeigtaschen));
      await repo.importCatalog(parseMenuFile(demo));
      final c = (await repo.current())!;
      expect(c.items, hasLength(14));
      expect(c.items.any((i) => i.id == 'teigtaschen'), isTrue);
    },
  );

  test(
    'eine stillgelegte Kategorie ist nach erneutem Auftauchen wieder aktiv',
    () async {
      final original = parseMenuFile(demo);
      final weg = original.categories.last;
      final json = jsonDecode(demo) as Map<String, dynamic>;
      (json['kategorien'] as List).removeWhere(
        (k) => (k as Map)['id'] == weg.id,
      );
      (json['artikel'] as List).removeWhere(
        (a) => (a as Map)['kategorie'] == weg.id,
      );
      await repo.importCatalog(parseMenuFile(jsonEncode(json)));
      expect(
        (await repo.current())!.categories.any((k) => k.id == weg.id),
        isFalse,
      );

      await repo.importCatalog(original);
      final c = (await repo.current())!;
      expect(
        c.categories.map((k) => (k.id, k.position)),
        original.categories.map((k) => (k.id, k.position)),
      );
      expect(c.items, hasLength(original.items.length));
      final ids = c.categories.map((k) => k.id).toSet();
      expect(c.items.every((i) => ids.contains(i.categoryId)), isTrue);
    },
  );

  test('scheitert das Einspielen, bleibt der alte Stand', () async {
    final vorher = (await repo.current())!;
    final kaputt = Catalog(
      business: BusinessInfo(name: 'Anderer Betrieb'),
      categories: const [Category(id: 'k', name: 'K', position: 0)],
      items: const [
        Item(
          id: 'x',
          name: 'X',
          priceCents: 100,
          categoryId: 'gibt-es-nicht',
          taxRate: TaxRate.normal,
          position: 0,
        ),
      ],
      templates: const [],
    );
    await expectLater(repo.importCatalog(kaputt), throwsA(anything));
    final nachher = (await repo.current())!;
    expect(nachher.businessName, vorher.businessName);
    expect(
      nachher.categories.map((k) => k.id),
      vorher.categories.map((k) => k.id),
    );
    expect(
      nachher.items.map((i) => (i.id, i.priceCents)),
      vorher.items.map((i) => (i.id, i.priceCents)),
    );
    expect(
      nachher.templates.map((t) => t.id),
      vorher.templates.map((t) => t.id),
    );
  });

  test(
    'scheitert der Import mitten in der Transaktion, wird zurückgerollt',
    () async {
      // Die Prüfung vorab greift hier nicht: zwei Gruppen mit derselben
      // Kennung scheitern erst beim Schreiben, nachdem der Betrieb schon
      // geändert und alte Vorlagen gelöscht wurden.
      final vorher = (await repo.current())!;
      final kaputt = Catalog(
        business: BusinessInfo(name: 'Anderer Betrieb'),
        categories: const [Category(id: 'k', name: 'K', position: 0)],
        items: const [],
        templates: const [
          ModifierTemplate(
            id: 't',
            name: 't',
            groups: [
              ModifierGroup(id: 'g', name: 'g', min: 0, max: 1, options: []),
              ModifierGroup(id: 'g', name: 'g', min: 0, max: 1, options: []),
            ],
          ),
        ],
      );
      await expectLater(repo.importCatalog(kaputt), throwsA(anything));
      final nachher = (await repo.current())!;
      expect(nachher.businessName, vorher.businessName);
      expect(nachher.items, hasLength(14));
      expect(nachher.templates, hasLength(vorher.templates.length));
    },
  );

  test('updateItem', () async {
    await repo.updateItem('cola', priceCents: 320, tags: {ItemTag.vegan});
    final cola = (await repo.current())!.item('cola');
    expect(cola.priceCents, 320);
    expect(cola.tags, {ItemTag.vegan});
  });

  test('updateItem ändert nur die angegebenen Felder', () async {
    final vorher = (await repo.current())!.item('cola');
    await repo.updateItem('cola', depositCents: 25);
    final nachher = (await repo.current())!.item('cola');
    expect(nachher.depositCents, 25);
    expect(
      (nachher.priceCents, nachher.inSale, nachher.favorite, _tags(nachher)),
      (vorher.priceCents, vorher.inSale, vorher.favorite, _tags(vorher)),
    );
  });

  test('updateItem mit unbekannter Kennung wirft StateError', () async {
    await expectLater(
      repo.updateItem('gibt-es-nicht', priceCents: 1),
      throwsA(isA<StateError>()),
    );
  });

  test(
    'Einspielen speichert die Betriebsdaten, neues Einspielen ersetzt sie',
    () async {
      final first = (await repo.current())!.business;
      expect(first.addressLines, ['Musterstraße 1', '1010 Wien']);
      expect(first.vatId, 'ATU12345678');
      expect(first.receiptFooter, 'Danke und bis bald!');

      final json = jsonDecode(demo) as Map<String, dynamic>
        ..['adresse'] = ['Andere Gasse 2']
        ..remove('uid')
        ..remove('bon_ende');
      await repo.importCatalog(parseMenuFile(jsonEncode(json)));
      final second = (await repo.current())!.business;
      expect(second.name, 'Beispiel-Imbiss');
      expect(second.addressLines, ['Andere Gasse 2']);
      expect(second.vatId, isNull);
      expect(second.receiptFooter, isNull);

      json.remove('adresse');
      await repo.importCatalog(parseMenuFile(jsonEncode(json)));
      expect((await repo.current())!.business.addressLines, isEmpty);
    },
  );
}
