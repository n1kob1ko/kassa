import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kassa/app.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/domain/staff.dart';

import '../support/pump.dart';

const _badFile =
    '{"betrieb":"X","kategorien":[],"artikel":[{"id":"x"}],"auswahlgruppen":{}}';

/// Gültige Datei mit einer Mitarbeiterin (PIN 1234).
const _goodFile = '''
{"betrieb":"Test-Bude",
 "kategorien":[{"id":"k","name":"Essen"}],
 "artikel":[{"id":"a","name":"Brot","kategorie":"k","preis_cent":250,"mwst":10},
            {"id":"b","name":"Kuchen","kategorie":"k","preis_cent":300,"mwst":10}],
 "mitarbeiter":[{"name":"Anna","pin":"1234","rolle":"mitarbeiter"}]}
''';

ProviderContainer _container(WidgetTester t) =>
    ProviderScope.containerOf(t.element(find.byType(KassaApp)));

Future<void> _start(WidgetTester t, {String? file}) async {
  await pumpApp(
    t,
    const KassaApp(),
    overrides: await memoryOverrides(seeded: false, pickedFile: file),
  );
  await t.pumpAndSettle();
}

void main() {
  testWidgets('Einrichtung mit Beispieldaten: Chef-PIN zweimal, dann Kassa', (
    t,
  ) async {
    await _start(t);
    expect(find.text('Diese Kassa einrichten'), findsOneWidget);
    await t.tap(find.text('Mit Beispieldaten starten'));
    await t.pumpAndSettle();
    expect(find.text('Chef-PIN festlegen'), findsOneWidget);
    await typePin(t, '4711');
    expect(find.text('PIN wiederholen'), findsOneWidget);
    await typePin(t, '4711');
    await t.pumpAndSettle();
    expect(find.byKey(const Key('tab-Kassa')), findsOneWidget);
    expect(find.text('Chef'), findsOneWidget);
    expect(find.text('Beispiel-Imbiss'), findsOneWidget);
  });

  testWidgets('unterschiedliche PINs: Hinweis und noch einmal', (t) async {
    await _start(t);
    await t.tap(find.text('Mit Beispieldaten starten'));
    await t.pumpAndSettle();
    await typePin(t, '4711');
    await typePin(t, '4712');
    await t.pumpAndSettle();
    expect(find.text('Die PINs sind nicht gleich. Bitte noch einmal.'),
        findsOneWidget);
    expect(find.text('Chef-PIN festlegen'), findsOneWidget);
    expect(find.byKey(const Key('tab-Kassa')), findsNothing);
  });

  testWidgets('fehlerhafte Datei zeigt alle Fehler und spielt nichts ein', (
    t,
  ) async {
    await _start(t, file: _badFile);
    await t.tap(find.text('Speisekarte einspielen'));
    await t.pumpAndSettle();
    expect(find.text('Die Datei passt noch nicht'), findsOneWidget);
    expect(find.text('Es wurde nichts eingespielt. Das muss in der Datei '
        'geändert werden:'), findsOneWidget);
    expect(find.text('Artikel "x": Name fehlt.'), findsOneWidget);
    expect(find.text('Andere Datei wählen'), findsOneWidget);
    expect(await _container(t).read(catalogRepositoryProvider).current(),
        isNull);
    await t.tap(find.text('Andere Datei wählen'));
    await t.pumpAndSettle();
    expect(find.text('Diese Kassa einrichten'), findsOneWidget);
  });

  testWidgets('gute Datei: Zusammenfassung, dann Chef-PIN', (t) async {
    await _start(t, file: _goodFile);
    await t.tap(find.text('Speisekarte einspielen'));
    await t.pumpAndSettle();
    expect(find.text('Speisekarte gelesen'), findsOneWidget);
    expect(find.text('Bitte kurz prüfen, ob das stimmt.'), findsOneWidget);
    expect(textOf(t, const Key('summary-Betrieb')), 'Test-Bude');
    expect(textOf(t, const Key('summary-Kategorien')), '1');
    expect(textOf(t, const Key('summary-Artikel')), '2');
    expect(textOf(t, const Key('summary-Mitarbeiter')), '1');
    expect(find.text('Andere Datei'), findsOneWidget);
    await t.tap(find.text('Weiter zur Chef-PIN'));
    await t.pumpAndSettle();
    expect(find.text('Chef-PIN festlegen'), findsOneWidget);
  });

  testWidgets('Abbruch der Dateiauswahl bleibt auf dem Startbild', (t) async {
    await _start(t, file: null);
    await t.tap(find.text('Speisekarte einspielen'));
    await t.pumpAndSettle();
    expect(find.text('Diese Kassa einrichten'), findsOneWidget);
    expect(find.text('Speisekarte gelesen'), findsNothing);
    expect(find.text('Die Datei passt noch nicht'), findsNothing);
  });

  testWidgets('geschrieben wird erst nach bestätigter PIN, dann genau ein Chef',
      (t) async {
    await _start(t, file: _goodFile);
    final c = _container(t);
    await t.tap(find.text('Speisekarte einspielen'));
    await t.pumpAndSettle();
    await t.tap(find.text('Weiter zur Chef-PIN'));
    await t.pumpAndSettle();
    await typePin(t, '4711');
    await typePin(t, '4712'); // nicht gleich: noch nichts geschrieben
    await t.pumpAndSettle();
    expect(await c.read(catalogRepositoryProvider).current(), isNull);
    expect(await c.read(staffRepositoryProvider).all(), isEmpty);
    await typePin(t, '4711');
    await typePin(t, '4711');
    await t.pumpAndSettle();
    final catalog = await c.read(catalogRepositoryProvider).current();
    expect(catalog!.businessName, 'Test-Bude');
    final staff = await c.read(staffRepositoryProvider).all();
    expect(staff.where((s) => s.role == StaffRole.chef), hasLength(1));
    expect(staff.singleWhere((s) => s.isChef).name, 'Chef');
    expect(staff.map((s) => s.name), containsAll(['Chef', 'Anna']));
    expect(staff, hasLength(2));
  });

  testWidgets('Chef-PIN gleich der PIN aus der Datei wird abgelehnt', (t) async {
    await _start(t, file: _goodFile);
    await t.tap(find.text('Speisekarte einspielen'));
    await t.pumpAndSettle();
    await t.tap(find.text('Weiter zur Chef-PIN'));
    await t.pumpAndSettle();
    await typePin(t, '1234');
    await t.pumpAndSettle();
    expect(
      find.text('Diese PIN hat schon jemand aus der Datei. '
          'Bitte eine andere wählen.'),
      findsOneWidget,
    );
    expect(find.text('Chef-PIN festlegen'), findsOneWidget);
    expect(await _container(t).read(catalogRepositoryProvider).current(),
        isNull);
  });

  testWidgets('Datei mit Mitarbeitern: deren PIN meldet sie an, ohne Abschluss',
      (t) async {
    await _start(t, file: _goodFile);
    await t.tap(find.text('Speisekarte einspielen'));
    await t.pumpAndSettle();
    await t.tap(find.text('Weiter zur Chef-PIN'));
    await t.pumpAndSettle();
    await typePin(t, '4711');
    await typePin(t, '4711');
    await t.pumpAndSettle();
    expect(find.byKey(const Key('tab-Abschluss')), findsOneWidget);
    await t.tap(find.byKey(const Key('staff')));
    await t.pumpAndSettle();
    await typePin(t, '1234');
    await t.pumpAndSettle();
    expect(find.text('Anna'), findsOneWidget);
    expect(find.byKey(const Key('tab-Kassa')), findsOneWidget);
    expect(find.byKey(const Key('tab-Abschluss')), findsNothing);
  });
}
