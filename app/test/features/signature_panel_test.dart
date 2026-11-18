import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/features/login/session.dart';
import 'package:kassa/features/settings/signature_panel.dart';
import 'package:kassa/rksv/rksv_providers.dart';
import 'package:kassa/rksv/rksv_secrets.dart';
import 'package:kassa/rksv/rksv_state.dart';
import 'package:kassa/ui/tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../support/cash_pump.dart' show queryRows, setUpPrinter;
import '../support/kassa_pump.dart' show containerOf;
import '../support/pump.dart';
import '../support/settings_pump.dart';
import '../support/signature_pump.dart';

Finder _key(String key) => find.byKey(Key(key));

Finder _inCard(Finder f) =>
    find.descendant(of: _key('signature-card'), matching: f);

Future<void> _tap(WidgetTester t, String key) async {
  await t.ensureVisible(_key(key));
  await t.pumpAndSettle();
  await t.tap(_key(key));
  await t.pumpAndSettle();
}

Future<RecordingProtocolSaver> _settings(
  WidgetTester t, {
  MemoryRksvSecrets? secrets,
  RecordingProtocolSaver? saver,
  bool printer = false,
}) async {
  final s = saver ?? RecordingProtocolSaver();
  await pumpSettings(
    t,
    extra: signatureOverrides(secrets: secrets, saver: s),
  );
  if (printer) await setUpPrinter(t);
  return s;
}

/// Schaltet die Probe-Signatur über den Dienst ein (echte Probe-Signatur).
Future<void> _startProbe(WidgetTester t) async {
  final c = containerOf(t);
  await c
      .read(rksvServiceProvider)
      .enableProbe(staff: c.read(sessionProvider)!);
  await t.pumpAndSettle();
}

Future<List<String>> _kinds(WidgetTester t) async => [
  for (final r in await queryRows(
    t,
    "SELECT kind FROM receipts WHERE kind != 'sale' ORDER BY number",
  ))
    r['kind']! as String,
];

Future<String> _idOf(WidgetTester t, String kind) async =>
    (await queryRows(
          t,
          "SELECT id FROM receipts WHERE kind = '$kind'",
        )).single['id']!
        as String;

Future<RksvState> _state(WidgetTester t) =>
    containerOf(t).read(rksvRepositoryProvider).current();

/// Schreibt nur den Modus in den Stand, ohne Kette.
Future<void> _setMode(WidgetTester t, RksvMode mode) async {
  final db = containerOf(t).read(databaseProvider);
  await (db.update(db.rksvStateRows)..where((r) => r.id.equals(1))).write(
    RksvStateRowsCompanion(mode: Value(mode.name)),
  );
  await t.pumpAndSettle();
}

class _BrokenSaver extends RecordingProtocolSaver {
  @override
  Future<bool> save(String fileName, Uint8List bytes) async =>
      throw StateError('kaputt mit geheimem Text');
}

