import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/data/stats_repository.dart';
import 'package:kassa/domain/cart.dart';
import 'package:kassa/domain/stats.dart';
import 'package:material_ui/material_ui.dart';

import '../support/demo_fixtures.dart';
import '../support/overview_pump.dart';
import '../support/pump.dart';

Future<void> _range(WidgetTester t, String id) async {
  await t.tap(find.byKey(Key('range-$id')));
  await t.pumpAndSettle();
}

String _text(WidgetTester t, String key) => textOf(t, Key(key));

class _Flaky extends StatsRepository {
  _Flaky(super.db, super.clock);

  int calls = 0;

  @override
  Future<Overview> overview(StatsRange range) {
    calls++;
    if (calls == 1) throw StateError('kaputt');
    return super.overview(range);
  }
}

void main() {
  group('Zahlen', () {
    testWidgets('zeigt Umsatz, Anzahl, Zahlungsarten und Meistverkauft', (
      t,
    ) async {
      await pumpOverviewWithSales(t);
      expect(_text(t, 'revenue'), '36,40 €');
      expect(_text(t, 'receipt-count'), '2');
      expect(_text(t, 'per-receipt'), '18,20 €');
      expect(_text(t, 'void-count'), '0');
      expect(_text(t, 'payment-cash-amount'), '36,40 €');
      expect(_text(t, 'payment-card-amount'), '0,00 €');
      expect(find.text('Cola 0,33 l'), findsOneWidget);
      expect(find.text('4 ×'), findsOneWidget);
      expect(find.text('Dienstag, 17. November'), findsOneWidget);
      expect(find.text('Umsatz pro Stunde'), findsOneWidget);
      expect(find.text('Bowls'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('Pro Bon rundet halb auf in ganzen Cent', (t) async {
      // 18,20 € und 3,15 € (eine Cola mit Pfand): 21,35 € durch 2 Bons.
      await pumpOverviewWithSales(
        t,
        sales: [
          OverviewSale(today(11, 5)),
          OverviewSale(today(11, 20), cart: const Cart.empty().add(cola)),
        ],
      );
      expect(_text(t, 'revenue'), '21,35 €');
      expect(_text(t, 'per-receipt'), '10,68 €'); // 1067,5 Cent, halb auf
    });

    testWidgets('Stornos zählen die Storno-Bons, Anzahl sinkt', (t) async {
      await pumpOverviewWithSales(
        t,
        sales: [
          OverviewSale(today(11, 5)),
          OverviewSale(today(12, 5), voided: true),
        ],
      );
      expect(_text(t, 'void-count'), '1');
      expect(_text(t, 'receipt-count'), '1');
      expect(_text(t, 'revenue'), '18,20 €');
      expect(_text(t, 'per-receipt'), '18,20 €');
    });

    testWidgets('Pro Bon ist 0,00 €, wenn nichts übrig bleibt', (t) async {
      await pumpOverviewWithSales(
        t,
        sales: [OverviewSale(today(11, 5), voided: true)],
      );
      expect(_text(t, 'receipt-count'), '0');
      expect(_text(t, 'void-count'), '1');
      expect(_text(t, 'revenue'), '0,00 €');
      expect(_text(t, 'per-receipt'), '0,00 €');
    });

    testWidgets('frische Zahlen, wenn der Bereich wieder geöffnet wird', (
      t,
    ) async {
      await pumpOverviewWithSales(t);
      expect(_text(t, 'revenue'), '36,40 €');
      await t.tap(find.byKey(const Key('tab-Bons')));
      await t.pumpAndSettle();
      await sellMore(t);
      await t.tap(find.byKey(const Key('tab-Übersicht')));
      await t.pumpAndSettle();
      expect(_text(t, 'revenue'), '54,60 €');
      expect(_text(t, 'receipt-count'), '3');
    });
  });

  group('Vergleich', () {
    testWidgets('mehr als letzten Dienstag', (t) async {
      await pumpOverviewWithSales(
        t,
        sales: [
          OverviewSale(DateTime(2026, 11, 10, 10)),
          OverviewSale(today(11, 5)),
          OverviewSale(today(12, 5)),
        ],
      );
      expect(_text(t, 'comparison'), '100 % mehr als letzten Dienstag');
    });

    testWidgets('weniger als letzten Dienstag, halb auf gerundet', (t) async {
      await pumpOverviewWithSales(
        t,
        sales: [
          OverviewSale(DateTime(2026, 11, 10, 10)),
          OverviewSale(DateTime(2026, 11, 10, 11)),
          OverviewSale(DateTime(2026, 11, 10, 12)),
          OverviewSale(today(11, 5)),
        ],
      );
      // 1820 gegen 5460: 66,67 % weniger -> 67 %
      expect(_text(t, 'comparison'), '67 % weniger als letzten Dienstag');
    });

    testWidgets('gleich, und für 7 Tage mit eigenem Text', (t) async {
      await pumpOverviewWithSales(
        t,
        sales: [
          OverviewSale(DateTime(2026, 11, 8, 10)),
          OverviewSale(today(11, 5)),
        ],
        now: today(11, 30),
      );
      await _range(t, 'days7');
      expect(_text(t, 'comparison'), 'Gleich wie in den 7 Tagen davor');
      await _range(t, 'today');
      expect(find.byKey(const Key('comparison')), findsNothing);
    });

    testWidgets('ohne Vergleichswert keine Pille', (t) async {
      await pumpOverviewWithSales(t);
      expect(find.byKey(const Key('comparison')), findsNothing);
    });
  });

  group('Diagramm', () {
    testWidgets('der höchste Balken ist am Anfang gewählt', (t) async {
      await pumpOverviewWithSales(t);
      // Gleichstand: der erste (11 Uhr).
      expect(_text(t, 'bar-detail-label'), '11 bis 12 Uhr');
      expect(_text(t, 'bar-detail'), '18,20 €');
    });

    testWidgets('Tipp auf einen Balken zeigt dessen Wert', (t) async {
      await pumpOverviewWithSales(
        t,
        sales: [
          OverviewSale(today(11, 5)),
          OverviewSale(today(13, 10)),
          OverviewSale(today(13, 20)),
        ],
      );
      expect(_text(t, 'bar-detail-label'), '13 bis 14 Uhr');
      expect(_text(t, 'bar-detail'), '36,40 €');
      await t.tap(find.byKey(const Key('bar-0')));
      await t.pump();
      expect(_text(t, 'bar-detail-label'), '11 bis 12 Uhr');
      expect(_text(t, 'bar-detail'), '18,20 €');
      await t.tap(find.byKey(const Key('bar-1')));
      await t.pump();
      expect(_text(t, 'bar-detail'), '0,00 €');
    });

    testWidgets('Balken haben eine Beschriftung für Vorlesehilfen', (t) async {
      final handle = t.ensureSemantics();
      await pumpOverviewWithSales(t);
      expect(find.bySemanticsLabel('11 bis 12 Uhr, 18,20 €'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('Umschalten auf 7 Tage lädt sieben Balken', (t) async {
      await pumpOverviewWithSales(t);
      await _range(t, 'days7');
      expect(find.byKey(const Key('bar-6')), findsOneWidget);
      expect(find.byKey(const Key('bar-7')), findsNothing);
      expect(_text(t, 'bar-detail-label'), 'Dienstag, 17. November');
      expect(find.text('Umsatz pro Tag'), findsOneWidget);
      expect(find.text('Letzte 7 Tage'), findsOneWidget);
    });

    testWidgets('30 Tage zeigen dreißig Balken', (t) async {
      await pumpOverviewWithSales(t);
      await _range(t, 'days30');
      expect(find.byKey(const Key('bar-29')), findsOneWidget);
      expect(find.byKey(const Key('bar-30')), findsNothing);
      expect(find.text('Letzte 30 Tage'), findsOneWidget);
    });
  });

  group('Achsenbeschriftung', () {
    /// Prüft, dass keine zwei sichtbaren Beschriftungen einander berühren und
    /// dass der gewählte Balken seine zeigt.
    void expectNoOverlap(WidgetTester t, int selected) {
      final rects = <int, Rect>{};
      for (var i = 0; i < 31; i++) {
        final f = find.byKey(Key('axis-label-$i'));
        if (f.evaluate().isNotEmpty) rects[i] = t.getRect(f);
      }
      expect(rects.containsKey(selected), isTrue, reason: 'gewählter fehlt');
      final ids = rects.keys.toList()..sort();
      for (var a = 0; a + 1 < ids.length; a++) {
        expect(
          rects[ids[a]]!.right,
          lessThan(rects[ids[a + 1]]!.left),
          reason: 'Beschriftung ${ids[a]} und ${ids[a + 1]} überlappen',
        );
      }
    }

    for (final size in [const Size(1280, 800), const Size(960, 600)]) {
      for (final pick in [1, 4, 6, 9, 24]) {
        testWidgets('30 Tage, Balken $pick gewählt, ${size.width.toInt()} dp', (
          t,
        ) async {
          await pumpOverviewWithSales(t, size: size, openRange: 'days30');
          await t.tap(find.byKey(Key('bar-$pick')));
          await t.pump();
          expectNoOverlap(t, pick);
        });
      }
    }

    for (final size in [
      const Size(960, 600),
      const Size(1000, 625),
      const Size(1200, 750),
      const Size(1280, 800),
    ]) {
      for (final pick in [2, 3, 7, 8]) {
        testWidgets(
          '30 Tage, Balken $pick gewählt, Textgröße 1,3, ${size.width.toInt()} dp',
          (t) async {
            await pumpOverviewWithSales(
              t,
              size: size,
              openRange: 'days30',
              textScale: 1.3,
            );
            await t.tap(find.byKey(Key('bar-$pick')));
            await t.pump();
            expectNoOverlap(t, pick);
          },
        );
      }
    }

    testWidgets('24 Stunden-Balken: kein Überlappen bei ungeradem Balken', (
      t,
    ) async {
      await pumpOverviewWithSales(
        t,
        sales: [
          OverviewSale(today(0, 5)),
          OverviewSale(today(5, 5)),
          OverviewSale(today(23, 5)),
        ],
        now: today(23, 30),
        size: const Size(960, 600),
      );
      await t.tap(find.byKey(const Key('bar-5')));
      await t.pump();
      expectNoOverlap(t, 5);
      // Die Beschriftung ist breiter als eine Spalte: die Nachbarn entfallen.
      expect(find.byKey(const Key('axis-label-4')), findsNothing);
      expect(find.byKey(const Key('axis-label-6')), findsNothing);
      await t.tap(find.byKey(const Key('bar-23')));
      await t.pump();
      expectNoOverlap(t, 23);
      expect(find.byKey(const Key('axis-label-22')), findsNothing);
    });
  });

  group('Leer und Fehler', () {
    testWidgets('ohne Bons: Hinweis statt leerer Balken (heute)', (t) async {
      await pumpOverviewWithSales(t, sales: []);
      expect(find.text('Noch keine Bons in diesem Zeitraum.'), findsOneWidget);
      expect(find.byKey(const Key('bar-0')), findsNothing);
      expect(_text(t, 'revenue'), '0,00 €');
      expect(find.text('Noch keine Bons.'), findsNWidgets(2));
    });

    testWidgets('ohne Bons: Hinweis auch bei 7 Tagen', (t) async {
      await pumpOverviewWithSales(t, sales: [], openRange: 'days7');
      expect(find.text('Noch keine Bons in diesem Zeitraum.'), findsOneWidget);
      expect(find.byKey(const Key('bar-0')), findsNothing);
    });

    testWidgets('Fehler beim Laden: Hinweis und Nochmal versuchen', (t) async {
      final List<Override> flaky = [
        statsRepositoryProvider.overrideWith(
          (ref) =>
              _Flaky(ref.watch(databaseProvider), ref.watch(clockProvider)),
        ),
      ];
      await pumpOverviewWithSales(t, extraOverrides: flaky);
      expect(
        find.text('Die Zahlen konnten nicht geladen werden.'),
        findsOneWidget,
      );
      await t.tap(find.text('Nochmal versuchen'));
      await t.pumpAndSettle();
      expect(_text(t, 'revenue'), '36,40 €');
    });
  });
}
