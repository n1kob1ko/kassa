// Gutschein einlösen (Spec 5.5, 5.6): "Gutschein" über "Bar" und "Karte"
// öffnet das Blatt "Gutschein einlösen". Reicht das Guthaben, schließt
// "Einlösen" den Bon ab (die Lade bleibt zu); sonst liegt der Gutschein am Bon
// und der Rest geht bar, mit Karte, "Teil bar" oder mit einem weiteren
// Gutschein. Abgebucht wird erst beim Abschließen; hat sich ein Guthaben
// geändert, ist nichts gespeichert, und vor der Karte erfährt das Terminal
// nichts.

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/data/receipt_repository.dart';
import 'package:kassa/data/voucher_repository.dart';
import 'package:kassa/devices/card_terminal.dart';
import 'package:kassa/domain/cart.dart';
import 'package:kassa/domain/feature_access.dart';
import 'package:kassa/domain/staff.dart';
import 'package:kassa/domain/voucher.dart';
import 'package:kassa/features/kassa/cart_controller.dart';
import 'package:kassa/features/kassa/sale_service.dart';
import 'package:kassa/features/kassa/voucher_code_entry.dart';
import 'package:kassa/features/login/session.dart';
import 'package:kassa/ui/primary_button.dart';
import 'package:material_ui/material_ui.dart';

import '../support/cash_pump.dart';
import '../support/kassa_pump.dart';
import '../support/pump.dart';

PrimaryButton _button(WidgetTester t, String key) =>
    t.widget<PrimaryButton>(find.byKey(Key(key)));

Future<void> _tap(WidgetTester t, String key) async {
  await t.ensureVisible(find.byKey(Key(key)));
  await t.pumpAndSettle();
  await t.tap(find.byKey(Key(key)));
  await t.pumpAndSettle();
}

Finder _inKey(String key, String text) =>
    find.descendant(of: find.byKey(Key(key)), matching: find.text(text));

/// Ein Bon, den die Kassa liest, als würde er im echten Betrieb entstehen:
/// nur die Frage "Übungs-Bon?" sagt nein.
class _LiveReceipts extends ReceiptRepository {
  _LiveReceipts(super.db, super.clock, super.days);

  @override
  Future<bool> isTestReceiptNow() async => false;
}

/// Kassa mit Gutschein an, angemeldet Anna, Drucker und Lade eingerichtet;
/// die Artikel [ids] (Standard: Teigtaschen und Cola, 9,65 €) auf dem Bon.
Future<void> _open(
  WidgetTester t, {
  List<String> ids = const ['teigtaschen', 'cola'],
  List<Override>? overrides,
}) async {
  await pumpKassa(t, overrides: overrides);
  await setSettings(
    t,
    (s) => s.copyWith(voucherEnabled: true, cashDrawerEnabled: true),
  );
  await setUpPrinter(t);
  for (final id in ids) {
    await tapItem(t, id);
  }
  await t.pumpAndSettle();
}

var _sold = 0;

/// Verkauft einen Gutschein über [cents] bar an dieser Kassa, ohne
/// Oberfläche, und gibt seinen Code zurück.
Future<String> sellVoucherAtRegister(WidgetTester t, int cents) async {
  final staff = containerOf(t).read(sessionProvider)!;
  final r = await containerOf(t)
      .read(receiptRepositoryProvider)
      .finalizeCashSale(
        saleId: 'gutschein-${_sold++}',
        cart: const Cart.empty().addVoucherSale(valueCents: cents),
        givenCents: cents,
        staff: staff,
      );
  return r.soldVouchers.single.code;
}

Future<Voucher> _voucher(WidgetTester t, String code) async =>
    (await containerOf(t).read(voucherRepositoryProvider).findByCode(code))
        .single;

/// Zieht [cents] vom Gutschein ab, wie eine Bewegung von einer anderen Kassa
/// aus dem Abgleich: direkt in die Datenbank.
Future<void> _drawElsewhere(WidgetTester t, String code, int cents) async {
  final v = await _voucher(t, code);
  final db = containerOf(t).read(databaseProvider);
  await db
      .into(db.voucherMovementRows)
      .insert(
        VoucherMovementRowsCompanion.insert(
          voucherId: v.id,
          receiptId: 'andere-kassa-${_sold++}',
          kind: VoucherMovementKind.redeem.dbName,
          amountCents: -cents,
          createdAt: DateTime(2026, 11, 17, 11, 30),
        ),
      );
}

