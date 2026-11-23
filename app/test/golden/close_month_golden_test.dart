import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/app.dart';
import 'package:material_ui/material_ui.dart';

import '../support/month_pump.dart';
import '../support/overview_pump.dart';

// Bildvergleich der Monatsabrechnung gegen die freigegebenen Entwürfe
// (Main.dc.html, Zeitraum.dc.html). Neu erzeugen mit
// `flutter test --update-goldens test/golden/close_month_golden_test.dart`.

/// September ein Verkauf, im Oktober sieben an fünf Tagen, einer storniert.
List<OverviewSale> _sales() => [
  OverviewSale(DateTime(2026, 9, 15, 12)),
  OverviewSale(DateTime(2026, 10, 1, 11)),
  OverviewSale(DateTime(2026, 10, 1, 12)),
  OverviewSale(DateTime(2026, 10, 2, 12)),
  OverviewSale(DateTime(2026, 10, 3, 12), voided: true),
  OverviewSale(DateTime(2026, 10, 3, 13)),
  OverviewSale(DateTime(2026, 10, 4, 12)),
  OverviewSale(DateTime(2026, 10, 5, 12)),
];

/// Jänner bis Oktober je ein bis zwei Verkäufe.
List<OverviewSale> _year() => [
  for (var m = 1; m <= 10; m++) ...[
    OverviewSale(DateTime(2026, m, 5, 12)),
    if (m.isEven) OverviewSale(DateTime(2026, m, 6, 12)),
  ],
];

Future<void> _shot(WidgetTester t, String name) async {
  expect(t.takeException(), isNull);
  await expectLater(
    find.byType(KassaApp),
    matchesGoldenFile('goldens/$name.png'),
  );
}

void main() {
  testWidgets('Abschluss, Monat (hell)', (t) async {
    await pumpMonth(t, sales: _sales(), printer: true);
    await _shot(t, 'abschluss_monat_hell');
  });

  testWidgets('Abschluss, Monat (dunkel)', (t) async {
    await pumpMonth(
      t,
      sales: _sales(),
      printer: true,
      brightness: Brightness.dark,
    );
    await _shot(t, 'abschluss_monat_dunkel');
  });

  testWidgets('Abschluss, Monat von bis (hell)', (t) async {
    await pumpMonth(t, sales: _year(), printer: true);
    await tapKey(t, 'segment-Von bis');
    await tapKey(t, 'month-1');
    await tapKey(t, 'month-10');
    await _shot(t, 'abschluss_monat_von_bis_hell');
  });

  testWidgets('Abschluss, noch kein Monat (hell)', (t) async {
    await pumpMonth(
      t,
      sales: [OverviewSale(DateTime(2026, 11, 10, 12))],
      printer: true,
    );
    await _shot(t, 'abschluss_monat_kein_monat_hell');
  });

  testWidgets('Abschluss, Monat mit Monatsbeleg, gedruckt (hell)', (t) async {
    await pumpMonth(
      t,
      sales: _sales(),
      printer: true,
      live: true,
      belege: [SignatureReceipt(DateTime(2026, 11, 1, 10, 2))],
    );
    await tapKey(t, 'print-period');
    await _shot(t, 'abschluss_monat_beleg_hell');
  });
}
