import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/domain/catalog.dart';
import 'package:kassa/domain/cart.dart';
import 'package:kassa/domain/print_document.dart';
import 'package:kassa/domain/receipt.dart';
import 'package:kassa/domain/receipt_layout.dart';

import '../support/sales.dart';

String row(String l, String r, [int w = 48]) =>
    l + ' ' * (w - l.length - r.length) + r;
List<String> texts(List<PrintOp> d) => [
  for (final o in d)
    if (o is PrintText) o.text,
];

const business = BusinessInfo(
  name: 'Beispiel-Imbiss',
  addressLines: ['Musterstraße 1', '1010 Wien'],
  vatId: 'ATU12345678',
  receiptFooter: 'Danke und bis bald!',
);

int _saleCount = 0;

/// Verkauft [c] bar über die Testumgebung und liefert den gespeicherten Bon.
Future<Receipt> saleOf(Cart c, {required int given}) async {
  final shop = await TestShop.open();
  addTearDown(shop.close);
  return shop.receipts.finalizeCashSale(
    saleId: 'sale-${_saleCount++}',
    cart: c,
    givenCents: given,
    staff: shop.anna,
  );
}

/// Ein Bon mit sehr langem Artikelnamen, Menge 99 zu 150,00 €.
Receipt longNames() {
  const gross = 99 * 15000;
  return Receipt(
    id: 'long',
    number: 12345,
    createdAt: DateTime(2026, 11, 17, 11),
    staffId: 's',
    staffName: 'Anna Maria Musterfrau-Beispiel',
    businessDayId: 'd',
    kind: ReceiptKind.sale,
    lines: const [
      ReceiptLine(
        position: 1,
        itemId: 'x',
        name:
            'Hausgemachte Teigtaschen mit Gemüsefüllung und Erdnuss-Sauce '
            'nach Art des Hauses',
        info: '12 Stück Großpackung',
        unitPriceCents: 15000,
        quantity: 99,
        unitDepositCents: 0,
        options: [
          ReceiptLineOption(
            groupName: 'Sauce',
            optionName: 'Extra scharfe Sauce nach Geheimrezept der Großmutter',
            surchargeCents: 200,
          ),
        ],
        grossByRate: {TaxRate.reduced1: gross},
      ),
    ],
    payment: const Payment(
      kind: PaymentKind.cash,
      amountCents: gross,
      givenCents: gross,
      changeCents: 0,
    ),
    goodsCents: gross,
    depositCents: 0,
    totalCents: gross,
  );
}

