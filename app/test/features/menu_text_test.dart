// Namen der Speisekarte am Bildschirm in der Bediensprache, über das
// Wörterbuch. Gespeichert und gedruckt wird der Name aus der Speisekarte.

import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/core/app_language.dart';
import 'package:kassa/data/providers.dart';
import 'package:material_ui/material_ui.dart';

import '../support/kassa_pump.dart';

/// Ein türkischer Name mit 45 Zeichen (Review Focus 1).
const _longTurkish = 'Izgara tavuklu büyük pirinç kasesi ve sebzeli';

Future<void> _setLanguage(WidgetTester t, AppLanguage language) async {
  final repo = containerOf(t).read(settingsRepositoryProvider);
  await repo.save((await repo.current()).copyWith(language: language));
  await t.pumpAndSettle();
}

Future<void> _seed(
  WidgetTester t,
  Map<String, Map<String, String>> entries,
) async {
  await containerOf(t).read(translationRepositoryProvider).upsert(entries);
  await t.pumpAndSettle();
}

Finder _inKey(String key, String text) =>
    find.descendant(of: find.byKey(Key(key)), matching: find.text(text));

/// Der gezeichnete Text mit [text] unter [key]: ganz zu sehen, nicht gekürzt.
RenderParagraph _paragraph(WidgetTester t, String key, String text) =>
    t.renderObject<RenderParagraph>(_inKey(key, text));

const _dictionary = {
  'Huhn Bowl': {'tr': 'Tavuk Bowl'},
  'Bowls': {'tr': 'Kaseler'},
  'Basis': {'tr': 'Taban'},
  'Reis': {'tr': 'Pirinç'},
  'Normal': {'tr': 'Normal'},
};

