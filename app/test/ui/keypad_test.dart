import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/ui/keypad.dart';
import 'package:material_ui/material_ui.dart';

import '../support/pump.dart';

void main() {
  testWidgets('Zahlenfeld meldet Tasten, jede Taste ist mindestens 48 dp', (
    t,
  ) async {
    final keys = <String>[];
    await pumpApp(t, Keypad(onKey: keys.add));
    await t.tap(find.byKey(const Key('key-7')));
    await t.tap(find.byKey(const Key('key-comma')));
    await t.tap(find.byKey(const Key('key-back')));
    expect(keys, ['7', ',', 'back']);
    for (final k in [
      for (var i = 0; i < 10; i++) 'key-$i',
      'key-comma',
      'key-back',
    ]) {
      expect(
        t.getSize(find.byKey(Key(k))).shortestSide,
        greaterThanOrEqualTo(48),
        reason: k,
      );
    }
    expect(t.getSize(find.byKey(const Key('key-7'))).height, 56);
  });

  testWidgets('Zahlenfeld ohne Komma lässt die Zelle leer', (t) async {
    final keys = <String>[];
    await pumpApp(t, Keypad(onKey: keys.add, showComma: false));
    expect(find.byKey(const Key('key-comma')), findsNothing);
    // Layout bleibt: die Null steht in der Mitte der unteren Reihe.
    final zero = t.getCenter(find.byKey(const Key('key-0')));
    final back = t.getCenter(find.byKey(const Key('key-back')));
    final eight = t.getCenter(find.byKey(const Key('key-8')));
    expect(zero.dx, closeTo(eight.dx, 0.5));
    expect(back.dx, greaterThan(zero.dx));
  });

  testWidgets('Tasten haben Semantik und es gibt kein Textfeld', (t) async {
    final handle = t.ensureSemantics();
    await pumpApp(t, Keypad(onKey: (_) {}));
    expect(find.bySemanticsLabel('Komma'), findsOneWidget);
    expect(find.bySemanticsLabel('Letzte Ziffer löschen'), findsOneWidget);
    expect(find.byType(EditableText), findsNothing);
    handle.dispose();
  });

  testWidgets('tapKeys tippt Tasten in Reihenfolge', (t) async {
    final keys = <String>[];
    await pumpApp(t, Keypad(onKey: keys.add));
    await tapKeys(t, '1 2 , 5 0 back');
    expect(keys, ['1', '2', ',', '5', '0', 'back']);
  });
}
