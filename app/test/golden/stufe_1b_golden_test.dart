import 'dart:math' show Random;

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/app.dart';
import 'package:kassa/core/app_language.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/data/receipt_repository.dart';
import 'package:kassa/domain/business_info.dart';
import 'package:kassa/domain/cart.dart';
import 'package:kassa/domain/customer.dart';
import 'package:kassa/domain/feature_access.dart';
import 'package:kassa/domain/print_document.dart';
import 'package:kassa/domain/receipt.dart';
import 'package:kassa/domain/receipt_layout.dart';
import 'package:kassa/domain/voucher.dart';
import 'package:kassa/domain/voucher_layout.dart';
import 'package:kassa/features/kassa/sale_service.dart';
import 'package:kassa/features/login/session.dart';
import 'package:kassa/rksv/rksv_providers.dart';
import 'package:kassa/ui/qr_view.dart';
import 'package:kassa/ui/tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../support/cash_pump.dart';
import '../support/digital_pump.dart';
import '../support/invoice_pump.dart';
import '../support/kassa_pump.dart';
import '../support/pump.dart';
import '../support/sales.dart';
import '../support/signature_pump.dart';

// Bildvergleich der Blätter aus Stufe 1b ("Mehr", Pfand zurück, Gutschein
// verkaufen, prüfen und einlösen, Firmenkunde wählen, neuer Kunde, "Verkauf
// fertig" mit digitalem Bon) in Deutsch und Arabisch, hell und dunkel, und
// von vier Papieren (Bon mit Pfand zurück, Bon mit Gutschein, Rechnung,
// Abschnitt eines Gutscheins; nur Deutsch, hell). Neu erzeugen mit
// `flutter test --update-goldens test/golden/stufe_1b_golden_test.dart`.

/// Erfundene arabische Namen eines Teils der Beispiel-Speisekarte (wie in
/// `stufe_1a_golden_test.dart`); "Cola 0,33 l" bleibt ohne.
const _names = {
  'Bowls': {'ar': 'أطباق'},
  'Snacks': {'ar': 'وجبات خفيفة'},
  'Süßes': {'ar': 'حلويات'},
  'Getränke': {'ar': 'مشروبات'},
  'Huhn Bowl': {'ar': 'طبق دجاج'},
  'Tofu Bowl': {'ar': 'طبق توفو'},
  'Gemüse Bowl': {'ar': 'طبق خضار'},
  'Rind Bowl': {'ar': 'طبق لحم بقري'},
  'Teigtaschen': {'ar': 'زلابية'},
  '5 Stück': {'ar': '5 قطع'},
};

/// Die feste Beispiel-Adresse des QR-Codes im Bild des digitalen Bons: die
/// Adresse der Tests ([testServerUrl]) und ein Schlüssel aus 16 Null-Bytes.
const _exampleUrl = 'https://kassa.example/beleg/AAAAAAAAAAAAAAAAAAAAAA';

/// Fester Zufall für Bilder, die sich nicht ändern dürfen: jedes Byte des
/// Schlüssels der Seite ist 0 ("AAAA…"), die Ziffern der Codes kommen der
/// Reihe nach aus [_digits] (erster Gutschein "12345678", zweiter
/// "87654321").
class _FixedRandom implements Random {
  static const _digits = [
    1, 2, 3, 4, 5, 6, 7, 8, //
    8, 7, 6, 5, 4, 3, 2, 1, //
    2, 4, 6, 8, 1, 3, 5, 7, //
  ];
  var _next = 0;

  @override
  int nextInt(int max) =>
      max == 10 ? _digits[_next++ % _digits.length] : 0;

  @override
  double nextDouble() => 0;

  @override
  bool nextBool() => false;
}

/// Die Bons der Kassa mit [_FixedRandom].
Override _fixedReceipts() => receiptRepositoryProvider.overrideWith(
  (ref) => ReceiptRepository(
    ref.watch(databaseProvider),
    ref.watch(clockProvider),
    ref.watch(dayRepositoryProvider),
    journal: ref.watch(rksvJournalProvider),
    random: _FixedRandom(),
  ),
);

