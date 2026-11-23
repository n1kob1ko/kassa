import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/app.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/devices/printer.dart';
import 'package:kassa/domain/day.dart';
import 'package:kassa/features/login/session.dart';
import 'package:material_ui/material_ui.dart';

import '../features/close_print_test.dart' show setUpPrinter;
import '../support/close_pump.dart';
import '../support/kassa_pump.dart';
import '../support/pump.dart';

// Bildvergleich des Bereichs Abschluss gegen die freigegebenen Entwürfe. Neu
// erzeugen mit `flutter test --update-goldens test/golden/close_golden_test.dart`.

/// Wechselgeld 150,00 €, Verkauf 18,20 €, eine Einlage von 50,00 € (Soll
/// 218,20 €).
Future<void> _ready(
  WidgetTester t, {
  Brightness brightness = Brightness.light,
}) async {
  await pumpClose(
    t,
    floatCents: 15000,
    brightness: brightness,
    openArea: false,
  );
  final c = containerOf(t);
  await c
      .read(dayRepositoryProvider)
      .addMovement(
        kind: CashMovementKind.deposit,
        amountCents: 5000,
        reason: CashReason.change,
        staff: c.read(sessionProvider)!,
      );
  await openClose(t);
}

void main() {
  testWidgets('Abschluss, Zählen mit zu wenig (hell)', (t) async {
    await _ready(t);
    await tapKeys(t, '2 1 8');
    expect(t.takeException(), isNull);
    await expectLater(
      find.byType(KassaApp),
      matchesGoldenFile('goldens/abschluss_zaehlen_hell.png'),
    );
  });

  testWidgets('Abschluss, Bargeld entnehmen (hell)', (t) async {
    await _ready(t);
    await t.tap(find.byKey(const Key('cash-out')));
    await t.pumpAndSettle();
    await tapKeys(t, '2 0');
    await t.tap(find.byKey(const Key('reason-purchase')));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await expectLater(
      find.byType(KassaApp),
      matchesGoldenFile('goldens/abschluss_bargeld_entnehmen_hell.png'),
    );
  });

  testWidgets('Abschluss, In der Lade lassen (hell)', (t) async {
    await _ready(t);
    await tapKeys(t, '2 1 8');
    await t.tap(find.byKey(const Key('count-next')));
    await t.pumpAndSettle();
    await tapKeys(t, '1 5 0');
    expect(t.takeException(), isNull);
    await expectLater(
      find.byType(KassaApp),
      matchesGoldenFile('goldens/abschluss_in_der_lade_lassen_hell.png'),
    );
  });

  testWidgets('Abschluss, Tag abgeschlossen (dunkel)', (t) async {
    await _ready(t, brightness: Brightness.dark);
    await tapKeys(t, '2 1 8');
    await t.tap(find.byKey(const Key('count-next')));
    await t.pumpAndSettle();
    await tapKeys(t, '1 5 0');
    await t.tap(find.byKey(const Key('close-day')));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await expectLater(
      find.byType(KassaApp),
      matchesGoldenFile('goldens/abschluss_fertig_dunkel.png'),
    );
  });

  Future<void> closedWithPrinter(WidgetTester t, {bool fails = false}) async {
    await _ready(t);
    await setUpPrinter(t);
    if (fails) {
      printerOf(t).next = const PrintOutcome.failed(PrintProblem.unreachable);
    }
    await tapKeys(t, '2 1 8');
    await t.tap(find.byKey(const Key('count-next')));
    await t.pumpAndSettle();
    await tapKeys(t, '1 5 0');
    await t.tap(find.byKey(const Key('close-day')));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  }

  testWidgets('Abschluss, Tag abgeschlossen mit Bericht (hell)', (t) async {
    await closedWithPrinter(t);
    await expectLater(
      find.byType(KassaApp),
      matchesGoldenFile('goldens/abschluss_abgeschlossen_bericht_hell.png'),
    );
  });

  testWidgets('Abschluss, Tag abgeschlossen mit Druckfehler (hell)', (t) async {
    await closedWithPrinter(t, fails: true);
    await expectLater(
      find.byType(KassaApp),
      matchesGoldenFile(
        'goldens/abschluss_abgeschlossen_druckfehler_hell.png',
      ),
    );
  });

  testWidgets('Kassa mit Hinweis auf vergessenen Abschluss (hell)', (t) async {
    await pumpShellNextMorningWithOpenDay(t);
    expect(t.takeException(), isNull);
    await expectLater(
      find.byType(KassaApp),
      matchesGoldenFile('goldens/kassa_vergessener_abschluss_hell.png'),
    );
  });
}
