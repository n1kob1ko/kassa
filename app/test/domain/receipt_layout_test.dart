import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/domain/catalog.dart';
import 'package:kassa/domain/cart.dart';
import 'package:kassa/domain/print_document.dart';
import 'package:kassa/domain/receipt.dart';
import 'package:kassa/domain/receipt_layout.dart';
import 'package:kassa/rksv/setup_facts.dart';

import '../support/fake_atrust.dart';
import '../support/rksv_rig.dart';
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

/// [r] mit Eintrag im Protokoll.
Receipt _withStamp(
  Receipt r, {
  bool probe = true,
  bool damaged = false,
  String qrText = _qrText,
}) => Receipt(
  id: r.id,
  number: r.number,
  createdAt: r.createdAt,
  staffId: r.staffId,
  staffName: r.staffName,
  businessDayId: r.businessDayId,
  kind: r.kind,
  voidsReceiptId: r.voidsReceiptId,
  lines: r.lines,
  payment: r.payment,
  rksv: RksvStamp(
    cashBoxId: 'K7QM2XB4HN',
    qrText: qrText,
    damaged: damaged,
    probe: probe,
  ),
  goodsCents: r.goodsCents,
  depositCents: r.depositCents,
  totalCents: r.totalCents,
);

const _qrText =
    '_R1-AT0_K7QM2XB4HN_12_2026-11-17T11:00:00_0,00_0,00_0,00_0,00_0,00_x_y_z';

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

/// Ein Startbeleg, wie Task 5 ihn schreiben wird: ohne Zeilen, Zahlung, Tag.
Receipt startReceipt() => Receipt(
  id: 'start',
  number: 7,
  createdAt: DateTime(2026, 11, 17, 11),
  staffId: 's',
  staffName: 'Anna',
  businessDayId: null,
  kind: ReceiptKind.start,
  lines: const [],
  payment: null,
  goodsCents: 0,
  depositCents: 0,
  totalCents: 0,
);