/// Öffnet die Bowl, wählt Reis und Normal und legt sie auf den Bon.
Future<void> _addBowl(WidgetTester t) async {
  await t.tap(find.byKey(const Key('cat-bowls')));
  await t.pump();
  await t.tap(find.byKey(const Key('item-huhn-bowl')));
  await t.pump();
  await t.tap(find.byKey(const Key('opt-bowl/1/0')));
  await t.tap(find.byKey(const Key('opt-bowl/0/0')));
  await t.pump();
  await t.tap(find.byKey(const Key('add-to-cart')));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('tr: Artikeltaste und Kategorie zeigen die Übersetzung', (
    t,
  ) async {
    await pumpKassa(t);
    await _seed(t, _dictionary);
    await _setLanguage(t, AppLanguage.tr);
    await t.tap(find.byKey(const Key('cat-bowls')));
    await t.pumpAndSettle();
    expect(_inKey('item-huhn-bowl', 'Tavuk Bowl'), findsOneWidget);
    expect(_inKey('item-huhn-bowl', 'Huhn Bowl'), findsNothing);
    expect(_inKey('cat-bowls', 'Kaseler'), findsOneWidget);
    expect(find.byKey(const Key('area-title')), findsOneWidget);
    expect(t.widget<Text>(find.byKey(const Key('area-title'))).data, 'Kaseler');
  });

  for (final language in [AppLanguage.de, AppLanguage.zh]) {
    testWidgets('${language.name}: ohne Übersetzung der Name der Speisekarte', (
      t,
    ) async {
      await pumpKassa(t);
      await _seed(t, _dictionary);
      await _setLanguage(t, language);
      await t.tap(find.byKey(const Key('cat-bowls')));
      await t.pumpAndSettle();
      expect(_inKey('item-huhn-bowl', 'Huhn Bowl'), findsOneWidget);
      expect(_inKey('cat-bowls', 'Bowls'), findsOneWidget);
    });
  }

  testWidgets('tr: Gruppe, Option und Zeile des Bons übersetzt', (t) async {
    await pumpKassa(t);
    await _seed(t, _dictionary);
    await _setLanguage(t, AppLanguage.tr);
    await t.tap(find.byKey(const Key('cat-bowls')));
    await t.pump();
    await t.tap(find.byKey(const Key('item-huhn-bowl')));
    await t.pumpAndSettle();
    expect(_inKey('opt-bowl/1/0', 'Pirinç'), findsOneWidget);
    expect(_inKey('opt-bowl/1/0', 'Reis'), findsNothing);
    expect(_inKey('group-bowl/1', 'Taban'), findsOneWidget);
    expect(_inKey('builder-huhn-bowl', 'Tavuk Bowl'), findsOneWidget);
    // Ohne Übersetzung: der Name der Speisekarte.
    expect(_inKey('opt-bowl/1/1', 'Nudeln'), findsOneWidget);

    await t.tap(find.byKey(const Key('opt-bowl/1/0')));
    await t.tap(find.byKey(const Key('opt-bowl/0/0')));
    await t.pump();
    await t.tap(find.byKey(const Key('add-to-cart')));
    await t.pumpAndSettle();
    final line = cartOf(t).lines.single;
    final row = 'line-${line.lineId}';
    expect(_inKey(row, 'Tavuk Bowl'), findsOneWidget);
    expect(_inKey(row, 'Normal, Pirinç'), findsOneWidget);
    // Der offene Bon hält den Namen der Speisekarte.
    expect(line.item.name, 'Huhn Bowl');
  });

  testWidgets('de und zh: Option und Bon-Zeile mit dem Namen der Speisekarte', (
    t,
  ) async {
    await pumpKassa(t);
    await _seed(t, _dictionary);
    await _setLanguage(t, AppLanguage.zh);
    await _addBowl(t);
    final row = 'line-${cartOf(t).lines.single.lineId}';
    expect(_inKey(row, 'Huhn Bowl'), findsOneWidget);
    expect(_inKey(row, 'Normal、Reis'), findsOneWidget);
    await _setLanguage(t, AppLanguage.de);
    expect(_inKey(row, 'Huhn Bowl'), findsOneWidget);
    expect(_inKey(row, 'Normal, Reis'), findsOneWidget);
  });

  for (final images in [true, false]) {
    testWidgets(
      'ein Name mit 45 Zeichen bricht auf der Taste um, nichts '
      'läuft über oder wird gekürzt (${images ? 'mit Bildern' : 'kompakt'})',
      (t) async {
        expect(_longTurkish.length, 45);
        await pumpKassa(t);
        await _seed(t, {
          'Huhn Bowl': {'tr': _longTurkish},
        });
        await _setLanguage(t, AppLanguage.tr);
        await t.tap(
          find.byKey(Key(images ? 'segment-Mit Bildern' : 'segment-Kompakt')),
        );
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('cat-bowls')));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        final p = _paragraph(t, 'item-huhn-bowl', _longTurkish);
        expect(p.didExceedMaxLines, isFalse);
        // Mehr als eine Zeile: der Name bricht um.
        final oneLine = p.getFullHeightForCaret(const TextPosition(offset: 0));
        expect(p.size.height, greaterThan(oneLine * 1.5));
        // Der Text bleibt innerhalb der Taste.
        final tile = t.getRect(find.byKey(const Key('item-huhn-bowl')));
        final text = t.getRect(_inKey('item-huhn-bowl', _longTurkish));
        expect(tile.contains(text.topLeft), isTrue);
        expect(tile.contains(text.bottomRight), isTrue);
      },
    );
  }

  testWidgets('ein Name mit 45 Zeichen in der Zeile des Bons: ganz zu sehen', (
    t,
  ) async {
    await pumpKassa(t);
    await _seed(t, {
      'Huhn Bowl': {'tr': _longTurkish},
    });
    await _setLanguage(t, AppLanguage.tr);
    await _addBowl(t);
    expect(t.takeException(), isNull);
    final row = 'line-${cartOf(t).lines.single.lineId}';
    expect(_paragraph(t, row, _longTurkish).didExceedMaxLines, isFalse);
  });

  testWidgets('nach dem Verkauf steht im gespeicherten Bon der Name der '
      'Speisekarte, auch im Bereich Bons', (t) async {
    await pumpKassa(t);
    await _seed(t, _dictionary);
    await _setLanguage(t, AppLanguage.tr);
    await _addBowl(t);
    await t.tap(find.byKey(const Key('pay-cash')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('finish-sale')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('next-customer')));
    await t.pumpAndSettle();

    await t.tap(find.byKey(const Key('tab-Bons')));
    await t.pumpAndSettle();
    final receipt = containerOf(t).read(todayReceiptsProvider).value!.single;
    final line = receipt.lines.single;
    expect(line.name, 'Huhn Bowl');
    expect(line.options.map((o) => o.optionName), ['Normal', 'Reis']);
    expect(line.options.map((o) => o.groupName), ['Größe', 'Basis']);
    // Die Liste zeigt den Bon mit seinen Namen.
    expect(_inKey('receipt-${receipt.number}', 'Huhn Bowl'), findsOneWidget);
    expect(find.text('Tavuk Bowl'), findsNothing);
  });
}
