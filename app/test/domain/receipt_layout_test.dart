import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/domain/catalog.dart';
import 'package:kassa/domain/customer.dart';
import 'package:kassa/domain/cart.dart';
import 'package:kassa/domain/discount.dart';
import 'package:kassa/domain/print_document.dart';
import 'package:kassa/domain/receipt.dart';
import 'package:kassa/domain/receipt_layout.dart';
import 'package:kassa/domain/voucher.dart';
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
  payments: r.payments,
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
    payments: const [
      Payment(
        kind: PaymentKind.cash,
        amountCents: gross,
        givenCents: gross,
        changeCents: 0,
      ),
    ],
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
  payments: const [],
  goodsCents: 0,
  depositCents: 0,
  totalCents: 0,
);

/// Die Paare links/rechts der Druckzeilen: rechts der Betrag am Rand, sonst
/// leer.
List<(String, String)> rows(List<PrintOp> d) => [
  for (final t in texts(d))
    if (RegExp(r'^(.*\S)\s+(-?[\d.]+,\d\d)$').firstMatch(t) case final m?)
      (m.group(1)!, m.group(2)!)
    else
      (t, ''),
];

/// [discounted] (Summe 15,36 €) mit 10,00 € bar und 5,36 € mit Karte, dazu
/// 0,64 € Trinkgeld für Anna.
Future<Receipt> mixedDiscounted(TestShop shop) => shop.sellCard(
  'mixed-discounted',
  cart: discounted,
  cashPartCents: 1000,
  tipCents: 64,
);

/// Der Storno-Bon zu [r], vom Chef.
Future<Receipt> voidOf(TestShop shop, Receipt r) =>
    shop.receipts.voidReceipt(r.id, staff: shop.chef);

