// Rabatt an der Kassa: Ein Tipp auf eine Bon-Zeile oder die Taste "Rabatt"
// öffnet ein Blatt (Grund, Höhe, Neu); ein gesetzter Rabatt ist immer zu
// sehen; eine Summe von 0,00 € mit Rabatt schließt mit "Abschließen" ab.

import 'dart:async';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/core/app_language.dart';
import 'package:kassa/core/money.dart';
import 'package:kassa/devices/card_terminal.dart';
import 'package:kassa/domain/discount.dart';
import 'package:kassa/domain/cart.dart';
import 'package:kassa/domain/feature_access.dart';
import 'package:kassa/domain/staff.dart';
import 'package:kassa/features/kassa/sale_service.dart';
import 'package:kassa/features/login/session.dart';
import 'package:kassa/ui/pressable.dart';
import 'package:kassa/ui/primary_button.dart';
import 'package:material_ui/material_ui.dart';

import '../support/cash_pump.dart';
import '../support/kassa_pump.dart';
import '../support/pump.dart';

PrimaryButton buttonOf(WidgetTester t, String key) =>
    t.widget<PrimaryButton>(find.byKey(Key(key)));

/// Ob die Taste einer Auswahl gewählt ist.
bool? selectedOf(WidgetTester t, String key) => t
    .widget<Pressable>(
      find
          .descendant(
            of: find.byKey(Key(key)),
            matching: find.byType(Pressable),
            matchRoot: true,
          )
          .first,
    )
    .selected;

/// Kassa mit Rabatt für [access], angemeldet mit [pin], Bon: 2 × Cola und
/// Teigtaschen (12,30 € Ware plus 0,50 € Pfand). Mit [ids] andere Artikel.
Future<void> openWithDiscount(
  WidgetTester t,
  FeatureAccess access, {
  String pin = '1234',
  List<String> ids = const ['cola', 'cola', 'teigtaschen'],
  Size size = const Size(1280, 800),
  double textScale = 1.0,
  AppLanguage language = AppLanguage.de,
  List<Override>? overrides,
}) async {
  await pumpKassa(
    t,
    pin: pin,
    size: size,
    textScale: textScale,
    overrides: overrides,
  );
  await setSettings(
    t,
    (s) => s.copyWith(discountAccess: access, language: language),
  );
  for (final id in ids) {
    await tapItem(t, id);
  }
  await t.pumpAndSettle();
}

Future<void> _tap(WidgetTester t, String key) async {
  await t.ensureVisible(find.byKey(Key(key)));
  await t.pumpAndSettle();
  await t.tap(find.byKey(Key(key)));
  await t.pumpAndSettle();
}

/// Öffnet das Blatt für die Zeile an Stelle [index] (Tipp auf den Preis: der
/// Name steht in jeder Sprache anders).
Future<void> _openLine(WidgetTester t, int index) async {
  final line = cartOf(t).lines[index];
  await t.tap(
    find.descendant(
      of: find.byKey(Key('line-${line.lineId}')),
      matching: find.text(formatEuro(line.goodsCents)),
    ),
  );
  await t.pumpAndSettle();
}

Finder _lineDiscount(WidgetTester t, int index) =>
    find.byKey(Key('line-discount-${cartOf(t).lines[index].lineId}'));

