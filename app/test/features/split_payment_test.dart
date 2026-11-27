// Teil bar, Rest Karte: Mit dem Schalter bietet das Blatt "Bar bezahlen"
// "Teil bar"; die Kassa tippt den Bar-Teil, der Rest geht an die Karte. Es
// entsteht ein Bon mit zwei Zahlungen.

import 'dart:async';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/core/app_language.dart';
import 'package:kassa/devices/card_terminal.dart';
import 'package:kassa/ui/primary_button.dart';
import 'package:material_ui/material_ui.dart';

import '../support/cash_pump.dart';
import '../support/fake_devices.dart';
import '../support/kassa_pump.dart';
import '../support/pump.dart';

PrimaryButton buttonOf(WidgetTester t, String key) =>
    t.widget<PrimaryButton>(find.byKey(Key(key)));

Future<void> _tap(WidgetTester t, String key) async {
  await t.ensureVisible(find.byKey(Key(key)));
  await t.tap(find.byKey(Key(key)));
  await t.pumpAndSettle();
}

/// Kassa mit "Teil bar, Rest Karte" (und mit [tip] auch Trinkgeld), Drucker
/// eingerichtet, Cola und Teigtaschen (9,65 €) auf dem Bon, "Bar" und "Teil
/// bar" getippt.
Future<void> openSplit(
  WidgetTester t, {
  bool tip = false,
  Size size = const Size(1280, 800),
  double textScale = 1.0,
  AppLanguage? language,
  List<Override>? overrides,
}) async {
  await pumpKassa(t, size: size, textScale: textScale, overrides: overrides);
  await setUpPrinter(t);
  await setSettings(
    t,
    (s) => s.copyWith(
      splitPaymentEnabled: true,
      cardTipEnabled: tip,
      language: language,
    ),
  );
  await tapItem(t, 'cola');
  await tapItem(t, 'teigtaschen');
  await t.pumpAndSettle();
  await _tap(t, 'pay-cash');
  await _tap(t, 'cash-mode-split');
}

/// Wie `tapKeys`, scrollt jede Taste vorher in Sicht (kleiner Bildschirm).
Future<void> _visibleKeys(WidgetTester t, String keys) async {
  for (final k in keys.split(' ')) {
    await t.ensureVisible(find.byKey(Key('key-$k')));
    await tapKeys(t, k);
  }
}

/// Wie [openSplit], dann 5,00 bar und "Weiter zur Karte".
Future<void> _splitFive(WidgetTester t, {bool tip = false}) async {
  await openSplit(t, tip: tip);
  await tapKeys(t, '5');
  await _tap(t, 'split-go');
}

