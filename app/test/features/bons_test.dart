import 'dart:async';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/core/app_language.dart';
import 'package:kassa/core/clock.dart';
import 'package:kassa/core/money.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/data/receipt_repository.dart';
import 'package:kassa/devices/printer.dart';
import 'package:kassa/domain/cart.dart';
import 'package:kassa/domain/receipt.dart';
import 'package:kassa/domain/staff.dart';
import 'package:kassa/features/kassa/kitchen_service.dart';
import 'package:kassa/features/login/session.dart';
import 'package:kassa/ui/pressable.dart';
import 'package:kassa/ui/tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../support/bons_pump.dart';
import '../support/cash_pump.dart';
import '../support/demo_fixtures.dart';
import '../support/fake_devices.dart';
import '../support/kassa_pump.dart';
import '../support/pump.dart';

const _failText =
    'Der Storno konnte nicht gespeichert werden. Bitte noch einmal.';

Future<void> _tapFilter(WidgetTester t, String name) async {
  await t.tap(find.byKey(Key('filter-$name')));
  await t.pumpAndSettle();
}

Future<void> _startVoid(WidgetTester t, int number) async {
  await openReceipt(t, number);
  await t.tap(find.byKey(const Key('void-receipt')));
  await t.pumpAndSettle();
}

Future<void> _setVoidRequiresChef(WidgetTester t) async {
  final repo = containerOf(t).read(settingsRepositoryProvider);
  await repo.save((await repo.current()).copyWith(voidRequiresChef: true));
  await t.pumpAndSettle();
}

/// Speicher, dessen Storno immer scheitert.
class _FailingVoids extends ReceiptRepository {
  _FailingVoids(super.db, super.clock, super.days);

  @override
  Future<Receipt> voidReceipt(String receiptId, {required Staff staff}) =>
      Future.error(StateError('Platte voll'));
}

/// Speicher, der die Storno-Aufrufe zählt.
class _CountingVoids extends ReceiptRepository {
  _CountingVoids(super.db, super.clock, super.days);

  int calls = 0;

  @override
  Future<Receipt> voidReceipt(String receiptId, {required Staff staff}) {
    calls++;
    return super.voidReceipt(receiptId, staff: staff);
  }
}

/// Verkauft [cart] mit Karte (Standard: eine Cola) als die angemeldete Person.
Future<Receipt> _sellCard(WidgetTester t) async {
  final staff = containerOf(t).read(sessionProvider)!;
  return containerOf(t)
      .read(receiptRepositoryProvider)
      .finalizeCardSale(
        saleId: 'card-sale-1',
        cart: const Cart.empty().add(cola),
        staff: staff,
        provider: 'sumup',
        txCode: 'TX1',
        cardScheme: 'VISA',
        cardLast4: '4242',
      );
}

