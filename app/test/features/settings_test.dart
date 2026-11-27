import 'dart:io';

import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/core/app_info.dart';
import 'package:kassa/core/app_language.dart';
import 'package:kassa/data/catalog_repository.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/data/settings_repository.dart';
import 'package:kassa/domain/feature_access.dart';
import 'package:kassa/features/settings/settings_screen.dart';
import 'package:kassa/l10n/generated/l10n.dart';
import 'package:kassa/ui/app_toggle.dart';
import 'package:kassa/ui/pressable.dart';
import 'package:kassa/ui/segmented.dart';
import 'package:kassa/ui/tokens.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../support/cash_pump.dart' show queryRows;
import '../support/close_pump.dart';
import '../support/kassa_pump.dart';
import '../support/pump.dart';
import '../support/server_pump.dart';
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
    await t.ensureVisible(find.byKey(const Key('toggle-images')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('toggle-images')));
    await t.pump();
    await t.ensureVisible(find.byKey(const Key('toggle-void-chef')));
    await t.pumpAndSettle();
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
    await t.ensureVisible(find.byKey(const Key('theme-dark')));
    await t.pumpAndSettle();
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
    await t.ensureVisible(find.byKey(const Key('theme-light')));
    await t.pumpAndSettle();
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
    await t.ensureVisible(find.byKey(const Key('reimport')));
    await t.pumpAndSettle();
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
    await t.ensureVisible(find.byKey(const Key('reimport')));
    await t.pumpAndSettle();
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
    await t.ensureVisible(find.byKey(const Key('reimport')));
    await t.pumpAndSettle();
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
    await t.ensureVisible(find.byKey(const Key('reimport')));
    await t.pumpAndSettle();
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
    await t.ensureVisible(find.byKey(const Key('reimport')));
    await t.pumpAndSettle();
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
    await t.ensureVisible(find.byKey(const Key('reimport')));
    await t.pumpAndSettle();
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
    await t.ensureVisible(find.byKey(const Key('reimport')));
    await t.pumpAndSettle();
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
    await t.ensureVisible(find.byKey(const Key('reimport')));
    await t.pumpAndSettle();
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
    await t.ensureVisible(find.byKey(const Key('reimport')));
    await t.pumpAndSettle();
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

  testWidgets('Zeilen der Geräte: Bondrucker und Kartenterminal, nichts '
      'Angekündigtes', (t) async {
    await pumpSettings(t);
    expect(find.text('Bondrucker'), findsOneWidget);
    expect(find.text('Kartenterminal'), findsOneWidget);
    expect(find.text('Kommt mit einem späteren Update.'), findsNothing);
    expect(find.text('Noch nicht dabei'), findsNothing);
    // Der Drucker und die Signatur der Bons.
    expect(find.text('Nicht eingerichtet'), findsNWidgets(2));
    expect(find.textContaining('Kundenanzeige'), findsNothing);
  });

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

  testWidgets('Rückfrage "Speisekarte neu einspielen" rollt ganz ins Bild', (
    t,
  ) async {
    await pumpSettings(t, pickedFile: demoOhneTeigtaschen());
    // Die Taste steht im Zustand "Nicht eingerichtet" unter dem Bildrand
    // (Zeile "Mit Karte ausprobieren"): erst hinrollen, gerade nur bis zum
    // Rand. Die Rückfrage muss dann von selbst ganz ins Bild rollen.
    await t.ensureVisible(find.byKey(const Key('reimport')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('reimport')));
    await t.pumpAndSettle();
    final visible = t.getRect(
      find
          .ancestor(
            of: find.byKey(const Key('confirm-reimport')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    for (final key in ['cancel-reimport', 'confirm-reimport']) {
      final button = t.getRect(find.byKey(Key(key)));
      expect(visible.top, lessThanOrEqualTo(button.top), reason: key);
      expect(button.bottom, lessThanOrEqualTo(visible.bottom), reason: key);
    }
    expect(t.takeException(), isNull);
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
      await t.pumpAndSettle();
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

  testWidgets(
    'Zahlen: Pfand zurück, Gutschein, Rechnung an Firma sind aus und lassen '
    'sich stellen',
    (t) async {
      await pumpSettings(t);
      await t.ensureVisible(find.byKey(const Key('payment-card')));
      await t.pumpAndSettle();
      // Nach den vier Reihen aus 1a, in dieser Reihenfolge.
      final rows = [
        'discount-access-off',
        'open-amount-access-off',
        'setting-deposit-return-off',
        'setting-voucher',
        'setting-invoice',
      ];
      for (var i = 1; i < rows.length; i++) {
        expect(
          t.getTopLeft(find.byKey(Key(rows[i]))).dy,
          greaterThan(t.getTopLeft(find.byKey(Key(rows[i - 1]))).dy),
          reason: rows[i],
        );
      }
      expect(
        find.descendant(
          of: find.byKey(const Key('payment-card')),
          matching: find.byKey(const Key('setting-deposit-return')),
        ),
        findsOneWidget,
      );
      expect(find.text('Pfand zurück'), findsOneWidget);
      expect(find.text('Gutschein'), findsOneWidget);
      expect(
        find.text('Wertgutscheine verkaufen und einlösen'),
        findsOneWidget,
      );
      expect(find.text('Rechnung an Firma'), findsOneWidget);
      expect(
        find.text('Bon mit Name und Adresse des Kunden drucken'),
        findsOneWidget,
      );
      expect(_segmentOf(t, 'setting-deposit-return'), FeatureAccess.off);
      expect(_toggleValue(t, 'setting-voucher'), isFalse);
      expect(_toggleValue(t, 'setting-invoice'), isFalse);
      final before = await settingsOf(t);
      expect(
        (
          before.depositReturnAccess,
          before.voucherEnabled,
          before.invoiceEnabled,
        ),
        (FeatureAccess.off, false, false),
      );

      await t.tap(find.byKey(const Key('setting-deposit-return-chefOnly')));
      await t.tap(find.byKey(const Key('setting-voucher')));
      await t.tap(find.byKey(const Key('setting-invoice')));
      await t.pumpAndSettle();
      expect(
        await queryRows(
          t,
          'SELECT deposit_return_access, voucher, invoice FROM settings',
        ),
        [
          {'deposit_return_access': 'chefOnly', 'voucher': 1, 'invoice': 1},
        ],
      );
      expect(_segmentOf(t, 'setting-deposit-return'), FeatureAccess.chefOnly);
      expect(_toggleValue(t, 'setting-voucher'), isTrue);
      expect(_toggleValue(t, 'setting-invoice'), isTrue);

      await t.tap(find.byKey(const Key('setting-deposit-return-all')));
      await t.tap(find.byKey(const Key('setting-invoice')));
      await t.pumpAndSettle();
      final s = await settingsOf(t);
      expect(
        (s.depositReturnAccess, s.voucherEnabled, s.invoiceEnabled),
        (FeatureAccess.all, true, false),
      );
      // Die Schalter aus 1a bleiben, wie sie waren.
      expect(
        (
          s.splitPaymentEnabled,
          s.cardTipEnabled,
          s.discountAccess,
          s.openAmountAccess,
        ),
        (false, false, FeatureAccess.off, FeatureAccess.off),
      );
    },
  );

  testWidgets('Kundenbon: ohne Kopplung sind die digitalen Werte grau, mit '
      'Kopplung lässt sich "Digital und Druck auf Wunsch" wählen', (t) async {
    // Ohne Server in dieser Version.
    await pumpSettings(t);
    await _showReceiptSection(t);
    expect(find.text('Kundenbon'), findsOneWidget);
    for (final (key, title, info) in [
      ('alwaysPrint', 'Immer drucken', 'Nach jedem Verkauf, wie bisher'),
      (
        'printAndDigital',
        'Drucken und digital',
        'Drucken und zusätzlich den QR-Code zeigen',
      ),
      (
        'digitalOnRequest',
        'Digital und Druck auf Wunsch',
        'QR-Code zeigen, drucken nur auf Tipp',
      ),
    ]) {
      final row = find.byKey(Key('receipt-mode-$key'));
      expect(
        find.descendant(
          of: find.byKey(const Key('receipt-section')),
          matching: row,
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.text(title)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.text(info)),
        findsOneWidget,
      );
    }
    _expectReceiptChoice(t, ReceiptMode.alwaysPrint, paired: false);
    expect(find.text(_needsServer), findsOneWidget);
    expect(find.text(_qrHint), findsNothing);
    // Ein Tipp auf einen grauen Wert ändert nichts.
    await t.tap(
      find.byKey(const Key('receipt-mode-digitalOnRequest')),
      warnIfMissed: false,
    );
    await t.tap(
      find.byKey(const Key('receipt-mode-printAndDigital')),
      warnIfMissed: false,
    );
    await t.pumpAndSettle();
    expect((await settingsOf(t)).receiptMode, ReceiptMode.alwaysPrint);
    _expectReceiptChoice(t, ReceiptMode.alwaysPrint, paired: false);

    // Mit Server, aber noch nicht gekoppelt: ebenso grau.
    await pumpUnpaired(t);
    await _showReceiptSection(t);
    _expectReceiptChoice(t, ReceiptMode.alwaysPrint, paired: false);
    expect(find.text(_needsServer), findsOneWidget);

    // Gekoppelt: alle drei wählbar, kein Hinweis auf den Server.
    await pumpPaired(t);
    await _showReceiptSection(t);
    _expectReceiptChoice(t, ReceiptMode.alwaysPrint, paired: true);
    expect(find.text(_needsServer), findsNothing);
    expect(find.text(_qrHint), findsNothing);
    await t.tap(find.byKey(const Key('receipt-mode-digitalOnRequest')));
    await t.pumpAndSettle();
    expect(await queryRows(t, 'SELECT receipt_mode FROM settings'), [
      {'receipt_mode': 'digitalOnRequest'},
    ]);
    _expectReceiptChoice(t, ReceiptMode.digitalOnRequest, paired: true);
    expect(find.text(_qrHint), findsOneWidget);
    await t.tap(find.byKey(const Key('receipt-mode-printAndDigital')));
    await t.pumpAndSettle();
    expect((await settingsOf(t)).receiptMode, ReceiptMode.printAndDigital);
    expect(find.text(_qrHint), findsOneWidget);
    await t.tap(find.byKey(const Key('receipt-mode-alwaysPrint')));
    await t.pumpAndSettle();
    expect((await settingsOf(t)).receiptMode, ReceiptMode.alwaysPrint);
    expect(find.text(_qrHint), findsNothing);
  });

  testWidgets('Kundenbon: ein gespeicherter digitaler Wert bleibt ohne '
      'Kopplung stehen, "Immer drucken" lässt sich wählen', (t) async {
    await pumpSettings(t);
    await setSettings(
      t,
      (s) => s.copyWith(receiptMode: ReceiptMode.printAndDigital),
    );
    await _showReceiptSection(t);
    expect((await settingsOf(t)).receiptMode, ReceiptMode.printAndDigital);
    _expectReceiptChoice(t, ReceiptMode.printAndDigital, paired: false);
    expect(find.text(_needsServer), findsOneWidget);
    expect(find.text(_qrHint), findsOneWidget);
    await t.tap(find.byKey(const Key('receipt-mode-alwaysPrint')));
    await t.pumpAndSettle();
    expect((await settingsOf(t)).receiptMode, ReceiptMode.alwaysPrint);
    // Zurück geht es ohne Kopplung nicht.
    await t.tap(
      find.byKey(const Key('receipt-mode-printAndDigital')),
      warnIfMissed: false,
    );
    await t.pumpAndSettle();
    expect((await settingsOf(t)).receiptMode, ReceiptMode.alwaysPrint);
  });

  testWidgets('Kundenbon steht direkt unter "Zahlen"', (t) async {
    await pumpSettings(t);
    await _showReceiptSection(t);
    final payments = t.getRect(find.byKey(const Key('payment-card')));
    final receipt = t.getRect(find.byKey(const Key('receipt-section')));
    expect(receipt.left, payments.left);
    expect(receipt.width, payments.width);
    expect(receipt.top, greaterThan(payments.bottom));
    expect(receipt.top - payments.bottom, KassaTokens.spaceXxl);
  });

  testWidgets('die neuen Tippflächen sind mindestens 48 dp hoch', (t) async {
    await pumpSettings(t);
    await _showReceiptSection(t);
    for (final key in [
      'setting-deposit-return-off',
      'setting-deposit-return-all',
      'setting-deposit-return-chefOnly',
      'setting-voucher',
      'setting-invoice',
      for (final m in ReceiptMode.values) 'receipt-mode-${m.name}',
    ]) {
      final size = t.getSize(find.byKey(Key(key)));
      expect(size.height, greaterThanOrEqualTo(48), reason: key);
      expect(size.width, greaterThanOrEqualTo(48), reason: key);
    }
  });

  for (final language in AppLanguage.values) {
    testWidgets('Zahlen und Kundenbon auf ${language.name}, 1024 x 600 mit '
        'Textskala 1,3: kein Überlauf, nichts gekürzt', (t) async {
      await pumpSettings(t, size: const Size(1024, 600), textScale: 1.3);
      // Ein digitaler Wert ohne Kopplung: beide Hinweise stehen da.
      await setSettings(
        t,
        (s) => s.copyWith(
          language: language,
          receiptMode: ReceiptMode.digitalOnRequest,
        ),
      );
      expect(
        Directionality.of(t.element(find.byType(SettingsScreen))),
        language.isRtl ? TextDirection.rtl : TextDirection.ltr,
      );
      final l = lookupL10n(language.locale);
      // In "Zahlen" die Texte der drei neuen Reihen und die Segmente der
      // drei Regler (auch die aus 1a: derselbe Umschalter).
      final newInPayments = {
        l.settingsDepositReturn,
        l.settingsVoucher,
        l.settingsVoucherInfo,
        l.settingsInvoice,
        l.settingsInvoiceInfo,
        l.settingsAccessOff,
        l.settingsAccessAll,
        l.settingsAccessChef,
      };
      for (final (card, mine) in [
        ('payment-card', newInPayments.contains),
        ('receipt-section', (String _) => true),
      ]) {
        await t.ensureVisible(find.byKey(Key(card)));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull, reason: card);
        final texts = find.descendant(
          of: find.byKey(Key(card)),
          matching: find.byType(RichText),
        );
        var checked = 0;
        for (final e in texts.evaluate()) {
          final box = e.renderObject! as RenderParagraph;
          final text = box.text.toPlainText();
          if (!mine(text)) continue;
          checked++;
          expect(box.didExceedMaxLines, isFalse, reason: '$card: $text');
          expect(
            box.getMinIntrinsicHeight(box.size.width),
            lessThanOrEqualTo(box.size.height + 0.5),
            reason: '$card: "$text" ist abgeschnitten',
          );
          // Eine Zeile ohne Umbruch muss ganz in ihre Breite passen.
          if (box.maxLines == 1 || !box.softWrap) {
            expect(
              box.getMaxIntrinsicWidth(double.infinity),
              lessThanOrEqualTo(box.size.width + 0.5),
              reason: '$card: "$text" ist abgeschnitten',
            );
          }
        }
        expect(
          checked,
          card == 'payment-card'
              // Fünf Texte der neuen Reihen, drei Regler mit je drei Segmenten.
              ? newInPayments.length - 3 + 9
              : greaterThan(8),
          reason: card,
        );
      }
      // Jedes Segment der drei Regler ist so hoch, wie sein Text es braucht,
      // und alle Segmente eines Reglers sind gleich hoch.
      for (final prefix in [
        'discount-access',
        'open-amount-access',
        'setting-deposit-return',
      ]) {
        final heights = <double>{};
        for (final a in FeatureAccess.values) {
          final segment = find.byKey(Key('$prefix-${a.name}'));
          final label = t.renderObject<RenderParagraph>(
            find.descendant(of: segment, matching: find.byType(RichText)),
          );
          final drawn = t.getSize(
            find.descendant(
              of: segment,
              matching: find.byType(AnimatedContainer),
            ),
          );
          heights.add(drawn.height);
          expect(
            label.getMinIntrinsicHeight(label.size.width),
            lessThanOrEqualTo(drawn.height + 0.5),
            reason: '$prefix-${a.name}: Text höher als sein Segment',
          );
          expect(
            drawn.height,
            greaterThanOrEqualTo(KassaTokens.drawnControlHeight),
          );
          expect(
            t.getSize(segment).height,
            greaterThanOrEqualTo(KassaTokens.minTap),
          );
        }
        expect(heights, hasLength(1), reason: '$prefix: ungleich hoch');
      }
      expect(find.text(l.settingsReceiptTitle), findsOneWidget);
      expect(find.text(l.settingsReceiptNeedsServer), findsOneWidget);
      expect(find.text(l.settingsReceiptQrHint), findsOneWidget);
      expect(find.text(l.settingsDepositReturn), findsOneWidget);
    });
  }
}

const _needsServer = 'Geht nur, wenn die Kassa mit dem Server verbunden ist.';
const _qrHint = 'Der Kunde muss den QR-Code am Bildschirm sehen können.';

Future<void> _showReceiptSection(WidgetTester t) async {
  await t.ensureVisible(find.byKey(const Key('receipt-section')));
  await t.pumpAndSettle();
}

/// Das gewählte Segment des Reglers, dessen Segmente `<prefix>-<name>` heißen.
FeatureAccess _segmentOf(WidgetTester t, String prefix) => t
    .widget<Segmented<FeatureAccess>>(
      find.ancestor(
        of: find.byKey(Key('$prefix-${FeatureAccess.off.name}')),
        matching: find.byType(Segmented<FeatureAccess>),
      ),
    )
    .selected;

/// Genau [chosen] ist gewählt (Semantik und Haken, nicht nur Farbe); ohne
/// Kopplung sind die zwei digitalen Werte ausgeschaltet.
void _expectReceiptChoice(
  WidgetTester t,
  ReceiptMode chosen, {
  required bool paired,
}) {
  for (final m in ReceiptMode.values) {
    final row = find.byKey(Key('receipt-mode-${m.name}'));
    final pressable = t.widget<Pressable>(
      find.descendant(of: row, matching: find.byType(Pressable)),
    );
    expect(pressable.selected, m == chosen, reason: m.name);
    expect(
      find.descendant(of: row, matching: find.byIcon(LucideIcons.check)),
      m == chosen ? findsOneWidget : findsNothing,
      reason: m.name,
    );
    final enabled = paired || m == ReceiptMode.alwaysPrint;
    expect(pressable.onTap != null, enabled, reason: m.name);
  }
}

KassaColors _colorsOf(WidgetTester t) =>
    KassaColors.of(t.element(find.byType(SettingsScreen)));