Future<void> _tap(WidgetTester t, String key) async {
  await t.ensureVisible(find.byKey(Key(key)));
  await t.pumpAndSettle();
  await t.tap(find.byKey(Key(key)));
  await t.pumpAndSettle();
}

/// Tippt die Ziffern von [code] ins Zahlenfeld.
Future<void> _typeCode(WidgetTester t, String code) async {
  for (final d in code.split('')) {
    await t.tap(find.byKey(Key('key-$d')));
    await t.pump();
  }
  await t.pumpAndSettle();
}

/// Kassa in [language] und [brightness] mit den arabischen Namen, der Chef
/// angemeldet, Drucker eingerichtet, die Bons mit festem Zufall. [overrides]
/// ersetzt die Datenbank im Speicher (der Zufall kommt immer dazu).
Future<void> _kassa(
  WidgetTester t,
  AppLanguage language,
  Brightness brightness, {
  List<Override>? overrides,
}) async {
  await pumpKassa(
    t,
    brightness: brightness,
    pin: '4711',
    overrides: [...overrides ?? await memoryOverrides(), _fixedReceipts()],
  );
  await containerOf(t).read(translationRepositoryProvider).upsert(_names);
  await setUpPrinter(t);
  await setSettings(t, (s) => s.copyWith(language: language));
}

/// Verkauft einen Gutschein über [cents] bar, wie an der Kassa, und gibt ihn
/// zurück.
Future<Voucher> _sellVoucher(WidgetTester t, String saleId, int cents) async {
  final receipts = containerOf(t).read(receiptRepositoryProvider);
  final r = await receipts.finalizeCashSale(
    saleId: saleId,
    cart: const Cart.empty().addVoucherSale(valueCents: cents),
    givenCents: cents,
    staff: containerOf(t).read(sessionProvider)!,
  );
  return (await containerOf(
    t,
  ).read(voucherRepositoryProvider).byId(r.soldVouchers.single.voucherId))!;
}

/// Kassa im echten Betrieb mit Rechnung an Firma, zwei gespeicherten
/// Firmenkunden, Cola und Teigtaschen bar verkauft; endet auf "Firmenkunde
/// wählen".
Future<void> _openCustomerPicker(
  WidgetTester t,
  AppLanguage language,
  Brightness brightness,
) async {
  await _kassa(
    t,
    language,
    brightness,
    overrides: [
      ...await memoryOverrides(),
      ...fakeSignatureOverrides(FakeSignatureUnit()),
    ],
  );
  await goLiveForInvoice(t);
  await setSettings(
    t,
    (s) => s.copyWith(invoiceEnabled: true, cashDrawerEnabled: true),
  );
  final customers = containerOf(t).read(customerRepositoryProvider);
  await customers.save(
    name: 'Muster GmbH',
    addressLine1: 'Musterweg 1',
    addressLine2: '1010 Wien',
    vatId: 'ATU00000000',
  );
  await customers.save(
    name: 'Beispiel KG',
    addressLine1: 'Beispielgasse 2',
    addressLine2: '1020 Wien',
  );
  await tapItem(t, 'cola');
  await tapItem(t, 'teigtaschen');
  await t.pumpAndSettle();
  await _tap(t, 'pay-cash');
  await _tap(t, 'finish-sale');
  await _tap(t, 'invoice-button');
  expect(find.byKey(const Key('customer-new')), findsOneWidget);
}