void main() {
  test('Barbon: Kopf, Zeilen, Pfand, Summe, Steuer, Zahlung, Ende', () async {
    final r = await saleOf(cart, given: 2000);
    final d = layoutReceipt(r, business);
    final t = texts(d);
    expect(
      d.first,
      isA<PrintText>()
          .having((x) => x.size, 'size', PrintSize.doubleBoth)
          .having((x) => x.text, 'text', 'Beispiel-Imbiss'),
    );
    expect(
      t,
      containsAllInOrder([
        'Musterstraße 1',
        '1010 Wien',
        'UID ATU12345678',
        '-' * 48,
        row('Bon Nr. 1', '17.11.2026 11:00'),
        'Bedienung: Anna',
        row('2 x Cola 0,33 l', '5,80'),
        '    je 2,90',
        row('1 x Huhn Bowl', '11,90'),
        '    XXL (+2,00)',
        '    Nudeln',
        row('Pfand', '0,50'),
        row('SUMME EUR', '18,20'),
        row('20 % MwSt 0,97  Netto 4,83', '5,80'),
        row('10 % MwSt 1,08  Netto 10,82', '11,90'),
        row('Bar', '18,20'),
        row('Gegeben', '20,00'),
        row('Rückgeld', '1,80'),
        'Danke und bis bald!',
        'TESTBON',
        'Keine gültige Rechnung',
      ]),
    );
    expect(d[d.length - 2], isA<PrintFeed>());
    expect(d.last, isA<PrintCut>());
  });

  test('Summe steht fett in doppelter Höhe', () async {
    final r = await saleOf(cart, given: 2000);
    final sum = layoutReceipt(
      r,
      business,
    ).whereType<PrintText>().firstWhere((x) => x.text.startsWith('SUMME EUR'));
    expect(sum.bold, isTrue);
    expect(sum.size, PrintSize.doubleHeight);
  });

  test('passend bezahlt: keine Zeilen Gegeben und Rückgeld', () async {
    final r = await saleOf(cart, given: 1820);
    final t = texts(layoutReceipt(r, business));
    expect(t, contains(row('Bar', '18,20')));
    expect(t.where((x) => x.startsWith('Gegeben')), isEmpty);
    expect(t.where((x) => x.startsWith('Rückgeld')), isEmpty);
  });

  test('Storno-Bon: STORNO, zu Bon Nr. 1, negative Beträge', () async {
    final shop = await TestShop.open();
    addTearDown(shop.close);
    final r = await shop.sell('s1');
    final v = await shop.receipts.voidReceipt(r.id, staff: shop.chef);
    final t = texts(layoutReceipt(v, business, voidedNumber: r.number));
    expect(
      t,
      containsAllInOrder([
        'STORNO',
        'zu Bon Nr. 1',
        row('-2 x Cola 0,33 l', '-5,80'),
        row('SUMME EUR', '-18,20'),
      ]),
    );
  });

  test('Kartenzahlung: eine Zeile Karte', () async {
    final shop = await TestShop.open();
    addTearDown(shop.close);
    await shop.days.openOrCreateDay();
    await shop.insertCardReceipt('c1', 1, 1820);
    final r = await shop.receipts.byId('c1');
    final t = texts(layoutReceipt(r, business));
    expect(t, contains(row('Karte', '18,20')));
    expect(t.where((x) => x.startsWith('Gegeben')), isEmpty);
  });

  test('Kartenbon: Karte, MASTERCARD **** 1234, Beleg TX1, keine Zeile '
      'Gegeben', () async {
    final shop = await TestShop.open();
    addTearDown(shop.close);
    final r = await shop.receipts.finalizeCardSale(
      saleId: 'c1',
      cart: cart,
      staff: shop.anna,
      provider: 'sumup',
      txCode: 'TX1',
      cardScheme: 'MASTERCARD',
      cardLast4: '1234',
    );
    final t = texts(layoutReceipt(r, business));
    final i = t.indexOf(row('Karte', '18,20'));
    expect(i, isNonNegative);
    expect(t[i + 1].trim(), 'MASTERCARD **** 1234');
    expect(t[i + 2].trim(), 'Beleg TX1');
    expect(t.where((x) => x.startsWith('Gegeben')), isEmpty);
  });

  test('Kartenbon ohne Kartendaten: nur die Zeile Karte', () async {
    final shop = await TestShop.open();
    addTearDown(shop.close);
    final bare = await shop.receipts.finalizeCardSale(
      saleId: 'c2',
      cart: cart,
      staff: shop.anna,
      provider: 'sumup',
    );
    final t = texts(layoutReceipt(bare, business));
    final i = t.indexWhere((x) => x.startsWith('Karte'));
    expect(t.any((x) => x.contains('****') || x.contains('Beleg')), isFalse);
    expect(i, isNonNegative);
  });

  test(
    'keine Zeile ist breiter als das Papier, auch bei 42 und 32 Zeichen',
    () {
      const wide = BusinessInfo(
        name: 'Hausgemachte Spezialitäten vom Beispiel-Imbiss am Marktplatz',
        addressLines: ['Donaudampfschifffahrtsgesellschaftsstraße 1234567'],
        vatId: 'ATU12345678',
        receiptFooter:
            'Vielen Dank für Ihren Besuch, wir freuen uns auf Ihren nächsten '
            'Einkauf – Supercalifragilisticexpialigetischerweisedochnicht',
      );
      for (final w in [48, 42, 32]) {
        for (final b in [business, wide]) {
          for (final o in layoutReceipt(
            longNames(),
            b,
            columns: w,
          ).whereType<PrintText>()) {
            expect(
              o.text.length,
              lessThanOrEqualTo(o.size == PrintSize.doubleBoth ? w ~/ 2 : w),
              reason: '"${o.text}" bei $w Zeichen',
            );
          }
        }
      }
    },
  );

  test(
    'langer Name: Betrag steht rechts in der ersten Zeile, Rest eingerückt',
    () {
      final t = texts(layoutReceipt(longNames(), business));
      final i = t.indexWhere((x) => x.startsWith('99 x Hausgemachte'));
      expect(i, greaterThan(0));
      expect(t[i].length, 48);
      expect(t[i], endsWith('14.850,00'));
      expect(t[i + 1], startsWith('    '));
      expect(t[i + 1].trim(), isNotEmpty);
      expect(t[i + 1], isNot(contains('14.850,00')));
      expect(t.skip(i).take(6), contains('    je 150,00'));
    },
  );

  test('ein zu langes Wort wird hart geschnitten', () {
    final t = texts(
      layoutReceipt(longNames(), BusinessInfo(name: 'A' * 70), columns: 32),
    );
    expect(t.first, 'A' * 32);
    expect(t[1], 'A' * 32);
    expect(t[2], 'A' * 6);
  });

  test('Zeichen, die der Drucker nicht kennt', () {
    expect(printable('Phở Bò'), 'Pho Bò');
    expect(printable('Crème brûlée'), 'Crème brûlée');
    expect(printable('Größe 0,5 l – 3 €'), 'Größe 0,5 l - 3 €');
    expect(printable('麻婆豆腐 Mapo'), '???? Mapo');
    expect(printable('a\tb\nc'), 'a b c');
    expect(printable('“x” „y“ ‘z’ wait…'), '"x" "y" \'z\' wait...');
    expect(printable('Čeština Łódź Şiş ū'), 'Cestina Lódz Sis u');
    expect(printable('a b'), 'a b');
    expect(printable('😀'), '?');
  });

  test('alle PC858-Zeichen bleiben unverändert', () {
    expect(printable(pc858Characters), pc858Characters);
  });

  test('ohne Adresse, UID und Bon-Ende fehlen die Zeilen, nichts ist leer '
      'gedruckt', () async {
    final r = await saleOf(cart, given: 2000);
    final d = layoutReceipt(
      r,
      const BusinessInfo(name: 'Beispiel-Imbiss'),
      testMarker: false,
    );
    final t = texts(d);
    expect(t.where((x) => x.startsWith('UID')), isEmpty);
    expect(t.where((x) => x.trim().isEmpty), isEmpty);
    expect(t, isNot(contains('TESTBON')));
    expect(t[1], '-' * 48);
    expect(t.last, row('Rückgeld', '1,80'));
    expect(d[d.length - 2], isA<PrintFeed>());
    expect(d.last, isA<PrintCut>());
  });

  test('amount', () {
    expect(amount(0), '0,00');
    expect(amount(-290), '-2,90');
    expect(amount(123450), '1.234,50');
    expect(amount(5), '0,05');
    expect(amount(100000000), '1.000.000,00');
  });

  test('Testdruck nennt Betrieb, Zeit und zeigt ein Lineal über die volle '
      'Breite', () {
    final t = texts(layoutTestPrint(business, DateTime(2026, 11, 17, 11)));
    expect(
      t,
      containsAll([
        'Testdruck',
        'Beispiel-Imbiss',
        '17.11.2026 11:00',
        '123456789012345678901234567890123456789012345678',
        'ä ö ü ß € sind lesbar',
      ]),
    );
  });
}