/// "Gutschein" und den Code tippen.
Future<void> _redeemSheet(WidgetTester t, String code) async {
  await _tap(t, 'pay-voucher');
  expect(find.byKey(const Key('voucher-redeem-sheet')), findsOneWidget);
  await tapKeys(t, code.split('').join(' '));
  await t.pumpAndSettle();
}

/// Den Gutschein mit [code] einlösen ("Einlösen ..."), ganz oder teils.
Future<void> _redeem(WidgetTester t, String code) async {
  await _redeemSheet(t, code);
  await _tap(t, 'voucher-redeem-go');
}

Future<List<Map<String, Object?>>> _payments(WidgetTester t) => queryRows(
  t,
  'SELECT kind, amount_cents, given_cents, change_cents, tip_cents, '
  'voucher_balance_after_cents FROM payments '
  "WHERE receipt_id NOT LIKE 'gutschein-%' ORDER BY receipt_id, position",
);

void main() {
  testWidgets('Guthaben reicht: Einlösen schließt ab, Lade bleibt zu, '
      'Verkauf fertig zeigt, was bleibt', (t) async {
    await _open(t);
    final code = await sellVoucherAtRegister(t, 2500);
    final drawerBefore = printerOf(t).drawerOpened;
    final jobsBefore = printerOf(t).printedJobs.length;
    expect(_button(t, 'pay-voucher').onPressed, isNotNull);
    expect(t.getSize(find.byKey(const Key('pay-voucher'))).height, 56);

    await _redeemSheet(t, code);
    expect(textOf(t, const Key('voucher-redeem-due')), '9,65 €');
    expect(
      (
        textOf(t, const Key('voucher-redeem-balance')),
        textOf(t, const Key('voucher-redeem-use')),
        textOf(t, const Key('voucher-redeem-left')),
      ),
      ('25,00 €', '9,65 €', '15,35 €'),
    );
    expect(textOf(t, const Key('voucher-redeem-go')), 'Einlösen 9,65 €');
    await _tap(t, 'voucher-redeem-go');

    expect(
      await queryRows(
        t,
        'SELECT kind, amount_cents, voucher_balance_after_cents FROM payments '
        "WHERE kind = 'voucher'",
      ),
      [
        {
          'kind': 'voucher',
          'amount_cents': 965,
          'voucher_balance_after_cents': 1535,
        },
      ],
    );
    expect(await receiptCount(t), 2);
    expect(printerOf(t).drawerOpened, drawerBefore);
    expect(printerOf(t).printedJobs.skip(jobsBefore).map((j) => j.kind), [
      'receipt',
    ]);
    expect(find.byKey(const Key('paid-by-voucher')), findsOneWidget);
    expect(textOf(t, const Key('paid-by-voucher')), 'Mit Gutschein bezahlt');
    expect(_inKey('voucher-left-0', 'Bleibt am Gutschein'), findsOneWidget);
    expect(textOf(t, const Key('voucher-left-amount-0')), '15,35 €');
    expect(find.byKey(const Key('change-done')), findsNothing);
    expect(cartOf(t).isEmpty, isTrue);
    expect(await draftOf(t), isNull);
    expect((await _voucher(t, code)).balanceCents, 1535);
  });

  testWidgets('Guthaben 5 € auf 9,65 €: Reihe am Bon, "Noch zu zahlen '
      '4,65 €", Rest bar mit Rückgeld aus 4,65 €', (t) async {
    await _open(t);
    final code = await sellVoucherAtRegister(t, 500);
    await _redeemSheet(t, code);
    expect(
      (
        textOf(t, const Key('voucher-redeem-use')),
        textOf(t, const Key('voucher-redeem-left')),
      ),
      ('5,00 €', '0,00 €'),
    );
    expect(
      textOf(t, const Key('voucher-redeem-go')),
      'Einlösen 5,00 €, Rest 4,65 €',
    );
    await _tap(t, 'voucher-redeem-go');

    // Nichts ist gespeichert, das Blatt ist zu, der Gutschein liegt am Bon.
    expect(find.byKey(const Key('voucher-redeem-sheet')), findsNothing);
    expect(await receiptCount(t), 1);
    expect((await _voucher(t, code)).balanceCents, 500);
    expect(cartOf(t).vouchers.single.balanceCents, 500);
    expect(
      _inKey('applied-voucher-0', 'Gutschein ${formatVoucherCode(code)}'),
      findsOneWidget,
    );
    expect(textOf(t, const Key('applied-voucher-amount-0')), '−5,00 €');
    expect(find.byKey(const Key('applied-voucher-remove-0')), findsOneWidget);
    expect(
      t.getSize(find.byKey(const Key('applied-voucher-remove-0'))).height,
      greaterThanOrEqualTo(48),
    );
    expect(_inKey('due-row', 'Noch zu zahlen'), findsOneWidget);
    expect(textOf(t, const Key('due-amount')), '4,65 €');
    expect(textOf(t, const Key('cart-total')), '9,65 €');
    // Ein weiterer Gutschein geht noch.
    expect(find.byKey(const Key('pay-voucher')), findsOneWidget);

    await _tap(t, 'pay-cash');
    expect(textOf(t, const Key('cash-total')), '4,65 €');
    expect(find.byKey(const Key('given-465')), findsOneWidget);
    await _tap(t, 'given-500');
    await _tap(t, 'finish-sale');
    expect(textOf(t, const Key('change-done')), '0,35 €');
    expect(_inKey('voucher-left-0', '0,00 €'), findsOneWidget);
    expect(find.byKey(const Key('paid-by-voucher')), findsNothing);
    expect(await _payments(t), [
      {
        'kind': 'voucher',
        'amount_cents': 500,
        'given_cents': 500,
        'change_cents': 0,
        'tip_cents': 0,
        'voucher_balance_after_cents': 0,
      },
      {
        'kind': 'cash',
        'amount_cents': 465,
        'given_cents': 500,
        'change_cents': 35,
        'tip_cents': 0,
        'voucher_balance_after_cents': null,
      },
    ]);
    expect((await _voucher(t, code)).state, VoucherState.empty);
  });

  testWidgets('Rest mit Karte und Trinkgeld: Terminal bekommt 4,65 € + '
      'Trinkgeld, Zahlungen in der Reihenfolge Gutschein, Karte', (t) async {
    await _open(t);
    await setSettings(t, (s) => s.copyWith(cardTipEnabled: true));
    final code = await sellVoucherAtRegister(t, 500);
    await _redeem(t, code);
    await _tap(t, 'pay-card');
    expect(textOf(t, const Key('tip-due')), '4,65 €');
    // Die Vorschläge rechnen mit dem, was die Karte bucht.
    expect(find.byKey(const Key('tip-pays-500')), findsOneWidget);
    expect(find.byKey(const Key('tip-pays-1000')), findsOneWidget);
    await _tap(t, 'tip-pays-500');
    await _tap(t, 'tip-go');
    expect(terminalOf(t).payments.single.amountCents, 500);
    expect(await _payments(t), [
      {
        'kind': 'voucher',
        'amount_cents': 500,
        'given_cents': 500,
        'change_cents': 0,
        'tip_cents': 0,
        'voucher_balance_after_cents': 0,
      },
      {
        'kind': 'card',
        'amount_cents': 465,
        'given_cents': 0,
        'change_cents': 0,
        'tip_cents': 35,
        'voucher_balance_after_cents': null,
      },
    ]);
    expect(find.byKey(const Key('paid-by-card')), findsOneWidget);
    expect(textOf(t, const Key('tip-done')), 'davon Trinkgeld 0,35 €');
    expect(find.byKey(const Key('voucher-left-0')), findsOneWidget);
  });

  testWidgets('Rest "Teil bar, Rest Karte": Gutschein, bar, Karte', (t) async {
    await _open(t);
    await setSettings(t, (s) => s.copyWith(splitPaymentEnabled: true));
    final code = await sellVoucherAtRegister(t, 300);
    await _redeem(t, code);
    expect(textOf(t, const Key('due-amount')), '6,65 €');
    await _tap(t, 'pay-cash');
    await _tap(t, 'cash-mode-split');
    await tapKeys(t, '2');
    await t.pumpAndSettle();
    expect(textOf(t, const Key('split-rest')), '4,65 €');
    await _tap(t, 'split-go');
    expect(terminalOf(t).payments.single.amountCents, 465);
    expect(
      [
        for (final p in await _payments(t))
          (p['kind'], p['amount_cents'], p['given_cents']),
      ],
      [('voucher', 300, 300), ('cash', 200, 200), ('card', 465, 0)],
    );
  });

  testWidgets('Karte allein nach Gutschein: das Terminal bekommt den Rest, '
      'der Kleinstbetrag gilt für den Rest', (t) async {
    await _open(t);
    final code = await sellVoucherAtRegister(t, 900);
    await _redeem(t, code);
    // 0,65 € bleiben: unter dem Kleinstbetrag von 1,00 €.
    expect(textOf(t, const Key('due-amount')), '0,65 €');
    expect(_button(t, 'pay-card').onPressed, isNull);
    expect(
      find.descendant(
        of: find.byKey(const Key('pay-card')),
        matching: find.text('ab 1,00 €'),
      ),
      findsOneWidget,
    );
    expect(_button(t, 'pay-cash').onPressed, isNotNull);
    await _tap(t, 'applied-voucher-remove-0');
    final small = await sellVoucherAtRegister(t, 500);
    await _redeem(t, small);
    expect(_button(t, 'pay-card').onPressed, isNotNull);
    await _tap(t, 'pay-card');
    expect(terminalOf(t).payments.single.amountCents, 465);
    expect(
      [for (final p in await _payments(t)) (p['kind'], p['amount_cents'])],
      [('voucher', 500), ('card', 465)],
    );
  });

  testWidgets('zwei Gutscheine nacheinander; × nimmt einen wieder weg', (
    t,
  ) async {
    await _open(t);
    final first = await sellVoucherAtRegister(t, 300);
    final second = await sellVoucherAtRegister(t, 200);
    await _redeem(t, first);
    await _redeem(t, second);
    expect([for (final v in cartOf(t).vouchers) v.code], [first, second]);
    expect(textOf(t, const Key('applied-voucher-amount-0')), '−3,00 €');
    expect(textOf(t, const Key('applied-voucher-amount-1')), '−2,00 €');
    expect(textOf(t, const Key('due-amount')), '4,65 €');

    await _tap(t, 'applied-voucher-remove-0');
    expect([for (final v in cartOf(t).vouchers) v.code], [second]);
    expect(find.byKey(const Key('applied-voucher-1')), findsNothing);
    expect(textOf(t, const Key('applied-voucher-amount-0')), '−2,00 €');
    expect(textOf(t, const Key('due-amount')), '7,65 €');

    await _tap(t, 'applied-voucher-remove-0');
    expect(cartOf(t).vouchers, isEmpty);
    expect(find.byKey(const Key('due-row')), findsNothing);
    expect(find.byKey(const Key('applied-voucher-0')), findsNothing);
    expect(await receiptCount(t), 2);
  });

  testWidgets('Bon wird kleiner als die gewählten Gutscheine: "Mit Gutschein '
      'abschließen", der zweite Gutschein wird nicht belastet', (t) async {
    await _open(t);
    final first = await sellVoucherAtRegister(t, 700);
    final second = await sellVoucherAtRegister(t, 200);
    await _redeem(t, first);
    await _redeem(t, second);
    expect(textOf(t, const Key('due-amount')), '0,65 €');

    // Die Cola weg: 6,50 €, der erste Gutschein deckt alles.
    final cola = cartOf(t).lines.singleWhere((l) => l.item.id == 'cola');
    await _tap(t, 'qty-minus-${cola.lineId}');
    expect(textOf(t, const Key('cart-total')), '6,50 €');
    expect(textOf(t, const Key('applied-voucher-amount-0')), '−6,50 €');
    expect(textOf(t, const Key('applied-voucher-amount-1')), '−0,00 €');
    expect(textOf(t, const Key('due-amount')), '0,00 €');
    expect(find.byKey(const Key('pay-cash')), findsNothing);
    expect(find.byKey(const Key('pay-card')), findsNothing);
    expect(find.byKey(const Key('pay-voucher')), findsNothing);
    expect(textOf(t, const Key('finish-voucher')), 'Mit Gutschein abschließen');
    expect(find.byKey(const Key('applied-voucher-remove-1')), findsOneWidget);

    final drawer = printerOf(t).drawerOpened;
    await _tap(t, 'finish-voucher');
    expect(find.byKey(const Key('paid-by-voucher')), findsOneWidget);
    expect(printerOf(t).drawerOpened, drawer);
    expect(
      [for (final p in await _payments(t)) (p['kind'], p['amount_cents'])],
      [('voucher', 650)],
    );
    expect((await _voucher(t, first)).balanceCents, 50);
    final untouched = await _voucher(t, second);
    expect((untouched.balanceCents, untouched.untouched), (200, true));
  });

  testWidgets('Bon mit Gutschein-Zeile hat keine Taste pay-voucher; Summe 0 '
      'und Summe unter 0 auch nicht; ohne Schalter nie', (t) async {
    await _open(t, ids: const []);
    expect(find.byKey(const Key('pay-voucher')), findsNothing); // leer
    await _tap(t, 'voucher-button');
    await _tap(t, 'voucher-preset-1000');
    await _tap(t, 'voucher-add');
    await tapItem(t, 'cola');
    await t.pumpAndSettle();
    expect(find.byKey(const Key('pay-voucher')), findsNothing);
    containerOf(t).read(cartProvider.notifier).clear();
    await t.pumpAndSettle();

    // Leitungswasser: Summe 0,00 €.
    await tapItem(t, 'leitungswasser');
    await t.pumpAndSettle();
    expect(textOf(t, const Key('cart-total')), '0,00 €');
    expect(find.byKey(const Key('pay-voucher')), findsNothing);

    // Summe unter 0: nur Pfand zurück.
    await setSettings(
      t,
      (s) => s.copyWith(depositReturnAccess: FeatureAccess.all),
    );
    containerOf(t).read(cartProvider.notifier).setDepositReturns({25: 2});
    await t.pumpAndSettle();
    expect(find.byKey(const Key('pay-out')), findsOneWidget);
    expect(find.byKey(const Key('pay-voucher')), findsNothing);

    containerOf(t).read(cartProvider.notifier).clear();
    await tapItem(t, 'cola');
    await t.pumpAndSettle();
    expect(find.byKey(const Key('pay-voucher')), findsOneWidget);
    await setSettings(t, (s) => s.copyWith(voucherEnabled: false));
    expect(find.byKey(const Key('pay-voucher')), findsNothing);
  });

  testWidgets('Meldungen: unbekannt, aufgebraucht, storniert, liegt schon am '
      'Bon, echter Gutschein im Übungsmodus', (t) async {
    await _open(t);
    Future<void> type(String code) async {
      await tapKeys(t, code.split('').join(' '));
      await t.pumpAndSettle();
    }

    Future<void> clear() async {
      await tapKeys(t, 'back back back back back back back back');
      await t.pumpAndSettle();
    }

    Future<void> expectProblem(String text) async {
      expect(textOf(t, const Key('voucher-code-problem')), text);
      expect(find.byKey(const Key('voucher-redeem-go')), findsNothing);
      expect(find.byKey(const Key('voucher-redeem-balance')), findsNothing);
    }

    // Aufgebraucht: ein Gutschein über 3,15 € zahlt eine Cola ganz.
    final used = await sellVoucherAtRegister(t, 315);
    final staff = containerOf(t).read(sessionProvider)!;
    final receipts = containerOf(t).read(receiptRepositoryProvider);
    await receipts.finalizeVoucherSale(
      saleId: 'cola-mit-gutschein',
      cart: const Cart.empty()
          .add(cartOf(t).lines.last.item)
          .applyVoucher(
            AppliedVoucher(
              voucherId: (await _voucher(t, used)).id,
              code: used,
              balanceCents: 315,
            ),
          ),
      staff: staff,
    );
    // Storniert: der Verkauf eines unberührten Gutscheins wird storniert.
    final voided = await sellVoucherAtRegister(t, 1000);
    final chef = (await containerOf(
      t,
    ).read(staffRepositoryProvider).all()).firstWhere((s) => s.name == 'Chef');
    final soldOn = (await _voucher(t, voided)).soldReceiptId!;
    await receipts.voidReceipt(soldOn, staff: chef);
    // Echt: ein Gutschein, der über den Abgleich aus dem echten Betrieb kam.
    final live = await sellVoucherAtRegister(t, 2000);
    final db = containerOf(t).read(databaseProvider);
    await db.customStatement('UPDATE vouchers SET is_test = 0 WHERE code = ?', [
      live,
    ]);
    final partial = await sellVoucherAtRegister(t, 200);
    await _redeem(t, partial);

    await _tap(t, 'pay-voucher');
    final unknown = [used, voided, live, partial].contains('00000000')
        ? '00000001'
        : '00000000';
    await type(unknown);
    await expectProblem('Diesen Gutschein kennt die Kassa nicht.');
    await clear();
    expect(find.byKey(const Key('voucher-code-problem')), findsNothing);

    await type(used);
    await expectProblem('Dieser Gutschein ist aufgebraucht.');
    await clear();
    await type(voided);
    await expectProblem('Dieser Gutschein ist storniert.');
    await clear();
    await type(partial);
    await expectProblem('Dieser Gutschein liegt schon am Bon.');
    await clear();
    await type(live);
    await expectProblem('Dieser Gutschein gilt nicht im Übungsmodus.');
    await clear();
    await _tap(t, 'voucher-redeem-back');
    expect(cartOf(t).vouchers, hasLength(1));
  });

  testWidgets('Übungs-Gutschein im echten Betrieb: "Das ist ein '
      'Übungs-Gutschein."', (t) async {
    final overrides = await memoryOverrides();
    await _open(
      t,
      overrides: [
        ...overrides,
        receiptRepositoryProvider.overrideWith(
          (ref) => _LiveReceipts(
            ref.watch(databaseProvider),
            ref.watch(clockProvider),
            ref.watch(dayRepositoryProvider),
          ),
        ),
      ],
    );
    // Ohne Signatur entsteht hier ein Übungs-Gutschein.
    final code = await sellVoucherAtRegister(t, 2000);
    expect((await _voucher(t, code)).isTest, isTrue);
    await _redeemSheet(t, code);
    expect(
      textOf(t, const Key('voucher-code-problem')),
      'Das ist ein Übungs-Gutschein.',
    );
    expect(find.byKey(const Key('voucher-redeem-go')), findsNothing);
  });

  testWidgets('ein Doppeltipp auf "Einlösen" schließt einmal ab und legt den '
      'Gutschein nicht zweimal an', (t) async {
    final calls = _Calls();
    await _open(
      t,
      overrides: [
        ...await memoryOverrides(),
        saleServiceProvider.overrideWith((ref) => _CountingSales(ref, calls)),
        cartProvider.overrideWith(() => _CountingCart(calls)),
      ],
    );
    final full = await sellVoucherAtRegister(t, 2500);
    await _redeemSheet(t, full);
    await t.tap(find.byKey(const Key('voucher-redeem-go')));
    await t.tap(
      find.byKey(const Key('voucher-redeem-go')),
      warnIfMissed: false,
    );
    await t.pumpAndSettle();
    // Der zweite Tipp ruft das Abschließen nicht noch einmal.
    expect((calls.complete, calls.apply), (1, 1));
    expect(await receiptCount(t), 2);
    expect(
      [for (final p in await _payments(t)) (p['kind'], p['amount_cents'])],
      [('voucher', 965)],
    );
    await _tap(t, 'next-customer');

    await tapItem(t, 'teigtaschen');
    await tapItem(t, 'cola');
    await t.pumpAndSettle();
    final part = await sellVoucherAtRegister(t, 500);
    await _redeemSheet(t, part);
    await t.tap(find.byKey(const Key('voucher-redeem-go')));
    await t.tap(
      find.byKey(const Key('voucher-redeem-go')),
      warnIfMissed: false,
    );
    await t.pumpAndSettle();
    // Teils: der Gutschein kommt genau einmal an den Bon, abgeschlossen wird
    // nichts.
    expect((calls.complete, calls.apply), (1, 2));
    expect(cartOf(t).vouchers, hasLength(1));
    expect(find.byKey(const Key('applied-voucher-1')), findsNothing);
  });

  testWidgets('Guthaben ändert sich zwischen Einlösen und Bar: nichts '
      'gespeichert, Hinweis, der Bon zeigt das neue Guthaben', (t) async {
    await _open(t);
    final code = await sellVoucherAtRegister(t, 500);
    await _redeem(t, code);
    await _drawElsewhere(t, code, 315);
    final receipts = await receiptCount(t);
    final moves = (await queryRows(
      t,
      'SELECT COUNT(*) c FROM voucher_movements',
    )).single['c'];

    await _tap(t, 'pay-cash');
    expect(textOf(t, const Key('cash-total')), '4,65 €');
    await _tap(t, 'finish-sale');
    expect(await receiptCount(t), receipts);
    expect(
      (await queryRows(
        t,
        'SELECT COUNT(*) c FROM voucher_movements',
      )).single['c'],
      moves,
    );
    expect(find.byKey(const Key('cash-total')), findsNothing);
    expect(find.byKey(const Key('voucher-changed')), findsOneWidget);
    expect(
      find.text('Das Guthaben hat sich geändert. Bitte noch einmal ansehen.'),
      findsOneWidget,
    );
    expect(cartOf(t).vouchers.single.balanceCents, 185);
    expect(textOf(t, const Key('applied-voucher-amount-0')), '−1,85 €');
    expect(textOf(t, const Key('due-amount')), '7,80 €');

    // Fällt das Guthaben auf 0, fällt der Gutschein vom Bon.
    await _drawElsewhere(t, code, 185);
    await _tap(t, 'pay-cash');
    await _tap(t, 'finish-sale');
    expect(cartOf(t).vouchers, isEmpty);
    expect(find.byKey(const Key('due-row')), findsNothing);
    expect(textOf(t, const Key('cart-total')), '9,65 €');
    expect(await receiptCount(t), receipts);
  });

  testWidgets('Guthaben reicht vor der Karte nicht mehr: das Terminal wird '
      'nicht gerufen', (t) async {
    await _open(t);
    final code = await sellVoucherAtRegister(t, 500);
    await _redeem(t, code);
    await _drawElsewhere(t, code, 315);
    await _tap(t, 'pay-card');
    expect(terminalOf(t).payments, isEmpty);
    expect(
      await containerOf(t).read(cardPaymentRepositoryProvider).pending(),
      isEmpty,
    );
    expect(find.byKey(const Key('unclear-card')), findsNothing);
    expect(find.byKey(const Key('voucher-changed')), findsOneWidget);
    expect(cartOf(t).vouchers.single.balanceCents, 185);
    expect(await receiptCount(t), 1);

    // Mit dem neuen Guthaben geht die Karte über den neuen Rest.
    await _tap(t, 'pay-card');
    expect(terminalOf(t).payments.single.amountCents, 780);
    expect(
      [for (final p in await _payments(t)) (p['kind'], p['amount_cents'])],
      [('voucher', 185), ('card', 780)],
    );
  });

  testWidgets('Guthaben reicht nach "Teil bar" nicht mehr: der Hinweis zum '
      'Bar-Teil bleibt neben "Guthaben geändert" stehen', (t) async {
    await _open(t);
    await setSettings(t, (s) => s.copyWith(splitPaymentEnabled: true));
    final code = await sellVoucherAtRegister(t, 500);
    await _redeem(t, code);
    await _drawElsewhere(t, code, 315);
    await _tap(t, 'pay-cash');
    await _tap(t, 'cash-mode-split');
    await tapKeys(t, '2');
    await _tap(t, 'split-go');
    expect(terminalOf(t).payments, isEmpty);
    expect(find.byKey(const Key('voucher-changed')), findsOneWidget);
    expect(cartOf(t).vouchers.single.balanceCents, 185);
    // Die 2 € liegen schon in der Hand.
    expect(find.byKey(const Key('split-card-failed')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('split-card-failed')),
        matching: find.textContaining('2,00'),
      ),
      findsOneWidget,
    );
    expect(await receiptCount(t), 1);
  });

  testWidgets('Karte belastet, Guthaben inzwischen weg: der Bon entsteht, '
      'der Gutschein ist überzogen', (t) async {
    await _open(t);
    final code = await sellVoucherAtRegister(t, 500);
    await _redeem(t, code);
    // Die Bewegung kommt, während das Terminal schon bucht.
    terminalOf(t).next = () async {
      await _drawElsewhere(t, code, 500);
      return const CardPaid(txCode: 'TX1');
    };
    await _tap(t, 'pay-card');
    expect(find.byKey(const Key('paid-by-card')), findsOneWidget);
    expect(
      [
        for (final p in await _payments(t))
          (p['kind'], p['amount_cents'], p['voucher_balance_after_cents']),
      ],
      [('voucher', 500, -500), ('card', 465, null)],
    );
    expect((await _voucher(t, code)).state, VoucherState.overdrawn);
    expect(
      await containerOf(t).read(cardPaymentRepositoryProvider).pending(),
      isEmpty,
    );
  });

  testWidgets('Neustart mit gewähltem Gutschein: er liegt wieder am Bon, mit '
      'frischem Guthaben', (t) async {
    await _open(t);
    final code = await sellVoucherAtRegister(t, 500);
    await _redeem(t, code);
    expect(await draftOf(t), contains('"vouchers"'));
    await _drawElsewhere(t, code, 315);

    await pumpKassa(t, sameDatabase: true);
    await t.pumpAndSettle();
    expect(cartOf(t).lines, hasLength(2));
    expect(cartOf(t).vouchers.single.code, code);
    expect(cartOf(t).vouchers.single.balanceCents, 185);
    expect(textOf(t, const Key('applied-voucher-amount-0')), '−1,85 €');
    expect(textOf(t, const Key('due-amount')), '7,80 €');
    expect(await draftOf(t), contains('"balanceCents":185'));
  });

  testWidgets('Code: 8 Ziffern, zurück und dieselbe Ziffer, während noch '
      'gesucht wird, melden den Gutschein genau einmal', (t) async {
    final slow = _SlowVouchers();
    addTearDown(slow.close);
    final found = <String>[];
    await pumpApp(
      t,
      SingleChildScrollView(
        child: VoucherCodeEntry(
          onFound: (v) => found.add(v.code),
          onCleared: () {},
        ),
      ),
      overrides: [
        ...await memoryOverrides(),
        voucherRepositoryProvider.overrideWithValue(slow),
      ],
    );
    await t.pumpAndSettle();
    await tapKeys(t, '1 2 3 4 5 6 7 8');
    await tapKeys(t, 'back 8');
    // Zwei Suchen nach demselben Code laufen; beide kommen jetzt zurück.
    expect(slow.waiting, 2);
    slow.release();
    await t.pumpAndSettle();
    expect(found, ['12345678']);
  });
}