/// [r] mit Rabatten über 0,00 € auf der ersten Zeile und auf dem Bon.
Receipt withZeroDiscounts(Receipt r) => Receipt(
  id: r.id,
  number: r.number,
  createdAt: r.createdAt,
  staffId: r.staffId,
  staffName: r.staffName,
  businessDayId: r.businessDayId,
  kind: r.kind,
  lines: [
    for (final (i, l) in r.lines.indexed)
      ReceiptLine(
        position: l.position,
        itemId: l.itemId,
        name: l.name,
        info: l.info,
        unitPriceCents: l.unitPriceCents,
        quantity: l.quantity,
        unitDepositCents: l.unitDepositCents,
        options: l.options,
        grossByRate: l.grossByRate,
        discount: i == 0
            ? const ReceiptDiscount(amountCents: 0, reason: 'staff')
            : null,
      ),
  ],
  payments: r.payments,
  goodsCents: r.goodsCents,
  depositCents: r.depositCents,
  totalCents: r.totalCents,
  discount: const ReceiptDiscount(
    percent: 10,
    amountCents: 0,
    reason: 'promotion',
  ),
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
        payments: const [],
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

  group('Rabatt, mehrere Zahlungen und Trinkgeld', () {
    test('Bon mit Zeilen-Rabatt, Bon-Rabatt, Bar-Teil, Karte und '
        'Trinkgeld', () async {
      final shop = await TestShop.open();
      addTearDown(shop.close);
      final r = await mixedDiscounted(shop);
      expect(
        rows(layoutReceipt(r, business)),
        containsAllInOrder([
          ('1 x Huhn Bowl', '11,90'),
          ('  Rabatt 10 % Stammgast', '-1,19'),
          ('Zwischensumme', '16,51'),
          ('Rabatt 10 % Aktion', '-1,65'),
          ('Pfand', '0,50'),
          ('SUMME EUR', '15,36'),
          ('Bar', '10,00'),
          ('Karte', '6,00'),
          ('  davon Trinkgeld', '0,64'),
        ]),
      );
      expect(
        rows(layoutReceipt(r, business)).map((x) => x.$1),
        isNot(contains('Gegeben')),
      );
      expect(
        rows(layoutReceipt(r, business)).map((x) => x.$1),
        isNot(contains('Rückgeld')),
      );
    });

    test('der Zeilen-Rabatt steht nach den Optionen der Zeile', () async {
      final shop = await TestShop.open();
      addTearDown(shop.close);
      final t = texts(layoutReceipt(await mixedDiscounted(shop), business));
      expect(
        t,
        containsAllInOrder([
          row('1 x Huhn Bowl', '11,90'),
          '    XXL (+2,00)',
          '    Nudeln',
          row('  Rabatt 10 % Stammgast', '-1,19'),
          '-' * 48,
          row('Zwischensumme', '16,51'),
        ]),
      );
    });

    test('Storno davon: dieselben Zeilen mit Minus', () async {
      final shop = await TestShop.open();
      addTearDown(shop.close);
      final r = await mixedDiscounted(shop);
      final v = await voidOf(shop, r);
      expect(
        rows(layoutReceipt(v, business, voidedNumber: 1)),
        containsAllInOrder([
          ('  Rabatt 10 % Stammgast', '1,19'),
          ('Zwischensumme', '-16,51'),
          ('Rabatt 10 % Aktion', '1,65'),
          ('SUMME EUR', '-15,36'),
          ('Bar', '-10,00'),
          ('Karte', '-6,00'),
          ('  davon Trinkgeld', '-0,64'),
        ]),
      );
    });

    test('Betrag-Rabatt ohne Prozent: "Rabatt Mitarbeiter"', () async {
      final shop = await TestShop.open();
      addTearDown(shop.close);
      final c = cart.setReceiptDiscount(
        const Discount.amount(200, DiscountReason.staff),
      );
      final r = await shop.receipts.finalizeCashSale(
        saleId: 'staff',
        cart: c,
        givenCents: 2000,
        staff: shop.anna,
      );
      expect(
        rows(layoutReceipt(r, business)),
        containsAllInOrder([
          ('Zwischensumme', '17,70'),
          ('Rabatt Mitarbeiter', '-2,00'),
          ('Pfand', '0,50'),
          ('SUMME EUR', '16,20'),
          // Eine einzige Bar-Zahlung: Gegeben und Rückgeld wie bisher.
          ('Bar', '16,20'),
          ('Gegeben', '20,00'),
          ('Rückgeld', '3,80'),
        ]),
      );
    });

    test('nur ein Zeilen-Rabatt: keine Zwischensumme', () async {
      final shop = await TestShop.open();
      addTearDown(shop.close);
      final c = cart.setLineDiscount(
        cart.lines[0].lineId,
        const Discount.percent(50, DiscountReason.complaint),
      );
      final r = await shop.receipts.finalizeCashSale(
        saleId: 'line',
        cart: c,
        givenCents: 2000,
        staff: shop.anna,
      );
      final t = rows(layoutReceipt(r, business));
      expect(
        t,
        containsAllInOrder([
          ('2 x Cola 0,33 l', '5,80'),
          ('  Rabatt 50 % Reklamation', '-2,90'),
          ('SUMME EUR', '15,30'),
        ]),
      );
      expect(t.map((x) => x.$1), isNot(contains('Zwischensumme')));
    });

    test('Rabatt über 0,00 €: keine Zeile, keine Zwischensumme', () async {
      final r = withZeroDiscounts(await saleOf(cart, given: 2000));
      final plain = texts(
        layoutReceipt(await saleOf(cart, given: 2000), business),
      );
      final t = texts(layoutReceipt(r, business));
      expect(t.where((x) => x.contains('Rabatt')), isEmpty);
      expect(t.where((x) => x.startsWith('Zwischensumme')), isEmpty);
      // Zeile für Zeile wie ohne Rabatt.
      expect(t, plain);
    });

    test('nur Karte mit Trinkgeld: "Karte" mit dem gebuchten Betrag, darunter '
        '"davon Trinkgeld", dann die Karte', () async {
      final shop = await TestShop.open();
      addTearDown(shop.close);
      final r = await shop.sellCard('tip', tipCents: 100);
      final t = texts(layoutReceipt(r, business));
      final i = t.indexOf(row('Karte', '10,65'));
      expect(i, isNonNegative);
      expect(t[i + 1], row('  davon Trinkgeld', '1,00'));
      expect(t[i + 2].trim(), 'VISA **** 4242');
      expect(t.where((x) => x.startsWith('Gegeben')), isEmpty);
    });
  });

  group('ReceiptDiscount.label', () {
    test('Prozent: "Rabatt 10 % Stammgast"', () {
      expect(
        const ReceiptDiscount(
          percent: 10,
          amountCents: 119,
          reason: 'regular',
        ).label,
        'Rabatt 10 % Stammgast',
      );
    });

    test('Betrag: "Rabatt Mitarbeiter"', () {
      expect(
        const ReceiptDiscount(amountCents: 200, reason: 'staff').label,
        'Rabatt Mitarbeiter',
      );
    });

    test('ein unbekannter Grund steht da, wie er ist', () {
      expect(
        const ReceiptDiscount(amountCents: 200, reason: 'geburtstag').label,
        'Rabatt geburtstag',
      );
      expect(
        const ReceiptDiscount(
          percent: 5,
          amountCents: 50,
          reason: 'geburtstag',
        ).label,
        'Rabatt 5 % geburtstag',
      );
    });
  });

  test('Rechnung: RECHNUNG, Rechnung Nr. KASSA-1 / 1042, An: mit Name, '
      'Adresse und UID; ohne Empfänger ist der Bon Zeile für Zeile wie '
      'vorher', () async {
    final sale = await saleOf(cart, given: 2000);
    // Bon Nr. 1042 der Kassa KASSA-1 im echten Betrieb.
    final r = Receipt(
      id: sale.id,
      number: 1042,
      createdAt: sale.createdAt,
      staffId: sale.staffId,
      staffName: sale.staffName,
      businessDayId: sale.businessDayId,
      kind: sale.kind,
      lines: sale.lines,
      payments: sale.payments,
      rksv: const RksvStamp(
        cashBoxId: 'KASSA-1',
        qrText: _qrText,
        damaged: false,
        probe: false,
      ),
      goodsCents: sale.goodsCents,
      depositCents: sale.depositCents,
      totalCents: sale.totalCents,
    );
    final recipient = ReceiptRecipient(
      receiptId: r.id,
      version: 0,
      customerId: 'k1',
      name: 'Muster GmbH',
      addressLine1: 'Musterweg 1',
      addressLine2: '1010 Wien',
      vatId: 'ATU00000000',
      createdAt: DateTime(2026, 11, 17, 11, 5),
      staffId: 's',
      staffName: 'Anna',
    );
    String describe(PrintOp o) => switch (o) {
      PrintText() => 'text ${o.align} ${o.bold} ${o.size} ${o.text}',
      PrintFeed() => 'feed ${o.lines}',
      PrintQr() => 'qr ${o.data}',
      PrintCut() => 'cut',
      PrintDrawerKick() => 'drawer',
    };
    final plain = [for (final o in layoutReceipt(r, business)) describe(o)];
    final invoiceOps = layoutReceipt(r, business, recipient: recipient);
    final invoice = [for (final o in invoiceOps) describe(o)];

    // Nach dem Kopf des Betriebs (bis zur ersten Linie) der Block der
    // Rechnung mit einer eigenen Linie, dann der Bon, wie er ist.
    final head = plain.indexOf(
      'text ${PrintAlign.left} false '
      '${PrintSize.normal} ${'-' * 48}',
    );
    expect(head, greaterThan(0));
    expect(invoice.sublist(0, head + 1), plain.sublist(0, head + 1));
    final block = texts(invoiceOps.sublist(head + 1, head + 9));
    expect(block, [
      'RECHNUNG',
      'Rechnung Nr. KASSA-1 / 1042',
      'An:',
      '    Muster GmbH',
      '    Musterweg 1',
      '    1010 Wien',
      '    UID ATU00000000',
      '-' * 48,
    ]);
    final title = invoiceOps[head + 1] as PrintText;
    expect(title.bold, isTrue);
    expect(title.align, PrintAlign.center);
    expect((invoiceOps[head + 2] as PrintText).align, PrintAlign.center);
    expect(invoice.sublist(head + 9), plain.sublist(head + 1));
    expect(invoice.length, plain.length + 8);
    // Gleiche Nummer, gleicher QR-Code, kein TESTBON.
    expect(
      texts(invoiceOps),
      contains(row('Bon Nr. 1042', '17.11.2026 11:00')),
    );
    expect(invoiceOps.whereType<PrintQr>().single.data, _qrText);
    expect(texts(invoiceOps), isNot(contains('TESTBON')));

    // Ohne UID fehlt die Zeile, ohne Kassen-ID steht nur die Nummer.
    final noVat = ReceiptRecipient(
      receiptId: r.id,
      version: 1,
      customerId: null,
      name: 'Muster GmbH',
      addressLine1: 'Musterweg 1',
      addressLine2: '1010 Wien',
      vatId: null,
      createdAt: DateTime(2026, 11, 17, 11, 6),
      staffId: 's',
      staffName: 'Anna',
    );
    final t = texts(layoutReceipt(r, business, recipient: noVat));
    expect(t.where((x) => x.contains('UID ATU00000000')), isEmpty);
    expect(t, contains('UID ATU12345678'));
    expect(
      texts(layoutReceipt(sale, business, recipient: noVat)),
      contains('Rechnung Nr. 1'),
    );
  });

  test('Rechnung: Name und Adress-Zeilen mit 80 Zeichen brechen auf 48 '
      'Spalten um, ohne Buchstaben zu verlieren und ohne zu lange Zeile', () async {
    final sale = await saleOf(cart, given: 2000);
    String eighty(String word) {
      final words = <String>[];
      var i = 0;
      while ([...words, '$word$i'].join(' ').length <= 80) {
        words.add('$word$i');
        i++;
      }
      final text = words.join(' ');
      return text + 'x' * (80 - text.length);
    }

    final name = eighty('Muster');
    final line1 = eighty('Weg');
    final line2 = eighty('Wien');
    expect([name.length, line1.length, line2.length], [80, 80, 80]);
    final recipient = ReceiptRecipient(
      receiptId: sale.id,
      version: 0,
      customerId: null,
      name: name,
      addressLine1: line1,
      addressLine2: line2,
      vatId: 'ATU00000000',
      createdAt: DateTime(2026, 11, 17, 11, 5),
      staffId: 's',
      staffName: 'Anna',
    );
    final t = texts(layoutReceipt(sale, business, recipient: recipient));
    for (final line in t) {
      expect(line.length, lessThanOrEqualTo(48), reason: line);
    }
    final start = t.indexOf('An:');
    final end = t.indexOf('    UID ATU00000000');
    expect(start, greaterThan(0));
    expect(end, greaterThan(start));
    final block = t.sublist(start + 1, end);
    expect(block.every((l) => l.startsWith('    ')), isTrue, reason: '$block');
    // Wieder zusammengesetzt steht jeder Buchstabe da, in der Reihenfolge.
    expect(
      block.map((l) => l.trim()).join(' '),
      '$name $line1 $line2',
    );
  });

  group('Pfand zurück, Auszahlung und Gutscheine (1.12.0)', () {
    late TestShop shop;
    setUp(() async {
      shop = await TestShop.open();
      addTearDown(shop.close);
    });

    /// [cart] (18,20 € mit 0,50 € Pfand) und 3 × Pfand zurück zu 0,25 €,
    /// bar mit 20,00 €: Summe 17,45 €.
    Future<Receipt> withReturn() => shop.receipts.finalizeCashSale(
      saleId: 'return',
      cart: cart.setDepositReturn(depositCents: 25, quantity: 3),
      givenCents: 2000,
      staff: shop.anna,
    );

    /// Nur 3 × Pfand zurück zu 0,25 €: 0,75 € bar ausbezahlt.
    Future<Receipt> payout() => shop.receipts.finalizePayout(
      saleId: 'payout',
      cart: const Cart.empty().setDepositReturn(depositCents: 25, quantity: 3),
      staff: shop.anna,
    );

    /// Ein Gutschein über 25,00 € bar verkauft, mit 30,00 € gegeben.
    Future<Receipt> voucherSold() => shop.receipts.finalizeCashSale(
      saleId: 'voucher-sold',
      cart: const Cart.empty().addVoucherSale(valueCents: 2500),
      givenCents: 3000,
      staff: shop.anna,
    );

    /// [cartCard] (9,65 €) mit einem Gutschein über 5,00 € und 4,65 € bar.
    Future<(Receipt, SoldVoucher)> voucherAndCash() async {
      final sold = (await shop.receipts.finalizeCashSale(
        saleId: 'voucher-5',
        cart: const Cart.empty().addVoucherSale(valueCents: 500),
        givenCents: 500,
        staff: shop.anna,
      )).soldVouchers.single;
      final r = await shop.receipts.finalizeCashSale(
        saleId: 'voucher-paid',
        cart: cartCard.applyVoucher(
          AppliedVoucher(
            voucherId: sold.voucherId,
            code: sold.code,
            balanceCents: 500,
          ),
        ),
        givenCents: 465,
        staff: shop.anna,
      );
      return (r, sold);
    }

    test('Bon mit Pfand zurück: Zeile mit -0,75 und je -0,25, Pfand 0,50 '
        'bleibt eigene Reihe, SUMME 17,45', () async {
      final r = await withReturn();
      final t = texts(layoutReceipt(r, business));
      expect(
        t,
        containsAllInOrder([
          row('3 x Pfand zurück', '-0,75'),
          '    je -0,25',
          '-' * 48,
          row('Pfand', '0,50'),
          row('SUMME EUR', '17,45'),
          row('Bar', '17,45'),
          row('Gegeben', '20,00'),
          row('Rückgeld', '2,55'),
        ]),
      );
      // Der Warenwert 0 der Zeile steht nirgends, das Pfand nur verlangt.
      expect(t.where((x) => x.startsWith('3 x Pfand zurück')), hasLength(1));
      expect(t.where((x) => x.startsWith('Pfand ')), hasLength(1));
    });

    test('eine einzelne Flasche zurück: keine Zeile "je"', () async {
      final r = await shop.receipts.finalizeCashSale(
        saleId: 'one',
        cart: cart.setDepositReturn(depositCents: 25, quantity: 1),
        givenCents: 2000,
        staff: shop.anna,
      );
      final t = texts(layoutReceipt(r, business));
      expect(t, contains(row('1 x Pfand zurück', '-0,25')));
      expect(t.where((x) => x.contains('je -0,25')), isEmpty);
    });

    test('Auszahlung: SUMME -0,75, "Bar ausbezahlt 0,75", kein Gegeben, kein '
        'Rückgeld', () async {
      final r = await payout();
      final t = texts(layoutReceipt(r, business));
      expect(
        t,
        containsAllInOrder([
          row('3 x Pfand zurück', '-0,75'),
          '    je -0,25',
          row('SUMME EUR', '-0,75'),
          row('Bar ausbezahlt', '0,75'),
        ]),
      );
      // Kein Pfand verlangt: keine Reihe "Pfand"; keine Reihe "Bar".
      expect(t.where((x) => x.startsWith('Pfand ')), isEmpty);
      expect(t.where((x) => x.startsWith('Bar ')), [
        row('Bar ausbezahlt', '0,75'),
      ]);
      expect(t.where((x) => x.startsWith('Gegeben')), isEmpty);
      expect(t.where((x) => x.startsWith('Rückgeld')), isEmpty);
    });

    test('Storno einer Auszahlung: dieselben Reihen mit umgekehrtem '
        'Vorzeichen', () async {
      final r = await payout();
      final v = await voidOf(shop, r);
      final t = texts(layoutReceipt(v, business, voidedNumber: r.number));
      expect(
        t,
        containsAllInOrder([
          'STORNO',
          row('-3 x Pfand zurück', '0,75'),
          '    je -0,25',
          row('SUMME EUR', '0,75'),
          row('Bar ausbezahlt', '-0,75'),
        ]),
      );
      expect(t.where((x) => x.startsWith('Gegeben')), isEmpty);
    });

    test('Gutschein verkauft: Zeile mit Code darunter, "  davon Gutschein '
        '(kein Umsatz) 25,00" eingerückt nach der Steuer', () async {
      final r = await voucherSold();
      final code = formatVoucherCode(r.soldVouchers.single.code);
      final t = texts(layoutReceipt(r, business));
      expect(
        t,
        containsAllInOrder([
          row('1 x Gutschein', '25,00'),
          '    Code $code',
          row('SUMME EUR', '25,00'),
          row('0 % MwSt 0,00  Netto 25,00', '25,00'),
          row('  davon Gutschein (kein Umsatz)', '25,00'),
          row('Bar', '25,00'),
          row('Gegeben', '30,00'),
          row('Rückgeld', '5,00'),
        ]),
      );
      // Der Code hängt nicht mehr am Namen.
      expect(t.where((x) => x.startsWith('1 x Gutschein Code')), isEmpty);
    });

    test('mit Gutschein bezahlt, Rest bar: "Gutschein 1234 5678 5,00", '
        '"Restguthaben 0,00", dann "Bar 4,65"', () async {
      final (r, sold) = await voucherAndCash();
      final code = formatVoucherCode(sold.code);
      final t = texts(layoutReceipt(r, business));
      expect(
        t,
        containsAllInOrder([
          row('SUMME EUR', '9,65'),
          row('Gutschein $code', '5,00'),
          row('  Restguthaben', '0,00'),
          row('Bar', '4,65'),
        ]),
      );
      // Eine Gutschein-Zahlung ist kein Umsatz-Abzug: keine Reihe dafür.
      expect(t.where((x) => x.contains('kein Umsatz')), isEmpty);
    });

    test(
      'nur mit Gutschein bezahlt: keine Reihe "Bar", Restguthaben 15,35',
      () async {
        final sold = (await voucherSold()).soldVouchers.single;
        final r = await shop.receipts.finalizeVoucherSale(
          saleId: 'only-voucher',
          cart: cartCard.applyVoucher(
            AppliedVoucher(
              voucherId: sold.voucherId,
              code: sold.code,
              balanceCents: 2500,
            ),
          ),
          staff: shop.anna,
        );
        final t = texts(layoutReceipt(r, business));
        expect(
          t,
          containsAllInOrder([
            row('Gutschein ${formatVoucherCode(sold.code)}', '9,65'),
            row('  Restguthaben', '15,35'),
          ]),
        );
        expect(t.where((x) => x.startsWith('Bar')), isEmpty);
      },
    );

    test('Storno eines Gutschein-Bons: Beträge mit Minus, Restguthaben nach '
        'dem Storno', () async {
      final (r, sold) = await voucherAndCash();
      final v = await voidOf(shop, r);
      final t = texts(layoutReceipt(v, business, voidedNumber: r.number));
      expect(
        t,
        containsAllInOrder([
          'STORNO',
          row('SUMME EUR', '-9,65'),
          row('Gutschein ${formatVoucherCode(sold.code)}', '-5,00'),
          row('  Restguthaben', '5,00'),
          row('Bar', '-4,65'),
        ]),
      );
    });

    test('Storno eines Gutschein-Verkaufs: Zeile, Code und Reihe nach der '
        'Steuer mit Minus', () async {
      final r = await voucherSold();
      final v = await voidOf(shop, r);
      final t = texts(layoutReceipt(v, business, voidedNumber: r.number));
      expect(
        t,
        containsAllInOrder([
          row('-1 x Gutschein', '-25,00'),
          '    Code ${formatVoucherCode(r.soldVouchers.single.code)}',
          row('SUMME EUR', '-25,00'),
          row('  davon Gutschein (kein Umsatz)', '-25,00'),
          row('Bar', '-25,00'),
        ]),
      );
    });

    test('mit Gutschein und bar, mehr gegeben: "Gegeben" und "Rückgeld" wie '
        'bei einem Barbon', () async {
      final sold = (await voucherSold()).soldVouchers.single;
      final r = await shop.receipts.finalizeCashSale(
        saleId: 'voucher-cash-given',
        cart: cart.applyVoucher(
          AppliedVoucher(
            voucherId: sold.voucherId,
            code: sold.code,
            balanceCents: 1000,
          ),
        ),
        givenCents: 1000,
        staff: shop.anna,
      );
      expect(
        texts(layoutReceipt(r, business)),
        containsAllInOrder([
          row('SUMME EUR', '18,20'),
          row('Gutschein ${formatVoucherCode(sold.code)}', '10,00'),
          row('  Restguthaben', '15,00'),
          row('Bar', '8,20'),
          row('Gegeben', '10,00'),
          row('Rückgeld', '1,80'),
        ]),
      );
    });

    test('mit Gutschein, Karte und Trinkgeld: Gutschein, Restguthaben, Karte '
        'mit Trinkgeld, davon Trinkgeld; die Zahlungen ergeben SUMME plus '
        'Trinkgeld', () async {
      final sold = (await voucherSold()).soldVouchers.single;
      final r = await shop.receipts.finalizeCardSale(
        saleId: 'voucher-card-tip',
        cart: cart.applyVoucher(
          AppliedVoucher(
            voucherId: sold.voucherId,
            code: sold.code,
            balanceCents: 500,
          ),
        ),
        staff: shop.anna,
        provider: 'sumup',
        tipCents: 80,
      );
      final rs = rows(layoutReceipt(r, business));
      expect(
        rs,
        containsAllInOrder([
          ('SUMME EUR', '18,20'),
          ('Gutschein ${formatVoucherCode(sold.code)}', '5,00'),
          ('  Restguthaben', '20,00'),
          ('Karte', '14,00'),
          ('  davon Trinkgeld', '0,80'),
        ]),
      );
      expect(rs.map((x) => x.$1), isNot(contains('Gegeben')));
      int cents(String label) => int.parse(
        rs.firstWhere((x) => x.$1 == label).$2.replaceAll(RegExp('[.,]'), ''),
      );
      expect(
        cents('Gutschein ${formatVoucherCode(sold.code)}') + cents('Karte'),
        cents('SUMME EUR') + cents('  davon Trinkgeld'),
      );
    });

    test('eine Gutschein-Zahlung ohne Code heißt "Gutschein", ohne Leerzeichen '
        'am Ende', () async {
      final (r, _) = await voucherAndCash();
      final noCode = Receipt(
        id: r.id,
        number: r.number,
        createdAt: r.createdAt,
        staffId: r.staffId,
        staffName: r.staffName,
        businessDayId: r.businessDayId,
        kind: r.kind,
        lines: r.lines,
        payments: [
          for (final p in r.payments)
            Payment(
              position: p.position,
              kind: p.kind,
              amountCents: p.amountCents,
              givenCents: p.givenCents,
              changeCents: p.changeCents,
            ),
        ],
        goodsCents: r.goodsCents,
        depositCents: r.depositCents,
        totalCents: r.totalCents,
      );
      final t = texts(layoutReceipt(noCode, business));
      expect(t, contains(row('Gutschein', '5,00')));
      expect(t.where((x) => x.contains('Restguthaben')), isEmpty);
    });

    test('Receipt.depositAskedCents: verlangtes Pfand ohne das '
        'zurückgegebene, beim Storno negativ', () async {
      final r = await withReturn();
      expect((r.depositCents, r.depositReturnCents), (-25, -75));
      expect(r.depositAskedCents, 50);
      expect((await payout()).depositAskedCents, 0);
      expect((await voidOf(shop, r)).depositAskedCents, -50);
      expect((await saleOf(cart, given: 2000)).depositAskedCents, 50);
    });

    test('Übungs-Bon mit den neuen Reihen: TESTBON wie immer', () async {
      final r = await payout();
      final t = texts(layoutReceipt(r, business));
      expect(
        t,
        containsAllInOrder([
          row('Bar ausbezahlt', '0,75'),
          'TESTBON',
          'Keine gültige Rechnung',
        ]),
      );
    });

    test('ein Bon aus 1.11.0 (Rabatt, Trinkgeld, Teil bar) druckt Zeile für '
        'Zeile wie vorher', () async {
      // Der Text von 1.11.0, festgehalten: keine der neuen Reihen.
      final r = await mixedDiscounted(shop);
      final t = texts(layoutReceipt(r, business));
      final from = t.indexOf(row('Bon Nr. 1', '17.11.2026 11:00'));
      expect(t.sublist(from), [
        row('Bon Nr. 1', '17.11.2026 11:00'),
        'Bedienung: Anna',
        '-' * 48,
        row('2 x Cola 0,33 l', '5,80'),
        '    je 2,90',
        row('1 x Huhn Bowl', '11,90'),
        '    XXL (+2,00)',
        '    Nudeln',
        row('  Rabatt 10 % Stammgast', '-1,19'),
        '-' * 48,
        row('Zwischensumme', '16,51'),
        row('Rabatt 10 % Aktion', '-1,65'),
        row('Pfand', '0,50'),
        row('SUMME EUR', '15,36'),
        '-' * 48,
        row('20 % MwSt 0,87  Netto 4,35', '5,22'),
        row('10 % MwSt 0,88  Netto 8,76', '9,64'),
        row('Bar', '10,00'),
        row('Karte', '6,00'),
        row('  davon Trinkgeld', '0,64'),
        '    VISA **** 4242',
        '    Beleg TX-mixed-discounted',
        'Danke und bis bald!',
        'TESTBON',
        'Keine gültige Rechnung',
      ]);
    });
  });
}
