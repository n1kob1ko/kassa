import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/core/app_info.dart';
import 'package:kassa/data/catalog_repository.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/data/settings_repository.dart';
import 'package:kassa/features/settings/settings_screen.dart';
import 'package:kassa/ui/app_toggle.dart';
import 'package:kassa/ui/tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../support/close_pump.dart';
import '../support/kassa_pump.dart';
import '../support/pump.dart';
import '../support/settings_pump.dart';

const _question =
    'Preise und Namen kommen neu aus der Datei. Favoriten und "Im Verkauf" bleiben.';
const _failText = 'Das hat nicht geklappt. Bitte nochmal versuchen.';
const _badFile =
    '{"betrieb":"X","kategorien":[],"artikel":[{"id":"x"}],"auswahlgruppen":{}}';

/// Speicher, dessen Schreiben immer scheitert.
class _FailingSettings extends SettingsRepository {
  _FailingSettings(super.db);

  @override
  Future<void> save(RegisterSettings s) => Future.error(StateError('voll'));
}

/// Speicher, der das Einspielen zählt.
class _CountingCatalog extends CatalogRepository {
  _CountingCatalog(super.db);

  int imports = 0;

  @override
  Future<void> importCatalog(catalog) async {
    imports++;
    await super.importCatalog(catalog);
  }
}

Brightness _brightness(WidgetTester t) =>
    Theme.of(t.element(find.byType(SettingsScreen))).brightness;

bool _toggleValue(WidgetTester t, String key) => t
    .widget<AppToggle>(
      find.descendant(
        of: find.byKey(Key(key)),
        matching: find.byType(AppToggle),
      ),
    )
    .value;

