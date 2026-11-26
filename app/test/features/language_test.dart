import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/app.dart';
import 'package:kassa/core/app_language.dart';
import 'package:kassa/features/login/pin_screen.dart';
import 'package:kassa/features/settings/settings_screen.dart';
import 'package:kassa/features/shell/shell_screen.dart';
import 'package:kassa/ui/language_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../support/kassa_pump.dart';
import '../support/pump.dart';
import '../support/settings_pump.dart';

/// Eine eingerichtete Kassa, niemand angemeldet: das Anmeldebild.
Future<void> _pumpLoggedOut(WidgetTester t) async {
  await pumpApp(t, const KassaApp(), overrides: await memoryOverrides());
  await t.pumpAndSettle();
}

Locale _localeOf(WidgetTester t, Type screen) =>
    Localizations.localeOf(t.element(find.byType(screen)));

void main() {
  testWidgets('Einstellungen: "Sprache" steht als erster Abschnitt', (t) async {
    await pumpSettings(t);
    final title = find.text('Sprache');
    expect(title, findsOneWidget);
    // Oben in der rechten Spalte, auf einer Höhe mit "Signatur" (die links
    // oben ohne Scrollen ganz im Bild bleiben muss), über den Geräten.
    expect(t.getTopLeft(title).dy, t.getTopLeft(find.text('Signatur')).dy);
    expect(
      t.getTopLeft(title).dy,
      lessThan(t.getTopLeft(find.text('Geräte an dieser Kassa')).dy),
    );
    for (final l in AppLanguage.values) {
      final key = find.byKey(Key('language-${l.name}'));
      expect(key, findsOneWidget);
      expect(
        find.descendant(of: key, matching: find.text(l.nativeName)),
        findsOneWidget,
      );
      expect(t.getSize(key).height, greaterThanOrEqualTo(64));
    }
  });

  testWidgets('Tipp auf English stellt sofort um und wird gespeichert', (
    t,
  ) async {
    await pumpSettings(t);
    expect(_localeOf(t, SettingsScreen), const Locale('de'));
    await t.tap(find.byKey(const Key('language-en')));
    await t.pumpAndSettle();
    expect(find.text('Sprache'), findsNothing);
    expect(find.text('Language'), findsOneWidget);
    expect(_localeOf(t, SettingsScreen), const Locale('en'));
    expect((await settingsOf(t)).language, AppLanguage.en);
    // Die gewählte Taste ist als gewählt markiert, nicht nur farbig.
    expect(
      t.getSemantics(find.byKey(const Key('language-en'))),
      isSemantics(isSelected: true, isButton: true),
    );
  });

  testWidgets('nach neuem Aufbau der App gilt Englisch', (t) async {
    await pumpSettings(t);
    await t.tap(find.byKey(const Key('language-en')));
    await t.pumpAndSettle();
    await pumpKassa(t, sameDatabase: true);
    expect(_localeOf(t, ShellScreen), const Locale('en'));
  });

  testWidgets('Arabisch liest von rechts nach links', (t) async {
    await pumpSettings(t);
    expect(
      Directionality.of(t.element(find.byType(SettingsScreen))),
      TextDirection.ltr,
    );
    await t.tap(find.byKey(const Key('language-ar')));
    await t.pumpAndSettle();
    expect(
      Directionality.of(t.element(find.byType(SettingsScreen))),
      TextDirection.rtl,
    );
    expect(find.text('اللغة'), findsOneWidget);
  });

  testWidgets('der offene Bon bleibt beim Wechsel der Sprache', (t) async {
    await pumpAppLoggedInAsChef(t);
    await tapItem(t, 'cola');
    await tapItem(t, 'cola');
    await tapItem(t, 'huhn-bowl');
    await t.pumpAndSettle();
    final before = cartOf(t);
    expect(before.lines, isNotEmpty);
    await openSettings(t);
    await t.tap(find.byKey(const Key('language-tr')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('language-ar')));
    await t.pumpAndSettle();
    expect(cartOf(t), same(before));
  });

  testWidgets('Sprachtaste am Anmeldebildschirm öffnet das Blatt, die Wahl '
      'schließt es und stellt um', (t) async {
    await _pumpLoggedOut(t);
    final button = find.byKey(const Key('login-language'));
    expect(button, findsOneWidget);
    expect(find.bySemanticsLabel('Sprache ändern'), findsOneWidget);
    expect(
      find.descendant(of: button, matching: find.text('Deutsch')),
      findsOneWidget,
    );
    expect(t.getSize(button).height, greaterThanOrEqualTo(52));
    // Oben am Ende der Zeile: rechts über der Karte.
    expect(t.getTopRight(button).dx, greaterThan(1280 - 40));
    expect(t.getTopRight(button).dy, lessThan(40));

    await t.tap(button);
    await t.pumpAndSettle();
    expect(find.byType(LanguagePicker), findsOneWidget);
    expect(find.text('Sprache'), findsOneWidget);
    await t.tap(find.byKey(const Key('language-zh')));
    await t.pumpAndSettle();
    expect(find.byType(LanguagePicker), findsNothing);
    expect(_localeOf(t, PinScreen), const Locale('zh'));
    expect(
      find.descendant(of: button, matching: find.text('中文')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('更改语言'), findsOneWidget);
  });

  testWidgets('Arabisch: die Sprachtaste steht links oben', (t) async {
    await _pumpLoggedOut(t);
    await t.tap(find.byKey(const Key('login-language')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('language-ar')));
    await t.pumpAndSettle();
    final button = find.byKey(const Key('login-language'));
    expect(t.getTopLeft(button).dx, lessThan(40));
    expect(t.getTopLeft(button).dy, lessThan(40));
  });

  testWidgets('das Blatt schließt mit Tipp daneben, ohne umzustellen', (
    t,
  ) async {
    await _pumpLoggedOut(t);
    await t.tap(find.byKey(const Key('login-language')));
    await t.pumpAndSettle();
    expect(find.byType(LanguagePicker), findsOneWidget);
    await t.tapAt(const Offset(640, 40));
    await t.pumpAndSettle();
    expect(find.byType(LanguagePicker), findsNothing);
    expect(_localeOf(t, PinScreen), const Locale('de'));
  });

  testWidgets('das Blatt schließt mit Wischen nach unten', (t) async {
    await _pumpLoggedOut(t);
    await t.tap(find.byKey(const Key('login-language')));
    await t.pumpAndSettle();
    await t.fling(find.byType(LanguagePicker), const Offset(0, 400), 1500);
    await t.pumpAndSettle();
    expect(find.byType(LanguagePicker), findsNothing);
    expect(_localeOf(t, PinScreen), const Locale('de'));
  });

  testWidgets('Namen der Sprachen haben eine Schrift mit ihren Zeichen', (
    t,
  ) async {
    await pumpSettings(t);
    for (final l in AppLanguage.values) {
      final text = t.widget<Text>(
        find.descendant(
          of: find.byKey(Key('language-${l.name}')),
          matching: find.text(l.nativeName),
        ),
      );
      final style = DefaultTextStyle.of(t.element(find.text(l.nativeName)))
          .style
          .merge(text.style);
      expect(style.fontFamily, 'Figtree');
      expect(
        style.fontFamilyFallback,
        containsAllInOrder(['Noto Sans Arabic', 'Noto Sans SC']),
      );
    }
  });

  test('alle fünf ARB-Dateien haben dieselben Schlüssel', () {
    Set<String> keysOf(String code) {
      final json = jsonDecode(
        File('lib/l10n/app_$code.arb').readAsStringSync(),
      ) as Map<String, dynamic>;
      expect(json['@@locale'], code);
      return json.keys.where((k) => !k.startsWith('@')).toSet();
    }

    final template = keysOf('de');
    expect(template, isNotEmpty);
    for (final l in AppLanguage.values) {
      final keys = keysOf(l.name);
      expect(keys, template, reason: 'app_${l.name}.arb');
      final json = jsonDecode(
        File('lib/l10n/app_${l.name}.arb').readAsStringSync(),
      ) as Map<String, dynamic>;
      for (final k in keys) {
        expect(
          (json[k] as String).trim(),
          isNotEmpty,
          reason: '$k in app_${l.name}.arb',
        );
      }
    }
  });
}
