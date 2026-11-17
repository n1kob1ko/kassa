import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/core/clock.dart';
import 'package:kassa/data/day_repository.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/domain/day.dart';
import 'package:kassa/domain/staff.dart';
import 'package:kassa/features/login/session.dart';
import 'package:kassa/ui/primary_button.dart';
import 'package:material_ui/material_ui.dart';

import '../support/bons_pump.dart';
import '../support/close_pump.dart';
import '../support/kassa_pump.dart';
import '../support/pump.dart';

/// Zählt, wie oft der Tag abgeschlossen wird.
class _CountingDays extends DayRepository {
  _CountingDays(super.db, super.clock);

  int closes = 0;

  @override
  Future<BusinessDay> close({
    required int countedCents,
    required int leftInDrawerCents,
    required Staff staff,
  }) {
    closes++;
    return super.close(
      countedCents: countedCents,
      leftInDrawerCents: leftInDrawerCents,
      staff: staff,
    );
  }
}

/// Bargeld-Bewegungen schlagen immer fehl.
class _FailingMovements extends DayRepository {
  _FailingMovements(super.db, super.clock);

  @override
  Future<void> addMovement({
    required CashMovementKind kind,
    required int amountCents,
    required CashReason reason,
    required Staff staff,
  }) => throw StateError('kaputt');
}

Future<void> _tap(WidgetTester t, String key) async {
  await t.ensureVisible(find.byKey(Key(key)));
  await t.tap(find.byKey(Key(key)));
  await t.pumpAndSettle();
}

/// Zählt 168,20 €, geht weiter, lässt 150 € in der Lade und schließt.
Future<void> _closeDay(WidgetTester t) async {
  await tapKeys(t, '1 6 8 , 2 0');
  await _tap(t, 'count-next');
  await tapKeys(t, '1 5 0');
  await _tap(t, 'close-day');
}

/// Wie [tapKeys], holt aber jede Taste zuerst ins Bild: auf kleinen Geräten
/// scrollt die Spalte.
Future<void> _scrollKeys(WidgetTester t, String keys) async {
  for (final k in keys.split(' ')) {
    final name = k == 'back' ? 'back' : (k == ',' ? 'comma' : k);
    await t.ensureVisible(find.byKey(Key('key-$name')));
    await t.pump();
    await tapKeys(t, k);
  }
}

bool _enabled(WidgetTester t, String key) =>
    t.widget<PrimaryButton>(find.byKey(Key(key))).onPressed != null;

