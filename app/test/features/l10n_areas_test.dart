// Bons, Artikel, Übersicht, Abschluss und die Hauptseite der Einstellungen in
// den anderen Sprachen. Datum und Beträge sehen in jeder Sprache gleich aus,
// nur die Namen von Monat und Wochentag sind übersetzt.

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/core/app_language.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/features/bons/bons_screen.dart';
import 'package:kassa/features/close/close_screen.dart';
import 'package:kassa/features/login/session.dart';
import 'package:kassa/features/items/items_screen.dart';
import 'package:kassa/features/overview/overview_screen.dart';
import 'package:kassa/features/settings/settings_screen.dart';
import 'package:kassa/l10n/generated/l10n.dart';
import 'package:kassa/ui/dates_text.dart';
import 'package:material_ui/material_ui.dart';

import '../support/bons_pump.dart';
import '../support/close_pump.dart';
import '../support/items_pump.dart';
import '../support/kassa_pump.dart';
import '../support/overview_pump.dart';
import '../support/settings_pump.dart';

Future<void> _setLanguage(WidgetTester t, AppLanguage language) async {
  final repo = containerOf(t).read(settingsRepositoryProvider);
  await repo.save((await repo.current()).copyWith(language: language));
  await t.pumpAndSettle();
}

/// [text] im Bereich [area], nicht in der Kopfleiste.
Finder _inArea(Type area, String text) =>
    find.descendant(of: find.byType(area), matching: find.text(text));

