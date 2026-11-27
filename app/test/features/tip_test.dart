// Trinkgeld bei Kartenzahlung: Mit dem Schalter zeigt "Karte" zuerst das
// Blatt "Trinkgeld"; das Terminal bucht, was der Gast zahlt, der Bon trägt
// das Trinkgeld für die Person, die kassiert.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/core/app_language.dart';
import 'package:kassa/devices/card_terminal.dart';
import 'package:kassa/ui/primary_button.dart';
import 'package:material_ui/material_ui.dart';

import '../support/cash_pump.dart';
import '../support/kassa_pump.dart';
import '../support/pump.dart';

PrimaryButton buttonOf(WidgetTester t, String key) =>
    t.widget<PrimaryButton>(find.byKey(Key(key)));

/// Kassa mit eingeschaltetem Trinkgeld, Anna angemeldet, Cola und
/// Teigtaschen (9,65 €) auf dem Bon.
Future<void> openWithTip(WidgetTester t) async {
  await pumpKassa(t);
  await setSettings(t, (s) => s.copyWith(cardTipEnabled: true));
  await tapItem(t, 'cola');
  await tapItem(t, 'teigtaschen');
  await t.pumpAndSettle();
}

Future<void> _tap(WidgetTester t, String key) async {
  await t.ensureVisible(find.byKey(Key(key)));
  await t.tap(find.byKey(Key(key)));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('Gast zahlt 10,00: Terminal bucht 10,00, der Bon trägt 0,35 '
      'Trinkgeld für Anna', (t) async {
    await openWithTip(t);
    await t.tap(find.byKey(const Key('pay-card')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('tip-sheet')), findsOneWidget);
    expect(terminalOf(t).payments, isEmpty);
    expect(textOf(t, const Key('tip-due')), '9,65 €');
    await t.tap(find.byKey(const Key('tip-pays-1000')));
    await t.pump();
    expect(textOf(t, const Key('tip-amount')), '0,35 €');
    expect(textOf(t, const Key('tip-go')), 'Zum Terminal 10,00 €');
    await t.tap(find.byKey(const Key('tip-go')));
    await t.pumpAndSettle();
    expect(terminalOf(t).payments.single.amountCents, 1000);
    expect(
      await queryRows(
        t,
        'SELECT amount_cents, tip_cents, tip_staff_name FROM payments',
      ),
      [
        {'amount_cents': 965, 'tip_cents': 35, 'tip_staff_name': 'Anna'},
      ],
    );
    expect(await queryRows(t, 'SELECT total_cents, tip_cents FROM receipts'), [
      {'total_cents': 965, 'tip_cents': 35},
    ]);
    expect(find.byKey(const Key('tip-done')), findsOneWidget);
    expect(textOf(t, const Key('tip-done')), 'davon Trinkgeld 0,35 €');
  });

  testWidgets('"Ohne Trinkgeld" ist ein Tipp und bucht die Summe', (t) async {
    await openWithTip(t);
    await _tap(t, 'pay-card');
    await _tap(t, 'tip-none');
    expect(terminalOf(t).payments.single.amountCents, 965);
    expect(await queryRows(t, 'SELECT amount_cents, tip_cents FROM payments'), [
      {'amount_cents': 965, 'tip_cents': 0},
    ]);
    expect(find.byKey(const Key('tip-done')), findsNothing);
  });

  testWidgets('nichts gewählt: "Zum Terminal" ist aus', (t) async {
    await openWithTip(t);
    await _tap(t, 'pay-card');
    expect(buttonOf(t, 'tip-go').onPressed, isNull);
  });

  testWidgets('Anderer Betrag unter der Summe: "Zum Terminal" ist aus', (
    t,
  ) async {
    await openWithTip(t);
    await _tap(t, 'pay-card');
    await _tap(t, 'tip-other');
    await tapKeys(t, '9');
    expect(buttonOf(t, 'tip-go').onPressed, isNull);
    expect(find.text('Der Betrag ist kleiner als die Summe.'), findsOneWidget);
    await t.tap(find.byKey(const Key('tip-go')));
    await t.pumpAndSettle();
    expect(terminalOf(t).payments, isEmpty);
  });

  testWidgets('Anderer Betrag 12,00: Terminal bucht 12,00', (t) async {
    await openWithTip(t);
    await _tap(t, 'pay-card');
    await _tap(t, 'tip-other');
    await tapKeys(t, '1 2');
    expect(textOf(t, const Key('tip-amount')), '2,35 €');
    await _tap(t, 'tip-go');
    expect(terminalOf(t).payments.single.amountCents, 1200);
  });

  testWidgets('Vertippt (100,00 statt 10,00): die Kassa fragt einmal nach', (
    t,
  ) async {
    await openWithTip(t);
    await _tap(t, 'pay-card');
    await _tap(t, 'tip-other');
    await tapKeys(t, '1 0 0');
    await _tap(t, 'tip-go');
    expect(textOf(t, const Key('tip-confirm')), 'Trinkgeld 90,35 €?');
    expect(terminalOf(t).payments, isEmpty);
    await _tap(t, 'tip-confirm-no');
    expect(find.byKey(const Key('tip-confirm')), findsNothing);
    expect(terminalOf(t).payments, isEmpty);
    // Nochmal, diesmal stimmt es.
    await _tap(t, 'tip-go');
    await _tap(t, 'tip-confirm-yes');
    expect(terminalOf(t).payments.single.amountCents, 10000);
  });

  testWidgets('zurück führt zum Bon, nichts gebucht', (t) async {
    await openWithTip(t);
    await _tap(t, 'pay-card');
    await _tap(t, 'tip-back');
    expect(find.byKey(const Key('tip-sheet')), findsNothing);
    expect(find.byKey(const Key('pay-card')), findsOneWidget);
    expect(cartOf(t).totalCents, 965);
    expect(terminalOf(t).payments, isEmpty);
  });

  testWidgets('die offene Zahlung trägt das Trinkgeld, bevor das Terminal '
      'antwortet', (t) async {
    await openWithTip(t);
    final hang = terminalOf(t).hang = Completer<CardPaymentResult>();
    await _tap(t, 'pay-card');
    await t.tap(find.byKey(const Key('tip-pays-1000')));
    await t.pump();
    await t.tap(find.byKey(const Key('tip-go')));
    await t.pump();
    await t.pump();
    expect(textOf(t, const Key('card-wait-amount')), '10,00 €');
    expect(
      await queryRows(
        t,
        'SELECT amount_cents, tip_cents, cash_part_cents '
        'FROM pending_card_payments',
      ),
      [
        {'amount_cents': 1000, 'tip_cents': 35, 'cash_part_cents': 0},
      ],
    );
    hang.complete(const CardPaid(txCode: 'TX1'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('tip-done')), findsOneWidget);
  });

  testWidgets('Tasten des Blatts sind mindestens 48 dp hoch, die Vorschläge '
      'stehen in einer Reihe', (t) async {
    await pumpKassa(t);
    await setSettings(t, (s) => s.copyWith(cardTipEnabled: true));
    // Mehr als ein Vorschlag.
    for (final id in ['teigtaschen', 'teigtaschen', 'teigtaschen', 'cola']) {
      await tapItem(t, id);
    }
    await t.pumpAndSettle();
    await _tap(t, 'pay-card');
    final due = cartOf(t).totalCents;
    final keys = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('tip-pays-'),
    );
    expect(keys, findsAtLeast(2));
    final tops = {
      for (final e in keys.evaluate()) t.getTopLeft(find.byWidget(e.widget)).dy,
    };
    expect(tops, hasLength(1), reason: 'Summe $due');
    for (final e in keys.evaluate()) {
      expect(
        t.getSize(find.byWidget(e.widget)).height,
        greaterThanOrEqualTo(48),
      );
    }
    for (final k in ['tip-other', 'tip-none', 'tip-go', 'tip-back']) {
      expect(
        t.getSize(find.byKey(Key(k))).height,
        greaterThanOrEqualTo(48),
        reason: k,
      );
    }
    expect(t.takeException(), isNull);
  });

  testWidgets('auf 1024 × 600: der Grund für das ausgeschaltete "Zum '
      'Terminal" steht ganz sichtbar bei den Tasten', (t) async {
    const screen = Size(1024, 600);
    await pumpKassa(t, size: screen);
    await setSettings(t, (s) => s.copyWith(cardTipEnabled: true));
    await tapItem(t, 'cola');
    await tapItem(t, 'teigtaschen');
    await t.pumpAndSettle();
    await _tap(t, 'pay-card');
    await _tap(t, 'tip-other');
    await tapKeys(t, '9');
    await t.pumpAndSettle();
    expect(buttonOf(t, 'tip-go').onPressed, isNull);
    final reason = t.getRect(find.byKey(const Key('tip-too-low')));
    expect(
      (Offset.zero & screen).intersect(reason),
      reason,
      reason: 'ganz im Bild',
    );
    for (final k in ['tip-none', 'tip-go']) {
      final button = t.getRect(find.byKey(Key(k)));
      expect(button.overlaps(reason), isFalse, reason: k);
    }
    // Nichts deckt die Zeile zu: ein Tipp auf ihre Mitte trifft sie selbst.
    expect(find.byKey(const Key('tip-too-low')).hitTestable(), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('in jeder Sprache auf 960 × 600 mit Textskala 1,3: nichts läuft '
      'über, auch nicht mit Zahlenfeld und Nachfrage', (t) async {
    for (final language in AppLanguage.values) {
      await pumpKassa(t, size: const Size(960, 600), textScale: 1.3);
      await setSettings(
        t,
        (s) => s.copyWith(cardTipEnabled: true, language: language),
      );
      await tapItem(t, 'cola');
      await tapItem(t, 'teigtaschen');
      await t.pumpAndSettle();
      await _tap(t, 'pay-card');
      expect(t.takeException(), isNull, reason: language.name);
      await _tap(t, 'tip-other');
      await tapKeys(t, '1 0 0');
      await _tap(t, 'tip-go');
      expect(find.byKey(const Key('tip-confirm')), findsOneWidget);
      expect(t.takeException(), isNull, reason: language.name);
    }
  });
}