void main() {
  testWidgets('Geldlade aus wird gespeichert', (t) async {
    await pumpSettings(t);
    await t.tap(find.byKey(const Key('toggle-drawer')));
    await t.pump();
    expect((await settingsOf(t)).cashDrawerEnabled, isFalse);
  });

  testWidgets('Bilder und "Storno nur durch den Chef" werden gespeichert', (
    t,
  ) async {
    await pumpSettings(t);
    await t.tap(find.byKey(const Key('toggle-images')));
    await t.pump();
    await t.tap(find.byKey(const Key('toggle-void-chef')));
    await t.pump();
    final s = await settingsOf(t);
    expect(s.showImages, isTrue);
    expect(s.voidRequiresChef, isTrue);
    await t.pump();
    expect(_toggleValue(t, 'toggle-images'), isTrue);
    expect(_toggleValue(t, 'toggle-void-chef'), isTrue);
  });

  testWidgets('dunkle Ansicht schaltet das Thema um', (t) async {
    await pumpAppLoggedInAsChef(t);
    await openSettings(t);
    await t.tap(find.byKey(const Key('theme-dark')));
    await t.pumpAndSettle();
    expect(_brightness(t), Brightness.dark);
    expect((await settingsOf(t)).themeMode, AppThemeMode.dark);
  });

  testWidgets('"Hell" bleibt hell, "Wie das Tablet" folgt dem Tablet', (
    t,
  ) async {
    await pumpSettings(t, brightness: Brightness.dark);
    expect(_brightness(t), Brightness.dark);
    await t.tap(find.byKey(const Key('theme-light')));
    await t.pumpAndSettle();
    expect(_brightness(t), Brightness.light);
    await t.tap(find.byKey(const Key('theme-system')));
    await t.pumpAndSettle();
    expect(_brightness(t), Brightness.dark);
  });

  testWidgets('Speisekarte neu einspielen fragt nach und meldet das Ergebnis', (
    t,
  ) async {
    await pumpSettings(t, pickedFile: demoOhneTeigtaschen());
    await t.tap(find.byKey(const Key('reimport')));
    await t.pumpAndSettle();
    expect(find.text(_question), findsOneWidget);
    await t.tap(find.byKey(const Key('confirm-reimport')));
    await t.pumpAndSettle();
    expect(find.text('Speisekarte eingespielt: 13 Artikel.'), findsOneWidget);
    expect(find.text(_question), findsNothing);
    final catalog = await containerOf(t)
        .read(catalogRepositoryProvider)
        .current();
    expect(catalog!.items.length, 13);
    expect(catalog.items.any((i) => i.id == 'teigtaschen'), isFalse);
  });

  testWidgets('abgebrochene Dateiwahl ändert nichts', (t) async {
    await pumpSettings(t);
    await t.tap(find.byKey(const Key('reimport')));
    await t.pumpAndSettle();
    expect(find.text(_question), findsNothing);
    expect(find.byKey(const Key('confirm-reimport')), findsNothing);
    expect(find.byKey(const Key('reimport')), findsOneWidget);
  });

  testWidgets('wirft der Dateiwähler: Hinweis, der zweite Versuch klappt', (
    t,
  ) async {
    final picker = BrokenPicker(demoOhneTeigtaschen());
    await pumpSettings(t, picker: picker);
    await t.tap(find.byKey(const Key('reimport')));
    await t.pumpAndSettle();
    expect(
      find.text(
        'Die Datei konnte nicht geöffnet werden. Bitte nochmal versuchen.',
      ),
      findsOneWidget,
    );
    expect(t.takeException(), isNull);
    picker.broken = false;
    await t.tap(find.byKey(const Key('reimport')));
    await t.pumpAndSettle();
    expect(picker.calls, 2);
    expect(find.text(_question), findsOneWidget);
    expect(
      find.text(
        'Die Datei konnte nicht geöffnet werden. Bitte nochmal versuchen.',
      ),
      findsNothing,
    );
  });

  testWidgets('Datei, die kein JSON ist: ruhiger Satz statt Fehlertext', (
    t,
  ) async {
    await pumpSettings(t, pickedFile: '\uFFFD\uFFFD\u0000JFIF');
    await t.tap(find.byKey(const Key('reimport')));
    await t.pumpAndSettle();
    expect(find.text('Die Datei passt noch nicht'), findsOneWidget);
    expect(
      find.text('Die Datei ist keine gültige Speisekarten-Datei.'),
      findsOneWidget,
    );
    expect(find.textContaining('Exception'), findsNothing);
  });

  testWidgets('Datei mit Problemen zeigt sie und schreibt nichts', (t) async {
    final counting = <_CountingCatalog>[];
    await pumpSettings(
      t,
      pickedFile: _badFile,
      extra: [
        catalogRepositoryProvider.overrideWith((ref) {
          final r = _CountingCatalog(ref.watch(databaseProvider));
          counting.add(r);
          return r;
        }),
      ],
    );
    await t.tap(find.byKey(const Key('reimport')));
    await t.pumpAndSettle();
    expect(find.text('Die Datei passt noch nicht'), findsOneWidget);
    expect(find.text('Andere Datei wählen'), findsOneWidget);
    expect(find.byKey(const Key('confirm-reimport')), findsNothing);
    expect(find.byKey(const Key('reimport')), findsOneWidget);
    expect(counting.last.imports, 0);
  });

  testWidgets('"Abbrechen" schreibt nichts', (t) async {
    final counting = <_CountingCatalog>[];
    await pumpSettings(
      t,
      pickedFile: demoOhneTeigtaschen(),
      extra: [
        catalogRepositoryProvider.overrideWith((ref) {
          final r = _CountingCatalog(ref.watch(databaseProvider));
          counting.add(r);
          return r;
        }),
      ],
    );
    await t.tap(find.byKey(const Key('reimport')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('cancel-reimport')));
    await t.pumpAndSettle();
    expect(find.text(_question), findsNothing);
    expect(find.byKey(const Key('reimport')), findsOneWidget);
    expect(counting.last.imports, 0);
  });

  testWidgets('doppelter Tipp auf "Ja, einspielen" spielt einmal ein', (
    t,
  ) async {
    final counting = <_CountingCatalog>[];
    await pumpSettings(
      t,
      pickedFile: demoOhneTeigtaschen(),
      extra: [
        catalogRepositoryProvider.overrideWith((ref) {
          final r = _CountingCatalog(ref.watch(databaseProvider));
          counting.add(r);
          return r;
        }),
      ],
    );
    await t.tap(find.byKey(const Key('reimport')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('confirm-reimport')));
    await t.tap(find.byKey(const Key('confirm-reimport')), warnIfMissed: false);
    await t.pumpAndSettle();
    expect(counting.last.imports, 1);
    expect(find.text('Speisekarte eingespielt: 13 Artikel.'), findsOneWidget);
  });

  testWidgets('ein Artikel: "1 Artikel"', (t) async {
    const one =
        '{"betrieb":"X","kategorien":[{"id":"k","name":"E"}],"artikel":[{"id":"a","name":"B","kategorie":"k","preis_cent":250,"mwst":10}]}';
    await pumpSettings(t, pickedFile: one);
    await t.tap(find.byKey(const Key('reimport')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('confirm-reimport')));
    await t.pumpAndSettle();
    expect(find.text('Speisekarte eingespielt: 1 Artikel.'), findsOneWidget);
  });

  testWidgets('Schreibfehler: Hinweis und alter Wert bleibt', (t) async {
    await pumpSettings(
      t,
      extra: [
        settingsRepositoryProvider.overrideWith(
          (ref) => _FailingSettings(ref.watch(databaseProvider)),
        ),
      ],
    );
    await t.tap(find.byKey(const Key('toggle-drawer')));
    await t.pumpAndSettle();
    expect(find.text(_failText), findsOneWidget);
    expect(_toggleValue(t, 'toggle-drawer'), isTrue);
  });

  testWidgets(
    'Geräte, die es in dieser Version noch nicht gibt, sind als solche beschriftet',
    (t) async {
      await pumpSettings(t);
      expect(find.text('Bondrucker'), findsOneWidget);
      expect(find.text('Kartenterminal'), findsOneWidget);
      expect(find.text('Kommt mit einem späteren Update.'), findsNWidgets(2));
      expect(find.text('Noch nicht dabei'), findsNWidgets(2));
      expect(find.textContaining('Kundenanzeige'), findsNothing);
    },
  );

  testWidgets('Titel, Untertitel und Version', (t) async {
    await pumpSettings(t);
    expect(find.text('Einstellungen'), findsOneWidget);
    expect(find.text('Kassa 1 bei Beispiel-Imbiss'), findsOneWidget);
    expect(find.text('Kassa Version $appVersion'), findsOneWidget);
  });

  test('die Versionsnummer stimmt mit pubspec.yaml überein', () {
    final line = File('pubspec.yaml')
        .readAsLinesSync()
        .firstWhere((l) => l.startsWith('version:'));
    final number = line.substring('version:'.length).trim().split('+').first;
    expect(appVersion, number);
  });

  testWidgets(
    'der Knopf ist aktiv, solange die Einstellungen offen sind; ein Reiter und der Knopf führen zurück',
    (t) async {
      await pumpAppLoggedInAsChef(t);
      Color? bg(String key) =>
          (t
                      .widget<Container>(
                        find
                            .descendant(
                              of: find.byKey(Key(key)),
                              matching: find.byType(Container),
                            )
                            .first,
                      )
                      .decoration
                  as BoxDecoration?)
              ?.color;
      expect(find.byType(SettingsScreen), findsNothing);
      await openSettings(t);
      expect(find.byType(SettingsScreen), findsOneWidget);
      final soft = _colorsOf(t).accentSoft;
      expect(bg('settings'), soft);
      expect(bg('tab-Kassa'), isNot(soft));

      await t.tap(find.byKey(const Key('tab-Bons')));
      await t.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsNothing);
      expect(find.byKey(const Key('area-bons')), findsOneWidget);
      expect(bg('settings'), isNot(soft));

      await openSettings(t);
      await t.tap(find.byKey(const Key('settings')));
      await t.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsNothing);
      expect(find.byKey(const Key('area-bons')), findsOneWidget);
    },
  );

  testWidgets('Mitarbeiter haben keinen Einstellungen-Knopf', (t) async {
    await pumpKassa(t);
    expect(find.byKey(const Key('settings')), findsNothing);
  });

  testWidgets(
    'kein Überlauf bei 960 x 600 mit Textskala 1,3, auch mit offener Rückfrage',
    (t) async {
      await pumpSettings(
        t,
        size: const Size(960, 600),
        textScale: 1.3,
        pickedFile: demoOhneTeigtaschen(),
      );
      expect(t.takeException(), isNull);
      await t.ensureVisible(find.byKey(const Key('reimport')));
      await t.tap(find.byKey(const Key('reimport')));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.byKey(const Key('confirm-reimport')), findsOneWidget);
    },
  );

  testWidgets('alle Tippflächen sind mindestens 48 dp hoch', (t) async {
    await pumpSettings(t);
    for (final key in [
      'toggle-drawer',
      'toggle-images',
      'toggle-void-chef',
      'theme-system',
      'theme-light',
      'theme-dark',
      'reimport',
    ]) {
      final size = t.getSize(find.byKey(Key(key)));
      expect(size.height, greaterThanOrEqualTo(48), reason: key);
    }
  });

  testWidgets(
    'der Hinweis auf einen vergessenen Abschluss steht auch über den Einstellungen',
    (t) async {
      await pumpShellNextMorningWithOpenDay(t);
      await openSettings(t);
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.byKey(const Key('forgotten-close')), findsOneWidget);
      // Aus den Einstellungen führt die Taste in den Abschluss.
      await t.tap(find.byKey(const Key('forgotten-close-go')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('area-close')), findsOneWidget);
      expect(find.byType(SettingsScreen), findsNothing);
    },
  );
}

KassaColors _colorsOf(WidgetTester t) =>
    KassaColors.of(t.element(find.byType(SettingsScreen)));
