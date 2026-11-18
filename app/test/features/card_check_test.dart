// "Karte prüfen" in den Einstellungen: die Karte "Signatur", der Bildschirm
// mit fünf Zeilen und das PIN-Fenster, gegen den nachgebauten Leser über die
// Provider. Die PINs stehen nur in den Körpern der Tests.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/app.dart';
import 'package:kassa/core/clock.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/rksv/card/card_check.dart';
import 'package:kassa/rksv/card/card_providers.dart';
import 'package:kassa/rksv/card/pin_guard.dart';
import 'package:kassa/rksv/card/reader_transport.dart';
import 'package:kassa/ui/keypad.dart';
import 'package:kassa/ui/pressable.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../support/fake_card_reader.dart';
import '../support/kassa_pump.dart' show containerOf;
import '../support/pump.dart' show typePin;
import '../support/settings_pump.dart';

const _cardNumber = '0102030405060708';
const _lastTry = 'Die PIN war falsch. Die Karte hat nur noch einen Versuch.';
const _lastTryHint =
    'Die Kassa schickt die PIN jetzt nicht mehr. Wird die Karte in der alten '
    'Kassa mit der richtigen PIN verwendet, ist der Zähler wieder voll.';

Finder _key(String key) => find.byKey(Key(key));

CardCheck _check(WidgetTester t) => containerOf(t).read(cardCheckProvider);

RowResult _row(WidgetTester t, CheckRow row) => _check(t).state.rows[row]!;

/// Das Zeichen der Zeile [row] mit seiner Semantik.
Finder _sign(CheckRow row) => _key('card-check-sign-${row.name}');

String? _signLabel(WidgetTester t, CheckRow row) =>
    t.getSemantics(_sign(row)).label;

Future<void> _run(WidgetTester t) async {
  await t.tap(_key('card-check-run'));
  await t.pumpAndSettle();
}

Future<void> _openPin(WidgetTester t) async {
  await t.ensureVisible(_key('card-check-pin'));
  await t.pumpAndSettle();
  await t.tap(_key('card-check-pin'));
  await t.pumpAndSettle();
}

/// Ist die Taste mit [key] eingeschaltet?
bool _enabled(WidgetTester t, String key) {
  final pressable = t.widget<Pressable>(
    find.descendant(of: _key(key), matching: find.byType(Pressable)).first,
  );
  return pressable.onTap != null;
}

/// Alle Texte im Baum unter [of].
List<String> _texts(WidgetTester t, Finder of) => [
  for (final e
      in find.descendant(of: of, matching: find.byType(Text)).evaluate())
    (e.widget as Text).data ?? (e.widget as Text).textSpan?.toPlainText() ?? '',
];

