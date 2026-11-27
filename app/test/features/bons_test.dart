import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/core/app_language.dart';
import 'package:kassa/core/clock.dart';
import 'package:kassa/core/money.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/delivery_repository.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/data/receipt_repository.dart';
import 'package:kassa/devices/printer.dart';
import 'package:kassa/domain/cart.dart';
import 'package:kassa/domain/receipt.dart';
import 'package:kassa/domain/staff.dart';
import 'package:kassa/domain/voucher.dart';
import 'package:kassa/features/kassa/kitchen_service.dart';
import 'package:kassa/features/kassa/late_kitchen.dart';
import 'package:kassa/features/login/session.dart';
import 'package:kassa/ui/pressable.dart';
import 'package:kassa/ui/tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../support/bons_pump.dart';
import '../support/cash_pump.dart';
import '../support/demo_fixtures.dart';
import '../support/digital_pump.dart';
import '../support/fake_devices.dart';
import '../support/kassa_pump.dart';
import '../support/pump.dart';
import '../support/sales.dart' show cart, discounted;

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

/// Verkauft den Bon `cart` (18,20 €) mit [cashPartCents] bar und dem Rest
/// mit Karte, mit [tipCents] Trinkgeld.
Future<Receipt> _sellSplit(
  WidgetTester t, {
  String saleId = 'split-1',
  int cashPartCents = 0,
  int tipCents = 0,
}) {
  final staff = containerOf(t).read(sessionProvider)!;
  return containerOf(t)
      .read(receiptRepositoryProvider)
      .finalizeCardSale(
        saleId: saleId,
        cart: cart,
        staff: staff,
        provider: 'sumup',
        txCode: 'TX-$saleId',
        cashPartCents: cashPartCents,
        tipCents: tipCents,
      );
}

