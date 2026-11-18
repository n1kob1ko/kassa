import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/app.dart';
import 'package:kassa/devices/printer.dart';
import 'package:material_ui/material_ui.dart';

import '../support/cash_pump.dart';
import '../support/pump.dart';

// Bildvergleich des Bezahlens gegen den freigegebenen Entwurf. Neu erzeugen
// mit `flutter test --update-goldens test/golden/cash_golden_test.dart`.

void main() {
  testWidgets('Bezahlen mit "Anderer Betrag" (hell)', (t) async {
    await openCash(t, ['cola', 'teigtaschen', 'teigtaschen']);
    await t.tap(find.byKey(const Key('other-amount')));
    await t.pump();
    await tapKeys(t, '2 0');
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await expectLater(
      find.byType(KassaApp),
      matchesGoldenFile('goldens/bar_eigener_betrag_hell.png'),
    );
  });

  testWidgets('Bezahlt (hell)', (t) async {
    await openCash(t, ['cola']);
    await t.tap(find.byKey(const Key('given-500')));
    await t.tap(find.byKey(const Key('finish-sale')));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await expectLater(
      find.byType(KassaApp),
      matchesGoldenFile('goldens/bezahlt_hell.png'),
    );
  });

  testWidgets('Bezahlt mit gedrucktem Bon (hell)', (t) async {
    await openCash(t, ['cola'], withPrinter: true);
    await t.tap(find.byKey(const Key('given-500')));
    await t.tap(find.byKey(const Key('finish-sale')));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await expectLater(
      find.byType(KassaApp),
      matchesGoldenFile('goldens/bezahlt_gedruckt_hell.png'),
    );
  });

  for (final dark in [false, true]) {
    testWidgets('Bezahlt, Drucker nicht bereit (${dark ? 'dunkel' : 'hell'})', (
      t,
    ) async {
      await openCash(
        t,
        ['cola'],
        withPrinter: true,
        brightness: dark ? Brightness.dark : Brightness.light,
      );
      printerOf(t).next = const PrintOutcome.failed(PrintProblem.paperOut);
      await t.tap(find.byKey(const Key('given-500')));
      await t.tap(find.byKey(const Key('finish-sale')));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await expectLater(
        find.byType(KassaApp),
        matchesGoldenFile(
          'goldens/bezahlt_drucker_nicht_bereit_${dark ? 'dunkel' : 'hell'}.png',
        ),
      );
    });
  }
}
