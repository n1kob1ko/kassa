import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/core/money.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/data/receipt_repository.dart';
import 'package:kassa/domain/cart.dart';
import 'package:kassa/domain/receipt.dart';
import 'package:kassa/domain/staff.dart';
import 'package:kassa/ui/pressable.dart';
import 'package:material_ui/material_ui.dart';

import '../support/bons_pump.dart';
import '../support/cash_pump.dart';
import '../support/demo_fixtures.dart';
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

void main() {
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
  });

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
}
