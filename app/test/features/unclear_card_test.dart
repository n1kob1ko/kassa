import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/app.dart';
import 'package:kassa/core/clock.dart';
import 'package:kassa/core/money.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/devices/card_terminal.dart';
import 'package:kassa/devices/printer.dart';
import 'package:kassa/domain/cart.dart';
import 'package:kassa/domain/catalog.dart' show TaxRate;
import 'package:kassa/domain/discount.dart';
import 'package:kassa/domain/staff.dart';
import 'package:kassa/domain/voucher.dart';
import 'package:kassa/core/app_language.dart';
import 'package:kassa/features/kassa/kitchen_service.dart';
import 'package:kassa/ui/primary_button.dart';
import 'package:material_ui/material_ui.dart';

import '../support/cash_pump.dart';
import '../support/demo_fixtures.dart';
import '../support/fake_devices.dart';
import '../support/fake_server.dart';
import '../support/kassa_pump.dart';
import '../support/pump.dart';
import '../support/sales.dart';
import '../support/server_pull.dart';
import '../support/settings_pump.dart';

const _anna = Staff(id: 'anna', name: 'Anna', role: StaffRole.staff);

/// Eine offene Zahlung aus einem früheren Lauf: [id], Bon und Startzeit.
typedef _Open = (String, Cart, DateTime);

final _first = DateTime(2026, 11, 17, 12, 4);
final _second = DateTime(2026, 11, 17, 12, 30);

/// Datenbank mit offenen Zahlungen, noch vor dem Start der Oberfläche.
/// [draft] legt den Entwurf der Kassa an, wie ihn ein Absturz hinterlässt.
Future<List<Override>> _setup({
  List<_Open> open = const [],
  Cart? draft,
  FakeCardTerminal? terminal,
  FakePrinter? printer,
}) async {
  final clock = FixedClock(_first);
  final overrides = await memoryOverrides(
    clock: clock,
    terminal: terminal,
    printer: printer,
  );
  final c = ProviderContainer(overrides: overrides);
  try {
    final staff = await c.read(staffRepositoryProvider).all();
    final anna = staff.firstWhere((s) => s.name == 'Anna');
    for (final (id, cart, at) in open) {
      clock.value = at;
      await c
          .read(cardPaymentRepositoryProvider)
          .begin(paymentId: id, cart: cart, staff: anna);
    }
    clock.value = DateTime(2026, 11, 17, 13);
    if (draft != null) {
      await c
          .read(settingsRepositoryProvider)
          .writeDraft(jsonEncode(draft.toJson()));
    }
  } finally {
    c.dispose();
  }
  return overrides;
}

Future<void> _start(WidgetTester t, List<Override> overrides) async {
  await pumpKassa(t, overrides: overrides);
  await t.pumpAndSettle();
}

Finder _inSheet(String text) =>
    find.descendant(of: _sheet, matching: find.text(text));

Finder get _sheet => find.byKey(const Key('unclear-card'));

Future<void> _tap(WidgetTester t, String key) async {
  await t.tap(find.byKey(Key(key)));
  await t.pumpAndSettle();
}

Future<int> _pending(WidgetTester t) async =>
    (await containerOf(t).read(cardPaymentRepositoryProvider).pending()).length;

Future<List<Map<String, Object?>>> _receipts(WidgetTester t) =>
    queryRows(t, 'SELECT id, kind FROM receipts');

String _json(Cart c) => jsonEncode(c.toJson());

/// Datenbank mit einer offenen, unklaren Zahlung von Anna über [cart]: mit
/// [tipCents] so, wie die Kassa sie heute schreibt; mit [v110] nur mit den
/// Spalten, die 1.10.0 kannte (Bar-Teil und Trinkgeld bleiben beim
/// Vorgabewert der Migration).
Future<List<Override>> _setupTipped({
  int tipCents = 0,
  bool v110 = false,
}) async {
  final overrides = await memoryOverrides(clock: FixedClock(_first));
  final c = ProviderContainer(overrides: overrides);
  try {
    final staff = await c.read(staffRepositoryProvider).all();
    final anna = staff.firstWhere((s) => s.name == 'Anna');
    if (v110) {
      await c.read(databaseProvider).customStatement(
        'INSERT INTO pending_card_payments (id, cart_json, amount_cents, '
        'staff_id, staff_name, started_at, state) '
        'VALUES (?, ?, ?, ?, ?, ?, ?)',
        [
          'p1',
          _json(cart),
          cart.totalCents,
          anna.id,
          anna.name,
          _first.millisecondsSinceEpoch ~/ 1000,
          'unknown',
        ],
      );
    } else {
      final repo = c.read(cardPaymentRepositoryProvider);
      await repo.begin(
        paymentId: 'p1',
        cart: cart,
        staff: anna,
        tipCents: tipCents,
      );
      await repo.markUnknown('p1');
    }
  } finally {
    c.dispose();
  }
  return overrides;
}