void main() {
  test('Startbeleg: Kopf, STARTBELEG, Bon-Kopf, Linie, Summe 0,00, keine '
      'Zahlung', () {
    final d = layoutReceipt(startReceipt(), business);
    expect(texts(d), [
      'Beispiel-Imbiss',
      'Musterstraße 1',
      '1010 Wien',
      'UID ATU12345678',
      '-' * 48,
      'STARTBELEG',
      row('Bon Nr. 7', '17.11.2026 11:00'),
      'Bedienung: Anna',
      '-' * 48,
      row('SUMME EUR', '0,00'),
      '-' * 48,
      'Danke und bis bald!',
      'TESTBON',
      'Keine gültige Rechnung',
    ]);
    final title = d.whereType<PrintText>().singleWhere(
      (x) => x.text == 'STARTBELEG',
    );
    expect((title.align, title.bold), (PrintAlign.center, true));
    expect(d.last, isA<PrintCut>());
  });

  test('jede Art von Sonderbeleg steht in Großbuchstaben da', () {
    for (final k in ReceiptKind.values.where((k) => k.isSpecial)) {
      final r = Receipt(
        id: k.name,
        number: 1,
        createdAt: DateTime(2026, 11, 17, 11),
        staffId: 's',
        staffName: 'Anna',
        businessDayId: null,
        kind: k,
        lines: const [],
        payment: null,
        goodsCents: 0,
        depositCents: 0,
        totalCents: 0,
      );
      final t = texts(layoutReceipt(r, business));
      expect(t, contains(k.specialTitle!.toUpperCase()));
      expect(t, isNot(contains('STORNO')));
      expect(
        t.where((x) => x.startsWith('Bar') || x.startsWith('Karte')),
        isEmpty,
      );
    }
  });

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

  test('Storno-Bon ohne bekannte Nummer: STORNO steht trotzdem da, keine '
      'Zeile "zu Bon Nr."', () async {
    final shop = await TestShop.open();
    addTearDown(shop.close);
    final r = await shop.sell('s1');
    final v = await shop.receipts.voidReceipt(r.id, staff: shop.chef);
    final t = texts(layoutReceipt(v, business));
    expect(t, containsAllInOrder(['STORNO', row('SUMME EUR', '-18,20')]));
    expect(t.where((x) => x.startsWith('zu Bon Nr.')), isEmpty);
    // Ein gewöhnlicher Bon trägt das Wort nicht.
    expect(texts(layoutReceipt(r, business)), isNot(contains('STORNO')));
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
    final r = _withStamp(await saleOf(cart, given: 2000), probe: false);
    final d = layoutReceipt(r, const BusinessInfo(name: 'Beispiel-Imbiss'));
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

  group('Kassen-Kennung und QR-Code', () {
    test('Probe-Verkauf: Kennung, Code nach der Zahlung, TESTBON', () async {
      final r = _withStamp(await saleOf(cart, given: 2000));
      final d = layoutReceipt(r, business);
      final t = texts(d);
      final staff = t.indexWhere((x) => x.startsWith('Bedienung:'));
      expect(t[staff + 1], 'Kassen-ID: K7QM2XB4HN');
      final qr = d.indexWhere((o) => o is PrintQr);
      expect((d[qr] as PrintQr).data, _qrText);
      expect(d[qr - 1], isA<PrintFeed>());
      final pay = d.indexWhere(
        (o) => o is PrintText && o.text.startsWith('Bar'),
      );
      final change = d.indexWhere(
        (o) => o is PrintText && o.text.startsWith('Rückgeld'),
      );
      expect(change, greaterThan(pay));
      expect(qr, greaterThan(change));
      expect(t, contains('TESTBON'));
      expect(t, isNot(contains('Sicherheitseinrichtung ausgefallen')));
    });

    test('Ausfall-Bon: der Satz steht mittig unter dem Code', () async {
      final r = _withStamp(
        await saleOf(cart, given: 2000),
        probe: false,
        damaged: true,
      );
      final d = layoutReceipt(r, business);
      final qr = d.indexWhere((o) => o is PrintQr);
      final next = d[qr + 1] as PrintText;
      expect(next.text, 'Sicherheitseinrichtung ausgefallen');
      expect(next.align, PrintAlign.center);
      expect(texts(d), isNot(contains('TESTBON')));
    });

    test('Bon ohne Eintrag: wie bisher, kein Code, TESTBON', () async {
      final d = layoutReceipt(await saleOf(cart, given: 2000), business);
      expect(d.whereType<PrintQr>(), isEmpty);
      expect(texts(d).where((x) => x.startsWith('Kassen-ID')), isEmpty);
      expect(texts(d), contains('TESTBON'));
    });

    test(
      'Bon einer live-Kette (echt signiert und mit Ausfall): kein TESTBON, '
      'keine Zeile "Keine gültige Rechnung", beim Ausfall der Vermerk',
      () async {
        final atrust = FakeAtrust();
        final rig = await RksvRig.open(atrust: atrust);
        addTearDown(rig.close);
        await rig.seedLive();
        final signed = await rig.sell('l1', cart);
        expect(signed.rksv!.probe, isFalse);
        final t = texts(layoutReceipt(signed, business));
        expect(t, contains('Kassen-ID: ${RksvRig.liveCashBoxId}'));
        expect(t, isNot(contains('TESTBON')));
        expect(t, isNot(contains('Keine gültige Rechnung')));
        expect(t, isNot(contains('Sicherheitseinrichtung ausgefallen')));

        atrust.signStatus = 500;
        final damaged = await rig.sell('l2', cart);
        expect(damaged.rksv!.damaged, isTrue);
        final d = texts(layoutReceipt(damaged, business));
        expect(d, contains('Sicherheitseinrichtung ausgefallen'));
        expect(d, isNot(contains('TESTBON')));
        expect(d, isNot(contains('Keine gültige Rechnung')));
      },
    );

    test('Sonderbeleg: der Code folgt der Summe', () async {
      final shop = await TestShop.open();
      addTearDown(shop.close);
      await shop.insertSpecialReceipt('z', 5, ReceiptKind.zero);
      final r = _withStamp(await shop.receipts.byId('z'), probe: false);
      final d = layoutReceipt(r, business);
      final sum = d.indexWhere(
        (o) => o is PrintText && o.text.startsWith('SUMME'),
      );
      final qr = d.indexWhere((o) => o is PrintQr);
      expect(qr, greaterThan(sum));
    });
  });

  group('Zettel "Angaben für FinanzOnline"', () {
    // Erfundene Werte.
    const facts = SetupFacts(
      kind: setupKind,
      provider: 'AT1 = A-TRUST',
      certSerialHex: '2159b9f6',
      certSerialDecimal: '559528438',
      cashBoxId: 'R4TW9KD2PX',
      aesKeyBase64: 'k3Vt9mQe2Lx8RbY1uZp0Hfd6Wc4NsJ7aGiTo5EyPqMw=',
      aesChecksum: 'Jq4T',
    );

    test('Überschrift, Betrieb, Zeit, je Angabe Name und Wert, Schlüssel in '
        'zwei Zeilen, Hinweis unten', () {
      final d = layoutSetupFacts(
        facts,
        business,
        DateTime(2026, 11, 20, 10, 15),
      );
      expect(texts(d), [
        'Angaben für FinanzOnline',
        'Beispiel-Imbiss',
        '20.11.2026 10:15',
        '-' * 48,
        'Art der Sicherheitseinrichtung',
        'Hardware-Sicherheitsmodul (HSM) eines',
        'Dienstleisters',
        'Anbieter',
        'AT1 = A-TRUST',
        'Seriennummer des Zertifikats',
        '2159b9f6',
        'dezimal 559528438',
        'Kassenidentifikationsnummer',
        'R4TW9KD2PX',
        'AES-Schlüssel',
        'k3Vt9mQe2Lx8RbY1uZp0Hf',
        'd6Wc4NsJ7aGiTo5EyPqMw=',
        'Prüfwert',
        'Jq4T',
        '-' * 48,
        'Diesen Zettel sicher aufheben. Der AES-Schlüssel',
        'ist geheim.',
      ]);
      final title = d.whereType<PrintText>().first;
      expect(title.bold, isTrue);
      expect(title.align, PrintAlign.center);
      // Kein QR-Code, kein TESTBON, und am Ende wird geschnitten.
      expect(d.whereType<PrintQr>(), isEmpty);
      expect(texts(d).where((l) => l.contains('TESTBON')), isEmpty);
      expect(d.last, isA<PrintCut>());
    });

    test('mit der Karte: die Zeile "Art der Sicherheitseinrichtung" trägt '
        '"Signaturkarte"', () {
      const card = SetupFacts(
        kind: setupKindCard,
        provider: 'AT1 = A-TRUST',
        certSerialHex: '2159b9f6',
        certSerialDecimal: '559528438',
        cashBoxId: 'R4TW9KD2PX',
        aesKeyBase64: 'k3Vt9mQe2Lx8RbY1uZp0Hfd6Wc4NsJ7aGiTo5EyPqMw=',
        aesChecksum: 'Jq4T',
      );
      final t = texts(
        layoutSetupFacts(card, business, DateTime(2026, 11, 22, 10, 15)),
      );
      final kind = t.indexOf('Art der Sicherheitseinrichtung');
      expect(t.sublist(kind, kind + 3), [
        'Art der Sicherheitseinrichtung',
        'Signaturkarte',
        'Anbieter',
      ]);
    });

    test('schmales Papier: lange Werte brechen um, der Schlüssel bleibt in '
        'zwei Zeilen zu je 22 Zeichen', () {
      const long = SetupFacts(
        kind: setupKind,
        provider: 'AT1 = A-TRUST',
        certSerialHex: '7a3f00c2e91b5d4486f2a0c7e35b19d24f68a0c1',
        certSerialDecimal: '698412639015284377109264590118374920571833640257',
        cashBoxId: 'R4TW9KD2PX',
        aesKeyBase64: 'k3Vt9mQe2Lx8RbY1uZp0Hfd6Wc4NsJ7aGiTo5EyPqMw=',
        aesChecksum: 'Jq4T',
      );
      final t = texts(
        layoutSetupFacts(
          long,
          business,
          DateTime(2026, 11, 20, 10, 15),
          columns: 32,
        ),
      );
      expect(t.every((l) => l.length <= 32), isTrue);
      expect(t.join(), contains('7a3f00c2e91b5d4486f2a0c7e35b19d24f68a0c1'));
      expect(
        t.join(),
        contains('698412639015284377109264590118374920571833640257'),
      );
      final key = t.indexOf('AES-Schlüssel');
      expect(t.sublist(key + 1, key + 3), [
        'k3Vt9mQe2Lx8RbY1uZp0Hf',
        'd6Wc4NsJ7aGiTo5EyPqMw=',
      ]);
      expect(t[key + 3], 'Prüfwert');
    });
  });
}