/// Bons neu öffnen, damit die Liste die eben angelegten Bons zeigt.
Future<void> _reopenBons(WidgetTester t) async {
  await t.tap(find.byKey(const Key('tab-Kassa')));
  await t.pump();
  await t.tap(find.byKey(const Key('tab-Bons')));
  await t.pumpAndSettle();
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

  testWidgets(
    'gemischter Bon: Pille "Bar + Karte", zu sehen unter "Bar" und unter "Karte"',
    (t) async {
      await pumpBonsWithSales(t, 0);
      final staff = containerOf(t).read(sessionProvider)!;
      await containerOf(t)
          .read(receiptRepositoryProvider)
          .finalizeCardSale(
            saleId: 'mixed-1',
            cart: const Cart.empty().add(teigtaschen).add(cola),
            staff: staff,
            provider: 'sumup',
            txCode: 'TX-M1',
            cardScheme: 'VISA',
            cardLast4: '4242',
            cashPartCents: 500,
            tipCents: 50,
          );
      await t.tap(find.byKey(const Key('tab-Kassa')));
      await t.pump();
      await t.tap(find.byKey(const Key('tab-Bons')));
      await t.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const Key('receipt-1')),
          matching: find.text('Bar + Karte'),
        ),
        findsOneWidget,
      );
      for (final f in ['bar', 'karte']) {
        await t.tap(find.byKey(Key('filter-$f')));
        await t.pumpAndSettle();
        expect(find.byKey(const Key('receipt-1')), findsOneWidget);
      }
      await t.tap(find.byKey(const Key('receipt-1')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('detail-payment-0')), findsOneWidget);
      expect(find.byKey(const Key('detail-payment-1')), findsOneWidget);
      // Bar vor Karte, je mit ihrem Teil; kein "Gegeben" bei zwei Zahlungen.
      expect(
        find.descendant(
          of: find.byKey(const Key('detail-payment-0')),
          matching: find.text(formatEuro(500)),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('detail-payment-1')),
          matching: find.text(formatEuro(515)),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('detail-tip')),
          matching: find.text(formatEuro(50)),
        ),
        findsOneWidget,
      );
      expect(find.text('Gegeben'), findsNothing);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('Storno-Frage beim gemischten Bon mit Trinkgeld', (t) async {
    await pumpBonsWithSales(t, 0);
    await _sellSplit(t, cashPartCents: 1000, tipCents: 80);
    await _reopenBons(t);
    await _startVoid(t, 1);
    expect(
      textOf(t, const Key('void-cash-back')),
      '10,00 € bar zurückgeben.',
    );
    expect(
      textOf(t, const Key('void-card-hint')),
      '9,00 € bei SumUp zurückbuchen, davon 0,80 € Trinkgeld.',
    );
    expect(find.text('Du gibst 18,20 € bar zurück.'), findsNothing);
    expect(
      find.text('Stornieren, Rückbuchung mache ich in SumUp'),
      findsOneWidget,
    );
    expect(t.takeException(), isNull);
  });

  testWidgets('Storno-Frage beim gemischten Bon ohne Trinkgeld und beim '
      'Karten-Bon mit Trinkgeld', (t) async {
    await pumpBonsWithSales(t, 0);
    await _sellSplit(t, cashPartCents: 1000);
    await _sellSplit(t, saleId: 'tip-only', tipCents: 80);
    await _reopenBons(t);
    await _startVoid(t, 1);
    expect(
      textOf(t, const Key('void-cash-back')),
      '10,00 € bar zurückgeben.',
    );
    expect(
      textOf(t, const Key('void-card-hint')),
      '8,20 € bei SumUp zurückbuchen.',
    );
    await t.tap(find.byKey(const Key('cancel-void')));
    await t.pumpAndSettle();
    await _startVoid(t, 2);
    expect(find.byKey(const Key('void-cash-back')), findsNothing);
    expect(
      textOf(t, const Key('void-card-hint')),
      '19,00 € bei SumUp zurückbuchen, davon 0,80 € Trinkgeld.',
    );
  });

  testWidgets('Storno-Frage bei einem Bar-Bon: der Text von 1.10.0', (
    t,
  ) async {
    await pumpBonsWithSales(t, 1);
    await _startVoid(t, 1);
    expect(find.text('Du gibst 3,15 € bar zurück.'), findsOneWidget);
    expect(find.byKey(const Key('void-cash-back')), findsNothing);
    expect(find.byKey(const Key('void-card-hint')), findsNothing);
    expect(find.text('Ja, stornieren'), findsOneWidget);
  });

  testWidgets('Detail zeigt Zeilen-Rabatt, Bon-Rabatt und Trinkgeld', (
    t,
  ) async {
    await pumpBonsWithSales(t, 0);
    final staff = containerOf(t).read(sessionProvider)!;
    // 15,36 €: 10,00 € bar, 5,36 € mit Karte, dazu 0,64 € Trinkgeld.
    await containerOf(t)
        .read(receiptRepositoryProvider)
        .finalizeCardSale(
          saleId: 'discounted-1',
          cart: discounted,
          staff: staff,
          provider: 'sumup',
          cardScheme: 'VISA',
          cardLast4: '4242',
          cashPartCents: 1000,
          tipCents: 64,
        );
    await t.tap(find.byKey(const Key('tab-Kassa')));
    await t.pump();
    await t.tap(find.byKey(const Key('tab-Bons')));
    await t.pumpAndSettle();
    await openReceipt(t, 1);

    // Die Huhn Bowl (Stelle 1) hat 10 % Stammgast, die Cola keinen Rabatt.
    expect(find.byKey(const Key('detail-line-discount-0')), findsNothing);
    expect(textOf(t, const Key('detail-line-discount-1')), formatEuro(-119));
    expect(find.text('−10 % Stammgast'), findsOneWidget);
    expect(find.text('Zwischensumme'), findsOneWidget);
    expect(find.text(formatEuro(1651)), findsOneWidget);
    expect(find.text('−10 % Aktion'), findsOneWidget);
    expect(textOf(t, const Key('detail-discount')), formatEuro(-165));
    expect(textOf(t, const Key('detail-total')), formatEuro(1536));
    // Die Karte mit dem gebuchten Betrag (5,36 € + 0,64 €) wie am Bon,
    // darunter das Trinkgeld.
    expect(
      find.descendant(
        of: find.byKey(const Key('detail-payment-1')),
        matching: find.text(formatEuro(600)),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('detail-tip')),
        matching: find.text('davon Trinkgeld'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('detail-tip')),
        matching: find.text(formatEuro(64)),
      ),
      findsOneWidget,
    );
    expect(t.takeException(), isNull);
  });

  testWidgets('nur Karte mit Trinkgeld: die Karte mit dem gebuchten Betrag, '
      'darunter "davon Trinkgeld"', (t) async {
    await pumpBonsWithSales(t, 0);
    final staff = containerOf(t).read(sessionProvider)!;
    // 9,65 € mit Karte, dazu 0,35 € Trinkgeld.
    await containerOf(t)
        .read(receiptRepositoryProvider)
        .finalizeCardSale(
          saleId: 'tip-1',
          cart: const Cart.empty().add(teigtaschen).add(cola),
          staff: staff,
          provider: 'sumup',
          tipCents: 35,
        );
    await t.tap(find.byKey(const Key('tab-Kassa')));
    await t.pump();
    await t.tap(find.byKey(const Key('tab-Bons')));
    await t.pumpAndSettle();
    await openReceipt(t, 1);

    expect(
      find.descendant(
        of: find.byKey(const Key('detail-payment-0')),
        matching: find.text(formatEuro(1000)),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('detail-payment-1')), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('detail-tip')),
        matching: find.text('davon Trinkgeld'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('detail-tip')),
        matching: find.text(formatEuro(35)),
      ),
      findsOneWidget,
    );
    expect(t.takeException(), isNull);
  });

  testWidgets('Detail ohne Rabatt und Trinkgeld: keine der Zeilen', (t) async {
    await pumpBonsWithSales(t, 1);
    await openReceipt(t, 1);
    expect(find.byKey(const Key('detail-line-discount-0')), findsNothing);
    expect(find.byKey(const Key('detail-line-discount-1')), findsNothing);
    expect(find.byKey(const Key('detail-discount')), findsNothing);
    expect(find.byKey(const Key('detail-tip')), findsNothing);
    expect(find.text('Zwischensumme'), findsNothing);
  });

  testWidgets('eine Bar-Zahlung: eine Zeile, dazu "Gegeben" und "Rückgeld"', (
    t,
  ) async {
    await pumpBonsWithSales(t, 1);
    await openReceipt(t, 1);
    expect(find.byKey(const Key('detail-payment-0')), findsOneWidget);
    expect(find.byKey(const Key('detail-payment-1')), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('detail-payment-0')),
        matching: find.text('Bar'),
      ),
      findsOneWidget,
    );
    expect(find.text('Gegeben'), findsOneWidget);
    expect(find.text('Rückgeld'), findsOneWidget);
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

    /// Bon [number] steht als nicht gedruckter Küchenbon im Hinweis der Kassa.
    Future<void> lateFailure(WidgetTester t, int number) async {
      final c = containerOf(t);
      final rows = await queryRows(
        t,
        'SELECT id FROM receipts WHERE number = $number',
      );
      final receipt = await c
          .read(receiptRepositoryProvider)
          .byId(rows.single['id']! as String);
      c
          .read(lateKitchenProvider.notifier)
          .follow(
            receipt,
            Future.value(const PrintOutcome.failed(PrintProblem.paperOut)),
          );
      await t.pumpAndSettle();
      expect(c.read(lateKitchenProvider), hasLength(1));
    }

    testWidgets('Storno eines Verkaufs aus dem Hinweis der Kassa: der Hinweis '
        'geht weg', (t) async {
      await pumpWithKitchen(t, 1);
      await lateFailure(t, 1);
      await _startVoid(t, 1);
      await t.tap(find.byKey(const Key('confirm-void')));
      await t.pumpAndSettle();
      expect(containerOf(t).read(lateKitchenProvider), isEmpty);
    });

    testWidgets('hier gedruckt: der Hinweis der Kassa geht weg; gescheitert '
        'bleibt er', (t) async {
      final kitchen = await pumpWithKitchen(t, 1);
      await lateFailure(t, 1);
      await openReceipt(t, 1);
      kitchen.next = const PrintOutcome.failed(PrintProblem.coverOpen);
      await t.tap(find.byKey(const Key('print-kitchen')));
      await t.pumpAndSettle();
      expect(containerOf(t).read(lateKitchenProvider), hasLength(1));
      kitchen.next = const PrintOutcome.ok();
      await t.tap(find.byKey(const Key('print-kitchen')));
      await t.pumpAndSettle();
      expect(kitchen.calls, ['for:1:copy', 'for:1:copy']);
      expect(containerOf(t).read(lateKitchenProvider), isEmpty);
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

  testWidgets('Detail: Gutschein nachdrucken; Storno nach dem Einlösen zeigt '
      'den Grund und speichert nichts', (t) async {
    await pumpBonsWithSales(t, 0);
    await setUpPrinter(t);
    // Bon 1: zwei Gutscheine verkauft; Bon 2: der erste teils eingelöst.
    final sold = await sellCash(
      t,
      cart: const Cart.empty()
          .addVoucherSale(valueCents: 2500)
          .add(cola)
          .addVoucherSale(valueCents: 1000),
    );
    final first = sold.soldVouchers.first;
    final staff = containerOf(t).read(sessionProvider)!;
    await containerOf(t)
        .read(receiptRepositoryProvider)
        .finalizeVoucherSale(
          saleId: 'einloesen',
          cart: const Cart.empty()
              .add(cola)
              .applyVoucher(
                AppliedVoucher(
                  voucherId: first.voucherId,
                  code: first.code,
                  balanceCents: 2500,
                ),
              ),
          staff: staff,
        );
    await t.pumpAndSettle();
    await openReceipt(t, 1);

    for (final (i, v) in sold.soldVouchers.indexed) {
      expect(
        find.descendant(
          of: find.byKey(Key('detail-voucher-$i')),
          matching: find.text(formatEuro(v.valueCents)),
        ),
        findsOneWidget,
      );
      expect(
        textOf(t, Key('detail-voucher-code-$i')),
        formatVoucherCode(v.code),
      );
      expect(
        t.getSize(find.byKey(Key('detail-voucher-print-$i'))).height,
        greaterThanOrEqualTo(48),
      );
    }
    await t.ensureVisible(find.byKey(const Key('detail-voucher-print-1')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('detail-voucher-print-1')));
    await t.pumpAndSettle();
    // Nur der Abschnitt, kein Bon.
    expect(printerOf(t).log, ['voucher:${sold.soldVouchers[1].voucherId}']);
    expect(printerOf(t).voucherSlips.single.voucher.valueCents, 1000);
    expect(printerOf(t).voucherSlips.single.soldAt, sold.createdAt);

    final before = await receiptCount(t);
    await _startVoid(t, 1);
    await t.tap(find.byKey(const Key('confirm-void')));
    await t.pumpAndSettle();
    expect(
      textOf(t, const Key('void-failure')),
      'Der Gutschein wurde schon eingelöst. Der Bon lässt sich nicht '
      'stornieren.',
    );
    expect(await receiptCount(t), before);
    expect(
      await queryRows(
        t,
        "SELECT kind FROM voucher_movements WHERE kind LIKE 'void%'",
      ),
      isEmpty,
    );
    // Nichts mehr gedruckt.
    expect(printerOf(t).log, hasLength(1));
  });

  testWidgets('Detail ohne Drucker: Wert und Code, keine Taste zum Drucken', (
    t,
  ) async {
    await pumpBonsWithSales(t, 0);
    final sold = await sellCash(
      t,
      cart: const Cart.empty().addVoucherSale(valueCents: 2500),
    );
    await t.pumpAndSettle();
    await openReceipt(t, 1);
    expect(
      textOf(t, const Key('detail-voucher-code-0')),
      formatVoucherCode(sold.soldVouchers.single.code),
    );
    expect(find.byKey(const Key('detail-voucher-print-0')), findsNothing);
  });

  testWidgets('Detail: eine Gutschein-Zahlung heißt "Gutschein 1234 5678" mit '
      'dem, was am Gutschein bleibt, nicht "Karte"', (t) async {
    await pumpBonsWithSales(t, 0);
    final sold = await sellCash(
      t,
      cart: const Cart.empty().addVoucherSale(valueCents: 2500),
    );
    final v = sold.soldVouchers.single;
    AppliedVoucher chosen(int balance) => AppliedVoucher(
      voucherId: v.voucherId,
      code: v.code,
      balanceCents: balance,
    );
    final staff = containerOf(t).read(sessionProvider)!;
    final receipts = containerOf(t).read(receiptRepositoryProvider);
    // Bon 2: nur Gutschein (Cola 3,15 €), Bon 3: Gutschein und bar.
    await receipts.finalizeVoucherSale(
      saleId: 'nur-gutschein',
      cart: const Cart.empty().add(cola).applyVoucher(chosen(2500)),
      staff: staff,
    );
    await receipts.finalizeCashSale(
      saleId: 'gutschein-und-bar',
      cart: const Cart.empty()
          .add(teigtaschen)
          .add(teigtaschen)
          .add(teigtaschen)
          .add(teigtaschen)
          .applyVoucher(chosen(2185)),
      givenCents: 500,
      staff: staff,
    );
    await t.pumpAndSettle();
    final label = 'Gutschein ${formatVoucherCode(v.code)}';

    expect(
      find.descendant(
        of: find.byKey(const Key('receipt-2')),
        matching: find.text('Karte'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('receipt-2')),
        matching: find.text('Gutschein'),
      ),
      findsOneWidget,
    );
    await openReceipt(t, 2);
    Finder inRow(String key, String text) => find.descendant(
      of: find.byKey(Key(key)),
      matching: find.text(text),
    );
    expect(inRow('detail-payment-0', label), findsOneWidget);
    expect(inRow('detail-payment-0', '3,15 €'), findsOneWidget);
    expect(inRow('detail-payment-0', 'Karte'), findsNothing);
    expect(inRow('detail-voucher-left-0', 'Bleibt am Gutschein'), findsOneWidget);
    expect(inRow('detail-voucher-left-0', '21,85 €'), findsOneWidget);
    expect(find.byKey(const Key('detail-payment-1')), findsNothing);

    await openReceipt(t, 3);
    // 4 × 6,50 € = 26,00 €: 21,85 € mit Gutschein, 4,15 € bar.
    expect(inRow('detail-payment-0', label), findsOneWidget);
    expect(inRow('detail-payment-0', '21,85 €'), findsOneWidget);
    expect(inRow('detail-voucher-left-0', '0,00 €'), findsOneWidget);
    expect(inRow('detail-payment-1', 'Bar'), findsOneWidget);
    expect(inRow('detail-payment-1', '4,15 €'), findsOneWidget);
  });

  testWidgets('Detail: Zeile Beleg mit den Zeiten; QR-Code nur bei digitalem '
      'Wert; ein Bon ohne Schlüssel hat keinen', (t) async {
    await pumpBonsWithSales(t, 2, overrides: await serverKassaOverrides());
    await setUpPrinter(t);
    final c = containerOf(t);
    final db = c.read(databaseProvider);
    Future<Receipt> byNumber(int n) async => (await c
        .read(receiptRepositoryProvider)
        .find(
          (await db
                  .customSelect('SELECT id FROM receipts WHERE number = $n')
                  .getSingle())
              .read<String>('id'),
        ))!;
    final first = await byNumber(1);
    final deliveries = c.read(deliveryRepositoryProvider);
    await deliveries.record(
      first.id,
      DeliveryKind.printed,
      at: DateTime(2026, 11, 17, 11, 3),
    );
    await deliveries.record(
      first.id,
      DeliveryKind.digital,
      at: DateTime(2026, 11, 17, 11, 4),
    );
    // Ein Bon aus 1.11.0: ohne Schlüssel der Seite.
    final day = (await db
            .customSelect('SELECT id FROM business_days WHERE closed_at IS NULL')
            .getSingle())
        .read<String>('id');
    await db
        .into(db.receiptRows)
        .insert(
          ReceiptRowsCompanion.insert(
            id: 'alt',
            number: 3,
            createdAt: DateTime(2026, 11, 17, 11, 5),
            staffId: 'anna',
            staffName: 'Anna',
            businessDayId: Value(day),
            kind: ReceiptKind.sale.name,
            goodsCents: 390,
            depositCents: 0,
            totalCents: 390,
          ),
        );
    await t.pumpAndSettle();

    // "Immer drucken": die Zeile Beleg, kein QR-Code.
    await openReceipt(t, 1);
    expect(find.text('Beleg'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('detail-delivery-printed')),
        matching: find.text('Gedruckt'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('detail-delivery-printed')),
        matching: find.text('11:03 Uhr'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('detail-delivery-digital')),
        matching: find.text('Digital angeboten'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('detail-delivery-digital')),
        matching: find.text('11:04 Uhr'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('detail-receipt-qr')), findsNothing);
    expect(find.byKey(const Key('receipt-qr-wait')), findsNothing);
    expect(find.byKey(const Key('print-receipt')), findsOneWidget);
    // Ohne Einträge keine Zeile.
    await openReceipt(t, 2);
    expect(find.byKey(const Key('detail-delivery-printed')), findsNothing);
    expect(find.byKey(const Key('detail-delivery-digital')), findsNothing);
    expect(find.text('Beleg'), findsNothing);

    // Digital gewählt, aber nicht gekoppelt: kein QR-Code.
    final settings = c.read(settingsRepositoryProvider);
    await settings.save(
      (await settings.current()).copyWith(
        receiptMode: ReceiptMode.printAndDigital,
      ),
    );
    await t.pumpAndSettle();
    expect(find.byKey(const Key('detail-receipt-qr')), findsNothing);
    expect(find.byKey(const Key('receipt-qr-wait')), findsNothing);

    // Gekoppelt: der Platzhalter, bis der Server den Bon hat, dann der Code.
    await pairRegister(t);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('receipt-qr-wait')), findsOneWidget);
    final second = await byNumber(2);
    await serverConfirms(t, second.id);
    await t.pumpAndSettle();
    expect(
      qrTextOf(t, 'detail-receipt-qr'),
      '$testServerUrl/beleg/${second.publicToken}',
    );
    expect(find.byKey(const Key('print-receipt')), findsOneWidget);

    // Der Bon aus 1.11.0 hat keinen.
    await openReceipt(t, 3);
    expect(find.byKey(const Key('detail-receipt-qr')), findsNothing);
    expect(find.byKey(const Key('receipt-qr-wait')), findsNothing);
    expect(find.byKey(const Key('print-receipt')), findsOneWidget);

    // "Digital, Druck auf Wunsch" zeigt ihn ebenso.
    await settings.save(
      (await settings.current()).copyWith(
        receiptMode: ReceiptMode.digitalOnRequest,
      ),
    );
    await openReceipt(t, 2);
    expect(find.byKey(const Key('detail-receipt-qr')), findsOneWidget);
    // Der Code im Detail ist keine Belegerteilung: für Bon 2 steht nichts.
    await t.pumpAndSettle();
    expect(
      await queryRows(
        t,
        "SELECT kind FROM receipt_deliveries WHERE receipt_id = '${second.id}'",
      ),
      isEmpty,
    );
    expect(find.byKey(const Key('detail-delivery-digital')), findsNothing);

    // Ein Sonderbeleg (Startbeleg) mit Schlüssel hat keinen Code.
    await db
        .into(db.receiptRows)
        .insert(
          ReceiptRowsCompanion.insert(
            id: 'start',
            number: 4,
            createdAt: DateTime(2026, 11, 17, 11, 6),
            staffId: 'anna',
            staffName: 'Anna',
            businessDayId: Value(day),
            kind: ReceiptKind.start.name,
            goodsCents: 0,
            depositCents: 0,
            totalCents: 0,
            publicToken: const Value('schluessel-des-startbelegs'),
          ),
        );
    await t.pumpAndSettle();
    await openReceipt(t, 4);
    expect(find.byKey(const Key('detail-receipt-qr')), findsNothing);
    expect(find.byKey(const Key('receipt-qr-wait')), findsNothing);
  });

  testWidgets('"Immer drucken" mit Drucker: im Detail die Zeile Beleg mit '
      '"Gedruckt" und der Zeit, kein QR-Code; genau ein Eintrag delivery, '
      'ein zweiter Druck bringt keinen', (t) async {
    await pumpKassa(t);
    await setUpPrinter(t);
    await tapItem(t, 'cola');
    await t.tap(find.byKey(const Key('pay-cash')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('finish-sale')));
    await t.pumpAndSettle();
    final id = (await queryRows(t, 'SELECT id FROM receipts')).single['id'];
    await t.tap(find.byKey(const Key('next-customer')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('tab-Bons')));
    await t.pumpAndSettle();
    await openReceipt(t, 1);
    expect(find.text('Beleg'), findsOneWidget);
    for (final text in ['Gedruckt', '11:00 Uhr']) {
      expect(
        find.descendant(
          of: find.byKey(const Key('detail-delivery-printed')),
          matching: find.text(text),
        ),
        findsOneWidget,
        reason: text,
      );
    }
    expect(find.byKey(const Key('detail-delivery-digital')), findsNothing);
    expect(find.byKey(const Key('detail-receipt-qr')), findsNothing);
    expect(find.byKey(const Key('receipt-qr-wait')), findsNothing);
    Future<List<Map<String, Object?>>> deliveryEntries() => queryRows(
      t,
      "SELECT ref FROM outbox WHERE kind = 'delivery'",
    );
    expect(await deliveryEntries(), [
      {'ref': '$id/printed'},
    ]);
    await t.tap(find.byKey(const Key('print-receipt')));
    await t.pumpAndSettle();
    expect(printerOf(t).printed, [id, id]);
    expect(await deliveryEntries(), [
      {'ref': '$id/printed'},
    ]);
    await t.pump(const Duration(seconds: 8));
    await t.pumpAndSettle();
  });
}
