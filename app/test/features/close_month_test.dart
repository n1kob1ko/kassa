import 'dart:async';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/core/clock.dart';
import 'package:kassa/core/money.dart';
import 'package:kassa/data/period_report_repository.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/devices/printer.dart';
import 'package:kassa/domain/period_report.dart';
import 'package:kassa/domain/receipt.dart';
import 'package:kassa/features/close/month_view.dart';
import 'package:kassa/features/login/session.dart';
import 'package:kassa/ui/pressable.dart';
import 'package:kassa/ui/primary_button.dart';
import 'package:material_ui/material_ui.dart';

import '../support/close_pump.dart';
import '../support/kassa_pump.dart';
import '../support/month_pump.dart';
import '../support/overview_pump.dart';
import '../support/pump.dart';
import '../support/sales.dart' show cartCard, discounted;
import '../support/voucher_deposit_day.dart' show sellVoucherAndPayout;

const _print = Key('print-period');
const _result = Key('period-print-result');

String _title(WidgetTester t) => textOf(t, const Key('period-title'));
String _period(WidgetTester t) => textOf(t, const Key('period-text'));

bool _enabled(WidgetTester t, String key) =>
    t.widget<Pressable>(find.byKey(Key(key))).onTap != null;

bool _printEnabled(WidgetTester t) =>
    t.widget<PrimaryButton>(find.byKey(_print)).onPressed != null;

/// Dezember 2025, Jänner 2026 und Oktober 2026 je ein Verkauf.
List<OverviewSale> _overNewYear() => [
  OverviewSale(DateTime(2025, 12, 10, 12)),
  OverviewSale(DateTime(2026, 1, 10, 12)),
  OverviewSale(DateTime(2026, 10, 1, 12)),
];

/// Rechnet wie das Original; September scheitert ([failSeptember]) oder der
/// Beleg zum September wartet auf [septemberBeleg].
class _Repo extends PeriodReportRepository {
  _Repo(super.db, super.clock);

  bool failSeptember = false;
  Completer<void>? septemberBeleg;

  static const _september = YearMonth(2026, 9);

  @override
  Future<PeriodReport> report(MonthRange range) async {
    if (failSeptember && range.from == _september) {
      throw StateError('Lesefehler');
    }
    return super.report(range);
  }

  @override
  Future<String?> signatureReceiptId(YearMonth month) async {
    final wait = septemberBeleg;
    if (wait != null && month == _september) await wait.future;
    return super.signatureReceiptId(month);
  }
}

/// Ersetzt das Repository der Abrechnung durch [_Repo]; erreichbar über
/// [_repoOf].
List<Override> _repoOverride() => [
  periodReportRepositoryProvider.overrideWith(
    (ref) => _Repo(ref.watch(databaseProvider), ref.watch(clockProvider)),
  ),
];

_Repo _repoOf(WidgetTester t) =>
    containerOf(t).read(periodReportRepositoryProvider) as _Repo;

