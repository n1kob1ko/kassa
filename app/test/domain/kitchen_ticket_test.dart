import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/core/app_language.dart';
import 'package:kassa/domain/catalog.dart';
import 'package:kassa/domain/kitchen_ticket.dart';
import 'package:kassa/domain/menu_dictionary.dart';
import 'package:kassa/domain/receipt.dart';

const texts = KitchenTexts(
  title: 'MUTFAK',
  voided: 'İPTAL',
  copy: 'KOPYA',
  sample: 'DENEME',
);

const dictionary = MenuDictionary({
  'Dürüm': {'tr': 'Tavuk şiş dürüm'},
  'Scharf': {'tr': 'Acı sos'},
  'Suppe': {'tr': 'Mercimek çorbası'},
});

ReceiptLine line(
  String itemId,
  String name,
  int quantity, {
  String? info,
  List<String> options = const [],
}) => ReceiptLine(
  position: 0,
  itemId: itemId,
  name: name,
  info: info,
  unitPriceCents: 500,
  quantity: quantity,
  unitDepositCents: 0,
  options: [
    for (final o in options)
      ReceiptLineOption(groupName: 'Gruppe', optionName: o, surchargeCents: 0),
  ],
);

Receipt receipt(
  List<ReceiptLine> lines, {
  ReceiptKind kind = ReceiptKind.sale,
  int number = 128,
}) => Receipt(
  id: 'r-$number',
  number: number,
  createdAt: DateTime(2026, 11, 26, 14, 32),
  staffId: 's1',
  staffName: 'Ayşe',
  businessDayId: kind.isSpecial ? null : 'd1',
  kind: kind,
  lines: lines,
  payment: null,
  goodsCents: 0,
  depositCents: 0,
  totalCents: 0,
);

KitchenTicket? build(
  Receipt r, {
  AppLanguage language = AppLanguage.tr,
  MenuDictionary dict = dictionary,
  Map<String, String> categoryOfItem = const {},
  Set<String> skip = const {},
  bool copy = false,
  int? voidedNumber,
}) => buildKitchenTicket(
  r,
  language: language,
  texts: texts,
  dictionary: dict,
  categoryOfItem: categoryOfItem,
  skipCategories: skip,
  copy: copy,
  voidedNumber: voidedNumber,
);