void main() {
  testWidgets('aus: "Nicht eingerichtet" und "Zum Ausprobieren einschalten"', (
    t,
  ) async {
    await _settings(t);
    expect(_inCard(find.text('Signatur der Bons')), findsOneWidget);
    expect(_inCard(find.text('Nicht eingerichtet')), findsOneWidget);
    expect(
      _inCard(
        find.text('Für die Registrierkassen-Pflicht. Noch nicht eingerichtet.'),
      ),
      findsOneWidget,
    );
    expect(_inCard(find.text('Zum Ausprobieren einschalten')), findsOneWidget);
    expect(
      _inCard(
        find.text(
          'Bons bekommen einen QR-Code und kommen ins Protokoll, wie später '
          'im echten Betrieb. Sie bleiben Testbons.',
        ),
      ),
      findsOneWidget,
    );
    expect(_key('rksv-probe-on'), findsOneWidget);
    expect(t.getSize(_key('rksv-probe-on')).height, 56);
    for (final k in ['rksv-zero', 'rksv-export', 'rksv-probe-off']) {
      expect(_key(k), findsNothing, reason: k);
    }
    expect(find.text('Zu erledigen'), findsNothing);
    expect(_key('open-card-check'), findsOneWidget);
  });

  testWidgets('Probe mit zwei Aufgaben: Pille, Kassen-ID, Aufgaben, Tasten', (
    t,
  ) async {
    await _settings(t);
    await seedProbe(t, tasks: twoTasks);
    expect(_inCard(find.text('Probe')), findsOneWidget);
    expect(
      _inCard(
        find.text(
          'Probe-Signatur, nicht für den echten Betrieb. Kassen-ID K7QM2XB4HN.',
        ),
      ),
      findsOneWidget,
    );
    expect(_inCard(find.text('Zu erledigen')), findsOneWidget);
    expect(
      _inCard(find.text('Aufgaben aus der Probe sind zum Üben.')),
      findsOneWidget,
    );
    for (final task in twoTasks) {
      expect(_inCard(find.text(rksvTaskText(task))), findsOneWidget);
      expect(t.getSize(_key('rksv-task-done-${task.id}')).height, 56);
    }
    expect(_inCard(find.text('Nullbeleg drucken')), findsOneWidget);
    expect(
      _inCard(
        find.text('Ein Beleg über 0 Euro, zum Beispiel für eine Kontrolle.'),
      ),
      findsOneWidget,
    );
    expect(_inCard(find.text('Protokoll ausgeben')), findsOneWidget);
    expect(
      _inCard(
        find.text(
          'Speichert die signierten Bons als Datei, zum Beispiel auf einen '
          'USB-Stick.',
        ),
      ),
      findsOneWidget,
    );
    expect(_inCard(find.text('Probe beenden')), findsOneWidget);
    expect(
      _inCard(
        find.text(
          'Die Kassa erstellt einen Schlussbeleg. Neue Bons haben dann keinen '
          'QR-Code mehr.',
        ),
      ),
      findsOneWidget,
    );
    for (final k in ['rksv-zero', 'rksv-export', 'rksv-probe-off']) {
      expect(t.getSize(_key(k)).height, 56, reason: k);
    }
    expect(_key('rksv-probe-on'), findsNothing);
    expect(_inCard(find.text('Zum Ausprobieren einschalten')), findsNothing);
    expect(_key('open-card-check'), findsOneWidget);
  });

  testWidgets(
    'Ausfall: Pille "Probe, Signatur ausgefallen" in der Warnfläche',
    (t) async {
      await _settings(t);
      await seedProbe(t, outageSince: DateTime(2026, 11, 17, 10, 30));
      final pill = _inCard(find.text('Probe, Signatur ausgefallen'));
      expect(pill, findsOneWidget);
      expect(t.widget<Text>(pill).style!.color, KassaColors.light.warnInk);
      expect(_inCard(find.text('Probe')), findsNothing);
      expect(_key('rksv-zero'), findsOneWidget);
    },
  );

  testWidgets('Mitarbeiter ohne Chef-Rolle sieht keine der Tasten', (t) async {
    await pumpApp(
      t,
      SingleChildScrollView(child: SignaturePanel(onOpenCardCheck: () {})),
      overrides: [...await memoryOverrides(), ...signatureOverrides()],
    );
    final c = ProviderScope.containerOf(t.element(find.byType(SignaturePanel)));
    await c.read(sessionProvider.notifier).login('1234');
    await seedProbe(
      t,
      container: c,
      tasks: twoTasks,
      notice: 'Die Probe-Signatur wurde beendet.',
    );
    expect(find.text('Probe'), findsOneWidget);
    expect(find.text(rksvTaskText(twoTasks.first)), findsOneWidget);
    expect(find.text('Die Probe-Signatur wurde beendet.'), findsOneWidget);
    for (final k in [
      'rksv-probe-on',
      'rksv-zero',
      'rksv-export',
      'rksv-probe-off',
      'rksv-notice-ok',
      'rksv-task-done-check-start-1',
      'rksv-task-done-backup-2026-Q4',
    ]) {
      expect(_key(k), findsNothing, reason: k);
    }
    expect(find.text('Erledigt'), findsNothing);
  });

  testWidgets('Einschalten mit Rückfrage: genau ein Startbeleg, gedruckt, '
      'auch bei doppeltem Antippen', (t) async {
    await _settings(t, printer: true);
    await t.ensureVisible(_key('rksv-probe-on'));
    await t.pumpAndSettle();
    await t.tap(_key('rksv-probe-on'));
    await t.tap(_key('rksv-probe-on'), warnIfMissed: false);
    await t.pumpAndSettle();
    expect(find.text('Probe-Signatur einschalten?'), findsOneWidget);
    expect(
      find.text(
        'Jeder Bon bekommt dann einen QR-Code und wird ins Protokoll '
        'geschrieben, so wie später im echten Betrieb. Die Bons bleiben '
        'Testbons. Ältere Bons kannst du danach nicht mehr stornieren.',
      ),
      findsOneWidget,
    );
    expect(t.getSize(_key('rksv-question-confirm')).height, 64);
    expect(t.getSize(_key('rksv-question-cancel')).height, 64);
    expect(
      find.descendant(
        of: _key('rksv-question-confirm'),
        matching: find.text('Einschalten'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _key('rksv-question-cancel'),
        matching: find.text('Abbrechen'),
      ),
      findsOneWidget,
    );
    await t.tap(_key('rksv-question-confirm'));
    await t.tap(_key('rksv-question-confirm'), warnIfMissed: false);
    await t.pumpAndSettle();
    expect(find.text('Probe-Signatur einschalten?'), findsNothing);
    expect(await _kinds(t), ['start']);
    expect((await _state(t)).mode, RksvMode.probe);
    expect(_inCard(find.text('Probe')), findsOneWidget);
    expect(printerOf(t).printed, [await _idOf(t, 'start')]);
    // Noch einmal antippen geht nicht mehr: die Taste ist weg.
    expect(_key('rksv-probe-on'), findsNothing);
  });

  testWidgets('Einschalten ohne Drucker: kein Druck, kein Fehler', (t) async {
    await _settings(t);
    await _tap(t, 'rksv-probe-on');
    await _tap(t, 'rksv-question-confirm');
    expect(await _kinds(t), ['start']);
    expect(printerOf(t).printed, isEmpty);
    expect(_key('rksv-message'), findsNothing);
  });

  testWidgets('Abbrechen ändert nichts', (t) async {
    await _settings(t, printer: true);
    await _tap(t, 'rksv-probe-on');
    await _tap(t, 'rksv-question-cancel');
    expect(find.text('Probe-Signatur einschalten?'), findsNothing);
    expect(await _kinds(t), isEmpty);
    expect((await _state(t)).mode, RksvMode.off);
    expect(printerOf(t).printed, isEmpty);
    expect(_key('rksv-probe-on'), findsOneWidget);
  });

  testWidgets('RksvProblem beim Einschalten zeigt den Satz', (t) async {
    await _settings(t, secrets: MemoryRksvSecrets()..failReads = true);
    await _tap(t, 'rksv-probe-on');
    await _tap(t, 'rksv-question-confirm');
    expect(
      _inCard(
        find.text('Das Tablet konnte den Schlüssel nicht sicher speichern.'),
      ),
      findsOneWidget,
    );
    expect((await _state(t)).mode, RksvMode.off);
    expect(await _kinds(t), isEmpty);
    expect(_key('rksv-probe-on'), findsOneWidget);
  });

  testWidgets('Nullbeleg: ein Beleg über 0 Euro, gedruckt', (t) async {
    await _settings(t, printer: true);
    await _startProbe(t);
    await _tap(t, 'rksv-zero');
    expect(await _kinds(t), ['start', 'zero']);
    expect(printerOf(t).printed, [await _idOf(t, 'zero')]);
  });

  testWidgets('Probe beenden mit Rückfrage: Schlussbeleg gedruckt, '
      '"Protokoll ausgeben" bleibt', (t) async {
    await _settings(t, printer: true);
    await _startProbe(t);
    await _tap(t, 'rksv-probe-off');
    expect(find.text('Probe-Signatur beenden?'), findsOneWidget);
    expect(
      find.text(
        'Die Kassa erstellt einen Schlussbeleg. Danach haben neue Bons keinen '
        'QR-Code mehr.',
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _key('rksv-question-confirm'),
        matching: find.text('Beenden'),
      ),
      findsOneWidget,
    );
    await _tap(t, 'rksv-question-confirm');
    expect(await _kinds(t), ['start', 'closing']);
    expect((await _state(t)).mode, RksvMode.off);
    expect(printerOf(t).printed, [await _idOf(t, 'closing')]);
    expect(_inCard(find.text('Nicht eingerichtet')), findsOneWidget);
    expect(_key('rksv-probe-on'), findsOneWidget);
    expect(_key('rksv-export'), findsOneWidget);
    expect(_key('rksv-zero'), findsNothing);
  });

  testWidgets('Probe beenden, Abbrechen ändert nichts', (t) async {
    await _settings(t);
    await _startProbe(t);
    await _tap(t, 'rksv-probe-off');
    await _tap(t, 'rksv-question-cancel');
    expect(await _kinds(t), ['start']);
    expect((await _state(t)).mode, RksvMode.probe);
  });

  testWidgets('Protokoll ausgeben: Blatt mit drei Zeiträumen und den drei '
      'Ausgängen', (t) async {
    final saver = await _settings(t);
    await _startProbe(t);
    await _tap(t, 'rksv-export');
    expect(find.text('Protokoll ausgeben'), findsNWidgets(2));
    expect(
      find.text(
        'Wähle den Zeitraum. Danach fragt Android, wohin die Datei soll.',
      ),
      findsOneWidget,
    );
    expect(find.text('Alles'), findsOneWidget);
    expect(find.text('Vom Startbeleg bis heute.'), findsOneWidget);
    expect(find.text('Dieses Vierteljahr'), findsOneWidget);
    expect(find.text('Seit 1. Oktober 2026.'), findsOneWidget);
    expect(find.text('Letztes Vierteljahr'), findsOneWidget);
    expect(find.text('1. Juli bis 30. September 2026.'), findsOneWidget);
    for (final k in [
      'rksv-export-all',
      'rksv-export-this-quarter',
      'rksv-export-last-quarter',
    ]) {
      expect(t.getSize(_key(k)).height, greaterThanOrEqualTo(76), reason: k);
    }
    expect(t.getSize(_key('rksv-export-cancel')).height, 64);

    // Gespeichert.
    await _tap(t, 'rksv-export-all');
    expect(
      find.text(
        'Wähle den Zeitraum. Danach fragt Android, wohin die '
        'Datei soll.',
      ),
      findsNothing,
    );
    expect(saver.saved, hasLength(1));
    expect(_inCard(find.text('Gespeichert.')), findsOneWidget);

    // Abgebrochen im Fenster von Android.
    saver.accept = false;
    await _tap(t, 'rksv-export');
    await _tap(t, 'rksv-export-this-quarter');
    expect(saver.saved, hasLength(1));
    expect(_inCard(find.text('Nicht gespeichert.')), findsOneWidget);
    expect(_inCard(find.text('Gespeichert.')), findsNothing);

    // Kein Eintrag im letzten Vierteljahr.
    saver.accept = true;
    await _tap(t, 'rksv-export');
    await _tap(t, 'rksv-export-last-quarter');
    expect(saver.saved, hasLength(1));
    expect(
      _inCard(find.text('In diesem Zeitraum gibt es keine Einträge.')),
      findsOneWidget,
    );

    // Abbrechen im Blatt: nichts.
    await _tap(t, 'rksv-export');
    await _tap(t, 'rksv-export-cancel');
    expect(saver.saved, hasLength(1));
    expect(find.text('Vom Startbeleg bis heute.'), findsNothing);
  });

  testWidgets('Protokoll ausgeben: Fehler beim Speichern zeigt einen eigenen '
      'Satz, nie den Text der Ausnahme', (t) async {
    await _settings(t, saver: _BrokenSaver());
    await _startProbe(t);
    await _tap(t, 'rksv-export');
    await _tap(t, 'rksv-export-all');
    expect(
      _inCard(find.text('Die Datei konnte nicht gespeichert werden.')),
      findsOneWidget,
    );
    expect(find.textContaining('geheim'), findsNothing);
  });

  testWidgets('Aufgabe erledigen: die Zeile geht weg, ohne Aufgabe der ganze '
      'Block', (t) async {
    await _settings(t);
    await seedProbe(t, tasks: twoTasks);
    await _tap(t, 'rksv-task-done-check-start-1');
    expect(find.text(rksvTaskText(twoTasks.first)), findsNothing);
    expect(find.text(rksvTaskText(twoTasks.last)), findsOneWidget);
    expect([for (final x in (await _state(t)).tasks) x.id], ['backup-2026-Q4']);
    await _tap(t, 'rksv-task-done-backup-2026-Q4');
    expect((await _state(t)).tasks, isEmpty);
    expect(find.text('Zu erledigen'), findsNothing);
    expect(find.text('Aufgaben aus der Probe sind zum Üben.'), findsNothing);
  });

  testWidgets('Hinweis mit "Verstanden"; beendete Kette: "Protokoll ausgeben" '
      'bleibt', (t) async {
    await _settings(t);
    const notice =
        'Die Probe-Signatur wurde beendet, weil etwas Unerwartetes passiert '
        'ist.';
    await seedProbe(t, ended: true, notice: notice);
    expect(_inCard(find.text(notice)), findsOneWidget);
    expect(_inCard(find.text('Nicht eingerichtet')), findsOneWidget);
    expect(_key('rksv-probe-on'), findsOneWidget);
    expect(_key('rksv-export'), findsOneWidget);
    expect(_key('rksv-zero'), findsNothing);
    expect(t.getSize(_key('rksv-notice-ok')).height, 56);
    await _tap(t, 'rksv-notice-ok');
    expect(find.text(notice), findsNothing);
    expect((await _state(t)).notice, isNull);
  });

  testWidgets('im Betrieb (live): keine Zeile "Zum Ausprobieren einschalten"', (
    t,
  ) async {
    await _settings(t);
    await _setMode(t, RksvMode.live);
    expect((await _state(t)).mode, RksvMode.live);
    expect(_inCard(find.text('In Betrieb')), findsOneWidget);
    expect(_key('rksv-probe-on'), findsNothing);
    expect(_inCard(find.text('Zum Ausprobieren einschalten')), findsNothing);
  });

  testWidgets('Probe ohne Kassen-ID: der Satz ohne "Kassen-ID"', (t) async {
    await _settings(t);
    await _setMode(t, RksvMode.probe);
    expect((await _state(t)).cashBoxId, isNull);
    expect(
      _inCard(find.text('Probe-Signatur, nicht für den echten Betrieb.')),
      findsOneWidget,
    );
    expect(_inCard(find.textContaining('Kassen-ID')), findsNothing);
  });
}
