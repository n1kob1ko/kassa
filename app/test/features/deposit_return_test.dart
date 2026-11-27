// Pfand zurück an der Kassa: Das Blatt zeigt je Pfand-Betrag der Karte eine
// Reihe mit Minus, Anzahl und Plus; "Auf den Bon" legt je Betrag eine Zeile
// "Pfand zurück" an. Die Summe sinkt um das zurückgegebene Pfand: über 0 wie
// bisher, genau 0 "Abschließen", unter 0 nur "Bar auszahlen".

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/data/receipt_repository.dart';
import 'package:kassa/domain/cart.dart';
import 'package:kassa/domain/receipt.dart';
import 'package:kassa/domain/staff.dart';
import 'package:kassa/domain/feature_access.dart';
import 'package:kassa/features/kassa/cart_controller.dart';
import 'package:kassa/features/login/session.dart';
import 'package:kassa/ui/pressable.dart';
import 'package:kassa/ui/primary_button.dart';
import 'package:material_ui/material_ui.dart';

import '../support/cash_pump.dart';
import '../support/kassa_pump.dart';
import '../support/pump.dart';

PrimaryButton buttonOf(WidgetTester t, String key) =>
    t.widget<PrimaryButton>(find.byKey(Key(key)));

/// Die Taste [key] (Plus oder Minus) nimmt einen Tipp an.
bool _enabled(WidgetTester t, String key) =>
    t
        .widget<Pressable>(
          find
              .descendant(
                of: find.byKey(Key(key)),
                matching: find.byType(Pressable),
                matchRoot: true,
              )
              .first,
        )
        .onTap !=
    null;

Future<void> _tap(WidgetTester t, String key) async {
  await t.ensureVisible(find.byKey(Key(key)));
  await t.pumpAndSettle();
  await t.tap(find.byKey(Key(key)));
  await t.pumpAndSettle();
}

Future<void> _tapTimes(WidgetTester t, String key, int times) async {
  await t.ensureVisible(find.byKey(Key(key)));
  await t.pumpAndSettle();
  for (var i = 0; i < times; i++) {
    await t.tap(find.byKey(Key(key)));
    await t.pump();
  }
  await t.pumpAndSettle();
}

/// Kassa mit Pfand zurück für alle, angemeldet Anna; die Artikel [ids] auf
/// dem Bon, mit Drucker.
Future<void> _open(WidgetTester t, {List<String> ids = const []}) async {
  await pumpKassa(t);
  await setSettings(
    t,
    (s) => s.copyWith(depositReturnAccess: FeatureAccess.all),
  );
  await setUpPrinter(t);
  for (final id in ids) {
    await tapItem(t, id);
  }
  await t.pumpAndSettle();
}

/// Öffnet das Blatt, gibt [count] × 0,25 € zurück und legt es auf den Bon.
Future<void> _giveBack(WidgetTester t, int count) async {
  await _tap(t, 'deposit-return-button');
  await _tapTimes(t, 'deposit-return-plus-25', count);
  await _tap(t, 'deposit-return-add');
}

CartLine _returnLine(WidgetTester t) =>
    cartOf(t).lines.singleWhere((l) => l.isDepositReturn);

