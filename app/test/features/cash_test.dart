import 'dart:async';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/data/receipt_repository.dart';
import 'package:kassa/data/settings_repository.dart';
import 'package:kassa/devices/printer.dart';
import 'package:kassa/domain/cart.dart';
import 'package:kassa/domain/receipt.dart';
import 'package:kassa/domain/staff.dart';
import 'package:kassa/features/kassa/cart_controller.dart';
import 'package:kassa/ui/primary_button.dart';
import 'package:material_ui/material_ui.dart';

import '../support/demo_fixtures.dart';
import '../support/cash_pump.dart';
import '../support/kassa_pump.dart';
import '../support/pump.dart';

const _failText = 'Der Bon konnte nicht gespeichert werden. Bitte noch einmal.';

Future<void> _finish(WidgetTester t) async {
  await t.tap(find.byKey(const Key('finish-sale')));
  await t.pumpAndSettle();
}

PrimaryButton _finishButton(WidgetTester t) =>
    t.widget<PrimaryButton>(find.byKey(const Key('finish-sale')));

/// Wie der erste Versuch ausgeht.
enum _Fail { none, before, afterStoring }

/// Ein Speicher, der jede `saleId` aufschreibt und den ersten Versuch auf
/// Wunsch scheitern lässt: vor dem Speichern oder erst danach (der Bon ist
/// gespeichert, die Antwort geht verloren).
class _FlakyReceipts extends ReceiptRepository {
  _FlakyReceipts(super.db, super.clock, super.days, this.mode);

  final _Fail mode;

  final List<String> ids = [];

  int get calls => ids.length;

  @override
  Future<Receipt> finalizeCashSale({
    required String saleId,
    required Cart cart,
    required int givenCents,
    required Staff staff,
  }) async {
    ids.add(saleId);
    final first = ids.length == 1;
    if (first && mode == _Fail.before) throw StateError('Platte voll');
    final receipt = await super.finalizeCashSale(
      saleId: saleId,
      cart: cart,
      givenCents: givenCents,
      staff: staff,
    );
    if (first && mode == _Fail.afterStoring) throw StateError('Antwort weg');
    return receipt;
  }
}

/// Überschreibt den Bon-Speicher; [made] erhält den erzeugten.
Future<List<Override>> _overridesWith(
  _Fail mode,
  void Function(_FlakyReceipts) made,
) async => [
  ...await memoryOverrides(),
  receiptRepositoryProvider.overrideWith((ref) {
    final r = _FlakyReceipts(
      ref.watch(databaseProvider),
      ref.watch(clockProvider),
      ref.watch(dayRepositoryProvider),
      mode,
    );
    made(r);
    return r;
  }),
];