/// Die acht Blätter, je bis zu dem Bild, das verglichen wird.
final _sheets =
    <(String, Future<void> Function(WidgetTester, AppLanguage, Brightness))>[
      (
        'mehr',
        (t, language, brightness) async {
          await _kassa(t, language, brightness);
          await setSettings(
            t,
            (s) => s.copyWith(
              openAmountAccess: FeatureAccess.all,
              depositReturnAccess: FeatureAccess.all,
              voucherEnabled: true,
            ),
          );
          await tapItem(t, 'cola');
          await tapItem(t, 'teigtaschen');
          await t.pumpAndSettle();
          await _tap(t, 'more-button');
          expect(find.byKey(const Key('more-sheet')), findsOneWidget);
        },
      ),
      (
        'pfand_zurueck',
        (t, language, brightness) async {
          await _kassa(t, language, brightness);
          await setSettings(
            t,
            (s) => s.copyWith(depositReturnAccess: FeatureAccess.all),
          );
          await _tap(t, 'deposit-return-button');
          for (var i = 0; i < 3; i++) {
            await t.tap(find.byKey(const Key('deposit-return-plus-25')));
            await t.pump();
          }
          await t.pumpAndSettle();
          expect(find.byKey(const Key('deposit-return-sheet')), findsOneWidget);
          expect(find.textContaining('0,75'), findsWidgets);
        },
      ),
      (
        'gutschein_verkaufen',
        (t, language, brightness) async {
          await _kassa(t, language, brightness);
          await setSettings(t, (s) => s.copyWith(voucherEnabled: true));
          await _tap(t, 'voucher-button');
          await _tap(t, 'voucher-preset-2500');
          expect(find.byKey(const Key('voucher-sheet')), findsOneWidget);
        },
      ),
      (
        'gutschein_pruefen',
        (t, language, brightness) async {
          await _kassa(t, language, brightness);
          await setSettings(t, (s) => s.copyWith(voucherEnabled: true));
          // 25,00 € verkauft, davon 9,65 € eingelöst: es bleiben 15,35 €.
          final voucher = await _sellVoucher(t, 'g-1', 2500);
          await containerOf(t)
              .read(receiptRepositoryProvider)
              .finalizeVoucherSale(
                saleId: 'g-2',
                cart: cartCard.applyVoucher(applied(voucher)),
                staff: containerOf(t).read(sessionProvider)!,
              );
          await _tap(t, 'voucher-button');
          await _tap(t, 'voucher-tab-check');
          await _typeCode(t, voucher.code);
          expect(voucher.code, '12345678');
          expect(find.byKey(const Key('voucher-check-movement-1')), findsOneWidget);
        },
      ),
      (
        'gutschein_einloesen',
        (t, language, brightness) async {
          await _kassa(t, language, brightness);
          await setSettings(t, (s) => s.copyWith(voucherEnabled: true));
          final voucher = await _sellVoucher(t, 'g-1', 500);
          await tapItem(t, 'cola');
          await tapItem(t, 'teigtaschen');
          await t.pumpAndSettle();
          await _tap(t, 'pay-voucher');
          await _typeCode(t, voucher.code);
          expect(find.byKey(const Key('voucher-redeem-go')), findsOneWidget);
        },
      ),
      (
        'rechnung_kunde_waehlen',
        (t, language, brightness) async {
          await _openCustomerPicker(t, language, brightness);
        },
      ),
      (
        'rechnung_neuer_kunde',
        (t, language, brightness) async {
          await _openCustomerPicker(t, language, brightness);
          await _tap(t, 'customer-new');
          await t.enterText(
            find.byKey(const Key('customer-name')),
            'Muster GmbH',
          );
          await t.enterText(
            find.byKey(const Key('customer-address1')),
            'Musterweg 1',
          );
          await t.enterText(
            find.byKey(const Key('customer-address2')),
            '1010 Wien',
          );
          await t.enterText(
            find.byKey(const Key('customer-vat')),
            'ATU00000000',
          );
          // Ohne blinkende Schreibmarke im Bild.
          FocusManager.instance.primaryFocus?.unfocus();
          await t.pumpAndSettle();
        },
      ),
      (
        'verkauf_fertig_digital',
        (t, language, brightness) async {
          await _kassa(
            t,
            language,
            brightness,
            overrides: await serverKassaOverrides(),
          );
          await setSettings(
            t,
            (s) => s.copyWith(
              receiptMode: ReceiptMode.digitalOnRequest,
              cashDrawerEnabled: true,
            ),
          );
          await pairRegister(t);
          await tapItem(t, 'cola');
          await tapItem(t, 'teigtaschen');
          await t.pumpAndSettle();
          await t.tap(find.byKey(const Key('pay-cash')));
          await t.pumpAndSettle();
          await t.tap(find.byKey(const Key('finish-sale')));
          await t.pump();
          await t.pump();
          await serverConfirms(t, await lastReceiptId(t));
          await t.pumpAndSettle();
          expect(qrTextOf(t, 'receipt-qr'), _exampleUrl);
          expect(find.byKey(const Key('print-receipt-now')), findsOneWidget);
          expect(find.byKey(const Key('next-customer')), findsOneWidget);
        },
      ),
    ];