void main() {
  testWidgets('Zeile: Tipp auf den Namen öffnet das Blatt, 10 % Stammgast '
      'steht unter der Zeile', (t) async {
    await openWithDiscount(t, FeatureAccess.all);
    await t.tap(find.text('Teigtaschen').last);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('discount-sheet')), findsOneWidget);
    expect(find.text('Rabatt auf: Teigtaschen'), findsOneWidget);
    expect(textOf(t, const Key('discount-target')), '6,50 €');
    expect(find.byKey(const Key('discount-hint')), findsNothing);
    expect(find.byKey(const Key('discount-remove')), findsNothing);
    expect(buttonOf(t, 'discount-apply').onPressed, isNull);
    await t.tap(find.byKey(const Key('discount-percent-10')));
    await t.pump();
    // Grund ist Pflicht.
    expect(buttonOf(t, 'discount-apply').onPressed, isNull);
    await t.tap(find.byKey(const Key('discount-reason-regular')));
    await t.pump();
    expect(textOf(t, const Key('discount-new')), '5,85 €');
    await t.tap(find.byKey(const Key('discount-apply')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('discount-sheet')), findsNothing);
    final line = cartOf(t).lines[1];
    expect(line.discount, const Discount.percent(10, DiscountReason.regular));
    final row = find.byKey(Key('line-discount-${line.lineId}'));
    expect(
      find.descendant(of: row, matching: find.text('−10 % Stammgast')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row, matching: find.text('−0,65 €')),
      findsOneWidget,
    );
    expect(textOf(t, const Key('cart-total')), '12,15 €');
  });

  testWidgets('Zeile: auch ein Tipp auf den Preis öffnet das Blatt; Minus und '
      'Plus bleiben, wie sie sind', (t) async {
    await openWithDiscount(t, FeatureAccess.all);
    final cola = cartOf(t).lines[0];
    await t.tap(find.byKey(Key('qty-plus-${cola.lineId}')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('discount-sheet')), findsNothing);
    expect(cartOf(t).lines[0].quantity, 3);
    await t.tap(find.byKey(Key('qty-minus-${cola.lineId}')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('discount-sheet')), findsNothing);
    expect(cartOf(t).lines[0].quantity, 2);
    await t.tap(
      find.descendant(
        of: find.byKey(Key('line-${cola.lineId}')),
        matching: find.text('5,80 €'),
      ),
    );
    await t.pumpAndSettle();
    expect(find.byKey(const Key('discount-sheet')), findsOneWidget);
    expect(find.text('Rabatt auf: 2 × Cola 0,33 l'), findsOneWidget);
    expect(textOf(t, const Key('discount-target')), '5,80 €');
    await _tap(t, 'discount-back');
    expect(find.byKey(const Key('discount-sheet')), findsNothing);
    expect(cartOf(t).lines[0].discount, isNull);
  });

  testWidgets('ganzer Bon: Taste "Rabatt", Hinweis auf die Zeile, Reihe im '
      'Summenblock', (t) async {
    await openWithDiscount(t, FeatureAccess.all);
    expect(find.byKey(const Key('receipt-discount')), findsNothing);
    await t.tap(find.byKey(const Key('discount-button')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('discount-hint')), findsOneWidget);
    expect(
      find.text('Für eine einzelne Zeile die Zeile im Bon antippen.'),
      findsOneWidget,
    );
    expect(find.text('Rabatt auf: ganzer Bon'), findsOneWidget);
    expect(textOf(t, const Key('discount-target')), '12,30 €');
    await t.tap(find.byKey(const Key('discount-reason-promotion')));
    await t.tap(find.byKey(const Key('discount-percent-20')));
    await t.pump();
    expect(textOf(t, const Key('discount-new')), '9,84 €');
    await t.tap(find.byKey(const Key('discount-apply')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('receipt-discount')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('receipt-discount')),
        matching: find.text('−20 % Aktion'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('receipt-discount')),
        matching: find.text('−2,46 €'),
      ),
      findsOneWidget,
    );
    expect(
      textOf(t, const Key('cart-total')),
      '10,34 €',
    ); // 12,30 - 2,46 + 0,50
    // Die MwSt rechnet nach Rabatt: Cola 4,64 € zu 20 % (0,77 €) und
    // Teigtaschen 5,20 € zu 10 % (0,47 €); vorher 1,56 €.
    expect(find.text('inkl. 1,24 € MwSt'), findsOneWidget);
  });

  testWidgets('ganzer Bon: der Wert vor dem Rabatt ist die Zwischensumme nach '
      'den Zeilen-Rabatten', (t) async {
    await openWithDiscount(t, FeatureAccess.all);
    await _openLine(t, 1);
    await t.tap(find.byKey(const Key('discount-reason-regular')));
    await t.tap(find.byKey(const Key('discount-percent-10')));
    await _tap(t, 'discount-apply');
    await _tap(t, 'discount-button');
    expect(textOf(t, const Key('discount-target')), '11,65 €');
  });

  testWidgets('"Einladung" wählt 100 % vor; Summe 0,00 €: "Abschließen" statt '
      'Bar und Karte, die Lade bleibt zu', (t) async {
    await openWithDiscount(t, FeatureAccess.all, ids: ['teigtaschen']);
    await setUpPrinter(t);
    await _tap(t, 'discount-button');
    await t.tap(find.byKey(const Key('discount-reason-invitation')));
    await t.pump();
    expect(selectedOf(t, 'discount-percent-100'), isTrue);
    expect(textOf(t, const Key('discount-new')), '0,00 €');
    await _tap(t, 'discount-apply');
    expect(textOf(t, const Key('cart-total')), '0,00 €');
    expect(find.byKey(const Key('pay-cash')), findsNothing);
    expect(find.byKey(const Key('pay-card')), findsNothing);
    expect(textOf(t, const Key('finish-free')), 'Abschließen');
    await t.tap(find.byKey(const Key('finish-free')));
    await t.pumpAndSettle();
    expect(
      await queryRows(t, 'SELECT total_cents, discount_cents FROM receipts'),
      [
        {'total_cents': 0, 'discount_cents': 650},
      ],
    );
    expect(await queryRows(t, 'SELECT kind, amount_cents FROM payments'), [
      {'kind': 'cash', 'amount_cents': 0},
    ]);
    expect(printerOf(t).log.single, startsWith('print:'));
    expect(find.byKey(const Key('next-customer')), findsOneWidget);
    expect(cartOf(t).isEmpty, isTrue);
  });

  testWidgets('"Einladung": die Höhe lässt sich danach noch ändern', (t) async {
    await openWithDiscount(t, FeatureAccess.all, ids: ['teigtaschen']);
    await _tap(t, 'discount-button');
    await t.tap(find.byKey(const Key('discount-reason-invitation')));
    await t.tap(find.byKey(const Key('discount-percent-50')));
    await t.pump();
    expect(selectedOf(t, 'discount-percent-100'), isFalse);
    expect(selectedOf(t, 'discount-percent-50'), isTrue);
    expect(selectedOf(t, 'discount-reason-invitation'), isTrue);
    await _tap(t, 'discount-apply');
    expect(
      cartOf(t).discount,
      const Discount.percent(50, DiscountReason.invitation),
    );
  });

  testWidgets('Summe 0,00 € mit Rabatt: "Abschließen" auch mit Teil bar und '
      'Trinkgeld', (t) async {
    await openWithDiscount(t, FeatureAccess.all, ids: ['teigtaschen']);
    await setSettings(
      t,
      (s) => s.copyWith(splitPaymentEnabled: true, cardTipEnabled: true),
    );
    await _tap(t, 'discount-button');
    await t.tap(find.byKey(const Key('discount-reason-invitation')));
    await _tap(t, 'discount-apply');
    expect(find.byKey(const Key('pay-cash')), findsNothing);
    expect(find.byKey(const Key('pay-card')), findsNothing);
    await _tap(t, 'finish-free');
    expect(find.byKey(const Key('tip-sheet')), findsNothing);
    expect(find.byKey(const Key('cash-total')), findsNothing);
    expect(terminalOf(t).payments, isEmpty);
    expect(await receiptCount(t), 1);
  });

  testWidgets('Summe 0,00 € ohne Rabatt (Leitungswasser): Bar und Karte wie '
      'bisher; "Übernehmen" bleibt aus, weil es nichts zu rabattieren gibt', (
    t,
  ) async {
    await openWithDiscount(t, FeatureAccess.all, ids: ['leitungswasser']);
    expect(textOf(t, const Key('cart-total')), '0,00 €');
    expect(find.byKey(const Key('pay-cash')), findsOneWidget);
    expect(find.byKey(const Key('pay-card')), findsOneWidget);
    expect(find.byKey(const Key('finish-free')), findsNothing);
    await _openLine(t, 0);
    await t.tap(find.byKey(const Key('discount-reason-regular')));
    await t.tap(find.byKey(const Key('discount-percent-10')));
    await t.pump();
    expect(buttonOf(t, 'discount-apply').onPressed, isNull);
    await _tap(t, 'discount-back');
    await _tap(t, 'discount-button');
    await t.tap(find.byKey(const Key('discount-reason-invitation')));
    await t.pump();
    expect(buttonOf(t, 'discount-apply').onPressed, isNull);
  });

  testWidgets('nur Chef: Anna hat keine Taste; der Rabatt des Chefs bleibt, '
      'Anna kann ihn nicht ändern', (t) async {
    await openWithDiscount(
      t,
      FeatureAccess.chefOnly,
      pin: '4711',
      ids: ['teigtaschen'],
    );
    await _tap(t, 'discount-button');
    await t.tap(find.byKey(const Key('discount-reason-regular')));
    await t.tap(find.byKey(const Key('discount-percent-10')));
    await _tap(t, 'discount-apply');
    await _openLine(t, 0);
    await t.tap(find.byKey(const Key('discount-reason-staff')));
    await t.tap(find.byKey(const Key('discount-percent-5')));
    await _tap(t, 'discount-apply');
    containerOf(t).read(sessionProvider.notifier).logout();
    await t.pumpAndSettle();
    await typePin(t, '1234');
    await t.pumpAndSettle();
    await tapItem(t, 'cola');
    await t.pumpAndSettle();
    expect(find.byKey(const Key('discount-button')), findsNothing);
    expect(find.byKey(const Key('receipt-discount')), findsOneWidget);
    expect(_lineDiscount(t, 0), findsOneWidget);
    await t.tap(find.byKey(const Key('receipt-discount')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('discount-sheet')), findsNothing);
    await t.tap(_lineDiscount(t, 0));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('discount-sheet')), findsNothing);
    await t.tap(find.text('Teigtaschen').last);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('discount-sheet')), findsNothing);
    expect(cartOf(t).discount!.percent, 10);
    expect(cartOf(t).lines[0].discount!.percent, 5);
    // Keine Tippfläche: in der Zeile sind nur Minus und Plus Tasten.
    final line = find.byKey(Key('line-${cartOf(t).lines[0].lineId}'));
    expect(
      find.descendant(of: line, matching: find.byType(Pressable)),
      findsNWidgets(2),
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('receipt-discount')),
        matching: find.byType(Pressable),
      ),
      findsNothing,
    );
    expect(
      find.ancestor(
        of: find.byKey(const Key('receipt-discount')),
        matching: find.byType(Pressable),
      ),
      findsNothing,
    );
  });

  testWidgets('Schalter wird ausgeschaltet, während ein Rabatt am Bon liegt: '
      'er bleibt und zählt', (t) async {
    await openWithDiscount(t, FeatureAccess.all);
    await _openLine(t, 1);
    await t.tap(find.byKey(const Key('discount-reason-regular')));
    await t.tap(find.byKey(const Key('discount-percent-10')));
    await _tap(t, 'discount-apply');
    await setSettings(t, (s) => s.copyWith(discountAccess: FeatureAccess.off));
    expect(find.byKey(const Key('discount-button')), findsNothing);
    expect(_lineDiscount(t, 1), findsOneWidget);
    expect(textOf(t, const Key('cart-total')), '12,15 €');
    await t.tap(find.text('Teigtaschen').last);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('discount-sheet')), findsNothing);
    await _tap(t, 'pay-cash');
    expect(textOf(t, const Key('cash-total')), '12,15 €');
  });

  testWidgets('Betrag: 20,00 € auf eine Zeile mit 6,50 € wird gekappt, "Neu" '
      'zeigt 0,00 €', (t) async {
    await openWithDiscount(t, FeatureAccess.all);
    await _openLine(t, 1);
    await t.tap(find.byKey(const Key('discount-reason-regular')));
    await _tap(t, 'discount-amount');
    await tapKeys(t, '2 0');
    expect(textOf(t, const Key('discount-new')), '0,00 €');
    await _tap(t, 'discount-apply');
    final row = _lineDiscount(t, 1);
    expect(
      find.descendant(of: row, matching: find.text('Rabatt Stammgast')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row, matching: find.text('−6,50 €')),
      findsOneWidget,
    );
    // Gespeichert wird der Betrag, wie er getippt ist; gekappt wird beim
    // Rechnen.
    expect(cartOf(t).lines[1].discount!.amountCents, 2000);
    expect(
      cartOf(t).lines[1].discount,
      const Discount.amount(2000, DiscountReason.regular),
    );
    expect(textOf(t, const Key('cart-total')), '6,30 €');
    // Zwei Teigtaschen: der Rabatt wächst mit, bis 13,00 €.
    await t.tap(find.byKey(Key('qty-plus-${cartOf(t).lines[1].lineId}')));
    await t.pumpAndSettle();
    expect(
      find.descendant(of: row, matching: find.text('−13,00 €')),
      findsOneWidget,
    );
    expect(textOf(t, const Key('cart-total')), '6,30 €');
    // Drei: 19,50 € Ware, 19,50 € Rabatt; vier: 26,00 €, nur 20,00 € Rabatt.
    for (var i = 0; i < 2; i++) {
      await t.tap(find.byKey(Key('qty-plus-${cartOf(t).lines[1].lineId}')));
      await t.pumpAndSettle();
    }
    expect(cartOf(t).lines[1].quantity, 4);
    expect(
      find.descendant(of: row, matching: find.text('−20,00 €')),
      findsOneWidget,
    );
    expect(textOf(t, const Key('cart-total')), '12,30 €');
    // Wieder geöffnet steht der getippte Betrag im Zahlenfeld.
    await t.tap(row);
    await t.pumpAndSettle();
    expect(textOf(t, const Key('given-field')), '20 €');
    expect(textOf(t, const Key('discount-new')), '6,00 €');
  });

  testWidgets('Betrag 0 oder nichts zu rabattieren: "Übernehmen" bleibt aus', (
    t,
  ) async {
    await openWithDiscount(t, FeatureAccess.all, ids: ['leitungswasser']);
    await _openLine(t, 0);
    await t.tap(find.byKey(const Key('discount-reason-regular')));
    await _tap(t, 'discount-amount');
    await tapKeys(t, '5');
    expect(buttonOf(t, 'discount-apply').onPressed, isNull);
    await _tap(t, 'discount-back');
    await tapItem(t, 'teigtaschen');
    await t.pumpAndSettle();
    await _openLine(t, 1);
    await t.tap(find.byKey(const Key('discount-reason-regular')));
    await _tap(t, 'discount-amount');
    await tapKeys(t, '0');
    expect(buttonOf(t, 'discount-apply').onPressed, isNull);
  });

  testWidgets('zwei schnelle Tipps auf "Abschließen" ergeben genau einen Bon; '
      'solange gespeichert wird, nimmt der Bon keine Tipps', (t) async {
    await openWithDiscount(t, FeatureAccess.all, ids: ['teigtaschen']);
    await _tap(t, 'discount-button');
    await t.tap(find.byKey(const Key('discount-reason-invitation')));
    await _tap(t, 'discount-apply');
    await t.tap(find.byKey(const Key('finish-free')));
    await t.tap(find.byKey(const Key('finish-free')), warnIfMissed: false);
    await t.pump();
    // Ist der Bon noch nicht gespeichert, nimmt die Bon-Spalte keine Tipps.
    final busy = find.byKey(const Key('cart-busy'));
    if (busy.evaluate().isNotEmpty) {
      expect(t.widget<AbsorbPointer>(busy).absorbing, isTrue);
    }
    await t.pumpAndSettle();
    expect(await receiptCount(t), 1);
    expect(find.byKey(const Key('next-customer')), findsOneWidget);
    await _tap(t, 'next-customer');
    // Danach nimmt der Bon wieder Tipps.
    expect(
      t.widget<AbsorbPointer>(find.byKey(const Key('cart-busy'))).absorbing,
      isFalse,
    );
    await tapItem(t, 'cola');
    await t.pumpAndSettle();
    expect(cartOf(t).lines.single.quantity, 1);
  });

  testWidgets('während "Abschließen" speichert, nimmt der Bon keine Tipps; '
      'nach einem Fehler wieder, und der zweite Versuch schreibt einen Bon', (
    t,
  ) async {
    final service = _HeldSaleService.hold = Completer<void>();
    await openWithDiscount(
      t,
      FeatureAccess.all,
      ids: ['teigtaschen'],
      overrides: [
        ...await memoryOverrides(),
        saleServiceProvider.overrideWith(_HeldSaleService.new),
      ],
    );
    _HeldSaleService.calls.clear();
    await _tap(t, 'discount-button');
    await t.tap(find.byKey(const Key('discount-reason-invitation')));
    await _tap(t, 'discount-apply');
    await t.tap(find.byKey(const Key('finish-free')));
    await t.pump();
    expect(
      t.widget<AbsorbPointer>(find.byKey(const Key('cart-busy'))).absorbing,
      isTrue,
    );
    final line = cartOf(t).lines.single.lineId;
    await t.tap(find.byKey(Key('qty-plus-$line')), warnIfMissed: false);
    await t.tap(find.byKey(Key('qty-minus-$line')), warnIfMissed: false);
    await t.tap(find.text('Teigtaschen').last, warnIfMissed: false);
    await t.tap(find.byKey(const Key('discount-button')), warnIfMissed: false);
    await t.tap(find.byKey(const Key('finish-free')), warnIfMissed: false);
    await t.pump();
    expect(cartOf(t).lines.single.quantity, 1);
    expect(find.byKey(const Key('discount-sheet')), findsNothing);
    expect(_HeldSaleService.calls, hasLength(1));
    // Der Fehler gibt den Bon wieder frei, nichts ist gespeichert.
    service.completeError(StateError('kaputt'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('finish-free-failed')), findsOneWidget);
    expect(
      t.widget<AbsorbPointer>(find.byKey(const Key('cart-busy'))).absorbing,
      isFalse,
    );
    expect(await receiptCount(t), 0);
    expect(cartOf(t).lines.single.quantity, 1);
    // Der zweite Versuch nimmt dieselbe Kennung und schreibt genau einen Bon.
    _HeldSaleService.hold = null;
    await _tap(t, 'finish-free');
    expect(_HeldSaleService.calls, hasLength(2));
    expect(_HeldSaleService.calls[1], _HeldSaleService.calls[0]);
    expect(await receiptCount(t), 1);
    expect(find.byKey(const Key('next-customer')), findsOneWidget);
  });

  testWidgets('der Hinweis nach einer abgelehnten Karte mit Bar-Teil geht '
      'weg, sobald ein Rabatt auf den Bon kommt', (t) async {
    await openWithDiscount(t, FeatureAccess.all, ids: ['cola', 'teigtaschen']);
    await setSettings(t, (s) => s.copyWith(splitPaymentEnabled: true));
    await _tap(t, 'pay-cash');
    await _tap(t, 'cash-mode-split');
    terminalOf(t).next = const CardFailed(CardFailure.declined);
    await tapKeys(t, '5');
    await _tap(t, 'split-go');
    expect(find.byKey(const Key('split-card-failed')), findsOneWidget);
    // Das Blatt öffnen und zurück ändert den Bon nicht: der Hinweis bleibt.
    await _tap(t, 'discount-button');
    await _tap(t, 'discount-back');
    expect(find.byKey(const Key('split-card-failed')), findsOneWidget);
    await _tap(t, 'discount-button');
    await t.tap(find.byKey(const Key('discount-reason-regular')));
    await _tap(t, 'discount-percent-10');
    await _tap(t, 'discount-apply');
    expect(find.byKey(const Key('split-card-failed')), findsNothing);
    expect(find.byKey(const Key('receipt-discount')), findsOneWidget);
  });

  testWidgets('Betrag 1,19 € zeigt "Neu" 5,31 €; ohne Betrag bleibt '
      '"Übernehmen" aus', (t) async {
    await openWithDiscount(t, FeatureAccess.all);
    await _openLine(t, 1);
    await t.tap(find.byKey(const Key('discount-reason-complaint')));
    await _tap(t, 'discount-amount');
    expect(buttonOf(t, 'discount-apply').onPressed, isNull);
    await tapKeys(t, '1 , 1 9');
    expect(textOf(t, const Key('discount-new')), '5,31 €');
    await _tap(t, 'discount-apply');
    expect(
      cartOf(t).lines[1].discount,
      const Discount.amount(119, DiscountReason.complaint),
    );
  });

  testWidgets('Höhe und Grund: je eine Wahl; Betrag ersetzt Prozent und '
      'umgekehrt; ein zweiter Tipp lässt die Wahl stehen', (t) async {
    await openWithDiscount(t, FeatureAccess.all);
    await _openLine(t, 1);
    await t.tap(find.byKey(const Key('discount-reason-regular')));
    await t.tap(find.byKey(const Key('discount-reason-staff')));
    await t.pump();
    expect(selectedOf(t, 'discount-reason-regular'), isFalse);
    expect(selectedOf(t, 'discount-reason-staff'), isTrue);
    await t.tap(find.byKey(const Key('discount-percent-10')));
    await t.tap(find.byKey(const Key('discount-percent-20')));
    await t.pump();
    expect(selectedOf(t, 'discount-percent-10'), isFalse);
    expect(selectedOf(t, 'discount-percent-20'), isTrue);
    await t.tap(find.byKey(const Key('discount-percent-20')));
    await t.pump();
    expect(selectedOf(t, 'discount-percent-20'), isTrue);
    expect(textOf(t, const Key('discount-new')), '5,20 €');
    await _tap(t, 'discount-amount');
    expect(selectedOf(t, 'discount-percent-20'), isFalse);
    expect(textOf(t, const Key('discount-new')), '6,50 €');
    await tapKeys(t, '2');
    expect(textOf(t, const Key('discount-new')), '4,50 €');
    await _tap(t, 'discount-percent-50');
    expect(selectedOf(t, 'discount-percent-50'), isTrue);
    expect(find.byKey(const Key('given-field')), findsNothing);
    expect(textOf(t, const Key('discount-new')), '3,25 €');
    await _tap(t, 'discount-apply');
    expect(
      cartOf(t).lines[1].discount,
      const Discount.percent(50, DiscountReason.staff),
    );
  });

  testWidgets('ein Rabatt ist beim Öffnen vorgewählt; "Entfernen" nimmt ihn '
      'weg; "Bon leeren" und "Rückgängig" bringen die Rabatte zurück', (
    t,
  ) async {
    await openWithDiscount(t, FeatureAccess.all);
    await _openLine(t, 1);
    await t.tap(find.byKey(const Key('discount-reason-regular')));
    await _tap(t, 'discount-amount');
    await tapKeys(t, '1 , 5');
    await _tap(t, 'discount-apply');
    // Wieder öffnen: Grund und Betrag stehen da.
    await t.tap(_lineDiscount(t, 1));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('discount-sheet')), findsOneWidget);
    expect(selectedOf(t, 'discount-reason-regular'), isTrue);
    expect(textOf(t, const Key('given-field')), '1,50 €');
    expect(textOf(t, const Key('discount-new')), '5,00 €');
    await _tap(t, 'discount-remove');
    expect(cartOf(t).lines[1].discount, isNull);
    expect(_lineDiscount(t, 1), findsNothing);
    expect(textOf(t, const Key('cart-total')), '12,80 €');

    await _openLine(t, 0);
    await t.tap(find.byKey(const Key('discount-reason-staff')));
    await _tap(t, 'discount-percent-15');
    await _tap(t, 'discount-apply');
    await _tap(t, 'discount-button');
    await t.tap(find.byKey(const Key('discount-reason-promotion')));
    await _tap(t, 'discount-percent-5');
    await _tap(t, 'discount-apply');
    await _tap(t, 'discount-button');
    expect(selectedOf(t, 'discount-reason-promotion'), isTrue);
    expect(selectedOf(t, 'discount-percent-5'), isTrue);
    expect(find.byKey(const Key('discount-remove')), findsOneWidget);
    await _tap(t, 'discount-back');
    final total = textOf(t, const Key('cart-total'));

    await t.tap(find.byKey(const Key('clear-cart')));
    await t.pump();
    expect(find.byKey(const Key('receipt-discount')), findsNothing);
    await t.tap(find.text('Rückgängig'));
    await t.pumpAndSettle();
    expect(
      cartOf(t).lines[0].discount,
      const Discount.percent(15, DiscountReason.staff),
    );
    expect(
      cartOf(t).discount,
      const Discount.percent(5, DiscountReason.promotion),
    );
    expect(find.byKey(const Key('receipt-discount')), findsOneWidget);
    expect(_lineDiscount(t, 0), findsOneWidget);
    expect(textOf(t, const Key('cart-total')), total);

    await _tap(t, 'discount-button');
    await _tap(t, 'discount-remove');
    expect(cartOf(t).discount, isNull);
    expect(find.byKey(const Key('receipt-discount')), findsNothing);
  });

  testWidgets('Menge der Zeile ändern: der Prozent-Rabatt rechnet mit '
      '(2 × Cola mit 10 %: −0,58 €, 3 ×: −0,87 €)', (t) async {
    await openWithDiscount(t, FeatureAccess.all);
    await _openLine(t, 0);
    await t.tap(find.byKey(const Key('discount-reason-regular')));
    await _tap(t, 'discount-percent-10');
    await _tap(t, 'discount-apply');
    final row = _lineDiscount(t, 0);
    expect(
      find.descendant(of: row, matching: find.text('−0,58 €')),
      findsOneWidget,
    );
    await t.tap(find.byKey(Key('qty-plus-${cartOf(t).lines[0].lineId}')));
    await t.pumpAndSettle();
    expect(
      find.descendant(of: row, matching: find.text('−0,87 €')),
      findsOneWidget,
    );
  });

  testWidgets('derselbe Rabatt noch einmal übernommen: der Bon ändert sich '
      'nicht', (t) async {
    await openWithDiscount(t, FeatureAccess.all);
    await _tap(t, 'discount-button');
    await t.tap(find.byKey(const Key('discount-reason-regular')));
    await _tap(t, 'discount-percent-10');
    await _tap(t, 'discount-apply');
    final before = cartOf(t);
    await _tap(t, 'discount-button');
    await _tap(t, 'discount-apply');
    expect(identical(cartOf(t), before), isTrue);
    expect(find.byKey(const Key('discount-sheet')), findsNothing);
  });

  testWidgets('jede Tippfläche ist mindestens 48 dp: Bon mit Rabatt, Blatt, '
      'Zahlenfeld, Abschließen', (t) async {
    Future<void> expectTapTargets(String where) async {
      final small = <String>[];
      for (final e in find.byType(Pressable).evaluate()) {
        final box = e.renderObject! as RenderBox;
        final size = box.size;
        final shorter = size.width < size.height ? size.width : size.height;
        if (shorter < 47.99) small.add('${e.widget.key ?? e.widget} $size');
      }
      expect(small, isEmpty, reason: where);
    }

    await openWithDiscount(t, FeatureAccess.all);
    await expectTapTargets('Bon');
    final cola = cartOf(t).lines[0].lineId;
    for (final k in ['qty-minus-$cola', 'qty-plus-$cola']) {
      final size = t.getSize(find.byKey(Key(k)));
      expect(size.width, greaterThanOrEqualTo(48), reason: k);
      expect(size.height, greaterThanOrEqualTo(48), reason: k);
    }
    await _openLine(t, 0);
    await expectTapTargets('Blatt');
    await t.tap(find.byKey(const Key('discount-reason-regular')));
    await _tap(t, 'discount-percent-10');
    await _tap(t, 'discount-apply');
    await expectTapTargets('Bon mit Rabatt');
    await _tap(t, 'discount-button');
    await _tap(t, 'discount-amount');
    await expectTapTargets('Zahlenfeld');
    await _tap(t, 'discount-back');
    // Einladung auf den ganzen Bon ergibt hier wegen des Pfands nicht 0:
    // Teigtaschen allein.
    await openWithDiscount(t, FeatureAccess.all, ids: ['teigtaschen']);
    await _tap(t, 'discount-button');
    await t.tap(find.byKey(const Key('discount-reason-invitation')));
    await _tap(t, 'discount-apply');
    await expectTapTargets('Abschließen');
    expect(
      t.getSize(find.byKey(const Key('finish-free'))).height,
      greaterThanOrEqualTo(48),
    );
    expect(t.takeException(), isNull);
  });

  testWidgets('in jeder Sprache auf 960 × 600 mit Textskala 1,3: nichts läuft '
      'über, auch nicht mit Zahlenfeld, Hinweis und Abschließen', (t) async {
    for (final language in AppLanguage.values) {
      await openWithDiscount(
        t,
        FeatureAccess.all,
        size: const Size(960, 600),
        textScale: 1.3,
        language: language,
      );
      expect(t.takeException(), isNull, reason: language.name);
      await _openLine(t, 1);
      await _tap(t, 'discount-reason-complaint');
      await _tap(t, 'discount-percent-15');
      expect(t.takeException(), isNull, reason: language.name);
      await _tap(t, 'discount-amount');
      await tapKeys(t, '2 0');
      expect(t.takeException(), isNull, reason: language.name);
      await _tap(t, 'discount-apply');
      expect(_lineDiscount(t, 1), findsOneWidget);
      expect(t.takeException(), isNull, reason: language.name);
      await _tap(t, 'discount-button');
      expect(find.byKey(const Key('discount-hint')), findsOneWidget);
      await _tap(t, 'discount-reason-invitation');
      await _tap(t, 'discount-apply');
      expect(find.byKey(const Key('receipt-discount')), findsOneWidget);
      expect(t.takeException(), isNull, reason: language.name);

      await openWithDiscount(
        t,
        FeatureAccess.all,
        size: const Size(960, 600),
        textScale: 1.3,
        language: language,
        ids: ['teigtaschen'],
      );
      await _tap(t, 'discount-button');
      await _tap(t, 'discount-reason-invitation');
      await _tap(t, 'discount-apply');
      expect(find.byKey(const Key('finish-free')), findsOneWidget);
      expect(t.takeException(), isNull, reason: language.name);
    }
  });
}

/// Ein Verkaufsdienst, dessen "Abschließen" auf [hold] wartet: ein Fehler
/// dort wird geworfen, sonst speichert er wie der echte. [calls] hält die
/// Kennungen der Aufrufe.
class _HeldSaleService extends SaleService {
  _HeldSaleService(super.ref);

  static Completer<void>? hold;
  static final calls = <String>[];

  @override
  Future<SaleResult> completeFree({
    required String saleId,
    required Cart cart,
    required Staff staff,
  }) async {
    calls.add(saleId);
    final h = hold;
    if (h != null) await h.future;
    return super.completeFree(saleId: saleId, cart: cart, staff: staff);
  }
}