void main() {
  testWidgets('Storno eines Karten-Bons zeigt den Hinweis zur Rückbuchung, '
      'bei Bar nicht', (t) async {
    await pumpBonsWithSales(t, 1);
    await _sellCard(t);
    await t.tap(find.byKey(const Key('tab-Kassa')));
    await t.pump();
    await t.tap(find.byKey(const Key('tab-Bons')));
    await t.pumpAndSettle();

    // Bar: wie bisher.
    await _startVoid(t, 1);
    expect(find.byKey(const Key('void-card-hint')), findsNothing);
    expect(find.text('Ja, stornieren'), findsOneWidget);
    expect(find.text('Du gibst 3,15 € bar zurück.'), findsOneWidget);
    await t.tap(find.byKey(const Key('cancel-void')));
    await t.pumpAndSettle();

    // Karte: der Hinweis in warnBg und die lange Beschriftung.
    await _startVoid(t, 2);
    expect(
      find.text(
        'Das Geld geht nicht von selbst zurück. Bitte die Zahlung in der '
        'SumUp-App rückbuchen.',
      ),
      findsOneWidget,
    );
    final hint = t.widget<Container>(find.byKey(const Key('void-card-hint')));
    expect((hint.decoration! as BoxDecoration).color, KassaColors.light.warnBg);
    expect(
      find.text('Stornieren, Rückbuchung mache ich in SumUp'),
      findsOneWidget,
    );
    expect(find.text('Ja, stornieren'), findsNothing);
    expect(find.textContaining('zurück auf die Karte'), findsNothing);
    final confirm = t.getRect(find.byKey(const Key('confirm-void')));
    expect(confirm.height, greaterThanOrEqualTo(48));
    expect(t.takeException(), isNull);

    await t.tap(find.byKey(const Key('confirm-void')));
    await t.pumpAndSettle();
    expect(find.text('Storniert'), findsWidgets);
  });

  testWidgets('Drucken im Bon-Detail druckt genau diesen Bon', (t) async {
    await pumpBonsWithSales(t, 3);
    await setUpPrinter(t);
    await openReceipt(t, 2);
    expect(t.getSize(find.byKey(const Key('print-receipt'))).height, 72);
    final id = (await queryRows(
      t,
      'SELECT id FROM receipts WHERE number = 2',
    )).single['id'];
    await t.tap(find.byKey(const Key('print-receipt')));
    await t.pumpAndSettle();
    expect(printerOf(t).log, ['print:$id']); // ohne Lade
    expect(find.text('Bon gedruckt'), findsOneWidget);
    expect(find.byKey(const Key('undo')), findsNothing);
  });

  testWidgets('Drucken: weitere Tipps, solange gedruckt wird, drucken nicht '
      'noch einmal', (t) async {
    await pumpBonsWithSales(t, 1);
    await setUpPrinter(t);
    await openReceipt(t, 1);
    final hold = printerOf(t).hold = Completer<void>();
    await t.tap(find.byKey(const Key('print-receipt')));
    await t.pump();
    await t.tap(find.byKey(const Key('print-receipt')));
    await t.pump();
    await t.tap(find.byKey(const Key('print-receipt')));
    await t.pump();
    expect(printerOf(t).log, hasLength(1));
    hold.complete();
    printerOf(t).hold = null;
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('print-receipt')));
    await t.pumpAndSettle();
    expect(printerOf(t).log, hasLength(2));
  });

  testWidgets('Drucken meldet ein Problem als Hinweis', (t) async {
    await pumpBonsWithSales(t, 1);
    await setUpPrinter(t);
    await openReceipt(t, 1);
    printerOf(t).next = const PrintOutcome.failed(PrintProblem.coverOpen);
    await t.tap(find.byKey(const Key('print-receipt')));
    await t.pumpAndSettle();
    expect(
      find.text('Drucker nicht bereit. Der Deckel ist offen.'),
      findsOneWidget,
    );
  });

  testWidgets('ohne Drucker gibt es die Taste Drucken nicht', (t) async {
    await pumpBonsWithSales(t, 1);
    await openReceipt(t, 1);
    expect(find.byKey(const Key('print-receipt')), findsNothing);
    expect(find.byKey(const Key('void-receipt')), findsOneWidget);
  });

  testWidgets('Storno druckt den Storno-Bon, die Lade bleibt zu', (t) async {
    await pumpBonsWithSales(t, 1);
    await setUpPrinter(t);
    await _startVoid(t, 1);
    await t.tap(find.byKey(const Key('confirm-void')));
    await t.pumpAndSettle();
    final log = printerOf(t).log;
    expect(log, hasLength(1));
    expect(log.single, startsWith('print:'));
  });

  testWidgets('Liste des offenen Tages, neuester zuerst, Detail rechts', (
    t,
  ) async {
    await pumpBonsWithSales(t, 3);
    expect(
      t.getTopLeft(find.byKey(const Key('receipt-3'))).dy,
      lessThan(t.getTopLeft(find.byKey(const Key('receipt-1'))).dy),
    );
    expect(find.text('Heute gibt es noch keine Bons.'), findsNothing);
    await openReceipt(t, 2);
    expect(find.text('Bon Nr. 2'), findsOneWidget);
    expect(find.text('Bar'), findsWidgets);
    expect(find.text('10 % MwSt'), findsOneWidget);
    expect(find.text('Boniert von Anna'), findsOneWidget);
    await openReceipt(t, 1);
    expect(find.text('20 % MwSt'), findsOneWidget);
    expect(find.text('Pfand'), findsOneWidget);
  });

  testWidgets('ohne Auswahl steht ein Hinweis in der Detailspalte', (t) async {
    await pumpBonsWithSales(t, 1);
    expect(find.text('Tippe auf einen Bon, um ihn anzusehen.'), findsOneWidget);
    await openReceipt(t, 1);
    expect(find.text('Tippe auf einen Bon, um ihn anzusehen.'), findsNothing);
  });

  testWidgets('ohne Bons steht ein Hinweis', (t) async {
    await pumpBonsWithSales(t, 0);
    expect(find.text('Heute gibt es noch keine Bons.'), findsOneWidget);
  });

  testWidgets('die Liste folgt einem Verkauf, während der Bereich offen ist', (
    t,
  ) async {
    await pumpBonsWithSales(t, 1);
    expect(find.byKey(const Key('receipt-2')), findsNothing);
    await sellCash(t);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('receipt-2')), findsOneWidget);
    expect(find.text('Heute gibt es noch keine Bons.'), findsNothing);
  });

  testWidgets('der erste Verkauf des Tages erscheint ebenfalls von selbst', (
    t,
  ) async {
    await pumpBonsWithSales(t, 0);
    await sellCash(t);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('receipt-1')), findsOneWidget);
  });

  testWidgets('Stornieren fragt einmal nach und legt einen Storno-Bon an', (
    t,
  ) async {
    await pumpBonsWithSales(t, 1);
    final total = formatEuro(315);
    await _startVoid(t, 1);
    expect(find.text('Bon Nr. 1 wirklich stornieren?'), findsOneWidget);
    expect(find.text('Du gibst $total bar zurück.'), findsOneWidget);
    expect(find.byKey(const Key('void-receipt')), findsNothing);
    await t.tap(find.byKey(const Key('confirm-void')));
    await t.pumpAndSettle();
    expect(find.text('Storniert'), findsWidgets);
    expect(find.byKey(const Key('receipt-2')), findsOneWidget);
    expect(find.byKey(const Key('void-receipt')), findsNothing);
    expect(find.text('Bon Nr. 1'), findsOneWidget); // Auswahl bleibt
    expect(find.textContaining('zählt nicht zum Umsatz'), findsOneWidget);
    expect(find.textContaining('Storniert von Anna'), findsOneWidget);
  });

  testWidgets(
    'Filter: Bar versteckt stornierte, Storniert zeigt Original und Storno',
    (t) async {
      await pumpBonsWithSales(t, 2);
      await _startVoid(t, 1);
      await t.tap(find.byKey(const Key('confirm-void')));
      await t.pumpAndSettle();
      // Bons: 1 (storniert), 2 (Verkauf), 3 (Storno zu 1).
      await _tapFilter(t, 'bar');
      expect(find.byKey(const Key('receipt-1')), findsNothing);
      expect(find.byKey(const Key('receipt-2')), findsOneWidget);
      expect(find.byKey(const Key('receipt-3')), findsNothing);
      await _tapFilter(t, 'storniert');
      expect(find.byKey(const Key('receipt-1')), findsOneWidget);
      expect(find.byKey(const Key('receipt-2')), findsNothing);
      expect(find.byKey(const Key('receipt-3')), findsOneWidget);
      await _tapFilter(t, 'karte');
      expect(find.byKey(const Key('receipt-2')), findsNothing);
      expect(find.text('Keine Bons mit diesem Filter.'), findsOneWidget);
      await _tapFilter(t, 'alle');
      for (final n in [1, 2, 3]) {
        expect(find.byKey(Key('receipt-$n')), findsOneWidget);
      }
      expect(find.text('Keine Bons mit diesem Filter.'), findsNothing);
    },
  );

  testWidgets('Storno-Bon: Pille "Storno", negativer Betrag, kein Stornieren', (
    t,
  ) async {
    await pumpBonsWithSales(t, 1);
    await _startVoid(t, 1);
    await t.tap(find.byKey(const Key('confirm-void')));
    await t.pumpAndSettle();
    final row = find.byKey(const Key('receipt-2'));
    expect(
      find.descendant(of: row, matching: find.text('Storno')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row, matching: find.text(formatEuro(-315))),
      findsOneWidget,
    );
    await openReceipt(t, 2);
    expect(find.text('Storno zu Bon Nr. 1'), findsOneWidget);
    expect(find.byKey(const Key('void-receipt')), findsNothing);
    expect(find.text('Bon Nr. 2'), findsOneWidget);
    expect(find.text('Storniert von Anna'), findsOneWidget);
    expect(find.textContaining('Boniert von'), findsNothing);
  });

  testWidgets(
    'Untertitel: "Heute" mit Datum, bei vergessenem Abschluss nur das Datum des offenen Tages',
    (t) async {
      final clock = FixedClock(DateTime(2026, 11, 17, 11));
      await pumpBonsWithSales(
        t,
        1,
        overrides: await memoryOverrides(clock: clock),
      );
      expect(find.text('Heute, Dienstag 17. November'), findsOneWidget);
      // Der Tag wurde nicht abgeschlossen, jetzt ist der nächste Morgen.
      clock.value = DateTime(2026, 11, 18, 8);
      await t.tap(find.byKey(const Key('tab-Kassa')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('tab-Bons')));
      await t.pumpAndSettle();
      expect(find.text('Dienstag 17. November'), findsOneWidget);
      expect(find.textContaining('Heute,'), findsNothing);
    },
  );

  testWidgets('Storno nur für den Chef: Mitarbeiterin sieht keine Taste', (
    t,
  ) async {
    await pumpBonsWithSales(t, 1);
    await openReceipt(t, 1);
    expect(find.byKey(const Key('void-receipt')), findsOneWidget);
    await _setVoidRequiresChef(t);
    expect(find.byKey(const Key('void-receipt')), findsNothing);
  });

  testWidgets('Storno nur für den Chef: der Chef sieht die Taste', (t) async {
    await pumpBonsWithSales(t, 1, pin: '4711');
    await _setVoidRequiresChef(t);
    await openReceipt(t, 1);
    expect(find.byKey(const Key('void-receipt')), findsOneWidget);
  });

  testWidgets('zwei schnelle Tipps auf "Ja, stornieren" geben einen Storno', (
    t,
  ) async {
    late _CountingVoids repo;
    final o = await memoryOverrides();
    await pumpBonsWithSales(
      t,
      1,
      overrides: <Override>[
        ...o,
        receiptRepositoryProvider.overrideWith((ref) {
          return repo = _CountingVoids(
            ref.watch(databaseProvider),
            ref.watch(clockProvider),
            ref.watch(dayRepositoryProvider),
          );
        }),
      ],
    );
    await _startVoid(t, 1);
    await t.tap(find.byKey(const Key('confirm-void')));
    await t.tap(find.byKey(const Key('confirm-void')), warnIfMissed: false);
    await t.pumpAndSettle();
    expect(repo.calls, 1);
    final rows = await queryRows(
      t,
      "SELECT COUNT(*) AS c FROM receipts WHERE kind = 'voided'",
    );
    expect(rows.single['c'], 1);
    expect(find.text(_failText), findsNothing);
  });

  testWidgets('Abbrechen schließt die Frage ohne Storno', (t) async {
    await pumpBonsWithSales(t, 1);
    await _startVoid(t, 1);
    await t.tap(find.byKey(const Key('cancel-void')));
    await t.pumpAndSettle();
    expect(find.text('Bon Nr. 1 wirklich stornieren?'), findsNothing);
    expect(find.byKey(const Key('void-receipt')), findsOneWidget);
    expect(await receiptCount(t), 1);
  });

  testWidgets('der Storno trägt den Namen der angemeldeten Person', (t) async {
    await pumpBonsWithSales(t, 1, pin: '4711');
    await _startVoid(t, 1);
    await t.tap(find.byKey(const Key('confirm-void')));
    await t.pumpAndSettle();
    final rows = await queryRows(
      t,
      "SELECT staff_name FROM receipts WHERE kind = 'voided'",
    );
    expect(rows.single['staff_name'], 'Chef');
    expect(find.textContaining('Storniert von Chef'), findsOneWidget);
  });

  testWidgets(
    'scheitert das Speichern, steht ein Hinweis und man kann es nochmal',
    (t) async {
      final o = await memoryOverrides();
      await pumpBonsWithSales(
        t,
        1,
        overrides: <Override>[
          ...o,
          receiptRepositoryProvider.overrideWith(
            (ref) => _FailingVoids(
              ref.watch(databaseProvider),
              ref.watch(clockProvider),
              ref.watch(dayRepositoryProvider),
            ),
          ),
        ],
      );
      await _startVoid(t, 1);
      await t.tap(find.byKey(const Key('confirm-void')));
      await t.pumpAndSettle();
      expect(find.text(_failText), findsOneWidget);
      expect(find.byKey(const Key('confirm-void')), findsOneWidget);
      expect(await receiptCount(t), 1);
      await t.tap(find.byKey(const Key('cancel-void')));
      await t.pumpAndSettle();
      expect(find.text(_failText), findsNothing);
    },
  );

  testWidgets(
    'kein Überlauf bei 960 x 600 und Textskala 1,3 mit vielen Zeilen',
    (t) async {
      await pumpBonsWithSales(t, 0, size: const Size(960, 600), textScale: 1.3);
      var cart = const Cart.empty();
      for (final item in catalog.items.where(
        (i) => catalog.templateOf(i) == null,
      )) {
        cart = cart.add(item);
      }
      cart = cart
          .add(huhnBowl, options: [xxl, nudeln])
          .add(huhnBowl, options: [normal, reis]);
      expect(cart.lines.length, greaterThan(9));
      await sellCash(t, cart: cart);
      await t.pumpAndSettle();
      await openReceipt(t, 1);
      expect(t.takeException(), isNull);
      await t.tap(find.byKey(const Key('void-receipt')));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.byKey(const Key('confirm-void')), findsOneWidget);
      // Die Zeilen scrollen: die letzte ist erst nach dem Wischen sichtbar.
      await t.drag(
        find.byKey(const Key('detail-scroll')),
        const Offset(0, -2000),
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'jede Tippfläche ist mindestens 48 dp in der kleineren Richtung',
    (t) async {
      await pumpBonsWithSales(t, 3);
      await openReceipt(t, 1);
      Future<void> check() async {
        final taps = find.descendant(
          of: find.byKey(const Key('area-bons')),
          matching: find.byType(Pressable),
        );
        expect(taps, findsWidgets);
        for (final e in taps.evaluate()) {
          final size = t.getSize(find.byElementPredicate((x) => x == e));
          expect(
            size.shortestSide,
            greaterThanOrEqualTo(48),
            reason: '${e.widget.key}',
          );
        }
      }

      await check();
      await t.tap(find.byKey(const Key('void-receipt')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('confirm-void')), findsOneWidget);
      await check();
    },
  );

  testWidgets('Sonderbeleg: Bezeichnung statt Zahlung, 0,00 €, nur unter '
      '"Alle", kein Stornieren', (t) async {
    await pumpBonsWithSales(t, 1, pin: '4711'); // der Chef dürfte stornieren
    final c = containerOf(t);
    final staff = c.read(sessionProvider)!;
    await c
        .read(databaseProvider)
        .into(c.read(databaseProvider).receiptRows)
        .insert(
          ReceiptRowsCompanion.insert(
            id: 'm1',
            number: 2,
            createdAt: c.read(clockProvider).now(),
            staffId: staff.id,
            staffName: staff.name,
            kind: ReceiptKind.month.name,
            goodsCents: 0,
            depositCents: 0,
            totalCents: 0,
          ),
        );
    await t.pumpAndSettle();

    final row = find.byKey(const Key('receipt-2'));
    expect(
      find.descendant(of: row, matching: find.text('Monatsbeleg')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row, matching: find.text('0,00 €')),
      findsOneWidget,
    );
    for (final f in ['bar', 'karte', 'storniert']) {
      await _tapFilter(t, f);
      expect(find.byKey(const Key('receipt-2')), findsNothing, reason: f);
    }
    await _tapFilter(t, 'alle');
    expect(find.byKey(const Key('receipt-2')), findsOneWidget);

    await openReceipt(t, 2);
    // Die Bezeichnung ist der Titel (Pille in der Liste und Titel rechts).
    expect(find.text('Bon Nr. 2'), findsNothing);
    expect(find.text('Monatsbeleg'), findsNWidgets(2));
    expect(find.text('Erstellt von Chef'), findsOneWidget);
    expect(find.text('Zahlung'), findsNothing);
    expect(find.text('Gegeben'), findsNothing);
    expect(textOf(t, const Key('detail-total')), '0,00 €');
    expect(find.byKey(const Key('void-receipt')), findsNothing);
    expect(t.takeException(), isNull);

    // Zum Vergleich: den Barverkauf darf der Chef stornieren.
    await openReceipt(t, 1);
    expect(find.byKey(const Key('void-receipt')), findsOneWidget);
  });

  testWidgets('auf Arabisch stehen Namen der Personen als eigener '
      'Abschnitt', (t) async {
    await pumpBonsWithSales(t, 1);
    await _startVoid(t, 1);
    await t.tap(find.byKey(const Key('confirm-void')));
    await t.pumpAndSettle();
    final repo = containerOf(t).read(settingsRepositoryProvider);
    await repo.save((await repo.current()).copyWith(language: AppLanguage.ar));
    await t.pumpAndSettle();
    await openReceipt(t, 1);
    // "Boniert von" und "Storniert von ... zählt nicht".
    expect(find.textContaining('\u2068Anna\u2069'), findsNWidgets(2));
    await openReceipt(t, 2);
    expect(find.textContaining('\u2068Anna\u2069'), findsOneWidget);
  });

  group('Küchenbon drucken im Bon-Detail', () {
    Future<FakeKitchenService> pumpWithKitchen(
      WidgetTester t,
      int sales, {
      KitchenMode mode = KitchenMode.receiptPrinter,
      String pin = '1234',
    }) async {
      final kitchen = FakeKitchenService();
      await pumpBonsWithSales(
        t,
        sales,
        pin: pin,
        overrides: [
          ...await memoryOverrides(),
          kitchenServiceProvider.overrideWithValue(kitchen),
        ],
      );
      final repo = containerOf(t).read(settingsRepositoryProvider);
      await repo.save((await repo.current()).copyWith(kitchenMode: mode));
      await t.pumpAndSettle();
      return kitchen;
    }

    testWidgets('Küchenbon aus: keine Taste', (t) async {
      await pumpWithKitchen(t, 1, mode: KitchenMode.off);
      await setUpPrinter(t);
      await openReceipt(t, 1);
      expect(find.byKey(const Key('print-receipt')), findsOneWidget);
      expect(find.byKey(const Key('print-kitchen')), findsNothing);
    });

    testWidgets('eingeschaltet: Taste neben "Drucken", druckt als Kopie', (
      t,
    ) async {
      final kitchen = await pumpWithKitchen(t, 2);
      await setUpPrinter(t);
      await openReceipt(t, 2);
      final print = t.getRect(find.byKey(const Key('print-receipt')));
      final again = t.getRect(find.byKey(const Key('print-kitchen')));
      expect(again.top, print.top);
      expect(again.height, greaterThanOrEqualTo(48));
      expect(find.text('Küchenbon drucken'), findsOneWidget);
      // Stornieren bleibt erreichbar.
      expect(find.byKey(const Key('void-receipt')), findsOneWidget);
      expect(t.takeException(), isNull);

      await t.tap(find.byKey(const Key('print-kitchen')));
      await t.pumpAndSettle();
      expect(kitchen.calls, ['for:2:copy']);
      expect(find.text('Küchenbon gedruckt.'), findsOneWidget);
      expect(printerOf(t).log, isEmpty);
    });

    testWidgets('ohne Bondrucker steht die Taste über "Stornieren", ganz '
        'breit', (t) async {
      await pumpWithKitchen(t, 1, mode: KitchenMode.kitchenPrinter);
      await openReceipt(t, 1);
      expect(find.byKey(const Key('print-receipt')), findsNothing);
      final kitchen = t.getRect(find.byKey(const Key('print-kitchen')));
      final cancel = t.getRect(find.byKey(const Key('void-receipt')));
      expect(kitchen.bottom, lessThan(cancel.top));
      expect(kitchen.width, cancel.width);
    });

    testWidgets('gescheitert: Meldung des Druckers als Hinweis', (t) async {
      final kitchen = await pumpWithKitchen(t, 1);
      await openReceipt(t, 1);
      kitchen.next = const PrintOutcome.failed(PrintProblem.paperOut);
      await t.tap(find.byKey(const Key('print-kitchen')));
      await t.pumpAndSettle();
      expect(
        find.text('Drucker nicht bereit. Das Papier ist leer.'),
        findsOneWidget,
      );
    });

    testWidgets('nichts für die Küche: der Hinweis sagt das', (t) async {
      final kitchen = await pumpWithKitchen(t, 1);
      await openReceipt(t, 1);
      kitchen.next = null;
      await t.tap(find.byKey(const Key('print-kitchen')));
      await t.pumpAndSettle();
      expect(kitchen.calls, ['for:1:copy']);
      expect(
        find.text('Auf diesem Bon ist nichts für die Küche.'),
        findsOneWidget,
      );
    });

    testWidgets('Küchendrucker fehlt: der Hinweis sagt das', (t) async {
      final kitchen = await pumpWithKitchen(
        t,
        1,
        mode: KitchenMode.kitchenPrinter,
      );
      await openReceipt(t, 1);
      kitchen.next = const PrintOutcome.failed(PrintProblem.notSetUp);
      await t.tap(find.byKey(const Key('print-kitchen')));
      await t.pumpAndSettle();
      expect(
        find.text('Kein Küchendrucker eingerichtet. Es kommt kein Küchenbon.'),
        findsOneWidget,
      );
    });

    testWidgets('weitere Tipps, solange gedruckt wird, drucken nicht noch '
        'einmal', (t) async {
      final kitchen = await pumpWithKitchen(t, 1);
      await openReceipt(t, 1);
      final hold = kitchen.hold = Completer<void>();
      await t.tap(find.byKey(const Key('print-kitchen')));
      await t.pump();
      await t.tap(find.byKey(const Key('print-kitchen')));
      await t.pump();
      expect(kitchen.calls, ['for:1:copy']);
      kitchen.hold = null;
      hold.complete();
      await t.pumpAndSettle();
    });

    testWidgets('der stornierte Verkauf hat keine Taste; der Storno-Bon '
        'druckt den STORNO-Zettel noch einmal', (t) async {
      final kitchen = await pumpWithKitchen(t, 1);
      await _startVoid(t, 1);
      await t.tap(find.byKey(const Key('confirm-void')));
      await t.pumpAndSettle();
      expect(kitchen.calls, ['for:2']);
      await openReceipt(t, 1);
      expect(find.byKey(const Key('print-kitchen')), findsNothing);
      await openReceipt(t, 2);
      expect(find.text('Storno'), findsWidgets);
      expect(find.byKey(const Key('print-kitchen')), findsOneWidget);
      await t.tap(find.byKey(const Key('print-kitchen')));
      await t.pumpAndSettle();
      // Als Kopie: der Zettel bleibt STORNO (Küchenbon-Bau, getestet).
      expect(kitchen.calls, ['for:2', 'for:2:copy']);
      expect(find.text('Küchenbon gedruckt.'), findsOneWidget);
    });

    testWidgets('Storno, der Küchenbon scheitert: Hinweis mit Grund und '
        '"Küchenbon drucken"', (t) async {
      final kitchen = await pumpWithKitchen(t, 1);
      kitchen.next = const PrintOutcome.failed(PrintProblem.paperOut);
      await _startVoid(t, 1);
      await t.tap(find.byKey(const Key('confirm-void')));
      await t.pumpAndSettle();
      final box = find.byKey(const Key('void-kitchen'));
      expect(
        find.descendant(
          of: box,
          matching: find.text('Küchenbon nicht gedruckt'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: box,
          matching: find.text('Drucker nicht bereit. Das Papier ist leer.'),
        ),
        findsOneWidget,
      );
      final button = find.byKey(const Key('void-kitchen-reprint'));
      expect(t.getSize(button).height, greaterThanOrEqualTo(64));
      kitchen.next = const PrintOutcome.ok();
      await t.tap(button);
      await t.pumpAndSettle();
      expect(kitchen.calls, ['for:2', 'for:2:copy']);
      expect(
        find.descendant(
          of: box,
          matching: find.text('Küchenbon gedruckt.'),
          matchRoot: true,
        ),
        findsOneWidget,
      );
      expect(button, findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('Storno, der Küchenbon kommt: kein Hinweis', (t) async {
      final kitchen = await pumpWithKitchen(t, 1);
      await _startVoid(t, 1);
      await t.tap(find.byKey(const Key('confirm-void')));
      await t.pumpAndSettle();
      expect(kitchen.calls, ['for:2']);
      expect(find.byKey(const Key('void-kitchen')), findsNothing);
      expect(find.text('Küchenbon nicht gedruckt'), findsNothing);
    });

    testWidgets('Storno, nichts davon für die Küche (null): kein Hinweis', (
      t,
    ) async {
      final kitchen = await pumpWithKitchen(t, 1);
      kitchen.next = null;
      await _startVoid(t, 1);
      await t.tap(find.byKey(const Key('confirm-void')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('void-kitchen')), findsNothing);
    });

    for (final language in AppLanguage.values) {
      testWidgets('drei Tasten ohne Überlauf (${language.name})', (t) async {
        await pumpWithKitchen(t, 1);
        await setUpPrinter(t);
        final repo = containerOf(t).read(settingsRepositoryProvider);
        await repo.save((await repo.current()).copyWith(language: language));
        await t.pumpAndSettle();
        await openReceipt(t, 1);
        expect(find.byKey(const Key('print-kitchen')), findsOneWidget);
        expect(find.byKey(const Key('void-receipt')), findsOneWidget);
        expect(t.takeException(), isNull);
        // Die Beschriftung steht ganz da, ohne Auslassungspunkte.
        final label = find.descendant(
          of: find.byKey(const Key('print-kitchen')),
          matching: find.byType(RichText),
        );
        final box = t.renderObject<RenderParagraph>(label.first);
        expect(box.didExceedMaxLines, isFalse);
      });
    }
  });
}