/// Alle Beschriftungen und Werte der Semantik der App, das PIN-Fenster
/// eingeschlossen.
List<String> _semanticTexts(WidgetTester t) {
  final out = <String>[];
  void visit(SemanticsNode node) {
    final data = node.getSemanticsData();
    out
      ..add(data.label)
      ..add(data.value)
      ..add(data.hint)
      ..add(data.tooltip);
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(t.getSemantics(find.byType(KassaApp)));
  return out;
}

/// Reicht alles an den nachgebauten Leser weiter; `open` wartet, bis
/// [release] gerufen wird (Android fragt nach der Erlaubnis).
class _GatedReader implements ReaderTransport {
  _GatedReader(this.inner);

  final FakeCardReader inner;
  final _gate = Completer<void>();

  void release() {
    if (!_gate.isCompleted) _gate.complete();
  }

  @override
  Future<List<UsbDeviceInfo>> list() => inner.list();

  @override
  Future<TabletInfo> info() => inner.info();

  @override
  Future<Uint8List> open(String address) async {
    await _gate.future;
    return inner.open(address);
  }

  @override
  Future<Uint8List> exchange(Uint8List? out, {required Duration limit}) =>
      inner.exchange(out, limit: limit);

  @override
  Future<void> close() => inner.close();
}

/// Reicht alles an den nachgebauten Leser weiter; ist [armed], wartet
/// `close`, bis [release] gerufen wird (der Lauf ist so lange beschäftigt).
class _CloseGate implements ReaderTransport {
  _CloseGate(this.inner);

  final FakeCardReader inner;
  final _gate = Completer<void>();
  bool armed = false;

  void release() {
    if (!_gate.isCompleted) _gate.complete();
  }

  @override
  Future<List<UsbDeviceInfo>> list() => inner.list();

  @override
  Future<TabletInfo> info() => inner.info();

  @override
  Future<Uint8List> open(String address) => inner.open(address);

  @override
  Future<Uint8List> exchange(Uint8List? out, {required Duration limit}) =>
      inner.exchange(out, limit: limit);

  @override
  Future<void> close() async {
    if (armed) await _gate.future;
    await inner.close();
  }
}

void main() {
  testWidgets(
    'Einstellungen zeigen die Karte "Signatur" mit "Nicht eingerichtet"; Tippen öffnet "Karte prüfen"',
    (t) async {
      await pumpSettings(t);
      final card = _key('signature-card');
      expect(card, findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.text('Signatur')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text('Signatur der Bons')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: card,
          matching: find.text(
            'Für die Registrierkassen-Pflicht. Noch nicht eingerichtet.',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text('Nicht eingerichtet')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: card,
          matching: find.text('Kartenleser und Signaturkarte ausprobieren.'),
        ),
        findsOneWidget,
      );
      // Oben in der linken Spalte, "Geräte an dieser Kassa" rechts daneben
      // (Entwurf `s1b-2`).
      final devices = t.getRect(find.text('Geräte an dieser Kassa'));
      final signature = t.getRect(card);
      expect(signature.left, lessThan(640));
      expect(devices.left, greaterThan(640));
      expect(signature.top, lessThan(devices.top));

      await t.ensureVisible(_key('open-card-check'));
      await t.pumpAndSettle();
      await t.tap(_key('open-card-check'));
      await t.pumpAndSettle();
      expect(_key('card-check'), findsOneWidget);
      expect(find.text('Karte prüfen'), findsOneWidget);
      expect(find.text('Was hier geprüft wird'), findsOneWidget);
      expect(
        find.text(
          'Hier siehst du, ob Tablet, Verteiler, Kartenleser und '
          'Signaturkarte zusammenarbeiten. Auf der Karte wird nichts '
          'verändert.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Steckt die Karte sonst in der alten Kassa, kann dort in dieser '
          'Zeit kein Bon erstellt werden.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'vor dem Start: fünf wartende Zeilen, Taste "Jetzt prüfen", kein "Bericht teilen"',
    (t) async {
      await pumpCardCheck(t);
      for (final (row, title) in [
        (CheckRow.reader, 'Kartenleser'),
        (CheckRow.access, 'Zugriff'),
        (CheckRow.card, 'Signaturkarte'),
        (CheckRow.certificate, 'Zertifikat'),
        (CheckRow.signature, 'Probe-Unterschrift'),
      ]) {
        final box = _key('card-check-row-${row.name}');
        expect(
          find.descendant(of: box, matching: find.text(title)),
          findsOneWidget,
        );
        // Die Nummer im Kreis, und der Text kommt unverändert aus Task 6.
        expect(
          find.descendant(of: box, matching: find.text('${row.index + 1}')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: box, matching: find.text(_row(t, row).message)),
          findsOneWidget,
        );
        expect(_signLabel(t, row), 'wartet');
      }
      expect(
        find.text('Wird geprüft, sobald du auf "Jetzt prüfen" tippst.'),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _key('card-check-run'),
          matching: find.text('Jetzt prüfen'),
        ),
        findsOneWidget,
      );
      expect(_enabled(t, 'card-check-run'), isTrue);
      expect(_key('card-check-share'), findsNothing);
      expect(_key('card-check-pin'), findsNothing);
      expect(_key('card-check-reset-guard'), findsNothing);
    },
  );

  testWidgets(
    '"Jetzt prüfen": Zeilen 1 bis 4 werden grün, Taste heißt "Nochmal prüfen", "PIN eingeben" erscheint',
    (t) async {
      late _GatedReader gated;
      await pumpCardCheck(t, wrap: (r) => gated = _GatedReader(r));
      await t.tap(_key('card-check-run'));
      // Während des Laufs ist die Hauptaktion gesperrt, ein zweiter Tipp
      // startet nichts.
      await t.pump();
      expect(_check(t).state.busy, isTrue);
      expect(_enabled(t, 'card-check-run'), isFalse);
      await t.tap(_key('card-check-run'), warnIfMissed: false);
      await t.pump();
      expect(_signLabel(t, CheckRow.access), 'läuft');
      gated.release();
      await t.pumpAndSettle();
      expect(gated.inner.opened, hasLength(1));

      for (final row in CheckRow.values.take(4)) {
        expect(_row(t, row).state, RowState.ok, reason: row.name);
        expect(_signLabel(t, row), 'in Ordnung');
        expect(find.text(_row(t, row).message), findsOneWidget);
      }
      expect(find.text('Beispiel-Kartenleser gefunden.'), findsOneWidget);
      expect(
        find.text('Die Kassa darf den Kartenleser verwenden.'),
        findsOneWidget,
      );
      final hint = _row(t, CheckRow.card).hint;
      expect(hint, isNotNull);
      expect(find.text(hint!), findsOneWidget);
      expect(find.textContaining('gültig bis 30.06.2031.'), findsOneWidget);
      expect(_signLabel(t, CheckRow.signature), 'wartet');
      expect(
        find.descendant(
          of: _key('card-check-run'),
          matching: find.text('Nochmal prüfen'),
        ),
        findsOneWidget,
      );
      expect(_enabled(t, 'card-check-run'), isTrue);
      expect(_key('card-check-pin'), findsOneWidget);
      expect(
        find.descendant(
          of: _key('card-check-pin'),
          matching: find.text('PIN eingeben'),
        ),
        findsOneWidget,
      );
      expect(_key('card-check-share'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'das Öffnen des Bildschirms startet keinen Lauf und fragt keine Erlaubnis an',
    (t) async {
      final reader = await pumpCardCheck(t);
      await t.pump(const Duration(seconds: 2));
      expect(reader.opened, isEmpty);
      expect(reader.exchanges, 0);
      expect(reader.closed, 0);
      expect(_check(t).state.busy, isFalse);
      for (final row in CheckRow.values) {
        expect(_row(t, row).state, RowState.waiting, reason: row.name);
      }
      // Auch Zurück und wieder Öffnen startet nichts.
      await t.tap(_key('card-check-back'));
      await t.pumpAndSettle();
      await t.ensureVisible(_key('open-card-check'));
      await t.pumpAndSettle();
      await t.tap(_key('open-card-check'));
      await t.pumpAndSettle();
      expect(reader.opened, isEmpty);
      expect(reader.exchanges, 0);
    },
  );

  testWidgets(
    'PIN-Fenster: 5 Ziffern lassen "Unterschrift erstellen" gesperrt, 4 und 6 geben frei, 7. Ziffer wird verworfen',
    (t) async {
      final reader = await pumpCardCheck(t);
      await _run(t);
      await _openPin(t);
      expect(find.text('PIN der Signaturkarte'), findsOneWidget);
      expect(
        find.text(
          'Das ist nicht deine Chef-PIN. Nach drei falschen Versuchen sperrt '
          'sich die Karte.',
        ),
        findsOneWidget,
      );
      expect(find.text('Abbrechen'), findsOneWidget);
      expect(find.text('Unterschrift erstellen'), findsOneWidget);
      expect(_enabled(t, 'card-pin-submit'), isFalse);

      String slots() => t.getSemantics(_key('card-pin-slots')).label;
      expect(slots(), '0 von 6 Ziffern eingegeben');
      await typePin(t, '123');
      expect(_enabled(t, 'card-pin-submit'), isFalse);
      await typePin(t, '4');
      expect(slots(), '4 von 6 Ziffern eingegeben');
      expect(_enabled(t, 'card-pin-submit'), isTrue);
      await typePin(t, '5');
      expect(slots(), '5 von 6 Ziffern eingegeben');
      expect(_enabled(t, 'card-pin-submit'), isFalse);
      await typePin(t, '6');
      expect(_enabled(t, 'card-pin-submit'), isTrue);
      await typePin(t, '7');
      expect(slots(), '6 von 6 Ziffern eingegeben');
      expect(_enabled(t, 'card-pin-submit'), isTrue);
      // Löschen nimmt die letzte Ziffer weg.
      await t.tap(_key('key-back'));
      await t.pump();
      expect(slots(), '5 von 6 Ziffern eingegeben');
      expect(_enabled(t, 'card-pin-submit'), isFalse);
      await typePin(t, '6');

      // Nichts wurde von selbst abgeschickt, auch nicht nach Warten.
      await t.pump(const Duration(seconds: 5));
      expect(reader.card!.verifyCount, 0);
      expect(find.text('PIN der Signaturkarte'), findsOneWidget);

      // Zweimal schnell tippen: genau eine Probe-Unterschrift.
      await t.tap(_key('card-pin-submit'));
      await t.tap(_key('card-pin-submit'), warnIfMissed: false);
      await t.pumpAndSettle();
      expect(find.text('PIN der Signaturkarte'), findsNothing);
      // Eine Probe-Unterschrift prüft die PIN in drei Runden.
      expect(reader.card!.verifyCount, 3);
      expect(reader.card!.signCount, 3);
    },
  );

  testWidgets('PIN-Fenster: weder Text noch Semantik enthalten die Ziffern', (
    t,
  ) async {
    final semantics = t.ensureSemantics();
    await pumpCardCheck(t);
    await _run(t);
    const pin = '907153';
    String tree() => t.element(find.byType(KassaApp)).toStringDeep();
    expect(tree(), isNot(contains(pin)));
    await _openPin(t);
    await typePin(t, pin);

    final sheet = _key('card-pin-sheet');
    expect(sheet, findsOneWidget);
    // Außer den Beschriftungen des Zahlenfelds steht keine Ziffer im Fenster.
    final keypad = find.descendant(of: sheet, matching: find.byType(Keypad));
    final keypadTexts = _texts(t, keypad);
    final others = [
      for (final s in _texts(t, sheet))
        if (!keypadTexts.contains(s)) s,
    ];
    expect(others, isNotEmpty);
    for (final s in others) {
      expect(s, isNot(matches(RegExp(r'[0-9]'))), reason: s);
    }
    // Die Plätze zeigen Punkte und sagen nur, wie viele Ziffern es sind.
    expect(
      t.getSemantics(_key('card-pin-slots')).label,
      '6 von 6 Ziffern eingegeben',
    );
    for (final s in _semanticTexts(t)) {
      for (var i = 0; i + 2 <= pin.length; i++) {
        expect(s, isNot(contains(pin.substring(i, i + 2))), reason: s);
      }
    }
    // Kein Key, kein Diagnose-Text im ganzen Baum enthält die PIN.
    for (final e in find.byType(Widget).evaluate()) {
      final key = e.widget.key;
      if (key != null) expect('$key', isNot(contains(pin)));
    }
    expect(tree(), isNot(contains(pin)));

    // Abbrechen: das Fenster ist zu, nichts ging zur Karte.
    await t.tap(find.text('Abbrechen'));
    await t.pumpAndSettle();
    expect(sheet, findsNothing);
    expect(cardReaderOf(t).card!.verifyCount, 0);
    expect(tree(), isNot(contains(pin)));
    semantics.dispose();
  });

  testWidgets('richtige PIN: Zeile 5 grün mit Dauer', (t) async {
    final reader = await pumpCardCheck(t);
    // Jeder Austausch mit dem Leser dauert 50 ms.
    final clock = containerOf(t).read(clockProvider) as FixedClock;
    reader.onExchange = (_) =>
        clock.value = clock.value.add(const Duration(milliseconds: 50));
    await _run(t);
    await _openPin(t);
    await typePin(t, '123456');
    await t.tap(_key('card-pin-submit'));
    await t.pumpAndSettle();

    final row = _row(t, CheckRow.signature);
    expect(row.state, RowState.ok);
    expect(
      row.message,
      matches(
        RegExp(
          r'^Unterschrift erstellt und geprüft\. Dauer: \d+,\d Sekunden\.$',
        ),
      ),
    );
    expect(row.message, isNot(contains('0,0')));
    final message = find.text(row.message);
    expect(message, findsOneWidget);
    // Die Dauer steht in Tabellenziffern.
    final style = t.widget<Text>(message).style;
    final features = style?.fontFeatures ?? const <FontFeature>[];
    final inherited = DefaultTextStyle.of(t.element(message)).style;
    expect([
      ...features,
      ...?inherited.fontFeatures,
    ], contains(const FontFeature.tabularFigures()));
    expect(_signLabel(t, CheckRow.signature), 'in Ordnung');
    expect(_key('card-check-pin'), findsNothing);
  });

  testWidgets(
    'falsche PIN: Text "Noch 2 Versuche.", das PIN-Fenster öffnet sich nicht von selbst wieder',
    (t) async {
      final reader = await pumpCardCheck(t);
      await _run(t);
      await _openPin(t);
      await typePin(t, '654321');
      await t.tap(_key('card-pin-submit'));
      await t.pumpAndSettle();
      await t.pump(const Duration(seconds: 5));
      await t.pumpAndSettle();

      expect(find.text('Die PIN war falsch. Noch 2 Versuche.'), findsOneWidget);
      expect(
        find.text(
          'Frag im Betrieb nach der richtigen PIN, bevor du es nochmal '
          'versuchst.',
        ),
        findsOneWidget,
      );
      expect(_signLabel(t, CheckRow.signature), 'Fehler');
      expect(_key('card-pin-sheet'), findsNothing);
      expect(find.text('PIN der Signaturkarte'), findsNothing);
      expect(reader.card!.verifyCount, 1);
      // Ein neuer Versuch geht nur über die Taste.
      expect(_key('card-check-pin'), findsOneWidget);
    },
  );

  testWidgets(
    'guardBlocks: "PIN eingeben" fehlt, "Zähler ist wieder voll" wirkt erst nach "Ja, …"',
    (t) async {
      final guard = MemoryPinGuard({_cardNumber: 1});
      final reader = await pumpCardCheck(t, guard: guard);
      await _run(t);
      expect(_check(t).state.guardBlocks, isTrue);
      expect(_check(t).state.cardLocked, isFalse);
      // Zeile 5 zeigt Text und Hinweis des Wächters, wie sie kommen.
      final row = _row(t, CheckRow.signature);
      expect(row.state, RowState.problem);
      expect(find.text(row.message), findsOneWidget);
      expect(find.text(row.hint!), findsOneWidget);
      expect(_signLabel(t, CheckRow.signature), 'Fehler');
      expect(_key('card-check-pin'), findsNothing);
      expect(_key('card-check-reset-guard'), findsOneWidget);
      expect(t.takeException(), isNull);

      // Antippen fragt erst nach; der Zähler bleibt.
      await t.ensureVisible(_key('card-check-reset-guard'));
      await t.pumpAndSettle();
      await t.tap(_key('card-check-reset-guard'));
      await t.pumpAndSettle();
      expect(
        find.text(
          'Wurde die Karte seit dem Fehlversuch in der alten Kassa mit der '
          'richtigen PIN verwendet? Ist die nächste PIN falsch, sperrt sich '
          'die Karte.',
        ),
        findsOneWidget,
      );
      expect(await guard.retriesLeft(_cardNumber), 1);
      expect(_check(t).state.guardBlocks, isTrue);

      // "Abbrechen" lässt alles, wie es war.
      await t.tap(_key('card-check-reset-cancel'));
      await t.pumpAndSettle();
      expect(await guard.retriesLeft(_cardNumber), 1);
      expect(_key('card-check-reset-guard'), findsOneWidget);

      await t.tap(_key('card-check-reset-guard'));
      await t.pumpAndSettle();
      expect(find.text('Ja, Zähler ist wieder voll'), findsOneWidget);
      await t.tap(find.text('Ja, Zähler ist wieder voll'));
      await t.pumpAndSettle();
      expect(await guard.retriesLeft(_cardNumber), isNull);
      expect(_check(t).state.guardBlocks, isFalse);
      expect(_key('card-check-reset-guard'), findsNothing);
      expect(_key('card-check-pin'), findsOneWidget);
      // Zur Karte ging dabei nichts.
      expect(reader.card!.verifyCount, 0);
    },
  );

  testWidgets(
    'solange die Probe-Unterschrift noch läuft, fehlt "Zähler ist wieder voll", auch wenn der Wächter schon sperrt',
    (t) async {
      late _CloseGate gate;
      final reader = await pumpCardCheck(
        t,
        card: testSignatureCard(retriesLeft: 2),
        wrap: (inner) => gate = _CloseGate(inner),
      );
      await _run(t);
      expect(_check(t).state.canSign, isTrue);
      gate.armed = true;
      await _openPin(t);
      await typePin(t, '654321');
      await t.tap(_key('card-pin-submit'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 50));

      // 63C1 ist da, der Leser wird noch freigegeben.
      final state = _check(t).state;
      expect(state.busy, isTrue);
      expect(state.guardBlocks, isTrue);
      expect(state.cardLocked, isFalse);
      expect(find.text(_lastTry), findsOneWidget);
      expect(_key('card-check-reset-guard'), findsNothing);
      expect(find.text('Zähler ist wieder voll'), findsNothing);

      gate.release();
      await t.pumpAndSettle();
      expect(_check(t).state.busy, isFalse);
      expect(_key('card-check-reset-guard'), findsOneWidget);
      expect(reader.card!.verifyCount, 1);
    },
  );

  testWidgets(
    'guardBlocks mit gesperrter Karte: keine Taste "Zähler ist wieder voll"',
    (t) async {
      await pumpCardCheck(t, guard: MemoryPinGuard({_cardNumber: 0}));
      await _run(t);
      expect(_check(t).state.guardBlocks, isTrue);
      expect(_check(t).state.cardLocked, isTrue);
      expect(find.text('Die Karte ist gesperrt.'), findsOneWidget);
      expect(_key('card-check-reset-guard'), findsNothing);
      expect(_key('card-check-pin'), findsNothing);
    },
  );

  testWidgets(
    '"Bericht teilen" übergibt Betreff und Bericht; false zeigt den Hinweis',
    (t) async {
      final share = FakeShareSheet();
      await pumpCardCheck(t, share: share);
      await _run(t);
      expect(_key('card-check-share'), findsOneWidget);
      expect(t.getSize(_key('card-check-share')).height, 64);
      await t.tap(_key('card-check-share'));
      await t.pumpAndSettle();
      expect(share.calls, hasLength(1));
      expect(share.calls.single.subject, 'Kassa: Bericht Karte prüfen');
      expect(share.calls.single.text, _check(t).state.report);
      expect(
        share.calls.single.text,
        startsWith('Kassa: Bericht "Karte prüfen"'),
      );
      expect(find.text('Teilen geht auf diesem Tablet nicht.'), findsNothing);

      share.result = false;
      await t.tap(_key('card-check-share'));
      await t.pumpAndSettle();
      expect(share.calls, hasLength(2));
      expect(find.text('Teilen geht auf diesem Tablet nicht.'), findsOneWidget);
    },
  );

  testWidgets(
    'keine Karte: Zeile 3 mit Kreuz und Hinweis, Zeilen 4 und 5 mit Schloss',
    (t) async {
      await pumpCardCheck(t, noCard: true);
      await _run(t);
      expect(_signLabel(t, CheckRow.reader), 'in Ordnung');
      expect(_signLabel(t, CheckRow.access), 'in Ordnung');
      expect(_signLabel(t, CheckRow.card), 'Fehler');
      expect(
        find.descendant(
          of: _sign(CheckRow.card),
          matching: find.byIcon(LucideIcons.x),
        ),
        findsOneWidget,
      );
      expect(find.text('Keine Karte im Leser.'), findsOneWidget);
      expect(
        find.text(
          'Steck die Karte mit dem Chip voran bis zum Anschlag hinein.',
        ),
        findsOneWidget,
      );
      for (final row in [CheckRow.certificate, CheckRow.signature]) {
        expect(_signLabel(t, row), 'gesperrt');
        expect(
          find.descendant(
            of: _sign(row),
            matching: find.byIcon(LucideIcons.lock),
          ),
          findsOneWidget,
        );
      }
      expect(
        find.text('Erst wenn die Zeile darüber grün ist.'),
        findsNWidgets(2),
      );
      expect(_key('card-check-pin'), findsNothing);
      expect(_key('card-check-share'), findsOneWidget);
    },
  );

  testWidgets('Zurück (Taste und Geste) führt zu den Einstellungen', (t) async {
    await pumpCardCheck(t);
    await t.tap(_key('card-check-back'));
    await t.pumpAndSettle();
    expect(_key('card-check'), findsNothing);
    expect(_key('area-settings'), findsOneWidget);
    expect(_key('open-card-check'), findsOneWidget);

    await t.ensureVisible(_key('open-card-check'));
    await t.pumpAndSettle();
    await t.tap(_key('open-card-check'));
    await t.pumpAndSettle();
    expect(_key('card-check'), findsOneWidget);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(_key('card-check'), findsNothing);
    expect(_key('area-settings'), findsOneWidget);

    // Mit offenem PIN-Fenster schließt die Geste nur das Fenster.
    await t.ensureVisible(_key('open-card-check'));
    await t.pumpAndSettle();
    await t.tap(_key('open-card-check'));
    await t.pumpAndSettle();
    await _run(t);
    await _openPin(t);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(_key('card-pin-sheet'), findsNothing);
    expect(_key('card-check'), findsOneWidget);
    expect(cardReaderOf(t).card!.verifyCount, 0);
  });

  testWidgets(
    'verlassen während des Laufs: der Lauf endet, gibt den Leser frei, Zurückkommen zeigt den Stand',
    (t) async {
      late _GatedReader gated;
      await pumpCardCheck(t, wrap: (r) => gated = _GatedReader(r));
      await t.tap(_key('card-check-run'));
      await t.pump();
      expect(_check(t).state.busy, isTrue);
      await t.tap(_key('card-check-back'));
      await t.pumpAndSettle();
      expect(_key('card-check'), findsNothing);
      expect(_check(t).state.busy, isTrue);
      // Der Lauf geht ohne Bildschirm weiter und gibt den Leser frei.
      gated.release();
      await t.pumpAndSettle();
      expect(_check(t).state.busy, isFalse);
      expect(gated.inner.closed, 1);
      expect(t.takeException(), isNull);
      await t.ensureVisible(_key('open-card-check'));
      await t.pumpAndSettle();
      await t.tap(_key('open-card-check'));
      await t.pumpAndSettle();
      expect(_signLabel(t, CheckRow.certificate), 'in Ordnung');
      expect(find.text('Nochmal prüfen'), findsOneWidget);
    },
  );

  testWidgets('Tippflächen: alle Tasten mindestens 48 dp', (t) async {
    await pumpCardCheck(t, guard: MemoryPinGuard({_cardNumber: 1}));
    await _run(t);
    expect(t.getSize(_key('card-check-run')).height, 76);
    expect(t.getSize(_key('card-check-share')).height, 64);
    void check(Finder within) {
      final taps = find.descendant(
        of: within,
        matching: find.byType(Pressable),
      );
      expect(taps, findsWidgets);
      for (final e in taps.evaluate()) {
        final size = t.getSize(find.byWidget(e.widget));
        expect(size.height, greaterThanOrEqualTo(48), reason: '${e.widget}');
        expect(size.width, greaterThanOrEqualTo(48), reason: '${e.widget}');
      }
    }

    check(_key('card-check'));
    // Die Rückfrage im Zustand mit dem längsten Text (nur noch ein Versuch).
    await t.ensureVisible(_key('card-check-reset-guard'));
    await t.pumpAndSettle();
    await t.tap(_key('card-check-reset-guard'));
    await t.pumpAndSettle();
    check(_key('card-check'));
    expect(t.takeException(), isNull);

    await t.tap(find.text('Ja, Zähler ist wieder voll'));
    await t.pumpAndSettle();
    await _openPin(t);
    check(_key('card-pin-sheet'));
    expect(t.getSize(_key('card-pin-submit')).height, greaterThanOrEqualTo(64));
  });

  for (final scale in [1.0, 1.3]) {
    testWidgets(
      'der längste Text (nur noch ein Versuch) läuft bei 1280 × 800 nicht über (Textgröße $scale)',
      (t) async {
        await pumpCardCheck(t, textScale: scale);
        await _run(t);
        // Zweimal falsch: Zeile 5 zeigt den längsten Text der Tabelle.
        for (var i = 0; i < 2; i++) {
          await _openPin(t);
          await typePin(t, '654321');
          await t.tap(_key('card-pin-submit'));
          await t.pumpAndSettle();
        }
        expect(find.text(_lastTry), findsOneWidget);
        expect(find.text(_lastTryHint), findsOneWidget);
        expect(t.takeException(), isNull);
        await t.ensureVisible(_key('card-check-reset-guard'));
        await t.pumpAndSettle();
        await t.tap(_key('card-check-reset-guard'));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await t.ensureVisible(_key('card-check-reset-confirm'));
        await t.pumpAndSettle();
        await t.tap(_key('card-check-reset-confirm'));
        await t.pumpAndSettle();
        await _openPin(t);
        expect(t.takeException(), isNull);
      },
    );
  }
}