void main() {
  group('en', () {
    testWidgets('Bons: Titel, Filter, Tag und Bon', (t) async {
      await pumpBonsWithSales(t, 2);
      await _setLanguage(t, AppLanguage.en);
      expect(_inArea(BonsScreen, 'Receipts'), findsOneWidget);
      expect(
        _inArea(BonsScreen, 'Today, Tuesday, 17 November'),
        findsOneWidget,
      );
      expect(_inArea(BonsScreen, 'All'), findsOneWidget);
      expect(_inArea(BonsScreen, 'Voided'), findsOneWidget);
      expect(_inArea(BonsScreen, 'Bons'), findsNothing);
      await openReceipt(t, 1);
      expect(_inArea(BonsScreen, 'Receipt no. 1'), findsOneWidget);
      expect(_inArea(BonsScreen, 'Total'), findsOneWidget);
      // Uhrzeit und Betrag wie auf Deutsch.
      expect(_inArea(BonsScreen, '11:00'), findsWidgets);
      // Der gespeicherte Bon behält seine Namen.
      expect(_inArea(BonsScreen, 'Cola 0,33 l'), findsWidgets);
    });

    testWidgets('Bons: Storno-Rückfrage', (t) async {
      await pumpBonsWithSales(t, 1);
      await _setLanguage(t, AppLanguage.en);
      await openReceipt(t, 1);
      await t.tap(find.byKey(const Key('void-receipt')));
      await t.pumpAndSettle();
      expect(_inArea(BonsScreen, 'Void receipt no. 1?'), findsOneWidget);
      expect(_inArea(BonsScreen, 'Yes, void'), findsOneWidget);
      expect(_inArea(BonsScreen, 'Cancel'), findsOneWidget);
    });

    testWidgets('Artikel: Titel, Kopf der Liste und Detail', (t) async {
      await pumpItems(t);
      await _setLanguage(t, AppLanguage.en);
      expect(_inArea(ItemsScreen, 'Items'), findsWidgets);
      expect(_inArea(ItemsScreen, 'Price'), findsWidgets);
      expect(_inArea(ItemsScreen, 'Change price'), findsOneWidget);
      expect(_inArea(ItemsScreen, 'Tax rate'), findsOneWidget);
      expect(_inArea(ItemsScreen, 'Preis ändern'), findsNothing);
    });

    testWidgets('Artikel: Namen der Speisekarte übersetzt', (t) async {
      await pumpItems(t);
      await containerOf(t).read(translationRepositoryProvider).upsert({
        'Huhn Bowl': {'en': 'Chicken bowl'},
        'Bowls': {'en': 'Bowls (en)'},
      });
      await _setLanguage(t, AppLanguage.en);
      await openItem(t, 'huhn-bowl');
      expect(
        find.descendant(
          of: find.byKey(const Key('row-huhn-bowl')),
          matching: find.text('Chicken bowl'),
        ),
        findsOneWidget,
      );
      expect(_inArea(ItemsScreen, 'Bowls (en)'), findsWidgets);
      expect(_inArea(ItemsScreen, 'Huhn Bowl'), findsNothing);
    });

    testWidgets('Übersicht: Titel, Umsatz und Datum', (t) async {
      await pumpOverviewWithSales(t);
      await _setLanguage(t, AppLanguage.en);
      expect(_inArea(OverviewScreen, 'Overview'), findsOneWidget);
      expect(_inArea(OverviewScreen, 'Revenue'), findsOneWidget);
      expect(_inArea(OverviewScreen, 'Tuesday, 17 November'), findsOneWidget);
      expect(_inArea(OverviewScreen, 'Übersicht'), findsNothing);
    });

    testWidgets('Abschluss: Titel, Tag und Monat, Geldlade', (t) async {
      await pumpClose(t, floatCents: 15000);
      await _setLanguage(t, AppLanguage.en);
      expect(_inArea(CloseScreen, 'Closing'), findsOneWidget);
      expect(_inArea(CloseScreen, 'Day'), findsOneWidget);
      expect(_inArea(CloseScreen, 'Month'), findsOneWidget);
      expect(_inArea(CloseScreen, 'Count cash drawer'), findsOneWidget);
      expect(_inArea(CloseScreen, 'Tagesabschluss'), findsNothing);
      await t.tap(_inArea(CloseScreen, 'Month'));
      await t.pumpAndSettle();
      expect(_inArea(CloseScreen, 'Monthly report'), findsWidgets);
    });

    testWidgets('Einstellungen: Hauptseite', (t) async {
      await pumpKassa(t);
      await containerOf(t).read(sessionProvider.notifier).login('4711');
      await t.pump();
      await openSettings(t);
      await _setLanguage(t, AppLanguage.en);
      expect(_inArea(SettingsScreen, 'Settings'), findsOneWidget);
      expect(_inArea(SettingsScreen, 'Display'), findsOneWidget);
      expect(_inArea(SettingsScreen, 'Dark'), findsOneWidget);
      expect(_inArea(SettingsScreen, 'Anzeige'), findsNothing);
    });
  });

  group('ar: der Titel jedes Bereichs', () {
    testWidgets('Bons', (t) async {
      await pumpBonsWithSales(t, 1);
      await _setLanguage(t, AppLanguage.ar);
      expect(_inArea(BonsScreen, 'الفواتير'), findsOneWidget);
    });
    testWidgets('Artikel', (t) async {
      await pumpItems(t);
      await _setLanguage(t, AppLanguage.ar);
      expect(_inArea(ItemsScreen, 'الأصناف'), findsWidgets);
    });
    testWidgets('Übersicht', (t) async {
      await pumpOverviewWithSales(t);
      await _setLanguage(t, AppLanguage.ar);
      expect(_inArea(OverviewScreen, 'نظرة عامة'), findsOneWidget);
    });
    testWidgets('Abschluss', (t) async {
      await pumpClose(t, floatCents: 15000);
      await _setLanguage(t, AppLanguage.ar);
      expect(_inArea(CloseScreen, 'إقفال اليوم'), findsOneWidget);
    });
  });

  test('Monate und Wochentage in jeder Sprache, Deutsch mit Jänner', () {
    final de = lookupL10n(const Locale('de'));
    expect(monthName(de, 1), 'Jänner');
    expect(monthName(de, 12), 'Dezember');
    expect(weekdayName(de, 1), 'Montag');
    expect(weekdayName(de, 7), 'Sonntag');
    final en = lookupL10n(const Locale('en'));
    expect(monthName(en, 1), 'January');
    expect(weekdayName(en, 2), 'Tuesday');
    for (final code in ['de', 'en', 'zh', 'tr', 'ar']) {
      final l = lookupL10n(Locale(code));
      final names = {
        for (var m = 1; m <= 12; m++) monthName(l, m),
        for (var d = 1; d <= 7; d++) weekdayName(l, d),
      };
      expect(names, hasLength(19), reason: code);
      for (final n in names) {
        expect(n.trim(), isNotEmpty, reason: code);
      }
    }
  });

  testWidgets('Übersicht: Pfand nach Kategorie in der Bediensprache', (
    t,
  ) async {
    // Die Beispiel-Verkäufe haben Cola mit Pfand.
    await pumpOverviewWithSales(t);
    expect(_inArea(OverviewScreen, 'Pfand'), findsOneWidget);
    await _setLanguage(t, AppLanguage.tr);
    expect(_inArea(OverviewScreen, 'Depozito'), findsOneWidget);
    expect(_inArea(OverviewScreen, 'Pfand'), findsNothing);
  });

  test('Chinesisch schreibt den Monat mit Ziffern ("11月17日")', () {
    final zh = lookupL10n(const Locale('zh'));
    expect(monthName(zh, 11), '11月');
    expect(weekdayDayMonth(zh, DateTime(2026, 11, 17)), '11月17日 星期二');
    expect(zh.closeDayMonth(1, monthName(zh, 12)), '12月1日');
    expect(zh.closeMonthYear(monthName(zh, 11), 2026), '2026年11月');
  });

  test('Politur der Übersetzungen', () {
    final en = lookupL10n(const Locale('en'));
    expect(en.kassaPaidExact, 'Exact amount');
    expect(en.kassaStillMissing, 'Remaining');
    final zh = lookupL10n(const Locale('zh'));
    expect(zh.closeSaveCashIn, '确认存入');
    expect(zh.closeSaveCashOut, '确认取出');
    expect(zh.bonsVoidOf('128'), '作废 128 号小票');
    // Türkisch: Tasten in der kurzen Befehlsform, Sätze höflich.
    final tr = lookupL10n(const Locale('tr'));
    expect(tr.outageRepin, "PIN'i yeniden gir");
    expect(tr.settingsDeviceTestHelp, 'Test baskısı, çekmeceyi açma.');
    final ar = lookupL10n(const Locale('ar'));
    expect(ar.kassaItemCount(0), 'لا أصناف');
    expect(ar.kassaCancel, 'إلغاء');
  });
}