void main() {
  testWidgets('passend ist vorgewählt, Vorschlag zeigt Rückgeld', (t) async {
    await openCash(t, ['cola', 'teigtaschen', 'teigtaschen']); // 16,15 €
    expect(find.byKey(const Key('given-1615')), findsOneWidget);
    expect(find.text('Passend'), findsOneWidget);
    expect(textOf(t, const Key('change')), '0,00 €');
    await t.tap(find.byKey(const Key('given-2000')));
    await t.pump();
    expect(textOf(t, const Key('change')), '3,85 €');
    expect(find.text('Rückgeld'), findsOneWidget);
  });

  testWidgets(
    'anderer Betrag: zu wenig sperrt Abschließen und zeigt "Fehlt noch"',
    (t) async {
      await openCash(t, ['cola', 'teigtaschen', 'teigtaschen']);
      await t.tap(find.byKey(const Key('other-amount')));
      await t.pump();
      await tapKeys(t, '1 0');
      expect(find.text('Fehlt noch'), findsOneWidget);
      expect(textOf(t, const Key('change')), '6,15 €');
      expect(_finishButton(t).onPressed, isNull);
      await tapKeys(t, 'back back 1 7 , 5');
      expect(find.text('Rückgeld'), findsOneWidget);
      expect(textOf(t, const Key('change')), '1,35 €');
      expect(_finishButton(t).onPressed, isNotNull);
    },
  );

  testWidgets('ein Vorschlag nimmt das Zahlenfeld wieder weg', (t) async {
    await openCash(t, ['cola']);
    await t.tap(find.byKey(const Key('other-amount')));
    await t.pump();
    expect(find.byKey(const Key('key-1')), findsOneWidget);
    await tapKeys(t, '1 0');
    expect(textOf(t, const Key('change')), '6,85 €');
    await t.tap(find.byKey(const Key('show-suggestions')));
    await t.pump();
    expect(find.byKey(const Key('key-1')), findsNothing);
    await t.tap(find.byKey(const Key('given-500')));
    await t.pump();
    expect(textOf(t, const Key('change')), '1,85 €');
  });

  testWidgets('mit Drucker heißt die Taste "Abschließen und Bon drucken", ohne '
      '"Abschließen"', (t) async {
    await openCash(t, ['cola']);
    expect(_finishButton(t).label, 'Abschließen');
    await t.tap(find.byKey(const Key('cash-back')));
    await t.pumpAndSettle();
    await setUpPrinter(t);
    await t.tap(find.byKey(const Key('pay-cash')));
    await t.pumpAndSettle();
    expect(_finishButton(t).label, 'Abschließen und Bon drucken');
  });

  testWidgets('ohne Drucker gibt es keine Druckzeile', (t) async {
    await openCash(t, ['cola']);
    await _finish(t);
    expect(find.byKey(const Key('print-state')), findsNothing);
    expect(find.byKey(const Key('reprint')), findsNothing);
    expect(printerOf(t).log, isEmpty);
  });

  testWidgets('Fertig-Ansicht: "Bon gedruckt"', (t) async {
    await openCash(t, ['cola'], withPrinter: true);
    await _finish(t);
    expect(textOf(t, const Key('print-state')), 'Bon gedruckt');
    expect(find.byKey(const Key('reprint')), findsNothing);
    expect(printerOf(t).log, [startsWith('print+drawer:')]);
  });

  testWidgets('Drucker hängt: "Bon wird gedruckt …", Nächster Kunde sofort', (
    t,
  ) async {
    await openCash(t, ['cola'], withPrinter: true);
    printerOf(t).hold = Completer<void>();
    await _finish(t);
    expect(textOf(t, const Key('print-state')), 'Bon wird gedruckt …');
    await t.tap(find.byKey(const Key('next-customer')));
    await t.pump();
    expect(textOf(t, const Key('cart-total')), '0,00 €');
    printerOf(t).hold!.complete();
    await t.pumpAndSettle();
  });

  testWidgets(
    'Drucker nicht bereit: Meldung, Nochmal drucken druckt erneut, Nächster '
    'Kunde geht sofort',
    (t) async {
      await openCash(t, ['cola'], withPrinter: true);
      printerOf(t).next = const PrintOutcome.failed(PrintProblem.paperOut);
      await _finish(t);
      expect(
        textOf(t, const Key('print-state')),
        'Drucker nicht bereit. Das Papier ist leer.',
      );
      expect(
        t.getSize(find.byKey(const Key('reprint'))).height,
        greaterThanOrEqualTo(64),
      );
      expect(
        t
            .widget<PrimaryButton>(find.byKey(const Key('next-customer')))
            .onPressed,
        isNotNull,
      );
      printerOf(t).next = const PrintOutcome.ok();
      await t.tap(find.byKey(const Key('reprint')));
      await t.pumpAndSettle();
      expect(textOf(t, const Key('print-state')), 'Bon gedruckt');
      expect(printerOf(t).printed, hasLength(2));
      expect(printerOf(t).printed.toSet(), hasLength(1)); // derselbe Bon
    },
  );

  testWidgets('Lade ging nicht auf: "Nochmal drucken" öffnet sie mit dem '
      'Bon, danach nicht mehr', (t) async {
    await openCash(t, ['cola'], withPrinter: true);
    printerOf(t).next = const PrintOutcome.failed(PrintProblem.timeout);
    await _finish(t);
    expect(
      textOf(t, const Key('print-state')),
      'Drucker nicht bereit. Er antwortet nicht.',
    );
    printerOf(t).next = const PrintOutcome.failed(PrintProblem.paperOut);
    printerOf(t).kickGoesOut = true;
    await t.tap(find.byKey(const Key('reprint')));
    await t.pumpAndSettle();
    printerOf(t)
      ..next = const PrintOutcome.ok()
      ..kickGoesOut = null;
    await t.tap(find.byKey(const Key('reprint')));
    await t.pumpAndSettle();
    expect(textOf(t, const Key('print-state')), 'Bon gedruckt');
    final log = printerOf(t).log;
    expect(log, hasLength(3));
    expect(log[0], startsWith('print+drawer:'));
    expect(log[1], startsWith('print+drawer:')); // die Lade fehlte noch
    expect(log[2], startsWith('print:')); // die Lade ist schon aufgegangen
  });

  testWidgets('Abschließen löscht den Entwurf in der Datenbank', (t) async {
    await openCash(t, ['cola']);
    await t.pumpAndSettle();
    expect(await draftOf(t), isNotNull);
    await _finish(t);
    expect(await draftOf(t), isNull);
  });

  testWidgets(
    'Abschließen speichert den Bon, leert den Bon und zeigt das Rückgeld',
    (t) async {
      await openCash(t, ['cola']);
      await t.tap(find.byKey(const Key('given-500')));
      await t.tap(find.byKey(const Key('finish-sale')));
      await t.pumpAndSettle();
      expect(find.text('Bon Nr. 1'), findsOneWidget);
      expect(find.text('Bezahlt'), findsOneWidget);
      expect(find.text('Rückgeld aus der Lade geben'), findsOneWidget);
      expect(textOf(t, const Key('change-done')), '1,85 €');
      expect(cartOf(t).isEmpty, isTrue);
      await t.tap(find.byKey(const Key('next-customer')));
      await t.pump();
      expect(textOf(t, const Key('cart-total')), '0,00 €');
      expect(find.byKey(const Key('finish-sale')), findsNothing);
    },
  );

  testWidgets('zwei schnelle Tipps auf Abschließen ergeben einen Bon', (
    t,
  ) async {
    late _FlakyReceipts counting;
    await pumpKassa(
      t,
      overrides: await _overridesWith(_Fail.none, (r) => counting = r),
    );
    await tapItem(t, 'cola');
    await t.tap(find.byKey(const Key('pay-cash')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('finish-sale')));
    await t.tap(
      find.byKey(const Key('finish-sale'), skipOffstage: false),
      warnIfMissed: false,
    );
    await t.pumpAndSettle();
    expect(await receiptCount(t), 1);
    expect(counting.calls, 1);
  });

  testWidgets('Summe 0,00 € lässt sich abschließen', (t) async {
    await openCash(t, ['leitungswasser']);
    expect(textOf(t, const Key('change')), '0,00 €');
    expect(_finishButton(t).onPressed, isNotNull);
    await _finish(t);
    expect(find.text('Bon Nr. 1'), findsOneWidget);
    expect(find.text('Passend bezahlt'), findsOneWidget);
  });

  testWidgets('Summe über 9.999,99 €: der Betrag lässt sich eintippen', (
    t,
  ) async {
    await pumpKassa(t);
    final ctl = containerOf(t).read(cartProvider.notifier);
    ctl.add(cola.copyWith(priceCents: 15000, depositCents: 0));
    ctl.setQuantity(cartOf(t).lines.single.lineId, 99);
    await t.pump();
    expect(cartOf(t).totalCents, 1485000);
    await t.tap(find.byKey(const Key('pay-cash')));
    await t.pumpAndSettle();
    expect(textOf(t, const Key('change')), '0,00 €');
    await t.tap(find.byKey(const Key('other-amount')));
    await t.pump();
    await tapKeys(t, '1 4 8 0 0');
    expect(find.text('Fehlt noch'), findsOneWidget);
    expect(_finishButton(t).onPressed, isNull);
    await tapKeys(t, 'back back back back back 1 5 0 0 0');
    expect(textOf(t, const Key('change')), '150,00 €');
    expect(_finishButton(t).onPressed, isNotNull);
    await _finish(t);
    expect(textOf(t, const Key('change-done')), '150,00 €');
  });

  testWidgets('Zurück lässt den Bon unverändert und speichert nichts', (
    t,
  ) async {
    await openCash(t, ['cola', 'teigtaschen']);
    final before = cartOf(t).totalCents;
    await t.tap(find.byKey(const Key('cash-back')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('finish-sale')), findsNothing);
    expect(cartOf(t).totalCents, before);
    expect(cartOf(t).lines.length, 2);
    expect(await receiptCount(t), 0);
    expect(find.byKey(const Key('pay-cash')), findsOneWidget);
  });

  testWidgets('die Artikelfläche reagiert nicht, solange bezahlt wird', (
    t,
  ) async {
    await openCash(t, ['cola']);
    final opacity = t.widget<AnimatedOpacity>(
      find.byKey(const Key('item-area-dim')),
    );
    expect(opacity.opacity, 0.5);
    await t.tap(find.byKey(const Key('item-cola')), warnIfMissed: false);
    await t.pump();
    expect(cartOf(t).lines.single.quantity, 1);
    await t.tap(find.byKey(const Key('cash-back')));
    await t.pumpAndSettle();
    expect(
      t.widget<AnimatedOpacity>(find.byKey(const Key('item-area-dim'))).opacity,
      1.0,
    );
    await t.tap(find.byKey(const Key('item-cola')));
    await t.pump();
    expect(cartOf(t).lines.single.quantity, 2);
  });

  testWidgets('ohne Geldlade heißt es "Rückgeld geben"', (t) async {
    await openCash(t, ['cola']);
    await containerOf(t)
        .read(settingsRepositoryProvider)
        .save(const RegisterSettings(cashDrawerEnabled: false));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('given-500')));
    await _finish(t);
    expect(find.text('Rückgeld geben'), findsOneWidget);
    expect(find.text('Rückgeld aus der Lade geben'), findsNothing);
    expect(textOf(t, const Key('change-done')), '1,85 €');
  });

  testWidgets('ohne Rückgeld steht "Passend bezahlt" und kein Betrag', (
    t,
  ) async {
    await openCash(t, ['cola']);
    await _finish(t);
    expect(find.text('Passend bezahlt'), findsOneWidget);
    expect(find.byKey(const Key('change-done')), findsNothing);
    expect(find.text('Rückgeld geben'), findsNothing);
    expect(find.text('Rückgeld aus der Lade geben'), findsNothing);
  });

  testWidgets('der Bon trägt Mitarbeiterin, gegebenen Betrag und Rückgeld', (
    t,
  ) async {
    await openCash(t, ['cola']);
    await t.tap(find.byKey(const Key('given-500')));
    await _finish(t);
    final id =
        (await queryRows(t, 'SELECT id FROM receipts')).single['id']! as String;
    final r = await containerOf(t).read(receiptRepositoryProvider).byId(id);
    expect(r.staffName, 'Anna');
    expect(r.number, 1);
    expect(r.totalCents, 315);
    expect(r.payment!.givenCents, 500);
    expect(r.payment!.changeCents, 185);
    expect(r.lines.single.itemId, 'cola');
  });

  testWidgets(
    'nach "Nächster Kunde" bekommt der nächste Verkauf Nummer 2 und eine neue Id',
    (t) async {
      await openCash(t, ['cola']);
      await _finish(t);
      await t.tap(find.byKey(const Key('next-customer')));
      await t.pump();
      await tapItem(t, 'cola');
      await t.tap(find.byKey(const Key('pay-cash')));
      await t.pumpAndSettle();
      await _finish(t);
      expect(find.text('Bon Nr. 2'), findsOneWidget);
      final rows = await queryRows(
        t,
        'SELECT id, number FROM receipts ORDER BY number',
      );
      expect(rows.map((r) => r['number']), [1, 2]);
      expect(rows[0]['id'], isNot(rows[1]['id']));
    },
  );

  testWidgets('nach dem Verkauf ist der Entwurf gelöscht', (t) async {
    await openCash(t, ['cola']);
    expect(await draftOf(t), isNotNull);
    await _finish(t);
    expect(await draftOf(t), isNull);
    await pumpKassa(t, sameDatabase: true);
    expect(cartOf(t).isEmpty, isTrue);
    expect(textOf(t, const Key('cart-total')), '0,00 €');
  });

  testWidgets('bei geschlossener App mit offenem Bezahlen bleibt der Entwurf', (
    t,
  ) async {
    await openCash(t, ['cola']);
    await pumpKassa(t, sameDatabase: true);
    expect(cartOf(t).lines.single.item.id, 'cola');
    expect(await receiptCount(t), 0);
  });

  testWidgets(
    'Speichern scheitert: Meldung, Bon bleibt, zweiter Tipp ergibt einen Bon',
    (t) async {
      late _FlakyReceipts flaky;
      final overrides = await _overridesWith(_Fail.before, (r) => flaky = r);
      await pumpKassa(t, overrides: overrides);
      await tapItem(t, 'cola');
      await t.tap(find.byKey(const Key('pay-cash')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('finish-sale')));
      await t.pumpAndSettle();
      expect(find.text(_failText), findsOneWidget);
      expect(find.byKey(const Key('finish-sale')), findsOneWidget);
      expect(_finishButton(t).onPressed, isNotNull);
      expect(cartOf(t).lines.length, 1);
      expect(await receiptCount(t), 0);
      await t.tap(find.byKey(const Key('finish-sale')));
      await t.pumpAndSettle();
      expect(find.text(_failText), findsNothing);
      expect(find.text('Bon Nr. 1'), findsOneWidget);
      expect(flaky.calls, 2);
      expect(flaky.ids[0], flaky.ids[1]);
      expect(await receiptCount(t), 1);
    },
  );

  testWidgets(
    'Antwort geht verloren, der Bon ist gespeichert: zweiter Tipp ergibt Bon Nr. 1 und eine Zeile',
    (t) async {
      late _FlakyReceipts flaky;
      final overrides = await _overridesWith(
        _Fail.afterStoring,
        (r) => flaky = r,
      );
      await pumpKassa(t, overrides: overrides);
      await tapItem(t, 'cola');
      await t.tap(find.byKey(const Key('pay-cash')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('finish-sale')));
      await t.pumpAndSettle();
      expect(find.text(_failText), findsOneWidget);
      expect(await receiptCount(t), 1);
      expect(cartOf(t).lines.length, 1);
      await t.tap(find.byKey(const Key('finish-sale')));
      await t.pumpAndSettle();
      expect(find.text('Bon Nr. 1'), findsOneWidget);
      expect(find.text(_failText), findsNothing);
      expect(flaky.ids[0], flaky.ids[1]);
      expect(await receiptCount(t), 1);
      expect(cartOf(t).isEmpty, isTrue);
    },
  );

  testWidgets('nach "Zurück" bekommt das erneute Öffnen eine neue saleId', (
    t,
  ) async {
    late _FlakyReceipts flaky;
    final overrides = await _overridesWith(_Fail.before, (r) => flaky = r);
    await pumpKassa(t, overrides: overrides);
    await tapItem(t, 'cola');
    await t.tap(find.byKey(const Key('pay-cash')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('finish-sale'))); // scheitert
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('cash-back')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('pay-cash')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('finish-sale')));
    await t.pumpAndSettle();
    expect(find.text('Bon Nr. 1'), findsOneWidget);
    expect(flaky.calls, 2);
    expect(flaky.ids[0], isNot(flaky.ids[1]));
    expect(await receiptCount(t), 1);
  });

  for (final (name, finish) in [
    ('Bezahlen', false),
    ('Fertig-Ansicht', true),
  ]) {
    testWidgets('$name läuft bei 960 x 600 mit Textskala 1,3 ohne Überlauf', (
      t,
    ) async {
      await openCash(
        t,
        ['cola', 'teigtaschen', 'teigtaschen'],
        size: const Size(960, 600),
        textScale: 1.3,
      );
      await t.tap(find.byKey(const Key('other-amount')));
      await t.pump();
      await tapKeys(t, '2 0');
      expect(t.takeException(), isNull);
      if (finish) {
        await _finish(t);
        expect(find.text('Bon Nr. 1'), findsOneWidget);
      }
      expect(t.takeException(), isNull);
    });
  }
}
