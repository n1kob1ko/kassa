import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../support/pump.dart';
import '../support/widget_board.dart';

// Bildvergleich: eine Tafel mit allen Bausteinen, hell und dunkel, 1280x800
// und 960x600 mit Textskala 1,3. Neu erzeugen mit
// `flutter test --update-goldens test/golden/widgets_golden_test.dart`.
void main() {
  for (final (name, size, brightness, scale) in [
    ('hell', const Size(1280, 800), Brightness.light, 1.0),
    ('dunkel', const Size(1280, 800), Brightness.dark, 1.0),
    ('klein', const Size(960, 600), Brightness.light, 1.3),
  ]) {
    testWidgets('Bausteine sehen aus wie im Entwurf ($name)', (t) async {
      await pumpApp(
        t,
        const WidgetBoard(),
        size: size,
        brightness: brightness,
        textScale: scale,
      );
      expect(t.takeException(), isNull); // kein Überlauf
      await expectLater(
        find.byType(WidgetBoard),
        matchesGoldenFile('goldens/widgets_$name.png'),
      );
    });
  }
}