void main() {
  testWidgets('3 × 0,25 € zurück auf einen Bon mit Ware: Zeile, Summe '
      '17,45 €, bar zahlen wie immer', (t) async {
    // 2 × Cola, Pommes, Bananenkuchen, Mochi: 18,20 € mit 0,50 € Pfand.
    await _open(t, ids: ['cola', 'cola', 'pommes', 'bananenkuchen', 'mochi']);
    expect(cartOf(t).totalCents, 1820);
    await _tap(t, 'deposit-return-button');
    expect(find.byKey(const Key('deposit-return-sheet')), findsOneWidget);
    // Eine Reihe je Pfand-Betrag der Karte: nur 0,25 €.
    expect(find.byKey(const Key('deposit-return-count-25')), findsOneWidget);
    expect(textOf(t, const Key('deposit-return-count-25')), '0');
    expect(_enabled(t, 'deposit-return-minus-25'), isFalse);
    expect(buttonOf(t, 'deposit-return-add').onPressed, isNull);
    await _tapTimes(t, 'deposit-return-plus-25', 3);
    expect(textOf(t, const Key('deposit-return-count-25')), '3');
    expect(textOf(t, const Key('deposit-return-total')), contains('−0,75'));
    expect(buttonOf(t, 'deposit-return-add').onPressed, isNotNull);
    // Bis "Auf den Bon" ändert sich am Bon nichts.
    expect(cartOf(t).depositReturnQuantity(25), 0);
    await _tap(t, 'deposit-return-add');

    expect(find.byKey(const Key('deposit-return-sheet')), findsNothing);
    expect(cartOf(t).depositReturnQuantity(25), 3);
    expect(cartOf(t).totalCents, 1745);
    expect(textOf(t, const Key('cart-total')), '17,45 €');
    final line = _returnLine(t);
    final row = find.byKey(Key('line-${line.lineId}'));
    expect(
      find.descendant(of: row, matching: find.text('Pfand zurück')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row, matching: find.text('−0,75 €')),
      findsOneWidget,
    );
    expect(textOf(t, Key('qty-${line.lineId}')), '3');
    expect(find.byKey(const Key('pay-cash')), findsOneWidget);
    expect(find.byKey(const Key('pay-card')), findsOneWidget);
    expect(find.byKey(const Key('pay-out')), findsNothing);
    expect(find.byKey(const Key('finish-free')), findsNothing);

    await _tap(t, 'pay-cash');
    await _tap(t, 'finish-sale');
    expect(
      await queryRows(
        t,
        'SELECT kind, amount_cents, given_cents, change_cents FROM payments',
      ),
      [
        {
          'kind': 'cash',
          'amount_cents': 1745,
          'given_cents': 1745,
          'change_cents': 0,
        },
      ],
    );
    expect(
      await queryRows(
        t,
        'SELECT item_id, quantity, unit_deposit_cents FROM receipt_lines '
        "WHERE item_id LIKE 'deposit-return-%'",
      ),
      [
        {
          'item_id': 'deposit-return-25',
          'quantity': 3,
          'unit_deposit_cents': -25,
        },
      ],
    );
  });

  testWidgets('nur Pfand zurück: "Bar auszahlen 0,75 €", Bon mit einer '
      'Bar-Zahlung über −0,75 €, Lade springt auf, "Auszahlen 0,75 €"', (
    t,
  ) async {
    await _open(t);
    expect(cartOf(t).isEmpty, isTrue);
    // Die Taste steht auch am leeren Bon.
    await _giveBack(t, 3);
    expect(cartOf(t).totalCents, -75);
    expect(textOf(t, const Key('cart-total')), '−0,75 €');
    expect(find.byKey(const Key('pay-cash')), findsNothing);
    expect(find.byKey(const Key('pay-card')), findsNothing);
    expect(find.byKey(const Key('finish-free')), findsNothing);
    expect(textOf(t, const Key('pay-out')), 'Bar auszahlen 0,75 €');
    await t.tap(find.byKey(const Key('pay-out')));
    await t.pumpAndSettle();
    expect(
      await queryRows(
        t,
        'SELECT kind, amount_cents, given_cents, change_cents FROM payments',
      ),
      [
        {
          'kind': 'cash',
          'amount_cents': -75,
          'given_cents': 0,
          'change_cents': 0,
        },
      ],
    );
    expect(await queryRows(t, 'SELECT total_cents FROM receipts'), [
      {'total_cents': -75},
    ]);
    expect(printerOf(t).drawerOpened, 1);
    expect(printerOf(t).log, [startsWith('print+drawer:')]);
    expect(textOf(t, const Key('payout-done')), contains('0,75'));
    expect(find.byKey(const Key('change-done')), findsNothing);
    expect(cartOf(t).isEmpty, isTrue);
    await _tap(t, 'next-customer');
    expect(find.byKey(const Key('deposit-return-button')), findsOneWidget);
  });

  testWidgets('Pfand zurück gleich Summe der Ware: "Abschließen", keine '
      'Zahlung mit Betrag, Lade bleibt zu', (t) async {
    // Die Beispiel-Karte hat keinen Artikel zu 0,25 €: Edamame 4,50 € und
    // 18 × 0,25 € zurück ergeben genau 0, ohne Rabatt.
    await _open(t, ids: ['edamame']);
    await _giveBack(t, 18);
    expect(cartOf(t).totalCents, 0);
    expect(cartOf(t).pricing.discountCents, 0);
    expect(find.byKey(const Key('pay-cash')), findsNothing);
    expect(find.byKey(const Key('pay-card')), findsNothing);
    expect(find.byKey(const Key('pay-out')), findsNothing);
    expect(textOf(t, const Key('finish-free')), 'Abschließen');
    await _tap(t, 'finish-free');
    expect(
      await queryRows(
        t,
        'SELECT kind, amount_cents, given_cents, change_cents FROM payments',
      ),
      [
        {
          'kind': 'cash',
          'amount_cents': 0,
          'given_cents': 0,
          'change_cents': 0,
        },
      ],
    );
    expect(printerOf(t).drawerOpened, 0);
    expect(printerOf(t).log, [startsWith('print:')]);
    expect(find.byKey(const Key('next-customer')), findsOneWidget);
    expect(find.byKey(const Key('payout-done')), findsNothing);
  });

  testWidgets('Summe unter 0 mit Rabatt 100 %, freiem Betrag und "Teil bar" '
      'an: nur pay-out, kein Trinkgeld, kein Gutschein', (t) async {
    await _open(t, ids: ['cola']);
    await setSettings(
      t,
      (s) => s.copyWith(
        discountAccess: FeatureAccess.all,
        openAmountAccess: FeatureAccess.all,
        splitPaymentEnabled: true,
        cardTipEnabled: true,
        voucherEnabled: true,
      ),
    );
    await _tap(t, 'discount-button');
    await t.tap(find.byKey(const Key('discount-reason-invitation')));
    await _tap(t, 'discount-apply');
    // 100 % auf die Ware: es bleibt das Pfand der Cola, 0,25 €.
    expect(cartOf(t).totalCents, 25);
    await _tap(t, 'more-button');
    // Gutschein verkaufen steht seit Task 10 im Blatt "Mehr"; Bezahlen mit
    // Gutschein gibt es unter 0 trotzdem nicht (unten).
    expect(find.byKey(const Key('more-voucher')), findsOneWidget);
    await _tap(t, 'more-deposit-return');
    await _tapTimes(t, 'deposit-return-plus-25', 2);
    await _tap(t, 'deposit-return-add');
    expect(cartOf(t).totalCents, -25);
    for (final key in [
      'pay-cash',
      'pay-card',
      'finish-free',
      'pay-voucher',
      'finish-voucher',
      'voucher-button',
    ]) {
      expect(find.byKey(Key(key)), findsNothing, reason: key);
    }
    expect(textOf(t, const Key('pay-out')), 'Bar auszahlen 0,25 €');
    await _tap(t, 'pay-out');
    expect(find.byKey(const Key('tip-sheet')), findsNothing);
    expect(find.byKey(const Key('cash-mode-split')), findsNothing);
    expect(terminalOf(t).payments, isEmpty);
    expect(
      await queryRows(t, 'SELECT kind, amount_cents, tip_cents FROM payments'),
      [
        {'kind': 'cash', 'amount_cents': -25, 'tip_cents': 0},
      ],
    );
    expect(
      await queryRows(t, 'SELECT total_cents, discount_cents FROM receipts'),
      [
        {'total_cents': -25, 'discount_cents': 290},
      ],
    );
    expect(textOf(t, const Key('payout-done')), contains('0,25'));
  });

  testWidgets('das Blatt öffnet mit den Mengen vom Bon; alle auf 0 nimmt die '
      'Zeile weg', (t) async {
    await _open(t, ids: ['cola']);
    await _giveBack(t, 3);
    await _tap(t, 'deposit-return-button');
    expect(textOf(t, const Key('deposit-return-count-25')), '3');
    expect(textOf(t, const Key('deposit-return-total')), contains('−0,75'));
    // Gleich wie am Bon: "Auf den Bon" ist grau.
    expect(buttonOf(t, 'deposit-return-add').onPressed, isNull);
    await _tapTimes(t, 'deposit-return-plus-25', 1);
    expect(buttonOf(t, 'deposit-return-add').onPressed, isNotNull);
    await _tapTimes(t, 'deposit-return-minus-25', 1);
    expect(buttonOf(t, 'deposit-return-add').onPressed, isNull);
    await _tapTimes(t, 'deposit-return-minus-25', 3);
    expect(textOf(t, const Key('deposit-return-count-25')), '0');
    expect(_enabled(t, 'deposit-return-minus-25'), isFalse);
    await _tap(t, 'deposit-return-add');
    expect(cartOf(t).lines.map((l) => l.item.id), ['cola']);
    expect(cartOf(t).totalCents, 315);

    // "Zurück" lässt den Bon, wie er ist.
    await _giveBack(t, 2);
    await _tap(t, 'deposit-return-button');
    await _tapTimes(t, 'deposit-return-plus-25', 4);
    await _tap(t, 'deposit-return-back');
    expect(find.byKey(const Key('deposit-return-sheet')), findsNothing);
    expect(cartOf(t).depositReturnQuantity(25), 2);
  });

  testWidgets('höchstens 99: Plus bei 99 grau, im Blatt und an der Zeile; '
      'Plus und Minus der Zeile ändern die Menge', (t) async {
    await _open(t, ids: ['cola']);
    containerOf(t).read(cartProvider.notifier).setDepositReturns({25: 98});
    await t.pumpAndSettle();
    final line = _returnLine(t);
    expect(_enabled(t, 'qty-plus-${line.lineId}'), isTrue);
    await _tap(t, 'qty-plus-${line.lineId}');
    expect(cartOf(t).depositReturnQuantity(25), 99);
    expect(_enabled(t, 'qty-plus-${line.lineId}'), isFalse);

    await _tap(t, 'deposit-return-button');
    expect(textOf(t, const Key('deposit-return-count-25')), '99');
    expect(_enabled(t, 'deposit-return-plus-25'), isFalse);
    expect(_enabled(t, 'deposit-return-minus-25'), isTrue);
    await _tap(t, 'deposit-return-back');

    await _tap(t, 'qty-minus-${line.lineId}');
    expect(cartOf(t).depositReturnQuantity(25), 98);
    // Die Zeile bleibt an ihrer Stelle, mit derselben Kennung.
    expect(_returnLine(t).lineId, line.lineId);
    containerOf(t).read(cartProvider.notifier).setDepositReturns({25: 1});
    await t.pumpAndSettle();
    await _tap(t, 'qty-minus-${line.lineId}');
    expect(cartOf(t).lines.map((l) => l.item.id), ['cola']);
  });

  testWidgets('"Nur Chef": eine Person ohne das Recht sieht die Zeile Pfand '
      'zurück, kann sie aber nicht erhöhen und nicht auszahlen; der Chef '
      'schon', (t) async {
    await _open(t);
    await _giveBack(t, 3);
    await setSettings(
      t,
      (s) => s.copyWith(depositReturnAccess: FeatureAccess.chefOnly),
    );
    final id = _returnLine(t).lineId;
    expect(find.byKey(Key('line-$id')), findsOneWidget);

    await t.tap(find.byKey(Key('qty-plus-$id')));
    await t.pump();
    expect(_returnLine(t).quantity, 3);
    expect(find.byKey(const Key('deposit-return-chef-only')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('deposit-return-chef-only')),
        matching: find.text('Pfand zurück ist für dich nicht freigegeben.'),
      ),
      findsOneWidget,
    );
    await t.pump(const Duration(seconds: 10));
    await t.pumpAndSettle();

    await t.tap(find.byKey(const Key('pay-out')));
    await t.pump();
    expect(find.byKey(const Key('deposit-return-chef-only')), findsOneWidget);
    await t.pump(const Duration(seconds: 10));
    await t.pumpAndSettle();
    expect(await queryRows(t, 'SELECT id FROM receipts'), isEmpty);
    expect(_returnLine(t).quantity, 3);

    // Weniger geht: die Zeile kleiner machen nimmt kein Geld heraus.
    await t.tap(find.byKey(Key('qty-minus-$id')));
    await t.pump();
    expect(_returnLine(t).quantity, 2);

    await containerOf(t).read(sessionProvider.notifier).login('4711');
    await t.pumpAndSettle();
    await t.tap(find.byKey(Key('qty-plus-$id')));
    await t.pump();
    expect(_returnLine(t).quantity, 3);
    expect(find.byKey(const Key('deposit-return-chef-only')), findsNothing);
    await t.tap(find.byKey(const Key('pay-out')));
    await t.pumpAndSettle();
    expect(await queryRows(t, 'SELECT total_cents FROM receipts'), [
      {'total_cents': -75},
    ]);
  });

  testWidgets('"Bar auszahlen", das Speichern scheitert: nichts gespeichert, '
      'die Lade bleibt zu, der Bon bleibt; der zweite Versuch schreibt genau '
      'einen Bon', (t) async {
    late _FlakyPayouts receipts;
    await pumpKassa(
      t,
      overrides: [
        ...await memoryOverrides(),
        receiptRepositoryProvider.overrideWith((ref) {
          return receipts = _FlakyPayouts(
            ref.watch(databaseProvider),
            ref.watch(clockProvider),
            ref.watch(dayRepositoryProvider),
          );
        }),
      ],
    );
    await setSettings(
      t,
      (s) => s.copyWith(depositReturnAccess: FeatureAccess.all),
    );
    await setUpPrinter(t);
    await _giveBack(t, 3);
    await t.tap(find.byKey(const Key('pay-out')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('finish-free-failed')), findsOneWidget);
    expect(await queryRows(t, 'SELECT id FROM receipts'), isEmpty);
    expect(printerOf(t).drawerOpened, 0);
    expect(_returnLine(t).quantity, 3);
    expect(find.byKey(const Key('pay-out')), findsOneWidget);

    await t.tap(find.byKey(const Key('pay-out')));
    await t.pumpAndSettle();
    expect(receipts.ids, hasLength(2));
    expect(receipts.ids[1], receipts.ids[0]);
    expect(await queryRows(t, 'SELECT total_cents FROM receipts'), [
      {'total_cents': -75},
    ]);
    expect(printerOf(t).drawerOpened, 1);
    expect(cartOf(t).isEmpty, isTrue);
  });

  testWidgets('die Zeile Pfand zurück ist kein Ziel im Rabatt-Blatt', (
    t,
  ) async {
    await _open(t, ids: ['cola']);
    await setSettings(t, (s) => s.copyWith(discountAccess: FeatureAccess.all));
    await _giveBack(t, 1);
    final line = _returnLine(t);
    final row = find.byKey(Key('line-${line.lineId}'));
    // Ein Tipp auf Name oder Betrag öffnet kein Blatt.
    await t.tap(find.descendant(of: row, matching: find.text('Pfand zurück')));
    await t.pumpAndSettle();
    await t.tap(find.descendant(of: row, matching: find.text('−0,25 €')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('discount-sheet')), findsNothing);

    // Ein Rabatt auf den ganzen Bon geht nur auf die Ware.
    await _tap(t, 'discount-button');
    await t.tap(find.byKey(const Key('discount-reason-regular')));
    await t.tap(find.byKey(const Key('discount-percent-50')));
    await _tap(t, 'discount-apply');
    expect(find.byKey(Key('line-discount-${line.lineId}')), findsNothing);
    final i = cartOf(t).lines.indexWhere((l) => l.isDepositReturn);
    expect(cartOf(t).pricing.lines[i].discountCents, 0);
    // Cola 2,90 € − 1,45 € + 0,25 € Pfand − 0,25 € zurück.
    expect(cartOf(t).totalCents, 145);
  });
}

/// Bon-Speicher, dessen erste Auszahlung scheitert.
class _FlakyPayouts extends ReceiptRepository {
  _FlakyPayouts(super.db, super.clock, super.days);

  final List<String> ids = [];

  @override
  Future<Receipt> finalizePayout({
    required String saleId,
    required Cart cart,
    required Staff staff,
  }) {
    ids.add(saleId);
    if (ids.length == 1) return Future.error(StateError('Platte voll'));
    return super.finalizePayout(saleId: saleId, cart: cart, staff: staff);
  }
}