void main() {
  test('Verkauf in Türkisch: Zeilen in Bon-Reihenfolge mit Wörterbuch', () {
    final t = build(
      receipt([
        line('i1', 'Dürüm', 2, options: ['Scharf', 'Ohne Zwiebel']),
        line('i2', 'Suppe', 1),
        line('i1', 'Dürüm', 1),
      ]),
    )!;
    expect(t.language, AppLanguage.tr);
    expect(t.kind, KitchenTicketKind.order);
    expect(t.title, 'MUTFAK');
    expect(t.banner, isNull);
    expect(t.number, 128);
    expect(t.time, DateTime(2026, 11, 26, 14, 32));
    expect(t.staffName, 'Ayşe');
    expect([for (final l in t.lines) l.quantity], [2, 1, 1]);
    expect(
      [for (final l in t.lines) l.name],
      ['Tavuk şiş dürüm', 'Mercimek çorbası', 'Tavuk şiş dürüm'],
    );
    // Übersetzte Option, fehlende Übersetzung gibt den Namen vom Bon.
    expect(t.lines.first.options, ['Acı sos', 'Ohne Zwiebel']);
  });

  test('Info wird über das Wörterbuch geschlagen', () {
    final t = build(receipt([line('i1', 'Dürüm', 1, info: 'Scharf')]))!;
    expect(t.lines.single.info, 'Acı sos');
    expect(build(receipt([line('i1', 'Dürüm', 1)]))!.lines.single.info, isNull);
  });

  test('fehlende Übersetzung gibt den Namen aus dem Bon', () {
    final t = build(receipt([line('i9', 'Pommes', 1)]))!;
    expect(t.lines.single.name, 'Pommes');
  });

  test('Deutsch bleibt beim Namen aus dem Bon', () {
    final t = build(
      receipt([line('i1', 'Dürüm', 1)]),
      language: AppLanguage.de,
    )!;
    expect(t.lines.single.name, 'Dürüm');
  });

  test('Kategorie ohne Küche wird übersprungen', () {
    final t = build(
      receipt([line('i1', 'Dürüm', 1), line('i3', 'Cola', 2)]),
      categoryOfItem: {'i1': 'speisen', 'i3': 'getraenke'},
      skip: {'getraenke'},
    )!;
    expect([for (final l in t.lines) l.name], ['Tavuk şiş dürüm']);
  });

  test('nur Getränke gibt null', () {
    final t = build(
      receipt([line('i3', 'Cola', 2)]),
      categoryOfItem: {'i3': 'getraenke'},
      skip: {'getraenke'},
    );
    expect(t, isNull);
  });

  test('Sonderbeleg gibt null', () {
    expect(build(receipt([], kind: ReceiptKind.start)), isNull);
    expect(
      build(receipt([line('i1', 'Dürüm', 1)], kind: ReceiptKind.month)),
      isNull,
    );
  });

  test('Storno hat Banner, positive Anzahl und die Nummer des Stornierten', () {
    final r = receipt(
      [line('i1', 'Dürüm', -2)],
      kind: ReceiptKind.voided,
      number: 130,
    );
    final t = build(r, voidedNumber: 128)!;
    expect(t.kind, KitchenTicketKind.voided);
    expect(t.banner, 'İPTAL');
    expect(t.lines.single.quantity, 2);
    expect(t.number, 128);
    // Ohne Angabe: die eigene Nummer.
    expect(build(r)!.number, 130);
  });

  test('stillgelegter und unbekannter Artikel bleiben mit dem Bon-Namen', () {
    final t = build(
      receipt([line('alt', 'Alte Suppe', 1), line('weg', 'Dürüm', 1)]),
      categoryOfItem: {'alt': 'speisen'},
      skip: {'getraenke'},
    )!;
    expect(t.lines.length, 2);
    expect(t.lines.first.name, 'Alte Suppe');
    expect(t.lines.last.name, 'Tavuk şiş dürüm');
  });

  test('Storno mit copy bleibt STORNO (kein KOPIE-Balken)', () {
    final r = receipt(
      [line('i1', 'Dürüm', -1)],
      kind: ReceiptKind.voided,
      number: 130,
    );
    final t = build(r, copy: true, voidedNumber: 128)!;
    expect(t.kind, KitchenTicketKind.voided);
    expect(t.banner, 'İPTAL');
  });

  test('copy setzt Banner KOPIE', () {
    final t = build(receipt([line('i1', 'Dürüm', 1)]), copy: true)!;
    expect(t.kind, KitchenTicketKind.copy);
    expect(t.banner, 'KOPYA');
  });

  group('Probe', () {
    const catalog = Catalog(
      business: BusinessInfo(name: 'Beispiel-Imbiss'),
      categories: [
        Category(id: 'speisen', name: 'Speisen', position: 0),
        Category(id: 'getraenke', name: 'Getränke', position: 1),
      ],
      items: [
        Item(
          id: 'c',
          name: 'Cola',
          priceCents: 300,
          categoryId: 'getraenke',
          taxRate: TaxRate.normal,
          position: 0,
        ),
        Item(
          id: 'a',
          name: 'Dürüm',
          priceCents: 800,
          categoryId: 'speisen',
          taxRate: TaxRate.normal,
          templateId: 't',
          position: 1,
        ),
        Item(
          id: 'x',
          name: 'Alt',
          priceCents: 800,
          categoryId: 'speisen',
          taxRate: TaxRate.normal,
          inSale: false,
          position: 2,
        ),
        Item(
          id: 'b',
          name: 'Suppe',
          priceCents: 400,
          categoryId: 'speisen',
          taxRate: TaxRate.normal,
          position: 3,
        ),
        Item(
          id: 'd',
          name: 'Salat',
          priceCents: 400,
          categoryId: 'speisen',
          taxRate: TaxRate.normal,
          position: 4,
        ),
        Item(
          id: 'e',
          name: 'Reis',
          priceCents: 400,
          categoryId: 'speisen',
          taxRate: TaxRate.normal,
          position: 5,
        ),
      ],
      templates: [
        ModifierTemplate(
          id: 't',
          name: 'Dürüm',
          groups: [
            ModifierGroup(
              id: 'g1',
              name: 'Soße',
              min: 0,
              max: 1,
              options: [
                ModifierOption(id: 'o1', name: 'Mild'),
                ModifierOption(id: 'o2', name: 'Scharf', isDefault: true),
              ],
            ),
            ModifierGroup(
              id: 'g2',
              name: 'Extra',
              min: 0,
              max: null,
              options: [ModifierOption(id: 'o3', name: 'Zwiebel')],
            ),
            ModifierGroup(
              id: 'g3',
              name: 'Größe',
              min: 0,
              max: 1,
              options: [ModifierOption(id: 'o4', name: 'Groß')],
            ),
          ],
        ),
      ],
    );
    final now = DateTime(2026, 11, 26, 14, 32);

    KitchenTicket sample(Catalog c, Set<String> skip) => sampleKitchenTicket(
      c,
      language: AppLanguage.tr,
      texts: texts,
      dictionary: dictionary,
      skipCategories: skip,
      now: now,
    );

    test(
      'drei aktive Artikel aus Küchen-Kategorien, 2/1/1, bis zu zwei Optionen',
      () {
        final t = sample(catalog, {'getraenke'});
        expect(t.kind, KitchenTicketKind.sample);
        expect(t.banner, 'DENEME');
        expect(t.staffName, 'DENEME');
        expect(t.number, 128);
        expect(t.time, now);
        expect(t.title, 'MUTFAK');
        expect(
          [for (final l in t.lines) l.name],
          ['Tavuk şiş dürüm', 'Mercimek çorbası', 'Salat'],
        );
        expect([for (final l in t.lines) l.quantity], [2, 1, 1]);
        expect(t.lines.first.options, ['Acı sos', 'Zwiebel']);
        expect(t.lines[1].options, isEmpty);
      },
    );

    test('leere Speisekarte gibt eine Zeile mit dem Probe-Text', () {
      final empty = Catalog(
        business: catalog.business,
        categories: const [],
        items: const [],
        templates: const [],
      );
      final t = sample(empty, {});
      expect(t.lines.length, 1);
      expect(t.lines.single.name, 'DENEME');
      expect(t.lines.single.quantity, 1);
    });
  });
}