void main() {
  testWidgets('Abschluss öffnet mit Tag; Monat zeigt den letzten '
      'abgeschlossenen Monat', (t) async {
    await pumpMonth(t, openMonth: false);
    expect(find.text('Tagesabschluss'), findsOneWidget);
    expect(find.byType(MonthView), findsNothing);
    expect(find.byKey(const Key('segment-Tag')), findsOneWidget);

    await tapKey(t, 'segment-Monat');
    expect(find.byType(MonthView), findsOneWidget);
    expect(find.text('Tagesabschluss'), findsNothing);
    expect(_title(t), 'Monatsabrechnung Oktober 2026');
    expect(_period(t), '1.10. bis 31.10.2026');
    expect(textOf(t, const Key('income-total')), '54,60 €');
    expect(textOf(t, const Key('year-label')), '2026');
    expect(find.text('Zeitraum'), findsOneWidget);
    // Karte Tage: ein Tag je Zeile.
    final rows = find.byKey(const Key('period-rows'));
    expect(find.text('Tage'), findsOneWidget);
    expect(
      find.descendant(of: rows, matching: find.text('Do., 1.10.')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: rows, matching: find.text('2 Bons')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: rows, matching: find.text('Fr., 2.10.')),
      findsOneWidget,
    );
    expect(t.takeException(), isNull);
  });

  testWidgets('Bereich verlassen und wieder öffnen: wieder Tag', (t) async {
    await pumpMonth(t);
    expect(find.byType(MonthView), findsOneWidget);
    await tapKey(t, 'tab-Kassa');
    await openClose(t);
    expect(find.byType(MonthView), findsNothing);
    expect(find.text('Tagesabschluss'), findsOneWidget);
    // Zurück auf Tag geht auch mit dem Umschalter.
    await tapKey(t, 'segment-Monat');
    await tapKey(t, 'segment-Tag');
    expect(find.text('Tagesabschluss'), findsOneWidget);
  });

  testWidgets('laufender Monat und Monate vor dem ersten Bon sind gesperrt', (
    t,
  ) async {
    await pumpMonth(t);
    for (final m in [1, 8, 11, 12]) {
      expect(_enabled(t, 'month-$m'), isFalse, reason: 'Monat $m');
    }
    expect(_enabled(t, 'month-9'), isTrue);
    expect(_enabled(t, 'month-10'), isTrue);
    await t.tap(find.byKey(const Key('month-11')), warnIfMissed: false);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('month-8')), warnIfMissed: false);
    await t.pumpAndSettle();
    expect(_title(t), 'Monatsabrechnung Oktober 2026');
    expect(_period(t), '1.10. bis 31.10.2026');
  });

  testWidgets('Tipp auf September zeigt September', (t) async {
    await pumpMonth(t);
    await tapKey(t, 'month-9');
    expect(_title(t), 'Monatsabrechnung September 2026');
    expect(_period(t), '1.9. bis 30.9.2026');
    expect(textOf(t, const Key('income-total')), '18,20 €');
    expect(find.text('Di., 15.9.'), findsOneWidget);
  });

  testWidgets('Von bis: zwei Tipps, Titel "Abrechnung September bis Oktober '
      '2026", Karte Monate', (t) async {
    await pumpMonth(t);
    await tapKey(t, 'segment-Von bis');
    // Nur der Beginn gewählt: dieser eine Monat.
    expect(_title(t), 'Monatsabrechnung Oktober 2026');
    await tapKey(t, 'month-9');
    expect(_title(t), 'Monatsabrechnung September 2026');
    await tapKey(t, 'month-10');
    expect(_title(t), 'Abrechnung September bis Oktober 2026');
    expect(_period(t), '1.9. bis 31.10.2026');
    expect(textOf(t, const Key('income-total')), '72,80 €');
    expect(find.text('Monate'), findsOneWidget);
    expect(find.text('Tage'), findsNothing);
    final rows = find.byKey(const Key('period-rows'));
    expect(
      find.descendant(of: rows, matching: find.text('September 2026')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: rows, matching: find.text('Oktober 2026')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: rows, matching: find.text('3 Bons')),
      findsOneWidget,
    );
  });

  testWidgets('Von bis über den Jahreswechsel: Jahr zwischen den Tipps '
      'wechseln', (t) async {
    await pumpMonth(t, sales: _overNewYear());
    await tapKey(t, 'segment-Von bis');
    await tapKey(t, 'year-prev');
    expect(textOf(t, const Key('year-label')), '2025');
    await tapKey(t, 'month-12');
    await tapKey(t, 'year-next');
    expect(textOf(t, const Key('year-label')), '2026');
    await tapKey(t, 'month-1');
    expect(_period(t), '1.12.2025 bis 31.1.2026');
    expect(_title(t), 'Abrechnung Dezember 2025 bis Jänner 2026');
    expect(find.text('Dezember 2025'), findsOneWidget);
    expect(find.text('Jänner 2026'), findsOneWidget);
    expect(textOf(t, const Key('income-total')), '36,40 €');
  });

  testWidgets('Jahrespfeile sind am ersten und letzten Jahr gesperrt', (
    t,
  ) async {
    await pumpMonth(t, sales: _overNewYear());
    expect(_enabled(t, 'year-next'), isFalse);
    expect(_enabled(t, 'year-prev'), isTrue);
    await tapKey(t, 'year-prev');
    expect(textOf(t, const Key('year-label')), '2025');
    expect(_enabled(t, 'year-prev'), isFalse);
    expect(_enabled(t, 'year-next'), isTrue);
    await t.tap(find.byKey(const Key('year-prev')), warnIfMissed: false);
    await t.pumpAndSettle();
    expect(textOf(t, const Key('year-label')), '2025');
    // Im Jahr 2025 ist nur der Dezember wählbar.
    expect(_enabled(t, 'month-11'), isFalse);
    expect(_enabled(t, 'month-12'), isTrue);
    // Der gewählte Monat bleibt Oktober 2026.
    expect(_title(t), 'Monatsabrechnung Oktober 2026');
  });

  testWidgets('Drucken ruft den Drucker mit dem gewählten Zeitraum', (t) async {
    await pumpMonth(t, printer: true);
    await tapKey(t, 'segment-Von bis');
    await tapKey(t, 'month-9');
    await tapKey(t, 'month-10');
    await tapKey(t, 'print-period');
    expect(printerOf(t).log, ['period-report:2026-09..2026-10']);
    expect(find.byKey(_result), findsOneWidget);
    expect(find.text('Abrechnung gedruckt.'), findsOneWidget);
    expect(_printEnabled(t), isTrue);
  });

  testWidgets('doppelt getippt: ein Druck; Zeitraum wechseln löscht die '
      'Meldung', (t) async {
    await pumpMonth(t, printer: true);
    final hold = Completer<void>();
    printerOf(t).hold = hold;
    await t.tap(find.byKey(_print));
    await t.pump();
    expect(_printEnabled(t), isFalse);
    await t.tap(find.byKey(_print), warnIfMissed: false);
    await t.pump();
    expect(printerOf(t).log, ['period-report:2026-10..2026-10']);
    expect(find.byKey(_result), findsNothing);

    hold.complete();
    await t.pumpAndSettle();
    expect(printerOf(t).log, hasLength(1));
    expect(find.text('Abrechnung gedruckt.'), findsOneWidget);
    expect(_printEnabled(t), isTrue);

    await tapKey(t, 'month-9');
    expect(find.byKey(_result), findsNothing);
    expect(_printEnabled(t), isTrue);
  });

  testWidgets('Zeitraum während des Drucks gewechselt: keine Meldung für den '
      'neuen Zeitraum', (t) async {
    await pumpMonth(t, printer: true);
    final hold = Completer<void>();
    printerOf(t).hold = hold;
    await t.tap(find.byKey(_print));
    await t.pump();
    await tapKey(t, 'month-9');
    hold.complete();
    await t.pumpAndSettle();
    expect(find.byKey(_result), findsNothing);
    expect(_printEnabled(t), isTrue);
  });

  testWidgets('Drucker nicht bereit: Meldung über der Taste', (t) async {
    await pumpMonth(t, printer: true);
    printerOf(t).next = const PrintOutcome.failed(PrintProblem.paperOut);
    await tapKey(t, 'print-period');
    expect(
      find.descendant(
        of: find.byKey(_result),
        matching: find.text('Drucker nicht bereit. Das Papier ist leer.'),
      ),
      findsOneWidget,
    );
    expect(find.text('Abrechnung gedruckt.'), findsNothing);
    expect(_printEnabled(t), isTrue);
  });

  testWidgets('ohne Drucker: Taste gesperrt, "Kein Drucker eingerichtet."', (
    t,
  ) async {
    await pumpMonth(t);
    expect(_printEnabled(t), isFalse);
    expect(find.text('Kein Drucker eingerichtet.'), findsOneWidget);
    await t.tap(find.byKey(_print), warnIfMissed: false);
    await t.pumpAndSettle();
    expect(printerOf(t).log, isEmpty);
  });

  testWidgets('leerer Monat: Satz statt Karten, Drucken gesperrt', (t) async {
    await pumpMonth(
      t,
      printer: true,
      sales: [
        OverviewSale(DateTime(2026, 8, 15, 12)),
        OverviewSale(DateTime(2026, 10, 1, 12)),
      ],
    );
    expect(_printEnabled(t), isTrue);
    await tapKey(t, 'month-9');
    expect(_title(t), 'Monatsabrechnung September 2026');
    expect(find.byKey(const Key('period-empty')), findsOneWidget);
    expect(find.text('In diesem Zeitraum gibt es keine Bons.'), findsOneWidget);
    expect(find.byKey(const Key('income-total')), findsNothing);
    expect(find.byKey(const Key('period-rows')), findsNothing);
    expect(_printEnabled(t), isFalse);
  });

  testWidgets('noch kein abgeschlossener Monat: "Die erste Monatsabrechnung '
      'gibt es ab 1. Dezember."', (t) async {
    await pumpMonth(
      t,
      printer: true,
      sales: [OverviewSale(DateTime(2026, 11, 10, 12))],
    );
    expect(find.byKey(const Key('no-month-yet')), findsOneWidget);
    expect(
      find.text('Die erste Monatsabrechnung gibt es ab 1. Dezember.'),
      findsOneWidget,
    );
    for (var m = 1; m <= 12; m++) {
      expect(_enabled(t, 'month-$m'), isFalse, reason: 'Monat $m');
    }
    expect(_enabled(t, 'year-prev'), isFalse);
    expect(_enabled(t, 'year-next'), isFalse);
    expect(find.byKey(_print), findsNothing);
    expect(find.byKey(const Key('income-total')), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('Monatsbeleg: Karte mit Zeit und Nummer, Drucken druckt den '
      'gespeicherten Beleg', (t) async {
    await pumpMonth(
      t,
      printer: true,
      live: true,
      belege: [SignatureReceipt(DateTime(2026, 11, 1, 10, 2), id: 'beleg-okt')],
    );
    final card = find.byKey(const Key('signature-receipt-card'));
    expect(card, findsOneWidget);
    expect(
      find.descendant(
        of: card,
        matching: find.text('Monatsbeleg der Signatur'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: card,
        matching: find.text('Erstellt am 1.11. um 10:02, Bon Nr. 12400'),
      ),
      findsOneWidget,
    );
    // Echt signiert: kein Testbetrieb.
    expect(find.byKey(const Key('test-mode-pill')), findsNothing);

    await tapKey(t, 'print-signature-receipt');
    expect(printerOf(t).printed, ['beleg-okt']);
    expect(printerOf(t).log, ['print:beleg-okt']);

    // Bei von bis gibt es die Karte nicht.
    await tapKey(t, 'segment-Von bis');
    await tapKey(t, 'month-9');
    await tapKey(t, 'month-10');
    expect(card, findsNothing);
  });

  testWidgets('Jahresbeleg: die Karte heißt "Jahresbeleg der Signatur"', (
    t,
  ) async {
    await pumpMonth(
      t,
      now: DateTime(2027, 1, 5, 11),
      signature: true,
      sales: [OverviewSale(DateTime(2026, 12, 3, 12))],
      belege: [
        SignatureReceipt(
          DateTime(2027, 1, 2, 9, 15),
          number: 31,
          kind: ReceiptKind.year,
        ),
      ],
    );
    expect(_title(t), 'Monatsabrechnung Dezember 2026');
    expect(find.text('Jahresbeleg der Signatur'), findsOneWidget);
    expect(find.text('Erstellt am 2.1. um 09:15, Bon Nr. 31'), findsOneWidget);
  });

  testWidgets('ohne Monatsbeleg: "Kommt von selbst mit dem nächsten Bon.", '
      'keine Taste', (t) async {
    await pumpMonth(t, printer: true, signature: true);
    final card = find.byKey(const Key('signature-receipt-card'));
    expect(card, findsOneWidget);
    expect(
      find.descendant(
        of: card,
        matching: find.text('Kommt von selbst mit dem nächsten Bon.'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('print-signature-receipt')), findsNothing);
  });

  testWidgets('ohne Signatur keine Karte', (t) async {
    await pumpMonth(
      t,
      belege: [SignatureReceipt(DateTime(2026, 11, 1, 10, 2))],
    );
    expect(_title(t), 'Monatsabrechnung Oktober 2026');
    expect(find.byKey(const Key('signature-receipt-card')), findsNothing);
  });

  testWidgets('nur Testbons: Pille Testbetrieb', (t) async {
    await pumpMonth(t);
    expect(textOf(t, const Key('test-mode-pill')), 'Testbetrieb');
  });

  testWidgets('Schriftgröße 1,3 und 1024 x 768: kein Überlauf', (t) async {
    await pumpMonth(
      t,
      openMonth: false,
      printer: true,
      live: true,
      size: const Size(1024, 768),
      textScale: 1.3,
      sales: _overNewYear(),
      belege: [SignatureReceipt(DateTime(2026, 11, 1, 10, 2))],
    );
    expect(t.takeException(), isNull);
    await tapKey(t, 'segment-Monat');
    expect(t.takeException(), isNull);
    await tapKey(t, 'print-period');
    expect(t.takeException(), isNull);
    printerOf(t).next = const PrintOutcome.failed(PrintProblem.coverOpen);
    await tapKey(t, 'print-period');
    expect(t.takeException(), isNull);
    await tapKey(t, 'segment-Von bis');
    await tapKey(t, 'year-prev');
    await tapKey(t, 'month-12');
    await tapKey(t, 'year-next');
    await tapKey(t, 'month-10');
    expect(_title(t), 'Abrechnung Dezember 2025 bis Oktober 2026');
    expect(t.takeException(), isNull);
  });

  testWidgets('Monat ändert nichts an der Datenbank', (t) async {
    await pumpMonth(
      t,
      openMonth: false,
      printer: true,
      signature: true,
      belege: [SignatureReceipt(DateTime(2026, 11, 1, 10, 2))],
    );
    final before = await rowCounts(t);
    await tapKey(t, 'segment-Monat');
    await tapKey(t, 'print-period');
    await tapKey(t, 'print-signature-receipt');
    await tapKey(t, 'segment-Von bis');
    await tapKey(t, 'month-9');
    await tapKey(t, 'month-10');
    await tapKey(t, 'print-period');
    expect(printerOf(t).log, [
      'period-report:2026-10..2026-10',
      'print:beleg-1',
      'period-report:2026-09..2026-10',
    ]);
    expect(await rowCounts(t), before);
  });

  testWidgets('Von bis: keine Karte zum Monatsbeleg, auch mit nur dem Beginn', (
    t,
  ) async {
    await pumpMonth(
      t,
      printer: true,
      signature: true,
      belege: [SignatureReceipt(DateTime(2026, 11, 1, 10, 2))],
    );
    final card = find.byKey(const Key('signature-receipt-card'));
    expect(card, findsOneWidget);
    await tapKey(t, 'segment-Von bis');
    expect(_title(t), 'Monatsabrechnung Oktober 2026');
    expect(card, findsNothing);
    await tapKey(t, 'month-9');
    expect(_title(t), 'Monatsabrechnung September 2026');
    expect(card, findsNothing);
    expect(find.byKey(const Key('print-signature-receipt')), findsNothing);
  });

  testWidgets('Fehler beim Rechnen: Hinweis statt alter Zahlen, Drucken '
      'gesperrt', (t) async {
    await pumpMonth(t, printer: true, extra: _repoOverride());
    expect(textOf(t, const Key('income-total')), '54,60 €');
    _repoOf(t).failSeptember = true;
    await tapKey(t, 'month-9');
    expect(
      find.text('Das hat nicht geklappt. Bitte den Bereich nochmal öffnen.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('income-total')), findsNothing);
    expect(find.byKey(const Key('period-rows')), findsNothing);
    expect(_printEnabled(t), isFalse);
    // Zurück zu einem Monat, der sich rechnen lässt.
    await tapKey(t, 'month-10');
    expect(textOf(t, const Key('income-total')), '54,60 €');
    expect(_printEnabled(t), isTrue);
  });

  testWidgets('Beleg des neuen Monats lädt noch: nie der Beleg eines anderen '
      'Monats', (t) async {
    await pumpMonth(
      t,
      printer: true,
      signature: true,
      extra: _repoOverride(),
      belege: [
        SignatureReceipt(
          DateTime(2026, 10, 1, 9),
          number: 900,
          id: 'beleg-sep',
        ),
        SignatureReceipt(DateTime(2026, 11, 1, 10, 2), id: 'beleg-okt'),
      ],
    );
    expect(find.text('Erstellt am 1.11. um 10:02, Bon Nr. 12400'), findsOne);
    final wait = _repoOf(t).septemberBeleg = Completer<void>();
    await tapKey(t, 'month-9');
    expect(_title(t), 'Monatsabrechnung September 2026');
    expect(
      find.text('Erstellt am 1.11. um 10:02, Bon Nr. 12400'),
      findsNothing,
    );
    expect(find.byKey(const Key('print-signature-receipt')), findsNothing);

    wait.complete();
    await t.pumpAndSettle();
    expect(find.text('Erstellt am 1.10. um 09:00, Bon Nr. 900'), findsOne);
    await tapKey(t, 'print-signature-receipt');
    expect(printerOf(t).printed, ['beleg-sep']);
  });

  testWidgets('Monat: Karte Einnahmen mit Rabatten, Trinkgeld je Person und '
      '"Am Kartenkonto"', (t) async {
    await pumpMonth(
      t,
      openMonth: false,
      sales: [
        ...defaultMonthSales(),
        OverviewSale(DateTime(2026, 10, 3, 12), cart: discounted),
      ],
    );
    final c = containerOf(t);
    final clock = c.read(clockProvider) as FixedClock;
    clock.value = DateTime(2026, 10, 3, 13);
    final chef = c.read(sessionProvider)!;
    await c
        .read(receiptRepositoryProvider)
        .finalizeCardSale(
          saleId: 'tip-1',
          cart: cartCard,
          staff: chef,
          provider: 'sumup',
          tipCents: 80,
        );
    clock.value = DateTime(2026, 11, 17, 11);
    await tapKey(t, 'segment-Monat');

    expect(_title(t), 'Monatsabrechnung Oktober 2026');
    expect(find.text('Rabatte'), findsOneWidget);
    expect(textOf(t, const Key('income-discounts')), formatEuro(-284));
    expect(textOf(t, const Key('income-card-tip')), formatEuro(80));
    expect(textOf(t, Key('income-tip-${chef.id}')), formatEuro(80));
    expect(textOf(t, const Key('income-card-account')), formatEuro(965 + 80));
    expect(t.takeException(), isNull);
  });

  testWidgets('Monat ohne Rabatt und Trinkgeld: keine der Zeilen', (t) async {
    await pumpMonth(t);
    for (final k in [
      'income-discounts',
      'income-card-tip',
      'income-card-account',
    ]) {
      expect(find.byKey(Key(k)), findsNothing);
    }
  });

  testWidgets('Monat: die drei neuen Reihen stehen nur da, wenn es etwas '
      'gibt; die Spalte ergibt von oben nach unten die Summe', (t) async {
    await pumpMonth(t, openMonth: false);
    final c = containerOf(t);
    final clock = c.read(clockProvider) as FixedClock;
    await tapKey(t, 'segment-Monat');
    for (final k in [
      'income-voucher-paid',
      'income-voucher-sold',
      'income-deposit-return',
      'tax-vouchers',
    ]) {
      expect(find.byKey(Key(k)), findsNothing, reason: k);
    }

    // Am 3.10.: ein Gutschein verkauft, mit ihm bezahlt, Pfand ausbezahlt.
    await tapKey(t, 'segment-Tag');
    clock.value = DateTime(2026, 10, 3, 13);
    await sellVoucherAndPayout(
      c.read(receiptRepositoryProvider),
      c.read(sessionProvider)!,
    );
    clock.value = DateTime(2026, 11, 17, 11);
    await tapKey(t, 'segment-Monat');

    expect(_title(t), 'Monatsabrechnung Oktober 2026');
    String amount(String k) => textOf(t, Key(k));
    expect(amount('income-cash'), formatEuro(5460 + 2500 - 75));
    expect(amount('income-voucher-paid'), formatEuro(965));
    expect(amount('income-voucher-sold'), formatEuro(-2500));
    expect(amount('income-total'), formatEuro(5460 + 965 - 75));
    expect(5460 + 2500 - 75 + 0 + 965 - 2500, 5460 + 965 - 75);
    expect(amount('income-deposit-return'), formatEuro(-75));
    expect(amount('tax-vouchers'), formatEuro(2500));
    expect(find.text('Mit Gutschein bezahlt'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