// --- Papier ---------------------------------------------------------------

const _business = BusinessInfo(
  name: 'Beispiel-Imbiss',
  addressLines: ['Musterstraße 1', '1010 Wien'],
  vatId: 'ATU12345678',
  receiptFooter: 'Danke und bis bald!',
);

/// [r] mit erfundenem Eintrag der Signatur im echten Betrieb (Kassa
/// KASSA-1, Bon Nr. [number]): so steht am Papier der QR-Code und kein
/// TESTBON.
Receipt _stamped(Receipt r, int number) => Receipt(
  id: r.id,
  number: number,
  createdAt: r.createdAt,
  staffId: r.staffId,
  staffName: r.staffName,
  businessDayId: r.businessDayId,
  kind: r.kind,
  voidsReceiptId: r.voidsReceiptId,
  lines: r.lines,
  payments: r.payments,
  rksv: RksvStamp(
    cashBoxId: 'KASSA-1',
    qrText:
        '_R1-AT1_KASSA-1_$number'
        '_2026-11-17T11:00:00_0,00_0,00_0,00_0,00_0,00_AAAA_BBBB_CCCC_DDDD',
    damaged: false,
    probe: false,
  ),
  goodsCents: r.goodsCents,
  depositCents: r.depositCents,
  totalCents: r.totalCents,
  discountCents: r.discountCents,
  discount: r.discount,
  publicToken: r.publicToken,
  soldVouchers: r.soldVouchers,
);

const _paperFont = 15.0;

/// Nur für dieses Bild: die Zeilen eines Druckauftrags als Text mit gleich
/// breiten Zeichen auf weißem Papier, so breit wie [columns] Zeichen. Fett,
/// doppelte Höhe und doppelte Breite wie am Drucker, der QR-Code als echter
/// Code, der Schnitt als gestrichelte Linie. Kein Teil der App.
class _Paper extends StatelessWidget {
  const _Paper(this.ops);

  final List<PrintOp> ops;
  static const columns = 48;

  static const _ink = Color(0xFF000000);

  TextStyle _style(bool bold) => TextStyle(
    fontFamily: KassaTokens.monoFontFamily,
    fontSize: _paperFont,
    height: 1.3,
    fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
    color: _ink,
  );

  Size _measure(String text, TextStyle style) {
    final p = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final size = p.size;
    p.dispose();
    return size;
  }