void main() {
  testWidgets('ohne offene Zahlung erscheint nichts', (t) async {
    await _start(t, await _setup());
    expect(_sheet, findsNothing);
    expect(find.byKey(const Key('area-kassa')), findsOneWidget);
  });

  testWidgets('eine gestartete Zahlung aus einem früheren Lauf erscheint '
      'nach dem Anmelden', (t) async {
    final overrides = await _setup(open: [('p1', cart, _first)]);
    // Vor der Anmeldung liegt nichts über der Anmeldung.
    await pumpApp(t, const KassaApp(), overrides: overrides);
    await t.pumpAndSettle();
    expect(_sheet, findsNothing);
    await typePin(t, '1234');
    await t.pumpAndSettle();
    expect(_sheet, findsOneWidget);
    expect(find.text('War diese Kartenzahlung erfolgreich?'), findsOneWidget);
    expect(find.text('18,20 €'), findsOneWidget);
    expect(find.text('Gestartet um 12:04 von Anna'), findsOneWidget);
    expect(find.text('2 × Cola 0,33 l'), findsOneWidget);
    expect(_inSheet('Huhn Bowl'), findsOneWidget);
    expect(
      find.text(
        'Die Kassa hat von SumUp keine Antwort bekommen. Schau in der '
        'SumUp-App unter Verkäufe nach, ob 18,20 € um 12:04 angekommen ist.',
      ),
      findsOneWidget,
    );
    expect(find.text('Ja, ist angekommen'), findsOneWidget);
    expect(find.text('Nein, nicht angekommen'), findsOneWidget);
    expect(t.getSize(find.byKey(const Key('unclear-paid'))).height, 80);
    expect(t.getSize(find.byKey(const Key('unclear-not-paid'))).height, 80);
    expect(find.byKey(const Key('unclear-confirm')), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('in einer anderen Sprache: Namen aus dem Wörterbuch, der Name '
      'der Person als eigener Abschnitt', (t) async {
    await _start(t, await _setup(open: [('p1', cart, _first)]));
    await containerOf(t).read(translationRepositoryProvider).upsert({
      'Cola 0,33 l': {'tr': 'Kola 0,33 l', 'ar': 'كولا'},
      'Huhn Bowl': {'tr': 'Tavuk Bowl'},
    });
    final repo = containerOf(t).read(settingsRepositoryProvider);
    await repo.save((await repo.current()).copyWith(language: AppLanguage.tr));
    await t.pumpAndSettle();
    expect(_inSheet('2 × Kola 0,33 l'), findsOneWidget);
    expect(_inSheet('Tavuk Bowl'), findsOneWidget);

    await repo.save((await repo.current()).copyWith(language: AppLanguage.ar));
    await t.pumpAndSettle();
    expect(_inSheet('2 × \u2068كولا\u2069'), findsOneWidget);
    // Ohne Übersetzung: der Name der Speisekarte, eigener Abschnitt.
    expect(_inSheet('\u2068Huhn Bowl\u2069'), findsOneWidget);
    expect(
      find.descendant(
        of: _sheet,
        matching: find.textContaining('\u2068Anna\u2069'),
      ),
      findsOneWidget,
    );
    // Gespeichert bleibt der Bon der Zahlung, wie er war.
    expect(await _pending(t), 1);
  });

  testWidgets('mehr als vier Zeilen: vier, dann "und 3 weitere"', (t) async {
    final big = const Cart.empty()
        .add(cola)
        .add(teigtaschen)
        .add(huhnBowl, options: [xxl, nudeln])
        .add(huhnBowl, options: [normal, reis])
        .add(leitungswasser)
        .add(catalog.item('pommes'))
        .add(catalog.item('mochi'));
    expect(big.lines.length, greaterThan(4));
    await _start(t, await _setup(open: [('p1', big, _first)]));
    final more = big.lines.length - 4;
    expect(find.text('und $more weitere'), findsOneWidget);
    expect(find.byKey(const Key('unclear-line-3')), findsOneWidget);
    expect(find.byKey(const Key('unclear-line-4')), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('Ja und Bestätigen: ein Bon mit Karte, gedruckt, Blatt weg', (
    t,
  ) async {
    final printer = FakePrinter();
    await _start(
      t,
      await _setup(open: [('p1', cart, _first)], printer: printer),
    );
    await setUpPrinter(t);
    await _tap(t, 'unclear-paid');
    expect(
      find.text('Die Kassa schreibt den Bon als Kartenzahlung und druckt ihn.'),
      findsOneWidget,
    );
    expect(await _receipts(t), isEmpty);
    expect(t.getSize(find.byKey(const Key('unclear-confirm'))).height, 80);
    await _tap(t, 'unclear-confirm');
    expect(_sheet, findsNothing);
    final rows = await queryRows(
      t,
      "SELECT r.id, p.kind FROM receipts r JOIN payments p ON p.receipt_id = r.id",
    );
    expect(rows.single['id'], 'p1');
    expect(rows.single['kind'], 'card');
    expect(await _pending(t), 0);
    expect(printer.printed, ['p1']);
  });

  testWidgets('Ja und Bestätigen, der Küchenbon scheitert: über dem Bon '
      'steht der Hinweis mit "Küchenbon drucken"', (t) async {
    final kitchen = FakeKitchenService()
      ..next = const PrintOutcome.failed(PrintProblem.unreachable);
    await _start(t, [
      ...await _setup(open: [('p1', cart, _first)]),
      kitchenServiceProvider.overrideWithValue(kitchen),
    ]);
    final repo = containerOf(t).read(settingsRepositoryProvider);
    await repo.save(
      (await repo.current()).copyWith(kitchenMode: KitchenMode.kitchenPrinter),
    );
    await t.pumpAndSettle();
    await _tap(t, 'unclear-paid');
    await _tap(t, 'unclear-confirm');
    expect(_sheet, findsNothing);
    expect(kitchen.calls, ['for:1']);
    final notice = find.byKey(const Key('late-kitchen'));
    expect(
      find.descendant(
        of: notice,
        matching: find.text('Küchenbon nicht gedruckt'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: notice, matching: find.text('Bon Nr. 1')),
      findsOneWidget,
    );
    kitchen.next = const PrintOutcome.ok();
    await _tap(t, 'late-kitchen-reprint');
    expect(kitchen.calls, ['for:1', 'for:1']);
    expect(notice, findsNothing);
  });

  testWidgets('Nein und Bestätigen: kein Bon, die Artikel liegen wieder auf '
      'dem Bon, Blatt weg', (t) async {
    await _start(t, await _setup(open: [('p1', cart, _first)]));
    expect(cartOf(t).isEmpty, isTrue);
    await _tap(t, 'unclear-not-paid');
    expect(
      find.text(
        'Die Kassa verwirft die Zahlung und legt die Artikel wieder auf den '
        'Bon.',
      ),
      findsOneWidget,
    );
    await _tap(t, 'unclear-confirm');
    expect(_sheet, findsNothing);
    expect(await _receipts(t), isEmpty);
    expect(await _pending(t), 0);
    expect(_json(cartOf(t)), _json(cart));
    expect(textOf(t, const Key('cart-total')), '18,20 €');
  });

  group('Texte und Ergebnis des Druckens', () {
    testWidgets('Ja ohne Drucker: kein Versprechen zu drucken, kein Hinweis', (
      t,
    ) async {
      await _start(t, await _setup(open: [('p1', cart, _first)]));
      await _tap(t, 'unclear-paid');
      expect(
        textOf(t, const Key('unclear-effect')),
        'Die Kassa schreibt den Bon als Kartenzahlung.',
      );
      await _tap(t, 'unclear-confirm');
      expect(_sheet, findsNothing);
      expect(await _receipts(t), hasLength(1));
      expect(find.byKey(const Key('undo-toast')), findsNothing);
    });

    testWidgets('Ja mit Drucker: unten steht "Bon gedruckt"', (t) async {
      await _start(t, await _setup(open: [('p1', cart, _first)]));
      await setUpPrinter(t);
      await _tap(t, 'unclear-paid');
      await _tap(t, 'unclear-confirm');
      expect(_sheet, findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('undo-toast')),
          matching: find.text('Bon gedruckt'),
        ),
        findsOneWidget,
      );
      // Der Hinweis verschwindet von selbst.
      await t.pump(const Duration(seconds: 8));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('undo-toast')), findsNothing);
    });

    testWidgets('Ja, der Drucker ist nicht bereit: unten steht die Meldung', (
      t,
    ) async {
      final printer = FakePrinter()
        ..next = const PrintOutcome.failed(PrintProblem.paperOut);
      await _start(
        t,
        await _setup(open: [('p1', cart, _first)], printer: printer),
      );
      await setUpPrinter(t);
      await _tap(t, 'unclear-paid');
      await _tap(t, 'unclear-confirm');
      expect(
        find.descendant(
          of: find.byKey(const Key('undo-toast')),
          matching: find.text('Drucker nicht bereit. Das Papier ist leer.'),
        ),
        findsOneWidget,
      );
      await t.pump(const Duration(seconds: 8));
      await t.pumpAndSettle();
    });

    testWidgets('Nein mit anderem Bon auf der Kassa: der Bon bleibt, wie er '
        'ist', (t) async {
      await _start(
        t,
        await _setup(open: [('p1', cart, _first)], draft: cartCard),
      );
      expect(_json(cartOf(t)), _json(cartCard));
      await _tap(t, 'unclear-not-paid');
      expect(
        textOf(t, const Key('unclear-effect')),
        'Die Kassa verwirft die Zahlung. Der Bon auf der Kassa bleibt, wie er '
        'ist.',
      );
      await _tap(t, 'unclear-confirm');
      expect(_json(cartOf(t)), _json(cartCard));
    });

    testWidgets('Nein, der Bon der Zahlung ist nicht lesbar: der Bon auf der '
        'Kassa bleibt, wie er ist', (t) async {
      await _start(t, await _setup(open: [('p1', cart, _first)]));
      final db = containerOf(t).read(databaseProvider);
      await db
          .update(db.pendingCardPaymentRows)
          .write(const PendingCardPaymentRowsCompanion(cartJson: Value('{}')));
      await t.pumpAndSettle();
      await _tap(t, 'unclear-not-paid');
      expect(
        textOf(t, const Key('unclear-effect')),
        'Die Kassa verwirft die Zahlung. Der Bon auf der Kassa bleibt, wie er '
        'ist.',
      );
      await _tap(t, 'unclear-confirm');
      expect(cartOf(t).isEmpty, isTrue);
    });
  });

  testWidgets('Zurück führt zur Wahl, nichts ist geschrieben', (t) async {
    await _start(t, await _setup(open: [('p1', cart, _first)]));
    await _tap(t, 'unclear-paid');
    expect(find.byKey(const Key('unclear-confirm')), findsOneWidget);
    expect(t.getSize(find.byKey(const Key('unclear-back'))).height, 72);
    await _tap(t, 'unclear-back');
    expect(find.byKey(const Key('unclear-confirm')), findsNothing);
    expect(find.byKey(const Key('unclear-paid')), findsOneWidget);
    expect(find.byKey(const Key('unclear-not-paid')), findsOneWidget);
    expect(await _receipts(t), isEmpty);
    expect(await _pending(t), 1);
    await _tap(t, 'unclear-not-paid');
    await _tap(t, 'unclear-back');
    expect(await _pending(t), 1);
    expect(cartOf(t).isEmpty, isTrue);
  });

  testWidgets('das Blatt lässt sich nicht wegtippen und nicht mit Zurück '
      'schließen', (t) async {
    await _start(t, await _setup(open: [('p1', cart, _first)]));
    await t.tapAt(const Offset(8, 8));
    await t.pumpAndSettle();
    await t.tapAt(const Offset(1270, 790));
    await t.pumpAndSettle();
    expect(_sheet, findsOneWidget);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(_sheet, findsOneWidget);
    // Was darunter liegt, nimmt keine Tipps an.
    await t.tap(find.byKey(const Key('tab-Bons')), warnIfMissed: false);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('area-bons')), findsNothing);
    await t.tap(find.byKey(const Key('item-tofu-bowl')), warnIfMissed: false);
    await t.pumpAndSettle();
    expect(cartOf(t).isEmpty, isTrue);
  });

  testWidgets('das Blatt liegt auch über den Einstellungen', (t) async {
    await pumpSettings(t);
    expect(find.byKey(const Key('area-settings')), findsOneWidget);
    expect(_sheet, findsNothing);
    await containerOf(t)
        .read(cardPaymentRepositoryProvider)
        .begin(paymentId: 'p1', cart: cart, staff: _anna);
    await t.pumpAndSettle();
    expect(_sheet, findsOneWidget);
    expect(find.byKey(const Key('area-settings')), findsOneWidget);
    await t.tap(find.byKey(const Key('settings')), warnIfMissed: false);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('area-settings')), findsOneWidget);
    expect(_sheet, findsOneWidget);
  });

  testWidgets('das Blatt liegt auch über dem Blatt "Bar bezahlen"', (t) async {
    await _start(t, await _setup());
    await tapItem(t, 'cola');
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('pay-cash')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('finish-sale')), findsOneWidget);
    await containerOf(t)
        .read(cardPaymentRepositoryProvider)
        .begin(paymentId: 'p1', cart: cart, staff: _anna);
    await t.pumpAndSettle();
    expect(_sheet, findsOneWidget);
  });

  testWidgets('zwei offene Zahlungen kommen nacheinander, die ältere zuerst', (
    t,
  ) async {
    await _start(
      t,
      await _setup(open: [('p2', cartCard, _second), ('p1', cart, _first)]),
    );
    expect(find.text('18,20 €'), findsOneWidget);
    expect(find.text('Gestartet um 12:04 von Anna'), findsOneWidget);
    await _tap(t, 'unclear-not-paid');
    await _tap(t, 'unclear-confirm');
    expect(_sheet, findsOneWidget);
    expect(find.text(formatEuro(cartCard.totalCents)), findsOneWidget);
    expect(find.text('Gestartet um 12:30 von Anna'), findsOneWidget);
    // Die zweite beginnt wieder bei der Wahl.
    expect(find.byKey(const Key('unclear-paid')), findsOneWidget);
    expect(find.byKey(const Key('unclear-confirm')), findsNothing);
    await _tap(t, 'unclear-paid');
    await _tap(t, 'unclear-confirm');
    expect(_sheet, findsNothing);
    expect((await _receipts(t)).single['id'], 'p2');
  });

  testWidgets('zwei schnelle Tipps auf Bestätigen ergeben einen Bon', (
    t,
  ) async {
    final printer = FakePrinter();
    await _start(
      t,
      await _setup(open: [('p1', cart, _first)], printer: printer),
    );
    await setUpPrinter(t);
    await _tap(t, 'unclear-paid');
    await t.tap(find.byKey(const Key('unclear-confirm')));
    await t.tap(find.byKey(const Key('unclear-confirm')), warnIfMissed: false);
    await t.pumpAndSettle();
    expect(await _receipts(t), hasLength(1));
    expect(printer.printed, ['p1']);
    expect(_sheet, findsNothing);
  });

  testWidgets('unklar direkt nach einer Zahlung (CardUnknown) zeigt dasselbe '
      'Blatt', (t) async {
    final terminal = FakeCardTerminal()..next = const CardUnknown();
    await _start(t, await _setup(terminal: terminal));
    await tapItem(t, 'cola');
    await tapItem(t, 'teigtaschen');
    await t.pumpAndSettle();
    final total = cartOf(t).totalCents;
    await t.tap(find.byKey(const Key('pay-card')));
    await t.pumpAndSettle();
    expect(_sheet, findsOneWidget);
    expect(find.text(formatEuro(total)), findsOneWidget);
    expect(find.text('2 × Cola 0,33 l'), findsNothing);
    expect(_inSheet('Cola 0,33 l'), findsOneWidget);
    expect(_inSheet('Teigtaschen'), findsOneWidget);
    expect(cartOf(t).isEmpty, isTrue);
    await _tap(t, 'unclear-paid');
    await _tap(t, 'unclear-confirm');
    expect(_sheet, findsNothing);
    expect(await _receipts(t), hasLength(1));
    expect(cartOf(t).isEmpty, isTrue);
  });

  testWidgets('eine Zahlung, die gerade am Terminal läuft, löst das Blatt '
      'nicht aus', (t) async {
    final hang = Completer<CardPaymentResult>();
    final terminal = FakeCardTerminal()..hang = hang;
    await _start(t, await _setup(terminal: terminal));
    await tapItem(t, 'cola');
    await tapItem(t, 'teigtaschen');
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('pay-card')));
    await t.pump(const Duration(milliseconds: 100));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('card-wait')), findsOneWidget);
    expect(await _pending(t), 1);
    expect(_sheet, findsNothing);
    hang.complete(const CardPaid(txCode: 'TX1'));
    await t.pumpAndSettle();
    expect(_sheet, findsNothing);
    expect(find.text('Bezahlt'), findsOneWidget);
    expect(await _receipts(t), hasLength(1));
  });

  testWidgets('Bon nicht mehr baubar: nur Nein bleibt', (t) async {
    await _start(t, await _setup(open: [('p1', cart, _first)]));
    // Die Speisekarte hat sich geändert: ein Artikel des Bons gibt es nicht
    // mehr.
    final db = containerOf(t).read(databaseProvider);
    await db
        .update(db.pendingCardPaymentRows)
        .write(
          PendingCardPaymentRowsCompanion(
            cartJson: Value(
              jsonEncode({
                'lines': [
                  {
                    'lineId': 'a',
                    'itemId': 'gibt-es-nicht',
                    'quantity': 1,
                    'optionIds': <String>[],
                  },
                ],
              }),
            ),
          ),
        );
    await t.pumpAndSettle();
    expect(_sheet, findsOneWidget);
    expect(
      find.text(
        'Der Bon lässt sich nicht mehr zusammenstellen, weil sich die '
        'Speisekarte geändert hat. Wähle Nein. Ist das Geld bei SumUp '
        'angekommen, buche es in der SumUp-App zurück und kassiere neu.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('unclear-paid')), findsNothing);
    expect(find.byKey(const Key('unclear-not-paid')), findsOneWidget);
    await _tap(t, 'unclear-not-paid');
    await _tap(t, 'unclear-confirm');
    expect(_sheet, findsNothing);
    expect(await _pending(t), 0);
    expect(await _receipts(t), isEmpty);
    expect(cartOf(t).isEmpty, isTrue);
  });

  group('Absturz mitten in der Kartenzahlung: derselbe Bon liegt schon auf '
      'der Kassa', () {
    testWidgets('Ja: Bon geschrieben und die Kassa ist leer', (t) async {
      await _start(t, await _setup(open: [('p1', cart, _first)], draft: cart));
      expect(_sheet, findsOneWidget);
      expect(_json(cartOf(t)), _json(cart));
      await _tap(t, 'unclear-paid');
      await _tap(t, 'unclear-confirm');
      expect(_sheet, findsNothing);
      expect(await _receipts(t), hasLength(1));
      expect(cartOf(t).isEmpty, isTrue);
      expect(await draftOf(t), isNull);
      expect(find.text('Noch nichts boniert'), findsOneWidget);
    });

    testWidgets('Nein: der Bon liegt einmal auf der Kassa, nicht doppelt', (
      t,
    ) async {
      await _start(t, await _setup(open: [('p1', cart, _first)], draft: cart));
      await _tap(t, 'unclear-not-paid');
      await _tap(t, 'unclear-confirm');
      expect(_sheet, findsNothing);
      expect(await _receipts(t), isEmpty);
      expect(await _pending(t), 0);
      expect(_json(cartOf(t)), _json(cart));
      expect(cartOf(t).totalCents, 1820);
      expect(await draftOf(t), _json(cart));
    });

    testWidgets('Ja mit anderem Inhalt auf der Kassa: der bleibt stehen', (
      t,
    ) async {
      await _start(
        t,
        await _setup(open: [('p1', cart, _first)], draft: cartCard),
      );
      await _tap(t, 'unclear-paid');
      await _tap(t, 'unclear-confirm');
      expect(await _receipts(t), hasLength(1));
      expect(_json(cartOf(t)), _json(cartCard));
      expect(await draftOf(t), _json(cartCard));
    });

    testWidgets('Nein mit anderem Inhalt auf der Kassa: der bleibt, nichts '
        'wird ersetzt', (t) async {
      await _start(
        t,
        await _setup(open: [('p1', cart, _first)], draft: cartCard),
      );
      await _tap(t, 'unclear-not-paid');
      await _tap(t, 'unclear-confirm');
      expect(await _pending(t), 0);
      expect(_json(cartOf(t)), _json(cartCard));
    });
  });

  testWidgets('unklar mit Trinkgeld: "bezahlt" schreibt den Bon mit '
      'Trinkgeld für die Person der Zahlung', (t) async {
    // Anna hat kassiert; inzwischen ist der Chef angemeldet.
    await pumpKassa(
      t,
      overrides: await _setupTipped(tipCents: 80),
      pin: '4711',
    );
    await t.pumpAndSettle();
    expect(_sheet, findsOneWidget);
    expect(textOf(t, const Key('unclear-amount')), '19,00 €');
    expect(textOf(t, const Key('unclear-tip')), 'Davon Trinkgeld 0,80 €');
    await _tap(t, 'unclear-paid');
    await _tap(t, 'unclear-confirm');
    expect(_sheet, findsNothing);
    expect(
      await queryRows(
        t,
        'SELECT kind, amount_cents, tip_cents, tip_staff_name FROM payments',
      ),
      [
        {
          'kind': 'card',
          'amount_cents': 1820,
          'tip_cents': 80,
          'tip_staff_name': 'Anna',
        },
      ],
    );
    expect(await queryRows(t, 'SELECT total_cents, tip_cents FROM receipts'), [
      {'total_cents': 1820, 'tip_cents': 80},
    ]);
    expect(await _pending(t), 0);
  });

  testWidgets('offene Zahlung in der Form von 1.10.0 (ohne Bar-Teil und '
      'Trinkgeld): "bezahlt" gibt einen Bon mit einer Kartenzahlung', (
    t,
  ) async {
    await _start(t, await _setupTipped(v110: true));
    expect(_sheet, findsOneWidget);
    expect(textOf(t, const Key('unclear-amount')), '18,20 €');
    expect(find.byKey(const Key('unclear-tip')), findsNothing);
    await _tap(t, 'unclear-paid');
    await _tap(t, 'unclear-confirm');
    expect(_sheet, findsNothing);
    expect(
      await queryRows(
        t,
        'SELECT position, kind, amount_cents, tip_cents FROM payments',
      ),
      [
        {'position': 0, 'kind': 'card', 'amount_cents': 1820, 'tip_cents': 0},
      ],
    );
    expect(await queryRows(t, 'SELECT total_cents, tip_cents FROM receipts'), [
      {'total_cents': 1820, 'tip_cents': 0},
    ]);
    expect(await _pending(t), 0);
  });

  testWidgets('unklar mit Bar-Teil: die offene Zahlung trägt ihn, "bezahlt" '
      'gibt den Bon mit zwei Zahlungen, "nicht bezahlt" nennt den Betrag zum '
      'Zurückgeben', (t) async {
    final terminal = FakeCardTerminal()..next = const CardUnknown();
    await _start(t, await _setup(terminal: terminal));
    await setSettings(t, (s) => s.copyWith(splitPaymentEnabled: true));
    await tapItem(t, 'cola');
    await tapItem(t, 'teigtaschen');
    await t.pumpAndSettle();
    await _tap(t, 'pay-cash');
    await _tap(t, 'cash-mode-split');
    await tapKeys(t, '5');
    await _tap(t, 'split-go');
    expect(_sheet, findsOneWidget);
    expect(
      await queryRows(
        t,
        'SELECT amount_cents, cash_part_cents, state FROM pending_card_payments',
      ),
      [
        {'amount_cents': 465, 'cash_part_cents': 500, 'state': 'unknown'},
      ],
    );
    expect(textOf(t, const Key('unclear-amount')), '4,65 €');
    expect(
      textOf(t, const Key('unclear-cash-part')),
      'Bar-Teil 5,00 € ist schon kassiert.',
    );
    await _tap(t, 'unclear-not-paid');
    expect(
      textOf(t, const Key('unclear-return-cash')),
      '5,00 € bar zurückgeben.',
    );
    await _tap(t, 'unclear-back');
    expect(find.byKey(const Key('unclear-return-cash')), findsNothing);
    await _tap(t, 'unclear-paid');
    expect(find.byKey(const Key('unclear-return-cash')), findsNothing);
    await _tap(t, 'unclear-confirm');
    expect(_sheet, findsNothing);
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
    expect(await _receipts(t), hasLength(1));
    expect(await _pending(t), 0);
  });

  testWidgets('unklar mit Bar-Teil, "nicht bezahlt": nichts gespeichert, der '
      'Bon kommt zurück', (t) async {
    final terminal = FakeCardTerminal()..next = const CardUnknown();
    await _start(t, await _setup(terminal: terminal));
    await setSettings(t, (s) => s.copyWith(splitPaymentEnabled: true));
    await tapItem(t, 'cola');
    await tapItem(t, 'teigtaschen');
    await t.pumpAndSettle();
    await _tap(t, 'pay-cash');
    await _tap(t, 'cash-mode-split');
    await tapKeys(t, '5');
    await _tap(t, 'split-go');
    await _tap(t, 'unclear-not-paid');
    await _tap(t, 'unclear-confirm');
    expect(_sheet, findsNothing);
    expect(await _receipts(t), isEmpty);
    expect(await _pending(t), 0);
    expect(cartOf(t).totalCents, 965);
  });

  testWidgets('unklar mit freiem Betrag und Rabatt: "bezahlt" schreibt den '
      'Bon mit seinen Zeilen, Rabatten und seiner Summe', (t) async {
    // Teigtaschen 6,50 € mit 10 % Stammgast, Cola 2,90 € plus 0,25 € Pfand,
    // freier Betrag 12,50 € zu 10 %, auf dem Bon 2,00 € Aktion.
    var mixed = cartCard.addOpenAmount(
      amountCents: 1250,
      rate: TaxRate.reduced1,
    );
    mixed = mixed
        .setLineDiscount(
          mixed.lines[0].lineId,
          const Discount.percent(10, DiscountReason.regular),
        )
        .setReceiptDiscount(
          const Discount.amount(200, DiscountReason.promotion),
        );
    await _start(t, await _setup(open: [('p1', mixed, _first)]));
    expect(_sheet, findsOneWidget);
    expect(textOf(t, const Key('unclear-amount')), '19,50 €');
    await _tap(t, 'unclear-paid');
    await _tap(t, 'unclear-confirm');
    expect(_sheet, findsNothing);
    expect(
      await queryRows(
        t,
        'SELECT id, goods_cents, deposit_cents, total_cents, discount_cents, '
        'discount_percent, discount_amount_cents, discount_reason '
        'FROM receipts',
      ),
      [
        {
          'id': 'p1',
          'goods_cents': 1925,
          'deposit_cents': 25,
          'total_cents': 1950,
          'discount_cents': 265,
          'discount_percent': null,
          'discount_amount_cents': 200,
          'discount_reason': 'promotion',
        },
      ],
    );
    final lines = await queryRows(
      t,
      'SELECT item_id, name, unit_price_cents, quantity, own_discount_percent, '
      'own_discount_cents, own_discount_reason, discount_cents, gross10_cents '
      'FROM receipt_lines ORDER BY position',
    );
    expect(
      [for (final l in lines) (l['item_id'], l['name'], l['unit_price_cents'])],
      [
        ('teigtaschen', 'Teigtaschen', 650),
        ('cola', 'Cola 0,33 l', 290),
        ('open-amount-10', 'Diverses 10 %', 1250),
      ],
    );
    expect(lines[0]['own_discount_percent'], 10);
    expect(lines[0]['own_discount_cents'], 65);
    expect(lines[0]['own_discount_reason'], 'regular');
    expect(lines[2]['own_discount_reason'], isNull);
    expect(
      lines[2]['gross10_cents'],
      1250 - (lines[2]['discount_cents']! as int),
    );
    expect(
      lines.fold<int>(0, (s, l) => s + (l['discount_cents']! as int)),
      265,
    );
    expect(
      await queryRows(t, 'SELECT kind, amount_cents, tip_cents FROM payments'),
      [
        {'kind': 'card', 'amount_cents': 1950, 'tip_cents': 0},
      ],
    );
    expect(await _pending(t), 0);
  });

  testWidgets('Tasten des Blatts sind mindestens 48 dp hoch', (t) async {
    await _start(t, await _setup(open: [('p1', cart, _first)]));
    for (final k in ['unclear-paid', 'unclear-not-paid']) {
      expect(t.getSize(find.byKey(Key(k))).height, greaterThanOrEqualTo(48));
    }
    expect(
      find.descendant(of: _sheet, matching: find.byType(PrimaryButton)),
      findsNWidgets(2),
    );
  });

  group('unklare Kartenzahlung nach Gutschein (Task 11)', () {
    /// Datenbank mit einem Gutschein über 5,00 € und einer offenen, unklaren
    /// Zahlung über cartCard mit diesem Gutschein (9,65 € − 5,00 €); danach
    /// zieht eine andere Kassa [drawn] vom Gutschein ab.
    /// Mit [draft] steht der Bon auch als Entwurf der Kassa da, wie ihn ein
    /// Absturz während der Zahlung hinterlässt.
    Future<(List<Override>, String)> setupVoucher({
      int drawn = 0,
      Cart Function(Cart paying)? draft,
    }) async {
      final overrides = await memoryOverrides(clock: FixedClock(_first));
      final c = ProviderContainer(overrides: overrides);
      final String code;
      try {
        final staff = await c.read(staffRepositoryProvider).all();
        final anna = staff.firstWhere((s) => s.name == 'Anna');
        final sold = await c
            .read(receiptRepositoryProvider)
            .finalizeCashSale(
              saleId: 'gutschein',
              cart: const Cart.empty().addVoucherSale(valueCents: 500),
              givenCents: 500,
              staff: anna,
            );
        final v = (await c
            .read(voucherRepositoryProvider)
            .byId(sold.soldVouchers.single.voucherId))!;
        code = v.code;
        final repo = c.read(cardPaymentRepositoryProvider);
        final paying = cartCard.applyVoucher(applied(v));
        await repo.begin(paymentId: 'p1', cart: paying, staff: anna);
        await repo.markUnknown('p1');
        if (draft != null) {
          await c
              .read(settingsRepositoryProvider)
              .writeDraft(jsonEncode(draft(paying).toJson()));
        }
        if (drawn > 0) {
          final db = c.read(databaseProvider);
          await db
              .into(db.voucherMovementRows)
              .insert(
                VoucherMovementRowsCompanion.insert(
                  voucherId: v.id,
                  receiptId: 'andere-kassa',
                  kind: 'redeem',
                  amountCents: -drawn,
                  createdAt: _first,
                ),
              );
        }
      } finally {
        c.dispose();
      }
      return (overrides, code);
    }

    testWidgets('das Blatt nennt den Gutschein-Teil; bestätigt entsteht der '
        'Bon mit Gutschein und Karte, auch wenn das Guthaben inzwischen 0 '
        'ist (überzogen)', (t) async {
      final (overrides, code) = await setupVoucher(drawn: 500);
      await _start(t, overrides);
      expect(textOf(t, const Key('unclear-amount')), '4,65 €');
      expect(
        textOf(t, const Key('unclear-voucher')),
        'Mit Gutschein 5,00 €',
      );
      expect(find.byKey(const Key('unclear-unreadable')), findsNothing);
      await _tap(t, 'unclear-paid');
      await _tap(t, 'unclear-confirm');
      expect(_sheet, findsNothing);
      expect(
        await queryRows(
          t,
          'SELECT kind, amount_cents, voucher_code, '
          "voucher_balance_after_cents FROM payments WHERE receipt_id = 'p1' "
          'ORDER BY position',
        ),
        [
          {
            'kind': 'voucher',
            'amount_cents': 500,
            'voucher_code': code,
            'voucher_balance_after_cents': -500,
          },
          {
            'kind': 'card',
            'amount_cents': 465,
            'voucher_code': null,
            'voucher_balance_after_cents': null,
          },
        ],
      );
      final v = (await containerOf(
        t,
      ).read(voucherRepositoryProvider).findByCode(code)).single;
      expect((v.balanceCents, v.state), (-500, VoucherState.overdrawn));
      expect(await _pending(t), 0);
    });

    testWidgets('unklare Kartenzahlung verworfen: der Bon liegt wieder an der '
        'Kassa, mit dem Gutschein und frischem Guthaben', (t) async {
      final (overrides, code) = await setupVoucher(drawn: 315);
      await _start(t, overrides);
      expect(
        textOf(t, const Key('unclear-voucher')),
        'Mit Gutschein 5,00 €',
      );
      await _tap(t, 'unclear-not-paid');
      await _tap(t, 'unclear-confirm');
      expect(_sheet, findsNothing);
      expect(await _pending(t), 0);
      expect(cartOf(t).lines, hasLength(2));
      expect(cartOf(t).vouchers.single.code, code);
      expect(cartOf(t).vouchers.single.balanceCents, 185);
      expect(textOf(t, const Key('due-amount')), '7,80 €');
      expect(
        await queryRows(t, "SELECT id FROM receipts WHERE id = 'p1'"),
        isEmpty,
      );
    });

    testWidgets('Absturz, Neustart, das Guthaben ist inzwischen 0 und der '
        'Gutschein fällt vom Entwurf: bestätigt entsteht der Bon mit Gutschein '
        'und Karte, die Kassa ist danach leer', (t) async {
      final (overrides, code) = await setupVoucher(
        drawn: 500,
        draft: (paying) => paying,
      );
      await _start(t, overrides);
      // refreshVouchers hat den Gutschein vom Bon der Kassa genommen.
      expect(cartOf(t).lines, hasLength(2));
      expect(cartOf(t).vouchers, isEmpty);
      await _tap(t, 'unclear-paid');
      await _tap(t, 'unclear-confirm');
      expect(_sheet, findsNothing);
      expect(
        await queryRows(
          t,
          'SELECT kind, amount_cents, voucher_balance_after_cents '
          "FROM payments WHERE receipt_id = 'p1' ORDER BY position",
        ),
        [
          {'kind': 'voucher', 'amount_cents': 500, 'voucher_balance_after_cents': -500},
          {'kind': 'card', 'amount_cents': 465, 'voucher_balance_after_cents': null},
        ],
      );
      final v = (await containerOf(
        t,
      ).read(voucherRepositoryProvider).findByCode(code)).single;
      expect(v.state, VoucherState.overdrawn);
      expect(cartOf(t).isEmpty, isTrue);
      expect(await draftOf(t), isNull);
    });

    testWidgets('Absturz mit anderem Bon an der Kassa (eine Zeile mehr): '
        'bestätigt bleibt der andere Bon an der Kassa', (t) async {
      final (overrides, _) = await setupVoucher(
        draft: (paying) => paying.add(cola),
      );
      await _start(t, overrides);
      expect(cartOf(t).lines.fold<int>(0, (s, l) => s + l.quantity), 3);
      await _tap(t, 'unclear-paid');
      await _tap(t, 'unclear-confirm');
      expect(_sheet, findsNothing);
      expect(
        await queryRows(t, "SELECT id FROM receipts WHERE id = 'p1'"),
        hasLength(1),
      );
      expect(cartOf(t).lines.fold<int>(0, (s, l) => s + l.quantity), 3);
      expect(await draftOf(t), isNotNull);
    });

    testWidgets('eine Einlösung von einer anderen Kassa kommt per Abgleich, '
        'während die Kartenzahlung mit Gutschein unklar ist: bestätigt '
        'entsteht der Bon trotzdem, der Gutschein ist überzogen', (t) async {
      final (overrides, code) = await setupVoucher(draft: (paying) => paying);
      await _start(t, overrides);
      expect(_sheet, findsOneWidget);
      expect(cartOf(t).vouchers.single.balanceCents, 500);
      final v = (await containerOf(
        t,
      ).read(voucherRepositoryProvider).findByCode(code)).single;
      // Der Abgleich bringt die Einlösung der anderen Kassa: der Gutschein
      // fällt vom Bon der Kassa (refreshVouchers), das Blatt bleibt.
      final server = FakeServer()
        ..putVoucherMovement({
          'voucherId': v.id,
          'receiptId': 'b0000000-0000-4000-8000-0000000000a2',
          'kind': 'redeem',
          'amountCents': -500,
          'createdAt': '2026-11-17T12:10:00.000Z',
        });
      expect(await pullFrom(containerOf(t), server), isTrue);
      await t.pumpAndSettle();
      expect(cartOf(t).vouchers, isEmpty);
      expect(_sheet, findsOneWidget);

      await _tap(t, 'unclear-paid');
      await _tap(t, 'unclear-confirm');
      expect(_sheet, findsNothing);
      expect(
        await queryRows(
          t,
          'SELECT kind, amount_cents, voucher_balance_after_cents '
          "FROM payments WHERE receipt_id = 'p1' ORDER BY position",
        ),
        [
          {
            'kind': 'voucher',
            'amount_cents': 500,
            'voucher_balance_after_cents': -500,
          },
          {
            'kind': 'card',
            'amount_cents': 465,
            'voucher_balance_after_cents': null,
          },
        ],
      );
      final after = (await containerOf(
        t,
      ).read(voucherRepositoryProvider).findByCode(code)).single;
      expect((after.balanceCents, after.state), (-500, VoucherState.overdrawn));
      expect(await _pending(t), 0);
      expect(cartOf(t).isEmpty, isTrue);
    });
  });
}