void main() {
  group('Wechselgeld am Morgen', () {
    testWidgets('erster Tag fragt nach dem Wechselgeld', (t) async {
      await pumpCloseWithSales(t, 1); // 18,20 € bar
      expect(
        find.text('Wie viel Wechselgeld war am Morgen in der Lade?'),
        findsOneWidget,
      );
      await tapKeys(t, '1 5 0');
      await t.tap(find.byKey(const Key('set-float')));
      await t.pumpAndSettle();
      expect(textOf(t, const Key('expected-cash')), '168,20 €');
    });

    testWidgets('frische Installation ohne Verkauf fragt auch', (t) async {
      await pumpClose(t, sales: 0);
      expect(find.text('Wechselgeld'), findsOneWidget);
      expect(find.byKey(const Key('set-float')), findsOneWidget);
      expect(find.byKey(const Key('cash-in')), findsNothing);
      expect(find.byKey(const Key('cash-out')), findsNothing);
      await tapKeys(t, '5 0');
      await _tap(t, 'set-float');
      expect(textOf(t, const Key('expected-cash')), '50,00 €');
    });

    testWidgets('speichern geht erst, wenn etwas getippt ist, 0 ist erlaubt', (t) async {
      await pumpCloseWithSales(t, 1);
      expect(_enabled(t, 'set-float'), isFalse);
      await tapKeys(t, '0');
      expect(_enabled(t, 'set-float'), isTrue);
      await _tap(t, 'set-float');
      expect(textOf(t, const Key('expected-cash')), '18,20 €');
      expect(textOf(t, const Key('left-float')), '0,00 €');
    });

    testWidgets('ohne Geldlade heißt es "Wechselgeld war am Morgen da"', (t) async {
      await pumpClose(t, drawer: false);
      expect(
        find.text('Wie viel Wechselgeld war am Morgen da?'),
        findsOneWidget,
      );
    });
  });

  group('Bargeld-Bewegungen', () {
    testWidgets('Bargeld entnehmen mit Grund senkt das Soll', (t) async {
      await pumpCloseReady(t); // Wechselgeld 150,00, ein Verkauf 18,20
      await t.tap(find.byKey(const Key('cash-out')));
      await t.pumpAndSettle();
      await tapKeys(t, '2 0');
      expect(
        t.widget<PrimaryButton>(find.byKey(const Key('save-movement'))).onPressed,
        isNull,
      ); // Grund fehlt
      await t.tap(find.byKey(const Key('reason-purchase')));
      await t.pump();
      await t.tap(find.byKey(const Key('save-movement')));
      await t.pumpAndSettle();
      expect(textOf(t, const Key('expected-cash')), '148,20 €');
      expect(find.text('Entnommen: Einkauf'), findsOneWidget);
      expect(find.text('11:00 Uhr'), findsOneWidget);
      expect(textOf(t, const Key('left-expected')), '148,20 €');
    });

    testWidgets('Einlage hebt das Soll und steht als "Eingelegt: Wechselgeld"', (t) async {
      await pumpCloseReady(t);
      await _tap(t, 'cash-in');
      expect(find.text('Bargeld einlegen'), findsWidgets);
      await tapKeys(t, '5 0');
      await t.tap(find.byKey(const Key('reason-change')));
      await t.pump();
      expect(find.text('Einlage speichern'), findsOneWidget);
      await _tap(t, 'save-movement');
      expect(textOf(t, const Key('expected-cash')), '218,20 €');
      expect(find.text('Eingelegt: Wechselgeld'), findsOneWidget);
    });

    testWidgets('speichern geht erst bei Betrag über 0 und mit Grund', (t) async {
      await pumpCloseReady(t);
      await _tap(t, 'cash-out');
      await t.tap(find.byKey(const Key('reason-bank')));
      await t.pump();
      expect(_enabled(t, 'save-movement'), isFalse); // Betrag fehlt
      await tapKeys(t, '0');
      expect(_enabled(t, 'save-movement'), isFalse); // 0 zählt nicht
      await tapKeys(t, '5');
      expect(_enabled(t, 'save-movement'), isTrue);
    });

    testWidgets('Schließen kehrt zum Zählen zurück, die getippte Zahl bleibt', (t) async {
      await pumpCloseReady(t);
      await tapKeys(t, '1 6 8');
      await _tap(t, 'cash-out');
      expect(find.byKey(const Key('count-next')), findsNothing);
      await _tap(t, 'close-movement');
      expect(textOf(t, const Key('amount-field')), '168 €');
      expect(find.byKey(const Key('count-next')), findsOneWidget);
    });

    testWidgets('nach dem Speichern bleibt die getippte Zahl stehen', (t) async {
      await pumpCloseReady(t);
      await tapKeys(t, '1 6 8');
      await _tap(t, 'cash-in');
      await tapKeys(t, '1 0');
      await t.tap(find.byKey(const Key('reason-other')));
      await t.pump();
      await _tap(t, 'save-movement');
      expect(textOf(t, const Key('amount-field')), '168 €');
      expect(textOf(t, const Key('expected-cash')), '178,20 €');
      expect(find.text('Eingelegt: Sonstiges'), findsOneWidget);
    });

    testWidgets('ohne offenen Tag gibt es die Tasten nicht', (t) async {
      await pumpCloseReady(t);
      await _closeDay(t);
      expect(find.byKey(const Key('cash-in')), findsNothing);
      expect(find.byKey(const Key('cash-out')), findsNothing);
    });
  });

  group('Fehler im Bargeld-Formular', () {
    testWidgets('Schließen des Formulars nimmt den Fehlerhinweis weg', (t) async {
      await pumpClose(
        t,
        floatCents: 15000,
        extra: [
          dayRepositoryProvider.overrideWith(
            (ref) => _FailingMovements(ref.watch(databaseProvider), ref.watch(clockProvider)),
          ),
        ],
      );
      await _tap(t, 'cash-out');
      await tapKeys(t, '5');
      await t.tap(find.byKey(const Key('reason-bank')));
      await t.pump();
      await _tap(t, 'save-movement');
      expect(find.text('Das hat nicht geklappt. Bitte nochmal versuchen.'), findsOneWidget);
      await _tap(t, 'close-movement');
      expect(find.text('Das hat nicht geklappt. Bitte nochmal versuchen.'), findsNothing);
    });
  });

  group('Zählen und Abschließen', () {
    testWidgets(
      'Zählen zeigt den Unterschied, dann "In der Lade lassen", dann ist der Tag zu',
      (t) async {
        await pumpCloseReady(t);
        await tapKeys(t, '1 6 8');
        expect(textOf(t, const Key('difference-label')), 'Es fehlen');
        expect(textOf(t, const Key('difference')), '0,20 €');
        await t.tap(find.byKey(const Key('count-next')));
        await t.pump();
        expect(
          find.text('Wie viel bleibt als Wechselgeld in der Lade?'),
          findsOneWidget,
        );
        expect(textOf(t, const Key('difference-signed')), '−0,20 €');
        await tapKeys(t, '1 5 0');
        await t.tap(find.byKey(const Key('close-day')));
        await t.pumpAndSettle();
        expect(find.text('Der Tag ist abgeschlossen.'), findsOneWidget);
        expect(find.text('Entnommen: 18,00 €'), findsOneWidget);
        expect(
          find.text('Morgen liegen 150,00 € Wechselgeld in der Lade.'),
          findsOneWidget,
        );
        expect(find.text('Abgeschlossen von Chef um 11:00 Uhr'), findsOneWidget);
        expect(find.text('Abgeschlossen'), findsOneWidget); // Pille links
        expect(textOf(t, const Key('left-counted')), '168,00 €');
        expect(textOf(t, const Key('left-difference')), '−0,20 €');
      },
    );

    testWidgets('Schritt 1: ohne Eingabe, stimmt genau, zu viel', (t) async {
      await pumpCloseReady(t);
      expect(find.text('Noch nichts eingetippt'), findsOneWidget);
      expect(_enabled(t, 'count-next'), isFalse);
      await tapKeys(t, '1 6 8 , 2');
      expect(textOf(t, const Key('difference-label')), 'Stimmt genau');
      expect(_enabled(t, 'count-next'), isTrue);
      await tapKeys(t, 'back back back back 7 0');
      expect(textOf(t, const Key('amount-field')), '170 €');
      expect(textOf(t, const Key('difference-label')), 'Zu viel in der Lade');
      expect(textOf(t, const Key('difference')), '1,80 €');
    });

    testWidgets('Zurück behält den gezählten Betrag', (t) async {
      await pumpCloseReady(t);
      await tapKeys(t, '1 6 8');
      await _tap(t, 'count-next');
      expect(find.text('Schritt 2 von 2'), findsOneWidget);
      await tapKeys(t, '1 0 0');
      await _tap(t, 'count-back');
      expect(find.text('Schritt 1 von 2'), findsOneWidget);
      expect(textOf(t, const Key('amount-field')), '168 €');
    });

    testWidgets('Schritt 2 zeigt, was herausgenommen wird', (t) async {
      await pumpCloseReady(t);
      await tapKeys(t, '1 6 8');
      await _tap(t, 'count-next');
      expect(_enabled(t, 'close-day'), isFalse);
      await tapKeys(t, '1 5 0');
      expect(textOf(t, const Key('take-out')), '18,00 €');
      expect(_enabled(t, 'close-day'), isTrue);
    });

    testWidgets('0 in der Lade lassen ist erlaubt', (t) async {
      await pumpCloseReady(t);
      await tapKeys(t, '1 6 8');
      await _tap(t, 'count-next');
      await tapKeys(t, '0');
      expect(textOf(t, const Key('take-out')), '168,00 €');
      expect(_enabled(t, 'close-day'), isTrue);
    });

    testWidgets('mehr in der Lade lassen als gezählt geht nicht', (t) async {
      await pumpCloseReady(t);
      await tapKeys(t, '1 6 8');
      await _tap(t, 'count-next');
      await tapKeys(t, '1 6 9');
      expect(
        find.text('Mehr als gezählt kann nicht in der Lade bleiben.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('take-out')), findsNothing);
      expect(_enabled(t, 'close-day'), isFalse);
      await tapKeys(t, 'back');
      expect(find.text('Mehr als gezählt kann nicht in der Lade bleiben.'), findsNothing);
      expect(_enabled(t, 'close-day'), isTrue);
    });

    testWidgets('der Abschluss speichert Gezählt, Gelassen, Unterschied und den Namen', (t) async {
      await pumpCloseReady(t);
      await _closeDay(t);
      final day = (await containerOf(t).read(dayRepositoryProvider).lastClosedDay())!;
      expect(day.countedCents, 16820);
      expect(day.leftInDrawerCents, 15000);
      expect(day.expectedCents, 16820);
      expect(day.differenceCents, 0);
      expect(day.closedByName, 'Chef');
      expect(textOf(t, const Key('left-difference')), '0,00 €');
    });

    testWidgets('zweimal schnell auf "Tag abschließen" schließt einmal', (t) async {
      late _CountingDays days;
      await pumpClose(
        t,
        floatCents: 15000,
        extra: [
          dayRepositoryProvider.overrideWith((ref) {
            return days = _CountingDays(ref.watch(databaseProvider), ref.watch(clockProvider));
          }),
        ],
      );
      await tapKeys(t, '1 6 8 , 2 0');
      await _tap(t, 'count-next');
      await tapKeys(t, '1 5 0');
      await t.tap(find.byKey(const Key('close-day')));
      await t.tap(find.byKey(const Key('close-day')));
      await t.pumpAndSettle();
      expect(days.closes, 1);
      expect(find.text('Der Tag ist abgeschlossen.'), findsOneWidget);
    });

    testWidgets('ein Fehler beim Schließen zeigt den Hinweis und behält die Eingabe', (t) async {
      await pumpCloseReady(t);
      await tapKeys(t, '1 6 8');
      await _tap(t, 'count-next');
      await tapKeys(t, '1 5 0');
      // Jemand anderer schließt den Tag, bevor die Taste gedrückt wird.
      final c = containerOf(t);
      await c
          .read(dayRepositoryProvider)
          .close(countedCents: 100, leftInDrawerCents: 0, staff: c.read(sessionProvider)!);
      await t.tap(find.byKey(const Key('close-day')));
      await t.pumpAndSettle();
      expect(find.text('Das hat nicht geklappt. Bitte nochmal versuchen.'), findsOneWidget);
      expect(textOf(t, const Key('amount-field')), '150 €');
    });
  });

  group('ohne Geldlade', () {
    testWidgets('heißt der Teil "Bargeld" in allen Schritten', (t) async {
      await pumpCloseReady(t, drawer: false);
      expect(find.text('Geldlade'), findsNothing);
      expect(find.text('Bargeld'), findsOneWidget); // Karte links
      expect(find.text('Bargeld zählen'), findsOneWidget);
      expect(find.text('Soll in bar'), findsWidgets);
      await tapKeys(t, '1 7 0');
      expect(textOf(t, const Key('difference-label')), 'Zu viel Bargeld');
      await _tap(t, 'count-next');
      expect(find.text('Wechselgeld für morgen'), findsOneWidget);
      expect(find.text('Wie viel bleibt als Wechselgeld?'), findsOneWidget);
      await tapKeys(t, '1 5 0');
      await _tap(t, 'close-day');
      expect(
        find.text('Morgen sind 150,00 € Wechselgeld da.'),
        findsOneWidget,
      );
      expect(find.textContaining('Geldlade'), findsNothing);
    });
  });

  group('Tag abgeschlossen', () {
    testWidgets('kein offener Tag: Hinweis und der letzte Abschluss', (t) async {
      await pumpCloseReady(t);
      await _closeDay(t);
      await _tap(t, 'tab-Bons');
      await _tap(t, 'tab-Abschluss');
      expect(find.text('Es gibt keinen offenen Tag.'), findsOneWidget);
      expect(find.text('Der nächste Tag beginnt mit dem ersten Bon.'), findsOneWidget);
      expect(find.text('Der Tag ist abgeschlossen.'), findsNothing);
      expect(find.text('Entnommen: 18,20 €'), findsOneWidget);
      expect(find.text('Abgeschlossen'), findsOneWidget);
      expect(textOf(t, const Key('left-expected')), '168,20 €');
    });

    testWidgets('"Zur Kassa" wechselt den Bereich', (t) async {
      await pumpCloseReady(t);
      await _closeDay(t);
      await _tap(t, 'to-kassa');
      expect(find.byKey(const Key('area-kassa')), findsOneWidget);
      expect(find.byKey(const Key('area-close')), findsNothing);
    });

    testWidgets('der nächste Verkauf öffnet einen neuen Tag mit dem Wechselgeld', (t) async {
      await pumpCloseReady(t);
      await _closeDay(t);
      await sellCash(t);
      await _tap(t, 'tab-Bons');
      await _tap(t, 'tab-Abschluss');
      expect(find.byKey(const Key('expected-cash')), findsOneWidget);
      expect(textOf(t, const Key('left-float')), '150,00 €');
    });
  });

  group('linke Seite', () {
    testWidgets('Titel, Datum und Einnahmen', (t) async {
      await pumpCloseReady(t);
      expect(find.text('Tagesabschluss'), findsOneWidget);
      expect(find.text('Dienstag, 17. November'), findsOneWidget);
      expect(find.text('Abgeschlossen'), findsNothing);
      expect(find.text('1 Bon'), findsWidgets);
      expect(textOf(t, const Key('left-cash')), '18,20 €');
      expect(textOf(t, const Key('left-float')), '150,00 €');
      expect(find.text('Noch offen'), findsOneWidget); // Gezählt
      expect(find.text('Storniert'), findsNothing);
      expect(find.text('MwSt 10 %'), findsOneWidget);
      expect(find.text('Pfand, ohne MwSt'), findsOneWidget);
    });

    testWidgets('Storniert und Bons je Zahlungsart nach einem Storno', (t) async {
      await pumpClose(t, sales: 3, floatCents: 15000);
      final c = containerOf(t);
      final receipts = await c.read(receiptRepositoryProvider).watchDay(
        (await c.read(dayRepositoryProvider).openDay())!.id,
      ).first;
      await c
          .read(receiptRepositoryProvider)
          .voidReceipt(receipts.first.id, staff: c.read(sessionProvider)!);
      await _tap(t, 'tab-Bons');
      await _tap(t, 'tab-Abschluss');
      expect(find.text('Storniert'), findsOneWidget);
      expect(find.text('1 Bon'), findsWidgets); // Storniert
      expect(find.text('2 Bons'), findsWidgets); // Bar und Gesamt
      expect(textOf(t, const Key('left-voided')), '18,20 €');
      expect(textOf(t, const Key('left-cash')), '36,40 €');
      expect(textOf(t, const Key('left-expected')), '186,40 €');
    });

    testWidgets('ohne Geldlade heißt die Karte "Bargeld"', (t) async {
      await pumpCloseReady(t, drawer: false);
      expect(find.text('Soll in bar'), findsWidgets);
      expect(find.text('Soll in der Lade'), findsNothing);
    });
  });

  group('Hinweis auf vergessenen Abschluss', () {
    testWidgets('Hinweis nach der Anmeldung, Bonieren bleibt möglich', (t) async {
      await pumpShellNextMorningWithOpenDay(t);
      expect(find.byKey(const Key('forgotten-close')), findsOneWidget);
      expect(find.text('Der letzte Tag ist noch nicht abgeschlossen.'), findsOneWidget);
      await tapItem(t, 'cola');
      expect(textOf(t, const Key('cart-total')), '3,15 €');
    });

    testWidgets('Mitarbeiter sehen nur den Text', (t) async {
      await pumpShellNextMorningWithOpenDay(t, pin: '1234');
      expect(find.byKey(const Key('forgotten-close')), findsOneWidget);
      expect(find.byKey(const Key('forgotten-close-go')), findsNothing);
    });

    testWidgets('kein Hinweis am selben Tag', (t) async {
      await pumpClose(t, openArea: false);
      expect(find.byKey(const Key('forgotten-close')), findsNothing);
    });

    testWidgets('der Chef kommt mit der Taste in den Abschluss, dort steht kein Hinweis, nach dem Abschluss ist er weg', (t) async {
      await pumpShellNextMorningWithOpenDay(t);
      expect(find.byKey(const Key('forgotten-close-go')), findsOneWidget);
      await _tap(t, 'tab-Bons');
      expect(find.byKey(const Key('forgotten-close')), findsOneWidget);
      await _tap(t, 'forgotten-close-go');
      expect(find.byKey(const Key('area-close')), findsOneWidget);
      expect(find.byKey(const Key('forgotten-close')), findsNothing);
      // Der gestrige Tag hat noch kein Wechselgeld.
      await tapKeys(t, '1 5 0');
      await _tap(t, 'set-float');
      await _closeDay(t);
      await _tap(t, 'to-kassa');
      expect(find.byKey(const Key('forgotten-close')), findsNothing);
    });
  });

  group('Hinweis bei angemeldeter Kassa über Nacht', () {
    testWidgets('kommt die App am Morgen zurück in den Vordergrund, erscheint der Hinweis', (t) async {
      final clock = FixedClock(DateTime(2026, 11, 17, 20));
      await pumpClose(t, openArea: false, clock: clock);
      await t.pumpAndSettle(); // der Strom hat den offenen Tag gemeldet
      expect(find.byKey(const Key('forgotten-close')), findsNothing);
      clock.value = DateTime(2026, 11, 18, 9);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pump();
      expect(find.byKey(const Key('forgotten-close')), findsOneWidget);
    });

    testWidgets('bleibt die App im Vordergrund, erscheint der Hinweis nach spätestens einer Minute', (t) async {
      final clock = FixedClock(DateTime(2026, 11, 17, 23, 59));
      await pumpClose(t, openArea: false, clock: clock);
      await t.pumpAndSettle(); // der Strom hat den offenen Tag gemeldet
      expect(find.byKey(const Key('forgotten-close')), findsNothing);
      clock.value = DateTime(2026, 11, 18, 0, 1);
      await t.pump(const Duration(minutes: 1));
      expect(find.byKey(const Key('forgotten-close')), findsOneWidget);
    });
  });

  group('Größe und Tippflächen', () {
    for (final drawer in [true, false]) {
      testWidgets('läuft bei 960 x 600 und Textskala 1,3 nicht über (Geldlade: $drawer)', (t) async {
        await pumpClose(
          t,
          floatCents: 15000,
          size: const Size(960, 600),
          textScale: 1.3,
          drawer: drawer,
        );
        expect(t.takeException(), isNull); // Zustand B
        await _scrollKeys(t, '1 6 8 , 2 0');
        await _tap(t, 'cash-out');
        await _scrollKeys(t, '2 0');
        await t.tap(find.byKey(const Key('reason-purchase')));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull); // Zustand D
        await _tap(t, 'close-movement');
        await _tap(t, 'count-next');
        await _scrollKeys(t, '1 5 0');
        expect(t.takeException(), isNull); // Zustand C
        await _scrollKeys(t, '0 0 0');
        expect(t.takeException(), isNull); // zu viel
        await _scrollKeys(t, 'back back back back');
        await _tap(t, 'close-day');
        expect(t.takeException(), isNull); // Zustand E
      });
    }

    testWidgets('Zustand A läuft bei 960 x 600 und Textskala 1,3 nicht über', (t) async {
      await pumpClose(t, size: const Size(960, 600), textScale: 1.3);
      expect(t.takeException(), isNull);
    });

    testWidgets('alle Tasten sind mindestens 48 dp hoch, Hauptaktionen 64 bis 80', (t) async {
      await pumpClose(t, sales: 1);
      expect(t.getSize(find.byKey(const Key('set-float'))).height, 80);
      await tapKeys(t, '1 5 0');
      await _tap(t, 'set-float');
      for (final k in ['cash-in', 'cash-out']) {
        expect(t.getSize(find.byKey(Key(k))).height, greaterThanOrEqualTo(48));
      }
      await tapKeys(t, '1');
      expect(t.getSize(find.byKey(const Key('count-next'))).height, 80);
      await _tap(t, 'count-next');
      expect(t.getSize(find.byKey(const Key('count-back'))).height, greaterThanOrEqualTo(64));
      expect(t.getSize(find.byKey(const Key('close-day'))).height, 80);
      await _tap(t, 'count-back');
      await _tap(t, 'cash-in');
      expect(t.getSize(find.byKey(const Key('close-movement'))).height, greaterThanOrEqualTo(48));
      expect(t.getSize(find.byKey(const Key('close-movement'))).width, greaterThanOrEqualTo(48));
      for (final r in ['bank', 'purchase', 'change', 'other']) {
        expect(t.getSize(find.byKey(Key('reason-$r'))).height, greaterThanOrEqualTo(48));
      }
      expect(t.getSize(find.byKey(const Key('save-movement'))).height, greaterThanOrEqualTo(64));
    });

    testWidgets('"Jetzt abschließen" ist mindestens 48 dp hoch', (t) async {
      await pumpShellNextMorningWithOpenDay(t);
      expect(
        t.getSize(find.byKey(const Key('forgotten-close-go'))).height,
        greaterThanOrEqualTo(48),
      );
    });
  });
}
