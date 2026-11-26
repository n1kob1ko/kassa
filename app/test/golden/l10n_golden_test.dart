import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/app.dart';
import 'package:kassa/core/app_language.dart';
import 'package:kassa/data/providers.dart';
import 'package:material_ui/material_ui.dart';

import '../support/kassa_pump.dart';
import '../support/pump.dart';

// Bildvergleich der Kassa in Chinesisch und Arabisch (von rechts nach links)
// und der Anmeldung in Arabisch, mit den mitgelieferten Schriften. Neu
// erzeugen mit `flutter test --update-goldens test/golden/l10n_golden_test.dart`.

/// Erfundene Übersetzungen eines Teils der Beispiel-Speisekarte; "Cola 0,33 l"
/// bleibt ohne, damit ein lateinischer Name in der Zeile zu sehen ist.
const _names = {
  'Bowls': {'zh': '饭碗', 'ar': 'أطباق'},
  'Snacks': {'zh': '小吃', 'ar': 'وجبات خفيفة'},
  'Süßes': {'zh': '甜点', 'ar': 'حلويات'},
  'Getränke': {'zh': '饮料', 'ar': 'مشروبات'},
  'Huhn Bowl': {'zh': '鸡肉饭碗', 'ar': 'طبق دجاج'},
  'Tofu Bowl': {'zh': '豆腐饭碗', 'ar': 'طبق توفو'},
  'Gemüse Bowl': {'zh': '蔬菜饭碗', 'ar': 'طبق خضار'},
  'Rind Bowl': {'zh': '牛肉饭碗', 'ar': 'طبق لحم بقري'},
  'Teigtaschen': {'zh': '饺子', 'ar': 'زلابية'},
  '5 Stück': {'zh': '5个', 'ar': '5 قطع'},
  'Größe': {'zh': '份量', 'ar': 'الحجم'},
  'Basis': {'zh': '主食', 'ar': 'القاعدة'},
  'XXL': {'zh': '特大', 'ar': 'كبير جدًا'},
  'Nudeln': {'zh': '面条', 'ar': 'معكرونة'},
};

Future<void> _setLanguage(WidgetTester t, AppLanguage language) async {
  final repo = containerOf(t).read(settingsRepositoryProvider);
  await repo.save((await repo.current()).copyWith(language: language));
  await t.pumpAndSettle();
}

/// Kassa mit drei Zeilen am Bon wie in `kassa_hell.png`: eine Bowl mit
/// Auswahl, zwei Cola, Teigtaschen.
Future<void> _kassa(WidgetTester t, AppLanguage language) async {
  await pumpKassa(t);
  await containerOf(t).read(translationRepositoryProvider).upsert(_names);
  await _setLanguage(t, language);
  await t.tap(find.byKey(const Key('item-huhn-bowl')));
  await t.pump();
  await t.tap(find.byKey(const Key('opt-bowl/1/0')));
  await t.tap(find.byKey(const Key('opt-bowl/0/1')));
  await t.pump();
  await t.tap(find.byKey(const Key('add-to-cart')));
  await t.pump();
  await tapItem(t, 'cola');
  await tapItem(t, 'cola');
  await tapItem(t, 'teigtaschen');
  await t.pumpAndSettle();
}

void main() {
  for (final (language, file) in [
    (AppLanguage.zh, 'kassa_chinesisch'),
    (AppLanguage.ar, 'kassa_arabisch'),
  ]) {
    testWidgets('Kassa mit drei Zeilen (${language.name})', (t) async {
      await _kassa(t, language);
      expect(t.takeException(), isNull);
      await expectLater(
        find.byType(KassaApp),
        matchesGoldenFile('goldens/$file.png'),
      );
    });
  }

  testWidgets('Anmeldung auf Arabisch, zwei Ziffern getippt', (t) async {
    await pumpApp(t, const KassaApp(), overrides: await memoryOverrides());
    await t.pumpAndSettle();
    await _setLanguage(t, AppLanguage.ar);
    await tapKeys(t, '1 2');
    await t.pump(const Duration(milliseconds: 300));
    expect(t.takeException(), isNull);
    await expectLater(
      find.byType(KassaApp),
      matchesGoldenFile('goldens/anmeldung_arabisch.png'),
    );
  });
}