  @override
  Widget build(BuildContext context) {
    final cell = _measure('0', _style(false));
    final width = cell.width * columns;
    Widget line(PrintText o) {
      final style = _style(o.bold);
      final natural = _measure(o.text, style);
      final (sx, sy) = switch (o.size) {
        PrintSize.normal => (1.0, 1.0),
        PrintSize.doubleHeight => (1.0, 2.0),
        PrintSize.doubleBoth => (2.0, 2.0),
      };
      return Align(
        alignment: switch (o.align) {
          PrintAlign.left => Alignment.centerLeft,
          PrintAlign.center => Alignment.center,
          PrintAlign.right => Alignment.centerRight,
        },
        child: SizedBox(
          width: natural.width * sx,
          height: natural.height * sy,
          child: FittedBox(
            fit: BoxFit.fill,
            child: Text(o.text, style: style, maxLines: 1, softWrap: false),
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        color: const Color(0xFFE6E6E6),
        padding: const EdgeInsets.all(24),
        child: Container(
          color: const Color(0xFFFFFFFF),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: SizedBox(
            width: width,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final o in ops)
                  switch (o) {
                    PrintText() => line(o),
                    PrintFeed() => SizedBox(height: cell.height * o.lines),
                    PrintQr() => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Center(child: QrView(data: o.data, size: 180)),
                    ),
                    PrintCut() => Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '- ' * (columns ~/ 2),
                        maxLines: 1,
                        style: _style(false).copyWith(
                          color: const Color(0xFF8A8A8A),
                        ),
                      ),
                    ),
                    PrintDrawerKick() => const SizedBox.shrink(),
                  },
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Zeigt [ops] als Papier und vergleicht es mit `goldens/[file].png`.
Future<void> _expectPaper(
  WidgetTester t,
  List<PrintOp> ops,
  String file,
) async {
  await pumpApp(
    t,
    Align(
      alignment: Alignment.topCenter,
      child: RepaintBoundary(key: const Key('paper'), child: _Paper(ops)),
    ),
    size: const Size(900, 2000),
  );
  await t.pumpAndSettle();
  expect(t.takeException(), isNull);
  await expectLater(
    find.byKey(const Key('paper')),
    matchesGoldenFile('goldens/$file.png'),
  );
}

/// Die vier Papiere: Bon, wie [layoutReceipt] und [layoutVoucher] ihn
/// drucken, je aus einem Verkauf der Testumgebung.
final _papers = <(String, Future<List<PrintOp>> Function(TestShop))>[
  (
    'bon_pfand_zurueck',
    (shop) async {
      // 3 × Pfand zurück zu 0,25 €: 0,75 € bar ausbezahlt.
      final r = await shop.receipts.finalizePayout(
        saleId: 'payout',
        cart: const Cart.empty().setDepositReturn(depositCents: 25, quantity: 3),
        staff: shop.anna,
      );
      return layoutReceipt(_stamped(r, 1041), _business);
    },
  ),
  (
    'bon_gutschein',
    (shop) async {
      // Teigtaschen und Cola (9,65 €): 5,00 € mit Gutschein, 4,65 € bar.
      final voucher = await sellVoucher(shop, 500, saleId: 'voucher-5');
      final r = await shop.receipts.finalizeCashSale(
        saleId: 'voucher-paid',
        cart: cartCard.applyVoucher(applied(voucher)),
        givenCents: 465,
        staff: shop.anna,
      );
      return layoutReceipt(_stamped(r, 1043), _business);
    },
  ),
  (
    'rechnung',
    (shop) async {
      final r = await shop.sell('invoice');
      return layoutReceipt(
        _stamped(r, 1042),
        _business,
        recipient: ReceiptRecipient(
          receiptId: r.id,
          version: 0,
          customerId: 'k1',
          name: 'Muster GmbH',
          addressLine1: 'Musterweg 1',
          addressLine2: '1010 Wien',
          vatId: 'ATU00000000',
          createdAt: DateTime(2026, 11, 17, 11, 5),
          staffId: shop.anna.id,
          staffName: shop.anna.name,
        ),
      );
    },
  ),
  (
    'gutschein_abschnitt',
    (shop) async {
      final r = await shop.receipts.finalizeCashSale(
        saleId: 'voucher-sold',
        cart: const Cart.empty().addVoucherSale(valueCents: 2500),
        givenCents: 2500,
        staff: shop.anna,
      );
      return layoutVoucher(
        r.soldVouchers.single,
        _business,
        soldAt: r.createdAt,
        isTest: false,
      );
    },
  ),
];

void main() {
  for (final (language, dark) in [
    (AppLanguage.de, false),
    (AppLanguage.de, true),
    (AppLanguage.ar, false),
    (AppLanguage.ar, true),
  ]) {
    final look = dark ? 'dunkel' : 'hell';
    final arabic = language == AppLanguage.ar ? '_arabisch' : '';
    for (final (name, open) in _sheets) {
      testWidgets('$name (${language.name}, $look)', (t) async {
        await open(t, language, dark ? Brightness.dark : Brightness.light);
        expect(t.takeException(), isNull);
        await expectLater(
          find.byType(KassaApp),
          matchesGoldenFile('goldens/1b_$name${arabic}_$look.png'),
        );
        // Die Uhr des digitalen Bons (und anderes, das noch läuft) ablaufen
        // lassen.
        await t.pump(receiptFallbackDelay);
        await t.pump();
      });
    }
  }

  for (final (name, ops) in _papers) {
    testWidgets('Papier $name (de, hell)', (t) async {
      final shop = await TestShop.open(random: _FixedRandom());
      addTearDown(shop.close);
      await _expectPaper(t, await ops(shop), '1b_${name}_hell');
    });
  }
}
