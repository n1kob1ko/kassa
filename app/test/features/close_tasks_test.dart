import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/features/settings/rksv_task_row.dart';
import 'package:kassa/rksv/rksv_state.dart';
import 'package:material_ui/material_ui.dart';

import '../support/close_pump.dart';
import '../support/kassa_pump.dart';
import '../support/pump.dart';
import '../support/signature_pump.dart';

Finder _key(String key) => find.byKey(Key(key));

Future<void> _tap(WidgetTester t, String key) async {
  await t.ensureVisible(_key(key));
  await t.pumpAndSettle();
  await t.tap(_key(key));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('ohne Signatur: keine Aufgaben im Abschluss', (t) async {
    await pumpClose(t, floatCents: 15000, extra: signatureOverrides());
    expect(find.byType(RksvTaskBlock), findsNothing);
    expect(find.text('Zu erledigen'), findsNothing);
  });

  testWidgets('offene Aufgaben unter den Summen, "Erledigt" für den Chef; '
      'der Tag lässt sich trotzdem abschließen', (t) async {
    await pumpClose(t, floatCents: 15000, extra: signatureOverrides());
    await seedProbe(t, tasks: twoTasks);

    expect(_key('rksv-tasks'), findsOneWidget);
    expect(find.text('Zu erledigen'), findsOneWidget);
    expect(find.text('Aufgaben aus der Probe sind zum Üben.'), findsOneWidget);
    expect(
      find.text('Startbeleg mit der App "BMF Belegcheck" prüfen.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Protokoll sichern: "Protokoll ausgeben" und die Datei '
        'aufheben.',
      ),
      findsOneWidget,
    );
    // Unter den Karten mit den Summen, in der linken Spalte.
    expect(
      t.getTopLeft(_key('rksv-tasks')).dy,
      greaterThan(t.getTopLeft(find.text('Geldlade')).dy),
    );
    expect(t.getSize(_key('rksv-task-done-check-start-1')).height, 56);

    await _tap(t, 'rksv-task-done-check-start-1');
    expect(_key('rksv-task-check-start-1'), findsNothing);
    expect(_key('rksv-task-backup-2026-Q4'), findsOneWidget);
    final state = await containerOf(t).read(rksvRepositoryProvider).current();
    expect([for (final task in state.tasks) task.id], ['backup-2026-Q4']);

    // Die Aufgabe sperrt den Abschluss nicht.
    await tapKeys(t, '1 6 8 , 2 0');
    await _tap(t, 'count-next');
    await tapKeys(t, '1 5 0');
    await _tap(t, 'close-day');
    expect(find.text('Tag abgeschlossen'), findsOneWidget);
    expect(_key('rksv-task-backup-2026-Q4'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  for (final decommissioned in [false, true]) {
    testWidgets('Aufgaben des echten Betriebs '
        '(${decommissioned ? 'außer Betrieb' : 'in Betrieb'}): ohne den Satz '
        'zum Üben, "Erledigt" nimmt sie weg', (t) async {
      final tasks = decommissioned ? decommissionTasks : liveTasks;
      await pumpClose(t, floatCents: 15000, extra: signatureOverrides());
      await seedLive(t, tasks: tasks, decommissioned: decommissioned);
      expect(_key('rksv-tasks'), findsOneWidget);
      expect(find.text('Aufgaben aus der Probe sind zum Üben.'), findsNothing);
      for (final task in tasks) {
        expect(find.text(rksvTaskText(task)), findsOneWidget);
      }
      final first = tasks.first.id;
      await _tap(t, 'rksv-task-done-$first');
      expect(_key('rksv-task-$first'), findsNothing);
      final state = await containerOf(t).read(rksvRepositoryProvider).current();
      expect([for (final task in state.tasks) task.id], [tasks.last.id]);
    });
  }
}