/// Zählt, wie oft der Bogen abschließt und einen Gutschein an den Bon legt.
class _Calls {
  int complete = 0;
  int apply = 0;
}

class _CountingSales extends SaleService {
  _CountingSales(super.ref, this._calls);

  final _Calls _calls;

  @override
  Future<SaleResult> completeVoucher({
    required String saleId,
    required Cart cart,
    required Staff staff,
  }) {
    _calls.complete++;
    return super.completeVoucher(saleId: saleId, cart: cart, staff: staff);
  }
}

class _CountingCart extends CartController {
  _CountingCart(this._calls);

  final _Calls _calls;

  @override
  void applyVoucher(AppliedVoucher voucher) {
    _calls.apply++;
    super.applyVoucher(voucher);
  }
}

/// Sucht Gutscheine erst, wenn [release] gerufen ist: so laufen zwei Suchen
/// gleichzeitig.
class _SlowVouchers extends VoucherRepository {
  _SlowVouchers() : this._(KassaDatabase(NativeDatabase.memory()));
  _SlowVouchers._(this._db) : super(_db);

  final KassaDatabase _db;
  final _gate = Completer<void>();
  int waiting = 0;

  void release() => _gate.complete();

  Future<void> close() => _db.close();

  @override
  Future<List<Voucher>> findByCode(String code) async {
    waiting++;
    await _gate.future;
    return [
      Voucher(
        id: 'v1',
        code: code,
        valueCents: 2500,
        createdAt: DateTime(2026, 11, 17),
        isTest: true,
        movements: const [],
      ),
    ];
  }
}