void main() {
  testWidgets('5,00 bar, Rest 4,65 mit Karte: ein Bon mit zwei Zahlungen, die '
      'Lade geht auf', (t) async {
    await openSplit(t);
    await tapKeys(t, '5');
    await t.pump();
    expect(textOf(t, const Key('split-rest')), '4,65 €');
    expect(textOf(t, const Key('split-go')), 'Weiter zur Karte 4,65 €');
    await t.tap(find.byKey(const Key('split-go')));
    await t.pumpAndSettle();
    expect(terminalOf(t).payments.single.amountCents, 465);
    expect(
      await queryRows(
        t,
        'SELECT position, kind, amount_cents FROM payments ORDER BY position',
      ),
      [
        {'position': 0, 'kind': 'cash', 'amount_cents': 500},
        {'position': 1, 'kind': 'card', 'amount_cents': 465},
      ],
    );
    expect(await receiptCount(t), 1);
    expect(printerOf(t).log.single, startsWith('print+drawer:'));
    expect(find.byKey(const Key('cash-part-done')), findsOneWidget);
    expect(textOf(t, const Key('cash-part-done')), 'Bar-Teil 5,00 €');
    expect(find.byKey(const Key('paid-by-card')), findsOneWidget);
  });

  testWidgets('Lade ausgeschaltet: der Bon wird ohne Lade gedruckt', (t) async {
    await openSplit(t);
    await setSettings(t, (s) => s.copyWith(cashDrawerEnabled: false));
    await tapKeys(t, '5');
    await _tap(t, 'split-go');
    expect(await receiptCount(t), 1);
    expect(printerOf(t).log.single, startsWith('print:'));
  });

  testWidgets('die Taste sagt, warum sie aus ist', (t) async {
    await openSplit(t);
    expect(textOf(t, const Key('split-reason')), 'Bar-Teil eingeben.');
    expect(buttonOf(t, 'split-go').onPressed, isNull);
    await tapKeys(t, '9'); // Rest 0,65
    await t.pump();
    expect(
      textOf(t, const Key('split-reason')),
      'Rest mit Karte mindestens 1,00 €.',
    );
    expect(buttonOf(t, 'split-go').onPressed, isNull);
  });

  testWidgets('Bar-Teil gleich der Summe oder darüber: Rest 0,00 €, die Taste '
      'ist aus', (t) async {
    await openSplit(t);
    await tapKeys(t, '9 , 6 5');
    expect(textOf(t, const Key('split-rest')), '0,00 €');
    expect(
      textOf(t, const Key('split-reason')),
      'Rest mit Karte mindestens 1,00 €.',
    );
    expect(buttonOf(t, 'split-go').onPressed, isNull);
    await _tap(t, 'cash-mode-full');
    await _tap(t, 'cash-mode-split');
    for (var i = 0; i < 4; i++) {
      await tapKeys(t, 'back');
    }
    await tapKeys(t, '2 0');
    expect(textOf(t, const Key('split-rest')), '0,00 €');
    expect(textOf(t, const Key('split-go')), 'Weiter zur Karte 0,00 €');
    expect(
      textOf(t, const Key('split-reason')),
      'Rest mit Karte mindestens 1,00 €.',
    );
    expect(buttonOf(t, 'split-go').onPressed, isNull);
    await t.tap(find.byKey(const Key('split-go')));
    await t.pumpAndSettle();
    expect(terminalOf(t).payments, isEmpty);
  });

  testWidgets('Terminal abgemeldet: der Grund der Karte steht unter der '
      'Taste', (t) async {
    await openSplit(
      t,
      overrides: await memoryOverrides(
        terminal: FakeCardTerminal(
          statusValue: const CardTerminalStatus(CardTerminalState.loggedOut),
        ),
      ),
    );
    await tapKeys(t, '5');
    expect(textOf(t, const Key('split-reason')), 'nicht angemeldet');
    expect(buttonOf(t, 'split-go').onPressed, isNull);
  });

  testWidgets('Ganzer Betrag ist gewählt und das Blatt ist das heutige', (
    t,
  ) async {
    await openSplit(t);
    await _tap(t, 'cash-mode-full');
    expect(find.byKey(const Key('split-rest')), findsNothing);
    expect(find.byKey(const Key('split-go')), findsNothing);
    expect(find.byKey(const Key('given-965')), findsOneWidget);
    expect(find.byKey(const Key('finish-sale')), findsOneWidget);
  });

  testWidgets('Karte abgelehnt: nichts gespeichert, der Hinweis nennt den '
      'Bar-Teil und bleibt stehen', (t) async {
    await openSplit(t);
    terminalOf(t).next = const CardFailed(CardFailure.declined);
    await tapKeys(t, '5');
    await _tap(t, 'split-go');
    expect(await receiptCount(t), 0);
    expect(await queryRows(t, 'SELECT id FROM pending_card_payments'), isEmpty);
    expect(
      textOf(t, const Key('split-card-failed')),
      contains('5,00 € bar zurückgeben'),
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('split-card-failed')),
        matching: find.text('Die Kartenzahlung wurde nicht abgeschlossen.'),
      ),
      findsOneWidget,
    );
    await t.pump(const Duration(seconds: 30));
    expect(find.byKey(const Key('split-card-failed')), findsOneWidget);
    expect(cartOf(t).totalCents, 965);
  });

  testWidgets('danach alles bar: ein Bon, eine Bar-Zahlung über 9,65, der '
      'Hinweis ist weg', (t) async {
    await openSplit(t);
    terminalOf(t).next = const CardFailed(CardFailure.declined);
    await tapKeys(t, '5');
    await _tap(t, 'split-go');
    expect(find.byKey(const Key('split-card-failed')), findsOneWidget);
    await _tap(t, 'pay-cash');
    await _tap(t, 'finish-sale');
    expect(find.byKey(const Key('split-card-failed')), findsNothing);
    expect(await queryRows(t, 'SELECT kind, amount_cents FROM payments'), [
      {'kind': 'cash', 'amount_cents': 965},
    ]);
    expect(await receiptCount(t), 1);
  });

  testWidgets('der Hinweis geht weg, sobald sich der Bon ändert', (t) async {
    await openSplit(t);
    terminalOf(t).next = const CardFailed(CardFailure.declined);
    await tapKeys(t, '5');
    await _tap(t, 'split-go');
    expect(find.byKey(const Key('split-card-failed')), findsOneWidget);
    await tapItem(t, 'cola');
    await t.pumpAndSettle();
    expect(find.byKey(const Key('split-card-failed')), findsNothing);
  });

  testWidgets('mit Trinkgeld: das Blatt "Gast zahlt" rechnet vom Rest, das '
      'Terminal bucht Rest plus Trinkgeld', (t) async {
    await _splitFive(t, tip: true);
    expect(find.byKey(const Key('tip-sheet')), findsOneWidget);
    expect(terminalOf(t).payments, isEmpty);
    expect(textOf(t, const Key('tip-due')), '4,65 €');
    await t.tap(find.byKey(const Key('tip-pays-500')));
    await t.pump();
    await _tap(t, 'tip-go');
    expect(terminalOf(t).payments.single.amountCents, 500);
    expect(
      await queryRows(
        t,
        "SELECT amount_cents, tip_cents FROM payments WHERE kind = 'card'",
      ),
      [
        {'amount_cents': 465, 'tip_cents': 35},
      ],
    );
    expect(textOf(t, const Key('cash-part-done')), 'Bar-Teil 5,00 €');
    expect(textOf(t, const Key('tip-done')), 'davon Trinkgeld 0,35 €');
  });

  testWidgets('die offene Zahlung trägt den Bar-Teil, bevor das Terminal '
      'antwortet; das Warten zeigt den Rest', (t) async {
    await openSplit(t);
    final hang = terminalOf(t).hang = Completer<CardPaymentResult>();
    await tapKeys(t, '5');
    await t.tap(find.byKey(const Key('split-go')));
    await t.pump();
    await t.pump();
    expect(textOf(t, const Key('card-wait-amount')), '4,65 €');
    expect(
      await queryRows(
        t,
        'SELECT amount_cents, tip_cents, cash_part_cents '
        'FROM pending_card_payments',
      ),
      [
        {'amount_cents': 465, 'tip_cents': 0, 'cash_part_cents': 500},
      ],
    );
    hang.complete(const CardPaid(txCode: 'TX1'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('cash-part-done')), findsOneWidget);
  });

  testWidgets('Tasten des Blatts sind mindestens 48 dp hoch', (t) async {
    await openSplit(t);
    await tapKeys(t, '5');
    for (final k in ['cash-mode-full', 'cash-mode-split', 'split-go']) {
      expect(
        t.getSize(find.byKey(Key(k))).height,
        greaterThanOrEqualTo(48),
        reason: k,
      );
    }
    expect(t.takeException(), isNull);
  });

  testWidgets('in jeder Sprache auf 960 × 600 mit Textskala 1,3: nichts läuft '
      'über, auch nicht mit Grund und Hinweis', (t) async {
    for (final language in AppLanguage.values) {
      await openSplit(
        t,
        size: const Size(960, 600),
        textScale: 1.3,
        language: language,
      );
      expect(find.byKey(const Key('split-reason')), findsOneWidget);
      expect(t.takeException(), isNull, reason: language.name);
      await _visibleKeys(t, '9');
      expect(textOf(t, const Key('split-rest')), '0,65 €');
      expect(t.takeException(), isNull, reason: language.name);
      await _visibleKeys(t, 'back 5');
      expect(textOf(t, const Key('split-rest')), '4,65 €');
      terminalOf(t).next = const CardFailed(CardFailure.declined);
      await _tap(t, 'split-go');
      expect(find.byKey(const Key('split-card-failed')), findsOneWidget);
      expect(t.takeException(), isNull, reason: language.name);
    }
  });
}
